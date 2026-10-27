import 'package:gainpath_pose/gainpath_pose.dart';

enum AudioPlaybackOutcome { completed, cancelled, unavailable }

enum WorkoutVoiceMode {
  fullCoaching('Full Coaching'),
  alertsOnly('Alerts Only'),
  muted('Muted');

  const WorkoutVoiceMode(this.label);
  final String label;
}

abstract interface class WorkoutVoicePreferences {
  Future<WorkoutVoiceMode?> read();
  Future<void> write(WorkoutVoiceMode mode);
}

/// Playback implementations may later combine recorded cues and narration.
/// Completion means playback finished (or was cancelled), not just enqueued.
abstract interface class WorkoutAudioPort {
  Future<AudioPlaybackOutcome> play(CueRequest cue);
  Future<void> stop();
  Future<void> close();
}

/// Engines with asynchronous initialization can be warmed without speaking.
/// The controller revalidates a waiting cue before invoking playback.
abstract interface class PreparedWorkoutAudioPort implements WorkoutAudioPort {
  Future<bool> prepare();
}
