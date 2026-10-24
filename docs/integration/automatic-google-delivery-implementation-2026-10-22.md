# Automatic Calendar sync and Gmail — local implementation

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Status: implemented locally, not deployed or activated. Earlier manually controlled Calendar/Gmail UAT passed; those passes do not prove automatic delivery UAT.

## Result

One prepared `synchronizeGoogleBooking` Firestore update trigger handles cleared paid Sandbox confirmation, confirmed-session reschedule and confirmed-session cancellation. Calendar uses the existing stable private event; Gmail uses distinct confirmation/reschedule/cancellation templates. Reschedule includes prior and new times; cancellation explicitly states refund review is separate.

Default automation is off. Required configured organization, activation cutoff, one-hour maximum event age and nonempty approved test-recipient allowlist fail closed. No historical sweep/backfill, automatic Coach calendar creation, new top-level collections, AI mutation tool or payment mutation is introduced.

Automatic delivery and existing Admin sync share the coordinator, per-booking lock and receipts. Existing manual confirmation receipts suppress an automatic resend. Distinct revision identities permit A → B → A reschedule notices. Exact Firestore update-time checks fence stale events in the same transactions as receipt/lease reads. Each provider request checks current authorization, original grant identity and booking/lease state. Busy leases can retry; expired Gmail reservations become uncertain without resend. Calendar failures can reconcile independently of an already attempted email. Retries stop after the event is one hour old; unresolved work remains for Admin review.

Gmail provides no exactly-once guarantee. The implementation makes at most one send attempt per notification identity. A reservation or issued send with unknown outcome is not automatically resent. A worker fenced by a newer booking revision can leave a sending receipt until a newer event recovers its expired lease; absent a newer event, Admin reconciliation is required. No periodic recovery worker was added.

## Changed implementation files

- New: functions/src/modules/coaching/automatic-google-delivery.ts, automatic-google-worker.ts, google-automation-config.ts, google-gym-runtime.ts.
- Updated: functions/src/modules/coaching/gym-booking-sync.ts, google-booking-delivery.ts, google-gym-callables.ts, google-gym-connection.ts; functions/src/platform/firestore/firestore-store.ts; functions/src/index.ts.
- Shared status: packages/gainpath_domain/lib/src/coaching/google_integration.dart and packages/gainpath_ui/lib/src/google_integration_panel.dart. No separate Firebase screen.
- Focused tests: new automatic-google-delivery.test.ts, google-automatic-worker.test.ts, google-automatic-enabled-worker.test.ts; updated google-booking-delivery.test.ts and google_integration_panel_test.dart.

## Verification

TypeScript build and test type-check passed. Final focused backend suite: 47 tests passed across 10 files. Shared UI: 5 tests; data repository: 3; Admin Google settings: 1. Total: 56 focused tests passed. Scoped Dart analysis: no issues in the three changed domain/UI/test files. Local Firebase Admin Web build passed, SHA256 59af48e7c7929bd697d01b7b46354a86838a9182af983d78c94986e9b780ec6a for main.dart.js. Build emitted a pre-existing missing CupertinoIcons font warning; no compilation failure. Local Node is 24; deployment runtime is configured Node 22. No full suites or live provider requests were run for this implementation.

Independent read-only review found a per-request disconnect gap. Fixed by revalidating authorization plus original grant identity before every provider call, with regressions for disconnect/disable after Calendar lookup. Re-review found no additional actionable blocker.

Enabled-trigger tests execute the actual exported handler with mocked Firestore, Auth and HTTP providers. They cover duplicate invocation, stale versions before/during IO, disable between provider requests, busy lease retry and expired Gmail no-resend. These are not deployed Eventarc, real Firestore contention or physical-device tests.

## Exact IAM proposal — not applied

Principal for both runtime and Eventarc trigger:
`serviceAccount:gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com`.

1. Project `projects/gainpath-0619`: add `roles/eventarc.eventReceiver`, no condition. Exact role permissions independently read: `eventarc.events.receiveEvent`, `eventarc.events.receiveAuditLogWritten`. No existing binding for this principal was found. This permits event receipt, not Firestore administration or Google OAuth access.
2. Only target service `projects/gainpath-0619/locations/us-central1/services/synchronizegooglebooking`: add `roles/run.invoker` for that service account, no condition. Expanded role permissions independently read: `run.instances.invoke`, `run.jobs.run`, `run.routes.invoke`. The binding is on this one Cloud Run service; it grants no access to separate Cloud Run Job resources. No public `allUsers` binding for this worker and no project-wide invoker grant.

All existing four custom runtime roles, one-secret accessor binding, deployment identity and OAuth scopes remain unchanged. No Owner, Editor, Secret Manager Admin, Token Creator, new service-account keys or Firestore list/query grants are proposed. Firebase CLI locally maps the endpoint runtime service account to its Eventarc trigger identity; verify both after deployment. Google documents these trigger grants in [Eventarc roles and permissions](https://docs.cloud.google.com/eventarc/docs/roles-permissions).

## Selective deployment proposal — not approved/executed

After approval of the IAM above, first deploy with automation disabled:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --only 'functions:synchronizeGoogleBooking,functions:googleGymConnectionCommand,functions:syncGymBookingCommand' --non-interactive
```

Scope: one new worker; update connection Callable for status and existing sync Callable for shared coordination/guards. No OAuth callback, other Functions, Rules, indexes, Hosting, APK or payments deployment. Reuse GOOGLE_GYM_CLIENT_SECRET; no new API key or OAuth grant needed. The new Eventarc trigger and its managed delivery infrastructure are part of this proposed Function deployment, not resources already approved.

Configuration parameters:

```text
GOOGLE_BOOKING_AUTOMATION_ENABLED=false
GOOGLE_BOOKING_AUTOMATION_ACTIVATED_AT=
GOOGLE_BOOKING_AUTOMATION_TEST_RECIPIENTS=
```

Do not write enabled settings until separate activation approval. For controlled activation, set enabled true, a fresh UTC ISO cutoff, and only `owner-google-account-redacted@example.invalid` as the consenting test recipient. Verify deployed configuration and service identities before creating a fresh disposable paid Sandbox booking. Other verified Members remain excluded while this UAT allowlist is enforced.

## Consolidated controlled automatic UAT

1. Verify disabled automation causes no delivery. Approve UAT activation and fresh cutoff; verify old bookings are not backfilled and another organization/recipient cannot receive delivery.
2. Confirm one fresh paid Sandbox booking for the consenting Member and Jackson. Verify one private Calendar event and actual Gmail receipt without Admin pressing Sync/Send.
3. Redeliver/reconcile the same transition; verify stable event identity and no duplicate email. Compare automatic and manual receipt behavior.
4. Reschedule A → B → A in GainPath; verify the same Calendar event follows current times and exactly one notice per actual change. Check old queued events cannot revert the current time.
5. Cancel in GainPath; verify owned event removal and one cancellation email without a refund promise. Review refund separately through existing processes.
6. Test disconnected/revoked grant, missing calendar and uncertain Gmail outcome. Verify actionable review status and no automatic Gmail resend. Disable automation and verify provider writes stop.

Keep production-wide recipients and broader automatic activation gated until this real UAT passes. Existing manually tested booking is not disposable and must not be rescheduled/cancelled without owner authorization.
