# B2 — Coach dated availability source implementation

Date: 2026-10-14. Approved baseline: `a6b28bb4dcb722ca5606cbcc3fd112a27e7a9387`. Scope: [approved B2 plan](2026-10-14-b2-availability-implementation.md). Source implementation and isolated verification only. No push, deployment, live mutation, real Coach provisioning, APK installation or B3 implementation.

## Completed user-visible behavior

**Coach:** Firebase Coach shell now enables the dated Availability tab. It loads seven organization-local dates from the server, offers bounded previous/next pages, and selects a future editable day. Coach chooses an assigned active branch and server-provided UTC time boundaries, adds/edits/removes windows, and explicitly saves the day. Today is read-only; authoring is tomorrow through today +30 calendar days, inclusive; maximum 16 submitted windows. No weekly recurrence, capacity slider, mock roster counts or fake save success is mounted in Firebase mode. Empty windows remove availability while preserving the day document/revision.

The original day/context remains immutable during editing. Overlap validation includes different branches. A stale day/policy/branch or protected-reservation conflict disables Save until explicit discard/reload. Same-intent retries retain their request ID; successful saves reread persisted data. Dirty edits prevent changing dates without saving/discarding. The inline editor stays inside the existing full-session guard; row mutation actions are disabled while it holds an edit index. Account/organization/branch/verification drift hides the old screen and late responses cannot restore it.

**Member:** published Coach detail opens a schedule by stable Coach UID. The real callable returns only windows allowed by current account organization/membership, current active Coach assignment, active branch, publication and shared branch access. Organization-local labels include UTC offsets. Empty, loading and unavailable/error states are truthful. The view explicitly says **Coach schedule; booking unavailable.** It does not expose lock IDs, imply free slots or enable booking.

**Admin:** existing Coach review opens a scoped read-only schedule route with a latched session guard. Canonical Admin organization authority does not require personal branch assignments. Admin cannot edit availability; staff aliases do not gain this read capability. Existing B1 Publish/Deactivate behavior remains intact.

Existing mock weekly availability/booking repositories and layouts are preserved. No SDK fallback to mock data exists in the real paths.

## Trusted storage and callable contracts

Path remains `orgs/{organizationId}/coachAvailability/{coachUid}/days/{YYYY-MM-DD}`. `schemaVersion: 1` and windows `{branchId,startAtMillis,endAtMillis}` are unchanged. Optional JSON-contract fields now allow revision, timeZone, policyVersion, createdAtMillis and updatedAtMillis; new B2 records require them. The existing booking consumer is unchanged and successfully consumes a B2 day containing metadata.

All timestamps are server-clock epoch milliseconds; intervals use the existing UTC half-hour grid and half-open `[start,end)` boundaries. Touching same-branch windows merge, preserving single-window containment for 30/60-minute bookings. Gregorian dates, DST skipped/repeated times, safe timestamps, overlaps and date/horizon bounds are validated. No authoritative conversion uses phone-local time.

Organization timezone is read from `orgs/{org}/settings/booking`, using the same physical policy contract as booking. Read context derives initial today on the server when firstLocalDate is omitted. Date grids enumerate a bounded UTC envelope and use Intl timezone formatting; repeated times receive distinct offset labels, skipped dates fail closed. Read pages contain at most seven dates and stop at the horizon.

| Operation | Contract |
|---|---|
| `getCoachAvailabilityCommand` | Verified authenticated caller; schema 1, organizationId, coachId, optional firstLocalDate, dayCount 1–7. Transactional current assignment/membership/org/branch checks. Returns server clock/today/zone, permitted branches and dated windows. Own Coach additionally receives immutable revision/policy/edit context and grid boundaries. Member receives no revision/authoring baseline/grid; displayTimes includes only permitted window endpoints. Admin receives read context but no edit permission. |
| `saveCoachAvailabilityDayCommand` | Verified canonical Coach only; infer UID from Auth. Input organizationId/requestId/localDate/expectedRevision/expectedPolicyVersion/expectedTimeZone/expectedCoachBranchIds/windows. Current organization, active membership/org/assigned branches, immutable context, horizon and day revision are checked inside transaction. Returns exact Coach/date/request identity, incremented revision and saved/removed outcome. |
| Receipt | `commandReceipts/{keyOf('saveCoachAvailabilityDay',actorUid,requestId)}`. Canonical fingerprint includes original expectations and normalized windows. Current actor authority precedes replay; same intent replays, changed intent rejects. Replay is an earlier operation result, so UI rereads. |

