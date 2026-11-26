# 5.1.4.5 — Workout voice feedback

The active Android integration uses bundled prerecorded English speech for stable cue IDs and installed offline Android TextToSpeech for dynamic/unmapped phrases. The historical V1 pack report identifies offline Kokoro af_heart at speed 1.15 for asset production. It reports 77 clips (30 numbers, 47 phrases), 24 kHz mono and 1,507,905 bytes. Runtime references the assets and Android TTS. It does not invoke a hosted voice provider or include a training model. See docs/integration/module2-ai-coach-voice-v1-implementation.md:1–33, apps/mobile/pubspec.yaml:88–95, apps/mobile/lib/features/workout/domain/coach_voice_catalog.dart and apps/mobile/assets/audio/coach_en/default_v1/manifest.json.

~~~mermaid
sequenceDiagram
  participant A as Analyzer
  participant S as Exercise session
  participant C as WorkoutAudioController
  participant P as CoachVoicePolicy
  participant N as Android WorkoutAudioPlugin
  A->>S: Fresh accepted metrics and cue candidates
  S->>C: Cues plus health, phase and rep progress
  C->>P: Filter by voice mode, source and event age
  P-->>C: Highest-priority permissible cue
  C->>N: MethodChannel play with start deadline
  alt Mapped bundled phrase available
    N->>N: Audio focus then MediaPlayer start
  else Supported offline fallback
    N->>N: Android TextToSpeech QUEUE_FLUSH under same deadline
  end
  N-->>C: Start/outcome/availability
~~~

## Policies and lifecycle

- User preference types support muted, alerts-only and full coaching. The app-private settings store persists the choice. WorkoutAudioController has distinct native V1 and legacy/custom port paths. V1 rewrites analyzer IDs to semantic phrase IDs and preserves real unmapped details (e.g. joint framing) as offline TTS. Setup/rest/set/effort/completion cues reuse workout state and asset definitions.
- Rank is warning 5, correction 4, latest valid number 3, transition 2, encouragement 1. Full accepted rep totals, presented against current set/arm baselines, drive numeric utterances 1–30 via bundled assets and >30 via dynamic TTS. Partials cannot turn into full numbers. A numeric observation must be <250 ms old. Newer numbers can supersede older ones; higher priority can replace an active lower cue. One selected current cue is used instead of building a speech backlog.
- A correction gets an 8 s semantic cooldown, increased to 15 s after the first two selections and a global 4 s correction spacing. Encouragement can come from halfway, two remaining or a multiple of five based on target and true full count. It expires after 2.5 s, waits at least 1.5 s after a rep and 4 s after correction, uses a 12 s global and 60 s same-phrase interval and caps at two per set/arm. Unavailable tracking suppresses nonwarning V1 candidates.
- AndroidWorkoutAudio uses gainpath/workout_audio and per-owner events. It passes a remaining start deadline capped at 500 ms (rep policy can provide only the remaining 250 ms event budget). WorkoutAudioPlugin initializes assets and the available offline English TTS voice, handles AudioFocus, stops/cancels the prior owner, and uses a single playback generation. Asset playback uses asynchronous MediaPlayer prepare. TTS can take the same cue only when fallback is still eligible and inside the deadline. Expired or already-started speech is not repeated as fallback. Asset readiness is independent of parallel TTS warm-up.
- Pausing, exiting, source/scope change and leaving foreground close or silence the relevant owner. Speech result and native preparation timing are observable diagnostics; award, rep counting and summary persistence remain functional even when audio is missed.

Anchors: apps/mobile/lib/features/workout/application/coach_voice_policy.dart:53–250 and workout_audio_controller.dart:213–376,453–519,694; apps/mobile/lib/infrastructure/audio/android_workout_audio.dart:12–50,170–207 and workout_audio_lifecycle.dart; apps/mobile/android/app/src/main/java/com/zyang/gainpath/WorkoutAudioPlugin.java:119–155,194–305,339–431,475–490. Tests include apps/mobile/test/coach_voice_policy_test.dart, floor_push_up_voice_feedback_test.dart, retained_voice_boundary_test.dart and workout_voice_readiness_test.dart. Historical probe observations and remaining measurement protocol are in the Voice Feedback evaluation.
