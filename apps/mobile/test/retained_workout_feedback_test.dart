import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/domain/retained_workout_feedback.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/application/workout_audio_controller.dart';
import 'workout_audio_controller_test.dart' show FakeAudio, flush;

void main() {
  test('completed movement copy makes no unmeasured form claim', () {
    for (final id in ['curl_rep', 'calf_rep', 'lateral_raise_rep']) {
      expect(
          retainedCoachingCue(CueRequest(
                  id: id, text: '1', priority: CuePriority.encouragement))
              .text,
          'Repetition counted.');
    }
  });
  for (final id in ['curl_partial', 'calf_partial', 'lateral_raise_partial']) {
    test(
        '$id is an actionable fresh correction, duplicate and expired events cannot replay',
        () async {
      final f = RetainedWorkoutFeedback(), p = FakeAudio();
      final c = WorkoutAudioController(port: p, boundedStarts: true);
      c.setVoiceMode(WorkoutVoiceMode.alertsOnly);
      final raw = CueRequest(
          id: id,
          text: 'Partial movement recorded.',
          priority: CuePriority.encouragement);
      final e = f.observe([raw],
          outcome: 1, capturedAtMicros: 100, nowMicros: 100, accepted: true);
      expect(e.single.cue.priority, CuePriority.correction);
      expect(e.single.cue.text, isNot(raw.text));
      expect(
          f.observe([raw],
              outcome: 1,
              capturedAtMicros: 200,
              nowMicros: 200,
              accepted: true),
          isEmpty);
      c.consume([], nowMicros: 100, trackingAvailable: true, events: e);
      await flush();
      expect(p.played, [e.single.cue]);
      p.completions.single.complete(AudioPlaybackOutcome.completed);
      await flush();
      c.consume([], nowMicros: 7000000, trackingAvailable: true, events: e);
      await flush();
      expect(p.played, hasLength(1));
      final expired = f.observe([raw],
          outcome: 2,
          capturedAtMicros: 7000000,
          nowMicros: 7600000,
          accepted: true);
      c.consume([],
          nowMicros: 7600000, trackingAvailable: true, events: expired);
      await flush();
      expect(p.played, hasLength(1));
      await c.close();
    });
  }
  test(
      'visible primary feedback follows warning then correction then encouragement',
      () {
    final cues = [
      const CueRequest(
          id: 'curl_rep', text: '1', priority: CuePriority.encouragement),
      const CueRequest(
          id: 'curl_partial',
          text: 'Partial movement recorded.',
          priority: CuePriority.encouragement),
      const CueRequest(
          id: 'source', text: 'Return to view', priority: CuePriority.warning)
    ];
    expect(primaryWorkoutCue(cues)!.id, 'source');
    expect(primaryWorkoutCue(cues.take(2))!.id, 'curl_partial');
  });
}
