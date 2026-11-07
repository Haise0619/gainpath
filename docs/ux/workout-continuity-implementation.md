# One-time AI consent and continuous workout implementation

Implemented 7 November 2026 on `codex/hybrid-workouts`, following Member UX commit `489b6e7`. This change includes the interaction design and Flutter UI, not only controller behavior.

## Member experience

**First AI exercise:** the Member reviews the versioned AI Tracking privacy notice and explicitly accepts it. That decision is remembered for the authenticated account and organization on this device. Android camera permission, exercise setup and optional upload remain separate decisions.

**Later AI exercises:** valid privacy consent is reused. Required physical setup is still enforced. The app does not repeat the privacy agreement during normal progression or reopening a workout. Material notice changes invalidate an older consent version.

**Settings:** Profile → Settings → Privacy & AI Tracking shows consent status, privacy review, withdrawal/re-enable and Workout Preferences. Auto-Continue defaults on; suggested between-exercise rest defaults to 30 seconds and can be changed from 0 to 300 seconds. Preferences and consent are local to the account/device and are not added to workout backup.

**Between exercises:** after a successful result save and checkpoint reconciliation, the existing journey opens a full-screen rest phase. It confirms completion and local save, shows a large purple countdown and the upcoming exercise's name, mode and targets. SafeArea-anchored 56px controls provide Pause Workout/Resume Workout and Skip Rest; View routine cancels the automatic handoff. At large text sizes the upcoming name is repeated above the countdown so it remains visible without scrolling. Secondary detail remains scrollable.

**At the end of rest:** the same attempt/day/exercise context is revalidated. AI enters its existing setup/readiness engine; Video Timed opens its existing player and starts only after media readiness; Manual returns to its selected set logger without crediting a set. The final completed exercise opens the existing routine summary. With Auto-Continue off, the existing manual next-exercise sheet remains.

## Safety and implementation decisions

- `WorkoutPreferencesController` owns versioned local consent and preferences. The app-private file is isolated by encoded organization/user identifiers and written through a flushed temporary file and rename. Existing workout records and schema versions are unchanged.
- Withdrawal invalidates consent in memory synchronously, cancels pending acceptance/load races and notifies active capture guards. All nine measured route authorization closures check live consent, so revoked consent immediately makes their active scope invalid. The guard then disposes the camera route and cannot remount that session after re-enabling consent. Withdrawal does not delete saved history.
- Disk failures remain visible and fail closed for launching AI work. If a withdrawal cannot be written, the current process stays revoked and Settings asks the Member to retry before leaving. Durable withdrawal across a restart requires that retry to succeed; no disk-write success is claimed when storage is unavailable.
- Consent acceptance does not enable summary upload, backup, Coach sharing or Android permission. Existing optional upload remains a separate per-session opt-in; automatic entry never invents an upload choice.
- The rest controller is monotonic, foreground-only and single-flight. It writes no exercise evidence. Suggested rest is never inferred from per-set rest. An optional explicit published `betweenExerciseRestSeconds` value (0–600 seconds) takes precedence and is labelled prescribed; missing values use the Member's suggested default. Optional values survive routine snapshots without changing existing exercise signatures or schema versions. This task adds no Admin authoring or backend deployment.
- Existing `RoutineJourneyController` owns saves, completion, next selection and Program identity. Route orchestration adds one in-flight launch gate and checks account, attempt, day, selected exercise, foreground and current route after asynchronous preparation. A failed save cannot enter rest or advance.
- Lifecycle interruption pauses rest; foreground return does not resume its countdown until an explicit action. Invalid account/attempt context permanently cancels that rest handoff. Navigation away retains saved work and cancels automatic progression.
- An interruption while consent/preparation is saving invalidates that launch even if the app returns to foreground before the save finishes. Interrupted manual saves retain the saved set but do not open rest. Timed loading does not auto-start after an interruption or route obscuring.
- After an interruption during an exercise, existing explicit workout resume remains available. Automatic handoff for that exercise is cancelled; after saving/completing, the Member explicitly continues from the journey or timed completion screen. This conservative exception prevents a completed in-flight save from unexpectedly starting capture after an interruption.
- Rest is transient convenience state, not a new persisted workout contract. App termination/reopening returns through the existing compatible checkpoint and explicit Member action; it never restarts a countdown or camera in the background.
- Exercise-specific arm/leg selection, angle, wall/floor contact, camera positioning and calibration remain required wherever the existing tracker requires them. Automatic progression prepares those screens rather than bypassing them. This means some AI transitions still require physical setup confirmation. No camera is initialized by the rest screen.
- Pose estimation, thresholds, repetition rules, timer work-credit logic, per-set rest logic, history, enrollment, backups, reward restrictions and Module 13 exclusions are preserved. Phase feedback is visual; no voice subsystem or dependency was added.

