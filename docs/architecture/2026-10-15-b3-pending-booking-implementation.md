# B3 — Real pending booking and shared role visibility

Completed source implementation across 2026-10-14/15, Asia/Kuala_Lumpur. Approved baseline: `51ddc66ef132f992d0c6b21e50c64836cc0663cc`; reviewed code/test head: `db2aea27f82688d338d01411be82ce4bbe0eb8b1`. All commits remain local on `codex/real-squat-flow`. The approved design is preserved at `docs/planning/2026-10-14-b3-pending-booking-plan.md`.

**Verified boundary:** working source integration, deterministic security/contract tests, isolated real Firebase SDK/Auth/Functions/Firestore persistence, and injected Flutter composition. **Not established:** deployed Firebase operation, provisioned real Coach identity, native Flutter-to-Firebase transport, genuine App Check attestation or device/browser validation. No deployment, live records, Console settings, private debug registration, push, APK build/install or Step 7C activity occurred.

## User-visible source behavior

- **Member:** published directory retains stable Coach UIDs; detail/schedule links to real eligible 30/60-minute options. Date/branch/start epochs come from the backend. Submit requests a pending hold, displays its actual ID and UTC expiry, and links to My bookings. My bookings is available even with an empty directory or App Check off. Unknown outcomes retain the same immutable operation ID/payload; selecting another time is blocked until recovery or explicit warned local discard. Repeated selection of the same option retains the ID. No fake checkout or confirmed/paid result.
- **Coach:** Firebase Roster opens a real read-only assigned-booking list, scoped to current active branches. Availability/Profile continue through B1/B2. Earnings, notes, chat, completion and other unsupported live workflows stay unavailable.
- **Admin:** View bookings is available beside View schedule in the existing selected-Coach review. It reads that Coach's persisted organization records through current canonical Admin authority; no booking status write or fabricated account creation is added. Staff aliases receive no Admin callable list authority.
- **All lists:** same persisted booking ID/status/expiry, original timezone/server labels, bounded current/upcoming range, manual refresh and pagination. Expiry labels include the calendar date because tomorrow's appointment can expire today. A pending hold past expiry remains `pending_hold`, labelled time elapsed/expiry processing unavailable; no local status mutation or expiry worker exists.

Mock layouts/repositories remain separate. Full captured session guards protect new pushed routes and stale asynchronous completions, including account, organization, role and branch changes. No workout results, history, progress scoring, consent/outbox, exercise bindings, enabled tuples, BlazePose or SquatAnalyzer behavior changed.

## Exact backend and persisted contracts

Existing write callable [createBookingHold](../../functions/src/modules/coaching/create-booking-hold.ts) remains `enforceAppCheck: true` with verified Auth. [Request schema](../../contracts/v1/create-booking-hold.request.schema.json):

```text
schemaVersion: 1
requestId, organizationId, memberId, coachId, branchId: identifiers
startAtMillis: positive bounded safe UTC integer
durationMinutes: 30 | 60
```

No other input fields are accepted. Identifier grammar is `[A-Za-z0-9_-]{1,128}`. The mobile adapter binds memberId/current organization to its authenticated immutable scope and verifies Auth UID before/after awaited operations. Server authorization remains authoritative, including delegated Staff/Admin creation supported by the pre-existing backend; the B3 Member UI only exposes self-booking.

Response: exactly `{schemaVersion:1, requestId, bookingId, status:'pending_hold', holdExpiresAtMillis}`. Strict Dart decoding rejects other statuses or mismatched request IDs. The async request/DTO now includes memberId/schemaVersion; legacy mutable mock booking interfaces remain unchanged.

New [getMemberBookingOptionsCommand](../../functions/src/modules/coaching/member-booking-options-callable.ts), also App Check enforced:

```text
input: schemaVersion, organizationId, coachId, durationMinutes, localDate?
output: schemaVersion, coachId, durationMinutes, serverNowMillis,
        todayLocalDate, localDate, timeZone, throughLocalDate,
        permittedBranchIds, options, unavailableReason?
option: branchId, startAtMillis, endAtMillis, startLabel, endLabel
```

