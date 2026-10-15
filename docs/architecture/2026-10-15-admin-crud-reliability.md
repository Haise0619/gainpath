# Existing Admin CRUD reliability repair — 2026-10-15

Scope: [approved non-core sprint](../planning/2026-10-15-non-core-crud-sprint.md). Existing layouts, repositories, collections, stable IDs, targets and trusted publication are retained. This source repair introduces no Firebase schema, Function, index, migration, deletion/withdrawal capability or deployment. Tutorial activation remains frozen.

## Confirmed defects and source changes

**Catalog:** the existing immutable original-document/assignment/membership comparison, retry behavior and intended-field transaction patch were retained. The Firebase preview now explains that catalog activation only permits routine authoring: save and trusted publication are separate. Unsupported prototype preview metrics are omitted only in Firebase mode. A further reproduced defect was that save returned locally submitted data without server read-back. Both create and edit now perform a single-document `Source.server` read before success. Uncertain saves require explicit discard/reload, preventing repeated create attempts after an unconfirmed commit. Raw transport/media details never appear in the error. Mock behavior remains separate.

**Routines:** the old adapter used unconditional `.update()` of every editable field, so two editors overwrote each other. The repaired domain object carries an optional opaque, nonserialized original baseline. Its owning Firebase adapter freezes the full original document, membership and canonical assignment. The submitted editable fields and nested arrays are captured before awaiting. Every transaction attempt compares the same original snapshot and current authority, checks all referenced exercises remain active, and writes only intentionally changed fields plus the existing `updatedAt`/`updatedBy`. No-op saves do not normalize or rewrite old optional defaults. Creation uses the existing schema and generated ID in a transaction. Postcommit `Source.server` read-back must decode successfully before reporting success; failure requires reload rather than a potentially duplicating retry.

Routine validation follows existing publisher bounds: 1–120-character name; 5–240 whole minutes; 1–14 uniquely numbered days; 1–20 exercises per day and 50 total; stable catalog IDs, sets 1–50 and reps 1–100. Existing UI supports adding/removing days and exercises. It has no reorder control; none was invented. Save remains distinct from publication. Publication uses the existing trusted command and fresh request ID; no backend publisher or media policy changed. UI blocks duplicate in-flight saves/publications and stale saves, offers discard/reload, and sanitizes publication failures.

Admin composition now supplies the existing latched `CatalogEditSessionGuard` to routines as well as Catalog. The narrower `contentAuthor` Rules predicate also requires both the canonical user assignment and membership organization to match. Staff authoring remains compatible; this does not grant Staff canonical Admin publication of Coach profiles. Member owner predicates are documented in the separate [Member repair](2026-10-15-member-private-crud-repair.md). Rules changes are source-only.

## Source and tests

Catalog paths:

- [UI](../../apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart)
- [Firebase repository](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart), [existing transport](../../apps/admin_web/lib/infrastructure/firebase/exercise_catalog_store.dart)
- [safe failure contract](../../packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart)
- [transaction/read-back tests](../../apps/admin_web/test/exercise_catalog_concurrency_test.dart), [UI conflict/reload tests](../../apps/admin_web/test/exercise_catalog_conflict_ui_test.dart)

Routine paths:

- [entity baseline](../../packages/gainpath_domain/lib/src/workout/entities/routine_blueprint.dart), [safe failures](../../packages/gainpath_domain/lib/src/workout/repositories/routine_template_repository.dart)
- [Firebase repository](../../apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart), [composition](../../apps/admin_web/lib/app/di/app_repositories.dart), [existing form/list](../../apps/admin_web/lib/features/workout/presentation/admin/routine_templates_screen.dart)
- [12 injected-SDK repository cases](../../apps/admin_web/test/routine_template_concurrency_test.dart), [builder/conflict UI](../../apps/admin_web/test/firebase_routine_authoring_ui_test.dart)

Authorization boundary: [Rules](../../firebase/firestore.rules), [Admin CRUD Rules tests](../../functions/emulator/admin-crud-authority.test.ts), [existing Catalog SDK contract](../../functions/emulator/catalog-edit-transactions.test.ts). Existing Catalog emulator assertions now permit earlier Rules denial when canonical assignment changes before commit; privileged read-back still proves no overwrite. They do not require a retry after Rules already rejected the operation. Deterministic Dart tests continue to check immutable retry baselines.

## Executed verification and boundaries

Original Routine defects were reproduced in six failing repository regressions; missing conflict UI was separately reproduced. Repository create/update/no-op, retries, account/role drift, inactive catalog, missing record, bounds and read-back plus existing builder/UI tests passed (16 tests). Existing full Admin suite then passed 72; the added reset callback raised it to 76. Final Catalog read-back/reload defects were reproduced with three failing cases, then the directly affected Catalog/mock/bridge suite passed all 39. Final all-source counts and exact-head CI are recorded in the sprint execution report, rather than treating these interim counts as the final suite.

Four directly relevant isolated emulator files passed **36 tests**: general Firestore Rules including Member owner reassignment, Admin author assignment, Catalog transactions and trusted published-routine discovery. These exercise actual SDK/Rules and backend publication; they are not Flutter browser integration or live project mutation evidence.

Two full local emulator runs exposed the unchanged Windows contention error `INVALID_ARGUMENT: Transaction is invalid or closed` in booking lifecycle; the second also hit booking receipt contention. The first additionally had two now-corrected Catalog assertion failures after Rules started rejecting revoked authors earlier. No frozen booking source, assertions or concurrency protections were weakened. Final CI must report the full backend/emulator result independently.

Local Firebase Admin Web build initially failed because the Windows shader compiler could not write a relative output path. The same build with an absolute output path passed. Original rollback build/server script remain preserved. No Hosting deployment or phone installation occurred.

Live testing is restricted to separately labelled new UAT records. Existing exercise, blueprint and published routine are protected. Live routine publication is not executed without an approved retention/withdrawal plan: current source has no supported public-routine withdrawal/delete. Member personal writes require exact owner-approved values; no synthetic personal values are written live. See the final execution report for actually completed browser and read-back checks.
