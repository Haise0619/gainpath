# B1 — real Coach profile and published directory source implementation

Date: 2026-10-14. Approved source baseline: `19d584eb1759e395f97f0128285747daa31ad52a`. Scope: the [approved B1 design](../planning/2026-10-14-b1-coach-profile-directory-design.md), following the [MVP order](../planning/2026-10-14-mvp-vertical-slices.md). **Source implementation and isolated verification only.** No live Firebase writes, deployment, Coach provisioning, push, APK build/install or B2/B3 implementation.

## Implemented three-role workflow

**Coach:** Firebase login now reaches the existing Coach shell with a real own-profile repository. The profile view loads the private draft and public publication state. The editor saves displayName, specialty, bio, specializationTags and nullable self-reported yearsExperience. It shows saved draft/pending Admin publication; it does not publish itself. Immutable revisions protect edits; conflicts disable saving until explicit discard/reload. Same-intent transport retries reuse their operation ID. Roster, availability, earnings, certification/photo/price operations remain unavailable. Existing mock Coach flows remain separate and compatible.

**Admin:** the existing Coaches sidebar now opens real draft/public directory management. Canonical Admin capability is checked against current own server assignment/membership; staff aliases do not gain publication authority from the client's collapsed `AppRole.admin`. Admin can review by stable UID, publish a validated snapshot, or deactivate a public record. Public-only rows remain discoverable/deactivatable when a draft or target membership is missing. Counts describe loaded records, not an invented organization total. No mock account creation, password reset, certification verification or identity suspension is enabled.

**Member:** the existing Coaches tab opens an organization-scoped published directory with 20-item pages plus one lookahead, stable document-ID cursors, explicit load-more and server refresh. Search is labeled as search of loaded Coaches. Opening a profile revalidates the exact UID with a bounded published range query; withdrawal/error is truthful. Profiles show only real professional fields and server-assigned branch IDs. No rating, review, fee, earnings, certification badge, fixed consultation duration or simulated booking is fabricated. Booking remains unavailable. The directory mounts on first tab visit, avoiding reads/SDK creation during unrelated Member flows.

Every pushed live Coach editor and Member detail route is guarded by its originating full AuthSession. Logout/account/org/role/branch/verification drift removes old role content and invalidates repository lifetimes. Known authorization denial also clears stale controller state. Existing Member profile, A1 selection/tutorial, measured progress/history and local consent/outbox behaviors are preserved.

## Real Firebase contracts

| Collection | Ownership and behavior |
|---|---|
| `orgs/{org}/coachProfiles/{coachUid}` | New private professional draft v1; own verified active canonical Coach get, canonical Admin get/list; client writes denied |
| `orgs/{org}/coaches/{coachUid}` | Existing public projection collection; stable Auth UID, published/inactive status, server branch IDs, source/public revision and timestamps; client writes denied |
| `orgs/{org}/commandReceipts/{key}` | Existing trusted receipt mechanism; command/actor/request key and canonical intent fingerprint; no client write/read capability added |
| Existing `users`, `members`, organization and `branches` | Read as current authority only; no role/assignment/identity/branch mutation |

Private/public professional fields share bounded validation: name/specialty 1–80 trimmed characters, bio 0–1000, 1–8 unique tags of 1–40 characters, experience null or integer 0–60. Server controls schema 1, positive revision, created/updated times. Public projection also carries status, branchIds, sourceRevision and publishedAtMillis. It contains no private identity/contact/certification data or unsupported aggregates. Private unknown fields are preserved and never projected; incompatible public versions/unknown fields fail closed rather than silently being overwritten.

`saveCoachProfileCommand` accepts `{schemaVersion:1, organizationId, requestId, expectedRevision, patch}`. Own UID is inferred from Auth. Allowed patch keys are the five professional fields only; creation requires all five. Current verified caller, canonical Coach role, matching user/membership organization, active organization and bounded active branch assignments are checked transactionally. Read original revision, reject conflict, merge only intentional fields plus revision/server timestamps, preserve creation/unrelated fields and record the receipt. It never changes public content or identity.

