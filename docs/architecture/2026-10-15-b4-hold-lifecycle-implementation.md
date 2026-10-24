# B4 — Pending booking cancellation and expiry

Status: bounded source implementation, locally verified; no push or live activation. Starting point: B3 `9a960d106e12fd469a9a09acb12a9e1081b04a65` on `codex/real-squat-flow`.

Implementation commits:

- `2b8915642e5595cffc6ca551e1fc91baa58d0776` — trusted lifecycle, schemas, expiry index, tests and plan.
- `d4b69d0c430469b40aa44dc285ebaba2fe18bdab` — domain/Flutter integration. The final handoff commit also encloses two new control-flow statements in braces; final analysis treats infos as failures.

## Implemented behavior

**Member:** My bookings offers confirmation for cancelling a persisted pending hold. A successful command triggers a server-list refresh. Uncertain transport/response failures retain the same immutable cancellation request and block another cancellation intent until recovery. Refresh remains available after uncertainty. Leaving the route does not undo a committed operation; recovery state is route-local, not durable across application restarts. New requests against an already closed record return its terminal state without releasing anything again.

**Coach/Admin:** existing scoped read-only lists display the same persisted cancellation/expiry state and resolution reason. No Coach, Staff or Admin cancellation authority is added. The Member creation screen labels its original receipt explicitly: a replay of the creation request cannot renew or prove the current state of a hold.

**Server:** `pending_hold` becomes `cancelled` strictly before its deadline, or `expired` at/after it. Server time is read inside the retryable transaction. Confirmed/completed/refunded records and their resources remain untouched. Current Coach publication, branch assignments or booking policy changes cannot prevent internal expiry of an existing well-formed hold. Member cancellation still requires current active organization membership; removal of an old branch does not prevent cancelling one's own record.

The pending-hold lifecycle is source-complete across the B1–B4 software workflow. This does not establish live booking operation, paid confirmation, consultation completion, refunds, rescheduling or account provisioning.

## Contracts and safety decisions

[`cancelBookingHoldCommand`](../../functions/src/modules/coaching/booking-lifecycle-callable.ts) is authenticated, verified-email and `enforceAppCheck: true`. Strict request:

```text
{ schemaVersion: 1, organizationId, bookingId, requestId }
```

There is no client-supplied Member UID, status, expiry time, price or cancellation reason. Current canonical Member role, current user organization and active organization/membership are checked before receipt replay. The booking must belong to the caller. Coach/Admin/Staff and cross-organization calls are denied.

Response:

```text
{ schemaVersion: 1, requestId, bookingId,
  status: 'cancelled' | 'expired',
  outcome: 'cancelled' | 'expired' | 'already_closed',
  resolvedAtMillis?: server UTC integer }
```

The timestamp is required for a new transition; an old cancelled record may lack historical resolution metadata. JSON/Dart/server validators reject mismatched request identity and unsupported fields/states. Receipt keys use existing organization command receipts, actor UID, command name and immutable request ID. Reusing an ID for another booking is rejected. Original `createBookingHold` receipts remain unchanged.

[`booking-lifecycle-service`](../../functions/src/modules/coaching/booking-lifecycle-service.ts) reads the booking, job, original daily accounting and all occupied half-hour locks before writes. A single transaction:

- Preserves the booking and all original immutable fields; adds `resolvedAtMillis` and `resolution: member_cancelled | hold_expired` with the terminal state.
- Removes only this booking's matching pending daily reservation, preserving other reservations and document fields verbatim.
- On early cancellation, sets only matching owned pending-lock expiry timestamps to server now. Existing B2/B3 allocation already treats elapsed pending locks as free and can replace them. No delete API or new lock status is needed.
- At expiry, locks are already logically free. Foreign replacement locks and reservations are retained. Missing/pruned expired resources are tolerated; missing resources before expiry, owned confirmed locks and inconsistent ownership fail closed.
- Completes the existing `expireBookingHold` job. Repeated cancellation or a late worker never reopens a booking or releases its replacement.

The new `expired` enum and optional resolution fields extend the existing version-1 record/list contract. Old cancelled records remain readable without fabricated timestamps. Older strict B3 clients cannot decode the extension: **roll out compatible readers before enabling lifecycle writers/worker**. No historical migration or record rewrite was performed. Original timezone/date/slot identity drives cleanup even when the current policy changes.

No Firestore Rules change was required. Existing client write denials for bookings, locks, daily accounting, jobs and receipts remain intact. One additive collection-group index supports the exact worker query.

## Scheduled processing

[`expireBookingHolds`](../../functions/src/modules/coaching/booking-expiry-worker.ts) is an internal v2 scheduled export configured every minute in UTC. It selects at most 50 supported pending due jobs per batch, ordered by due time and document ID. Each job is handled transactionally; correctness does not depend on the maximum-instance setting. Transient failures leave jobs pending for a later scan. Invalid ownership/missing bookings quarantine an unchanged job as `blocked` with a fixed safe failure code; no raw exception/request payload is stored.

