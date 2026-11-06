import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'routine_journey_controller_test.dart' show routineFixture;
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_exercise_image.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final routine = PublishedRoutine.fromDocument('private-routine-id', {
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'source',
    'title': 'Strength basics',
    'estimatedMinutes': 20,
    'exercises': [
      {
        'exerciseId': 'first-id',
        'name': 'Squat',
        'sets': 3,
        'reps': 8,
        'imageUrl':
            'https://firebasestorage.googleapis.com/v0/b/demo/o/squat.jpg'
      },
      {
        'exerciseId': 'second-id',
        'name': 'Shoulder press',
        'sets': 2,
        'reps': 10
      },
    ],
  });
  testWidgets('visual workout hub opens the tapped exercise, not the first one',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PublishedRoutineExercise? selected;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
      live: true,
      publishedRoutine: routine,
      routes: WorkoutPrepRoutes(tutorialBuilder: (_, exercise) {
        selected = exercise;
        return const Scaffold(body: Text('Exercise details'));
      }),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.textContaining('private-routine-id'), findsNothing);
    expect(
        find.byWidgetPredicate(
            (w) => w is WorkoutExerciseImage && w.url.contains('squat.jpg')),
        findsWidgets);
    await tester.scrollUntilVisible(find.text('Shoulder press'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Shoulder press'));
    await tester.pumpAndSettle();
    expect(selected?.exerciseId, 'second-id');
    expect(find.text('Exercise details'), findsOneWidget);
  });

  testWidgets(
      'change workout opens visual options without internal identifiers',
      (tester) async {
    final other = PublishedRoutine(
        id: 'private-other-id',
        sourceBlueprintId: 'source',
        title: 'Upper body',
        estimatedMinutes: 30,
        exercises: routine.exercises);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PublishedRoutineCatalogControls(
      state: PublishedRoutineCatalogState(
          status: CatalogStatus.ready,
          items: [routine, other],
          selected: routine),
      onRefresh: () async {},
      onSelect: (id) => selected = id,
      onLoadMore: () async {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workout'));
    await tester.pumpAndSettle();
    expect(find.text('Upper body'), findsOneWidget);
    expect(find.textContaining('private-'), findsNothing);
    await tester.tap(find.text('Upper body'));
    await tester.pumpAndSettle();
    expect(selected, 'private-other-id');
  });
  testWidgets('scheduled preview only shows the exercises for that day',
      (tester) async {
    final program = ScheduledWorkoutPreview(
        routine: routineFixture(),
        day: 2,
        dayKey: 'w1-d2',
        enrollmentId: 'e',
        date: DateTime.utc(2026, 11, 2),
        snapshot: 'snapshot',
        inProgress: true);
    var started = 0;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
      live: true,
      scheduledWorkout: program,
      onStartScheduled: () => started++,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Squat day two'), findsOneWidget);
    expect(find.text('Press'), findsNothing);
    expect(find.text('Continue workout'), findsOneWidget);
    expect(find.textContaining('about 10 min'), findsNothing);
    await tester.tap(find.text('Continue workout'));
    expect(started, 1);
  });
}
