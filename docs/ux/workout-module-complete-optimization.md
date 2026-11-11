# Complete Workout Module Optimization

Implemented 11 November 2026. Verified source and phase commits are listed below.

## Delivered architecture

Workout presents the current or next workout with its primary action first. Training plan, History and Progress are compact shortcuts inside the current-workout section. Browse and the optional multi-day Routine preview remain available. Exercise tutorials open from the selected exercise. Camera guidance and Equipment tools follow the exercise list.

History has two tabs, Routines and Exercise sessions. Both lists stay mounted when switching tabs, preserving local filters and scroll. Routine detail shows saved results and resolves its current plan association before enabling continuation. Progress retains long-term trends, supported form estimates, goals and contextual reports. Workout settings exposes workout preferences, Voice Coach, AI privacy and Data & backup. Camera permissions have Android instructions and Equipment offers a direct browsing entry alongside scanning.

## Phase 1 — State and navigation

Commit `fe792735a1c0a04f2471aed1674363792c971d6e`.

- Free-workout selection excludes attempt IDs linked to every locally retained Program enrollment, including inactive enrollments. Journey uses the same exclusion when opening free checkpoints.
- Scheduled cards display only their own progress. A new scheduled attempt has zero completed exercises and the current day's target count.
- Multi-day free cards show the day they will start or continue. Per-plan duration is omitted where a truthful per-day duration is unavailable.
- Program launch carries enrollment ID, schedule day key, routine day and exact attempt ID. Entry validates the active journal and slot. History revalidates its plan association before mutation.
- Skipped schedule slots use Make up workout. Existing completed results, skipped state, rescheduling and old enrollments retain their stored identity.

A regression reproduced a scheduled card using a free-workout denominator before the fix. A separate same-template test checks free and scheduled progress isolation and retains a scheduled record after ending its plan. The phase gate passed 56 tests. Scoped analysis had seven existing brace-style infos and zero errors or warnings.

## Phase 2 — Hub and hierarchy

Commit `ebaa71e5e4f9ea3d68ff382310acd227be06155e`.

- A compact surface replaces the decorative workout hero. The primary action precedes supporting statistics. Purple identifies the start action and contextual links.
- Training plan moves ahead of the exercise list. A selected free workout has a direct Back to planned workout action.
- A single-day free workout uses the hub's exercise list. Multi-day or scheduled viewing keeps an explicitly named Routine preview. Viewing a preview creates no workout credit.
- Starting a new routine can enter the first executable AI or timed exercise directly. A manual first exercise opens its logger. Interrupted or partial attempts remain deliberate recovery flows.
- The duplicate fixed-footer Tutorial button was removed. The contextual tutorial remains in the selected-exercise section.
- Existing Program enrollment cards and their local assets were included because the current Workout UI depends on them.

A 320dp, 200% text test reproduced the inaccessible start/low-priority-plan layout before the change. The phase gate passed 37 tests. Scoped analysis reported no issues.

## Phase 3 — Execution and recovery

Commit `0dc1e941fdb2f6ebc6285053c6871fe7440041d7`.

- Successful result saving precedes the rest countdown and next-exercise launch. Zero or very short rest retains three seconds of preparation. Pause and authorization changes invalidate automatic continuation.
- AI, timed and manual next-step copy reflects their real execution. With Auto-Continue disabled, Open set logger goes directly to the selected manual action.
- READY voice is one-shot per set in Full Coaching. Measured feedback takes priority over a READY announcement. Existing Alerts Only and Muted semantics apply.
- Camera startup is bounded. A delayed native operation remains serialized with cleanup, and retry waits for release. Back and Stop can dismiss an empty failed capture while cleanup retains ownership.
- Timed save failures expose Retry save. That action persists the same progress while keeping playback paused. Video failure and save failure have distinct actions.

The new partial-timer save regression failed before the fix. The phase gate passed 114 tests and scoped analysis reported no issues. Final review in Phase 4 restored the explicit Calf Raise floor-contact check and Floor Push-up stable-phone/clear-space acknowledgement. Their required safety choices precede capture. Lateral Raise and Shoulder Press keep live framing/readiness instructions, and Curl keeps arm selection.

## Phase 4 — History, Progress and supporting pages

Commit `c52f176b8f31d421171ff24764d6adff178a0cd7`.