Quarantine is intentionally not automatic repair. Blocked jobs, invalid/nonpositive/missing due timestamps outside the supported query, backlog and sustained infrastructure errors require authorized operational review. A hold can remain displayed as pending with an elapsed deadline while processing waits. This source slice does not promise closure exactly at the deadline or implement a production operations dashboard/backoff system.

## Executed verification

Local evidence is under ignored `build/b4-implementation/`; commands exited successfully unless explicitly identified as an earlier environment/red-test failure.

| Check | Result | Evidence |
|---|---|---|
| Backend build/export load | Pass | `backend-build.log` |
| Backend test typecheck | Pass | `backend-typecheck.log` |
| Full backend unit suite | 288 passed / 15 files | `backend-unit.log` |
| Real Firestore lifecycle + booking read + B2 concurrency regressions | 12 passed / 3 files | `backend-emulator.log` |
| Three-role Firebase SDK smoke | Pass | `sdk-smoke.log` |
| Focused mobile booking/controller/transport/composition | 16 passed | `mobile-focused.log` |
| Final brace-only cancellation regression | 3 passed | `mobile-cancellation-final.log` |
| Full pure-Dart domain suite | 69 passed | `domain-full.log` |
| Focused Admin booking reads/session drift | 2 passed | `admin-focused.log` |
| Maintained-source analysis, final `--fatal-infos` | No issues | `analysis.log` |
| Architecture checker | Zero findings | `architecture.log` |
| Existing tooling/architecture regression tests | 21 passed | `architecture-tests.log` |

Unit and emulator tests cover server expiry boundaries, own-only cancellation, same-ID replay, changed-intent rejection, current-organization drift, missing records, protected nonpending states, inconsistent owned locks, other reservation preservation, replacement protection and actual Firestore transaction contention.

The opt-in `pnpm run test:booking:lifecycle` reuses the B3 synthetic SDK fixture: Coach profile → Admin publication → dated availability → competing Member holds → owner cancellation/replay → three-role terminal reads → replacement hold → expiry batch → three-role expired reads. Missing App Check headers and other Member/Coach/Admin/cross-organization cancellation calls are denied with no protected writes. Existing workout/consent collections remain empty in the fixture.

**Measurement boundary:** the SDK smoke uses real client SDK callable HTTP and local Firestore transactions. Its App Check header is synthetic; the Functions emulator does not establish cryptographic attestation. The emulator ignores the scheduled trigger; its batch service was invoked locally with deterministic server time. Cloud Scheduler/IAM invocation was not tested. Flutter composition uses injected repositories; it is not an actual Flutter-browser-to-emulator or phone test. No APK/app build, device installation, live Firebase test or exact-head GitHub CI was executed under B4. Existing Windows CanvasKit limitations remain documented separately.

Environment: installed Node 24.19.0 differs from the project/CI Node 22 engine; CLI warnings were retained. An initial SDK run was blocked by occupied test ports. The verified orphaned `demo-gainpath` Java emulator from the completed prior run was stopped, then the SDK smoke passed. Sandboxed Dart access failures were environmental; successful local checks used the available elevated test execution. The initial new tests failed before implementation as expected. A mistaken nonexistent tooling-test filename was corrected to the actual `dart test test` suite. Two late brace-style notices were corrected and final maintained analysis passed with infos fatal.

One fresh-context read-only final source review found no material correctness/concurrency issue. No second implementer or broad infrastructure work was started.

## Preservation and activation gates

All 60 pre-existing dirty/untracked files match their recorded hashes. README/run configurations, prior plans/reports, local evidence and rollback artifacts were not staged. Protected pose, identity, workout, commerce and content runtime paths remain unchanged; B1/B2 services and Firebase Rules are unchanged. The scoped B4 source scan found no tutorial token-bearing URL, Firebase download token, API key pattern or private key. Only synthetic test attestation material appears in fixtures. This scan is evidence for the bounded files, not a global secret-audit claim.

Before any live activation, obtain separate approval for:

1. Source integration/push and exact-commit CI for the local B3/B4 chain. B4 has not been pushed.
2. Narrow pre-existing B1 malformed timestamp and B2 malformed lock-status fixes, then their relevant verification. These were preserved rather than silently included.
3. Fresh project/policy/timezone/branch and canonical-role checks; explicitly approved real Coach provisioning and publication. No real eligible Coach identity is claimed.
4. Coordinated compatible Member/Admin readers and the intended B1/B2/B3 resources, Rules/indexes if not already deployed. B4 adds only `cancelBookingHoldCommand`, `expireBookingHolds` and its jobs collection-group index. Deploy the index and compatible reads before enabling the expiry worker; verify index readiness.
5. Private Android App Check configuration/readiness and trusted callable verification. Do not remove App Check enforcement to make the demonstration work.
6. Scheduler/Run service-account and IAM checks, private scheduled invocation, billing/API prerequisites, and bounded real expiry/retry smoke. No public cleanup endpoint or client-supplied clock is authorized.
7. Separately approved Firebase-mode browser/device smoke: own cancellation, cross-role refresh, hold expiry, replacement allocation and account switching. Preserve the installed APK and all local workout/consent/outbox data if a later installation is approved.

