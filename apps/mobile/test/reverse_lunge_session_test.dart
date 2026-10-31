import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/reverse_lunge_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'support/reverse_lunge_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class LungeDetector implements ManagedPoseDetector {
  late PoseFrame frame;
  @override
  Future<PoseFrame> detect(PoseInput input) async => frame;
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope =
      SessionScope(userId: 'lunge-member', organizationId: 'gainpath');
  testWidgets(
      'deferred lunge camera starts only after foreground and explicit resume',
      (tester) async {
    final camera = Camera(),
        detector = LungeDetector(),
        store = FailingStore(scope: scope);
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    final session = ReverseLungeWorkoutSession(
        scope: scope,
        side: LungeSide.left,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => 0,
        sessionId: 'lunge-deferred',
        exerciseId: 'bodyweight-reverse-lunge-side-v1',
        publishedRoutineId: 'lunge-routine',
        detectorId: 'synthetic-reverse-lunge',
        detectorVersion: '1',
        sets: 1,
        reps: 2,
        provenance: WorkoutProvenance.recordedFixture);
    addTearDown(() {
      session.dispose();
      repo.dispose();
    });
    await session.start(
        consented: true, setupConfirmed: true, foreground: false);
    expect(camera.starts, 0);
    await session.pause();
    await session.setForeground(true);
    expect(camera.starts, 0);
    await session.resume();
    expect(camera.starts, 1);
    await session.close();
  });
  for (final side in LungeSide.values) {
    testWidgets(
        '${side.name} lunge respects authored targets/rest and retries one unscored saved result',
        (tester) async {
      var now = 0;
      final camera = Camera(),
          detector = LungeDetector(),
          store = FailingStore(scope: scope);
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = ReverseLungeWorkoutSession(
          scope: scope,
          side: side,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repo,
          clockMicros: () => now,
          sessionId: 'lunge-${side.name}',
          exerciseId: 'bodyweight-reverse-lunge-side-v1',
          publishedRoutineId: 'lunge-routine',
          detectorId: 'synthetic-reverse-lunge',
          detectorVersion: '1',
          sets: 2,
          reps: 1,
          provenance: WorkoutProvenance.recordedFixture);
      var notifications = 0;
      session.addListener(() => notifications++);
      addTearDown(() {
        session.dispose();
        repo.dispose();
      });
      session.guidance.setRestSeconds(45);
      await session.start(consented: false, setupConfirmed: true);
      expect(camera.starts, 0);
      await session.start(consented: true, setupConfirmed: true);
      expect(session.preview.responsivePreview, true);
      expect(await session.endAndSave(), isNull);
      Future<void> cycle() async {
        // Flush explicit start/save/rest actions before measuring frame updates.
        await tester.pump();
        for (final frame
            in reverseLungeTrajectory(side: side, startMicros: now + 50000)) {
          now = frame.capturedAtMicros;
          detector.frame = frame;
          final before = notifications;
          camera.receive!(PoseInput(timestampMicros: now));
          await tester.pump();
          expect(notifications - before, lessThanOrEqualTo(1));
        }
      }

      await cycle();
      expect(session.guidance.stage, GuidedWorkoutStage.resting);
      expect(session.analysis!.repetitions, 1);
      await cycle();
      expect(session.analysis!.repetitions, 1);
      await session.pause();
      session.startNextSet(skipRest: true);
      expect(session.guidance.stage, GuidedWorkoutStage.resting);
      await session.resume();
      session.startNextSet(skipRest: true);
      await cycle();
      expect(session.guidance.stage, GuidedWorkoutStage.complete);
      expect(session.analysis!.repetitions, 2);
      expect(session.analysis!.formScorePercent, isNull);
      expect(await session.endAndSave(), isNull);
      expect(session.viewPhase, MeasuredWorkoutPhase.saveFailed);
      store.fail = false;
      final saved = (await session.endAndSave())!;
      expect(saved.repetitions, 2);
      expect(saved.accuracy, 0);
      expect(saved.poseMetrics!.lungeSide, side.name);
      expect(saved.poseMetrics!.formScorePercent, isNull);
      expect(saved.isEligibleForRealUpload, false);
      expect(WorkoutSessionSummary.fromJson(saved.toJson()), saved);
      expect(await session.endAndSave(), same(saved));
      expect((await repo.loadHistory()).length, 1);
    });
  }
  testWidgets(
      'lunge session discards an interrupted peak and closes on account loss',
      (tester) async {
    var now = 0;
    SessionScope? active = scope;
    final camera = Camera(),
        detector = LungeDetector(),
        store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final session = ReverseLungeWorkoutSession(
        scope: scope,
        side: LungeSide.left,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'lunge-account',
        exerciseId: 'bodyweight-reverse-lunge-side-v1',
        publishedRoutineId: 'lunge-routine',
        detectorId: 'synthetic-reverse-lunge',
        detectorVersion: '1',
        sets: 1,
        reps: 2,
        provenance: WorkoutProvenance.recordedFixture);
    addTearDown(() {
      session.dispose();
      repo.dispose();
    });
    await session.start(consented: true, setupConfirmed: true);
    for (final frame in reverseLungeTrajectory()
        .where((f) => f.capturedAtMicros <= 2000000)) {
      now = frame.capturedAtMicros;
      detector.frame = frame;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
    }
    await session.pause();
    expect(session.isPaused, true);
    await session.setForeground(false);
    await session.setForeground(true);
    expect(session.isManuallyPaused, true);
    expect(camera.starts, 1);
    await session.resume();
    expect(camera.starts, 2);
    now += 50000;
    detector.frame = reverseLungeFrame(now, 0, 0);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.analysis!.repetitions, 0);
    expect(session.analysis!.needsCalibration, true);
    session.beginRecalibration();
    now += 50000;
    detector.frame = reverseLungeFrame(now, 1, 1);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.canConfirmRecalibration, false);
    now += 50000;
    detector.frame = reverseLungeFrame(now, 0, 0);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.canConfirmRecalibration, true);
    now += 50000;
    final neutral = reverseLungeFrame(now, 0, 0);
    detector.frame = PoseFrame(
        capturedAtMicros: neutral.capturedAtMicros,
        detectorId: 'unexpected-model',
        modelVersion: neutral.modelVersion,
        imageWidth: neutral.imageWidth,
        imageHeight: neutral.imageHeight,
        isMirrored: neutral.isMirrored,
        landmarks: neutral.landmarks);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.canConfirmRecalibration, false);
    now += 1000000;
    expect(session.canConfirmRecalibration, false);
    active = null;
    session.accountChanged();
    await tester.pump();
    expect(session.viewPhase, MeasuredWorkoutPhase.closed);
    expect(await session.endAndSave(), isNull);
    expect(await store.read(), isEmpty);
  });
}
