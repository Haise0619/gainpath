import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/wall_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class WallDetector implements ManagedPoseDetector {
  WallPushUpSide side = WallPushUpSide.left;
  double angle = 170;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    final reach = .28 * math.sin(angle * math.pi / 360),
        sag = .14 * math.cos(angle * math.pi / 360);
    const wrist = .42;
    final shoulder = wrist - reach, hip = shoulder - .04;
    PosePoint p(double x, double y) =>
        PosePoint(x: x * 2, y: y, z: 0, visibility: .99, presence: .99);
    final j = WallPushUpGeometry.joints(side);
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 400,
        imageHeight: 800,
        landmarks: {
          j[0]: p(shoulder, .25),
          j[1]: p((shoulder + wrist) / 2, .25 + sag),
          j[2]: p(wrist, .25),
          j[3]: p(hip, .5),
          j[4]: p(hip - .04, .75)
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
  for (final side in WallPushUpSide.values) {
    testWidgets(
        '${side.name} wall push-up completes sets and retries one saved result',
        (tester) async {
      var now = 0;
      final camera = Camera(),
          detector = WallDetector()..side = side,
          store = FailingStore(scope: scope);
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = WallPushUpWorkoutSession(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repo,
          clockMicros: () => now,
          sessionId: 'wall-${side.name}',
          exerciseId: 'wall-push-up-side-v1',
          publishedRoutineId: 'routine',
          detectorId: 'fixture',
          detectorVersion: '1',
          sets: 2,
          reps: 1,
          provenance: WorkoutProvenance.recordedFixture);
      await session.start(consented: false, setupConfirmed: true);
      expect(camera.starts, 0);
      await session.start(consented: true, setupConfirmed: true);
      expect(session.preview.responsivePreview, false);
      Future<void> frame(double angle) async {
        now += 150000;
        detector.angle = angle;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump();
      }

      Future<void> calibrate() async {
        for (var i = 0; i < 9; i++) {
          await frame(170);
        }
      }

      Future<void> press() async {
        for (final a in <double>[
          160,
          140,
          120,
          100,
          90,
          90,
          110,
          140,
          160,
          170,
          170
        ]) {
          await frame(a);
        }
      }

      await calibrate();
      await press();
      expect(session.guidance.stage, GuidedWorkoutStage.resting);
      session.startNextSet(skipRest: true);
      await calibrate();
      await press();
      expect(session.guidance.stage, GuidedWorkoutStage.complete);
      expect(camera.starts, 1);
      expect(await session.endAndSave(), isNull);
      expect(session.viewPhase, MeasuredWorkoutPhase.saveFailed);
      store.fail = false;
      final saved = await session.endAndSave();
      expect(saved!.repetitions, 2);
      expect(saved.poseMetrics!.scoringVersion, WallPushUpAnalyzer.version);
      expect(saved.isEligibleForRealUpload, false);
      expect(WorkoutSessionSummary.fromJson(saved.toJson()), saved);
      expect((await repo.loadHistory()).length, 1);
      await tester.pumpWidget(
          MaterialApp(home: WorkoutResultScreen.measured(summary: saved)));
      await tester.pumpAndSettle();
      expect(find.text('MEASURED WALL PUSH-UP RESULT'), findsOneWidget);
      expect(find.text('MEASURED SQUAT RESULT'), findsNothing);
      session.dispose();
      repo.dispose();
    });
  }
  testWidgets(
      'wall contact setup needs acknowledgement and offers no upload option',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        onUploadChanged: (_) {},
                        allowUpload: false,
                        exerciseInstruction: wallPushUpCaptureInstruction,
                        setupConfirmationLabel: wallPushUpSetupConfirmation),
                    child: const Text('Consent'))))));
    await tester.tap(find.text('Consent'));
    await tester.pumpAndSettle();
    expect(find.text(wallPushUpSetupConfirmation), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept and start'))
            .onPressed,
        isNull);
    expect(find.text('Also allow this measured summary to be uploaded.'),
        findsNothing);
  });
  testWidgets('wall session closes on account loss and cannot save',
      (tester) async {
    var now = 0;
    SessionScope? active = scope;
    final camera = Camera(), store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final session = WallPushUpWorkoutSession(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => WallDetector(),
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'wall-account',
        exerciseId: 'wall-push-up-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 1,
        reps: 5,
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
    repo.dispose();
  });
}
