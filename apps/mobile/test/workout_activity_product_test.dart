import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/member_progress_overview.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/analytics/domain/exercise_improvement.dart';
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'routine_history_ui_test.dart' as routines;
import 'member_workout_report_test.dart' as reports;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('stored Curl summaries retain actual arm modes in progress mapping',
      () async {
    final scope = reports.reportScope;
    final start = DateTime.utc(2026, 10, 25);
    final store = InMemoryWorkoutSessionStore(scope: scope);
    for (final mode in <CurlArmMode?>[
      CurlArmMode.leftOnly,
      CurlArmMode.rightOnly,
      CurlArmMode.both,
      null
    ]) {
      final left = mode == CurlArmMode.rightOnly ? 0 : 2;
      final right = mode == CurlArmMode.leftOnly || mode == null ? 0 : 2;
      final arms = mode == null
          ? null
          : CurlArmMetrics(
              mode: mode,
              targetSets: 1,
              repetitionsPerArm: 2,
              completedSets: 1,
              left: CurlArmResult(
                  repetitions: left,
                  partialRepetitions: 0,
                  formScorePercent: left == 0 ? null : 90),
              right: CurlArmResult(
                  repetitions: right,
                  partialRepetitions: 0,
                  formScorePercent: right == 0 ? null : 90));
      final summary = WorkoutSessionSummary(
          sessionId: mode?.name ?? 'legacy',
          userId: scope.userId,
          organizationId: scope.organizationId,
          exerciseId: 'standing-single-arm-curl-side-v1',
          repetitions: left + right,
          accuracy: 90,
          startedAt: start,
          endedAt: start.add(const Duration(seconds: 10)),
          provenance: WorkoutProvenance.realCamera,
          poseMetrics: WorkoutPoseMetrics(
              partialRepetitions: 0,
              trackedDurationMicros: 8000000,
              rejectedDurationMicros: 0,
              formScorePercent: 90,
              scoringVersion: 'single-arm-curl-side-v1',
              detectorId: 'blazepose-tflite',
              detectorVersion: 'same-model',
              cameraView: 'side',
              consentVersion: 'pose-local-summary-v1',
              consentedAt: start,
              publishedRoutineId: 'routine',
              curlArms: arms));
      await WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope).saveLocal(summary);
    }
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: MemoryRealWorkoutSyncStore(scope: scope),
        activeScope: () => scope).load();
    expect(result.records.map((r) => r.armMode).toSet(),
        {'leftOnly', 'rightOnly', 'both', null});
  });
  testWidgets('History date filters retain older workouts under All time',
      (tester) async {
    final a = routines.attempt();
    await tester.pumpWidget(MaterialApp(
        home: RoutineHistoryScreen(
            attempts: [a],
            asOf: DateTime.utc(2026, 12, 25),
            onOpenAttempt: (_) {})));
    expect(find.text('Strength days · Day 1'), findsNothing);
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('Strength days · Day 1'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Strength days · Day 1'), findsOneWidget);
  });
  test('Curl comparisons split left right both and unknown historical modes',
      () {
    final base =
        reports.reportRecord('base', reports.reportNow, exercise: 'curl');
    final records = <LocalWorkoutProgressRecord>[];
    for (final mode in <String?>['leftOnly', 'rightOnly', 'both', null]) {
      records.add(LocalWorkoutProgressRecord(
          scope: base.scope,
          sessionId: mode ?? 'old',
          exerciseId: base.exerciseId,
          startedAt: base.startedAt,
          endedAt: base.endedAt,
          repetitions: base.repetitions,
          partialRepetitions: base.partialRepetitions,
          trackedDurationMicros: base.trackedDurationMicros,
          rejectedDurationMicros: 0,
          formScorePercent: base.formScorePercent,
          scoringVersion: 'single-arm-curl-side-v1',
          detectorId: base.detectorId,
          detectorVersion: base.detectorVersion,
          cameraView: base.cameraView,
          status: base.status,
          armMode: mode));
    }
    final progress = calculateLocalMemberProgress(
        scope: base.scope, records: records, asOf: reports.reportNow);
    expect(progress.formSeries, hasLength(4));
    expect(
        exerciseImprovements(progress).every((c) => c.previous == null), true);
    expect(progress.records.singleWhere((r) => r.sessionId == 'old').armMode,
        isNull);
  });
  testWidgets('linked captures do not duplicate workouts or start dates',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = routines.attempt();
    final opened = DateTime.utc(2026, 10, 27, 15, 50);
    final ended = DateTime.utc(2026, 10, 27, 16, 10);
    final now = DateTime.utc(2026, 10, 28, 12);
    final record = reports.reportRecord('camera', ended,
        exercise: a.routine.exercises.first.exerciseId);
    final saved = RoutineAttempt(
        id: a.id,
        scope: a.scope,
        routine: a.routine,
        day: a.day,
        finished: true,
        updatedAtMicros: ended.microsecondsSinceEpoch,
        startedAtMicros: opened.microsecondsSinceEpoch,
        finishedAtMicros: ended.microsecondsSinceEpoch,
        entries: a.entries);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MemberProgressOverview(
                    progress: calculateLocalMemberProgress(
                        scope: a.scope, records: [record], asOf: now),
                    routines: RoutineProgress(
                        scope: a.scope, attempts: [saved], asOf: now),
                    onPerformance: () {})))));
    await tester.pumpAndSettle();
    final metric = find.byKey(const ValueKey('progress-training-days'));
    expect(
        find.descendant(of: metric, matching: find.text('1')), findsOneWidget);
    expect(find.text('Workout start days'), findsOneWidget);
    expect(find.text('5 reps · Measured / provisional'), findsNothing);
    expect(find.text('Activity trends'), findsOneWidget);
  });
}