The caller must be a current verified Member. Date defaults to server-local today; horizon today..today+30 inclusive. Empty allowed results distinguish `no_open_times`/`daily_limit`; authorization, malformed data, missing policy and ineligible Coach are errors, not empty mock success. An option is a snapshot, never a reservation guarantee.

New [getBookingListCommand](../../functions/src/modules/coaching/booking-read-callables.ts) is a verified authenticated read; no new Admin web App Check registration is required for this read-only operation:

```text
input: schemaVersion, organizationId, coachId?, firstLocalDate?, dayCount?, cursor?
cursor: startAtMillis, bookingId
output: schemaVersion, serverNowMillis, timeZone, firstLocalDate,
        throughLocalDate, records, nextCursor?
```

Member rejects supplied coachId and queries own UID; Coach permits absent/self coachId and current active assigned branches; canonical Admin requires selected Coach UID; Staff callable access rejects. First date defaults to server today; dayCount 1..31, clipped to +30. Fixed query limit21 returns at most20, timestamp ascending then document-ID ascending, cursor from the last returned row. This is not complete historical reporting.

Records allowlist: schemaVersion, bookingId, organizationId, memberId, coachId, branchId, requestId, startAtMillis, endAtMillis, durationMinutes, status, holdExpiresAtMillis, localDate, original timeZone/policyVersion, createdAtMillis, startLabel/endLabel/expiryLabel. `createdBy` is validated but removed. No receipts, email/phone, private profile/medical data, fees, earnings or metrics are returned. Known raw statuses remain pending_hold/confirmed/cancelled/completed/refunded; B3 only creates pending_hold.

Existing collection ownership and write shapes are retained:

| Path under `orgs/{organizationId}` | B3 use |
|---|---|
| `bookings/{uuid}` | Sole persisted booking; no duplicate projection |
| `slotLocks/{keyOf(coachUid, utcHalfHour)}` | Global Coach/time locks across branches; one/two per hold |
| `bookingDays/{keyOf(memberUid, localDate)}` | Current organization-local daily accounting |
| `commandReceipts/{keyOf('createBookingHold', actorUid, requestId)}` | Fingerprinted idempotent result |
| `jobs/{keyOf('expireBookingHold', bookingId)}` | Existing pending job only; no worker added |
| `coachAvailability/{coachUid}/days/{date}` | Read valid B2 metadata/windows; no schedule migration |
| `settings/booking`, `members`, `branches`, `coaches`, current `users` | Authoritative policy/scope/publication inputs |

## Authorization, locking and recovery

[Shared B3 validation](../../functions/src/modules/coaching/booking-validation.ts) checks current account/membership organization, canonical active membership, active organization, active shared branches and current published Coach. New holds/options require existing enabled verified Coach Auth through the B1 identity reader. Auth lookup occurs outside retried transactions; Firestore scope/publication is rechecked transactionally. Auth disable can race a lookup/commit and claims can lag revocation; no instantaneous lifecycle guarantee or automatic projection withdrawal is claimed.

New holds require valid B2 metadata, matching current timezone, future UTC half-hour starts, one-local-date whole interval and current daily cap/hold length. Changed policyVersion alone does not migrate or invalidate an otherwise compatible stored window. Legacy/malformed days remain review-required. Server date grids handle DST labels/bounds without assuming 24-hour days. B3 metadata rejects control/blank policy versions and numeric-only timezone offsets incompatible with its pure-Dart IANA-name contract.

Every bounded date slot is inspected before writes. Literal recognized lock statuses are required: arrays cannot be coerced into accepted values. Malformed/orphaned/mismatched locks fail closed. Live/confirmed coverage cannot be reclaimed; known expired pending locks can be replaced under the existing contract. Sixty-minute holds require both slots. Member/day accounting identity/timezone/entries are validated. The day document shared with B2 creates serializable hold-versus-edit contention; no booking/lock deletion was added.

Current actor/recipient authority precedes receipt replay. A matching existing receipt returns the original result, even after expiry or Coach eligibility/publication/policy changes. Missing receipt leads to one captured external Auth lookup; the final transaction checks receipt again **before** applying lookup failure, preserving concurrent recovery. IDs/fingerprint remain stable across retries; replay does not renew a hold. Changed intent under an ID rejects. Malformed receipts fail for review.

