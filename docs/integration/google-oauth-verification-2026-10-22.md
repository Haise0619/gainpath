# OAuth verification and final IAM approval — 2026-10-22

Project: gainpath-0619 (879719977530). Gym OAuth owner, Gmail sender, support/developer contact and sole proposed test user: owner-google-account-redacted@example.invalid.

## Verified independently

- Supplied nonsecret Web OAuth client ID is saved as GOOGLE_GYM_CLIENT_ID: 879719977530-ifb9qd1nqogi0kf79vm5mcqbesno530j.apps.googleusercontent.com. Its project-number prefix matches gainpath-0619. Other existing environment settings were preserved.
- GOOGLE_GYM_CLIENT_SECRET exists in the correct project. Version 1 is ENABLED. Only metadata and IAM bindings were read, never its value. This cannot establish that the private value matches the client; that is tested only during separately approved OAuth consent.
- Calendar and Gmail APIs remain enabled.
- Callback source/export/region and local environment agree on https://us-central1-gainpath-0619.cloudfunctions.net/googleGymOAuthCallback. All three local exports use the proposed dedicated runtime account and only GOOGLE_GYM_CLIENT_SECRET binding.
- The implemented requested scopes are exactly openid, email, https://www.googleapis.com/auth/calendar.app.created and https://www.googleapis.com/auth/gmail.send. Google's userinfo.email alias is normalized.
- Both IAM conditions below passed Google's policy linter with no findings. Effective runtime authorization cannot be verified until approved roles/bindings exist.
- The runtime account and custom roles still do not exist; there are no bindings for the proposed account. All three Google Functions are absent from production (46 existing Functions recorded).

## Owner-confirmed Console settings

The owner reports the dedicated client was created with External/Testing, the four scopes and exact callback. Intended sole test user is owner-google-account-redacted@example.invalid. Independent Console read-back remains incomplete: the available in-app session still uses the former student account and receives insufficient project access, even after the owner reported switching accounts; no accessible project-owner Cloud tab was found in Chrome. No access was granted to the student account. This does not invalidate the user's setup report, but must not be described as an independent Console verification. Read back client type/redirect/audience/test-user list in the owner session before eventual deployment approval. No secret-value read is needed.

## Final IAM proposal — approval required; nothing applied

Create gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com without user-managed keys. Create and bind only these project custom roles to that account:

| Exact role under projects/gainpath-0619/roles/ | Exact included permissions | Resource scope |
| --- | --- | --- |
| gainpathGoogleIdentityRead | firebaseauth.users.get | Project gainpath-0619; no condition. |
| gainpathGoogleFirestore | datastore.databases.get; datastore.entities.get; datastore.entities.create; datastore.entities.update | Project binding with condition A; only default database. |
| gainpathGoogleSecretCreate | secretmanager.secrets.create | Project gainpath-0619; no condition. |
| gainpathGoogleTokenVault | secretmanager.versions.add; secretmanager.versions.access; secretmanager.secrets.delete | Project binding with condition B; only GainPath token-secret prefix. |

Condition A, title gainpath_default_database_only:

```cel
resource.name == 'projects/gainpath-0619/databases/(default)'
```

Condition B, title gainpath_google_token_secrets_only:

```cel
resource.service == 'secretmanager.googleapis.com' &&
(resource.type == 'secretmanager.googleapis.com/Secret' ||
 resource.type == 'secretmanager.googleapis.com/SecretVersion') &&
resource.name.startsWith('projects/879719977530/secrets/gainpath-google-')
```

Additional binding: roles/secretmanager.secretAccessor for that runtime account on ONLY projects/879719977530/secrets/GOOGLE_GYM_CLIENT_SECRET. The predefined role's full included permissions are secretmanager.versions.access and resourcemanager.projects.get/list; the binding is secret-level, not project-level. No read/delete grant is given to GEMINI_API_KEY or other unrelated secrets. Token secret creation must be project-level because create is authorized against the project parent; name-prefix IAM constraints restrict subsequent version access/addition and deletion, while the runtime also validates secret names.

Firestore IAM is database-level, not document-level: the four granted Firestore permissions allow point read/create/update in the default database. The application enforces org scope and limits writes to integration metadata/receipts. No document delete/query/list, Auth write, index, IAM-policy editing, service-account key creation or general resource administration is proposed. No Owner, Editor, broad Datastore User, unrestricted Secret Manager Admin or Token Creator grant is included.

Deployment identity remains user:owner-google-account-redacted@example.invalid; no new deployer bindings are proposed. After creating the account under an approved IAM scope, check existing iam.serviceAccounts.actAs access; if missing, submit a separate account-scoped proposal instead of granting project-wide impersonation.

Complete machine-readable roles and bindings: [google-gym-iam-proposal.json](google-gym-iam-proposal.json). Local metadata evidence is in build/google-oauth-setup/readiness.json, client-secret-metadata.json and condition-lint.json. No functional code changed, so no full test suites were run; this verification used exact configuration comparisons, fresh metadata reads and IAM condition linting.

## Separate deployment proposal — NOT APPROVED

After IAM approval/application, effective permission checks and Console read-back, request separate approval for only:

```text
pnpm exec firebase deploy --project gainpath-0619 --only functions:googleGymConnectionCommand,functions:googleGymOAuthCallback,functions:syncGymBookingCommand --non-interactive
```

Region us-central1; Node.js 22; runtime account above. This proposal does not include any existing Function, Rules, indexes, Hosting, billing, automatic workers or APK installation. Deploying must not connect the Google account or perform provider writes. Controlled UAT remains Admin-triggered, with separate approval for consent, Coach calendar creation and real Calendar/Gmail delivery. Personal primary Google Calendar, booking/payment authority and existing modules remain unchanged.

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.