Rollback: stop the scheduled worker first under separate approval, retain compatible readers and all booking/job/receipt records, and disable new lifecycle actions if necessary. Never turn cancelled/expired records back into pending or restore old locks/accounting snapshots over newer bookings. Index rollback is additive and not urgent. A downgrade to strict B3 readers would reject new terminal records, so use a compatible reader/hotfix instead. There was no live mutation to reverse under this task.

The next step is review/source integration and a coordinated activation preflight, not payment or confirmation implementation. Step 7C remains independent.

## Exact changed files

The following inventory covers both implementation commits and the final handoff/lint cleanup. Links are relative to this report.

- [`apps/admin_web/lib/features/coaching/application/booking_list_cubit.dart`](../../apps/admin_web/lib/features/coaching/application/booking_list_cubit.dart)
- [`apps/admin_web/lib/features/coaching/presentation/admin/booking_list_view.dart`](../../apps/admin_web/lib/features/coaching/presentation/admin/booking_list_view.dart)
- [`apps/mobile/lib/app/di/booking_factory.dart`](../../apps/mobile/lib/app/di/booking_factory.dart)
- [`apps/mobile/lib/features/coaching/application/booking_cancellation_cubit.dart`](../../apps/mobile/lib/features/coaching/application/booking_cancellation_cubit.dart)
- [`apps/mobile/lib/features/coaching/application/live_booking_cubit.dart`](../../apps/mobile/lib/features/coaching/application/live_booking_cubit.dart)
- [`apps/mobile/lib/features/coaching/presentation/member/live_member_booking_view.dart`](../../apps/mobile/lib/features/coaching/presentation/member/live_member_booking_view.dart)
- [`apps/mobile/lib/features/coaching/presentation/shared/live_booking_list_view.dart`](../../apps/mobile/lib/features/coaching/presentation/shared/live_booking_list_view.dart)
- [`apps/mobile/lib/infrastructure/firebase/firebase_booking_repository.dart`](../../apps/mobile/lib/infrastructure/firebase/firebase_booking_repository.dart)
- [`apps/mobile/test/booking_cancellation_test.dart`](../../apps/mobile/test/booking_cancellation_test.dart)
- [`apps/mobile/test/live_booking_composition_test.dart`](../../apps/mobile/test/live_booking_composition_test.dart)
- [`contracts/v1/cancel-booking-hold.request.schema.json`](../../contracts/v1/cancel-booking-hold.request.schema.json)
- [`contracts/v1/cancel-booking-hold.response.schema.json`](../../contracts/v1/cancel-booking-hold.response.schema.json)
- [`contracts/v1/get-booking-list.response.schema.json`](../../contracts/v1/get-booking-list.response.schema.json)
- [`docs/architecture/2026-10-15-b4-hold-lifecycle-implementation.md`](../../docs/architecture/2026-10-15-b4-hold-lifecycle-implementation.md)
- [`docs/planning/2026-10-15-b4-hold-lifecycle-plan.md`](2026-10-15-b4-hold-lifecycle-implementation.md)
- [`firebase/firestore.indexes.json`](../../firebase/firestore.indexes.json)
- [`functions/emulator/booking-callable-smoke.cjs`](../../functions/emulator/booking-callable-smoke.cjs)
- [`functions/emulator/booking-lifecycle.test.ts`](../../functions/emulator/booking-lifecycle.test.ts)
- [`functions/package.json`](../../functions/package.json)
- [`functions/src/index.ts`](../../functions/src/index.ts)
- [`functions/src/modules/coaching/booking-expiry-worker.ts`](../../functions/src/modules/coaching/booking-expiry-worker.ts)
- [`functions/src/modules/coaching/booking-lifecycle-callable.ts`](../../functions/src/modules/coaching/booking-lifecycle-callable.ts)
- [`functions/src/modules/coaching/booking-lifecycle-service.ts`](../../functions/src/modules/coaching/booking-lifecycle-service.ts)
- [`functions/src/modules/coaching/booking-list-service.ts`](../../functions/src/modules/coaching/booking-list-service.ts)
- [`functions/src/modules/coaching/booking-record.ts`](../../functions/src/modules/coaching/booking-record.ts)
- [`functions/test/booking-lifecycle.test.ts`](../../functions/test/booking-lifecycle.test.ts)
- [`packages/gainpath_domain/lib/gainpath_domain.dart`](../../packages/gainpath_domain/lib/gainpath_domain.dart)
- [`packages/gainpath_domain/lib/src/coaching.dart`](../../packages/gainpath_domain/lib/src/coaching.dart)
- [`packages/gainpath_domain/lib/src/coaching/booking_lifecycle_contracts.dart`](../../packages/gainpath_domain/lib/src/coaching/booking_lifecycle_contracts.dart)
- [`packages/gainpath_domain/lib/src/coaching/booking_read_contracts.dart`](../../packages/gainpath_domain/lib/src/coaching/booking_read_contracts.dart)
- [`packages/gainpath_domain/test/booking_lifecycle_contracts_test.dart`](../../packages/gainpath_domain/test/booking_lifecycle_contracts_test.dart)
