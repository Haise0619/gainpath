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
