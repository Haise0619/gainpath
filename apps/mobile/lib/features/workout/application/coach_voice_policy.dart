import 'dart:math';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../domain/coach_voice_catalog.dart';
import 'guided_workout_progress.dart';

/// Read-only voice projection of an accepted analyzer total. Never earns reps.
class CoachRepProgress {
  const CoachRepProgress(
      {required this.total,
      required this.spoken,
      required this.scope,
      this.target});
  factory CoachRepProgress.guided(int total, GuidedWorkoutProgress? guidance) =>
      CoachRepProgress(
          total: total,
          spoken:
              guidance == null ? total : total - guidance.repetitionBaseline,
          scope: '${guidance?.currentSet ?? 1}',
          target: guidance?.repetitions);
  final int total, spoken;
  final String scope;
  final int? target;
}

class CoachVoiceDecision {
  const CoachVoiceDecision(this.cue, this.rank, this.observedAtMicros);
  final CueRequest cue;
  final int rank, observedAtMicros;
  bool get isNumber =>
      cue.id.startsWith('number_') || cue.id == 'number_dynamic';
}

/// Constant-space semantic policy. Only the latest accepted number is offered;
/// an optional encouragement expires after2.5s and is never a speech FIFO.
class CoachVoicePolicy {
  CoachVoicePolicy({Random? random}) : _random = random ?? Random();
  final Random _random;
  int _total = 0, _spoken = 0, _lastRepAt = -100000000;
  String? _scope;
  int _encouragements = 0;
  final _milestones = <String>{};
  final _last = <String, int>{}, _times = <String, int>{};
  int _lastCorrection = -100000000, _lastEncouragement = -100000000;
  String? _pendingEncouragement;
  int _pendingAt = 0;
  final _recentVariants = <String>[];

  void invalidate() {
    _pendingEncouragement = null;
  }

  static bool isNumber(CueRequest cue) => cue.id.startsWith('number_');
  static int rank(CueRequest cue) => cue.priority == CuePriority.warning
      ? 5
      : isNumber(cue)
          ? 3
          : cue.priority == CuePriority.correction
              ? 4
              : cue.id.startsWith('encourage_')
                  ? 1
                  : 2;

  static CueRequest clip(String id, CuePriority priority, {String? fallback}) =>
      CueRequest(
          id: id,
          text: coachVoiceCatalog[id]?.text ?? fallback ?? id,
          priority: priority);

