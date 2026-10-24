# P0 — Architecture Checker and CI Recovery

Baseline: `98d5dec` plus the actual dirty working tree. User approved this bounded recovery and push; no new feature, pose tuning, Firebase schema/resource/deployment or workout tuple change was authorized. The latest dashboard/password recovery was preserved in prerequisite commit `30c68ad` before P0 changes.

## Result

Local architecture checker: **21 findings / exit 1 → zero findings / exit 0**. Maintained-source analysis is clean. The corrected full verification runner passed every workspace suite and both app builds. Backend build/typecheck/unit/emulator checks passed separately. GitHub Actions completed successfully for the exact pushed head `f13478cf81e7ca0231f5e58f4e4251701594deae`; both Flutter and backend jobs are green.

## Reviewable commits

| Commit | Increment |
|---|---|
| `30c68ad` | Separate prerequisite: checkpoint already approved real local dashboard/history and Firebase password recovery. No P0 source repair is hidden in this commit. |
| `39da9c3` | Six diagnostic import false positives corrected; five new checker regressions. |
| `4616a76` | Profile ready-content construction injected from composition; generic unavailable behavior moved into shared UI. |
| `0356c29` | Published routine view/domain contract, injected workout routes and listenable sync presentation port; preserve both mock preview entry points. |
| `ac87cd1` | Live admin composition exposes connected repositories and actual account identity; unsupported seeded operations unavailable. |
| `f13478c` | CI/PowerShell select native Dart vs Flutter tests and maintained analysis targets; final admin lint cleanup. |

All commits through `f13478c` were pushed to existing `codex/real-squat-flow` without force/reset. No PR or deployment was created.

## Exact boundary repairs

### Six tool findings

Previously, package tools were nonruntime but their relative URIs were checked against the package's `lib/` directory. This incorrectly rejected two preprocessing helper imports, two sampler helper imports, one filter probe support import and the pose evaluator's sibling tool import.

[check_architecture.dart](../../tool/check_architecture.dart) now permits only normalized **same-owner** `tool/` and `test/support/` references for a source scanned from that owner's `tool/`. Existing own-lib references remain valid. These directives add no runtime graph edge. No filename whitelist, production exception, external-package `src` allowance or runtime dependency relaxation was added.

[check_imports_test.dart](../../test/tool/check_imports_test.dart) adds tests for allowed normalized tool/support/lib paths, diagnostic-only graph edges, external-src/conditional/encoded URIs, package/root/sibling-folder escapes, and forbidden `lib`/`bin` access to tools/support. The existing conditional-export, parse-error, feature-layer, pure/transitive/native/app-cycle and legacy-root tests remain active. Three positive tool tests failed before the fix; all 21 checker tests now pass. Independent review found no boundary weakening.

### Fifteen production findings

| Original findings | Repair |
|---|---|
| Six feature imports of `app/unavailable_action.dart` | [Shared UI helper](../../packages/gainpath_ui/lib/src/shared/unavailable_action.dart), exported by [gainpath_ui.dart](../../packages/gainpath_ui/lib/gainpath_ui.dart); [old app path](../../apps/mobile/lib/app/unavailable_action.dart) remains a compatibility export. Removed app imports from Coaching, Gamification, Account Settings, Member Profile, Routine and Workout Prep. |
| FitnessProfileGate: app shell + cross-feature/concrete routine data (three findings) | [Gate](../../apps/mobile/lib/features/identity/presentation/member/fitness_profile_gate.dart) receives a required `readyBuilder` under its existing scoped profile repository/Cubit providers. [mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart) constructs MemberShell and supplies session/profile/routine/progress/settings dependencies. |
| Routine and Workout Prep: concrete published-routine data (two findings) | Move the identical DTO and document parser into [published_routine_view.dart](../../apps/mobile/lib/features/workout/domain/published_routine_view.dart); [old data file](../../apps/mobile/lib/features/workout/data/published_routine.dart) re-exports it. Text comparison confirmed parser/model move is identical. No schema or validation change. |
| Workout Prep: three app destination imports | Typed [WorkoutPrepRoutes/RealWorkoutLaunch](../../apps/mobile/lib/navigation/workout_navigation.dart) and app-owned [WorkoutPrepRoute](../../apps/mobile/lib/app/routing/workout_prep_route.dart). [Prep](../../apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart) retains supported binding, consent/setup/upload choice and scope checks; app factories construct the original real/history/preview destinations. |
| Sync panel: concrete outbox import | [RealWorkoutSyncPresentation](../../apps/mobile/lib/features/workout/domain/real_workout_sync_presentation.dart) exposes existing listenable state/actions. [Panel](../../apps/mobile/lib/features/workout/presentation/member/real_workout_sync_panel.dart) imports the port. [Outbox](../../apps/mobile/lib/features/workout/data/real_workout_outbox_repository.dart) adds only interface declaration/import and override annotations; business method bodies are unchanged. |