`setCoachDirectoryStatusCommand` accepts `{schemaVersion:1, organizationId, coachId, requestId, action, expectedPublicRevision}` plus `expectedProfileRevision` and `expectedCoachBranchIds` **only for publish**. Current canonical Admin authorization is required before receipt replay and before mutation. Publication checks target Auth existence/non-disabled/verified email through `getAuth().getUser` outside the retryable transaction, then rechecks target assignment/membership/active branches and both immutable revisions/branch baseline within Firestore. Only allowlisted fields are projected. The Auth observation and Firestore transaction are not atomic across the two services.

Deactivation does not require a draft or eligible target identity. It preserves the public snapshot and creation/publication provenance while setting inactive, updated time and next revision. Already inactive at the expected revision is a receipt-backed no-op. Same ID/same intent replays without reapplying; changed intent under that ID rejects. Current actor authorization is checked even on replay. Retries never adopt a new baseline. Errors expose safe messages, not raw request/document bodies.

Exactly two undeployed callable exports are added. They follow the existing publisher's callable configuration and authenticated error mapping. No existing booking/workout App Check policy changes; no client App Check rollout is claimed. No index or Storage change was needed by the executed query shapes.

The only Rules changes are the private profile match and narrowed public Coach read authority. B1 reads require current `users/{uid}.organizationId` and matching active membership organization, preventing stale membership access after reassignment. Private drafts are excluded from ordinary Member/other-Coach/staff reads. Inactive public owner access additionally requires canonical Coach role; ordinary Members, including former Coaches, read only published rows. Organization-wide directory visibility remains; branch/availability booking eligibility is separate.

## Exact source and test paths

The local commit contains these B1 paths, this report and the unchanged approved B1 design. Historical CRUD/MVP/audit/CI documents remain outside the commit.

| Layer | Changed paths |
|---|---|
| Shared pure-Dart contracts | [identity.dart](../../packages/gainpath_domain/lib/identity.dart), [coach_profile_contracts.dart](../../packages/gainpath_domain/lib/src/identity/coach_profile_contracts.dart), [contract tests](../../packages/gainpath_domain/test/coach_profile_contracts_test.dart) |
| Trusted backend | [index.ts](../../functions/src/index.ts), [coach-profile-service.ts](../../functions/src/modules/coaching/coach-profile-service.ts), [coach-profile-callables.ts](../../functions/src/modules/coaching/coach-profile-callables.ts), [coach-identity-reader.ts](../../functions/src/modules/coaching/coach-identity-reader.ts) |
| Backend/Rules tests | [service tests](../../functions/test/coach-profile.test.ts), [callable error tests](../../functions/test/coach-profile-callables.test.ts), [Coach emulator smoke](../../functions/emulator/coach-directory.test.ts), [firestore.rules](../../firebase/firestore.rules) |
| Mobile composition | [mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart), [coach_profile_factory.dart](../../apps/mobile/lib/app/di/coach_profile_factory.dart), [coach_shell.dart](../../apps/mobile/lib/app/shells/coach_shell.dart), [member_shell.dart](../../apps/mobile/lib/app/shells/member_shell.dart) |
| Mobile Firebase | [profile repository](../../apps/mobile/lib/infrastructure/firebase/firebase_coach_profile_repository.dart), [directory repository](../../apps/mobile/lib/infrastructure/firebase/firebase_coach_directory_repository.dart) |
| Mobile feature state | [profile Cubit](../../apps/mobile/lib/features/identity/application/coach_profile_cubit.dart), [directory Cubit](../../apps/mobile/lib/features/coaching/application/coach_directory_cubit.dart) |
| Mobile existing layouts/live branches | [coach_account_screen.dart](../../apps/mobile/lib/features/identity/presentation/coach/coach_account_screen.dart), [live_coach_profile_views.dart](../../apps/mobile/lib/features/identity/presentation/coach/live_coach_profile_views.dart), [browse_coaches_screen.dart](../../apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart), [live_coach_directory_views.dart](../../apps/mobile/lib/features/coaching/presentation/shared/live_coach_directory_views.dart) |
| Mobile tests | [profile state](../../apps/mobile/test/coach_profile_state_test.dart), [directory state](../../apps/mobile/test/coach_directory_state_test.dart), [role UI smoke](../../apps/mobile/test/coach_directory_flow_test.dart), [app entry/sign-out regressions](../../apps/mobile/test/app_test.dart), [Member profile/tab regressions](../../apps/mobile/test/fitness_profile_flow_test.dart) |
| Admin composition | [admin_app.dart](../../apps/admin_web/lib/app/admin_app.dart), [admin_feature_availability.dart](../../apps/admin_web/lib/app/admin_feature_availability.dart), [app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart), [admin_shell.dart](../../apps/admin_web/lib/app/shells/admin_shell.dart) |
| Admin state/data/UI | [Firebase repository](../../apps/admin_web/lib/infrastructure/firebase/firebase_coach_profile_admin_repository.dart), [Admin Cubit](../../apps/admin_web/lib/features/identity/application/coach_directory_admin_cubit.dart), [coaches_screen.dart](../../apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart), [live management view](../../apps/admin_web/lib/features/identity/presentation/admin/live_coach_directory_admin_view.dart), [Admin tests](../../apps/admin_web/test/coach_directory_publication_flow_test.dart) |

