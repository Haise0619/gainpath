# GainPath Module 2 Phase 5A — Software reliability and release readiness

The verified source is `e8b0dd475c780cea8d4e57458dd7a3feb266c727`. Checkpoint changes are in `216d2bf4d3c0da4f87a22718466b6f35de9a2ca6`.

## Issues resolved

- The routine store used a wall-clock microsecond timestamp as its compare-and-set revision. A write with the same timestamp could change progress while leaving the revision unchanged, allowing a stale view to pass the next comparison. A backward clock step could also reject a legitimate update. Both cases failed deterministically before the fix.
- Checkpoint copies now use the greater of the current wall-clock time and the prior revision plus one. Under the existing file lock, the store checks the expected revision and requires each replacement to advance it. Existing serialized fields and backup contracts remain compatible. The logical update timestamp can briefly run ahead of the wall clock. Exercise result timestamps and measured evidence keep their existing sources.
- The clean checkout exposed a missing `EquipmentImage.extension` getter referenced by the in-memory routine cover preview. That getter existed only in unrelated local changes. The preview now uses the image's existing validated MIME type.

## Regression coverage

Simulated trajectories exercise Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press through rep and set completion and next-set preparation. The combined suite covers manual and automatic continuation, Full Coaching, Alerts Only and Muted, camera failures and recovery, pause/resume/stop, app lifecycle, consent withdrawal and account changes. Routine and persistence tests cover mixed AI/timed/manual journeys, summary, local save retry, backup restore and recovery without duplicate credit. Widget tests include 320px and 360px short sides, 200% text and landscape. Coverage comes from cooperating session, widget, route and persistence tests.

The new deterministic tests exercise equal revisions, a checkpoint loaded after clock rollback, and 32 concurrent write contests between distinct file-store instances. Each contest checks one winner, a strictly advancing revision and the winning payload on disk. The stale controller regression also checks recovery after reopening.

## Verification

| Environment | Result |
| --- | --- |
| Original workspace with unrelated edits | 30 focused checkpoint, routine and backup tests passed. |
| Detached clean worktree, default Mobile configuration | 415 passed across 62 test files. 21 feature-flagged cases skipped in this configuration. |
| Detached clean worktree, Preview and diagnostic flags | 34 passed, covering all 21 default skips. |
| Detached clean worktree, full pose suite | 759 passed. |
| Detached clean worktree, checkpoint repeat | Five runs of 11 tests passed, including 160 write contests. |
| Detached clean worktree, scoped analysis | Four files analyzed. Zero errors and warnings. Ten existing brace-style infos in the checkpoint model and store. |
| Detached clean worktree, arm64 Android Debug APK | Built successfully. SHA-256 `F5E7BD03F358736A5DE853E998221D08FD6D5B50296490C2EF4A611AE783E8B0`. |

The initial clean run combined debug flags with the default suite. Six session assertions expected the default responsive preview configuration and one renderer assertion expected the default independent camera paint path. The enabled diagnostics select a different preview/render path. Those seven cases passed in the default run. The eighth failure was the missing routine cover getter. The backup integration test passed after the compile fix. The Phase 4 workspace manifest also listed `pose_runtime_timing_test.dart`, an unrelated untracked fixture absent from the verified source.

From a fresh checkout with the Flutter and Android toolchains available, run `flutter pub get` at `apps/mobile` to resolve the workspace. Use the default configuration for the Mobile manifest below. Run the Preview and diagnostic tests separately with `GAINPATH_POSE_PREVIEW`, `GAINPATH_POSE_QUALITY_DEBUG`, `GAINPATH_POSE_JOINT_LAG_DEBUG` and `GAINPATH_POSE_REFINED_SKELETON` set to `true` using `--dart-define`. The three files are `test/workout_preview_launch_test.dart`, `test/pose_preview_controller_test.dart` and `test/pose_refined_skeleton_test.dart`. Run `dart test` in `packages/gainpath_pose` and `flutter build apk --debug --target-platform android-arm64 --no-pub` in `apps/mobile`. Local verification logs and the APK are under `build/module2-phase5a/`.

## Phase 5B physical-device acceptance checklist

