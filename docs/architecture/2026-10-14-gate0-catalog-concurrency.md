# Gate 0 — concurrency-safe Admin Exercise Catalog editing

Implemented on 2026-10-14 from `58efe0e1edeea6161da1bce75da823e3d6927077`, branch `codex/real-squat-flow`. Scope is the authorized Admin source prerequisite from the [rename impact review](2026-10-14-p8-1br-exercise-rename-impact.md) and [activation plan](../planning/p8-1b-bodyweight-squat-rename-activation-plan.md). No activation is performed by this change.

## Before and after

Previously, an existing-record save blindly updated name, URL, category, active status and schema from an old form. It did not read the current document or retain its original metadata. Raw exceptions were interpolated into the form error.

Now a server catalog load attaches an opaque, immutable baseline to each existing TutorialVideo. The form retains that exact baseline and ID throughout its lifetime. The baseline contains a deep immutable snapshot of the full catalog document, the user's organization assignment and author membership, and is bound to the originating repository lifetime/document ID. It is a captured **field snapshot**, including `updatedAt`, not Firestore metadata `updateTime`. Capturing it during catalog load is conservative: changes between loading the list and opening the form also cause a conflict.

Every save attempt transactionally reads `users/{uid}`, `orgs/{org}/members/{uid}` and the same catalog document before writing. It verifies assignment organization, active Admin/Staff membership, original authorization snapshots and original catalog snapshot. Deleted/missing documents, missing edit baselines and baselines from another repository fail closed. Neither the baseline nor the patch is rebuilt during automatic transaction retries.

Only changed `exerciseName`, `videoUrl`, `muscleCategory` and/or `isActive` fields are patched, with server `updatedAt` supplied by the Firestore transport. Unchanged normalized text does not cause incidental writes. No-op saves perform guarded reads without changing timestamps. ID, `createdAt`, schema and all fields outside the explicit patch remain untouched. Category/status remain editable when deliberately changed; a name/URL-only edit leaves them untouched and rejects concurrent changes to them.

A catalog conflict displays a fixed safe message, disables Save, and provides **Discard edits and reload catalog**. Reload exits the form, loads current catalog data, and requires reopening the exercise; it does not merge or silently rebase old edits. Authorization failures invalidate the repository permanently and require a fresh authenticated composition. Account/scope/role/verification/session changes and disposal invalidate the composition guard; a restored old identity cannot revive that edit. Server assignment/membership drift and permission rejection are also latched. AppRepositories is keyed by the full immutable AuthSession so changed authorization context obtains a fresh provider lifetime.

Flutter web's installed transaction bridge wraps Dart callback errors in JS errors. The actual Firestore transport captures safe domain conflict/authorization failures, including recognized callback Firebase authorization errors, outside the retryable callback and restores their types after rejection. It still throws inside the callback to abort the write. This preserves the form's conflict/reload behavior on web. Other transport failures are sanitized into fixed messages. No new logging, private media URL fixture or Firebase schema is introduced.

Creation retains generated IDs, the existing encoder and server creation/update timestamps. Mock storage retains its prototype fields and session behavior. The added baseline is optional and opaque in the pure-Dart domain; Firestore types stay in Admin infrastructure. The transport seam exercises the **same repository callback**, not a second editing API or service.

## Exact changed files

| File | Change |
|---|---|
| [admin_app.dart](../../apps/admin_web/lib/app/admin_app.dart) | Key scoped providers by the complete AuthSession. |
| [app_repositories.dart](../../apps/admin_web/lib/app/di/app_repositories.dart) | Inject and dispose the catalog session lifetime guard in existing Firebase composition. |
| [catalog_edit_session_guard.dart](../../apps/admin_web/lib/app/di/catalog_edit_session_guard.dart) | Latch observed session drift/disposal. |
| [exercise_tutorials_screen.dart](../../apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart) | Retain baseline/ID; safe errors, disabled stale Save, explicit discard/reload. |
| [firebase_exercise_catalog_repository.dart](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart) | Immutable snapshots, narrow patch, transaction comparison, authorization and error handling. |
| [exercise_catalog_store.dart](../../apps/admin_web/lib/infrastructure/firebase/exercise_catalog_store.dart) | Existing repository's Firestore transport, server reads/timestamps and web failure preservation. |
| [tutorial_video.dart](../../packages/gainpath_domain/lib/src/workout/entities/tutorial_video.dart) | Optional opaque baseline; no Firebase dependency. |
| [tutorial_repository.dart](../../packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart) | Fixed safe conflict, authorization and save failure types; unchanged save/load API. |
| [exercise_catalog_concurrency_test.dart](../../apps/admin_web/test/exercise_catalog_concurrency_test.dart) | Actual repository transaction callbacks: conflicts, retries, preservation, assignment/membership drift, deletion, create and privacy. |
| [catalog_edit_session_guard_test.dart](../../apps/admin_web/test/catalog_edit_session_guard_test.dart) | Account/org/role/verification changes, restoration and disposal. |
| [exercise_catalog_conflict_ui_test.dart](../../apps/admin_web/test/exercise_catalog_conflict_ui_test.dart) | Baseline retention, disabled Save, explicit reload and fixed errors. |
| [catalog_transaction_failure_test.dart](../../apps/admin_web/test/catalog_transaction_failure_test.dart) | Domain and Firebase authorization failure preservation under simulated web exception wrapping. |
| [catalog_mock_regression_test.dart](../../apps/admin_web/test/catalog_mock_regression_test.dart) | Real in-memory create/edit, prototype metadata and session isolation. |
| [catalog-edit-transactions.test.ts](../../functions/emulator/catalog-edit-transactions.test.ts) | Ten isolated web SDK/Rules transaction contract checks. No backend production changes. |
| [implementation plan](../superpowers/plans/2026-10-14-gate0-catalog-concurrency.md) | Bounded implementation/verification plan. |
| This report | Behavior, evidence and remaining limitations. |

