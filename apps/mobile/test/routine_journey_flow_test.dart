import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_journey_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/infrastructure/local/file_routine_journey_store.dart';
import 'routine_journey_controller_test.dart' as support;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');

  testWidgets(
      'preparation without an installed tracker opens instructions before consent',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream
          .firstWhere((state) => state.status == AuthStatus.signedIn);
    });
    var captured = false;
    String? tutorialId;
    await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(
          home: WorkoutPrepScreen(
        live: true,
        publishedRoutine: support.routineFixture(),
        trackers: const ExerciseTrackerDispatcher(availableTrackers: {}),
        routes: WorkoutPrepRoutes(
          realSessionBuilder: (_, launch) {
            captured = true;
            return const SizedBox();
          },
          tutorialBuilder: (_, exercise) {
            tutorialId = exercise.exerciseId;
            return const Scaffold(body: Text('Selected exercise instructions'));
          },
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start guided session'), 200);
    await tester.tap(find.text('Start guided session'));
    await tester.pumpAndSettle();
    expect(tutorialId, 'F3b8xIr8ynBDd3gEICKX');
    expect(find.text('Selected exercise instructions'), findsOneWidget);
    expect(find.text('Before we turn on the camera'), findsNothing);
    expect(captured, false);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });

  testWidgets(
      'unavailable tracker offers manual sets and resumes without measured results',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = support.MemoryJourneyStore(scope);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    var id = 0, captures = 0;
    RoutineJourneyController controller() => RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: support.routineFixture(),
        store: store,
        workouts: workouts,
        newId: () => 'id-${id++}',
        trackers: const ExerciseTrackerDispatcher(availableTrackers: {}));
    var c = controller();
    await c.openLatest();
    await tester.pumpWidget(MaterialApp(
        home: RoutineJourneyScreen(
            controller: c,
            onTrack: (_) async {
              captures++;
            },
            onTutorial: (_) async {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI tracking is unavailable'), findsOneWidget);
    expect(find.text('Start guided exercise'), findsNothing);
    await expectLater(c.prepareCapture(0), throwsStateError);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(c.manualSetsFor(0), 1);
    expect(c.fullRepetitions, 0);
    expect(c.measuredSessions, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    c = controller();
    await c.openLatest();
    expect(c.manualSetsFor(0), 1);
    expect(c.measuredSessions, isEmpty);
    expect(c.trackedDurationMicros, 0);
    expect(captures, 0);
    expect(await workouts.loadHistory(), isEmpty);
    c.dispose();
    workouts.dispose();
  });

  testWidgets(
      'normal preparation opens an instructional-only routine before camera consent',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream
          .firstWhere((state) => state.status == AuthStatus.signedIn);
    });
    final routine = PublishedRoutine(
        id: 'instructional',
        sourceBlueprintId: 'source',
        title: 'Press day',
        estimatedMinutes: 10,
        exercises: [support.routineFixture().exercises[1]]);
    String? selected;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: WorkoutPrepScreen(
                live: true,
                publishedRoutine: routine,
                routes: WorkoutPrepRoutes(journeyBuilder: (_, routine) {
                  selected = routine.id;
                  return const Scaffold(
                      body: Center(child: Text('Routine journey opened')));
                })))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start guided session'), 200);
    await tester.tap(find.text('Start guided session'));
    await tester.pumpAndSettle();
    expect(selected, 'instructional');
    expect(find.text('Routine journey opened'), findsOneWidget);
    expect(find.text('Before we turn on the camera'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });

  testWidgets(
      'routine selects, tracks, reviews unsupported exercise, summarizes and resumes after reopening',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = support.MemoryJourneyStore(scope);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    var id = 0, tutorials = 0, captures = 0;
    RoutineJourneyController makeController() => RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: support.routineFixture(),
        store: store,
        workouts: workouts,
        newId: () => 'capture-${id++}');
    var c = makeController();
    await c.openDay(1);
    Future<void> mount() => tester.pumpWidget(MaterialApp(
        home: RoutineJourneyScreen(
            controller: c,
            onTutorial: (_) async {
              tutorials++;
            },
            onTrack: (index) async {
              captures++;
              final capture = await c.prepareCapture(index);
              await workouts.saveLocal(support.measured(scope, capture));
              await c.refresh();
            })));
    await mount();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start guided exercise'), 200);
    await tester.tap(find.text('Start guided exercise'));
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(c.selectedIndex, 1);
    await tester.scrollUntilVisible(find.text('Watch exercise tutorial'), 150);
    await tester.tap(find.text('Watch exercise tutorial'));
    await tester.pumpAndSettle();
    expect(tutorials, 1);
    expect(find.textContaining('Guided only ·'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Mark instructions reviewed'), 150);
    await tester.tap(find.text('Mark instructions reviewed'));
    await tester.pumpAndSettle();
    expect(c.manualSetsFor(1), 0);
    for (var set = 1; set <= 2; set++) {
      await tester.scrollUntilVisible(find.text('Mark set $set done'), -150);
      await tester.tap(find.text('Mark set $set done'));
      await tester.pumpAndSettle();
    }
    expect(c.fullRepetitions, 2);
    // Finishing the last target now opens the summary without another gate.
    expect(find.text('Routine summary'), findsOneWidget);
    expect(find.text('2 full reps · 1 partial reps'), findsOneWidget);
    expect(find.textContaining('Self-reported sets complete'), findsOneWidget);
    expect(find.text('2 self-reported sets · separate from AI measurements'),
        findsOneWidget);
    expect(c.checkpoint!.finished, true);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    c = makeController();
    await c.openDay(1);
    await mount();
    await tester.pumpAndSettle();
    expect(find.text('Routine summary'), findsOneWidget);
    expect(c.fullRepetitions, 2);
    expect(c.manualSetsFor(1), 2);
    expect(captures, 1);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    workouts.dispose();
  });

  testWidgets(
      'measured result returns to routine using the supplied continuation',
      (tester) async {
    var continued = false;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutResultScreen.measured(
            summary: support.measured(scope, 'one'),
            continueLabel: 'Continue routine',
            onContinue: () => continued = true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue routine'), 200);
    await tester.tap(find.text('Continue routine'));
    await tester.pump();
    expect(continued, true);
  });

  test(
      'file checkpoints survive reopen, preserve earlier attempts and isolate accounts',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-routine-test-');
    try {
      final fileStore =
          FileRoutineJourneyStore(directory: directory, scope: scope);
      final workouts = WorkoutSessionRepository(
          scope: scope,
          store: InMemoryWorkoutSessionStore(scope: scope),
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      var id = 0;
      final c = RoutineJourneyController(
          scope: scope,
          activeScope: () => scope,
          routine: support.routineFixture(),
          store: fileStore,
          workouts: workouts,
          newId: () => 'id-${id++}');
      await c.openDay(1);
      await c.reviewInstructions(1);
      await c.markManualSet(1);
      await c.startNewAttempt();
      final reopened =
          FileRoutineJourneyStore(directory: directory, scope: scope);
      final checkpoints = await reopened.load();
      expect(checkpoints.length, 2);
      expect(checkpoints.where((e) => e.reviewed.contains(1)).length, 1);
      expect(checkpoints.where((e) => e.manualSets[1] == 1).length, 1);
      expect(
          await FileRoutineJourneyStore(
                  directory: directory,
                  scope: SessionScope(
                      userId: 'different', organizationId: 'gainpath'))
              .load(),
          isEmpty);
      c.dispose();
      workouts.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
