import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/guided_timed_workout_route.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/guided_timed_workout_screen.dart';
import 'package:gainpath_mobile/features/workout/application/guided_timed_workout_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_domain/workout.dart';
import 'guided_timed_workout_controller_test.dart' show Player;

void main() {
  testWidgets('timed controls remain visible on a small screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GuidedTimedWorkoutController(
        progress: GuidedTimedProgress(
            runId: 'r',
            entryId: 'e',
            entryIndex: 0,
            exerciseId: 'x',
            prescription: const TimedPrescription(
                sets: 3, durationSeconds: 45, restSeconds: 30),
            mediaIdentity: 'v',
            updatedAt: DateTime.now().toUtc()),
        player: Player(),
        activeScope: () => true,
        persist: (_) async {});
    await c.initialize();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: GuidedTimedWorkoutScreen(
            controller: c,
            exerciseName: 'Long timed exercise title',
            onBack: () async {},
            onSkip: () async {},
            onCompleted: () {})));
    expect(tester.takeException(), isNull);
    final start = find.text('Start Timed Workout');
    expect(tester.getRect(start).bottom, lessThanOrEqualTo(616));
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(tester.getRect(find.text('Resume')).bottom, lessThanOrEqualTo(616));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('camera-free timer displays truthful target and explicit start',
      (tester) async {
    final c = GuidedTimedWorkoutController(
        progress: GuidedTimedProgress(
            runId: 'r',
            entryId: 'e',
            entryIndex: 0,
            exerciseId: 'x',
            prescription:
                TimedPrescription(sets: 3, durationSeconds: 45, restSeconds: 0),
            mediaIdentity: 'v',
            updatedAt: DateTime.now().toUtc()),
        player: Player(),
        activeScope: () => true,
        persist: (_) async {});
    await c.initialize();
    await tester.pumpWidget(MaterialApp(
        home: GuidedTimedWorkoutScreen(
            controller: c,
            exerciseName: 'Stretch',
            onBack: () async {},
            onSkip: () async {},
            onCompleted: () {})));
    expect(find.text('Not AI verified'), findsOneWidget);
    expect(find.text('Start Timed Workout'), findsOneWidget);
    expect(find.textContaining('0/3 sets'), findsOneWidget);
    await tester.tap(find.text('Start Timed Workout'));
    await tester.pump();
    expect(c.progress.phase, GuidedTimedPhase.working);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('scoped route never opens capture and releases video on logout',
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
    final player = Player();
    var writes = 0;
    const e = PublishedRoutineExercise(
        exerciseId: 'stretch',
        entryId: 'entry',
        dayNumber: 1,
        name: 'Stretch',
        category: 'Mobility',
        sets: 1,
        reps: null,
        cue: '',
        imageUrl: '',
        muscleGroup: '',
        durationSeconds: 45,
        restSeconds: 0,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        videoUrl: 'https://media.example.test/v.mp4',
        mediaRevision: 1,
        mediaGeneration: 'g');
    const routine = PublishedRoutine(
        id: 'routine',
        sourceBlueprintId: 'blueprint',
        title: 'Timer',
        estimatedMinutes: 1,
        exercises: [e],
        schemaVersion: 2);
    final progress = GuidedTimedProgress(
        runId: 'run',
        entryId: 'entry',
        entryIndex: 0,
        exerciseId: 'stretch',
        prescription:
            TimedPrescription(sets: 1, durationSeconds: 45, restSeconds: 0),
        mediaIdentity: guidedTimedMediaIdentity(
            videoUrl: e.videoUrl!, mediaRevision: 1, mediaGeneration: 'g'),
        updatedAt: DateTime.now().toUtc());
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: GuidedTimedWorkoutRoute(
                scope: auth.state.session!.scope,
                routine: routine,
                exerciseIndex: 0,
                progress: progress,
                monotonicNow: () => Duration.zero,
                persist: (_) async {
                  writes++;
                },
                playerFactory: (_) => player))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Start Timed Workout'), findsOneWidget);
    await tester.tap(find.text('Start Timed Workout'));
    await tester.pump();
    expect(player.playing, true);
    // Playback can start before the initial durable save finishes. Wait for
    // the visible back control to become enabled instead of tapping it busy.
    for (var frame = 0;
        frame < 10 &&
            tester
                    .widget<IconButton>(find.byWidgetPredicate((widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Back to routine'))
                    .onPressed ==
                null;
        frame++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Back to routine'))
            .onPressed,
        isNotNull);
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is IconButton && widget.tooltip == 'Back to routine'));
    await tester.pumpAndSettle();
    expect(find.text('Save progress & exit'), findsOneWidget);
    expect(player.playing, false);
    await tester.tap(find.text('Return to paused workout'));
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    final before = writes;
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pump();
    expect(player.released, true);
    expect(writes, before);
    expect(find.text('This workout is no longer available for this account.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
}
