import 'package:gainpath_pose/gainpath_pose.dart';

/// A completed observation, independent of the next repetition phase. Session
/// owners create these only from a new, accepted attempt outcome, never ticks.
class WorkoutFeedbackEvent {
  const WorkoutFeedbackEvent({
    required this.id,
    required this.cue,
    required this.observedAtMicros,
    required this.generatedAtMicros,
  });

  static const maximumAgeMicros = 500000;
  final String id;
  final CueRequest cue;
  final int observedAtMicros, generatedAtMicros;
  int get expiresAtMicros => observedAtMicros + maximumAgeMicros;

  bool isFresh(int nowMicros) =>
      id.isNotEmpty &&
      observedAtMicros >= 0 &&
      generatedAtMicros >= observedAtMicros &&
      nowMicros >= generatedAtMicros &&
      nowMicros < expiresAtMicros;
}
