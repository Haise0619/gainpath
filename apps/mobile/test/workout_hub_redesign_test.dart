import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_hub_visuals.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';

PublishedRoutine hubRoutine([String id = 'free']) => PublishedRoutine(
    id: id,
    sourceBlueprintId: 'source',
    title: 'Strength foundations $id',
    estimatedMinutes: 20,
    exercises: List.generate(
        6,
        (i) => PublishedRoutineExercise(
            exerciseId: 'exercise-$i',
            dayNumber: 1,
            name: i == 0
                ? 'Standing single-arm dumbbell curl'
                : 'Movement ${i + 1}',
            category: 'Strength',
            sets: 2,
            reps: 8,
            cue: '',
            imageUrl: '',
            muscleGroup: '')));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('hero separates plan and activity and omits initial progress',
      (t) async {
    var plan = 0, history = 0, progress = 0;
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: hubRoutine(),
            onStartFree: () {},
            onOpenPrograms: () => plan++,
            onOpenRoutineHistory: () => history++,
            onOpenProgress: () => progress++)));
    await t.pumpAndSettle();
    final hero = find.byType(WorkoutHubOverview);
    expect(find.descendant(of: hero, matching: find.text('Training Plan')),
        findsNothing);
    expect(find.descendant(of: hero, matching: find.text('Progress')),
        findsNothing);
    expect(
        find.descendant(
            of: hero, matching: find.byType(CircularProgressIndicator)),
        findsNothing);
    await t.scrollUntilVisible(find.text('Explore programs'), 180);
    await t.pumpAndSettle();
    await t.tap(find.text('Explore programs'));
    await t.scrollUntilVisible(find.text('History'), 180);
    await t.pumpAndSettle();
    await t.tap(find.text('History'));
    await t.tap(find.text('Progress'));
    expect([plan, history, progress], [1, 1, 1]);
  });
  testWidgets('exercise disclosure shows total and collapse retains its anchor',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true, publishedRoutine: hubRoutine(), onStartFree: () {})));
    await t.pumpAndSettle();
    expect(find.text('Movement 4'), findsNothing);
    await t.scrollUntilVisible(find.text('View all 6 exercises'), 150);
    await t.pumpAndSettle();
    await t.tap(find.text('View all 6 exercises'));
    await t.pumpAndSettle();
    expect(find.text('Movement 6'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Show fewer exercises'), 150);
    await t.pumpAndSettle();
    await t.tap(find.text('Show fewer exercises'));
    await t.pumpAndSettle();
    expect(find.text('Movement 4'), findsNothing);
    expect(find.text('Your exercises').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('rapid primary taps launch once', (t) async {
    var launches = 0;
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: hubRoutine(),
            onStartFree: () => launches++)));
    await t.pumpAndSettle();
    await t.tap(find.text('Start workout'));
    await t.tap(find.text('Start workout'));
    expect(launches, 1);
    await t.pumpAndSettle();
  });
  testWidgets('primary stays guarded throughout an asynchronous launch',
      (t) async {
    final gate = Completer<void>();
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: hubRoutine(),
            onStartFree: () {
              calls++;
              return gate.future;
            })));
    await t.pumpAndSettle();
    await t.tap(find.text('Start workout'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Start workout'));
    expect(calls, 1);
    gate.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('destination cards expose button role and action', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: hubRoutine(),
            onOpenPrograms: () {},
            onOpenProgress: () {})));
    await t.pumpAndSettle();
    final node = t.getSemantics(
        find.bySemanticsLabel(RegExp('Make room for your next goal')));
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
  testWidgets('exercise preview back navigation preserves hub scroll position',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: hubRoutine(),
            routes: WorkoutPrepRoutes(
                tutorialBuilder: (_, exercise) => Scaffold(
                    appBar: AppBar(),
                    body: Text('Preview ${exercise.name}'))))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Movement 3'));
    await t.pumpAndSettle();
    final position =
        t.state<ScrollableState>(find.byType(Scrollable).first).position;
    final offset = position.pixels;
    await t.tap(find.text('Movement 3'));
    await t.pumpAndSettle();
    expect(find.text('Preview Movement 3'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(position.pixels, closeTo(offset, 1));
    expect(find.text('Movement 3').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
