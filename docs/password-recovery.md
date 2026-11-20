# GainPath password recovery

The Android opt-in uses one callable in `asia-southeast1`. Active Member and Coach profiles with Firebase password credentials are eligible. The Firebase email-link option remains available, including for Admin and Staff accounts.

## Local acceptance

From the repository root, run these commands after installing the existing workspace dependencies.

```powershell
pnpm --dir functions run build
firebase emulators:exec --project demo-gainpath --config firebase/coach-availability.emulator.test.json --only auth,firestore "node functions/emulator/password-recovery.cjs"
Set-Location apps/mobile
flutter test test/password_recovery_screen_test.dart test/password_reset_test.dart test/firebase_auth_error_test.dart
flutter build apk --debug --dart-define=ENABLE_PASSWORD_RECOVERY_OTP=true
```

The emulator suite captures email in memory. For a hands-on test after approved deployment, use an eligible test account and an inbox you control. Open Forgot password, send a code, paste it into the six cells, and set and confirm a new password. Sign in with the new password and verify your account details. Try an incorrect code, resend after the timer, and verify that the earlier challenge cannot be reused. The email-link option can be tested independently.

## Brevo and Firebase setup

1. Create a [Brevo Free account](https://www.brevo.com/) and add and verify a sender email address you control. Brevo can substitute its own sending address for unauthenticated domains. Use the verified address as `BREVO_SENDER_EMAIL` in the Functions project-specific environment configuration. Set the sender display name to GainPath in Brevo, and disable open and click tracking for transactional messages.
2. Create a transactional API key in Brevo. After authorization, enter it through `firebase functions:secrets:set BREVO_API_KEY --project PROJECT_ID`. Set `PASSWORD_RECOVERY_HMAC_KEY` with the same command using a different value generated from at least 32 cryptographically random bytes. Keep both values in Secret Manager.
3. Optional production logo configuration uses `PASSWORD_RECOVERY_LOGO_URL`. Point it to a public HTTPS copy of the existing `apps/mobile/assets/images/achievement_gainpath_logo.png` asset at a stable URL you control. GainPath remains visible as text when the image is blocked. The local preview uses that asset directly.
4. Verify the selected Firebase project’s deployed Firestore rules deny all client reads and writes under `passwordRecovery`. The checked-in rules deny this unmatched collection by default. The runtime service account needs Firestore document access, Firebase Auth user read/update access including refresh-token revocation, and Secret Manager accessor on the two specific secrets. The callable needs unauthenticated transport invocation for signed-out users, with Firebase App Check enforced at the callable. Review and authorize any missing grants before deployment.
5. After approval, build the Functions code and deploy only `functions:passwordRecovery` to the confirmed project. Verify the App Check policy using an enrolled test build and approve a test email before enabling the mobile build flag for users. In Android Studio, put `--dart-define=ENABLE_PASSWORD_RECOVERY_OTP=true` in the mobile run configuration’s additional arguments to enable the flow. Omit the flag to roll back to the Firebase link flow.

Brevo documents a 300-send daily Free quota. The callable reserves at most 250 delivery attempts across its rolling hour buckets, leaving headroom for this project’s other usage. Firebase and Brevo configuration and delivery verification require separate owner authorization. [Brevo Free quotas](https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan) · [Brevo sender policy](https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders) · [Firebase secret setup](https://firebase.google.com/docs/functions/config-env)
