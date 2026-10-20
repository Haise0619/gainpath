# Step 3 audio slice: coordination and interface

The user's 2026-10-07 request in “Review pose estimation progress” explicitly
starts Step 3 in parallel with this chat. The earlier Step 2 accuracy acceptance
is still unmet; this work does not certify it or enable real workout uploads.

## Owned files and planned interface

This chat owns new mobile audio port/controller/Android adapter and focused
tests, and focused changes to `audio_cue_arbiter.dart` if needed. The coordinating
chat owns `src/squat/*`, pure package exports/tests, and Step 3 orchestration.
No pose inference/filter/preview, persistence, routes, backend or UI changes.

- Preserve `CueRequest(id, text, priority)`.
- New `WorkoutAudioController.consume(cues, nowMicros: ..., trackingAvailable: ...)`
  is nonblocking; timestamps are monotonic input/session microseconds.
- `applyPreferences(MemberPreferences)` honors the existing `voiceCoaching`
  choice; default is disabled. Explicit voice toggle, pause/resume,
  foreground/background and idempotent close are supported.
- `WorkoutAudioPort.play(CueRequest)` completes after playback, cancellation or
  unavailability; `stop` interrupts, `close` releases resources.
- Only fresh input batches are eligible. Higher priority interrupts; duplicates
  and cooldown do not create a delayed corrective backlog. Tracking-loss warnings
  remain eligible when tracking is unavailable, while corrections/encouragement
  are suppressed. Recovery cancels stale loss speech and accepts fresh cues.
- Dart and native cancellation generations suppress late initialization/playback.
  A lifecycle binding is separate from the reusable controller.

Android integration note before shared-file edits: a standalone
`WorkoutAudioPlugin` requires one MainActivity registration, preserving the
existing GPU registration, and one TTS service query in AndroidManifest for
Android package visibility. No Gradle/dependency change is planned. These are
audio-only integration edits; the coordinating chat can continue its own files.

The usable initial playback adapter uses installed offline Android TTS voices.
The Chapter 4.9 soundbank/fast-path interface remains a future port implementation;
no recorded cue assets exist in this slice, so no <10 ms fast-path or physical
speech-latency acceptance is claimed. Priority interruption/cooldown is implemented
without pretending TTS is a prerecorded soundbank.

## Validation status

Audio slice implementation complete on 2026-10-08; API stable and ready for
the coordinating chat's final full mobile run. Verification:

- Focused mobile policy/adapter/lifecycle tests: **22/22 passed**.
- Focused arbiter + legacy pose tests: **11/11 passed**.
- Native epoch JVM test: **11 assertions passed**.
- Focused Dart analysis: **no issues found**.
- Android `:app:compileProfileJavaWithJavac :app:compileProfileKotlin --offline`:
  **BUILD SUCCESSFUL**, final voice-selection repair compiled, 161 tasks.
  Existing Gradle/Kotlin deprecation notices and Android's required deprecated
  one-argument `onError` callback override are warnings, not compile failures.

No installation/device changes.
Independent focused re-review on 2026-10-08 confirmed both reported findings
resolved, with no remaining issues in that focused review. The final background
preference regression also passed; no public API changed for the coordinating
controller.

## Integration API (ready for coordinating controller)

Imports from the mobile package:

- `features/workout/application/workout_audio_controller.dart`
- `features/workout/domain/workout_audio_port.dart`
- `infrastructure/audio/android_workout_audio.dart`
- `infrastructure/audio/workout_audio_lifecycle.dart`

Construction: `WorkoutAudioController(port: AndroidWorkoutAudio())`.
Optional `pendingStartTimeout` defaults to 500 ms: this bounds only a cue waiting
to **start speech**, and does not alter the pose pipeline's 250 ms freshness.
Public methods:

```dart
void consume(Iterable<CueRequest> cues, {
  required int nowMicros, required bool trackingAvailable,
});
void applyPreferences(MemberPreferences preferences);
void setVoiceEnabled(bool enabled);
void pause();
void resume();
void setForeground(bool foreground);
Future<void> close();
```

Getters: `voiceEnabled`, `isClosed`, `activeCue`. Diagnostic results:
`lastOutcome` (`AudioPlaybackOutcome.completed/cancelled/unavailable`) and
`lastError` (nullable Object). No event history or audio recording is stored.

`AndroidWorkoutAudio` also implements optional `PreparedWorkoutAudioPort` with
`Future<bool> prepare()`. Enabling voice warms the engine without speech. Waiting
cues are revalidated against newer batches and cancelled if absent/changed;
the 500 ms start deadline also cancels them when no newer frames arrive.
Speech already dispatched can finish normally, so a one-frame rep event is not
cut off on the next empty batch. Pause/disable/background/recovery still stop it.
There is no stale corrective backlog after engine initialization.

## Review repairs

Independent review and regression checks identified these issues; all addressed:

- Pending-stop calls coalesce, avoiding an unbounded cancellation chain.
- Delayed stop/initialization could start an outdated cue; behavioral red/green
  regressions now verify absent-cue cancellation, stalled-stream start expiry,
  and normal completion of speech already started.
- Offline voice candidates exclude `KEY_FEATURE_NOT_INSTALLED`, and selection
  tries remaining installed offline English voices when a candidate fails.
- Preferences arriving while backgrounded defer TTS warmup until foreground or
  manual resume, avoiding cached initialization failure from a background create.

The native epoch JVM test verifies late callback/cancellation ownership. Android
compilation verifies API compatibility; installed-engine selection and spoken
playback remain physical-device checks, not established by the mocked Dart tests.
Official contract: [Android TTS](https://developer.android.com/reference/android/speech/tts/TextToSpeech),
[not-installed voice feature](https://developer.android.com/reference/android/speech/tts/TextToSpeech.Engine#KEY_FEATURE_NOT_INSTALLED).

## Physical validation still required

After the coordinating controller is mounted in the real camera flow, check
voice disabled/enabled on the Xiaomi; installed offline English voice selection;
audible completion and high-priority interruption; mute/missing voice/focus
denial; pause/Home/manual pause/reopen/End preview/logout while speech or engine
initialization is pending. Record actual speech startup/interruption observations
separately from pose inference telemetry. This slice does not establish squat
accuracy, voice latency, production GPU acceptance, or trusted workout upload.

For an analyzed update use its **monotonic analysis/session time** (the analyzer
`nowMicros`, especially on watchdog ticks), not an old capturedAt timestamp for
freshness-loss events. Duplicate/out-of-order timestamps are ignored. Each
controller has one monotonic session clock; recreate it for a new session.
Tracking transitions cancel old speech. Pass trackingAvailable false for
uncalibrated/rejected tracking; only engine-supplied warnings remain eligible.
`resume()` never replays queued cues and preserves cooldowns.

Bind `WorkoutAudioLifecycle(audio)` only when the orchestration owner does not
already forward foreground state; dispose the binding, then await audio.close()
on end/logout/session replacement. User pause and foreground state are separate.
Apply the account's loaded MemberPreferences before voice is enabled. Do not
enable based on a previous user's preference after logout.

This slice does not touch settings text or mount a new real-workout UI. The
existing settings UI still labels voice coaching inactive until real integration
and physical playback checks are completed.