The Flutter controller preserves uncertainty through later rejection and already-exists conflicts. No automatic new intent is generated after uncertain transport. Local discard explicitly warns that a hold may exist; it is not cancellation. Intent storage is in-memory for the route lifetime; no durable booking outbox was introduced. After restart, inspect My bookings; the app does not automatically recreate a hold.

[Booking Rules](../../firebase/firestore.rules) changes are confined to the booking match: current account/membership organization, active org, canonical owner roles, Coach active assigned branch, Admin organization authority and retained current Staff branch read. Member ownership survives branch removal within its current organization. All client booking writes remain denied. Service authorization surrounds the SDK query because Admin SDK bypasses Rules. Unrelated Rules helpers/matches remain unchanged.

Exactly two [indexes](../../firebase/firestore.indexes.json) added from implemented SDK queries: Member `memberId ASC,startAtMillis ASC`; Coach `coachId ASC,branchId ASC,startAtMillis ASC`. Admin per-Coach uses existing coachId/start index. The ascending name suffix matches timestamp/document-ID ordering. Emulator success does not establish deployed compound indexes.

## App Check and dependency boundary

Pinned mobile firebase_app_check **0.4.8**; only its platform-interface **0.4.2+1** and web **0.2.6+1** entries were added to the lockfile. No existing locked package version was upgraded. Two mechanical tracked Windows plugin registration files changed; Windows Firebase support did not expand.

After Firebase initialization, Android booking capability reads `APP_CHECK_MODE=off|debug|production`, default **off**. Production uses Play Integrity; debug is explicit and refuses actual release builds. Initialization/token failure becomes booking-unavailable without falling back, disabling enforcement or breaking existing auth/content/progress/B1/B2. Lists remain authenticated reads independent of booking attestation readiness. No private tokens or raw SDK errors are logged or committed. Tests use injected synthetic token callbacks; no private token was registered or real provider activated.

The actual SDK smoke uses a **test-only CustomProvider with a synthetic emulator JWT**, guarded to demo-gainpath and exact localhost ports. Installed emulator tooling skips cryptographic App Check verification. Its success proves header transport, guarded handler execution and persistence, not signatures, private debug registration or Play Integrity. Missing-header rejection and unchanged booking/lock/accounting/receipt/job snapshots were separately asserted while Auth remained valid.

## Verification actually executed

| Verification | Result / boundary |
|---|---|
| Domain/data focused contracts plus representative legacy | 13 domain,4 data passed |
| Final backend `pnpm run build`, `typecheck:tests`, `pnpm test` | Passed; **275 tests /14 files** |
| Real Firestore transaction/B2 suites | **11 passed**; explicit synthetic Coach eligibility, real transaction adapter |
| Rules and real SDK query suites | **25 passed** (20 Rules +5 read/query) |
| Mobile full `flutter test --no-pub` | **349 passed,15 existing skipped** |
| Admin full `flutter test --no-pub` | **59 passed** |
| Post-lint focused mobile/state/composition/legacy and Admin | **19 +2 passed** |
| Final architecture checker | **Architecture boundaries OK**, exit0 |
| Final CI-style maintained-source analysis | **No issues found**, exit0 |
| Actual Auth+Functions+Firestore JS SDK smoke, rerun after metadata fix | **Passed**, exit0 |
| Smoke outside dedicated emulator environment | Refused before Admin initialization, exit1 |

The [SDK smoke](../../functions/emulator/booking-callable-smoke.cjs) executes real trusted Coach profile save/publication, real B2 day save/read, Member options, simultaneous competing Member holds, exactly one winner/two locks, same-ID replay, changed-intent rejection, persisted same ID/status/expiry in all three role lists, direct write/role/org denial, missing App Check header with zero booking changes, withdrawal/new-options denial while existing receipt/list remain recoverable. No real project resources or workout records were used.

