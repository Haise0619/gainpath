# Module 2 — Phases 1 and 2 implementation

Primary optimization scope: **Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press**. Reverse Lunge, Dumbbell Row and Wall Push-up remain available to historical sessions, existing references and legacy tests pending a separate retirement assessment. Other execution modes remain intact.

## Phase 1 — verified 11 November 2026

- Curl, Calf Raise and Lateral Raise now measure watchdog silence from accepted result delivery, matching Squat/Shoulder Press. Incoming250ms capture-age/gap gates and all movement, confidence and dwell thresholds remain unchanged. Deterministic steady200ms inference cases reproduce the old reset and pass after the fix; true delivery absence still resets tracking.
- Geometry and watchdog loss invalidate current-source speech across retained sessions. Completed observation semantics are preserved for Phase 2.
- Detector failures retire the failed model before deliberate retry. Inference requests have a5s failure deadline. UI cleanup waits are bounded, but a deadline or isolate-kill request is never treated as proof that native work exited. A shared physical-camera lease survives route replacement until real cleanup and worker exit confirm release. Pending native work can keep capture unavailable; restarting capture concurrently is deliberately prevented.
- Frozen local results are written before optional camera/audio teardown. Save retries reuse the same observation. Generic setup copy no longer contradicts front-view instructions.

Fresh verification: **325 Mobile tests passed,13 optional diagnostic skips** across52 affected files with preview enabled; **759 pose tests passed**; **18-file scoped analysis clean**; arm64 Debug APK built successfully. Retained artifact: `build/module2-phase1-20261110/phase1-app-debug.apk`, SHA256 `875A9BFF5F272F2FDB8130BC6DDC7FD4812CD51562AE8AAC7BDE1AA54F80E293`. The backup integration fixture now compiles because of a separately modified domain file; that change is excluded from this commit. An intermediate run incorrectly enabled the baseline define for a test explicitly asserting ordinary-build defaults; the final run uses the correct preview define.

Independent review identified cross-route ownership and unconfirmed isolate termination gaps. Both have RED→GREEN regression coverage. No physical device was touched. No detector model/backend, movement algorithm, rep threshold, scheduling backend, schema, catalog or historical record changed. Diagnostic metrics remain bounded scalars; Phase 0's physical profiling procedure still applies. Real camera permission/native termination, exercise accuracy, memory/thermal behavior and audible latency require device acceptance.

Modified production areas: retained six sessions, shared preview controller, Android camera and BlazePose worker lifecycle, Curl/Calf/Lateral watchdog timestamps and neutral preparation copy. Added recovery/ownership/session lifecycle/worker-exit and delivery-timing regressions. Documentation includes the execution ledger and operational references. Existing unrelated changes are preserved through partial staging; verification ran against the inspected working tree, not an isolated clean checkout.

## Phase 2 — verified 11 November 2026

Completed outcome speech now survives rest/completion without letting later watchdog snapshots replay it. Curl/Calf/Lateral adopt the existing500ms completed-event/native absolute start deadline used by Squat/Floor/Press. All six opt into a2s cross-ID quiet period (higher-priority alerts can interrupt), with6s per-ID cooldown. Budgets count selection, including failed starts; they do not claim audible delivery. When normal repetition throttling suppresses a final outcome, one distinct **“Set complete.”** event can replace it using that observation's original freshness deadline. This boundary exception bypasses ordinary quiet/cooldown, remains deduplicated, honors Alerts Only/mute, and never queues old feedback.

Analysis stops at set boundaries; explicit pause, source/geometry loss, background, consent/account change and close still cancel speech. Frozen results persist first, then completion speech gets at most1.5s to finish before teardown/navigation. Failed speech cannot block durable storage. Background also suspends camera capture during the final saving phase. Squat geometry changes now invalidate feedback even while saving.

| Retained exercise | Evidence and feedback policy |
|---|---|
| Squat | Existing accepted completed-attempt depth correction/praise and source evidence retained |
| Biceps Curl | A new accepted flexion/return outcome; partial range/dwell prompts “Curl a little farther and hold briefly before lowering” as a correction |
| Calf Raise | A new accepted heel-raise/return outcome; partial height/dwell prompts a fuller heel raise with a brief hold |
| Floor Push-up | Existing accepted observation, temporary-dropout evidence, depth/extension corrections and provisional form boundaries retained |
| Lateral Raise | A new accepted bilateral raise/return outcome; partial elevation/dwell prompts shoulder height and a brief hold |
| Shoulder Press | Existing accepted bilateral overhead event/correction retained; count-only praise now says “Repetition counted.” |

Curl/Calf/Lateral full outcomes also say **“Repetition counted.”**; no load, spinal alignment, balance, floor contact, perfect-form or safety claim is added. Their actionable partials have correction priority and are eligible in Alerts Only. The visible primary cue selects the same highest-priority supported message, with other details retained in the sheet.

