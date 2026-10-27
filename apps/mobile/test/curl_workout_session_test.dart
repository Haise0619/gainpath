import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/curl_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class _CurlDetector implements ManagedPoseDetector {
  double angle = 170;
  CurlSide side = CurlSide.left;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    final radians = angle * math.pi / 180;
    PosePoint p(double x, double y) =>
        PosePoint(x: x, y: y, z: 0, visibility: .99, presence: .99);
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 400,
        imageHeight: 800,
        landmarks: {
          CurlGeometry.joints(side)[0]: p(.4, .2),
          CurlGeometry.joints(side)[1]: p(.4, .34),
          CurlGeometry.joints(side)[2]:
              p(.4 + .24 * math.sin(radians), .34 - .12 * math.cos(radians)),
          CurlGeometry.joints(side)[3]: p(.4, .58),
        });
  }

  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  testWidgets(
      'curl consent names the single-arm session and offers no upload opt-in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        onUploadChanged: (_) {},
                        allowUpload: false,
                        exerciseInstruction: curlCaptureInstruction),
                    child: const Text('Open consent'))))));
    await tester.tap(find.text('Open consent'));
    await tester.pumpAndSettle();
    expect(find.text(curlCaptureInstruction), findsOneWidget);
    expect(
        find.text(
            'My full body is visible from the side and the camera is upright and stationary.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept and start'))
            .onPressed,
        isNull);
    expect(find.text('Also allow this measured summary to be uploaded.'),
        findsNothing);
  });
  testWidgets(
      'account loss closes curl capture and cannot save measured activity',
      (tester) async {
    SessionScope? active = scope;
    var now = 0;
    final camera = Camera(), store = FailingStore(scope: scope)..fail = false;
    final repository = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final session = CurlWorkoutSession(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => _CurlDetector(),
        audioPort: AudioSink(),
        repository: repository,
        clockMicros: () => now,
        sessionId: 'curl-account',
        exerciseId: 'standing-single-arm-curl-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 1,
        reps: 1,
        armMode: CurlArmMode.leftOnly,
        provenance: WorkoutProvenance.recordedFixture);
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    active = null;
    session.accountChanged();
    await tester.pump();
    expect(session.viewPhase, MeasuredWorkoutPhase.closed);
    expect(await session.endAndSave(), isNull);
    expect(await store.read(), isEmpty);
    session.dispose();
    repository.dispose();
  });
  for (final side in CurlSide.values) {
    testWidgets(
        '${side.name}-only curl completes targets and retries the same local summary after a disk failure',
        (tester) async {
      var now = 0;
      final camera = Camera(), detector = _CurlDetector()..side = side;
      final store = FailingStore(scope: scope);
      final repository = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = CurlWorkoutSession(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repository,
          clockMicros: () => now,
          sessionId: 'curl-capture',
          exerciseId: 'standing-single-arm-curl-side-v1',
          publishedRoutineId: 'routine',
          detectorId: 'fixture',
          detectorVersion: '1',
          sets: 1,
          reps: 1,
          armMode: side == CurlSide.left
              ? CurlArmMode.leftOnly
              : CurlArmMode.rightOnly,
          provenance: WorkoutProvenance.recordedFixture);
      await session.start(consented: false, setupConfirmed: true);
      expect(camera.starts, 0);
      await session.start(consented: true, setupConfirmed: true);
      Future<void> frame(double angle, int delta) async {
        now += delta;
        detector.angle = angle;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump();
      }

      for (var i = 0; i < 11; i++) {
        await frame(170, 100000);
      }
      for (final angle in [
        160.0,
        130.0,
        100.0,
        70.0,
        45.0,
        45.0,
        70.0,
        100.0,
        130.0,
        160.0
      ]) {
        await frame(angle, 150000);
      }
      expect(session.analysis!.repetitions, 1);
      expect(session.guidance.completedSets, 1);
      expect(await session.endAndSave(), isNull);
      expect(session.viewPhase, MeasuredWorkoutPhase.saveFailed);
      store.fail = false;
      final saved = await session.endAndSave();
      expect(saved!.sessionId, 'curl-capture');
      expect(saved.exerciseId, 'standing-single-arm-curl-side-v1');
      expect(saved.poseMetrics!.scoringVersion, CurlAnalyzer.version);
      expect(saved.isEligibleForRealUpload, false);
      expect((await repository.loadHistory()).single.summary.repetitions, 1);
      expect(session.viewPhase, MeasuredWorkoutPhase.saved);
      await tester.pumpWidget(
          MaterialApp(home: WorkoutResultScreen.measured(summary: saved)));
      await tester.pumpAndSettle();
      expect(find.text('MEASURED CURL RESULT'), findsOneWidget);
      expect(find.text('MEASURED SQUAT RESULT'), findsNothing);
      session.dispose();
      repository.dispose();
    });
  }
  testWidgets(
      'both arms require a deliberate switch and complete each set separately',
      (tester) async {
    var now = 0;
    final camera = Camera(), detector = _CurlDetector();
    final store = FailingStore(scope: scope)..fail = false;
    final repository = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    final session = CurlWorkoutSession(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repository,
        clockMicros: () => now,
        sessionId: 'both-arms',
        exerciseId: 'standing-single-arm-curl-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 2,
        reps: 1,
        provenance: WorkoutProvenance.recordedFixture);
    await session.start(consented: true, setupConfirmed: true);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: RealWorkoutView(
            session: session,
            viewport: const ColoredBox(color: Colors.black),
            exerciseName: 'Curl',
            targetRepetitions: 1)));
    Future<void> frame(double angle) async {
      now += 150000;
      detector.angle = angle;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }

    Future<void> calibrate() async {
      for (var i = 0; i < 8; i++) {
        await frame(170);
      }
    }

    Future<void> curl() async {
      for (final a in [
        160.0,
        130.0,
        100.0,
        70.0,
        45.0,
        45.0,
        70.0,
        100.0,
        130.0,
        160.0
      ]) {
        await frame(a);
      }
    }

    // Wrong anatomical arm cannot calibrate or earn reps.
    detector.side = CurlSide.right;
    await calibrate();
    await curl();
    expect(session.analysis!.repetitions, 0);
    detector.side = CurlSide.left;
    await calibrate();
    await curl();
    expect(session.awaitingArmSwitch, true);
    expect(session.guidance.stage, GuidedWorkoutStage.working);
    expect(session.guidance.completedSets, 0);
    await tester.pump();
    expect(find.text('Switch arms'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand workout details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Left arm: 1 full'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse workout details'));
    await tester.pumpAndSettle();
    await curl(); // Switching screen never counts extra motion.
    expect(session.analysis!.repetitions, 1);
    await tester.tap(find.byTooltip('Start right arm'));
    await tester.pump();
    detector.side = CurlSide.right;
    expect(session.analysis!.needsCalibration, true);
    await calibrate();
    await curl();
    expect(session.guidance.stage, GuidedWorkoutStage.resting);
    expect(session.armMetrics.left.repetitions, 1);
    expect(session.armMetrics.right.repetitions, 1);
    expect(camera.starts, 1);
    session.startNextSet(skipRest: true);
    expect(session.armLabel, 'Left arm');
    detector.side = CurlSide.left;
    await calibrate();
    await curl();
    session.confirmArmSwitch();
    detector.side = CurlSide.right;
    await calibrate();
    await curl();
    expect(session.guidance.stage, GuidedWorkoutStage.complete);
    final saved = await session.endAndSave();
    expect(saved!.repetitions, 4);
    final restored = WorkoutSessionSummary.fromJson(saved.toJson());
    expect(restored.poseMetrics!.curlArms!.completedSets, 2);
    expect(restored.poseMetrics!.curlArms!.left.repetitions, 2);
    expect(restored.poseMetrics!.curlArms!.right.repetitions, 2);
    expect(restored, saved);
    await tester.pumpWidget(
        MaterialApp(home: WorkoutResultScreen.measured(summary: restored)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Left arm: 2 full'), findsOneWidget);
    expect(find.textContaining('Right arm: 2 full'), findsOneWidget);
    expect(tester.takeException(), isNull);
    session.dispose();
    repository.dispose();
  });
}
