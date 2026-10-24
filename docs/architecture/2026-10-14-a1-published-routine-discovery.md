# A1 — Member published routine browsing, selection and refresh

Date: 2026-10-14. Approved baseline: `e14f877f8cf2eb333eab909891a1b4df0b0133ca`, branch `codex/real-squat-flow`. This bounded source increment implements A1 from the [approved MVP plan](../STATUS.md) and [CRUD integration matrix](../STATUS.md). The matrix exists under `docs/planning`, rather than the architecture path in the request. Neither historical document was moved or overwritten.

## Result and read contract

**Verified source behavior:** Firebase Members can browse a bounded catalog in the existing Workout layout, select a published routine by content document ID, load another page, and refresh without logging out. Home and Workout receive the same selected object. Home's Start action opens the shared Workout tab. Existing Detail and Tutorial navigation receives the selected routine/exercise IDs and targets; unsupported exercises still cannot launch the real squat route.

The Firebase adapter reads only `orgs/{organizationId}/content`, filtered by `status == published` and `kind == routine`, ordered by document ID. Default page size is 20; each page fetches at most 21 documents for lookahead. The next cursor is the last returned item, not the lookahead document. The reader uses server reads with a 20-second timeout, checks the current authenticated UID and active scope before/after reads, and retains the existing schema parser. Existing Rules and indexes are unchanged. Emulator queries passed; a live-project query/index smoke remains unexecuted.

Selection is in-memory and session-scoped. Initial selection is the first deterministic published item. Refresh hides the previous launchable snapshot until revalidated. A selected ID absent from the refreshed page is revalidated using the same organization/published/kind query, ordered by document ID, `startAt([id])`, `limit(1)`. Only an exact returned ID match is accepted; a neighboring result is absence, never a replacement selection. This range query passed unchanged Rules for drafts and withdrawal. An earlier equality-on-document-ID query was denied for a draft by the emulator; it was corrected without relaxing Rules.

Successful revalidation preserves selection and refreshes its content. An unavailable selected ID is cleared and the Member must choose again. Network, authorization and parse failures show a retry state rather than claiming withdrawal or falling back to mock content. Logout, role loss or account/organization change invalidates the controller and pending requests. Generation checks also discard older refresh responses. Load-more errors retain the already loaded, authorized page and offer a retry.

No selection preferences, assignment records, catalog writes, publication commands, workout records or new Firebase schemas are introduced. Existing injected single-routine loaders retain a compatibility adapter; default Firebase composition uses the paged reader. Mock composition remains unchanged.

## Exact changed paths

| Path | Purpose |
|---|---|
| [published_routine_catalog_repository.dart](../../apps/mobile/lib/features/workout/domain/published_routine_catalog_repository.dart) | Scoped asynchronous read port and immutable page |
| [published_routine_catalog_cubit.dart](../../apps/mobile/lib/features/workout/application/published_routine_catalog_cubit.dart) | Shared selection, refresh, paging, invalidation and safe errors |
| [firebase_published_routine_repository.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart) | Bounded server catalog and selected-ID reads; legacy `load()` compatibility |
| [published_routine_catalog_factory.dart](../../apps/mobile/lib/app/di/published_routine_catalog_factory.dart) | Composition factory and legacy loader adapter |
| [mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart) | Inject Firebase catalog through existing auth composition |
| [member_shell.dart](../../apps/mobile/lib/app/shells/member_shell.dart) | Own session state and feed the same selection to both tabs |
| [member_home_screen.dart](../../apps/mobile/lib/app/home/member_home_screen.dart) | Truthful routine state and shared Workout-tab callback |
| [workout_prep_route.dart](../../apps/mobile/lib/app/routing/workout_prep_route.dart) | Pass state/controls through existing route |
| [workout_prep_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart) | Insert compact controls in existing preparation layout |
| [published_routine_catalog_controls.dart](../../apps/mobile/lib/features/workout/presentation/member/published_routine_catalog_controls.dart) | Stable-ID selector, refresh/load-more and truthful states |
| [published_routine_catalog_test.dart](../../apps/mobile/test/published_routine_catalog_test.dart) | Six focused state/selection/stale-response checks |
| [firebase_published_routine_catalog_test.dart](../../apps/mobile/test/firebase_published_routine_catalog_test.dart) | Two SDK query-contract/session checks using explicit test doubles |
| [member_routine_discovery_flow_test.dart](../../apps/mobile/test/member_routine_discovery_flow_test.dart) | One representative Flutter composition/navigation/preservation smoke |
| [published-routine-discovery.test.ts](../../functions/emulator/published-routine-discovery.test.ts) | One real isolated Firestore publication/read/Rules smoke |
| This report | Behavior, evidence, limits and B1 handoff |