An optional voice capability on the six retained sessions exposes preparation, readiness and unavailability without changing manual/timed sessions or requiring legacy trackers to adopt the new UI. Persisted mute remains silent and does not initialize TTS. Voice warms after authorized session/setup creation when enabled preferences are applied; preparation has a3s UI deadline. An explicit retry closes the previous native engine and creates a fresh ephemeral identity, with no automatic retry loop or speech test. Late prepare/close/mute callbacks cannot revive playback. The voice menu explains Android offline English-voice settings and the live view retains visual feedback. Status and retry work at320px/1.5× text; the header/live cue now flow vertically to avoid overlap.

Fresh verification: **362 affected Mobile tests passed,13 optional diagnostic skips** across56 files with preview enabled; **759 pose tests passed**; **20-file scoped analysis clean**; arm64 Android Debug APK built successfully. Retained artifact: `build/module2-phase2-20261111/phase2-app-debug.apk`, SHA256 `76565538C0E14FCBCFADBDBEF721987379791B5C3AC5B9793E35F6BFD8D4BB83`. Tests include24 actual six-exercise one/two-repetition rest/completion cases, durable save before pending speech, source/background cancellation during save, cooldown fallback, quiet-period priority, fresh partials, duplicate/expired events, native engine recreation, muted late preparation and voice status/retry UI. Independent review identified the save-time Squat source gap and final-cue cooldown suppression; both are fixed with regression coverage. Initial boundary/cooldown/readiness/quiet-period/copy failures and final passing logs are retained under ignored `build/module2-phase2-20261111/`.

A separate320px/2× text probe found an existing4px vertical sheet overflow; replay against the pre-Phase-2 view reproduces it (`baseline-large-text.log`). The new status/cue overlap is fixed; the broader sheet accessibility issue remains outside this voice change. No full-repository green claim is made. Tests/build used the inspected workspace containing preserved unrelated changes; only scoped Phase 2 deltas are committed.

Modified files: six retained sessions, Squat processing, shared audio controller/port, Android audio adapter, optional voice-session interface, retained feedback mapper, live workout view, scalar event classification, Android/Press tests and four new boundary/readiness/feedback/UI test files. Audit/plan and operational-reference updates document the implementation. No tracking model, movement threshold, backend, schema, history, catalog, enrollment, legacy retirement or automatic next-set policy changed.

The Phase 0 privacy-safe scalar instrumentation remains ready, including boundary-event correlation; no camera frames, identities or raw pose histories are recorded. **Physical camera/inference FPS and drops, native failure recovery, audible/Bluetooth latency, duty cycle, movement accuracy, memory/resource soak, power/thermal and user comprehension remain unmeasured.** Follow the exact device/environment, cold/warm, six-exercise, audio and45–60min soak procedure in [the Phase 0 report](module-2-phase0-implementation.md#exact-remaining-physical-baseline-procedure). No APK was installed/launched, and no device, live catalog or Firebase resource was touched.


## Phase 2 modified files

- `AGENTS.md`
- `README.md`
- `apps/mobile/lib/features/workout/application/calf_raise_workout_session.dart`
- `apps/mobile/lib/features/workout/application/curl_workout_session.dart`
- `apps/mobile/lib/features/workout/application/floor_push_up_workout_session.dart`
- `apps/mobile/lib/features/workout/application/lateral_raise_workout_session.dart`
- `apps/mobile/lib/features/workout/application/real_squat_session_controller.dart`
- `apps/mobile/lib/features/workout/application/shoulder_press_workout_session.dart`
- `apps/mobile/lib/features/workout/application/squat_processing_controller.dart`
- `apps/mobile/lib/features/workout/application/workout_audio_controller.dart`
- `apps/mobile/lib/features/workout/application/workout_voice_session.dart`
- `apps/mobile/lib/features/workout/domain/retained_workout_feedback.dart`
- `apps/mobile/lib/features/workout/domain/workout_audio_port.dart`
- `apps/mobile/lib/features/workout/domain/workout_performance_diagnostics.dart`
- `apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart`
- `apps/mobile/lib/infrastructure/audio/android_workout_audio.dart`
- `apps/mobile/test/android_workout_audio_test.dart`
- `apps/mobile/test/retained_voice_boundary_test.dart`
- `apps/mobile/test/retained_workout_feedback_test.dart`
- `apps/mobile/test/shoulder_press_session_test.dart`
- `apps/mobile/test/workout_voice_readiness_test.dart`
- `apps/mobile/test/workout_voice_status_ui_test.dart`
- `docs/ARCHITECTURE.md`
- `docs/OPERATIONS.md`
- `docs/PROGRESS_REPORT.md`
- `docs/STATUS.md`
- `docs/SUPERVISOR_DEMO_GUIDE.md`
- `docs/superpowers/plans/2026-11-10-module2-phases1-2.md`
- `docs/ux/module-2-performance-voice-ux-audit.md`
- `docs/ux/module-2-phases1-2-implementation.md`
