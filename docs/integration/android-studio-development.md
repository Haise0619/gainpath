# Run GainPath from Android Studio

Open the repository root (the folder containing `pubspec.yaml` and `apps`) with the Flutter and Dart plugins enabled. The shared configurations live in `.run`. Reopen the project if Android Studio was open when they were added.

| App | Run configuration | Device |
| --- | --- | --- |
| Member | **GainPath Member — Android** | A running Android Emulator, or a USB-debugging-enabled Android phone |
| Admin | **GainPath Admin — Chrome** | **Chrome (web)** |

Click the green **Run ▶** button. Android Studio compiles the current local Dart source in debug mode. Start an emulator from Device Manager if no Android device is listed. For Dart UI edits, save and click **Flutter Hot Reload** (lightning icon). Use **Hot Restart** to rerun app initialization. Stop and Run again for launch-argument, dependency or native changes.

Both launchers use the existing `gainpath-0619` Firebase project. Sign in with the appropriate existing Member or Admin account. The Android configuration uses debug App Check and retains the existing workout backup and check-in build flags. A new emulator or phone may need its own approved Android App Check debug registration for enforced Firebase operations.

The Admin configuration reads the existing private `build/local-run/admin.firebase.json` file. If it is missing, run `node tools/admin_web/prepare-ide.cjs` once from the root using the existing approved App Check fixture. On another checkout, set `GAINPATH_ADMIN_APP_CHECK_FIXTURE` to the path of that private fixture before running the helper. The generated file is git-ignored. Keep it private and retain the normal Firebase Auth sign-in. Flutter starts its own development server at `http://localhost:7361`; no separate preview server or release build is required.

Open **Recommendations** after signing in to see the monitoring interface. The UI comes from local Dart source, while Firebase reads and actions still use the deployed backend. Automatic FYP delivery and receipt-backed statuses depend on the backend activation described in [Module 13 activation](module13-workout-automatic.md#release-scope-and-rollback).