Other changed composition/presentation files: [MemberShell](../../apps/mobile/lib/app/shells/member_shell.dart), [MemberHomeScreen](../../apps/mobile/lib/app/home/member_home_screen.dart), [RoutineScreen](../../apps/mobile/lib/features/workout/presentation/member/routine_screen.dart), [BrowseCoachesScreen](../../apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart), [GamificationDashboardScreen](../../apps/mobile/lib/features/gamification/presentation/member/gamification_dashboard_screen.dart), [AccountSettingsScreen](../../apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart), [MemberProfileScreen](../../apps/mobile/lib/features/identity/presentation/member/member_profile_screen.dart).

Missing composition fails truthfully with unavailable feedback instead of silently constructing native/Firebase resources from feature UI. The real app supplies all existing routes. A review caught lost mock preview injection; a failing regression reproduced it, then both mock Home/Workout-tab callsites were corrected to use `WorkoutPrepRoute(live: false)`. Both live callsites retain `live: true`.

### Live admin handoff assertion

[AppRepositories](../../apps/admin_web/lib/app/di/app_repositories.dart) now provides only connected Tutorial/Routine ports in Firebase mode and creates mock state lazily only in mock mode. [Admin app](../../apps/admin_web/lib/app/admin_app.dart) supplies current authenticated session; its composition key includes account scope and role. [AdminShell](../../apps/admin_web/lib/app/shells/admin_shell.dart) reuses navigation/layout, lazily initializes visited live pages and uses [AdminFeatureAvailability](../../apps/admin_web/lib/app/admin_feature_availability.dart) for actual account identity and unsupported-module notices. Members/refunds/rewards/reports/coach prototype operations are not built in live mode. Profile/sidebar use the actual session; fake notification/search/account actions are unavailable. Connected Tutorial/Routine screens and default Firebase adapters remain intact; mock UI remains unchanged.

Tests use isolated scoped ports rather than treating their fixture rows as live operations. This is composition honesty, not implementation of missing admin modules.

## Verification runners

[verify.ps1](../../tool/verify.ps1) and [verify.yml](../../.github/workflows/verify.yml) now run:

- Root CLI/checker tests, `gainpath_domain`, `gainpath_data`, `gainpath_pose`: `dart test`.
- Flutter identity/UI packages, mobile and admin apps: `flutter test --no-pub`.
- Analysis: root `tool/test` and every owner's existing `lib/bin/test/integration_test/tool` folders. No maintained source folder is excluded. Preserved ignored build controls are not current source and remain on disk. Broad pre-task analysis reported 86 issues from build snapshots; explicit maintained analysis is clean.
- Architecture remains the first blocking code check, before tests/builds. Both mock debug app builds remain required. Backend CI checks remain unchanged.

The full local runner was executed as `./tool/verify.ps1 -BuildApps` with Flutter 3.38.9 / Dart 3.10.8. Backend scripts were run separately against existing dependencies and the isolated `demo-gainpath` emulators. No Firebase deployment or real workout submission occurred.

## Actual local results and logs