- History consolidates Routines and Exercise sessions. Routines filter All, Completed and Unfinished. Single-day titles omit Day 1. Legacy record links still reach the corresponding list.
- Report, dashboard and history routine links use the same scoped detail resolver with available measured-session links. Returning from an exercise result uses Done and returns to its caller.
- Detail actions wait for plan identity resolution. A single-flight latch and current-route check prevent rapid repeated taps from opening competing Repeat attempts.
- Completed scheduled days provide View workout summary. A linked active unfinished slot resumes its exact attempt. An inactive/skipped association remains readable.
- Progress groups workout trends, goals and wellbeing, and reports/backup. Its plan CTA says Open training plan.
- Voice Coach reads and writes the existing account-local voice preference. Full Coaching, Alerts Only and Muted are available without opening capture. Failed reads and writes expose retry feedback.
- Workout Settings includes privacy state, withdrawal, Android camera-permission instructions, both Auto-Continue controls, suggested rest, voice, and local-save/backup information. Backup links are available from Workout and Journey settings.
- Browse equipment is reachable directly from Workout and retains the scoped reader and account guard. Scanning keeps its own camera and uploaded-image paths.

The phase gate passed 100 tests. Scoped analysis of 16 files reported no issues. Review also corrected journal-load failure handling so the hub publishes validated checkpoints and Program metadata together. Unknown workout state exposes Retry workout. Async scheduled starts and first-exercise launch recheck foreground and route validity.

## Verification

Per-phase gates above used the inspected workspace containing unrelated local changes. Final regression, analysis and APK evidence are produced in the detached clean worktree at `build/workout-optimization-20261111/clean`.

The first complete run found six legacy UI fixtures still expecting the old preview page, refresh tooltip, Paused label after a save failure, and explanatory copy. They were updated to exercise the new intended actions and retain the underlying history/save assertions in `acf243042702b03195f07f32b150f6faa7294df4`. A subsequent run exposed a separate ordering defect when returning to a previous routine day. The deterministic rollback fixture failed before the fix. Reopening now advances the touched checkpoint after the other compatible days, preserving the existing serialized fields. That fix is in `6f9da2ba648207244bb71d16ece63d587f1ac0a1`.

| Final verification | Result |
| --- | --- |
| Clean source at `6f9da2b`, relevant Mobile suite across 123 files | 675 passed, 28 feature-flagged cases skipped in the default configuration |
| Complete pose suite | 759 passed |
| Preview authorization and pose diagnostic configuration | 34 passed |
| Hub and rest render configuration | Five passed |
| Preview UI with Preview, quality, joint-lag and blank diagnostics enabled | Three passed, including the two remaining default skips |
| Scoped analysis of 62 changed Dart files | Zero errors or warnings, 15 existing brace-style infos |
| Preview fixture analysis after final test-only correction | No issues |
| Clean arm64 Android Debug APK at `6f9da2b` | Built successfully |

All 28 default skips are covered by the separate flag/render runs. The fresh large-text rendering shows the primary Start and Training plan actions on screen. The opt-in Preview UI run initially found an older fixture missing AuthBloc and account consent dependencies. That fixture now uses the real authorization contract and still asserts that unaccepted consent keeps the start action disabled. Its correction is `d8b9009699bb16a9bc66cec4999e6685972c0ce6`, followed by a clean-checkout targeted run.

The delivered APK is `build/workout-optimization-20261111/workout-complete-debug.apk`. SHA-256 is `3A554BF9AC5A5E1B9120C5C99595D5A46D71B8FBB030851426A23819654917C7`. Its application source matches the final commits. Later changes concern regression fixtures and this report. No APK installation was performed.

## Reproduction

Use Flutter at `C:/flutter` and an installed Android SDK. Resolve cached dependencies with `flutter pub get --offline` from `apps/mobile` in the worktree. The full relevant Mobile manifest is retained in `build/workout-optimization-20261111/clean-mobile-manifest.txt`. Run it with `flutter test --no-pub --reporter expanded`.

Run Preview and quality/refined/lag diagnostics separately in `workout_preview_launch_test.dart`, `pose_preview_controller_test.dart` and `pose_refined_skeleton_test.dart` with the existing `GAINPATH_POSE_PREVIEW`, `GAINPATH_POSE_QUALITY_DEBUG`, `GAINPATH_POSE_JOINT_LAG_DEBUG` and `GAINPATH_POSE_REFINED_SKELETON` defines. Run the complete `gainpath_pose` suite with `dart test`. Build with `flutter build apk --debug --target-platform android-arm64 --no-pub`.

## Remaining validation

Physical-device acceptance is pending. Verify real camera handoff across the six retained exercises, permission denial/retry, back/Stop during initialization, readiness and first-rep speech, speaker/Bluetooth timing, thermal and memory behavior, and repeated background/foreground transitions. At 320/360/390dp and 200% text, check safe-area controls, tab labels and portrait/landscape.

