# Non-core CRUD sprint — execution and integration evidence

Date: 15 October 2026, Asia/Kuala_Lumpur. Approved baseline: `6dd91d90980dcd351b9f3aec297f0e885aa60b30`. Branch: `codex/real-squat-flow`. This report accompanies the [complete module matrix](2026-10-15-non-core-crud-matrix.md), [bounded plan](2026-10-15-non-core-crud-execution.md), [Admin repair](2026-10-15-admin-crud-reliability.md) and [Member repair](2026-10-15-member-private-crud-repair.md). It does not supersede historical rollback artifacts.

## Reviewed source integration

Exact pushed source HEAD: **`99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb`**. Remote was inspected/fetched at `6dd91d9`; the outgoing chain was a clean fast-forward. Push used the explicit reviewed SHA and branch ref, without force, rebase, merge or unrelated staging. `ls-remote` matched the exact SHA after push.

| Commit | Bounded change |
|---|---|
| `84909d1c7932e4cf0f0886b19a001c9c79b926d3` | Catalog publication truthfulness and initial full non-core audit/plan |
| `431d3badbe0a73af33ef72f755727e86f7e0193c` | Catalog server read-back and uncertain-save reload |
| `359fde441ce0c1e4de3b24985de9bb9edafa4d94` | Immutable Routine Template edit baseline, transactional intended changes, authorization guard and read-back |
| `f3faca766d701da546581d044cdcc3165ef09d32` | Member profile/preferences preservation/read-back, canonical ownership Rules and focused regressions |
| `5c63f5e83fe278d52a720c0f1d48812fe2a03f6f` | Existing Admin reset callback, Firebase prototype-route guard and truthful Coach capability text |
| `99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb` | Matrix source-delta and remaining integration gates |

Read-only independent reviews found no material defect in Admin Routine/Rules, Member Android delivery or final Catalog read-back changes. The reviewers did not claim to execute tests or live calls. Member Web transaction exception preservation remains unverified; current delivery is Android. Injected SDK tests are not real browser integration.

## Actually executed checks

| Check | Result / evidence boundary |
|---|---|
| Final full Admin `flutter test --no-pub` | **79 passed**; `build/non-core-crud-sprint/admin-final-tests.log` |
| Final full Mobile `flutter test --no-pub` | **373 passed, 15 existing skips, no failures**; `build/non-core-crud-sprint/mobile-final-tests.log`; new CRUD tests have no skips |
| Full domain/data/identity suites during Member repair | **69 / 80 / 21 passed**, respectively; inspected agent execution output; no retained local stdout files claimed |
| Maintained workspace source analysis | **No issues found**; `build/non-core-crud-sprint/final-analysis.log`; final Catalog-only addition also analyzed clean |
| Architecture checker | **Architecture boundaries OK**, zero findings; production boundary rules remain enabled |
| Backend emulator-source typecheck | **Passed**; `build/non-core-crud-sprint/backend-typecheck.log`; local Node 24 engine warning is retained, CI uses Node 22 |
| Directly relevant isolated Firestore emulator files | **36 passed in 4 files**: general Rules (including Member owner reassignment), Admin CRUD authorization, Catalog transactions, trusted publication/Member discovery; `build/non-core-crud-sprint/crud-emulator-tests.log` |
| Firebase-mode Admin Web local build | **Passed** with absolute output path and bundled web resources; `build/non-core-crud-sprint/admin-firebase-final-build.log`; no Hosting deployment |
| Diff hygiene / added-line credential scan | Passed; no token-bearing media URL, private key or GitHub credential pattern in the committed additions |

Failures are retained, not hidden: Routine overwrite/read-back and stale UI regressions were first reproduced RED, then passed. Catalog's final read-back/reload cases also failed before the fix. The first full local emulator run had two Catalog assertions that assumed the client callback would execute before the newly stricter Rules rejected a revoked author; these were corrected while preserving no-write assertions. It also hit the pre-existing Windows booking contention `INVALID_ARGUMENT: Transaction is invalid or closed`. The second full local run passed all changed CRUD files but hit the same unchanged booking lifecycle failure and a booking receipt contention failure. No frozen booking implementation or tests were weakened. An initial local Web build failed at the Windows shader compiler's relative output path; the absolute-output build passed without source changes.

