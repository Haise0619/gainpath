import 'dart:async';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_feedback_event.dart';
import 'workout_audio_controller_test.dart' show FakeAudio, correction, flush;

class RetryAudio extends FakeAudio implements RetryableWorkoutAudioPort {
  Completer<bool> ready = Completer<bool>();
  int prepares = 0, retries = 0;
  @override
  Future<bool> prepare() {
    prepares++;
    return ready.future;
  }

  @override
  Future<bool> retryPrepare() {
    retries++;
    ready = Completer<bool>();
    return ready.future;
  }
}

void main() {
  test(
      'quiet period spans cue IDs while higher priority warnings remain immediate',
      () async {
    final p = FakeAudio();
    final c = WorkoutAudioController(port: p, quietPeriodMicros: 2000000);
    c.setVoiceEnabled(true);
    const a = CueRequest(
        id: 'a', text: 'Move with control.', priority: CuePriority.correction);
    const b = CueRequest(
        id: 'b',
        text: 'Reset your movement.',
        priority: CuePriority.correction);
    const w = CueRequest(
        id: 'tracking', text: 'Return to view.', priority: CuePriority.warning);
    c.consume([a], nowMicros: 100, trackingAvailable: true);
    await flush();
    p.completions.single.complete(AudioPlaybackOutcome.completed);
    await flush();
    c.consume([b], nowMicros: 1000100, trackingAvailable: true);
    await flush();
    expect(p.played, [a]);
    c.consume([w], nowMicros: 1000101, trackingAvailable: false);
    await flush();
    expect(p.played, [a, w]);
    await c.close();
  });
  test('recent rep cooldown cannot silence a fresh set completion', () async {
    final p = FakeAudio();
    final c = WorkoutAudioController(
        port: p, arbiter: AudioCueArbiter(cooldownMicros: 6000000));
    c.setVoiceEnabled(true);
    const rep = CueRequest(
        id: 'curl_rep',
        text: 'Good repetition.',
        priority: CuePriority.encouragement);
    for (final t in [100, 3000100]) {
      c.consume([],
          nowMicros: t,
          trackingAvailable: true,
          events: [
            WorkoutFeedbackEvent(
                id: 'rep-$t',
                cue: rep,
                observedAtMicros: t,
                generatedAtMicros: t)
          ]);
      await flush();
      if (t == 100) {
        p.completions.single.complete(AudioPlaybackOutcome.completed);
        await flush();
      }
    }
    expect(p.played, hasLength(1));
    c.finishSet();
    await flush();
    expect(p.played.last.text, 'Set complete.');
    expect(p.played, hasLength(2));
    c.finishSet();
    await flush();
    expect(p.played, hasLength(2));
    await c.close();
  });
  test('voice readiness reports failure and explicit retry without speaking',
      () async {
    final p = RetryAudio();
    final a = WorkoutAudioController(port: p);
    expect(a.availability.value, WorkoutVoiceAvailability.muted);
    expect(p.prepares, 0);
    a.setVoiceEnabled(true);
    expect(a.availability.value, WorkoutVoiceAvailability.preparing);
    p.ready.complete(false);
    await flush();
    expect(a.availability.value, WorkoutVoiceAvailability.unavailable);
    final retry = a.retryVoice();
    await flush();
    expect(p.retries, 1);
    p.ready.complete(true);
    await retry;
    expect(a.availability.value, WorkoutVoiceAvailability.ready);
    expect(p.played, isEmpty);
    a.setVoiceEnabled(false);
    await a.retryVoice();
    expect(p.retries, 1);
    expect(a.availability.value, WorkoutVoiceAvailability.muted);
    await a.close();
  });
  test(
      'muting during prepare cannot resurrect voice or dispatch waiting feedback',
      () async {
    final p = RetryAudio();
    final c = WorkoutAudioController(port: p);
    c.setVoiceEnabled(true);
    c.consume([],
        nowMicros: 100,
        trackingAvailable: true,
        events: [
          WorkoutFeedbackEvent(
              id: 'attempt',
              cue: correction,
              observedAtMicros: 100,
              generatedAtMicros: 100)
        ]);
    c.setVoiceEnabled(false);
    p.ready.complete(true);
    await flush();
    expect(c.availability.value, WorkoutVoiceAvailability.muted);
    expect(p.played, isEmpty);
    await c.close();
  });
  test(
      'set boundary retains only completed fresh feedback; explicit pause still cancels',
      () async {
    final p = RetryAudio();
    final a = WorkoutAudioController(port: p);
    a.setVoiceEnabled(true);
    a.consume([],
        nowMicros: 100,
        trackingAvailable: true,
        events: [
          WorkoutFeedbackEvent(
              id: 'attempt',
              cue: correction,
              observedAtMicros: 100,
              generatedAtMicros: 100)
        ]);
    a.finishSet();
    p.ready.complete(true);
    await flush();
    expect(p.played, [correction]);
    a.pause();
    await flush();
    expect(a.activeCue, isNull);
    await a.close();
  });
}