Missing day means revision 0 creation baseline. Existing legacy schema-1/window-only data is read-only/review-required; malformed/partial metadata, unknown stored fields or timezone mismatch reject authoring rather than being silently repaired. createdAtMillis is preserved. No hard deletion, migration or parallel schedule collection is introduced.

No production Firestore Rules or index changed. All schedule reads use the authenticated role-filtering callable; direct client schedule get/write remains denied in both Rules tests and the actual SDK smoke. Policy/branch private documents are not broadly exposed. New callables follow B1 authenticated callable configuration; existing booking App Check enforcement is unchanged.

## Reservation safety evidence

Every save transaction reads all supported global Coach/time lock paths for the local day before writing. Recognized unexpired holds and confirmed locks require unchanged interval coverage on their original branch. Malformed/unknown locks and live locks inconsistent with stored coverage fail closed. A known expired hold permits availability removal, but its lock, booking and job remain untouched. Changes elsewhere in the day are allowed when protected coverage remains intact.

The original revision, policy strings and branch expectations are captured outside retry callbacks. Actual Firestore contention tests show one winner for concurrent edits and one compatible winner for racing hold/removal: a committed hold retains its covering window; committed removal prevents the hold. This uses the existing shared day-document transaction dependency, without modifying createBookingHoldService, slot-lock schema or TransactionPort.

Deterministic callback replay testing is explicitly a **retry simulation**, separate from the actual contention tests. No external competing writer is awaited inside a pessimistic transaction callback. Existing booking/job/lock data is compared before/after allowed expired-hold removal; it remains identical. Isolated CRUD/SDK smoke also confirms no booking/workout/consent activity is manufactured.

## Local commits and exact files

| Commit | Purpose |
|---|---|
| `9e0e4772f2c7ffd0a29134c6a49ed9269bb1d550` | Trusted commands, domain/schema contracts and focused persistence/concurrency tests; approved plan preserved verbatim |
| `765e9be6a1adccf8ea46fe5683e725950f243095` | Capture original policy expectations before retry callbacks; exact horizon/window-cap regression |
| `3db515b08584e9aa03c3ea5e0fff1a20b2886e3f` | Three-role UI/SDK composition and repeatable isolated callable smoke |
| `9c28faded758529e97321b8e865307c482038227` | Fresh-review fix: freeze row actions during inline editing, with observed RED → GREEN regression |

This report is committed separately after the source checks. All B2 commits are local; remote integration/CI is not claimed.

