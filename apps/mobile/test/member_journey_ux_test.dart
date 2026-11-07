import 'package:flutter/material.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'workout_preferences_test.dart' show MemoryWorkoutPreferencesStore;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_exercise_tutorial_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'published_tutorial_test.dart' show row, FakePlayer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/routine_journey_route.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'routine_journey_controller_test.dart'
    show MemoryJourneyStore, routineFixture;
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_journey_screen.dart';
import 'hybrid_routine_journey_test.dart' show hybridFixture;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('manual tutorial opens the same set logger without awarding work',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope,
        store = MemoryJourneyStore(auth.state.session!.scope);
    final workouts = InMemoryWorkoutSessionStore(scope: scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: RoutineJourneyRoute(
                scope: scope,
                routine: routineFixture(),
                preferencesFactory: (s) async => WorkoutPreferencesController(
                    scope: s, store: MemoryWorkoutPreferencesStore()),
                storeFactory: (_) async => store,
                workoutStoreFactory: (_) async => workouts))));
    await tester.pumpAndSettle();
    final initialId = store.records.keys.single;
    await tester.tap(find.text('Press').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Set Logger'));
    await tester.pumpAndSettle();
    expect(find.text('Mark set 1 done'), findsOneWidget);
    expect(store.records.keys.single, initialId);
    expect(store.records.values.single.selectedIndex, 1);
    expect(store.records.values.single.manualSets, isEmpty);
    expect(await workouts.read(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets('journey action stays reachable with large text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final workouts = WorkoutSessionRepository(
        scope: scope,
        activeScope: () => scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway());
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: routineFixture(),
        store: MemoryJourneyStore(scope),
        workouts: workouts,
        newId: () => 'small');
    await c.openDay(1);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: RoutineJourneyScreen(
            controller: c,
            onTrack: (_) async {
              starts++;
            },
            onTutorial: (_) async {})));
    expect(tester.takeException(), isNull);
    final start = find.text('Start AI Workout');
    expect(tester.getRect(start).bottom, lessThanOrEqualTo(616));
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    workouts.dispose();
  });
  testWidgets(
      'timer and manual completion show success without invented AI totals',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final base = hybridFixture();
    final routine = PublishedRoutine(
        id: base.id,
        sourceBlueprintId: base.sourceBlueprintId,
        title: 'Timed and manual',
        estimatedMinutes: 10,
        schemaVersion: 2,
        exercises: [
          base.exercises[1],
          const PublishedRoutineExercise(
              exerciseId: 'manual',
              entryId: 'manual',
              dayNumber: 1,
              name: 'Manual movement',
              category: 'Mobility',
              sets: 1,
              reps: 8,
              cue: '',
              imageUrl: '',
              muscleGroup: '',
              restSeconds: 0,
              executionMode: ExerciseExecutionMode.legacyManual)
        ]);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        activeScope: () => scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway());
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: routine,
        store: MemoryJourneyStore(scope),
        workouts: workouts,
        newId: () => 'complete');
    await c.openDay(1);
    final g = await c.prepareGuidedSession(0), now = DateTime.now().toUtc();
    await c.saveGuidedProgress(
        0,
        g.copyWith(
            startedAt: now.subtract(const Duration(seconds: 100)),
            updatedAt: now,
            endedAt: now,
            phase: GuidedTimedPhase.completed,
            completedSetActiveMicroseconds: [45000000, 45000000]));
    await c.markManualSet(1);
    await c.finish();
    await tester.pumpWidget(MaterialApp(
        home: RoutineJourneyScreen(
            controller: c, onTrack: (_) async {}, onTutorial: (_) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Workout Completed'), findsOneWidget);
    expect(find.textContaining('full reps'), findsNothing);
    for (final name in ['Mobility', 'Manual movement']) {
      await tester.scrollUntilVisible(find.text(name), 150);
      final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(name), matching: find.byType(ListTile)));
      expect((tile.leading as Icon).icon, Icons.check_circle_rounded);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    workouts.dispose();
  });
  testWidgets(
      'active tutorial returns through consent in the same saved attempt',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope;
    final store = MemoryJourneyStore(scope);
    final workouts = InMemoryWorkoutSessionStore(scope: scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: RoutineJourneyRoute(
                scope: scope,
                routine: routineFixture(),
                preferencesFactory: (s) async => WorkoutPreferencesController(
                    scope: s, store: MemoryWorkoutPreferencesStore()),
                storeFactory: (_) async => store,
                workoutStoreFactory: (_) async => workouts))));
    await tester.pumpAndSettle();
    final initialId = store.records.keys.single;
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Exercise'));
    await tester.pumpAndSettle();
    expect(find.text('AI Tracking privacy'), findsOneWidget);
    expect(store.records.keys.single, initialId);
    expect(store.records.values.single.selectedIndex, 0);
    expect(await workouts.read(), isEmpty);
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(store.records.keys.single, initialId);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
  testWidgets(
      'preview has no execution action; active tutorial anchors its action',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    Widget screen({VoidCallback? start}) => MaterialApp(
        home: PublishedExerciseTutorialScreen(
            exercise: row(),
            playerFactory: (_) => FakePlayer(),
            onStart: start));
    await tester.pumpWidget(screen());
    expect(find.text('Start Exercise'), findsNothing);
    await tester.pumpWidget(screen(start: () => starts++));
    await tester.pumpAndSettle();
    expect(
        find.ancestor(
            of: find.text('Start Exercise'), matching: find.byType(SafeArea)),
        findsWidgets);
    await tester.tap(find.text('Start Exercise'));
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });
}
