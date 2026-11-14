# Module 13 scoped deployment — 15 November 2026

Owner approval followed implementation commit `b1d9ce7e0589b7ed20725cb373b235c0bee769a1`. Only the eight reviewed Functions were deployed to `gainpath-0619`, `(default)`, `asia-southeast1`. Unrelated local Workout UI edits were excluded.

## Deployed and verified

| Entry | Result |
|---|---|
| `fypDatasetCommand` | ACTIVE; source-only update, existing settings/IAM preserved |
| `module13AdminCommand` | ACTIVE; owner-approved client transport enabled, Auth/App Check/role denials verified |
| `module13MemberCommand` | ACTIVE; owner-approved client transport enabled, ordinary Member reads verified |
| `module9MemberCommandCallable` | ACTIVE; source-only update, existing settings/IAM preserved |
| `module13WorkoutBackupCreated` | ACTIVE; exact ordinary backup create filter and retry verified |
| `module13WorkoutConsentChanged` | ACTIVE; exact ordinary consent-write filter and retry verified |
| `module13FypWorkoutBackupCreated` | ACTIVE; exact cohort backup create filter and retry verified |
| `module13FypWorkoutConsentChanged` | ACTIVE; exact cohort consent-write filter and retry verified |

Every downloaded deployed source archive matches reviewed SHA-256 `A558020419EAA8FEA22ACCF3C2BB2EFCF8793727B50FE9FDA287989829F0FC3A`.

- 71 unrelated Functions are byte-for-byte unchanged in their metadata inventory.
- Existing shared service/build configuration and IAM policies are unchanged.
- Firestore Rules release and indexes are unchanged.
- Existing FYP release and unified Admin integration gates were verified enabled, not modified.
- No workout evidence policy was enabled, no Firestore product records were written by the operator, and no Gemini requests were made.
- Fresh pre-deployment regression: 22 tests passed across release boundaries, summary guidance and unified Admin pagination.
- Exact previous sources and settings for the two updated shared callables were captured before deployment for rollback.

## Live authenticated read verification

Used the two previously authorized sample accounts with their existing private credentials and the registered App Check provider. No password reset, consent change, recommendation generation, dismissal, booking or payment operation was performed.

| Protected operation | Result |
|---|---|
| FYP Member `member.recommendation.list` with history | HTTP 200; four existing delivered/history projections |
| FYP Member `member.inbox` | HTTP 200; four notices |
| FYP Member summary-purpose consent read | HTTP 200 |
| FYP Admin `workout.admin.queue.list` | HTTP 200; no new summary recommendations yet |

These checks verify live authentication, App Check and reads. They do not establish a real camera workout or automatic delivery acceptance.

## Client transport activation — approved and verified

Before activation, both new callable services returned Cloud Run HTTP 401 with an HTML response even with Firebase Auth and valid App Check. Requests did not reach the handler. The owner separately and explicitly approved invocation access for only these two services on 15 November 2026.

Added only `roles/run.invoker` for `allUsers` on `module13MemberCommand` and `module13AdminCommand`. This permits Flutter/Firebase callable transport to reach the handler; handlers still enforce Auth, App Check, fresh organization membership and Member/Admin role checks. Readback verified the exact bindings. Project-level IAM, the other six Module 13 service policies and Firestore Rules remain unchanged. The deployment approval was not used to change IAM; this step followed the owner's separate approval required by `AGENTS.md`.

Fresh live checks used existing ordinary Member and FYP credentials plus real App Check, without creating/resetting accounts or granting consent:

| Check | Result |
|---|---|
| Both new APIs, missing Auth | JSON HTTP 401 `UNAUTHENTICATED` |
| Both new APIs, missing App Check | JSON HTTP 401 `UNAUTHENTICATED` |
| Ordinary Member access | HTTP 200, recommendations enabled |
| Ordinary Member recommendation history | HTTP 200; empty for this account, no examples fabricated |
| Ordinary Member consent and current notice | HTTP 200 |
| Member calling Admin API | HTTP 403 `PERMISSION_DENIED` |
| Member selecting another organization | HTTP 403 `PERMISSION_DENIED` |
| FYP Member calling ordinary Member/Admin APIs | HTTP 403 `PERMISSION_DENIED` |

All 12 Auth/App Check/access/isolation checks passed. Both APIs also passed Chrome localhost:7361 CORS preflight. No product record mutation, consent grant, payment/booking action or Gemini request was made. Evidence: `transport-activation-verified.json`, `transport-authenticated-verified.json`, `cors-verified.json` under the private deployment folder.

## Remaining acceptance and rollback

Transport activation and the read-only access/denial checks are complete. A real Android workout and offline/reconnect demonstration are still pending; no device installation or camera session was performed here. Members must authorize the current summary-personalization notice and existing backup preference. Previous consent is not silently upgraded. A valid new save or explicit permission update then invokes the deployed automatic pipeline without Admin review. Positive ordinary Admin authentication was not tested with an ordinary Admin password; the actual FYP Admin monitoring read and ordinary Member denial on the Admin endpoint were verified separately.

Rollback artifacts and operation/source verification remain private under `build/module13-deploy-20261115/`. Restore the two shared functions' captured source using a source-only update; remove/disable only newly created Module 13 endpoints if separately authorized. Preserve all workout, recommendation, Inbox, payment and booking records. No destructive rollback was performed.

Private verification files: `preflight.json`, `deployment-verified.json`, `authenticated-smoke.json`, `functions-before.private.json`, `functions-after.private.json`, prior source ZIPs and per-service operation/status records. They contain operational/user-specific information and are not committed.
