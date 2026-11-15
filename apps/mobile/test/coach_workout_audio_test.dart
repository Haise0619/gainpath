import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'package:gainpath_mobile/features/workout/application/coach_voice_policy.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'workout_audio_controller_test.dart' show FakeAudio, flush;

class CoachAudio extends FakeAudio implements CoachWorkoutAudioPort {}

void main() {
  test('leaving rest drops a pending rest announcement behind final number',
      () async {
    final port = CoachAudio();
    final audio = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    audio.consume([],
        nowMicros: 1,
        trackingAvailable: true,
        progress: const CoachRepProgress(total: 1, spoken: 1, scope: '1'));
    await flush();
    audio.finishSet(transition: 'Set complete. Rest.', restScoped: true);
    audio.cancelTransition();
    port.completions.single.complete(AudioPlaybackOutcome.completed);
    await flush();
    expect(port.played, hasLength(1));
    await audio.close();
  });
  test(
      'tracking loss cancels evidence correction without explicit invalidation',
      () async {
    final port = CoachAudio();
    final audio = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    audio.consume([
      const CueRequest(
          id: 'wall_body', text: 'line', priority: CuePriority.correction)
    ], nowMicros: 1000000, trackingAvailable: true);
    await flush();
    expect(audio.activeCue!.id, 'wall_line_v1');
    audio.consume([], nowMicros: 1100000, trackingAvailable: false);
    await flush();
    expect(audio.activeCue, isNull);
    await audio.close();
  });
  test('new accepted number replaces old number without a rep queue', () async {
    final port = CoachAudio();
    final audio = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    void rep(int n, int now) => audio.consume([],
        nowMicros: now,
        trackingAvailable: true,
        observedAtMicros: now,
        progress: CoachRepProgress(total: n, spoken: n, scope: '1'));
    rep(1, 1000000);
    await flush();
    rep(2, 1200000);
    await flush();
    rep(3, 1300000);
    await flush();
    expect(port.played.map((c) => c.id),
        ['number_001', 'number_002', 'number_003']);
    rep(3, 1400000);
    await flush();
    expect(port.played, hasLength(3));
    await audio.close();
  });
  test('warning wins; an interrupted number is never replayed', () async {
    final port = CoachAudio();
    final audio = WorkoutAudioController(port: port)..setVoiceEnabled(true);
    audio.consume([],
        nowMicros: 1,
        trackingAvailable: true,
        progress: const CoachRepProgress(total: 1, spoken: 1, scope: '1'));
    await flush();
    audio.consume([
      const CueRequest(
          id: 'squat_tracking_lost',
          text: 'lost',
          priority: CuePriority.warning)
    ], nowMicros: 10, trackingAvailable: false, invalidateFeedback: true);
    await flush();
    expect(port.played.last.id, 'tracking_lost_v1');
    audio.pause();
    await flush();
    audio.resume();
    audio.consume([],
        nowMicros: 20,
        trackingAvailable: true,
        progress: const CoachRepProgress(total: 1, spoken: 1, scope: '1'));
    await flush();
    expect(port.played, hasLength(2));
    await audio.close();
  });
}