| Layer | Exact changed files |
|---|---|
| Shared contract | [coach-availability.schema.json](../../contracts/v1/coach-availability.schema.json), [coaching.dart](../../packages/gainpath_domain/lib/coaching.dart), [coach_availability_contracts.dart](../../packages/gainpath_domain/lib/src/coaching/coach_availability_contracts.dart), [domain tests](../../packages/gainpath_domain/test/coach_availability_contracts_test.dart) |
| Backend | [index.ts](../../functions/src/index.ts), [coach-availability-contracts.ts](../../functions/src/modules/coaching/coach-availability-contracts.ts), [coach-availability-service.ts](../../functions/src/modules/coaching/coach-availability-service.ts), [coach-availability-callables.ts](../../functions/src/modules/coaching/coach-availability-callables.ts) |
| Backend verification | [service tests](../../functions/test/coach-availability.test.ts), [synthetic fixture](../../functions/test/coach-availability.fixture.ts), [Firestore tests](../../functions/emulator/coach-availability.test.ts), [real callable smoke](../../functions/emulator/coach-availability-callable-smoke.cjs), [local emulator config](../../firebase/coach-availability.emulator.test.json), [package.json script](../../functions/package.json) |
| Mobile composition | [mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart), [coach_profile_factory.dart](../../apps/mobile/lib/app/di/coach_profile_factory.dart), [coach_shell.dart](../../apps/mobile/lib/app/shells/coach_shell.dart), [member_shell.dart](../../apps/mobile/lib/app/shells/member_shell.dart) |
| Mobile data/state | [Firebase repository](../../apps/mobile/lib/infrastructure/firebase/firebase_coach_availability_repository.dart), [availability Cubit](../../apps/mobile/lib/features/coaching/application/coach_availability_cubit.dart) |
| Mobile views | [availability_screens.dart](../../apps/mobile/lib/features/coaching/presentation/coach/availability_screens.dart), [live_coach_availability_view.dart](../../apps/mobile/lib/features/coaching/presentation/coach/live_coach_availability_view.dart), [live_coach_schedule_view.dart](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_schedule_view.dart), [existing detail](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_directory_views.dart) |
| Mobile tests | [B2 flow](../../apps/mobile/test/coach_availability_flow_test.dart), [fixture](../../apps/mobile/test/support/coach_availability_fake.dart), [existing B1 flow](../../apps/mobile/test/coach_directory_flow_test.dart) |
| Admin composition | [admin_app.dart](../../apps/admin_web/lib/app/admin_app.dart), [app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart), [coach_availability_factory.dart](../../apps/admin_web/lib/app/di/coach_availability_factory.dart), [admin_shell.dart](../../apps/admin_web/lib/app/shells/admin_shell.dart) |
| Admin data/views/tests | [Firebase repository](../../apps/admin_web/lib/infrastructure/firebase/firebase_coach_availability_repository.dart), [coach_schedule_view.dart](../../apps/admin_web/lib/features/coaching/presentation/admin/coach_schedule_view.dart), [coaches_screen.dart](../../apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart), [existing review](../../apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart), [read-route test](../../apps/admin_web/test/coach_availability_read_test.dart) |
| Documents | [approved plan](2026-10-14-b2-availability-implementation.md), this report |

Total: **38 distinct committed paths** including this report. No pubspec/lockfile dependency changes; functions package change adds only the isolated smoke script. The legacy mock Availability screen received only its live entry branch/parameters, avoiding a cosmetic reformat.

## Executed verification and limits

Ignored evidence remains under `build/b2-availability/`; older evidence directories are preserved.

| Check | Actual result / evidence |
|---|---|
| Backend build, compiled index import, test typecheck | Exit 0; compiled callable definitions load |
| Relevant backend group | **64 passed**, 6 files: B2 availability, B1 profiles/callable error mapping, booking, authorization, shared contracts; `backend-final.log` |
| Domain B1/B2 contracts | **6 passed**; `domain-final.log` |
| Real Firestore group | **9 passed**: 4 B2 persistence/Rules/contention/retry tests plus 5 existing transaction regressions; `emulator.log`. Final compiled-backend B2 rerun: **4 passed**, `emulator-final.log`; repeated tests are not counted twice |
| Actual Auth/Functions/Firestore client smoke | Passed, verified synthetic accounts, actual HTTPS callable SDK dispatch and persistence; `callable-smoke-final.log` |
| Relevant mobile group | **30 passed**, 7 files: B2, B1 role/directory/profile state, A1 catalog, local progress, app entry; `mobile-final.log` |
| Relevant Admin group | **6 passed**, B2 route/B1 publication/feature availability; `admin-final.log` |
| Maintained workspace analysis | `No issues found!`; final review-fix files also clean |
| Architecture checker | `Architecture boundaries OK`, zero findings |
| Fresh source review | No critical/minor B2 issues; one Important captured-index defect fixed in one pass with genuine failing expectation and green relevant mobile group |

Backend test-first runs failed against unimplemented commands before passing. Domain models and Flutter composition were missing before implementation. Harness errors (non-const SessionScope fixture, two incorrect test filenames, Tooltip finder type) were diagnosed and corrected, not represented as product failures or passing evidence. All final named groups are green; no new test skips were introduced.

Repeat the actual callable smoke in functions, with Java 21 available:

```powershell
pnpm run test:availability:callable
```

It explicitly targets `demo-gainpath`; local emulator-host guards reject accidental live execution. The commands executed here used existing Node/Firebase CLI/Vitest entry points directly because the managed pnpm shim hit sandbox filesystem access. No dependencies were installed. Expected permission-denied SDK logs are assertions of denied direct writes, not failed smoke steps. No raw Auth token or private media URL is printed.

