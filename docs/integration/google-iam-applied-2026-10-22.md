# Google integration IAM application — 2026-10-22

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Owner approved the exact reviewed IAM proposal with “proceed”. Applied and independently read back:

- Runtime service account: `gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com`; zero user-managed keys.
- Four custom roles and their exact approved permissions: `gainpathGoogleIdentityRead`, `gainpathGoogleFirestore`, `gainpathGoogleSecretCreate`, `gainpathGoogleTokenVault`.
- Four project bindings to that runtime account, including the default-database condition and token-secret prefix condition from `google-gym-iam-proposal.json`.
- `roles/secretmanager.secretAccessor` bound only on `GOOGLE_GYM_CLIENT_SECRET`.
- Original pre-change and final policies compared: unrelated bindings and audit configurations preserved. No new Owner, Editor, Token Creator or Secret Manager Admin grants.
- Existing deployer has `iam.serviceAccounts.actAs`; no deployer grants added.
- Client-secret version 1 remains ENABLED. No secret payloads read.
- All 46 existing Functions retained their state/revision. The three proposed Google Functions remain undeployed.

An initial comparison failed because Google reordered condition JSON properties. Canonical comparison and fresh readback passed. No runtime impersonation or live provider operation was performed; actual runtime permission behavior remains a deployment/UAT check.

OAuth callback: `https://us-central1-gainpath-0619.cloudfunctions.net/googleGymOAuthCallback`.
Scopes: `openid`, `email`, `https://www.googleapis.com/auth/calendar.app.created`, `https://www.googleapis.com/auth/gmail.send`.
Account/test user/support: `owner-google-account-redacted@example.invalid`.
Registered callback, External/Testing audience and test-user configuration remain owner-confirmed; independent Console readback remains pending.

Separate deployment proposal, not approved or executed:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --only functions:googleGymConnectionCommand,functions:googleGymOAuthCallback,functions:syncGymBookingCommand --non-interactive
```

No Google account connection, Calendar creation, email delivery or booking changes occurred. Initial synchronization remains Admin-triggered. Account consent and real Calendar/Gmail UAT require separate approval after deployment.