- Verify camera permission, framing and initial READY cues on all six exercises. Check front and side setup, partial reps, occlusion and reacquisition.
- Exercise set/rest boundaries with automatic continuation enabled and disabled. Confirm the required arm switch, pause/resume, tracking loss, and manual recovery.
- Test cold and warm voice startup, rep and transition timing, cancellation, and Full Coaching, Alerts Only and Muted on speaker and Bluetooth.
- Verify foreground/background, permission or consent withdrawal, logout and account switching release the camera and suppress stale cues.
- Run mixed AI/timed/manual routines offline, interrupt and recover, then confirm one summary and one local result per completed capture.
- Check 2–3 metre readability, large text, insets and landscape. Follow the Phase 3 physical procedure for frame timing, resource and thermal measurements. [Phase 3 procedure](module-2-phase3-rendering.md#remaining-physical-baseline)

No physical device or installation was used. Real camera, acoustic, thermal and end-to-end device performance remain open.

## Modified files

- `apps/mobile/lib/features/workout/domain/routine_journey.dart`
- `apps/mobile/lib/infrastructure/local/file_routine_journey_store.dart`
- `apps/mobile/test/routine_attempt_test.dart`
- `packages/gainpath_data/lib/src/workout/in_memory/in_memory_routine_template_repository.dart`
- This report and the repository's operational references.

## Default Mobile test manifest

Run the listed paths together with `flutter test --no-pub` from `apps/mobile`.

```text
test/android_workout_audio_test.dart
test/between_exercise_prescription_test.dart
test/between_exercise_rest_test.dart
test/blazepose_asset_cache_test.dart
test/blazepose_contract_test.dart
test/blazepose_geometry_test.dart
test/blazepose_gpu_test.dart
test/blazepose_preprocessing_equivalence_test.dart
test/calf_raise_workout_session_test.dart
test/curl_workout_session_test.dart
test/features/workout_account_scope_test.dart
test/features/workout_pose_persistence_test.dart
test/features/workout_sync_test.dart
test/file_workout_voice_preferences_test.dart
test/firebase_workout_backup_negotiation_test.dart
test/floor_push_up_voice_feedback_test.dart
test/floor_push_up_workout_session_test.dart
test/guided_timed_workout_controller_test.dart
test/guided_timed_workout_flow_test.dart
test/guided_workout_flow_test.dart
test/guided_workout_progress_test.dart
test/hybrid_routine_journey_test.dart
test/lateral_raise_session_test.dart
test/live_camera_workout_accessibility_test.dart
test/pose_failure_recovery_test.dart
test/pose_preview_authorization_test.dart
test/pose_preview_controller_test.dart
test/pose_refined_skeleton_test.dart
test/pose_rendering_test.dart
test/pose_viewport_render_efficiency_test.dart
test/pose_worker_termination_test.dart
test/real_squat_session_test.dart
test/real_workout_outbox_test.dart
test/retained_auto_set_continuation_test.dart
test/retained_session_lifecycle_test.dart
test/retained_voice_boundary_test.dart
test/retained_workout_feedback_test.dart
test/reverse_lunge_session_test.dart
test/routine_attempt_test.dart
test/routine_journey_controller_test.dart
test/routine_journey_flow_test.dart
test/row_workout_session_test.dart
test/shoulder_press_session_test.dart
test/squat_processing_controller_test.dart
test/wall_push_up_workout_session_test.dart
test/workout_audio_controller_test.dart
test/workout_audio_lifecycle_test.dart
test/workout_backup_integration_test.dart
test/workout_backup_scheduler_test.dart
test/workout_backup_test.dart
test/workout_camera_sheet_test.dart
test/workout_continuity_flow_test.dart
test/workout_feedback_event_test.dart
test/workout_launch_contract_test.dart
test/workout_performance_diagnostics_test.dart
test/workout_preferences_test.dart
test/workout_preview_launch_test.dart
test/workout_privacy_settings_test.dart
test/workout_set_continuation_test.dart
test/workout_voice_readiness_test.dart
test/workout_voice_status_ui_test.dart
test/workout_backup_local_store_test.dart
```