Shared real profile models are immutable and have no fake required metrics; legacy mutable Coach/CoachRepository stay the mock contract. SDK adapters remain app infrastructure; composition owns route/session guards and injects domain ports. The live editor/directory views are small branches beside existing mock layouts, not another app/runtime or a replacement identity system.

## Executed verification and limits

Ignored local evidence: `build/b1-coach-directory/`. No CI run or app build was performed for B1; the previously green A1 run is not B1 evidence.

| Verification | Actual result |
|---|---|
| Pure-Dart `dart test test/coach_profile_contracts_test.dart` | **3 passed** |
| Functions build and `typecheck:tests` | Exit 0; local Node 24.19.0 emitted project Node 22 engine warning. Deploy/runtime validation is separate |
| Focused backend plus authorization/booking/publisher regressions | **51 passed**, 5 files: `coach-profile`, `coach-profile-callables`, `authorization`, `booking`, `publish-routine` |
| Actual Firestore emulator group | **20 passed**, 3 files: `coach-directory`, existing `firestore-rules`, existing A1 `published-routine-discovery` |
| Relevant mobile group | **36 passed**, 11 files: B1 profile/directory state/UI, app entry, A1 catalog/reader/navigation, fitness profile, local progress, tutorials and workout composition |
| Final focused B1 mobile run | **8 passed**, including same-account branch/verification route-drift regressions |
| Admin complete suite | **56 passed**; final focused B1 run **2 passed** |
| Maintained-source analysis | `No issues found!` |
| Architecture checker | `Architecture boundaries OK`, zero findings |
| Source review | One Important editor-route lifetime defect reproduced RED and fixed GREEN; one minor malformed-timestamp validation mismatch deferred below |

Emulator command (in functions, Java 21, isolated `demo-gainpath`):

```powershell
pnpm exec firebase emulators:exec --project demo-gainpath --config ../build/b1-coach-directory/emulator/emulator.json --only firestore 'vitest run --config vitest.emulator.config.ts emulator/coach-directory.test.ts emulator/firestore-rules.test.ts emulator/published-routine-discovery.test.ts'
```

