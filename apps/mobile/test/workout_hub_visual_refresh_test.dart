import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_hub_visuals.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
  }

  test('semantic tones and hero/action text meet AA in both themes', () {
    for (final palette in [WorkoutHubPalette.light, WorkoutHubPalette.dark]) {
      for (final tone in palette.tones) {
        expect(contrast(tone.ink, tone.fill), greaterThanOrEqualTo(4.5));
      }
    }
    expect(
        contrast(Colors.white, AppColors.primary), greaterThanOrEqualTo(4.5));
    expect(contrast(Colors.white, AppColors.ink), greaterThanOrEqualTo(4.5));
    expect(contrast(const Color(0xFFDDD2F0), AppColors.ink),
        greaterThanOrEqualTo(4.5));
  });
  final routine = PublishedRoutine.fromDocument('visual', {
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'visual',
    'title': 'Full Body Foundations',
    'estimatedMinutes': 20,
    'exercises': [
      for (var i = 0; i < 4; i++)
        {
          'exerciseId': 'manual_$i',
          'name': 'Movement ${i + 1}',
          'sets': 2,
          'reps': 8
        },
    ],
  });
  ScheduledWorkoutPreview preview(List<RoutineExerciseStatus> states) =>
      ScheduledWorkoutPreview(
        routine: routine,
        day: 1,
        dayKey: 'day',
        enrollmentId: 'enrollment',
        date: DateTime.utc(2026, 11, 7),
        snapshot: 'snapshot',
        inProgress: true,
        attempt: RoutineAttempt(
          id: 'attempt',
          scope: SessionScope(userId: 'member', organizationId: 'gym'),
          routine: routine,
          day: 1,
          finished: false,
          updatedAtMicros: 1,
          entries: [
            for (var i = 0; i < states.length; i++)
              RoutineExerciseResult(
                  index: i,
                  status: states[i],
                  sessionIds: const [],
                  fullRepetitions: 0,
                  partialRepetitions: 0,
                  trackedDurationMicros: 0,
                  manualSets:
                      states[i] == RoutineExerciseStatus.selfReportedCompleted
                          ? 2
                          : 0)
          ],
        ),
      );

  testWidgets('saved states are glanceable without repeated initial labels',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            scheduledWorkout: preview([
              RoutineExerciseStatus.selfReportedCompleted,
              RoutineExerciseStatus.selfReportedPartial,
              RoutineExerciseStatus.skipped,
              RoutineExerciseStatus.notStarted,
            ]),
            onStartScheduled: () {})));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('In progress'), findsAtLeastNWidgets(1));
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Not started'), findsNothing);
    expect(find.text('Manual · Self-reported'), findsNWidgets(3));
    expect(find.text('Movement 4'), findsNothing);
    await tester.ensureVisible(find.text('View all 4 exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all 4 exercises'));
    await tester.pumpAndSettle();
    expect(find.text('Manual · Self-reported'), findsNWidgets(4));
    expect(find.byIcon(Icons.check_rounded), findsAtLeastNWidgets(1));
    expect(
        find.bySemanticsLabel(RegExp(r'Exercise 1.*Completed · Self-reported')),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp(r'Exercise 3.*Skipped')), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (size: const Size(375, 812), scale: 1.0, dark: false),
    (size: const Size(320, 640), scale: 2.0, dark: false),
    (size: const Size(812, 375), scale: 1.0, dark: true),
    (size: const Size(768, 1024), scale: 2.0, dark: true),
  ]) {
    testWidgets('actions and all content survive $config', (tester) async {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var starts = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            brightness: config.dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(config.scale),
                disableAnimations: true),
            child: child!),
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: routine,
            onStartFree: () => starts++,
            onOpenPrograms: () {},
            routes: WorkoutPrepRoutes(
                tutorialBuilder: (_, exercise) => Scaffold(
                    appBar: AppBar(),
                    body: Text('${exercise.name} instructions')))),
      ));
      await tester.pumpAndSettle();
      final start = find.text('Start workout');
      if (config.scale == 1 && config.size.height > 800) {
        expect(tester.getBottomRight(start).dy, lessThan(500));
      }
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      expect(starts, 1);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Movement 1'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movement 1'));
      await tester.pumpAndSettle();
      expect(find.text('Movement 1 instructions'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Equipment'), 200);
      expect(tester.takeException(), isNull);
    });
  }
}
