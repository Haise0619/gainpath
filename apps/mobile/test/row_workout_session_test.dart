import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/row_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'support/row_trajectory.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

class RowDetector implements ManagedPoseDetector {
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
  final scope = SessionScope(userId: 'row-member', organizationId: 'gainpath');
  testWidgets(
      'deferred row camera starts only after foreground and explicit resume',
      (tester) async {
    final camera = Camera(),
        detector = RowDetector(),
        store = FailingStore(scope: scope);
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    final session = RowWorkoutSession(
        scope: scope,
        side: RowSide.left,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => 0,
        sessionId: 'row-deferred',
        exerciseId: 'single-arm-dumbbell-row-side-v1',
        publishedRoutineId: 'row-routine',
        detectorId: 'synthetic-row',
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
  for (final side in RowSide.values) {
    testWidgets(
        '${side.name} row respects authored targets/rest and retries one unscored saved result',
        (tester) async {
      var now = 0;
      final camera = Camera(),
          detector = RowDetector(),
          store = FailingStore(scope: scope);
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = RowWorkoutSession(
          scope: scope,
          side: side,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: AudioSink(),
          repository: repo,
          clockMicros: () => now,
          sessionId: 'row-${side.name}',
          exerciseId: 'single-arm-dumbbell-row-side-v1',
          publishedRoutineId: 'row-routine',
          detectorId: 'synthetic-row',
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
            in rowTrajectory(side: side, startMicros: now + 50000)) {
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
      expect(saved.poseMetrics!.rowSide, side.name);
      expect(saved.poseMetrics!.formScorePercent, isNull);
      expect(saved.isEligibleForRealUpload, false);
      expect(WorkoutSessionSummary.fromJson(saved.toJson()), saved);
      expect(await session.endAndSave(), same(saved));
      expect((await repo.loadHistory()).length, 1);
      await tester.pumpWidget(
          MaterialApp(home: WorkoutResultScreen.measured(summary: saved)));
      await tester.pumpAndSettle();
      expect(find.text('MEASURED ROW RESULT'), findsOneWidget);
      expect(find.text('MEASURED SQUAT RESULT'), findsNothing);
      expect(find.text('Form score is not assessed for rows'), findsOneWidget);
      expect(find.textContaining('Selected arm:'), findsOneWidget);
    });
  }
  testWidgets(
      'row session discards an interrupted peak and closes on account loss',
      (tester) async {
    var now = 0;
    SessionScope? active = scope;
    final camera = Camera(),
        detector = RowDetector(),
        store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final session = RowWorkoutSession(
        scope: scope,
        side: RowSide.left,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: AudioSink(),
        repository: repo,
        clockMicros: () => now,
        sessionId: 'row-account',
        exerciseId: 'single-arm-dumbbell-row-side-v1',
        publishedRoutineId: 'row-routine',
        detectorId: 'synthetic-row',
        detectorVersion: '1',
        sets: 1,
        reps: 2,
        provenance: WorkoutProvenance.recordedFixture);
    addTearDown(() {
      session.dispose();
      repo.dispose();
    });
    await session.start(consented: true, setupConfirmed: true);
    for (final frame
        in rowTrajectory().where((f) => f.capturedAtMicros <= 2000000)) {
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
    detector.frame = rowFrame(now, 0);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(session.analysis!.repetitions, 0);
    expect(session.analysis!.needsCalibration, true);
    active = null;
    session.accountChanged();
    await tester.pump();
    expect(session.viewPhase, MeasuredWorkoutPhase.closed);
    expect(await session.endAndSave(), isNull);
    expect(await store.read(), isEmpty);
  });
}