Reproduce with `pnpm run test:booking:callable` in functions using the [dedicated emulator config](../../firebase/booking.emulator.test.json). Project is hardcoded demo-gainpath; tests own synthetic identities and isolated localhost ports. Do not substitute the live project. Existing occupied ports were not killed; dedicated test ports avoided unrelated processes.

Runtime: Flutter3.38.9/Dart3.10.8; local Node24.19.0/pnpm11.25.0 versus project-declared Node22. The engine warning, firebase-functions upgrade notice, emulator negative-denial logs and existing pose skips are acknowledged, not suppressed as new success. No Node22 or exact-head B3 CI result is claimed; no B3 push occurred. Prior B2 CI does not validate these new commits. Flutter widget/state evidence uses injected repositories; it is not actual browser/native Firebase integration. Windows CanvasKit remains deferred.

Local ignored evidence under `build/b3-implementation/`: task-1..4 reports and review packages; `backend-final.log`, `backend-build-final.log`, `backend-typecheck-final.log`, metadata RED logs, `sdk-smoke-final.log`, `architecture-final.log`, `maintained-analysis-final.log`, preserved-before.json and progress.md. App suite counts/commands are recorded in task-4-report.md; no nonexistent raw app log artifact is claimed. Task reviews and a fresh whole-source review approved the final code; no outstanding B3 blocker was identified.

## Preservation, limitations and next gates

All60 pre-existing uncommitted entries were preserved by presence/hash checks. Unrelated README, run configuration, P0 plan and historical reports/rollback evidence remain unstaged. Protected pose/identity/native Android/workout/analytics/consent/source and B1/B2 runtime diffs are empty. Targeted source/document token-bearing URL scan is clean; this is not a universal repository credential audit. No staging of unrelated files, merge, rebase or force push occurred.

Two **pre-existing, separately reviewed pre-live fixes** remain outside this source slice:

