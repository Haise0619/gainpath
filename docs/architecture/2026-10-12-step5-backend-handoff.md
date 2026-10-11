# Step 5 backend interface and coordination

Scope: server consent acknowledgement/revocation, bounded real v2 submission,
transactional idempotent acceptance, callable exports and security tests. This
chat owns functions/workouts + tests/rules. The coordinating chat owns all mobile
upload/consent/outbox/UI and Git integration. No deployment/commit/push here.

## Implemented callable API

Existing v1/v2 contracts remain authoritative, no raw poses/partial/deviation
streams in submissions. Export these callable names from functions/src/index.ts
by appending their exports and preserving all existing exports:

- `acknowledgeWorkoutConsentCommand`: existing AcknowledgeWorkoutConsentV1 ->
  WorkoutConsentAcknowledgementV1. Server owns acknowledgementId/time. Requires
  verified UID == memberId, users/{uid}.organizationId matching request, active
  member role in org. requestId retry key scoped by org+UID+operation.
- `submitWorkoutSessionCommand`: existing SubmitWorkoutSessionV2 ->
  WorkoutAcceptanceV2. Same ownership/membership checks; current non-revoked
  consent acknowledgement must match and precede session start, current exercise
  active, published routine currently contains the exercise, enabled exact tuple.
- `revokeWorkoutConsentCommand`: new bounded request
  `{schemaVersion:1,requestId,organizationId,memberId,consentVersion,
  acknowledgementId}` -> same identity + `revokedAtMillis`. Revokes only current
  matching acknowledgement. Same request retries return prior receipt and never
  revoke a later fresh acknowledgement.

Consent path: `orgs/{org}/workoutConsents/{uid}` holds server-controlled current
acknowledgement + nullable revokedAtMillis. New acknowledgement rotates current
ID; prior IDs do not authorize new submissions. Replaying a revoked old consent
request does not reactivate it. Cached acknowledgements remain client assertions;
the server rechecks state on every submission/retry.

Acceptance document: `orgs/{org}/workoutSessions/{sha256(memberId,sessionId)}`,
stored summary preserves member/session/routine/exercise IDs and exact versioned
v2 metrics, server acceptedAtMillis/status plus immutable payload fingerprint.
Receipt keys: existing org commandReceipts using hashed operation+UID+requestId.
Session fingerprint omits requestId so a new request retry of identical session
deduplicates, but changed payload under either key is already-exists. No rewards,
points, leaderboards, notifications or analytics side effects.

**Production enabled tuple list is empty.** Callables use that fixed fail-closed
policy. Pure service tests inject a known eligible tuple; no request, client rule,
Firestore config or environment toggle can enable acceptance. Physical quality
approval and deliberate reviewed server policy change are required before any
real model/rule tuple is enabled. Implemented endpoint does not certify motion.

Submission parser rejects extra/missing fields, v1, simulation/fixture provenance,
invalid IDs, NaN/unsafe/range counts/times, end<=start, duration>24h, measured time
exceeding elapsed, nonnull score/reps with no tracked time. Service rejects future
end times and fewer than 600 tracked milliseconds per full rep (matching the
current provisional rule minimum cycle), not an anatomical accuracy claim.

Rules: existing workoutSessions owner/admin reads and deny-all client writes
remain. Add only current consent **owner get** for verified active member (no
list/other-member/admin client reads and no client writes), needed for safe
offline cache/revocation refresh. Command receipts remain server-only.

## Verification

Completed locally on 2026-10-12:

- All functions unit tests: **114 passed**, 9 files. The workout service has 40
  tests; shared v2/consent schema coverage has 19 tests.
- Full Firestore + Storage emulator suite: **28 passed**, 4 files. Six workout
  emulator tests cover actual transaction contention, command/session retries,
  conflicting summaries, consent revocation serialization, closed runtime policy,
  and exported callable auth/validation/error mapping. All 15 Firestore rules
  tests pass, including existing authoring/publishing access and the new narrow
  consent owner-get permission. Client acceptance writes remain denied.
- Functions production TypeScript build + entry-point import passed; source,
  unit and emulator test TypeScript check passed.
- Independent scoped backend review found no actionable defects.
- Initial missing revoke schemas and owner consent permission were observed as
  failing tests before adding those contracts/rules. V1 submission remains
  rejected by the real handler; historical schema compatibility is preserved.

One initial full emulator run failed the concurrent command/session test with
`INVALID_ARGUMENT: Transaction is invalid or closed`. A focused run of all six
workout tests and subsequent full suite passed without a transaction behavior
change. Emulator logs show transaction lock timeouts under contention. This is
recorded as an intermittent local emulator failure, not a proven production fix.
Callables return a bounded internal error on unexpected failures and instruct
same-request retry; transactional receipts preserve idempotency on such retries.

Reproducible equivalents of package scripts, using installed dependencies:

```powershell
# Run from functions/; no package install required.
node node_modules/typescript/bin/tsc
node -e "require('./' + require('./package.json').main)"
node node_modules/typescript/bin/tsc -p tsconfig.test.json
node node_modules/vitest/vitest.mjs run
node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec `
  --project demo-gainpath --config ../firebase/emulator.test.json `
  --only firestore,storage `
  "node node_modules/vitest/vitest.mjs run --config vitest.emulator.config.ts"
```

For this Windows host, Node is `C:/Program Files/nodejs/node.exe`; the emulator
uses Android Studio's bundled JBR via JAVA_HOME and PATH. Verification logs are
local ignored files `functions/step5-emulator-{verification,focused,final}.log`.
No live Firebase calls, deployment, APK installation, commit or push occurred in
this backend slice. The coordinator owns mobile integration and coherent Git
commits/pushes. Shared index edit is confined to the three explicit new exports.

## Mobile integration boundary

Consent/revocation request/response schemas are in contracts/v1; real summary and
acceptance schemas remain in contracts/v2. Acknowledge and revoke are callable
ready if deliberately deployed. The current consent document adds nullable
`revokedAtMillis` to the acknowledgement wire object. Owner get is permitted;
there is no client set/list permission or client acceptance receipt creation.

All service attempts, including retries of previously accepted test sessions,
recheck current membership, consent, active catalog/routine row and enabled
tuple. A stale/revoked/rotated acknowledgement is `failed-precondition`; the app
must not silently issue fresh consent or retry with a replaced acknowledgement.
New explicit consent needs a fresh requestId. Replaying a completed revoke
returns its receipt without revoking a later fresh grant.

Production `submitWorkoutSessionCommand` still returns `failed-precondition`
for every tuple, with an explicit physical-validation policy reason. Mobile
must retain a local saved session on that response; it must not mark accepted,
award points or substitute mock acceptance. The backend owns no reward side
effects. Enabling a tuple is a later reviewed change after physical acceptance.
