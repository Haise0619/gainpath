import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/app/routing/guided_timed_workout_route.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'guided_timed_workout_controller_test.dart' show Player;

void main() {
  for (final (failSave, interrupted) in [
    (false, false),
    (true, false),
    (false, true)
  ]) {
    testWidgets(
        'automatic timed flow saves before returning; failSave=$failSave interrupted=$interrupted',
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
      final player = Player()..initialization = Completer<void>();
      var now = Duration.zero, saved = false;
      GuidedTimedWorkoutOutcome? outcome;
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
          durationSeconds: 5,
          restSeconds: 0,
          executionMode: ExerciseExecutionMode.videoGuidedTimed,
          videoUrl: 'https://media.example.test/v.mp4',
          mediaRevision: 1,
          mediaGeneration: 'g');
      const routine = PublishedRoutine(
          id: 'r',
          sourceBlueprintId: 'b',
          title: 'Timer',
          estimatedMinutes: 1,
          exercises: [e],
          schemaVersion: 2);
      final progress = GuidedTimedProgress(
          runId: 'run',
          entryId: 'entry',
          entryIndex: 0,
          exerciseId: 'stretch',
          prescription: const TimedPrescription(
              sets: 1, durationSeconds: 5, restSeconds: 0),
          mediaIdentity: guidedTimedMediaIdentity(
              videoUrl: e.videoUrl!, mediaRevision: 1, mediaGeneration: 'g'),
          updatedAt: DateTime.now().toUtc());
      await tester.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: FilledButton(
                          onPressed: () async {
                            outcome =
                                await Navigator.push<GuidedTimedWorkoutOutcome>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                            value: auth,
                                            child: GuidedTimedWorkoutRoute(
                                                scope:
                                                    auth.state.session!.scope,
                                                routine: routine,
                                                exerciseIndex: 0,
                                                progress: progress,
                                                autoStart: true,
                                                autoContinue: true,
                                                playerFactory: (_) => player,
                                                monotonicNow: () => now,
                                                utcNow: () =>
                                                    DateTime.utc(2026, 11, 7)
                                                        .add(now),
                                                persist: (p) async {
                                                  if (p.completed) {
                                                    if (failSave) {
                                                      throw StateError('disk');
                                                    }
                                                    saved = true;
                                                  }
                                                }))));
                          },
                          child: const Text('Open')))))));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      now = const Duration(seconds: 100);
      await tester.pump(const Duration(milliseconds: 200));
      expect(player.playing, isFalse);
      expect(saved, isFalse); // Loading earns no active time.
      if (interrupted) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      player.initialization!.complete();
      await tester.pumpAndSettle();
      if (interrupted) {
        expect(player.playing, isFalse);
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
      }
      expect(player.playing, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      now += const Duration(seconds: 5);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(saved, !failSave);
      expect(
          outcome,
          failSave || interrupted
              ? isNull
              : GuidedTimedWorkoutOutcome.completed);
      if (interrupted) {
        await tester.tap(find.text('Return to routine'));
        await tester.pumpAndSettle();
        expect(outcome, GuidedTimedWorkoutOutcome.completed);
      }
      if (failSave) expect(find.text('Paused'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(auth.close);
    });
  }
}
