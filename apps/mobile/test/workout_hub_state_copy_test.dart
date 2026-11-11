import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_attempt.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'package:gainpath_mobile/navigation/workout_navigation.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  final routine = PublishedRoutine(
      id: 'manual',
      sourceBlueprintId: 'source',
      title: 'Foundations',
      estimatedMinutes: 15,
      exercises: const [
        PublishedRoutineExercise(
            exerciseId: 'manual',
            dayNumber: 1,
            name: 'Manual movement',
            category: 'Strength',
            sets: 2,
            reps: 8,
            cue: '',
            imageUrl: '',
            muscleGroup: '')
      ]);
  for (final completed in [false, true]) {
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets(
          'hub uses durable completed=$completed copy at $width and double text',
          (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = MemoryJourneyStore(scope);
        final repository = WorkoutSessionRepository(
            scope: scope,
            store: InMemoryWorkoutSessionStore(scope: scope),
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => scope);
        final c = RoutineJourneyController(
            scope: scope,
            activeScope: () => scope,
            routine: routine,
            store: store,
            workouts: repository,
            newId: () => 'attempt');
        await c.openDay(1);
        await c.markManualSet(0);
        if (completed) await c.markManualSet(0);
        await c.finish();
        final attempt = WorkoutHubAttempt.fromCheckpoints(
            scope: scope, routine: routine, checkpoints: await store.load());
        var settings = 0, progressOpens = 0, historyOpens = 0;
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    padding: const EdgeInsets.only(bottom: 24)),
                child: child!),
            home: WorkoutPrepScreen(
                live: true,
                publishedRoutine: routine,
                routes: WorkoutPrepRoutes(
                    journeyBuilder: (_, __) => const SizedBox()),
                freeAttempt: attempt,
                onStartFree: () {},
                onOpenProgress: () => progressOpens++,
                onOpenRoutineHistory: () => historyOpens++,
                onOpenSettings: () => settings++)));
        await tester.pumpAndSettle();
        final progress = tester.widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('workout-progress-ring')));
        expect(progress.value, 0);
        expect(find.text('0 / 1'), findsOneWidget);
        expect(
            find.text(
                completed ? 'Start workout' : 'Resume Unfinished Exercises'),
            findsOneWidget);
        await tester.tap(find.byTooltip('Workout settings'));
        expect(settings, 1);
        await tester.tap(find.text('Progress'));
        await tester.tap(find.text('Routine history'));
        expect(progressOpens, 1);
        expect(historyOpens, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        repository.dispose();
      });
    }
  }
  testWidgets(
      'recovery action and support copy consistently point to the schedule',
      (tester) async {
    var schedules = 0;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: routine,
            routes:
                WorkoutPrepRoutes(journeyBuilder: (_, __) => const SizedBox()),
            scheduledWorkout: ScheduledWorkoutPreview(
                routine: routine,
                day: 1,
                dayKey: 'day',
                enrollmentId: 'e',
                date: DateTime.utc(2026, 11, 9),
                snapshot: 's',
                inProgress: false),
            recoveryDayLabel: 'Rest day today',
            onOpenPrograms: () => schedules++)));
    await tester.pumpAndSettle();
    expect(find.text('Available in your schedule'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
    await tester.tap(find.text('View Training Schedule'));
    expect(schedules, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unstarted scheduled card never borrows free workout progress',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: routine,
            freeAttempt: const WorkoutHubAttempt(total: 9),
            scheduledWorkout: ScheduledWorkoutPreview(
                routine: routine,
                day: 1,
                dayKey: 'day',
                enrollmentId: 'e',
                date: DateTime.utc(2026, 11, 9),
                snapshot: 's',
                inProgress: false),
            onStartScheduled: () {})));
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('0 / 9'), findsNothing);
  });
  testWidgets('start and Training plan precede the exercise list at 320dp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: WorkoutPrepScreen(
            live: true,
            publishedRoutine: routine,
            onStartFree: () {},
            onOpenPrograms: () {},
            onOpenProgress: () {},
            onOpenRoutineHistory: () {})));
    expect(find.text('Start workout').hitTestable(), findsOneWidget);
    expect(find.text('Training plan').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your exercises'), 100);
    await tester.ensureVisible(find.text('Your exercises'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Your exercises')).dy, lessThan(640));
  });
}
