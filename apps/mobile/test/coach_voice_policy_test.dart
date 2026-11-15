import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/coach_voice_policy.dart';

void main() {
  test(
      'specific press visibility evidence stays specific offline fallback text',
      () {
    for (final text in [
      'Show left hip clearly · adjust framing or lighting',
      'Move closer · keep both hips and overhead hands in view'
    ]) {
      final decision = CoachVoicePolicy().select([
        CueRequest(id: 'press_setup', text: text, priority: CuePriority.warning)
      ],
          nowMicros: 1,
          observedAtMicros: 1,
          trackingAvailable: false,
          fullCoaching: true)!;
      expect(decision.cue.text, text);
      expect(decision.cue.id, 'press_setup');
    }
  });
  test('accepted numbers are current, duplicate free, and support TTS above30',
      () {
    final policy = CoachVoicePolicy();
    CoachVoiceDecision? rep(int count, int now, {int? observed}) =>
        policy.select([],
            nowMicros: now,
            observedAtMicros: observed ?? now,
            trackingAvailable: true,
            fullCoaching: true,
            progress: CoachRepProgress(
                total: count, spoken: count, scope: '1', target: 40));
    expect(rep(0, 0), isNull);
    expect(rep(1, 1000000)!.cue.id, 'number_001');
    expect(rep(1, 1100000), isNull);
    expect(rep(2, 1200000)!.cue.text, 'Two.');
    expect(rep(3, 2000000, observed: 1500000), isNull);
    expect(rep(3, 2100000), isNull); // Never replay an expired count.
    expect(rep(31, 3000000)!.cue.text, '31');
  });
  test('partial cues never manufacture reps and semantic correction is cooled',
      () {
    final policy = CoachVoicePolicy();
    const cue = CueRequest(
        id: 'squat_depth', text: 'old', priority: CuePriority.correction);
    CoachVoiceDecision? pick(int now) => policy.select([cue],
        nowMicros: now,
        observedAtMicros: now,
        trackingAvailable: true,
        fullCoaching: true);
    final first = pick(0)!;
    expect(first.cue.id, 'squat_depth_v1');
    policy.didSelect(first, 0);
    expect(pick(1000000), isNull);
    expect(pick(8000000)!.cue.id, first.cue.id);
  });
  test('milestones use actual target and expire instead of interrupting reps',
      () {
    final policy = CoachVoicePolicy();
    CoachVoiceDecision? pick(int n, int now, {bool idle = true}) =>
        policy.select([],
            nowMicros: now,
            observedAtMicros: now,
            trackingAvailable: true,
            fullCoaching: true,
            idle: idle,
            progress:
                CoachRepProgress(total: n, spoken: n, scope: '1', target: 10));
    pick(0, 0);
    expect(pick(5, 10000000)!.cue.id, 'number_005');
    expect(pick(5, 10500000, idle: false), isNull);
    final half = pick(5, 11600000)!;
    expect(half.cue.id, startsWith('encourage_halfway_'));
    policy.didSelect(half, 11600000);
    expect(pick(5, 12000000), isNull);
    expect(pick(8, 14000000)!.cue.id, 'number_008');
    expect(pick(8, 15600000), isNull); // Global encouragement cooldown.
  });
}