| Check | Result | Log |
|---|---|---|
| Baseline architecture | 21 findings, exit 1 | Local temporary `gainpath-p0-before.log` |
| Final checker | Zero findings, exit 0 | `build/p0-logs/verify-full.log` |
| Final maintained analysis | No issues found | `build/p0-logs/analyze-final.log` |
| Root tooling | 21 passed | `build/p0-logs/root-tests.log`, full runner log |
| Data / Domain / Identity / Pose / UI | 77 / 54 / 19 / 70 / 1 passed | `build/p0-logs/verify-full.log` |
| Admin / Mobile | 12 / 298 passed; mobile 15 optional diagnostic skips | `build/p0-logs/verify-full.log` |
| Enabled mock preview flag | 2 composition regressions passed | `apps/mobile/build/p0-preview-flag-tests.log` |
| Admin web / Mobile debug APK | Both built, exit 0 | `build/p0-logs/verify-full.log` |
| Backend build / test typecheck | Passed | `build/p0-logs/backend-build.log`, `backend-typecheck.log` |
| Backend unit | 114 passed | `build/p0-logs/backend-unit.log` |
| Firestore/Storage emulator | 28 passed, exit 0 | `build/p0-logs/backend-emulator.log` |
| Whitespace / protected source hashes | Passed; all 84 protected files unchanged | `build/p0-logs/protected-before.json` |

Additional/updated test files: [fitness_profile_gate_test.dart](../../apps/mobile/test/fitness_profile_gate_test.dart), [real_workout_ui_test.dart](../../apps/mobile/test/real_workout_ui_test.dart), [real_workout_sync_ui_test.dart](../../apps/mobile/test/real_workout_sync_ui_test.dart), [workout_prep_composition_test.dart](../../apps/mobile/test/workout_prep_composition_test.dart), [firebase_feature_availability_test.dart](../../apps/admin_web/test/firebase_feature_availability_test.dart).

## GitHub evidence

[Pushed-head verification run](https://github.com/Haise0619/gainpath/actions/runs/38387351582), inspected on 2026-10-13: **completed / success**, exact head `f13478cf81e7ca0231f5e58f4e4251701594deae`.

| Job | Verified remote steps | Conclusion |
|---|---|---|
| `flutter` | Enforced-lockfile dependency resolution; Architecture boundaries; Analyze maintained workspace sources; Pure Dart tooling tests; Package and app tests; Build Admin Web; Build Mobile APK | Every step completed successfully |
| `backend` | Frozen-lockfile dependency installation; build; test typecheck; unit tests; Firestore/Storage emulator tests | Every step completed successfully |

Public GitHub API run and job/step metadata are preserved in [github-run.json](../../build/p0-logs/github-run.json) and [github-jobs.json](../../build/p0-logs/github-jobs.json). Detailed local execution logs are preserved in [verify-full.log](../../build/p0-logs/verify-full.log), [analyze-final.log](../../build/p0-logs/analyze-final.log), [backend-unit.log](../../build/p0-logs/backend-unit.log) and [backend-emulator.log](../../build/p0-logs/backend-emulator.log). Raw remote job-log download was unavailable without authenticated access; the remote success claim is based on the exact-head run and every step's actual API conclusion, not on local results.

## Preservation and limitations

- Byte comparisons cover existing pose engine, mobile pose inference/native/application controllers, Firebase backend source and Firebase Rules/index/config files. None changed. Outbox change is a type port/annotations only; published parser is text-identical. Account-isolation/progress/history/consent/outbox regression suites remain passing. Trusted tuples stay empty.
- CPU/GPU/Step2M/Step7 experimental reports and dedicated rollback artifacts were not deleted or tuned. P0 builds were not installed on a phone and did not alter device app data.
- Local Java 20 emulator shutdown emitted a rules-runtime warning after all 28 tests and script exit 0; no test failed. CI uses configured Java 21 for the backend. Gradle reported an existing AudioPlugin deprecation note; build succeeded.
- Automatic approval review rejected direct selective README index staging because it could commit incorrect content or affect pre-existing README edits. The safe alternative leaves README uncommitted; local task documentation edits coexist with the user's earlier changes. Original run configuration, caches and historical/untracked reports remain uncommitted. This report and final planning status are local review artifacts.
- This maintenance task does not establish physical pose accuracy, enable workout acceptance or complete unsupported product modules. No other feature work began.