## Verification

- **181 tests passed, zero failed**, across 36 affected regression files. This is an affected Mobile suite, not a claim that the entire monorepo ran.
- A separate existing camera permission-denial regression also passed, confirming denied permission still stops capture without fabricated pose data.
- Strict Flutter analysis: **no issues in 40 changed Dart files**.
- Additional opt-in normal/large-text rest rendering passed; fresh renders were inspected. Rest and Settings widgets cover 360×640, 200% text and bottom safe-area padding.
- Coverage includes first consent, durable restart, account/organization isolation, consent version changes, withdrawal, failed writes/retry, pending grant/load races, active guard disposal and Android permission/readiness regressions.
- Progression tests cover saved AI → AI, AI → Timed, timed success/save failure, explicit Manual logging, final summary, pause/resume/Skip Rest, Auto-Continue off, duplicate-attempt/session prevention, delayed preparation obscured/backgrounded, manual save interruption and consent persistence interruption. AI route handoff tests use test-only measured fixtures saved through the actual session repository; they do not establish physical pose accuracy.
- Focused reviews identified asynchronous launch and interruption gaps; those gates were corrected and pinned by regression tests before the final run.
- Final Android debug build: **passed**. No new APK installation or physical-device acceptance is claimed. Existing device data and unsaved activity were not interrupted.

Private logs, test/file manifests, source hashes, rendered previews and APK evidence are under ignored `build/workout-continuity-20261107/`. The APK represents the current checkout, including pre-existing pose instrumentation outside this feature; unrelated Admin/pose edits are excluded from the feature commit.

## Remaining device verification

When the approved phone is idle, update in place without clearing data and verify mixed routines, real permission revocation, lock/background interruptions, video loading/buffering recovery, required side/angle changes and withdrawal during capture. Check TalkBack traversal, gym-distance readability, one-handed controls and system safe areas. Automated tests and screenshots do not replace those checks.

## Exact files

The following implementation and test paths are relative to the repository root. Operational notes and the implementation plan are also updated; unrelated pending changes are preserved.

- `apps/mobile/lib/app/di/workout_preferences_factory.dart`
- `apps/mobile/lib/app/di/workout_preferences_io.dart`
- `apps/mobile/lib/app/di/workout_preferences_stub.dart`
- `apps/mobile/lib/app/routing/between_exercise_rest_route.dart`
- `apps/mobile/lib/app/routing/calf_raise_workout_route.dart`
- `apps/mobile/lib/app/routing/curl_workout_route.dart`
- `apps/mobile/lib/app/routing/exercise_tracker_route.dart`
- `apps/mobile/lib/app/routing/floor_push_up_workout_route.dart`
- `apps/mobile/lib/app/routing/guided_timed_workout_route.dart`
- `apps/mobile/lib/app/routing/lateral_raise_workout_route.dart`
- `apps/mobile/lib/app/routing/real_squat_route.dart`
- `apps/mobile/lib/app/routing/reverse_lunge_workout_route.dart`
- `apps/mobile/lib/app/routing/routine_journey_route.dart`
- `apps/mobile/lib/app/routing/row_workout_route.dart`
- `apps/mobile/lib/app/routing/shoulder_press_workout_route.dart`
- `apps/mobile/lib/app/routing/wall_push_up_workout_route.dart`
- `apps/mobile/lib/app/routing/workout_prep_route.dart`
- `apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart`
- `apps/mobile/lib/features/workout/application/between_exercise_rest_controller.dart`
- `apps/mobile/lib/features/workout/application/workout_preferences_controller.dart`
- `apps/mobile/lib/features/workout/domain/published_routine_view.dart`
- `apps/mobile/lib/features/workout/domain/routine_attempt.dart`
- `apps/mobile/lib/features/workout/presentation/member/between_exercise_rest_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart`
- `apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_ai_consent_guard.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_privacy_settings_screen.dart`
- `apps/mobile/lib/infrastructure/local/file_workout_preferences.dart`
- `apps/mobile/lib/navigation/workout_navigation.dart`
- `apps/mobile/test/between_exercise_prescription_test.dart`
- `apps/mobile/test/between_exercise_rest_render_test.dart`
- `apps/mobile/test/between_exercise_rest_test.dart`
- `apps/mobile/test/member_journey_ux_test.dart`
- `apps/mobile/test/privacy_and_data_settings_test.dart`
- `apps/mobile/test/real_workout_ui_test.dart`
- `apps/mobile/test/timed_continuity_test.dart`
- `apps/mobile/test/workout_continuity_flow_test.dart`
- `apps/mobile/test/workout_preferences_test.dart`
- `apps/mobile/test/workout_privacy_settings_test.dart`