## Executed verification

Logs are preserved locally under ignored `build/a1-routine-discovery/`. No build or installation was performed.

| Check | Executed result / boundary |
|---|---|
| `dart run tool/check_architecture.dart` | Exit 0, `Architecture boundaries OK`, zero findings |
| Maintained-source `dart analyze` | Exit 0, `No issues found`; `tool`, root `test`, and existing source/test/tool folders under packages/apps, using the path selection in [verify.ps1](../../tool/verify.ps1) |
| Mobile focused regressions below | Exit 0, **44 tests passed**, including nine new tests and existing mock/composition/tutorial/profile/local-progress/real-workout regressions |
| `pnpm exec vitest run test/publish-routine.test.ts` in functions | Exit 0, **20 tests passed**; production publisher source unchanged |
| `pnpm run typecheck:tests` in functions | Exit 0; local Node 24.19.0 emitted the existing engine warning (project specifies Node 22). This is not deployed-runtime validation |
| Isolated Firestore smoke below | Exit 0, **1 test passed**, with actual unchanged Rules and production `publishRoutine` service/Firestore store against `demo-gainpath` |
| Final source review | No material bugs or A1 acceptance gaps found; read-only review, not additional device evidence |

Mobile command, run in `apps/mobile`:

```powershell
flutter test --no-pub test/published_routine_catalog_test.dart test/firebase_published_routine_catalog_test.dart test/member_routine_discovery_flow_test.dart test/published_routine_test.dart test/published_tutorial_test.dart test/tutorial_navigation_test.dart test/workout_prep_composition_test.dart test/real_workout_ui_test.dart test/member_local_progress_flow_test.dart test/fitness_profile_flow_test.dart
```

Emulator command, run in `functions`, with Android Studio's Java 21 runtime and isolated ports configured in the ignored local config (unchanged repository Rules/indexes):

```powershell
pnpm exec firebase emulators:exec --project demo-gainpath --config ../build/a1-routine-discovery/emulator/emulator.json --only firestore 'vitest run --config vitest.emulator.config.ts emulator/published-routine-discovery.test.ts'
```

The emulator smoke seeds only synthetic identities/catalog/blueprints, executes trusted fixture publication of two routines, and uses a real Rules-bound Member Firebase JS client to read pages, revalidate a selected ID, and observe fresh fixture publication. It verifies draft exclusion, withdrawal, cross-organization/unverified denial, exact exercise targets/media, and absence of workout/consent writes. The Flutter smoke independently verifies the shared selector/Home/Workout/Detail/Tutorial path with injected scoped repositories and unchanged local session/outbox snapshots. SDK-double tests are query-contract tests, not Firestore integration.

The final regression run followed a compatibility correction: the existing empty-state label was restored to `No published routine yet`, rather than changing the old test expectation. No unrelated test infrastructure was repaired.

## Preservation and remaining boundaries

Exercise identity, target parsing, tutorial media policy, real squat binding checks, algorithms, scoring, local history, consent/outbox, workout acceptance and enabled tuples are unchanged. Firebase production source, Rules, indexes and schema files have no A1 changes. Test-only SDK annotation suppressions are confined to the manual query-double file; runtime architecture checks remain enabled.