The actual Firestore smoke executes production profile/publication services and FirestoreStore against synthetic identities, with Rules-bound Firebase JS clients. It proves create/read/update, private versus public snapshots, Admin review/publication, Member visibility/withdrawal, source-field preservation, role/org/current-assignment denial and real simultaneous-save contention. The target Auth reader is explicitly an injected synthetic observation; it does not prove real Firebase Auth provisioning/verification or callable network transport.

The callback retry is explicitly simulated by discarding a successful callback's writes, changing real persisted state, and rerunning with the same expected revision. An earlier fixture awaited a competing writer inside a pessimistic transaction and deadlocked; the harness was corrected without changing production transaction behavior. This simulation is separate from actual Firestore contention, and is not claimed as a forced real SDK retry.

Flutter tests use explicit scoped port fixtures to verify the actual role composition and navigation, including no local activity/outbox writes and stale route removal. They are not Flutter native/browser-to-emulator integration. Existing Member entry/tab expectations were updated only for the newly connected Coach workflow and existing confirmation-sheet sign-out. No fake production fallback was introduced.

## Preservation, decisions and remaining gates

No BlazePose/SquatAnalyzer, counting/form/scoring, exercise binding, workout data/history, consent/outbox, Firebase workout acceptance or enabled tuple source changes. No content/publication algorithm change. README, run configuration, old P0 edits and historical rollback artifacts remain untouched/excluded. Recorded hashes/presence of the 52-entry pre-existing snapshot are unchanged; new B1 files/report contain no private tutorial token-bearing URL. There are no new package dependencies.

Implementation decisions: retain the user's dedicated checkout and explicitly stage B1 paths; preserve ignored evidence instead of deleting it; mount Member directory lazily; leave private target identity/Auth checks on the trusted server; label the retry simulation accurately. Automatic approval review rejected an initially generated formatter path list as potentially including unrelated files; an explicit reviewed B1 allowlist was used successfully. Required braces were added only at B1 lint locations. No blocked approval remains.

**Deferred minor:** backend stored-timestamp validation currently accepts negative safe integers, while Dart rejects them. Normal server-created timestamps are unaffected; malformed externally authored records can therefore need an authorized schema review rather than being usable in the UI. No extra data repair or cosmetic testing was added for this existing-data edge case.

**Live blockers:** the previous read-only inspection found no provisioned Coach membership/public record in development `gainpath`. B1 does not create one. Need explicit approval for real Coach account provisioning/assignment and genuine email verification, then current canonical Admin/branch validation. Need review/push/exact-head CI approval, selective deployment of the two new callables and reviewed Firestore Rules, fresh revision snapshots/read-back, and approved live role/browser/device smoke. App Check activation remains a separate decision. No Rules/index/Functions deployment is implied by local tests.

Account suspension/reassignment/Auth disable does **not** automatically withdraw an existing public projection. Admin directory deactivation is separate from identity lifecycle; future identity management must integrate withdrawal. Booking already requires live membership/branch/publication checks, but booking, availability, certification review and paid consultation are not operational outcomes of B1. Manual refresh/detail revalidation is not a real-time withdrawal subscription.

**B2 readiness:** after B1 source acceptance, dated availability CRUD can reuse stable Coach UID, current Coach/Admin authority, assigned active branches and the published Coach contract expected by the existing booking service. Next bounded design should use `orgs/{org}/coachAvailability/{coachUid}/days/{YYYY-MM-DD}` with schema 1 windows `{branchId,startAtMillis,endAtMillis}`, organization timezone and future-date bounds; define trusted own CRUD and scoped Member/Admin reads, preserving any reserved intervals. Existing mock weekly availability is not the physical dated-window contract. Review required availability Rules/commands and booking policy/timezone inputs before implementation. Do not add B3 holds, checkout or confirmed bookings during B2.

Rollback is a reviewed source revert of B1 only. No B1 live data or local workout migration exists. Future deployment needs independent Rules/function/public-content rollback snapshots and must preserve private drafts, receipts, identity and all workout/booking records. Stop for source review; no next module has begun.
