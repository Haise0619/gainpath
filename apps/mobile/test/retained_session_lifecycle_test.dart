import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'shoulder_press_session_test.dart' show PressHarness;
import 'support/shoulder_press_trajectory.dart';
import 'workout_audio_controller_test.dart' show FakeAudio;
import 'real_squat_session_test.dart' show Camera;
import 'support/workout_consent_harness.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';

class RetiringCamera extends Camera {
  final gate = Completer<void>();
  @override
  Future<void> stop() async {
    await gate.future;
    await super.stop();
  }
}

void main() {
  testWidgets(
      'front view preparation never adds a contradictory side view instruction',
      (tester) async {
    await openWorkoutConsent(tester,
        previouslyAccepted: true,
        instruction: shoulderPressCaptureInstruction,
        setupLabel: shoulderPressSetupConfirmation);
    expect(find.textContaining('Use a side view'), findsNothing);
    await confirmWorkoutSetup(tester);
  });
  testWidgets('frozen result is durable before camera retirement finishes',
      (tester) async {
    final h = PressHarness(), camera = RetiringCamera();
    h.store.fail = false;
    final c = ShoulderPressWorkoutSession(
        scope: h.scope,
        activeScope: () => h.active,
        camera: camera,
        detectorFactory: () async => h.detector,
        audioPort: h.audio,
        repository: h.repo,
        clockMicros: () => h.now,
        sessionId: 'durable-first',
        exerciseId: 'dumbbell-shoulder-press-front-v1',
        publishedRoutineId: 'routine',
        detectorId: 'synthetic-press',
        detectorVersion: '1',
        sets: 1,
        reps: 5,
        provenance: WorkoutProvenance.recordedFixture);
    addTearDown(() {
      if (!camera.gate.isCompleted) camera.gate.complete();
      c.dispose();
      h.dispose();
    });
    await c.start(consented: true, setupConfirmed: true);
    h.now = 100000;
    h.detector.frame = shoulderPressTrajectory().first;
    camera.receive!(PoseInput(timestampMicros: 0));
    await tester.pump();
    final saving = c.endAndSave();
    await tester.pump();
    expect(await h.repo.loadHistory(), hasLength(1));
    camera.gate.complete();
    await saving;
  });
  for (final interruption in ['geometry', 'watchdog']) {
    testWidgets(
        'press $interruption cancels current-source speech without another pose',
        (tester) async {
      final h = PressHarness(), port = FakeAudio();
      final c = ShoulderPressWorkoutSession(
          scope: h.scope,
          activeScope: () => h.active,
          camera: h.camera,
          detectorFactory: () async => h.detector,
          audioPort: port,
          repository: h.repo,
          clockMicros: () => h.now,
          sessionId: 'interruption',
          exerciseId: 'dumbbell-shoulder-press-front-v1',
          publishedRoutineId: 'routine',
          detectorId: 'synthetic-press',
          detectorVersion: '1',
          sets: 1,
          reps: 5,
          provenance: WorkoutProvenance.recordedFixture);
      await c.start(consented: true, setupConfirmed: true);
      for (final f in shoulderPressTrajectory()
          .where((f) => f.capturedAtMicros <= 1000000)) {
        h.now = f.capturedAtMicros;
        h.detector.frame = f;
        h.camera.receive!(PoseInput(timestampMicros: h.now));
        await tester.pump();
      }
      c.audio.setVoiceEnabled(true);
      h.now++;
      c.audio.consume([
        const CueRequest(
            id: 'current',
            text: 'Move with control.',
            priority: CuePriority.correction)
      ], nowMicros: h.now, trackingAvailable: true);
      await tester.pump();
      expect(c.audio.activeCue, isNotNull);
      if (interruption == 'geometry') {
        c.preview.onGeometryInvalidated!();
      } else {
        h.now += 600000;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.audio.activeCue, isNull);
      await c.close();
      c.dispose();
      h.dispose();
    });
  }
}
