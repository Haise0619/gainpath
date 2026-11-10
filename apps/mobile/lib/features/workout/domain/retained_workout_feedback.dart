import 'package:gainpath_pose/gainpath_pose.dart';
import 'workout_feedback_event.dart';

const _partialCopy = {
  'curl_partial': 'Curl a little farther and hold briefly before lowering.',
  'calf_partial': 'Raise your heels farther and hold briefly before lowering.',
  'lateral_raise_partial':
      'Raise both arms to shoulder height and hold briefly before lowering.',
};
const _completed = {'curl_rep', 'calf_rep', 'lateral_raise_rep'};
bool isRetainedOutcomeCue(CueRequest cue) =>
    _completed.contains(cue.id) || _partialCopy.containsKey(cue.id);

/// Copy describes only the observed range/dwell outcome, never load or safety.
CueRequest retainedCoachingCue(CueRequest cue) => isRetainedOutcomeCue(cue)
    ? CueRequest(
        id: cue.id,
        text: _partialCopy[cue.id] ?? 'Repetition counted.',
        priority: _partialCopy.containsKey(cue.id)
            ? CuePriority.correction
            : CuePriority.encouragement)
    : cue;

CueRequest? primaryWorkoutCue(Iterable<CueRequest> cues) {
  CueRequest? selected;
  for (final raw in cues) {
    final cue = retainedCoachingCue(raw);
    if (selected == null || cue.priority.weight > selected.priority.weight) {
      selected = cue;
    }
  }
  return selected;
}

/// One completed outcome produces at most one batch; ticks cannot replay it.
class RetainedWorkoutFeedback {
  int _lastOutcome = 0;
  List<WorkoutFeedbackEvent> observe(Iterable<CueRequest> cues,
      {required int outcome,
      required int capturedAtMicros,
      required int nowMicros,
      required bool accepted}) {
    final fresh = outcome > _lastOutcome;
    _lastOutcome = outcome;
    if (!fresh || !accepted) return const [];
    return [
      for (final cue in cues.where(isRetainedOutcomeCue))
        WorkoutFeedbackEvent(
            id: 'outcome-$outcome-${cue.id}',
            cue: retainedCoachingCue(cue),
            observedAtMicros: capturedAtMicros,
            generatedAtMicros: nowMicros)
    ];
  }
}
