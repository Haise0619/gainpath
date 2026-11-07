import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/routine_journey_route.dart';
import 'package:gainpath_mobile/app/routing/guided_timed_workout_route.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'routine_journey_controller_test.dart' as support;
import 'hybrid_routine_journey_test.dart' show hybridFixture;
import 'guided_timed_workout_controller_test.dart' show Player;
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'workout_preferences_test.dart' show MemoryWorkoutPreferencesStore;

class FailingJourneyStore extends MemoryJourneyStore {
  FailingJourneyStore(super.scope);
  bool failWrites = false;
  @override
  Future<void> save(RoutineCheckpoint value) async {
    if (failWrites) throw StateError('disk unavailable');
    await super.save(value);
  }
}

class DelayedPrepareStore extends MemoryJourneyStore {
  DelayedPrepareStore(super.scope);
  final gate = Completer<void>();
  bool waiting = false;
  @override
  Future<void> save(RoutineCheckpoint value) async {
    if (value.guidedProgress.isNotEmpty) {
      waiting = true;
      await gate.future;
    }
    await super.save(value);
  }
}

class DelayedManualStore extends MemoryJourneyStore {
  DelayedManualStore(super.scope);
  final gate = Completer<void>();
  bool waiting = false;
  @override
  Future<void> save(RoutineCheckpoint value) async {
    if (value.manualSets.isNotEmpty) {
      waiting = true;
      await gate.future;
    }
    await super.save(value);
  }
}

PublishedRoutine manualRoutine() =>
    PublishedRoutine.fromDocument('manual-routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'manual-source',
      'title': 'Manual routine',
      'estimatedMinutes': 5,
      'exercises': [
        {
          'exerciseId': 'manual-one',
          'name': 'First movement',
          'sets': 1,
          'reps': 5
        },
        {
          'exerciseId': 'manual-two',
          'name': 'Second movement',
          'sets': 1,
          'reps': 8
        },
      ],
    });

Future<AuthBloc> signedIn(WidgetTester tester) async {
  late AuthBloc auth;
  await tester.runAsync(() async {
    auth = AuthBloc(
        repository: InMemoryAuthRepository(organizationId: 'gainpath'));
    await Future<void>.delayed(Duration.zero);
    auth.add(const LoginSubmitted(
        email: 'member@example.com', password: 'password123'));
    await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
  });
  return auth;
}

