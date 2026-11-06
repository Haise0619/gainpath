import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'floor_push_up_workout_session_test.dart' show FloorDetector;
import 'real_squat_session_test.dart' show Camera, FailingStore;
import 'squat_processing_controller_test.dart' show AudioSink;

void main() {
  testWidgets('release audit delivers observed incomplete-extension correction',
      (tester) async {
    var now = 0;
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final camera = Camera(), detector = FloorDetector(), audio = AudioSink();
    final store = FailingStore(scope: scope)..fail = false;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    final session = FloorPushUpWorkoutSession(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: audio,
        repository: repo,
        clockMicros: () => now,
        sessionId: 'release-voice-probe',
        exerciseId: 'standard-floor-push-up-side-v1',
        detectorId: 'fixture',
        detectorVersion: '1',
        sets: 1,
        reps: 8,
        provenance: WorkoutProvenance.recordedFixture);
    await session.start(consented: true, setupConfirmed: true);
    session.setVoiceMode(WorkoutVoiceMode.fullCoaching, persist: false);
    Future<void> hold(double angle, int n) async {
      for (var i = 0; i < n; i++) {
        now += 50000;
        detector.angle = angle;
        camera.receive!(PoseInput(timestampMicros: now));
        await tester.pump();
      }
    }

    await hold(170, 14);
    for (final p in [
      (150.0, 4),
      (130.0, 4),
      (110.0, 4),
      (90.0, 8),
      (110.0, 4),
      (130.0, 4),
      (147.0, 4),
      (152.61, 6),
      (140.0, 6),
      (120.0, 6),
      (100.0, 6)
    ]) {
      await hold(p.$1, p.$2);
    }
    final d = session.localDiagnostics['analyzer'] as Map;
    final played = audio.played.map((c) => c.id).toList();
    detector.visibility = .1;
    await hold(170, 10);
    final warningControl = audio.played.map((c) => c.id).toList();
    session.dispose();
    repo.dispose();
    await tester.pump();
    expect(d['partialRepetitions'], 1);
    expect(warningControl, contains('floor_tracking'));
    expect(played, contains('floor_extension'));
  });
  for (final shallow in [false, true]) {
    testWidgets(
        shallow
            ? 'shallow attempt delivers depth correction'
            : 'last target repetition delivers encouragement before set completion',
        (tester) async {
      var now = 0;
      final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
      final camera = Camera(), detector = FloorDetector(), audio = AudioSink();
      final store = FailingStore(scope: scope)..fail = false;
      final repo = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope);
      final session = FloorPushUpWorkoutSession(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: audio,
          repository: repo,
          clockMicros: () => now,
          sessionId: 'voice-outcome',
          exerciseId: 'standard-floor-push-up-side-v1',
          detectorId: 'fixture',
          detectorVersion: '1',
          sets: 1,
          reps: 1,
          provenance: WorkoutProvenance.recordedFixture);
      await session.start(consented: true, setupConfirmed: true);
      session.setVoiceMode(WorkoutVoiceMode.fullCoaching, persist: false);
      Future<void> hold(double angle, int n) async {
        for (var i = 0; i < n; i++) {
          now += 50000;
          detector.angle = angle;
          camera.receive!(PoseInput(timestampMicros: now));
          await tester.pump();
        }
      }

      await hold(170, 14);
      for (final a in shallow
          ? [150.0, 130.0, 125.0, 125.0, 140.0, 155.0, 170.0, 170.0]
          : [
              150.0,
              130.0,
              110.0,
              90.0,
              90.0,
              90.0,
              110.0,
              130.0,
              150.0,
              170.0,
              170.0
            ]) {
        await hold(a, 4);
      }
      expect(audio.played.map((c) => c.id),
          contains(shallow ? 'floor_depth' : 'floor_good'));
      expect(session.analysis!.repetitions, shallow ? 0 : 1);
      if (shallow) expect(session.analysis!.partialRepetitions, 1);
      final before = audio.played.length;
      await hold(
          170, 10); // Timer/current snapshot cannot replay a completed event.
      expect(audio.played.length, before);
      session.dispose();
      repo.dispose();
      await tester.pump();
    });
  }
}