  static String transitionId(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('workout complete')) return 'workout_complete_v1';
    if (lower.contains('exercise complete')) return 'exercise_complete_v1';
    if (lower.contains('left arm')) return 'switch_left_v1';
    if (lower.contains('right arm')) return 'switch_right_v1';
    if (lower.contains('nearly') || lower.contains('rest is')) {
      return 'rest_ending_v1';
    }
    if (lower.contains('rest')) return 'rest_begin_v1';
    if (lower.contains('set complete')) return 'set_complete_v1';
    if (lower.startsWith('get ready for') || lower.contains('next exercise')) {
      return 'next_exercise_v1';
    }
    if (lower.contains('begin') || lower.contains('moving')) return 'start_v1';
    return 'ready_v1';
  }

  static const _mapping = {
    'squat_trunk': 'squat_chest_v1',
    'squat_depth': 'squat_depth_v1',
    'curl_upper_arm': 'curl_upper_v1',
    'curl_trunk': 'curl_trunk_v1',
    'curl_partial': 'curl_range_v1',
    'calf_knee': 'calf_knees_v1',
    'calf_partial': 'calf_range_v1',
    'lateral_raise_partial': 'lateral_range_v1',
    'shoulder_press_partial': 'press_range_v1',
    'floor_sag': 'floor_sag_v1',
    'floor_pike': 'floor_pike_v1',
    'floor_depth': 'floor_depth_v1',
    'floor_extension': 'floor_extension_v1',
    'wall_body': 'wall_line_v1',
    'wall_partial': 'partial_general_v1',
    'row_partial': 'partial_general_v1',
    'reverse_lunge_partial': 'partial_general_v1',
    'floor_tracking': 'camera_adjust_v1',
    'squat_tracking_lost': 'tracking_lost_v1',
    'lunge_begin': 'start_v1',
  };
  CueRequest? _rewrite(CueRequest cue) {
    if (cue.id.endsWith('_rep') || cue.id == 'floor_good') return null;
    String? id = _mapping[cue.id];
    if (cue.id.startsWith('lunge_start_')) {
      final number = int.tryParse(cue.text);
      if (number != null && number >= 1 && number <= 3) {
        return clip('number_${number.toString().padLeft(3, '0')}',
            CuePriority.encouragement);
      }
    }
    if (cue.id == 'press_setup') {
      final text = cue.text.toLowerCase();
      // Unpackaged joint/framing reasons retain their actual observed detail.
      // A generic hand-position cue would assert an unrelated problem.
      if (text.startsWith('show ') ||
          text.startsWith('move closer') ||
          text.contains('lighting') ||
          text.contains('forearms upward')) {
        return cue;
      }
      id = text.contains('together')
          ? 'press_sync_v1'
          : text.contains('delayed') || text.contains('tracking uncertain')
              ? 'tracking_delay_v1'
              : text.contains('face ') || text.contains('straight on')
                  ? 'setup_front_v1'
                  : text.contains('camera geometry')
                      ? 'camera_adjust_v1'
                      : text.contains('camera or body moved')
                          ? 'tracking_delay_v1'
                          : 'setup_press_v1';
    }
    if (id == null) return cue; // Offline TTS only for real, unmapped evidence.
    return clip(
        id,
        coachVoiceCatalog[id]?.asset.contains('/correction/') == true &&
                cue.priority != CuePriority.warning
            ? CuePriority.correction
            : cue.priority);
  }

  CoachVoiceDecision? select(
    Iterable<CueRequest> cues, {
    required int nowMicros,
    required int observedAtMicros,
    required bool trackingAvailable,
    required bool fullCoaching,
    CoachRepProgress? progress,
    bool idle = true,
  }) {
    final candidates = <CoachVoiceDecision>[];
    if (progress != null) {
      if (_scope != progress.scope) {
        _scope = progress.scope;
        _spoken = 0;
        _encouragements = 0;
        _milestones.clear();
        invalidate();
      }
      final advanced = progress.total > _total;
      _total = max(_total, progress.total);
      if (advanced) {
        final fresh = nowMicros >= observedAtMicros &&
            nowMicros - observedAtMicros < 250000;
        if (fullCoaching && trackingAvailable && fresh && progress.spoken > 0) {
          final id = progress.spoken <= 30
              ? 'number_${progress.spoken.toString().padLeft(3, '0')}'
              : 'number_dynamic';
          candidates.add(CoachVoiceDecision(
              clip(id, CuePriority.encouragement,
                  fallback: '${progress.spoken}'),
              3,
              observedAtMicros));
          _lastRepAt = nowMicros;
          final target = progress.target;
          String? family;
          if (target != null &&
              target >= 6 &&
              _spoken < (target / 2).ceil() &&
              progress.spoken >= (target / 2).ceil() &&
              progress.spoken < target) {
            family = 'halfway';
          } else if (target != null &&
              target >= 8 &&
              progress.spoken >= target - 2 &&
              progress.spoken < target) {
            family = 'finish';
          } else if (progress.spoken % 5 == 0 &&
              (target == null || progress.spoken < target)) {
            family = 'rep';
          }
          if (family != null && (family == 'rep' || _milestones.add(family))) {
            _pendingEncouragement = family;
            _pendingAt = nowMicros;
          }
        }
      }
      _spoken = progress.spoken;
    }
    for (final source in cues) {
      final cue = _rewrite(source);
      if (cue == null ||
          (!fullCoaching && cue.priority == CuePriority.encouragement)) {
        continue;
      }
      final priority = rank(cue);
      if (!trackingAvailable && priority != 5) continue;
      final previous = _last[cue.id];
      final cooldown = (_times[cue.id] ?? 0) >= 2 ? 15000000 : 8000000;
      if (previous != null && nowMicros - previous < cooldown) continue;
      if (priority == 4 && nowMicros - _lastCorrection < 4000000) continue;
      candidates.add(CoachVoiceDecision(cue, priority, observedAtMicros));
    }
    if (_pendingEncouragement != null && nowMicros - _pendingAt > 2500000) {
      invalidate();
    }
    if (candidates.isEmpty &&
        fullCoaching &&
        trackingAvailable &&
        idle &&
        _pendingEncouragement != null &&
        _encouragements < 2 &&
        nowMicros - _lastRepAt >= 1500000 &&
        nowMicros - _lastCorrection >= 4000000 &&
        nowMicros - _lastEncouragement >= 12000000) {
      final family = 'encourage_${_pendingEncouragement!}_v';
      final variants = coachVoiceCatalog.keys
          .where((id) =>
              id.startsWith(family) &&
              !_recentVariants.contains(id) &&
              nowMicros - (_last[id] ?? -100000000) >= 60000000)
          .toList();
      if (variants.isNotEmpty) {
        final id = variants[_random.nextInt(variants.length)];
        candidates.add(CoachVoiceDecision(
            clip(id, CuePriority.encouragement), 1, nowMicros));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.rank.compareTo(a.rank));
    return candidates.first;
  }

  void didSelect(CoachVoiceDecision decision, int now) {
    final id = decision.cue.id;
    _last[id] = now;
    _times[id] = (_times[id] ?? 0) + 1;
    if (decision.rank == 4) _lastCorrection = now;
    if (decision.rank == 1) {
      _lastEncouragement = now;
      _encouragements++;
      _recentVariants.add(id);
      if (_recentVariants.length > 2) _recentVariants.removeAt(0);
      invalidate();
    }
  }
}
