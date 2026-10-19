# Accepted integration checkpoint — 19 October 2026

The owner accepted Unified Admin Web commit `18e4130beb17c29136b582420643cd4482dadd2c` with manual UAT PASS, then requested a safe fast-forward push and one consolidated CI verification before Module 10 implementation.

## Verified Git state before this documentation commit

- Current branch: `codex/real-squat-flow`; source HEAD: `18e4130beb17c29136b582420643cd4482dadd2c`.
- Remote: `origin`, `https://github.com/Haise0619/gainpath.git`.
- Live remote branch tip read directly from GitHub: `99d5ed1de92606ad3cc1e7f5d2fd29116d629ddb`.
- The live tip is an ancestor of local HEAD: 45 local commits ahead, zero remote-only commits. No fetch, reset, merge, rebase or push was needed for this inspection.
- Live `main` remains `e96493880c1ebcd351b87de0222853974df10613`; this checkpoint does not target or merge into `main`.

Six pre-existing tracked modifications are retained and excluded from this checkpoint: `.run/main.dart.run.xml`, `README.md`, `apps/mobile/lib/app/di/coach_profile_factory.dart`, `apps/mobile/test/coach_module8_route_composition_test.dart`, `docs/planning/2026-10-15-coaching-read-performance.md`, and `docs/superpowers/plans/2026-10-13-p0-ci-recovery.md`. Existing untracked work remains untouched. In particular, the outstanding mobile roster routing fix is not represented by a committed APK source change in this checkpoint.

## Approved-sequence boundary

1. Commit only this checkpoint note and the Admin acceptance update. This adds one documentation commit after the 45 existing local commits.
2. Request owner approval for the exact resulting SHA and destination `origin/codex/real-squat-flow`. No push is authorized merely by preparing this note.
3. After approval, recheck the remote tip and ancestry, then perform a normal fast-forward push of that exact SHA. Never force-push, include working-tree changes, or change `main`.
4. Observe the single `.github/workflows/verify.yml` run triggered by that push, covering the existing Flutter and backend jobs. Do not also run a redundant full local CI suite. Report the actual result and any necessary blocker; do not claim CI passed before completion.
5. After this checkpoint/CI sequence, implement Module 10 as one integrated sprint against original C3 FR-10.1–FR-10.4 and C4. Inspect exact live Firebase policy/configuration before proposing deployment; request approval for production/policy/security changes. Preserve existing transactions, reservation locks, timezone rules, data and frozen systems.

No application source, Firebase configuration or live data changed while preparing the original checkpoint.

## Approved push and observed CI

The owner approved the exact checkpoint push. A normal fast-forward push advanced only `codex/real-squat-flow` from `99d5ed1` to `97f65c0f3e53ca107624537273671c3d2b76bc5e`; all six pre-existing modified files stayed excluded. The single automatically triggered [Verify workspace run 39181449682](https://github.com/Haise0619/gainpath/actions/runs/39181449682) completed with failures in both jobs:

- Flutter stopped at Architecture boundaries: two Member profile widgets imported concrete data repositories, and the profile screen directly imported Membership and Body Metrics feature implementations.
- Backend build, test typecheck and unit tests passed; the Rules emulator step failed because five suites required ignored activation candidates/environment variables absent from a clean checkout.

The bounded integration repair moves repository construction into infrastructure, composes the two navigation destinations in MemberShell through builders, and defaults those five Rules suites to committed Rules. Explicit activation-candidate overrides remain supported, including `MODULE8_RULES_DIR`. No test is skipped, no Rules or deployed policy changes, and no live record is written. Tests against committed Rules are not evidence of deployed-policy validation.

Focused repair verification: architecture checker passed; targeted Dart analysis passed; 16 Member widget tests passed (including both navigation destinations); backend test typecheck passed; all 36 tests in the five affected Rules files passed on isolated local emulators. Emulator shutdown emitted a Java tooling warning after successful test exit. The original CI remains failed; these focused results do not establish a passing consolidated CI run.

The repair requires a separate exact-SHA push approval. A subsequent CI run is necessary because the first run found genuine integration failures, not a routine repeated audit. Module 10 implementation and backend deployment have not started while this checkpoint is unresolved.

## Repair push result and remaining legacy fixture repair

The owner approved pushing `08f2e89b3538b70e490bebde85e69351a83bbc84`; the normal fast-forward push succeeded. [Run 39182247344](https://github.com/Haise0619/gainpath/actions/runs/39182247344) passed architecture boundaries and the previously repaired Rules suites, but exposed two further legacy test integration defects:

- Analysis: the ChatBloc test fake implemented `EquipmentRepository` without its newer methods. It now extends that repository and inherits the existing defaults; no application behavior changed. All six ChatBloc tests pass. The exact maintained-source analysis step was reproduced locally: exit 0, no errors or warnings, 18 informational style notices.
- Backend: unit tests passed (19 files), while the emulator step reported 26 passing files and four failures in `firestore-rules.test.ts`. Its old fitness profile fixture lacked required `createdAt`/`profileCompletedAt` timestamps, and its name test expected a standalone membership update instead of the existing atomic identity/membership pair. Updating only these fixtures yields 22 passing tests in that file; no Rules were relaxed or changed. Backend test typecheck also passes.

The owner’s six original modified files remain excluded. These two test-only fixes and this evidence require another exact-SHA push approval; consolidated CI is still not claimed as passed. Module 10 remains pending the integration gate.

## Third CI result

The owner approved `2a127fd5ac2a85efb660ca80cb48dab0fa8cd6e1`, which was pushed normally. [Run 39182632225](https://github.com/Haise0619/gainpath/actions/runs/39182632225) passed the complete backend job, architecture boundaries, analysis and earlier package tests. The Admin app test phase reported 187 passing and three failing tests, then stopped before mobile tests/builds. The failures were stale test assumptions: default app construction now requires Firebase initialization unless test authentication is injected, and Settings defaults to General while preserving the read-only Reward conversion control. Two test files now explicitly inject test authentication, select Legal & compliance, and assert the retained conversion button is disabled. All 10 tests in those two files and their targeted analysis pass. Application source and Firebase policy are unchanged by this repair. CI has not yet passed end to end, and Module 10 remains pending.

Read-only Module 10 preflight (19 October 2026) confirmed 24 ACTIVE Node 22 functions, organization timezone Asia/Kuala_Lumpur, 15-minute holds and existing one-active-booking-per-Member-per-day policy. Exact live Firestore SHA-256 is `3b11087f0d21639249374ae17035fbc4d734a0827f1c7390acd118b0c486e2db`; Storage is `50138b9c519882e03005c1f7f5821b306d9d35baf3aca701c716c1feb8b3fc8d`. Source snapshots and sanitized inventory are retained under ignored `build/non-core-crud-sprint/module-10-activation/`. No deployment or live write occurred.