**Validation boundaries:** local Functions emulator used host Node 24 and warned that deployment specifies Node 22; Node 22/exact-head CI remains source integration verification after push approval. Firebase SDK smoke is JavaScript, while Flutter tests use explicit async port fixtures. Actual Flutter web/native-to-emulator, live Firebase and Xiaomi functionality remain unverified; the documented Windows CanvasKit issue was not reopened. No B2 app build or installation was performed. B1's earlier CI is not B2 CI evidence.

## Preservation and implementation decisions

All **54** recorded pre-existing entries retain hashes/presence, including the accepted B2 plan and B1 integration report. README, run configuration, old P0 edits, historical reports and rollback artifacts remain unchanged. Commit paths are allowlisted; no unrelated files are staged. No production Rules/index change; no booking service/payment/identity lifecycle or workout/native/pose package change. No token-bearing tutorial URL was retrieved or committed.

Recorded decisions: keep the dedicated checkout and explicitly stage paths (staging risk checked); use PowerShell-compatible ignored ledger/evidence (housekeeping only); retain evidence rather than deleting it (disk use only); return allowlisted visible endpoint labels (small read-response addition); permit canonical Admin with empty personal branches (organization authority, no editing); use an inline guarded editor (avoids detached-dialog session exposure); retain small independent-app SDK/view adapters instead of introducing a shared Firebase runtime package (bounded duplication); use actual SDK smoke plus separate Flutter composition proof (browser/device gate retained); honor all live/B1/B3/B4 deferrals (operational readiness not claimed). No additional B2 minor findings are deferred.

## Deployment prerequisites and B3 readiness

Before coordinated live activation: approve source push/exact-head CI; reconcile the documented B1 negative stored-timestamp mismatch with a focused reviewed fix; verify actual organization booking policy/timezone and branch assignments; approve genuine Coach provisioning/email verification; review/deploy only authorized B1/B2 resources; inspect legacy schedules before any migration; execute an approved real Coach → Member/Admin browser/device smoke. B1 still does not automatically withdraw public projections after suspension/reassignment; B2 Member schedule reads independently recheck current Firestore membership/assignment and branch eligibility. Auth-only disable without a membership change does not automatically withdraw the public schedule. Auth claims and in-flight requests retain normal token/lifecycle propagation boundaries.

B2 supplies the real dated authoring/read foundation for **B3 pending holds and shared visibility**. Recommended bounded B3 scope after acceptance:

1. Reconcile [CreateBookingHoldRequest](../../packages/gainpath_domain/lib/src/coaching.dart) and [remote DTO](../../packages/gainpath_data/lib/src/booking_repository.dart) with the existing v1 schema, including missing schema/member fields; connect a real async callable adapter with stable same-intent request IDs.
2. Add a trusted/scoped view of eligible future 30/60-minute starts, current branch/policy checks and occupied-lock handling; do not relabel all B2 schedule windows as free slots. Tighten/reuse B1 current-assignment/active-organization checks in booking authoring and reads where the old booking contract lacks them. Preserve existing lock/idempotency and App Check enforcement.
3. Wire Member schedule selection to a real **pending_hold** result, then show the same persisted booking/status to its Member, assigned Coach and authorized branch Admin. Add only indexes proven necessary by the chosen query shapes. Existing mock confirmation/payment screens remain unavailable in Firebase mode.
4. Verify actual hold contention, daily cap, role/org/branch denial, request replay and one cross-role emulator path. Keep confirmation/payment and cancellation/expiry in their separately approved slices; B4 is needed before claiming a complete ongoing reservation lifecycle.

The mobile source currently has no App Check initialization/dependency; existing createBookingHold enforces it. A concrete App Check integration decision is a B3 callable/live gate, not permission to disable it. No B3 source was implemented here.

Rollback: a reviewed revert of B2 source commits only. Preserve dated day revisions/tombstones, B1 profiles, bookings/locks/jobs/receipts and all workout/local evidence. No live B2 resources/data exist from this task. Stop for B2 review; no next module or activation begins automatically.