## Exact-commit GitHub Actions

[Verify workspace run 38692714973](https://github.com/Haise0619/gainpath/actions/runs/38692714973) **completed successfully** at exactly `99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb`. Both jobs and every required stage succeeded: Node 22 backend build, typecheck, unit suites and all 11 emulator files; architecture, maintained-source analysis, pure-Dart tooling, shared package/app tests, Admin Web build and Mobile mock APK build. The Linux/Node 22 emulator run passed the booking contention cases that failed locally on Windows/Node 24. This does not erase those disclosed local failures.

Exact-head status is retained in `build/firebase-demo-preparation/exact-head-ci-99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb.json`; completed backend and Flutter logs are the corresponding `ci-backend-...log` and `ci-flutter-...log` files there. Mock CI builds are not live Firebase/device verification and no generated APK was installed.

Downloaded backend logs confirm **307 unit tests in 16 files** and **66 emulator tests in 11 files**, all passed. Admin Web completed at `06:32:36Z`; the mock Mobile APK completed at `06:36:27Z`.

## Real Firebase / browser UAT

Project `gainpath-0619`, organization `gainpath`; no emulator connection in the locally built Admin client. The current approved task permits isolated development records only, without protected content or personal-data mutation.

- Empty Catalog Create displayed field validation and did not create a record.
- Existing authenticated Admin UI created **`exerciseVideos/s1ERYwaBd19TqXoHpk2R`**, labelled **`CRUD UAT 2026-10-15 - catalog`**, schema 1, inactive/Draft. A non-media placeholder `https://example.com/gainpath-crud-uat` was used; no private Storage URL or playable tutorial was activated.
- Independent read-only Firestore read-back confirmed its generated stable ID, Draft status, exact non-media fixture and server creation/update timestamps (`2026-10-15T06:18:22.792245Z`). This validates the already-existing live create path, not the later rebuilt client by assumption.
- The final repaired Firebase Admin client was built into `build/non-core-crud-sprint/admin-firebase`. Original <http://localhost:7357/> retained an older cached Flutter client: its form still showed the old “Member preview” copy, despite the local server's JavaScript hash matching the new compiled bundle (`F73FB72E0C03BC1A05EEC96B883992B3454AF19E95C792DA635D502DEB9A815E`). Source UAT was paused rather than misreported. The same unmodified build is served only over loopback at the fresh <http://localhost:7358/> origin. The owner signed in there; the live form displayed the new “Catalog preview” wording, explicit stable exercise ID and save/publish/Member-refresh guidance. The original `build/firebase-demo-preparation/admin-web` and server script remain preserved. No credential or Firebase Auth persistence policy was changed to work around the cache.
- **Completed after the owner's fresh-origin sign-in:** Catalog read/edit/save/activate/deactivate/reload and Routine draft create/read/update/add/remove/save/reload passed through the actual Flutter Web UI against the development Firebase project. See the exact completion evidence below. No duplicate exercise or hard-delete operation was used.
- No live routine was published or republished. Current source cannot withdraw a disposable public routine through the product. Isolated emulator publication/republish/Member-refresh passed; an approved live test retention plan is still required.
- No live Member profile/goals/preferences values were changed. Exact owner-approved before/after values and approval for a compatible updated client are required before that physical UAT; no APK was installed.

### Completed browser smoke and retained test records

| Existing workflow | Actual live steps and read-back |
|---|---|
| Catalog update and activation | Opened only `s1ERYwaBd19TqXoHpk2R`; changed name to `CRUD UAT 2026-10-15 - catalog edited` and Draft → Active. Saving disabled the save control; the server-backed list then displayed the edited name, same ID and Active status. Independent Firestore read-back confirmed update `2026-10-15T06:56:58.942579Z` and unchanged creation timestamp/category/schema/non-media fixture URL. |
| Routine create/read | Created only `routineBlueprints/VGkLOYv1nn8R193biEAK`, named `CRUD UAT 2026-10-15 - routine draft`; description `Isolated CRUD test draft. Do not publish.`, 30 minutes, Day 1, 3×10 targeting the isolated Catalog ID. Save completed and the server-backed list reloaded. Independent read-back confirmed creation `2026-10-15T06:59:03.129138Z`, existing schema 1 and stable ID. |
| Routine update/add | Reopened the new blueprint; renamed it `CRUD UAT 2026-10-15 - routine edited`, added a second row referencing the same isolated exercise with 2×5. Save/read-back confirmed ordered rows 3×10 then 2×5, same blueprint ID and creation timestamp (`updatedAt` `2026-10-15T07:01:03.127439Z`). No existing blueprint was edited. |
| Routine remove/reload | Reopened the persisted two-row blueprint, removed only its second row and saved. UI reload displayed one exercise; expanded breakdown showed the original Day 1 3×10. Independent read-back at `07:02:21Z` confirmed only the original target remained; final document update `07:01:52.767522Z`. |
| Catalog deactivation/retention | Reopened the isolated exercise with a fresh baseline; selected Active → Draft and saved. UI reloaded with the same edited name/ID and Draft status. Final read-back confirmed `isActive: false`. The original protected squat and the owner's separate Testing exercise were not edited. |
| Final retention/preservation | At `2026-10-15T07:04:26Z`, private before/after comparison confirmed Catalog final changes only `exerciseName`/`updatedAt`; routine final changes only `name`/`updatedAt`, after the temporary added row was removed. All unrelated fields, creation identity and original targets were preserved. `content/routine_VGkLOYv1nn8R193biEAK` returned 404: the test blueprint is **unpublished**. No new draft-status field or withdrawal schema was introduced. |

Final fixtures are intentionally retained: inactive Catalog exercise and clearly labelled unpublished Routine blueprint. Its exercise is inactive, so publishing/editing targets must pass the existing active-catalog checks before any later use. There is no supported Routine delete/withdraw operation; no direct privileged deletion was used for cleanup. Actual live stale-editor conflicts, account/role drift and validation extremes remain software/emulator evidence rather than additional live mutations.

Sanitized results: `build/non-core-crud-sprint/isolated-uat-result.json`; private before/added-row/final snapshots stay under ignored `private/`. Browser screenshots without account/email details: [inactive Catalog](../../build/non-core-crud-sprint/catalog-inactive-uat.jpg), [unpublished Routine breakdown](../../build/non-core-crud-sprint/routine-draft-uat.jpg). These local artifacts are evidence, not committed source or public media URLs. Software tests and the older installed phone client are not physical validation of the new Member repairs.

## Preservation and privacy

Private before snapshots and token-bearing data remain in ignored `build/non-core-crud-sprint/private/`, never Git or public reports. At `2026-10-15T06:21:37Z`, read-only comparison found **all 17 protected documents unchanged**, all **14 Function revisions unchanged**, both **Firestore/Storage Rules releases unchanged**, and all **6 indexes unchanged**. New isolated UAT records are tracked separately from those protected anchors. No Auth user, membership, existing Catalog anchor, blueprint, publication, booking or personal record was mutated by this sprint.

All **66 pre-existing modified/untracked files** matched their original byte hashes after the source commits. This includes README, run configuration, local evidence and historical reports. Frozen production source comparisons found no changes in pose/native, SquatAnalyzer, workout/session/history/progress, consent/outbox/acceptance, backend booking implementations, contracts, Storage Rules or indexes. `firebase/firestore.rules` changes are limited to three current-organization ownership/author predicates and are **not deployed**.

Final repeat at `2026-10-15T06:43:14Z`: all 17 protected documents, Functions, Rules and indexes still unchanged; all 66 preserved files and frozen source still unchanged; remote HEAD still exactly `99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb`. This execution report remains a local, uncommitted evidence artifact so it does not create an unverified source HEAD after the green CI run.

**After live UI completion**, the final preservation repeat at `2026-10-15T07:04:32Z` again passed: all 17 protected documents, all Function revisions, both Rules releases and all indexes unchanged; all 66 original files and frozen source unchanged. Only the two explicitly identified new UAT records were written. No deployment or phone operation occurred in this continuation.

## Remaining delivery gates and next module

Essential verification remains supported C/R/U/deactivate, validation, authoritative persistence, owner/role/org denial, original-baseline concurrency and uncertain-result recovery, plus one representative integrated smoke. Trusted publication retains stronger transaction/receipt/security checks. Repetitive presentation tests, screenshot pixel assertions, cosmetic refinements, new broad reporting tests and repeated unchanged core/booking suites are safely deferred. Existing skipped tests and Windows contention failures are disclosed; no required authorization/data-integrity check is bypassed. The earlier CanvasKit test environment issue was not pursued: the actual rebuilt local Firebase Admin browser rendered, while device and browser boundaries remain explicit below.

1. Catalog/draft Routine representative live UAT is complete. Retain the two labelled fixtures as described above; additional multi-editor/account-drift live tests are not claimed. Do not edit protected source content or silently delete test records.
2. Review/approve selective deployment of only the narrowed Firestore Rules; no Function/index/Storage deployment is needed by these repairs. Confirm canonical user/membership organization fields on real participating accounts before deployment. Rollback is the preserved prior Rules release plus scoped source revert, never record deletion.
3. Approve a compatible client update for Member profile/preferences UAT using the owner's exact values and existing local-data/signature preservation checks. No body measurement, goal or preference is invented. Admin reset delivery can be tested only against an owner-approved address; none was sent here.
4. Agree a public test-routine retention/withdrawal decision before live publication → Member Refresh routines verification. Tutorial media activation remains a separate frozen task.
5. The next proposed new business module is **Admin announcements → Member Home**, FR-11.6 content subset, described in the matrix. It needs explicit scope/schema/authorization approval before source implementation. No Payment, Rewards, Chatbot, reporting, notifications-delivery, booking expansion or core task is started.

All first-three workflows now have bounded software reliability repairs and focused security checks. Live deployment, personal mutation and unapproved new modules remain explicit stopping boundaries; full FR completion is not claimed.

## Exact committed path inventory

47 paths at the exact pushed HEAD; this execution report is a separate local evidence document.

- [apps/admin_web/lib/app/admin_app.dart](../../apps/admin_web/lib/app/admin_app.dart)
- [apps/admin_web/lib/app/di/app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart)
- [apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart](../../apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart)
- [apps/admin_web/lib/features/workout/presentation/admin/routine_templates_screen.dart](../../apps/admin_web/lib/features/workout/presentation/admin/routine_templates_screen.dart)
- [apps/admin_web/lib/infrastructure/firebase/exercise_catalog_store.dart](../../apps/admin_web/lib/infrastructure/firebase/exercise_catalog_store.dart)
- [apps/admin_web/lib/infrastructure/firebase/firebase_auth_gateway.dart](../../apps/admin_web/lib/infrastructure/firebase/firebase_auth_gateway.dart)
- [apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart)
- [apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart](../../apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart)
- [apps/admin_web/test/admin_password_reset_test.dart](../../apps/admin_web/test/admin_password_reset_test.dart)
- [apps/admin_web/test/exercise_catalog_concurrency_test.dart](../../apps/admin_web/test/exercise_catalog_concurrency_test.dart)
- [apps/admin_web/test/exercise_catalog_conflict_ui_test.dart](../../apps/admin_web/test/exercise_catalog_conflict_ui_test.dart)
- [apps/admin_web/test/firebase_routine_authoring_ui_test.dart](../../apps/admin_web/test/firebase_routine_authoring_ui_test.dart)
- [apps/admin_web/test/routine_template_concurrency_test.dart](../../apps/admin_web/test/routine_template_concurrency_test.dart)
- [apps/mobile/lib/app/mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart)
- [apps/mobile/lib/app/routing/feature_routes.dart](../../apps/mobile/lib/app/routing/feature_routes.dart)
- [apps/mobile/lib/features/identity/presentation/coach/live_coach_profile_views.dart](../../apps/mobile/lib/features/identity/presentation/coach/live_coach_profile_views.dart)
- [apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart](../../apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart)
- [apps/mobile/lib/features/identity/presentation/member/fitness_profile_gate.dart](../../apps/mobile/lib/features/identity/presentation/member/fitness_profile_gate.dart)
- [apps/mobile/lib/features/identity/presentation/member/profile_setup_screen.dart](../../apps/mobile/lib/features/identity/presentation/member/profile_setup_screen.dart)
- [apps/mobile/lib/features/identity/presentation/member/save_live_profile.dart](../../apps/mobile/lib/features/identity/presentation/member/save_live_profile.dart)
- [apps/mobile/lib/infrastructure/firebase/firebase_fitness_profile_gateway.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_fitness_profile_gateway.dart)
- [apps/mobile/lib/infrastructure/firebase/firebase_member_preferences_repository.dart](../../apps/mobile/lib/infrastructure/firebase/firebase_member_preferences_repository.dart)
- [apps/mobile/test/firebase_legacy_route_guard_test.dart](../../apps/mobile/test/firebase_legacy_route_guard_test.dart)
- [apps/mobile/test/firebase_member_private_documents_test.dart](../../apps/mobile/test/firebase_member_private_documents_test.dart)
- [apps/mobile/test/fitness_profile_flow_test.dart](../../apps/mobile/test/fitness_profile_flow_test.dart)
- [apps/mobile/test/fitness_profile_gate_test.dart](../../apps/mobile/test/fitness_profile_gate_test.dart)
- [apps/mobile/test/member_settings_flow_test.dart](../../apps/mobile/test/member_settings_flow_test.dart)
- [apps/mobile/test/support/fitness_profile_fake.dart](../../apps/mobile/test/support/fitness_profile_fake.dart)
- [docs/architecture/2026-10-15-admin-crud-reliability.md](../../docs/architecture/2026-10-15-admin-crud-reliability.md)
- [docs/architecture/2026-10-15-member-private-crud-repair.md](../../docs/architecture/2026-10-15-member-private-crud-repair.md)
- [docs/architecture/2026-10-15-non-core-crud-matrix.md](../../docs/architecture/2026-10-15-non-core-crud-matrix.md)
- [docs/planning/2026-10-15-non-core-crud-sprint.md](2026-10-15-non-core-crud-execution.md)
- [firebase/firestore.rules](../../firebase/firestore.rules)
- [functions/emulator/admin-crud-authority.test.ts](../../functions/emulator/admin-crud-authority.test.ts)
- [functions/emulator/catalog-edit-transactions.test.ts](../../functions/emulator/catalog-edit-transactions.test.ts)
- [functions/emulator/firestore-rules.test.ts](../../functions/emulator/firestore-rules.test.ts)
- [packages/gainpath_data/lib/gainpath_data.dart](../../packages/gainpath_data/lib/gainpath_data.dart)
- [packages/gainpath_data/lib/src/firebase_fitness_profile_repository.dart](../../packages/gainpath_data/lib/src/firebase_fitness_profile_repository.dart)
- [packages/gainpath_data/lib/src/member_document_snapshot.dart](../../packages/gainpath_data/lib/src/member_document_snapshot.dart)
- [packages/gainpath_data/test/firebase_fitness_profile_repository_test.dart](../../packages/gainpath_data/test/firebase_fitness_profile_repository_test.dart)
- [packages/gainpath_domain/lib/src/fitness_profile.dart](../../packages/gainpath_domain/lib/src/fitness_profile.dart)
- [packages/gainpath_domain/lib/src/member_preferences.dart](../../packages/gainpath_domain/lib/src/member_preferences.dart)
- [packages/gainpath_domain/lib/src/workout/entities/routine_blueprint.dart](../../packages/gainpath_domain/lib/src/workout/entities/routine_blueprint.dart)
- [packages/gainpath_domain/lib/src/workout/repositories/routine_template_repository.dart](../../packages/gainpath_domain/lib/src/workout/repositories/routine_template_repository.dart)
- [packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart](../../packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart)
- [packages/gainpath_identity/lib/src/fitness_profile_cubit.dart](../../packages/gainpath_identity/lib/src/fitness_profile_cubit.dart)
- [packages/gainpath_identity/test/fitness_profile_cubit_test.dart](../../packages/gainpath_identity/test/fitness_profile_cubit_test.dart)