Original README, run configuration, P0 planning edits, historical reports and rollback artifacts are preserved and excluded from this commit. The preservation check confirms all 52 entries in the pre-existing snapshot remain present with unchanged recorded hashes. The two approved CRUD audit/plan documents are also left unedited and excluded. A1 source/report uses no private tutorial Download URL. The emulator media is a synthetic `example.test` URL. No private media URL was fetched or logged.

**Not executed:** actual Flutter browser/native Firebase plugin-to-emulator flow, Xiaomi interaction/playback, live catalog query, live authoring/publication, callable transport/App Check, deployment, exact-head remote CI, APK build/install. This is layered software integration evidence, not a full browser/device end-to-end demonstration. Existing Windows CanvasKit limitations remain documented and were not expanded into A1 work.

Previously opened Detail/Tutorial routes retain their immutable navigation snapshot; manual refresh updates the shell for subsequent navigation. This is not a real-time revocation subscription or an in-progress workout reassignment mechanism. Multiple page reads are not a transactional snapshot; explicit refresh reconciles the selected item. Selection is not durable across logout/restart. These are deliberate scope boundaries.

**Content-flow readiness:** the existing Admin authoring → trusted publisher → Member discovery/selection/detail/tutorial path is source-complete for this bounded workflow and demonstrated in separate isolated backend and Flutter smoke boundaries. Live end-to-end activation is still unvalidated. The separate P8.1B rename/media/publisher/device approvals remain required; A1 neither changes their IDs/targets nor performs their operations. Step 7C remains independent.

Rollback is a reviewed revert of this A1 commit only. There are no A1 live-data changes or local-history migrations to undo.

## Exact next increment — B1 Coach Profile/Directory (not implemented)

1. **Confirm identity and contracts first:** use an existing verified/provisioned Coach and scoped Admin account; inspect current role/branch policy and `orgs/{org}/coaches/{coachId}`. Existing [Rules](../../firebase/firestore.rules) permit published/own/Admin reads but deny client writes. [CoachRepository](../../packages/gainpath_domain/lib/src/identity/repositories/coach_repository.dart) is synchronous prototype data; the [Coach entity](../../packages/gainpath_domain/lib/src/identity/entities/coach.dart) carries seeded rating/reviews/session metrics. Define the smallest async scoped profile/public-directory port and truthful optional display data, reusing these concepts without inventing ratings or certifications. Account provisioning remains a separately reviewed increment if existing Coach identities are unavailable.
2. **Implement bounded trusted profile commands:** own Coach edits validated professional fields; Admin publishes/deactivates the existing public projection. Explicitly separate editable profile data from server-owned verification/publication/aggregate fields. Check current membership/role/organization/branch and revision on writes; preserve unrelated fields, use stable operation IDs where a receipt is needed. Review contracts/schema/Rules needs before coding, rather than assuming the mock mutable object is a production contract. Any eventual deployment/live writes require separate approval.
3. **Connect the existing layouts:** [mobile composition](../../apps/mobile/lib/app/mobile_app.dart) currently leaves Firebase Coach at the identity-ready screen. Connect only real profile/directory capability in the [Coach shell](../../apps/mobile/lib/app/shells/coach_shell.dart), [Coach account](../../apps/mobile/lib/features/identity/presentation/coach/coach_account_screen.dart), [Member directory](../../apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart), and scoped [Admin availability gate](../../apps/admin_web/lib/app/admin_feature_availability.dart). Keep unsupported earnings, appointments, certification approval and checkout unavailable. Preserve mock behavior and account invalidation.
4. **Verify one complete slice:** isolated Coach create/read/update → Admin publication/deactivation → Member authorized directory read, plus essential role/org rejection and concurrent-field preservation. Add one representative composition smoke, maintained-source analysis and architecture checks. Defer cosmetic permutations. Review/commit B1 independently before B2 dated availability CRUD; B3 Member booking and cross-role status requires B2 plus corrected booking DTO/query/authorization contracts. No booking or payment success is implied by B1.

Estimated B1 effort: medium–high, 3–5 focused development days, excluding account provisioning, deployment approval and physical smoke. A1 acceptance is the gate to beginning B1; this report does not start it.