Future<void> openRoutine(
    WidgetTester tester,
    AuthBloc auth,
    MemoryJourneyStore store,
    WorkoutPreferencesController preferences,
    InMemoryWorkoutSessionStore workouts) async {
  await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(
          home: RoutineJourneyRoute(
              scope: auth.state.session!.scope,
              routine: manualRoutine(),
              preferencesFactory: (_) async => preferences,
              storeFactory: (_) async => store,
              workoutStoreFactory: (_) async => workouts))));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'background and return during manual save preserve saved work without opening rest',
      (tester) async {
    final auth = await signedIn(tester), scope = auth.state.session!.scope;
    final store = DelayedManualStore(scope),
        workouts = InMemoryWorkoutSessionStore(scope: scope);
    final preferences = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await openRoutine(tester, auth, store, preferences, workouts);
    final id = store.records.keys.single;
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pump();
    expect(store.waiting, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    store.gate.complete();
    await tester.pumpAndSettle();
    expect(store.records.keys.single, id);
    expect(store.records.values.single.manualSets, {0: 1});
    expect(store.records.values.single.selectedIndex, 1);
    expect(find.text('Skip Rest'), findsNothing);
    expect(find.text('Progress saved on this device'), findsNothing);
    expect(find.text('Mark set 1 done'), findsOneWidget);
    expect(await workouts.read(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });

  for (final background in [true, false]) {
    testWidgets(
        'delayed prepare cannot launch after ${background ? 'backgrounding' : 'route obscuring'}',
        (tester) async {
      final auth = await signedIn(tester), scope = auth.state.session!.scope;
      final store = DelayedPrepareStore(scope);
      final workouts = InMemoryWorkoutSessionStore(scope: scope);
      final preferences = WorkoutPreferencesController(
          scope: scope, store: MemoryWorkoutPreferencesStore());
      var playersCreated = 0;
      final nav = GlobalKey<NavigatorState>();
      final base = hybridFixture();
      final routine = PublishedRoutine(
          id: base.id,
          sourceBlueprintId: base.sourceBlueprintId,
          title: 'Delayed timer',
          estimatedMinutes: 1,
          schemaVersion: 2,
          exercises: [base.exercises[1]]);
      await tester.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              navigatorKey: nav,
              home: RoutineJourneyRoute(
                  scope: scope,
                  routine: routine,
                  storeFactory: (_) async => store,
                  workoutStoreFactory: (_) async => workouts,
                  preferencesFactory: (_) async => preferences,
                  timedPlayerFactory: (_) {
                    playersCreated++;
                    return Player();
                  }))));
      await tester.pumpAndSettle();
      final id = store.records.keys.single;
      await tester.tap(find.text('Start Timed Workout'));
      await tester.pump();
      expect(store.waiting, isTrue);
      if (background) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // Returning before the disk write completes must not restore an old
        // automatic launch intent without a new explicit action.
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        unawaited(nav.currentState!.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Unrelated screen')))));
        await tester.pumpAndSettle();
      }
      store.gate.complete();
      await tester.pumpAndSettle();
      expect(playersCreated, 0);
      expect(find.byType(GuidedTimedWorkoutRoute), findsNothing);
      expect(store.records.keys.single, id);
      expect(store.records.values.single.guidedProgress.values.single.startedAt,
          isNull);
      if (background) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        nav.currentState!.pop();
      }
      await tester.pumpAndSettle();
      expect(playersCreated, 0);
      expect(find.byType(GuidedTimedWorkoutRoute), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(auth.close);
    });
  }

  for (final nextTimed in [false, true]) {
    testWidgets(
        'durably saved AI exercise proceeds to ${nextTimed ? 'timed' : 'AI'} after rest in the same attempt',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = await signedIn(tester), scope = auth.state.session!.scope;
      final store = MemoryJourneyStore(scope),
          workouts = InMemoryWorkoutSessionStore(scope: scope);
      final preferences = WorkoutPreferencesController(
          scope: scope, store: MemoryWorkoutPreferencesStore());
      await preferences.grantConsent();
      final base = hybridFixture();
      final next = nextTimed
          ? base.exercises[1]
          : const PublishedRoutineExercise(
              exerciseId: 'standing-lateral-raise-front-v1',
              entryId: 'raise',
              dayNumber: 1,
              name: 'Standing lateral raise',
              category: '',
              sets: 1,
              reps: 2,
              cue: '',
              imageUrl: '',
              muscleGroup: '');
      final routine = PublishedRoutine(
          id: 'routine',
          sourceBlueprintId: 'blueprint',
          title: 'Continuous routine',
          estimatedMinutes: 5,
          schemaVersion: 2,
          exercises: [base.exercises.first, next]);
      final launches = <RealWorkoutLaunch>[];
      final player = Player();
      await tester.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              home: RoutineJourneyRoute(
                  scope: scope,
                  routine: routine,
                  storeFactory: (_) async => store,
                  workoutStoreFactory: (_) async => workouts,
                  preferencesFactory: (_) async => preferences,
                  timedPlayerFactory: (_) => player,
                  measuredBuilder: (launch) {
                    if (!launches
                        .any((item) => item.sessionId == launch.sessionId)) {
                      launches.add(launch);
                    }
                    return Builder(
                        builder: (context) => Scaffold(
                            body: FilledButton(
                                onPressed: () async {
                                  final result = support.measured(
                                      scope, launch.sessionId!);
                                  final repository = WorkoutSessionRepository(
                                      scope: scope,
                                      store: workouts,
                                      activeScope: () =>
                                          auth.state.session?.scope,
                                      uploadGateway:
                                          UnavailableWorkoutUploadGateway());
                                  await repository.saveLocal(result);
                                  repository.dispose();
                                  if (context.mounted) {
                                    Navigator.pop(context, result);
                                  }
                                },
                                child:
                                    const Text('Persist measured fixture'))));
                  }))));
      await tester.pumpAndSettle();
      final id = store.records.keys.single;
      await tester.tap(find.text('Start AI Workout'));
      // The active journey owns an intentional busy spinner behind the modal.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('AI Tracking privacy'), findsNothing);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.text('Ready to continue'));
      await tester.pumpAndSettle();
      expect(launches.length, 1);
      await tester.tap(find.text('Persist measured fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Progress saved on this device'), findsOneWidget);
      expect((await workouts.read()).length, 1);
      expect(
          store.records.values.single.sessions[0], [launches.first.sessionId]);
      await tester.tap(find.text('Skip Rest'));
      await tester.pumpAndSettle();
      expect(store.records.keys.single, id);
      expect(store.records.values.single.selectedIndex, 1);
      expect(find.text('AI Tracking privacy'), findsNothing);
      if (nextTimed) {
        expect(find.byType(GuidedTimedWorkoutRoute), findsOneWidget);
        expect(player.playing, isTrue);
        expect(launches.length, 1);
      } else {
        expect(launches.length, 2);
        expect(launches.last.exercise.exerciseId, next.exerciseId);
        expect(launches.last.sessionId, isNot(launches.first.sessionId));
        expect(launches.last.routineId, 'routine');
        expect(launches.last.routineContext!.day, 1);
        expect(launches.last.consentCurrent!(), isTrue);
      }
      expect((await workouts.read()).length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(auth.close);
    });
  }

  testWidgets(
      'saved manual completion enters rest; pause and skip retain the same attempt and require next manual logging',
      (tester) async {
    final auth = await signedIn(tester), scope = auth.state.session!.scope;
    final store = MemoryJourneyStore(scope),
        workouts = InMemoryWorkoutSessionStore(scope: scope);
    final preferences = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await openRoutine(tester, auth, store, preferences, workouts);
    final id = store.records.keys.single;
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(find.text('Progress saved on this device'), findsOneWidget);
    expect(store.records.values.single.manualSets, {0: 1});
    expect(store.records.values.single.selectedIndex, 1);
    await tester.tap(find.text('Pause Workout'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 40));
    expect(find.text('Workout paused'), findsOneWidget);
    expect(store.records.values.single.manualSets, {0: 1});
    await tester.tap(find.text('Skip Rest'));
    await tester.pumpAndSettle();
    expect(find.text('Mark set 1 done'), findsOneWidget);
    expect(store.records.keys.single, id);
    expect(store.records.values.single.manualSets, {0: 1});
    expect(await workouts.read(), isEmpty);
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(store.records.keys.single, id);
    expect(store.records.values.single.manualSets, {0: 1, 1: 1});
    expect(store.records.values.single.finished, isTrue);
    expect(find.text('Routine summary'), findsOneWidget);
    expect(find.text('Pause Workout'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });

  testWidgets('disabled Auto-Continue retains the explicit next-exercise sheet',
      (tester) async {
    final auth = await signedIn(tester), scope = auth.state.session!.scope;
    final store = MemoryJourneyStore(scope),
        workouts = InMemoryWorkoutSessionStore(scope: scope);
    final preferences = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await preferences.updatePreferences(autoContinue: false);
    await openRoutine(tester, auth, store, preferences, workouts);
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(find.text('Start next exercise'), findsOneWidget);
    expect(find.text('Skip Rest'), findsNothing);
    expect(store.records.values.single.manualSets, {0: 1});
    await tester.tap(find.text('Back to routine'));
    await tester.pumpAndSettle();
    expect(store.records.values.single.manualSets, {0: 1});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });

  testWidgets(
      'failed manual save cannot enter rest or create a duplicate attempt',
      (tester) async {
    final auth = await signedIn(tester), scope = auth.state.session!.scope;
    final store = FailingJourneyStore(scope),
        workouts = InMemoryWorkoutSessionStore(scope: scope);
    final preferences = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await openRoutine(tester, auth, store, preferences, workouts);
    final id = store.records.keys.single;
    store.failWrites = true;
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(find.text('Progress saved on this device'), findsNothing);
    expect(find.text('Skip Rest'), findsNothing);
    expect(store.records.keys.single, id);
    expect(store.records.values.single.manualSets, isEmpty);
    expect(store.records.values.single.selectedIndex, 0);
    expect(await workouts.read(), isEmpty);
    store.failWrites = false;
    await tester.tap(find.text('Mark set 1 done'));
    await tester.pumpAndSettle();
    expect(find.text('Progress saved on this device'), findsOneWidget);
    expect(store.records.values.single.manualSets, {0: 1});
    expect(store.records.keys.single, id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
}
