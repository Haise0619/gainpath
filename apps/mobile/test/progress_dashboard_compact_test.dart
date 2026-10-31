import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'routine_journey_controller_test.dart' as support;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'recent workouts dedupe captures and show real manual routine with distinct training date',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scope = SessionScope(userId: 'u', organizationId: 'o');
    final now = DateTime.utc(2026, 10, 29, 10);
    final capture = LocalWorkoutProgressRecord(
        scope: scope,
        sessionId: 'camera',
        exerciseId: 'F3b8xIr8ynBDd3gEICKX',
        startedAt: now.subtract(const Duration(minutes: 1)),
        endedAt: now,
        repetitions: 5,
        partialRepetitions: 1,
        formScorePercent: null,
        trackedDurationMicros: 3000000,
        rejectedDurationMicros: 0,
        scoringVersion: 'v',
        detectorId: 'd',
        detectorVersion: 'v',
        cameraView: 'side',
        status: LocalWorkoutRecordStatus.localOnly);
    final savedPlan = routinePlanSnapshot(support.routineFixture());
    for (final exercise in savedPlan['exercises'] as List) {
      if (exercise['exerciseId'] == 'F3b8xIr8ynBDd3gEICKX') {
        exercise['name'] = 'Front / squat-low';
      }
    }
    final namedRoutine = PublishedRoutine.fromDocument('routine', savedPlan);
    final manual = RoutineAttempt(
        id: 'routine',
        scope: scope,
        routine: namedRoutine,
        day: 1,
        finished: true,
        startedAtMicros:
            now.subtract(const Duration(hours: 2)).microsecondsSinceEpoch,
        finishedAtMicros:
            now.subtract(const Duration(hours: 1)).microsecondsSinceEpoch,
        updatedAtMicros: now.microsecondsSinceEpoch,
        entries: [
          RoutineExerciseResult(
              index: 0,
              status: RoutineExerciseStatus.selfReportedCompleted,
              sessionIds: [],
              fullRepetitions: 0,
              partialRepetitions: 0,
              trackedDurationMicros: 0,
              manualSets: 2)
        ]);
    RoutineAttempt? opened;
    await tester.pumpWidget(MaterialApp(
        home: ProgressDashboardScreen(
            localProgress: calculateLocalMemberProgress(
                scope: scope, records: [capture, capture], asOf: now),
            routineProgress: RoutineProgress(
                scope: scope, attempts: [manual, manual], asOf: now),
            onOpenRoutine: (a) => opened = a)));
    await tester.pumpAndSettle();
    expect(find.text('Front / squat-low'), findsOneWidget);
    expect(find.text('5 reps · Measured / provisional'), findsOneWidget);
    expect(find.textContaining('2 self-reported sets'), findsOneWidget);
    final training = find.byKey(const ValueKey('progress-training-days'));
    expect(find.descendant(of: training, matching: find.text('1')),
        findsOneWidget);
    await tester.tap(find.textContaining('2 self-reported sets'));
    expect(opened?.id, 'routine');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'weekly hero uses actual scheduled denominator and leaves zero schedule unscored',
      (tester) async {
    final scope = SessionScope(userId: 'u', organizationId: 'o');
    final progress = calculateLocalMemberProgress(
        scope: scope, records: [], asOf: DateTime.utc(2026, 10, 29));
    Future<void> render(int? completed, int? scheduled) async {
      await tester.pumpWidget(MaterialApp(
          home: ProgressDashboardScreen(
              localProgress: progress,
              programStatsBuilder: (summary) => Builder(
                  builder: (context) =>
                      summary(context, completed, scheduled)))));
      await tester.pumpAndSettle();
    }

    await render(2, 4);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await render(0, 0);
    expect(find.text('0%'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    await render(null, null);
    expect(find.text('—'), findsNWidgets(2));
  });
  for (final populated in [false, true]) {
    testWidgets('compact Progress $populated narrow enlarged text and actions',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scope = SessionScope(userId: 'u', organizationId: 'o');
      final now = DateTime.utc(2026, 10, 29, 10);
      var starts = 0;
      final progress =
          calculateLocalMemberProgress(scope: scope, asOf: now, records: [
        if (populated)
          LocalWorkoutProgressRecord(
              scope: scope,
              sessionId: 's',
              exerciseId: 'squat',
              startedAt: now.subtract(const Duration(minutes: 1)),
              endedAt: now,
              repetitions: 5,
              partialRepetitions: 1,
              formScorePercent: null,
              trackedDurationMicros: 3000000,
              rejectedDurationMicros: 0,
              scoringVersion: 'v',
              detectorId: 'd',
              detectorVersion: 'v',
              cameraView: 'side',
              status: LocalWorkoutRecordStatus.localOnly)
      ]);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!),
          home: ProgressDashboardScreen(
              localProgress: progress, onStartWorkout: () => starts++)));
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Training days'), findsOneWidget);
      expect(find.text('Saved sessions'), findsNothing);
      expect(
          find.byKey(const ValueKey('progress-training-days')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('progress-quick-History')), findsOneWidget);
      expect(find.text('Adherence'), findsOneWidget);
      expect(find.text('Estimated Form Scores'), findsOneWidget);
      final form = find.ancestor(
          of: find.text('Estimated Form Scores'),
          matching: find.byType(ExpansionTile));
      expect(form, findsNothing);
      final heading = tester.widget<Text>(find.text('This week'));
      expect(heading.style?.color, Colors.white);
      await tester.scrollUntilVisible(find.text('Start workout'), 150);
      await tester.ensureVisible(find.text('Start workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start workout'));
      expect(starts, 1);
      await tester.scrollUntilVisible(find.text('Measurement details'), 150);
      expect(find.text('Partial attempts'), findsNothing);
      await tester.ensureVisible(find.text('Measurement details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measurement details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('partial attempts'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