Program association is derived from the local enrollment journal. Restored results on a device without that journal remain free results where no link is known. A journal read failure leaves the saved result readable and continuation unavailable. Required floor-contact/clear-space choices remain explicit. This release uses no physical-device performance claims.

## Modified files

The following manifest covers committed application and test changes across the four phases and verification follow-ups.

```text
apps/mobile/assets/icons/tool_camera_setup.webp
apps/mobile/assets/icons/tool_saved_sessions.webp
apps/mobile/assets/icons/tool_scan_equipment.webp
apps/mobile/lib/app/routing/between_exercise_rest_route.dart
apps/mobile/lib/app/routing/lateral_raise_workout_route.dart
apps/mobile/lib/app/routing/member_progress_route.dart
apps/mobile/lib/app/routing/routine_journey_route.dart
apps/mobile/lib/app/routing/shoulder_press_workout_route.dart
apps/mobile/lib/app/routing/workout_prep_route.dart
apps/mobile/lib/app/routing/workout_program_route.dart
apps/mobile/lib/app/shells/member_shell.dart
apps/mobile/lib/features/analytics/presentation/member/activity_timeline_screen.dart
apps/mobile/lib/features/analytics/presentation/member/widgets/routine_progress_card.dart
apps/mobile/lib/features/analytics/presentation/member/workout_history_tabs.dart
apps/mobile/lib/features/analytics/presentation/shared/member_progress_overview.dart
apps/mobile/lib/features/analytics/presentation/shared/progress_dashboard_screen.dart
apps/mobile/lib/features/workout/application/guided_timed_workout_controller.dart
apps/mobile/lib/features/workout/application/pose_preview_controller.dart
apps/mobile/lib/features/workout/application/routine_journey_controller.dart
apps/mobile/lib/features/workout/application/workout_audio_controller.dart
apps/mobile/lib/features/workout/application/workout_hub_attempt.dart
apps/mobile/lib/features/workout/application/workout_program_controller.dart
apps/mobile/lib/features/workout/domain/program_enrollment.dart
apps/mobile/lib/features/workout/domain/routine_journey.dart
apps/mobile/lib/features/workout/presentation/member/between_exercise_rest_screen.dart
apps/mobile/lib/features/workout/presentation/member/guided_timed_workout_screen.dart
apps/mobile/lib/features/workout/presentation/member/published_routine_catalog_controls.dart
apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart
apps/mobile/lib/features/workout/presentation/member/routine_history_screen.dart
apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart
apps/mobile/lib/features/workout/presentation/member/routine_next_exercise_sheet.dart
apps/mobile/lib/features/workout/presentation/member/widgets/program_enrollment_cards.dart
apps/mobile/lib/features/workout/presentation/member/widgets/workout_hub_visuals.dart
apps/mobile/lib/features/workout/presentation/member/widgets/workout_session_sheet.dart
apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart
apps/mobile/lib/features/workout/presentation/member/workout_privacy_settings_screen.dart
apps/mobile/lib/features/workout/presentation/member/workout_program_screen.dart
apps/mobile/lib/features/workout/presentation/member/workout_result_screen.dart
apps/mobile/lib/features/workout/presentation/workout_presentation.dart
apps/mobile/test/between_exercise_rest_test.dart
apps/mobile/test/guided_timed_workout_flow_test.dart
apps/mobile/test/live_camera_workout_accessibility_test.dart
apps/mobile/test/member_local_progress_flow_test.dart
apps/mobile/test/member_progress_route_test.dart
apps/mobile/test/member_routine_discovery_flow_test.dart
apps/mobile/test/pose_failure_recovery_test.dart
apps/mobile/test/pose_preview_ui_test.dart
apps/mobile/test/published_routine_test.dart
apps/mobile/test/routine_completion_actions_test.dart
apps/mobile/test/routine_history_ui_test.dart
apps/mobile/test/routine_journey_controller_test.dart
apps/mobile/test/routine_journey_flow_test.dart
apps/mobile/test/timed_continuity_test.dart
apps/mobile/test/workout_audio_controller_test.dart
apps/mobile/test/workout_continuity_flow_test.dart
apps/mobile/test/workout_hub_attempt_test.dart
apps/mobile/test/workout_hub_dashboard_test.dart
apps/mobile/test/workout_hub_program_test.dart
apps/mobile/test/workout_hub_render_test.dart
apps/mobile/test/workout_hub_state_copy_test.dart
apps/mobile/test/workout_hub_visual_refresh_test.dart
apps/mobile/test/workout_phase4_ux_test.dart
apps/mobile/test/workout_presentation_test.dart
apps/mobile/test/workout_privacy_settings_test.dart
apps/mobile/test/workout_program_controller_test.dart
apps/mobile/test/workout_program_redesign_test.dart
```
