# GainPath Module 2 Phase 4 — Workout continuity

Phase 4 covers Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press. The implementation builds on the verified consent, tracking, audio and skeleton rendering work from Phases 0–3.

Implementation commit `2c6e3db4d99c0fbb2213d0bcc8c4f91964d5ae03`.

## Between-set continuation

**Auto-Continue Between Sets** is an account-scoped option in workout privacy settings. It defaults off, including for older local preference files. **Auto-Continue Between Exercises** remains a separate control for the routine's existing exercise handoff.

After the set rest expires, the camera prompts the member to hold the exercise's starting pose. A separate in-memory analyzer checks the existing calibration rules on fresh delivered frames. Once it verifies a neutral pose, the member sees a three-second countdown. The countdown requires continuously valid pose evidence and a fresh qualifying frame at expiry. The normal next-set action starts the live analyzer. It performs its existing calibration check and the display shows **READY** only when live analysis is ready. The preparation announcement says “Hold steady. Wait for ready.” The countdown and readiness check add no repetitions, form estimates, tracked duration or saved evidence.

The optional upright side-view check uses paired landmarks to reject a clearly frontal or ambiguous view. It is a conservative readiness check for automatic start. Existing exercise counting thresholds and manual setup rules still govern tracking. Front-view and floor exercises use their existing geometry and starting-pose checks. A member can start manually when automatic readiness cannot be verified.

An interrupted preparation stays cancelled for that rest. Pause, background, geometry or model change, scope or consent loss, and loss of fresh tracking during the countdown all prevent automatic start. Explicit manual continuation still uses the session's existing controls. A two-arm Curl keeps its deliberate switch and manual next-set start. A new exercise follows its own positioning or arm selection flow. Between sets, the same exercise stays on the same camera and avoids reopening a setup screen.

## Transition speech

| Mode | Behavior |
| --- | --- |
| Full Coaching | Can announce set completion and rest in one cue, rest ending, preparation and workout completion. A routine with another exercise says “Exercise complete.” |
| Alerts Only | Keeps actionable corrections and warnings. Routine transition announcements are quiet. |
| Muted | Speech stays silent. The visual counter, readiness and rest states carry the instructions. |

Transition announcements use the existing arbitration, one-shot freshness window and native start deadlines. A busy voice channel drops the transition cue. Pause, source loss, authorization change and rest exit invalidate pending or active rest speech, including the coalesced set boundary cue. A final result saves locally before the existing bounded audio settlement.

The between-exercise rest screen can announce “Get ready for” the next exercise in the last five seconds when at least three seconds remain. This uses the saved local Full Coaching mode when either adjacent step is a retained tracker. An absent local voice preference leaves this cue silent. Timer and manual steps keep their execution and credit rules. The cue cancels when the route pauses, becomes obscured, loses authorization or exits, and route advancement does not wait for it.

## Live workout layout

The camera remains the main surface. The counter emphasizes current reps and set progress, and it switches to rest or preparation seconds at the appropriate boundary. High-contrast status text distinguishes setup, calibration, readiness, tracking loss, pause and camera failure. The active view shows one prioritized correction. The camera instructions distinguish front and side views, name the joints to keep visible, and describe the exercise's starting pose. Floor Push-up keeps its stable cue through a brief recoverable dropout.

Pause, Resume, Stop, manual next-set and retry controls stay available in the relevant states. Portrait uses a measured, scrollable detail sheet with safe-area padding. Landscape reserves a separate side panel beside the camera. The camera subtree keeps the Phase 3 repaint boundary while workout controls and status change. The narrow-screen layout accommodates 200% text and compact camera realignment.

## Affected files

- Application continuation and readiness helpers, the six retained workout sessions, Squat processing and the shared audio controller under `apps/mobile/lib/features/workout/application/`.
- Account-scoped workout preferences, the AI consent guard and workout privacy settings.
- `real_workout_view.dart`, `workout_session_sheet.dart`, `workout_camera_feedback.dart` and `workout_alignment_guide.dart`.
- `between_exercise_rest_route.dart` and `routine_journey_route.dart` for voice on saved-result handoff.
- Regression fixtures for continuation, voice, settings, mixed journeys, narrow screens and the existing Curl, guided save and guided timed paths. The scoped manifest is in `build/module2-phase4-20261111/dart-files.txt` in the local workspace.

## Verification and remaining device validation

The local regression matrix covers 320px and 360px short sides, 100%, 150% and 200% text, portrait and landscape, and simulated system insets. Additional checks cover loading, tracking loss, camera retry, voice unavailable and muted, and rest controls. Deterministic trajectories exercise successful continuation on all six trackers. Lifecycle tests cover tracking loss, silence, geometry change, pause, background and withdrawal during preparation. Mixed-mode tests cover camera confirmation, timed handoff and deliberate manual completion.

| Verification | Result |
| --- | --- |
| Affected Mobile tests, serial default run | 406 passed across 62 files. The 21 feature-flagged cases were skipped in this configuration. |
| Preview authorization and pose diagnostic tests with flags enabled | 34 passed, including the 21 cases skipped above. |
| Full `gainpath_pose` suite | 759 passed. |
| Scoped Flutter static analysis | 30 Dart files, no issues. |
| Android arm64 Debug APK | Built successfully. Local artifact is `build/module2-phase4-20261111/phase4-app-debug.apk`. SHA-256 is `1AB95127DB3498D8CBCA79E8886316E6C85207134DF00EA476A17ACD715B0EE4`. |

The timed-workout accessibility fixture now advances its monotonic and UTC clocks together and asserts the elapsed time after Pause. An earlier parallel run intermittently failed the existing stale-checkpoint assertion. The serial run passed that case. The existing store uses a wall-clock timestamp as its revision and remains susceptible to equal timestamps. The checkpoint contract is outside Phase 4's scope.

Tests and build used the local workspace with its existing unrelated changes. The implementation commit contains only the Phase 4 changes. Verification logs are in `build/module2-phase4-20261111/`.

Physical Android testing was unavailable for this phase. Device acceptance still covers readability at 2–3 metres, real camera framing and recovery, whether the side-profile readiness check admits typical valid poses, audible cue timing and comprehension, and repeated rest and mixed-exercise transitions. The Phase 3 baseline procedure remains the source for physical timing and resource measurements. [Phase 3 report](module-2-phase3-rendering.md)
