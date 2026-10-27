import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/widgets/routine_progress_card.dart';
import 'routine_journey_controller_test.dart' as support;

RoutineAttempt attempt({bool complete = true}) {
  final end = DateTime.utc(2026, 10, 25, 15).microsecondsSinceEpoch;
  return RoutineAttempt(
      id: 'attempt',
      scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
      routine: support.routineFixture(),
      day: 1,
      finished: true,
      startedAtMicros: end - 60000000,
      finishedAtMicros: end,
      updatedAtMicros: end,
      entries: [
        RoutineExerciseResult(
            index: 0,
            status: complete
                ? RoutineExerciseStatus.completed
                : RoutineExerciseStatus.skipped,
            sessionIds: complete ? ['camera'] : [],
            fullRepetitions: complete ? 2 : 0,
            partialRepetitions: 0,
            trackedDurationMicros: complete ? 8000000 : 0,
            manualSets: 0),
        RoutineExerciseResult(
            index: 1,
            status: RoutineExerciseStatus.selfReportedCompleted,
            sessionIds: [],
            fullRepetitions: 0,
            partialRepetitions: 0,
            trackedDurationMicros: 0,
            manualSets: 2)
      ]);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('routine card shows routine days separately from camera sessions',
      (tester) async {
    final a = attempt();
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RoutineProgressCard(
                progress: RoutineProgress(
                    scope: a.scope,
                    attempts: [a],
                    asOf: DateTime.utc(2026, 10, 25, 15, 1)),
                onOpenHistory: () => opened = true))));
    expect(find.text('1 routine day completed this week'), findsOneWidget);
    expect(find.textContaining('Strength days'), findsOneWidget);
    await tester.tap(find.text('Routine history'));
    expect(opened, true);
  });
  testWidgets(
      'history opens exact saved attempt and detail offers next day and repeat',
      (tester) async {
    final a = attempt();
    RoutineAttempt? selected;
    await tester.pumpWidget(MaterialApp(
        home: RoutineHistoryScreen(
            attempts: [a], onOpenAttempt: (v) => selected = v)));
    expect(find.text('Completed'), findsOneWidget);
    await tester.tap(find.text('Strength days · Day 1'));
    expect(selected, a);
    var next = false, repeat = false;
    await tester.pumpWidget(MaterialApp(
        home: RoutineAttemptDetailScreen(
            attempt: a,
            onRepeat: () => repeat = true,
            onNextDay: () => next = true)));
    await tester.scrollUntilVisible(find.text('Next routine day'), 200);
    await tester.ensureVisible(find.text('Next routine day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next routine day'));
    expect(next, true);
    await tester.scrollUntilVisible(find.text('Repeat this workout'), 200);
    await tester.ensureVisible(find.text('Repeat this workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat this workout'));
    expect(repeat, true);
  });
  testWidgets(
      'partial detail preserves skipped status and offers resume on small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var resumed = false;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: RoutineAttemptDetailScreen(
            attempt: attempt(complete: false),
            onResume: () => resumed = true)));
    expect(find.text('Partially completed'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Resume unfinished exercises'), 180);
    await tester.tap(find.text('Resume unfinished exercises'));
    expect(resumed, true);
    expect(tester.takeException(), isNull);
  });
}
