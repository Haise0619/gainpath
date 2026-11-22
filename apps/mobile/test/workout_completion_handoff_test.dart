import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_workout_context.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'support/replay_pose_detector.dart';
import 'retained_voice_boundary_test.dart' show trajectory;
import 'coach_workout_audio_test.dart' show CoachAudio;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final routine in [false, true]) {
    for (final voice in [
      'speech',
      'muted',
      'unavailable',
      if (!routine) 'disposed',
      if (routine) 'background',
      if (routine) 'intermediate',
      if (routine) 'out-of-order',
      if (routine) 'last-remaining',
    ]) {
      testWidgets(
          '${routine ? 'Routine' : 'Single'} $voice waits for celebration and spoken completion',
          (tester) async {
        final effects = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        const channel = MethodChannel('gainpath/sound_effects');
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'play') return null;
          effects.add(call.arguments as String);
          return voice == 'speech' && call.arguments == 'workoutComplete'
              ? 480
              : 0;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final scope =
            SessionScope(userId: 'completion', organizationId: 'gainpath');
        final store = FailingStore(scope: scope)..fail = false;
        final repo = WorkoutSessionRepository(
            scope: scope,
            store: store,
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => scope);
        final camera = Camera(),
            detector = ReplayPoseDetector(),
            port = CoachAudio();
        port.failPlay = voice == 'unavailable';
        var now = 0;
        final frames = await trajectory('squat');
        final session = RealSquatSessionController(
            scope: scope,
            activeScope: () => scope,
            camera: camera,
            detectorFactory: () async => detector,
            audioPort: port,
            repository: repo,
            clockMicros: () => now,
            sessionId: 'completion',
            exerciseId: 'squat',
            publishedRoutineId: 'routine',
            detectorId: 'fixture',
            detectorVersion: '1',
            guidance: GuidedWorkoutProgress(sets: 1, repetitions: 1),
            provenance: WorkoutProvenance.recordedFixture);
        await session.start(consented: true, setupConfirmed: true);
        session.setVoiceMode(voice == 'muted'
            ? WorkoutVoiceMode.muted
            : WorkoutVoiceMode.fullCoaching);
        final view = RealWorkoutView(
            session: session,
            viewport: const ColoredBox(color: Colors.black),
            exerciseName: 'Squat',
            targetRepetitions: 1,
            routineContext: routine
                ? const RoutineWorkoutContext(
                    routineTitle: 'Routine',
                    day: 1,
                    exerciseNumber: 1,
                    totalExercises: 1)
                : null,
            resultBuilder: (_) =>
                const Scaffold(body: Text('Result destination')));
        final effectiveView = ['intermediate', 'out-of-order', 'last-remaining']
                .contains(voice)
            ? RealWorkoutView(
                session: session,
                viewport: const ColoredBox(color: Colors.black),
                exerciseName: 'Squat',
                targetRepetitions: 1,
                routineContext: RoutineWorkoutContext(
                    routineTitle: 'Routine',
                    day: 1,
                    exerciseNumber: voice == 'out-of-order' ? 2 : 1,
                    totalExercises: 2,
                    nextExerciseName: voice == 'last-remaining' ? null : 'Row'))
            : view;
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => effectiveView));
                        },
                        child: const Text('Open'))))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        for (final frame in frames) {
          now = frame.capturedAtMicros;
          detector.frame = frame;
          camera.receive?.call(PoseInput(timestampMicros: now));
          await tester.pump();
        }
        expect(session.guidance!.stage, GuidedWorkoutStage.complete);
        expect(find.byKey(const ValueKey('workout-completion-overlay')),
            findsOneWidget);
        expect(
            store.writes, 1); // No audio/animation delay before durable saving.
        expect(find.text('Result destination'), findsNothing);
        if (voice == 'disposed') {
          await tester.pumpWidget(const SizedBox());
          await session.close();
          await tester.pump();
          session.dispose();
          repo.dispose();
          return;
        }
        if (voice == 'muted' || voice == 'unavailable') {
          await tester.pump(const Duration(milliseconds: 800));
          expect(find.byKey(const ValueKey('workout-completion-overlay')),
              findsOneWidget);
          await tester.pump(const Duration(milliseconds: 850));
        } else {
          await tester.pump(const Duration(milliseconds: 750));
          port.completions.last.complete(AudioPlaybackOutcome.completed);
          await tester.pump();
          expect(
              port.played.last.id,
              voice == 'intermediate' || voice == 'out-of-order'
                  ? 'exercise_complete_v1'
                  : 'workout_complete_v1');
          await tester.pump(const Duration(milliseconds: 950));
          expect(find.byKey(const ValueKey('workout-completion-overlay')),
              findsOneWidget);
          expect(port.closes, 0);
          expect(effects, isNot(contains('workoutComplete')));
          expect(effects, isNot(contains('rep')));
          if (voice == 'background') {
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.paused);
          }
          port.completions.last.complete(AudioPlaybackOutcome.completed);
          await tester.pump();
          if (voice == 'speech') {
            expect(effects, ['workoutComplete']);
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byKey(const ValueKey('workout-completion-overlay')),
                findsOneWidget);
            await tester.pump(const Duration(milliseconds: 190));
          }
          if (voice == 'background') {
            await tester.pump(const Duration(seconds: 1));
            expect(find.byKey(const ValueKey('workout-completion-overlay')),
                findsOneWidget);
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          }
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('workout-completion-overlay')),
            findsNothing);
        expect(
            find.text(routine ? 'Open' : 'Result destination'), findsOneWidget);
        expect(store.writes, 1);
        await tester.pumpWidget(const SizedBox());
        await session.close();
        session.dispose();
        repo.dispose();
      });
    }
  }
}
