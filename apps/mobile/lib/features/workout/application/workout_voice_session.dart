import 'workout_audio_controller.dart';

/// Optional capability adopted by the six retained AI trackers.
abstract interface class WorkoutVoiceSession {
  WorkoutAudioController get voiceFeedback;
}
