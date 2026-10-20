# Firebase Forgot Password fix

The user reported that Forgot Password never delivered an email in the installed Firebase APK. The cause was executable UI logic, not a demonstrated mail-delivery failure: `gainpath_ui`'s sheet delayed 900 ms and displayed a success message without any backend operation. It also asserted an unsupported 15-minute expiration.

## Bounded change

- [Shared recovery sheet](../../packages/gainpath_ui/lib/src/account/forgot_password_sheet.dart) accepts an asynchronous sender and presentation-safe failure. It awaits the request, disables duplicate sends/input while pending, shows retryable failures, retains resend cooldown and handles disposal. Neutral success says a link has been requested if an account exists; it does not guarantee delivery or reveal account existence. The default mock flow explicitly says no email was sent. Removed the unsupported expiry claim.
- [LoginScreen](../../apps/mobile/lib/features/identity/presentation/shared/login_screen.dart) passes the callback and converts domain `AuthException` to a safe sheet error.
- [Mobile composition](../../apps/mobile/lib/app/mobile_app.dart) provides a real sender only in Firebase mode; an injection seam supports isolated tests. [Named routes](../../apps/mobile/lib/app/routing/app_routes.dart) use the same configured login builder, including unauthorized role fallbacks. Existing mock routing API remains available.
- [FirebasePasswordResetActions](../../apps/mobile/lib/infrastructure/firebase/firebase_password_actions.dart) calls `FirebaseAuth.sendPasswordResetEmail` with a trimmed address. It maps invalid-address/network/rate failures, and treats `user-not-found` like Firebase's neutral enumeration-protected outcome. Existing authenticated Change Password behavior remains untouched.
- [Focused tests](../../apps/mobile/test/password_reset_test.dart) cover SDK operation/delegation, neutral missing-user handling, transport/rate failure, root/named login callback binding, pending-request behavior, success/error/retry, resend and invalid input.

No pose analysis, consent/outbox contract, account provisioning, Firebase resource, server deployment or CI policy was changed. The earlier dashboard work remains present. Admin password-reset backend wiring is outside this mobile fix; its shared sheet now truthfully identifies the unconnected demo flow.

## Evidence

- Root-cause reproduction: four focused tests failed after adding only the API seam (no SDK call, no sender call, no failure response). All passed after implementation.
- Review found that named login routes omitted the callback; a separate failing route regression reproduced this, then passed after composition correction. Review confirmed the correction with no blocking findings.
- Final full mobile suite: **289 passed, 15 optional diagnostics skipped, zero failed**. Six focused reset tests are included.
- Shared UI package: **1 passed**. Admin app regression suite: **9 passed**.
- Changed-source/test analysis: **No issues found**. Diff whitespace check passed.
- Architecture checker: same **21 existing findings**, exit 1; no additional reset-flow boundary finding. The pre-existing CI architecture failure was not bypassed.

SDK tests use isolated injected callbacks/fake Firebase Auth objects. No account was created and no verification/reset email was automatically sent by the agent. Automated tests establish callback/SDK invocation and UI behavior, not actual inbox delivery.

## Phone update

A fresh profile APK was built and installed with `adb install -r` on Xiaomi 23013RK75C (`7c4cbff`) at **2026-10-13 17:10:45 Malaysia time**. Installation returned Success and app launch was issued. Existing package first-install time remained 2026-10-01 19:09:19; no uninstall or app-data clearing occurred. Package version remains 0.1.0 / code 1, so the build is identified by artifact hash.

The APK retains the preceding phone's Firebase development/profile, performance logging, experimental GPU and direct-refined-preview defines. It does not enable decision/3D diagnostics or trusted workout tuples.

```powershell
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true
```

Ignored local artifacts:

- `apps/mobile/build/password-reset-install/gainpath-firebase-password-reset-profile.apk`
- SHA-256: `AF9B3AB15CFD58284493C35FD5A044EE47361A6A5E741CBD33108DC326A3612D`
- Actual prior installed dashboard APK retained at `apps/mobile/build/password-reset-install/previous-installed.apk`.
- Build log: `apps/mobile/build/password-reset-apk-build.log`; mobile tests: `apps/mobile/build/password-reset-tests.log`.

Next manual check: on the updated app, choose Forgot Password, enter the registered account's address and tap Send reset link. Check inbox/spam and complete the Firebase-hosted reset link; then sign in with the new password. Receipt/link completion remains unverified until that user test. No other module implementation began.
