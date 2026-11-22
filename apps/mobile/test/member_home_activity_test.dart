import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/app/home/member_home_activity.dart';
import 'package:gainpath_mobile/app/home/member_home_data.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';

import 'member_home_refinement_test.dart' as fixture;

void main() {
  final layouts = [320.0, 360.0, 393.0, 412.0];
  final monday = DateTime.utc(2026, 11, 16);
  final friday = monday.add(const Duration(days: 4));

  RoutineProgress week(Iterable<RoutineAttempt> attempts) => RoutineProgress(
      scope: fixture.homeScope, attempts: attempts, asOf: friday);

  Widget weekly(RoutineProgress? routines,
          {double scale = 1,
          bool reducedMotion = false,
          MemberLocalProgress? records}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              HomeWeeklyActivity(progress: records, routines: routines)
            ],
          ),
        ),
      );

  for (final width in layouts) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'Weekly card fits ${width.toInt()} dp at ${scale}x with all activity states',
          (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        final routines = week([
          fixture.homeAttempt(
              id: 'mon1', completed: true, finished: true, at: monday),
          fixture.homeAttempt(
              id: 'mon2', completed: true, finished: true, at: monday),
          fixture.homeAttempt(
              id: 'tue', at: monday.add(const Duration(days: 1))),
        ]);
        final progress = calculateLocalMemberProgress(
          scope: fixture.homeScope,
          records: [
            LocalWorkoutProgressRecord(
              scope: fixture.homeScope,
              sessionId: 'weekly-record',
              exerciseId: 'squat',
              startedAt: friday.subtract(const Duration(minutes: 5)),
              endedAt: friday,
              repetitions: 12,
              partialRepetitions: 0,
              trackedDurationMicros: 1000000,
              rejectedDurationMicros: 0,
              formScorePercent: null,
              scoringVersion: 'v1',
              detectorId: 'd',
              detectorVersion: 'v1',
              cameraView: 'front',
              status: LocalWorkoutRecordStatus.pending,
            ),
          ],
          asOf: friday,
        );
        await tester
            .pumpWidget(weekly(routines, scale: scale, records: progress));
        await tester.pumpAndSettle();
        expect(find.text('THIS WEEK'), findsOneWidget);
        expect(find.text('Workouts completed'), findsOneWidget);
        expect(find.text('Weekly activity'), findsOneWidget);
        expect(find.text('Exercise records saved this week'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.bySemanticsLabel('2 completed workouts'), findsOneWidget);
        expect(find.bySemanticsLabel('Monday, Completed'), findsOneWidget);
        expect(find.bySemanticsLabel('Tuesday, In progress'), findsOneWidget);
        expect(
            find.bySemanticsLabel('Friday, Exercise record'), findsOneWidget);
        expect(find.bySemanticsLabel('Sunday, No activity'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets('weekly card distinguishes loading, zero and a large count',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(weekly(null, scale: 2, reducedMotion: true));
    expect(find.text('Workout progress is loading.'), findsOneWidget);
    expect(find.bySemanticsLabel('0 completed workouts'), findsNothing);
    await tester.pumpWidget(weekly(week([]), scale: 2, reducedMotion: true));
    expect(find.text('0'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^[A-Z][a-z]+day, No activity$')),
        findsNWidgets(7));
    final allWeek = RoutineProgress(
      scope: fixture.homeScope,
      asOf: monday.add(const Duration(days: 6)),
      attempts: List.generate(
          1234,
          (index) => fixture.homeAttempt(
                id: 'completed-$index',
                completed: true,
                finished: true,
                at: monday.add(Duration(days: index % 7)),
              )),
    );
    await tester.pumpWidget(weekly(allWeek, scale: 2, reducedMotion: true));
    expect(find.text('1234'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^[A-Z][a-z]+day, Completed$')),
        findsNWidgets(7));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('weekly count animates updates without replaying on rebuild',
      (tester) async {
    final count = find.byKey(const ValueKey('home-weekly-completion-count'));
    String? value() => tester.widget<Text>(count).data;
    final completed = fixture.homeAttempt(
        id: 'completed', finished: true, completed: true, at: monday);
    await tester.pumpWidget(weekly(week([])));
    expect(value(), '0');

    await tester.pumpWidget(weekly(week([completed])));
    expect(value(), '0');
    await tester.pumpAndSettle();
    expect(value(), '1');

    await tester.pumpWidget(weekly(week([completed])));
    expect(value(), '1');
  });

  test('Sunday completion is excluded at the Malaysia Monday boundary', () {
    final sunday = fixture.homeAttempt(
        completed: true,
        finished: true,
        at: DateTime.utc(2026, 11, 15, 15, 59, 59));
    // 16:00 UTC is midnight Monday in Malaysia.
    final monday = DateTime.utc(2026, 11, 15, 16);
    final previous = RoutineProgress(
        scope: fixture.homeScope,
        attempts: [sunday],
        asOf: monday.subtract(const Duration(seconds: 1)));
    final current = RoutineProgress(
        scope: fixture.homeScope, attempts: [sunday], asOf: monday);
    expect(previous.weeklyCompleted, 1);
    expect(homeWeekActivity(previous, null).last, HomeDayActivity.completed);
    expect(current.weeklyCompleted, 0);
    expect(homeWeekActivity(current, null), everyElement(HomeDayActivity.none));

    final onBoundary = RoutineProgress(
        scope: fixture.homeScope,
        attempts: [
          fixture.homeAttempt(completed: true, finished: true, at: monday)
        ],
        asOf: monday);
    expect(onBoundary.weeklyCompleted, 1);
    expect(homeWeekActivity(onBoundary, null).first, HomeDayActivity.completed);
  });

  test(
      'progress, partial finish and exercise records do not inflate completions',
      () {
    final asOf = fixture.homeNow;
    final records = fixture.homeProgress();
    final inProgress = fixture.homeRoutines([fixture.homeAttempt()]);
    expect(inProgress.weeklyCompleted, 0);
    final day = asOf.difference(inProgress.weekStart).inDays;
    expect(
        homeWeekActivity(inProgress, records)[day], HomeDayActivity.inProgress);
    final partial = fixture.homeRoutines([fixture.homeAttempt(finished: true)]);
    expect(partial.weeklyCompleted, 0);
    expect(homeWeekActivity(partial, records)[day],
        HomeDayActivity.exerciseRecord);
    final future = RoutineProgress(
        scope: fixture.homeScope,
        attempts: [
          fixture.homeAttempt(at: asOf.add(const Duration(minutes: 1)))
        ],
        asOf: asOf);
    expect(homeWeekActivity(future, null), everyElement(HomeDayActivity.none));
  });

  testWidgets('empty and active activity preserve actions and reduced motion',
      (tester) async {
    var history = 0;
    RoutineAttempt? opened;
    final attempt = fixture.homeAttempt();
    Widget page(RoutineProgress routines) => MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: Scaffold(
            body: HomeRecentActivity(
          live: true,
          scope: fixture.homeScope,
          routines: routines,
          onOpenHistory: () => history++,
          onOpenRoutine: (item) => opened = item,
        )));
    await tester.pumpWidget(page(fixture.homeRoutines([])));
    expect(find.text('No saved workouts yet.'), findsOneWidget);
    await tester.tap(find.text('View all'));
    expect(history, 1);
    await tester.pumpWidget(page(fixture.homeRoutines([attempt])));
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Saved on device · backup status unavailable'),
        findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0);
    await tester.tap(find.text(attempt.routine.title));
    expect(opened, same(attempt));
  });
}
