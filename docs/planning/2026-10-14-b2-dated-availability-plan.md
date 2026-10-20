# B2 — Dated Coach Availability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after user approval. Steps use checkbox syntax. This document authorizes no implementation, deployment or live mutation.

**Goal:** Coach manages future dated availability, Firebase persists it, and authorized Member/Admin screens read the same schedule.

**Architecture:** Reuse stable Coach UID, B1 current-assignment/session guards and the existing booking day/window path. Two authenticated callables provide bounded role-filtered reads and transactional own-day authoring; SDK adapters stay in app infrastructure and pure-Dart contracts stay in the shared domain package. Preserve the synchronous weekly mock repository rather than adapting it into a misleading Firebase implementation.

**Tech Stack:** Existing Flutter/BLoC, pure Dart, TypeScript, Firebase callable Functions, FirestoreStore and isolated emulators. No new timezone library, collection, recurring scheduler or booking command is proposed.

**Spec:** [Contract review and proposed decisions below](#contract-review). Baseline: `a6b28bb4dcb722ca5606cbcc3fd112a27e7a9387`. Follow [MVP sequence](2026-10-14-mvp-vertical-slices.md) and [B1 design](2026-10-14-b1-coach-profile-directory-design.md). The CRUD matrix actually resides at [docs/planning](2026-10-14-crud-integration-matrix.md), not the previously mentioned architecture path.

## Global constraints

- Planning only until B2 source approval; no live records, provisioning, deployment, APK installation or B3 implementation.
- Preserve B1/A1 and all unrelated modifications/evidence. No pose, scoring, exercise binding, workout/history/consent/outbox, enabled tuple or Step 7C changes.
- No mock success in Firebase mode. Keep booking, recurrence, capacity controls, payments, cancellation/expiry and rescheduling unavailable.
- Strong verification remains required for authorization, stale baselines and booking-lock preservation; avoid redundant presentation tests.
- Public directory publication is not certification. Schedule visibility is not a promise that a slot is free or bookable.

## Review focus

1. Phone timezone differs from organization timezone: select server-generated UTC boundaries and label the organization zone.
2. Two branches share the same Coach/time lock: branch reassignment cannot bypass a reservation.
3. A save overlaps a concurrent hold: transactions serialize through the existing availability day document.
4. A form survives assignment/logout/policy changes: immutable expected context and latched session guards reject it.
5. Legacy or malformed day records: show unavailable/read-only review state; do not silently upgrade or overwrite them.

## Contract review

### Verified executable facts

| Contract | Current evidence and implication |
|---|---|
| Authoritative policy | [booking-service.ts](../../functions/src/modules/coaching/booking-service.ts), `policyFrom`: `orgs/{org}/settings/booking`, schema 1, policyVersion, valid IANA timeZone, daily Member cap 1–32 and holdMinutes 1–30. Organization timezone comes from this policy, not the phone or profile. |
| Date identity | `localDate(startAtMillis, policy.timeZone)` produces `YYYY-MM-DD`. A booking's `endAtMillis - 1` must be on the same organization-local date. Intervals are treated as half-open `[start,end)`. |
| UTC slot grid | Start is a future UTC epoch half-hour boundary; durations are 30/60 minutes. It is not an arbitrary local-wall-time grid. |
| Availability storage | `orgs/{org}/coachAvailability/{coachUid}/days/{YYYY-MM-DD}`, schemaVersion 1, windows `{branchId,startAtMillis,endAtMillis}`. One window must contain the whole booking. [JSON contract](../../contracts/v1/coach-availability.schema.json) limits windows to 96, safe positive millisecond bounds, and presently rejects metadata as additional properties. |
| Availability authoring | No real writer, async repository or availability Rules match exists. Current booking consumes these documents through the Admin SDK. Ordinary clients cannot read/write them under current Rules. |
| Locks | `orgs/{org}/slotLocks/{keyOf(coachUid, utcSlotStart)}`. Locks span branches. Only recognized expired pending holds can be replaced by the booking service; confirmed, unexpired or malformed locks fail closed. |
| Transactions | Existing [TransactionPort](../../functions/src/platform/firestore/store.ts) supports point get/create/set, not query/delete. Booking reads the day document before creating locks. No store-interface rewrite is required for B2. |
| Eligibility | Booking checks active branch, canonical active Coach membership, assigned branch and published Coach branch snapshot. B1 additionally checks current user/membership organization, verified email and active organization. Reuse the stronger B1 scope for B2. |
| Horizon | No real scheduling horizon is enforced by booking today. The mock slider is not an authoritative policy. B2's proposed authoring limit below does not retroactively add a booking horizon. |
| UI | [AvailabilityScreen](../../apps/mobile/lib/features/coaching/presentation/coach/availability_screens.dart) synchronously edits weekly WorkingDay/BlockedSlot/cap/lookahead mock objects. Firebase [CoachShell](../../apps/mobile/lib/app/shells/coach_shell.dart) deliberately disables this tab. B2 must add a live async path. |

The fixture uses `Asia/Kuala_Lumpur`; this is **fixture evidence only**. No live policy, branch assignments or availability was read during this task. Live organization timezone and policy readiness remain an activation prerequisite. There is still no verified provisioned development Coach membership established by these source checks.

### Proposed bounded decisions — require approval with B2

- **Authoring horizon:** tomorrow through organization-local today + 30 calendar days, inclusive. Same-day schedules can be read but are not edited in this initial slice. This keeps in-progress/past intervals outside the edit contract. Horizon is a server constant returned to the UI, not a new live policy field. Same-day future editing can follow separately if needed.
- **Windows:** at most 16 submitted windows per day; positive bounded safe-integer UTC timestamps on the existing 30-minute grid; end > start; every interval stays within its date; no overlaps, including across branches. Sort canonically and merge touching same-branch windows so a 60-minute hold remains covered by a single stored window. Actual assigned active branches only.
- **Removal:** replace the day with `windows: []` and increment its revision; do not hard-delete. This preserves revision history against delete/recreate baseline reuse. Removing one interval submits the remaining full-day set. Empty create/no-change save returns a validation state rather than invented activity.
- **Visibility:** canonical Coach reads/edits own schedule even before publication; canonical Admin reads scoped schedules but does not edit them in B2. Member reads only a currently published, current active Coach's windows on branches shared with the Member and the current publication/assignment. Other Coaches and staff aliases cannot inspect/edit another Coach's schedule. Deactivation or target reassignment blocks Member schedule reads even though B1's public projection withdrawal is not automatic.
- **Read mechanism:** use the authenticated read callable for all roles, including an allowlisted policy/date context. This avoids exposing the entire booking-policy document and avoids leaking unrelated branch windows from a multi-branch Firestore document. Keep direct availability reads/writes denied; **no new Rules match or index is needed** for bounded point reads. Add a Rules regression that proves denial remains. Do not loosen settings, branches or public Coach Rules.
- **Timezone conversion:** server reuses one `Intl.DateTimeFormat` per request to generate absolute UTC half-hour intervals whose start and end-minus-one have the requested local date. Enumerate a bounded UTC envelope around the parsed date; return eligible endpoints with local labels and UTC offsets. Labels distinguish repeated DST times; skipped times are never offered. Client chooses epoch values, never applies phone-local `DateTime` conversion. Fail closed for a skipped date or an unsupported unusually long day; support at most 52 half-hour slots/day. Do not manufacture local midnight by assuming every day is 24 hours.
- **Policy change:** saved day metadata records policyVersion/timeZone. A changed policy or branch baseline rejects a stale save. Stored timezone mismatch needs review; no automatic migration of schedules/bookings. Policy editing remains outside B2.

### Proposed day record and compatibility

Retain existing path, schemaVersion 1 and exact windows fields. Extend the strict JSON contract with explicit **optional** day metadata so old booking fixtures still validate; new B2-owned records require this metadata in the B2 parser:

```text
schemaVersion: 1
windows: [{branchId, startAtMillis, endAtMillis}]
revision: positive safe integer
timeZone: organization policy IANA zone
policyVersion: current booking policy version
createdAtMillis: server clock, preserved on edit
updatedAtMillis: server clock
```

The booking reader ignores these additional metadata fields and remains unchanged. No duplicate schedule/projection collection is added. Missing day = creation baseline revision 0. An existing schema-1 document without B2 metadata is a legacy record, not a missing document: show review-required/read-only and reject writes. No live migration is performed. Malformed/unknown day fields fail closed for B2 authoring rather than being dropped by replacement. No lock, booking, receipt, job or workout record is rewritten by editing availability, except the new B2 command receipt.

### Exact proposed command contracts

`getCoachAvailabilityCommand` input: `{schemaVersion:1, organizationId, coachId, firstLocalDate?, dayCount}` with real Gregorian `YYYY-MM-DD`, dayCount 1–7, range between org-local today and +30 days. Omit firstLocalDate on initial load so the server derives today; never seed it from the phone date. For a final partial page the server returns only dates within the horizon. The Coach's own UID is checked; Member/Admin may request an authorized target. Infer role/scope from current server documents, not request fields. Reject unknown input fields.

Response: `{schemaVersion:1, coachId, serverNowMillis, todayLocalDate, timeZone, policyVersion, writableFromLocalDate, writableThroughLocalDate, assignedBranchIds, days:[{localDate, revision, windows, editable, reviewRequired, boundaries}]}`. For Members, omit revision/authoring baselines/boundaries and expose only filtered schedule windows and date/zone context. Missing permitted day is an explicit empty day; forbidden/unavailable target is a safe error, not an empty-success fallback. Return branch IDs only for allowed schedule/editor scope. Reads occur through a transaction so policy/assignment/day context is consistent; cap total days/read count. No receipt for read-only operations.

`saveCoachAvailabilityDayCommand` input: `{schemaVersion:1, organizationId, requestId, localDate, expectedRevision, expectedPolicyVersion, expectedTimeZone, expectedCoachBranchIds, windows}`. Infer Coach UID exclusively from authenticated actor; no writable targetCoachId/role/status/cap. Validate canonical sorted immutable branch baseline and allowed fields. expectedRevision 0 creates only if genuinely missing. Result: `{schemaVersion:1, requestId, coachId, localDate, revision, outcome:'saved'|'removed'}`; verify result identity on the client.

Both commands use verified Auth claims, current `users/{uid}.organizationId`, matching current active membership organization, canonical roles, active organization and active permitted branches. Client session guards supplement, not replace, these checks. Follow B1 authenticated callable configuration; do not change existing booking App Check enforcement or claim a new App Check rollout. Account disable/verification claims have token propagation limits; fresh Auth lifecycle integration remains a separate live gate.

The writer uses `commandReceipts/{keyOf('saveCoachAvailabilityDay',actorUid,requestId)}` with canonical org/date/revision/policy/branch/window fingerprint. Recheck current actor authorization before replay. Same ID/same intent returns its receipt without applying again; changed intent under that ID rejects. Replay is an earlier operation receipt, not current schedule state; UI rereads. Every transaction retry uses the original expected revisions/context. No automatic retry with a newer baseline.

### Booking-lock safety

1. Transactionally read current actor assignment/membership/org/branches, policy, receipt and day. Validate context and the immutable day revision before any write.
2. Enumerate every supported half-hour slot for that local day and read the existing global Coach/time lock paths, including slots absent from the submitted windows. No collection query or lock deletion is needed.
3. Build old/new branch coverage maps for each UTC slot. A known unexpired hold or confirmed reservation requires unchanged coverage on its recorded branch. Existing live orphaned/mismatched lock versus old coverage fails closed for review. Unknown/malformed lock prevents the edit; do not reinterpret it as expired. Recognized expired holds need no interval preservation, but their lock/job/booking remain untouched.
4. Permit changes elsewhere in the day while preserving locked intervals. Removing all windows is rejected if any protected interval would be removed. Never move a protected interval to another branch.
5. Only after all reads, write the replacement day and one receipt atomically. Because createBookingHold already reads this same day, a concurrent hold/save cannot both commit an inconsistent reservation: if hold wins, save observes the lock; if save wins, hold revalidates changed coverage. Re-evaluate time on retry; keep expected baseline immutable.

B4 cancellation/expiry is not implemented. B2 neither releases locks nor claims that a pending hold was cancelled. Member schedule display does not expose lock/booking identities or declare free capacity.

## Reviewable implementation tasks

### Task 1 — Shared dated contracts and bounded server read

**Files:** create `packages/gainpath_domain/lib/src/coaching/coach_availability_contracts.dart`, export from [coaching.dart](../../packages/gainpath_domain/lib/coaching.dart); extend [coach-availability.schema.json](../../contracts/v1/coach-availability.schema.json); create `functions/src/modules/coaching/coach-availability-contracts.ts`, `coach-availability-service.ts`, `coach-availability-callables.ts`; add exports to [index.ts](../../functions/src/index.ts). Tests: new `packages/gainpath_domain/test/coach_availability_contracts_test.dart`, `functions/test/coach-availability.test.ts`.

**Interfaces:** immutable `DatedCoachWindow`, `CoachAvailabilityDay`, `CoachAvailabilityContext`, `CoachAvailabilitySaveResult`; `CoachAvailabilityRepository.load({required String coachId, String? firstLocalDate, int dayCount = 7})` and `save({required CoachAvailabilityDay baseline, required CoachAvailabilityContext context, required List<DatedCoachWindow> windows, required String requestId})`. Shared `CoachAvailabilityException` maps safe error codes. Backend exports `getCoachAvailabilityService(store, auth, input, clock = Date.now)` plus date/grid/parser helpers in the new module; no booking-service refactor.

- [ ] Add focused parser/date tests: malformed dates, negative/unsafe times, overlap, tomorrow/+30 horizon, Kuala Lumpur fixture at UTC date rollover, DST repeated/skipped boundaries and phone-zone-independent epoch selection.
- [ ] Run failing focused tests, then implement the contracts and authenticated bounded point-read context with role filtering. Test Member branch intersection, withdrawn/reassigned target and cross-org denial.
- [ ] Run `dart test test/coach_availability_contracts_test.dart` in domain and `pnpm exec vitest run test/coach-availability.test.ts` in functions. Check legacy fixture JSON still validates. Commit only this task's explicitly reviewed paths.

### Task 2 — Transactional day create/update/remove and locks

**Files:** writer in the new B2 service/callables; new `functions/emulator/coach-availability.test.ts`; focused service tests above; small additions to [firestore-rules tests](../../functions/emulator/firestore-rules.test.ts) proving availability direct-read/write denial. No production Rules edit, lock schema change or TransactionPort expansion.

**Interfaces:** `saveCoachAvailabilityDayService(store, auth, input, clock = Date.now)` implements the write contract and receipt above. Consumes Task 1 validation/date-grid helpers and existing `keyOf`, DocumentStore, safe errors.

- [ ] Add create/edit/empty-removal assertions including preserved createdAt, stale revision, same-intent receipt replay, changed-intent rejection, immutable retry baseline and role/org/branch drift.
- [ ] Add security/concurrency tests for unknown locks, expired versus unexpired holds, confirmed locks, protected branch switches, orphan locks, legacy records and changed timezone/policy.
- [ ] Implement all-reads-before-writes transaction. Run real emulator concurrent save/save and save/hold contention with bounded completion; never wait for a competing writer inside a pessimistic transaction callback.
- [ ] Verify focused B2 service/emulator plus existing booking/authorization regressions. Prove protected booking/lock/job documents are byte-for-byte unchanged by successful B2 edits. Commit this bounded backend increment.

### Task 3 — Coach live editor and Member/Admin schedule reads

**Files:** create mobile/admin `lib/infrastructure/firebase/firebase_coach_availability_repository.dart`; create mobile `lib/features/coaching/application/coach_availability_cubit.dart` and `presentation/coach/live_coach_availability_view.dart`; reuse [availability_screens.dart](../../apps/mobile/lib/features/coaching/presentation/coach/availability_screens.dart) through an explicit live branch; modify [CoachShell](../../apps/mobile/lib/app/shells/coach_shell.dart) and composition [coach_profile_factory.dart](../../apps/mobile/lib/app/di/coach_profile_factory.dart). Create shared mobile `presentation/shared/live_coach_schedule_view.dart`; inject into [live directory detail](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_directory_views.dart) through composition. Admin injects a read-only schedule panel into [directory management](../../apps/admin_web/lib/features/identity/presentation/admin/live_coach_directory_admin_view.dart) through [app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart); use a small new coaching state/view if needed to avoid cross-feature imports. All factories/routes belong to app composition.

**Interfaces:** Task 1 repository plus `bool Function() isCurrent`; Cubit `loadWeek({String? firstLocalDate})`, `openDay(String localDate)`, `saveWindows(List<DatedCoachWindow>)`, `discardAndReload()`. Read-only consumers call `load` and receive role-filtered context; no inferred totals or local fallback. Backend chooses write eligibility; UI cannot manufacture it.

- [ ] SDK adapters call the two real commands, check scope/Auth UID before and after awaits, verify response Coach/date/request identity, and translate errors without raw payload logging. Inject adapters/emulator endpoints only through composition.
- [ ] Coach tab lazily loads a seven-day dated view, date/assigned-branch selection, server-grid start/end selectors, add/edit/remove and explicit Save. Keep immutable original day/context until save or explicit discard/reload. Conflict disables Save. Successful save rereads real data.
- [ ] Keep weekly recurrence/block types/cap slider out of the live path. Member opens schedule by stable Coach UID from the published detail; Admin opens the scoped read-only schedule from existing review. Loading, no windows, denied, conflict and errors are distinct. Label timezone and “Coach schedule; booking unavailable.”
- [ ] Add minimal state/composition checks for save+reload, stale response after account/organization change, and conflict/discard/fresh-save. Reuse full B1 route guard on pushed editor/detail routes. Existing mock weekly flow remains untouched.
- [ ] Run focused mobile/admin tests and B1 role/directory regressions, maintained-source analysis and architecture checker. Commit only approved B2 paths.

### Task 4 — One integrated smoke and final source handoff

**Files:** new `apps/mobile/integration_test/coach_availability_smoke_test.dart` plus explicit synthetic emulator fixture setup under functions emulator/tool tests; report `docs/architecture/2026-10-14-b2-availability-implementation.md` (date updated if execution is later).

- [ ] Isolated Auth+Functions+Firestore emulator smoke: synthetic verified Coach saves a dated branch window using the actual callable adapter; a fresh read persists it; published Coach's same window appears to authorized Member and Admin; remove a non-locked window and reread. Negative role/org and direct-write checks remain separate focused security tests.
- [ ] If Windows CanvasKit still blocks a real Flutter/browser path, execute the real callable/emulator client smoke and separate Flutter composition fixture smoke, report them as separate boundaries, and retain actual device/browser integration outstanding. Do not call the combined fixtures a browser end-to-end test; do not spend an open-ended effort on CanvasKit.
- [ ] Run functions build/typecheck, focused B2+booking/authorization/Rules tests, domain contract tests, relevant Flutter tests, `dart run tool/check_architecture.dart` and maintained-source analysis. No broad repeated suites unless a dependency failure warrants them.
- [ ] Check changed-path allowlist, token hygiene, protected-source diffs and preservation snapshot. Locally commit and report evidence/limits. No push/deploy without approval; stop before B3.

## Effort, dependencies and definition of done

Estimated **3–4 focused days**, medium complexity: contracts/read 0.5–1 day, writer/lock safety 1 day, role UI/adapters 1 day, smoke/review 0.5–1 day. This refines the earlier 2–3 day estimate because explicit timezone context and lock-preserving edits need meaningful checks. No new identity provisioning is needed for isolated source work.

Strict gates: approve this proposal → shared context/contracts → transactional writer/lock tests → role integration → source smoke/review. Read-only UI and writer can progress independently after contracts are fixed; Step 7C remains independent. B3 must wait for B2 authoring, policy/branch context and reservation safety contracts; B4 must precede claims of safe ongoing reservation lifecycle.

Done means a real callable-backed three-role schedule path in source, isolated persisted records with correct UTC/date/branch identity, authorized reads, stale/conflicting edits rejected, locks preserved, mock compatibility, scoped evidence and local commit. It does not mean live deployment, free slots, confirmed booking, recurring schedules or device validation.

Rollback: revert only reviewed B2 source commits after approval; preserve existing dated records, revision tombstones, B1 projections, bookings/locks/jobs/receipts and unrelated evidence. Future deployment rollback needs an independent code/RPC compatibility check; never hard-delete schedules to simulate rollback.

Remaining activation gates: inspect actual development booking policy/timezone and current branch assignments; provision/verify a real Coach only after approval; fix the B1 malformed-timestamp mismatch narrowly; review B1/B2 callable and Rules deployment separately; inspect legacy schedule records before any migration; approved real role/device/browser smoke. No approval to change live state is implied by accepting this source proposal.