1. B1 [stored timestamp validation](../../functions/src/modules/coaching/coach-profile-service.ts#L48) accepts negative safe integers that the Dart profile contract rejects. No B1 refactor/fix was folded into B3.
2. B2 [lock-status coercion](../../functions/src/modules/coaching/coach-availability-service.ts#L102) uses String(lock.status), so array-shaped malformed values can bypass its literal-state protection. New B3 validation rejects those values and cannot produce them, but the older B2 validator was deliberately left intact under the approved boundary. Require a narrow regression/fix review before live activation; do not treat previous malformed-lock evidence as covering this case.

Further activation approvals: inspect current development policy/timezone/caps/hold length/branches; provision/verify a real Coach and memberships; review current deployed B1/B2 foundations; approve selective create/options/list Functions plus booking Rules/index deployment; register private Android development App Check and configure production provider; verify deployed indexes; approve Firebase-mode device/browser smoke. No broader App Check enforcement rollout is implied. Existing public Coach projections still are not automatically withdrawn on account suspension/reassignment.

**B4 readiness:** source contracts and genuine persisted pending holds are ready for the next bounded cancellation/expiry design. B4 must establish authorized transition/status contracts, idempotent cancellation/expiry ownership, exact lock ownership checks, daily-accounting release and job retries/races. No cancellation, worker, payment, confirmation, refund execution or completion was implemented here. Sustainable ongoing booking lifecycle and coordinated live demonstration remain gated by B4 and separate activation approval.

Rollback: retain these local commits for review; a later approved revert should target only B3 commits. Never delete booking/lock/receipt/accounting/job records to simulate rollback. No live records or installed APK were changed, so there is no live/device rollback action in this task.

Stop after this local-source handoff. No push, deployment or B4 implementation without approval.

## Exact commits and changed paths

The generated inventory below covers the seven reviewed code/test commits. This report is the only subsequent documentation addition.


| SHA | Change |
|---|---|
| `28d324eaea03e6f1f7625457b13820e6cdc66853` | feat(booking): add strict wire and immutable read contracts |
| `5163a8f9ebc2fe5fc98cc030c1baa9f1e0c9fa95` | feat(coaching): add authoritative booking options and harden holds |
| `e4afd0463bc7994131413518dc9888edb219357e` | fix(coaching): reject nonliteral reservation lock statuses |
| `9b486fae82103ed94bf900c6f2908fcd76d72152` | feat(coaching): add scoped persisted booking lists |
| `1fc24f64bf8b9b14f6314450da05399e9d1a19cc` | feat(booking): integrate guarded live booking roles and App Check readiness |
| `ad4049de9f270c0e5b9c3a6340d427429f5df7db` | fix(coaching): align booking metadata with shared wire validation |
| `db2aea27f82688d338d01411be82ce4bbe0eb8b1` | test(coaching): verify persisted three-role booking callable flow |

66 distinct source/test/configuration paths:

- [apps/admin_web/lib/app/admin_app.dart](../../apps/admin_web/lib/app/admin_app.dart)
- [apps/admin_web/lib/app/di/app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart)
- [apps/admin_web/lib/app/di/booking_factory.dart](../../apps/admin_web/lib/app/di/booking_factory.dart)
- [apps/admin_web/lib/app/shells/admin_shell.dart](../../apps/admin_web/lib/app/shells/admin_shell.dart)
- [apps/admin_web/lib/features/coaching/application/booking_list_cubit.dart](../../apps/admin_web/lib/features/coaching/application/booking_list_cubit.dart)
- [apps/admin_web/lib/features/coaching/presentation/admin/booking_list_view.dart](../../apps/admin_web/lib/features/coaching/presentation/admin/booking_list_view.dart)
- [apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart](../../apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart)
- [current Admin coach management](../../apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart)
- [apps/admin_web/lib/infrastructure/firebase/firebase_booking_list_repository.dart](../../apps/admin_web/lib/infrastructure/firebase/firebase_booking_list_repository.dart)
- [apps/admin_web/test/booking_list_test.dart](../../apps/admin_web/test/booking_list_test.dart)
- [apps/mobile/lib/app/di/booking_factory.dart](../../apps/mobile/lib/app/di/booking_factory.dart)
- [apps/mobile/lib/app/di/coach_profile_factory.dart](../../apps/mobile/lib/app/di/coach_profile_factory.dart)
- [apps/mobile/lib/app/mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart)
- [apps/mobile/lib/app/shells/coach_shell.dart](../../apps/mobile/lib/app/shells/coach_shell.dart)
- [apps/mobile/lib/app/shells/member_shell.dart](../../apps/mobile/lib/app/shells/member_shell.dart)
- [apps/mobile/lib/features/coaching/application/live_booking_cubit.dart](../../apps/mobile/lib/features/coaching/application/live_booking_cubit.dart)
- [apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart](../../apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart)
- [apps/mobile/lib/features/coaching/presentation/member/live_member_booking_view.dart](../../apps/mobile/lib/features/coaching/presentation/member/live_member_booking_view.dart)
- [apps/mobile/lib/features/coaching/presentation/shared/live_booking_list_view.dart](../../apps/mobile/lib/features/coaching/presentation/shared/live_booking_list_view.dart)
- [apps/mobile/lib/features/coaching/presentation/shared/live_coach_directory_views.dart](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_directory_views.dart)
- [apps/mobile/lib/features/coaching/presentation/shared/live_coach_schedule_view.dart](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_schedule_view.dart)
- [apps/mobile/lib/infrastructure/firebase/firebase_app_check_readiness.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_app_check_readiness.dart)
- [apps/mobile/lib/infrastructure/firebase/firebase_booking_repository.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_booking_repository.dart)
- [apps/mobile/lib/infrastructure/firebase/firebase_bootstrap.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_bootstrap.dart)
- [apps/mobile/pubspec.yaml](../../apps/mobile/pubspec.yaml)
- [apps/mobile/test/firebase_booking_repository_test.dart](../../apps/mobile/test/firebase_booking_repository_test.dart)
- [apps/mobile/test/live_booking_composition_test.dart](../../apps/mobile/test/live_booking_composition_test.dart)
- [apps/mobile/test/live_booking_cubit_test.dart](../../apps/mobile/test/live_booking_cubit_test.dart)
- [apps/mobile/windows/flutter/generated_plugin_registrant.cc](../../apps/mobile/windows/flutter/generated_plugin_registrant.cc)
- [apps/mobile/windows/flutter/generated_plugins.cmake](../../apps/mobile/windows/flutter/generated_plugins.cmake)
- [contracts/v1/get-booking-list.request.schema.json](../../contracts/v1/get-booking-list.request.schema.json)
- [contracts/v1/get-booking-list.response.schema.json](../../contracts/v1/get-booking-list.response.schema.json)
- [contracts/v1/get-member-booking-options.request.schema.json](../../contracts/v1/get-member-booking-options.request.schema.json)
- [contracts/v1/get-member-booking-options.response.schema.json](../../contracts/v1/get-member-booking-options.response.schema.json)
- [firebase/booking.emulator.test.json](../../firebase/booking.emulator.test.json)
- [firebase/firestore.indexes.json](../../firebase/firestore.indexes.json)
- [firebase/firestore.rules](../../firebase/firestore.rules)
- [functions/emulator/booking-callable-smoke.cjs](../../functions/emulator/booking-callable-smoke.cjs)
- [functions/emulator/booking-read.test.ts](../../functions/emulator/booking-read.test.ts)
- [functions/emulator/coach-availability.test.ts](../../functions/emulator/coach-availability.test.ts)
- [functions/emulator/firestore-rules.test.ts](../../functions/emulator/firestore-rules.test.ts)
- [functions/emulator/transactions.test.ts](../../functions/emulator/transactions.test.ts)
- [functions/package.json](../../functions/package.json)
- [functions/src/index.ts](../../functions/src/index.ts)
- [functions/src/modules/coaching/booking-list-service.ts](../../functions/src/modules/coaching/booking-list-service.ts)
- [functions/src/modules/coaching/booking-query-reader.ts](../../functions/src/modules/coaching/booking-query-reader.ts)
- [functions/src/modules/coaching/booking-read-callables.ts](../../functions/src/modules/coaching/booking-read-callables.ts)
- [functions/src/modules/coaching/booking-service.ts](../../functions/src/modules/coaching/booking-service.ts)
- [functions/src/modules/coaching/booking-validation.ts](../../functions/src/modules/coaching/booking-validation.ts)
- [functions/src/modules/coaching/create-booking-hold.ts](../../functions/src/modules/coaching/create-booking-hold.ts)
- [functions/src/modules/coaching/member-booking-options-callable.ts](../../functions/src/modules/coaching/member-booking-options-callable.ts)
- [functions/src/modules/coaching/member-booking-options-service.ts](../../functions/src/modules/coaching/member-booking-options-service.ts)
- [functions/test/booking-fixture.ts](../../functions/test/booking-fixture.ts)
- [functions/test/booking-list.test.ts](../../functions/test/booking-list.test.ts)
- [functions/test/booking.test.ts](../../functions/test/booking.test.ts)
- [functions/test/coach-availability.test.ts](../../functions/test/coach-availability.test.ts)
- [functions/test/member-booking-options.test.ts](../../functions/test/member-booking-options.test.ts)
- [packages/gainpath_data/lib/src/booking_repository.dart](../../packages/gainpath_data/lib/src/booking_repository.dart)
- [packages/gainpath_data/test/booking_repository_test.dart](../../packages/gainpath_data/test/booking_repository_test.dart)
- [packages/gainpath_domain/lib/gainpath_domain.dart](../../packages/gainpath_domain/lib/gainpath_domain.dart)
- [packages/gainpath_domain/lib/src/coaching.dart](../../packages/gainpath_domain/lib/src/coaching.dart)
- [packages/gainpath_domain/lib/src/coaching/booking_read_contracts.dart](../../packages/gainpath_domain/lib/src/coaching/booking_read_contracts.dart)
- [packages/gainpath_domain/lib/src/coaching/booking_wire_validation.dart](../../packages/gainpath_domain/lib/src/coaching/booking_wire_validation.dart)
- [packages/gainpath_domain/test/booking_read_contracts_test.dart](../../packages/gainpath_domain/test/booking_read_contracts_test.dart)
- [packages/gainpath_domain/test/contracts_test.dart](../../packages/gainpath_domain/test/contracts_test.dart)
- [pubspec.lock](../../pubspec.lock)
