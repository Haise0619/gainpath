# Workout backup availability — 15 November 2026

The owner observed “Cloud sync is unavailable in this build” instead of the sync switch. The backup factory's build flag defaulted to false, despite the backend now being deployed. The two saved root launch configurations already explicitly enable it, but a build without those arguments still hides the feature. The installed phone build and its launch arguments were not inspected, so an old APK versus another launch configuration is not conclusively distinguished.

Changed only `workout_backup_factory.dart` to default `WORKOUT_CLOUD_BACKUP_ENABLED` to true. This exposes the optional backup settings in ordinary `main.dart` builds. The persisted per-member sync choice, explicit confirmation, account isolation and recommendation-purpose consent remain unchanged. No automatic consent grant, existing-history upload or Firebase configuration change is part of this fix. An explicit false build define remains available outside emulator mode.

Verification:

- Added a normal-build regression test and observed its expected failure (`false` instead of `true`) before changing the default.
- 30 affected tests pass: availability, opt-in/cancel, disabling sync, offline retries, scheduler and sync product behavior.
- Focused two-file Dart analysis: no issues.
- Android Debug build from clean committed source plus only this factory change: passed, without supplying the backup build define. Unrelated in-progress Workout UI/assets were excluded. Dependency lock hashes match the repository.
- Evidence and isolated APK: `build/workout-backup-default-20261115/`. The source manifest records the base commit and exact patch hash.
- ADB reported no connected devices. No phone installation or real cloud workout acceptance is claimed.

To load the fix, stop the existing run and select **GainPath Member — Android → Run** in Android Studio. Hot Reload/Hot Restart do not replace compile-time build values in the installed binary. Then navigate **Workout → Settings → Data & backup → Workout backup**, turn on **Automatic workout sync**, and confirm **Enable backup**. Recommendation-purpose permission remains a separate Member choice.

## Follow-up: direct settings route lost backup state

The owner still observed the same message after the build-default correction. Further inspection established an independent navigation bug: Workout Settings opens `MemberProgressRoute(view: backup)`. Its builder called `_progressContent` without the Host's coordinator, initialization error or retry callback. Consequently even an initialized, authorized coordinator was rendered as missing. This is a client route defect shared by ordinary/FYP Member entrypoints, not evidence of an account permission denial. The earlier default-flag fix alone was insufficient.

Direct progress routes now reuse `_ScopedProgressPage`, the existing reactive projection used by nested navigation. It observes the same backup-state notifier and preserves Auth/cubit isolation, loading errors and retry. Added an optional backup-factory injection seam to exercise the actual direct route, without changing production authorization or synchronization logic. Goal/program builders remain forwarded.

The actual direct-route test reproduced the screenshot's exact unavailable message with an already initialized coordinator before the route fix. Afterward, both direct-success/logout and delayed-loading/failure/retry tests pass. Fresh affected regression: 34 tests passed, focused analysis has no issues, and an isolated Android Debug build passed (14.7 seconds). Evidence: `build/workout-backup-route-20261115/`. The isolated build contains only the prior default fix and this route change, with unrelated dirty Workout sources/assets excluded. No Firebase deployment, account change, consent grant, device installation or live workout acceptance was performed.
