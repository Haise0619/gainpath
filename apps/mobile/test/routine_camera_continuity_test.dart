import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_workout_context.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_next_exercise_sheet.dart';
import 'real_squat_session_test.dart' as support;
import 'squat_processing_controller_test.dart' as poses;
import 'routine_journey_controller_test.dart' as journey;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final failFirst in [false, true]) {
    testWidgets(
        'completed routine exercise saves and returns without manual result gates; disk failure=$failFirst',
        (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
      final camera = support.Camera(), detector = support.Detector();
      final store = support.FailingStore(scope: scope)..fail = failFirst;
      final repository = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      var now = 0;
      WorkoutSessionSummary? returned;
      final c = RealSquatSessionController(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: poses.AudioSink(),
          repository: repository,
          clockMicros: () => now,
          sessionId: 'routine-camera',
          exerciseId: 'squat',
          publishedRoutineId: 'routine',
          detectorId: 'fixture',
          detectorVersion: '1',
          provenance: WorkoutProvenance.recordedFixture,
          guidance: GuidedWorkoutProgress(sets: 1, repetitions: 1));
      await c.start(consented: true, setupConfirmed: true);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        returned = await Navigator.push<WorkoutSessionSummary>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RealWorkoutView(
                                    session: c,
                                    viewport:
                                        const ColoredBox(color: Colors.black),
                                    exerciseName: 'Squat',
                                    targetRepetitions: 1,
                                    routineContext: const RoutineWorkoutContext(
                                        routineTitle: 'Testing 2',
                                        day: 1,
                                        exerciseNumber: 1,
                                        totalExercises: 2,
                                        nextExerciseName: 'Curl'))));
                      },
                      child: const Text('Open exercise'))))));
      await tester.tap(find.text('Open exercise'));
      await tester.pumpAndSettle();
      Future<void> send(double angle) async {
        now += 100000;
        detector.angle = angle;
        camera.receive?.call(PoseInput(timestampMicros: now));
        await tester.pump();
      }

      for (var i = 0; i < 12; i++) {
        await send(175);
      }
      for (var i = 1; i <= 20; i++) {
        await send(175.0 - i * 5);
      }
      for (var i = 0; i < 8; i++) {
        await send(75);
      }
      for (var i = 1; i <= 20; i++) {
        await send(75.0 + i * 5);
      }
      for (var i = 0; i < 12; i++) {
        await send(175);
      }
      await tester.pumpAndSettle();
      if (failFirst) {
        expect(returned, isNull);
        expect(find.text('Retry save'), findsOneWidget);
        expect(await store.read(), isEmpty);
        store.fail = false;
        await tester.tap(find.text('Retry save'));
        await tester.pumpAndSettle();
      }
      expect(returned?.repetitions, 1);
      expect((await repository.loadHistory()).length, 1);
      expect(find.text('Open exercise'), findsOneWidget);
      expect(find.text('Save result'), findsNothing);
      c.dispose();
      repository.dispose();
    });
  }

  testWidgets(
      'next exercise sheet exposes targets, readiness and tutorial on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    RoutineNextAction? action;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      action = await showModalBottomSheet<RoutineNextAction>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => RoutineNextExerciseSheet(
                              previousExercise: 'Squat',
                              exercise: journey.routineFixture().exercises[1],
                              completedExercises: 1,
                              totalExercises: 2,
                              capabilityLabel: 'Guided only',
                              guidance: 'Follow the tutorial.'));
                    },
                    child: const Text('Next'))))));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('2 sets · 8 reps per set'), findsOneWidget);
    await tester.ensureVisible(find.text('Review tutorial'));
    await tester.tap(find.text('Review tutorial'));
    await tester.pumpAndSettle();
    expect(action, RoutineNextAction.tutorial);
  });
}