## Verification evidence

All verification commands completed successfully. The full workspace runner executed without `BuildApps`, `Backend` or `Emulators` switches; backend and isolated emulator checks ran separately. A final Admin and maintained-source check followed the last web authorization handling fix.

| Check | Result |
|---|---|
| `dart run tool/check_architecture.dart` | Zero findings / Architecture boundaries OK. |
| Maintained-source `dart analyze` | No issues found. |
| Root architecture/tool tests | 21 passed. |
| Complete Admin `flutter test --no-pub` | **54 passed**, including 42 added tests. |
| Domain / Data / Identity / Pose / UI | 54 / 77 / 19 / 70 / 1 passed. |
| Mobile | 313 passed, 15 existing physical/device skips. |
| Backend build and `typecheck:tests` | Passed. |
| Backend unit suite | 129 passed across 9 files. |
| Firestore/Storage emulator suite | **39 passed across 5 files**, including 10 new catalog checks. |
| Independent code review / `git diff --check` | No remaining actionable findings / clean. |

Regression failures were observed before fixes for form baseline retention/raw error display, repository private-error sanitization, server assignment switch/deletion, role restoration replay, reload permission rejection and wrapped callback authorization failures. Initial repository/session tests were introduced before their new API existed; their initial failure was compilation, not a claim of measured live contention.

Ignored local logs: [workspace-verification.log](../../build/gate0-catalog/workspace-verification.log), [admin-tests.log](../../build/gate0-catalog/admin-tests.log), [architecture.log](../../build/gate0-catalog/architecture.log), [analysis.log](../../build/gate0-catalog/analysis.log), [backend-build.log](../../build/gate0-catalog/backend-build.log), [backend-typecheck.log](../../build/gate0-catalog/backend-typecheck.log), [backend-tests.log](../../build/gate0-catalog/backend-tests.log), [emulator-tests.log](../../build/gate0-catalog/emulator-tests.log). Emulator project was **demo-gainpath**, using unchanged copied Rules/index files, Java 21 and isolated ports 18280/19399. No real project was contacted.

## Limits and remaining approvals

- Dart tests execute the production repository callback through a deterministic transport. Emulator tests execute actual Firebase web SDK transactions and current Rules using separate contract fixtures; they do **not** execute Flutter's Firebase platform plugin. Web exception wrapping was verified in installed SDK source and simulated in regression tests. An actual browser session against an emulator, and live Admin operation, remain integration validation boundaries.
- Full snapshot comparison deliberately rejects even unrelated concurrent catalog or author-profile changes. It prioritizes preservation over automatic merging. Existing Rules reject unknown catalog fields; the deterministic extra-field fixture proves patch preservation, not authorization to write an expanded live schema.
- Transactions require connectivity. Offline edits do not silently queue blind updates. Server membership/assignment changes are checked as transaction reads, while authenticated session changes are also checked before writing and after completion. An already committed write cannot be recalled by a later logout; no automatic rollback or compensating write is attempted.
- Creation retains its existing one-document set behavior, with extra current authorization checks; immutable original-baseline concurrency protection applies to editing existing catalog records.
- The revised activation plan still requires separate approval for pushing this commit/CI, selective publisher deployment, the exact existing-record name/media update, fresh trusted publication, and Firebase APK/playback work. The software fix does not perform any of those operations or establish live playback/real workout acceptance.

README, run configuration, the earlier P0 plan, historical reports, private/local evidence and rollback artifacts are preserved outside the bounded commit. No Rules, indexes, functions production source, pose/analyzer/score code, workout history, consent/outbox, acceptance tuples or historical records change. Step 7C remains independent.
