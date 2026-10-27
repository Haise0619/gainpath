import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/calf_raise_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class CalfDetector implements ManagedPoseDetector {
  CalfSide side = CalfSide.left;
  double lift = 0;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    PosePoint p(double x, double y) =>
        PosePoint(x: x * 2, y: y, z: 0, visibility: .99, presence: .99);
    final j = CalfRaiseGeometry.joints(side);
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 400,
        imageHeight: 800,
        landmarks: {
          j[0]: p(.20, .35 - lift * .2),
          j[1]: p(.20, .55 - lift * .2),
          j[2]: p(.20, .75 - lift * .2),
          j[3]: p(.19, .80 - lift * .2),
          j[4]: p(.26, .80),
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
  for (final side in CalfSide.values) {
    testWidgets(
        '${side.name} calf raise preserves targets, rest and same-result save retry',
        (tester) async {
      var now = 0;
      final camera = Camera(),
          detector = CalfDetector()..side = side,
          store = FailingStore(scope: scope);
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = CalfRaiseWorkoutSession(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repo,
          clockMicros: () => now,
          sessionId: 'calf-${side.name}',
          exerciseId: 'standing-calf-raise-side-v1',
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
      Future<void> frame(double lift) async {
        now += 150000;
        detector.lift = lift;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump();
      }

      Future<void> calibrate() async {
        for (var i = 0; i < 8; i++) {
          await frame(0);
        }
      }

      Future<void> raise() async {
        for (final lift in <double>[
          .02,
          .04,
          .07,
          .11,
          .11,
          .11,
          .07,
          .04,
          .01,
          0
        ]) {
          await frame(lift);
        }
      }

      await frame(0);
      await frame(0);
      expect(session.calibrationCue, contains('Hold still'));
      expect(session.calibrationCue, contains('%'));
      await calibrate();
      await raise();
      expect(session.guidance.stage, GuidedWorkoutStage.resting);
      expect(session.analysis!.repetitions, 1);
      session.startNextSet(skipRest: true);
      await calibrate();
      await raise();
      expect(session.guidance.stage, GuidedWorkoutStage.complete);
      expect(camera.starts, 1);
      expect(await session.endAndSave(), isNull);
      expect(session.viewPhase, MeasuredWorkoutPhase.saveFailed);
      store.fail = false;
      final saved = await session.endAndSave();
      expect(saved!.repetitions, 2);
      expect(saved.poseMetrics!.scoringVersion, CalfRaiseAnalyzer.version);
      expect(saved.isEligibleForRealUpload, false);
      expect(WorkoutSessionSummary.fromJson(saved.toJson()), saved);
      expect((await repo.loadHistory()).length, 1);
      await tester.pumpWidget(
          MaterialApp(home: WorkoutResultScreen.measured(summary: saved)));
      await tester.pumpAndSettle();
      expect(find.text('MEASURED CALF RAISE RESULT'), findsOneWidget);
      expect(find.text('MEASURED SQUAT RESULT'), findsNothing);
      session.dispose();
      repo.dispose();
    });
  }
  testWidgets('calf consent describes foot visibility with no upload option',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showWorkoutCaptureConsent(context,
                        onUploadChanged: (_) {},
                        allowUpload: false,
                        exerciseInstruction: calfRaiseCaptureInstruction),
                    child: const Text('Consent'))))));
    await tester.tap(find.text('Consent'));
    await tester.pumpAndSettle();
    expect(find.text(calfRaiseCaptureInstruction), findsOneWidget);
    expect(find.text('Also allow this measured summary to be uploaded.'),
        findsNothing);
  });
  testWidgets(
      'calf pause breaks an unfinished raise and account loss blocks saving',
      (tester) async {
    var now = 0;
    SessionScope? active = scope;
    final camera = Camera(),
        detector = CalfDetector(),
        store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final session = CalfRaiseWorkoutSession(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'calf-pause',
        exerciseId: 'standing-calf-raise-side-v1',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 1,
        reps: 5,
        provenance: WorkoutProvenance.recordedFixture);
    await session.start(consented: true, setupConfirmed: true);
    Future<void> frame(double lift) async {
      now += 150000;
      detector.lift = lift;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }

    for (var i = 0; i < 8; i++) {
      await frame(0);
    }
    for (final lift in <double>[.02, .04, .07, .11, .11, .11]) {
      await frame(lift);
    }
    await session.pause();
    await session.resume();
    await frame(0);
    expect(session.analysis!.repetitions, 0);
    expect(session.analysis!.needsCalibration, true);
    await session.setForeground(false);
    expect(session.isPaused, true);
    await session.setForeground(true);
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
