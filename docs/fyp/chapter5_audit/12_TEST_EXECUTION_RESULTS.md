# 5.5.7 Test execution results

## Audited execution

The tests ran on 25 November 2026, Asia/Kuala_Lumpur, from the `membership-upgrade-work` working tree at base commit `f81fb2d5d48857c75cb5f1b8491086fc4bcceba6`. This is a dirty checkout snapshot. The host used Windows, Flutter 3.38.9, Dart 3.10.8 and Node 24.19.0. Functions production and CI use Node 22. The Firestore run used the locally installed Firebase CLI 13.35.1 and Java 20.0.2. Exact UTC start/end and wall-clock durations are in [run summary](evidence/test_logs/RUN_SUMMARY.csv). Machine reporter timing can exclude process launch, artifact checks and teardown. Test outcomes and child process exit codes both appear in the logs.

| Run | Level | Pass | Fail | Skip | Evidence |
| --- | --- | ---: | ---: | ---: | --- |
| Backend default Vitest, local transport approved | TypeScript unit/service and loopback callable transport | 2,395 | 0 | 2 | 198 files, [log](evidence/test_logs/backend-portable.txt) |
| Admin web | Flutter VM widget/unit | 711 | 13 | 30 | 136 files, [log](evidence/test_logs/admin-portable.txt) |
| Mobile Member/Coach | Flutter VM widget/unit | 2,450 | 41 | 53 | 433 files. Of 41 failures, 25 are suite-loading compile failures and 16 are actual assertions. [Log](evidence/test_logs/mobile-portable.txt) |
| Shared pose | Pure Dart VM, deterministic fixtures and CLI | 407 | 0 | 0 | 29 files, [log](evidence/test_logs/dart-pose-portable.txt) |
| Shared domain | Pure Dart VM | 198 | 0 | 0 | 48 files, [log](evidence/test_logs/dart-domain.txt) |
| Shared data | Pure Dart VM | 165 | 0 | 0 | 35 files, [log](evidence/test_logs/dart-data.txt) |
| Shared identity | Flutter VM | 25 | 0 | 0 | 4 files, [log](evidence/test_logs/gainpath_identity.txt) |
| Shared UI | Flutter VM | 26 | 0 | 0 | 6 files, [log](evidence/test_logs/gainpath_ui.txt) |
| Repository tooling | Pure Dart VM | 22 | 0 | 0 | 1 file, [log](evidence/test_logs/dart-tools.txt) |
| Firebase grouped runner | Demo projects, real SDK transactions and configured Auth/Firestore/Storage Rules | 312 | 0 | 2 | 57 files across seven groups, [log](evidence/test_logs/emulator-full.txt) |

The grouped result is core 231 passed and 2 skipped, backup 5, check-in 5, reporting 24, mini-game rounds 3, participation 3 and exercise catalog status 41. Grouped runner coverage does not include separately prepared Functions/Flutter recommendation or FYP cohorts. The separate five-case workout backup retry [log](evidence/test_logs/emulator-backup.txt) verifies the same backup cases and is excluded from the grouped total.

The [assertion inventory](evidence/test_logs/AUTOMATED_ASSERTION_RESULTS.csv) contains test titles and runtime outcomes for completed Dart/Flutter/Vitest reports. [Discovered test files](evidence/test_logs/DISCOVERED_TEST_FILES.csv) also lists static declarations for suites outside those reports. Parameterized cases, loops and generated titles can cause the static and runtime counts to differ. [Test case index](09_TEST_CASES/TEST_CASE_INDEX.csv) maps academic scenarios to component source and observed results. A single grand total would double-count the retry runs and overlapping test layers.

The 74 academic scenario rows classify 40 as Pass at the specified component or SDK scope, 5 as Fail based on the selected test files, and 29 as Not Executed at the proposed scenario scope. These are documentation groupings. They should not be added to the runner totals or used to calculate an application pass rate.

## Commands and environment

Root-relative working directories are indicated in the first column. Functions use the locally resolved Vitest and TypeScript executables. The Dart package runner was invoked directly with the existing package configuration after the wrapper attempted network dependency resolution. The test artifacts and local Admin build were generated under ignored `build/chapter5-audit-raw/`. The shared evidence package contains sanitized summaries and does not contain arbitrary widget output, stack traces, machine paths or cloud logs.

| Working directory | Invocation |
| --- | --- |
| `functions/` | `node node_modules/vitest/vitest.mjs run --no-cache --maxWorkers 3 --minWorkers 1 --reporter=dot --reporter=json --outputFile.json=<local report>` |
| `functions/` | `node node_modules/typescript/bin/tsc -p tsconfig.test.json --incremental false` and `node node_modules/typescript/bin/tsc -p tsconfig.json --noEmit --incremental false` |
| `functions/` | `node emulator/run-suites.cjs backup` and `node emulator/run-suites.cjs` |
| workspace root or pure Dart package | `dart --packages=<workspace package_config.json> <cached test-1.26.3 package>/bin/test.dart --concurrency=2 -r json`. Root invocation passed `test` explicitly |
| `apps/admin_web/` and `apps/mobile/` | `flutter --suppress-analytics test --no-pub --concurrency=2 --machine test`; Mobile used concurrency 3 |
| `packages/gainpath_identity/` and `packages/gainpath_ui/` | `flutter --suppress-analytics test --no-pub --concurrency=2 --machine test` |
| workspace root | `dart --packages=.dart_tool/package_config.json tool/check_architecture.dart` |
| `apps/admin_web/` | `flutter --suppress-analytics build web --debug --no-pub --no-web-resources-cdn --output <isolated output>` |

## Consistency, static verification and builds

| Check | Outcome |
| --- | --- |
| Backend test type check | Exit 0. [Run log](evidence/test_logs/types.txt) |
| Backend source type check, `--noEmit` | Exit 0. Source compilation types verified. [Run log](evidence/test_logs/functions-source-types.txt) |
| Workspace architecture checker | Nonzero, two forbidden cross-feature imports at `apps/mobile/lib/features/workout/presentation/member/widgets/workout_achievement_feedback.dart:6` and `:8`. These findings refer to the audited source and affect the architecture gate. [Run log](evidence/test_logs/architecture.txt) |
| Debug Admin web build | Exit 0. Local isolated build; compiler 167.5 s, wall-clock 169.04 s. `main.dart.js` SHA-256 `ff1486ad69f2c2ed2a35defe402d4dee9f23d2b535157f878fb8fe956bdf8a2a`. Wasm dry-run success is not a tested Wasm release. [Build log](evidence/build_logs/admin-debug-build.txt) |
| Current signed APK, deployment and physical acceptance | Remain pending. Current Mobile tests that load the main Member shell cannot compile it because the call supplies an unsupported named argument. Dated build/install reports identify different artifacts |

## Observed failures, skips and recovered environmental blocks

- In the first managed Vitest run, nine HTTP callable checks failed with loopback `EACCES` and the linked cache write also produced `EPERM`. The approved rerun isolated network and cache constraints and all nine passed. Count the successful verified rerun as the backend result. [Initial log](evidence/test_logs/backend.txt)
- The initial Dart wrappers tried to resolve Pub externally and hit a socket error. The direct local runner was used for VM suites. Three pose CLI cases initially failed because their subprocesses did not return the expected validation exits in the managed run. They passed in the approved rerun. [Initial pose log](evidence/test_logs/dart-pose.txt)
- The managed Flutter commands could not write the SDK cache lockfile and then the `libimobiledevice.stamp` during the next attempt. Approved runs accessed the installed SDK and executed the assertions. Those early attempts yielded no assertion outcomes and are excluded from counts.
- The initial Firebase command could not reach its own hub on port 14400, so it yielded no assertions. The approved isolated five-case backup run and the subsequent grouped run completed against demo projects, including SDK persistence and Rules authorization. [Blocked attempt](evidence/test_logs/emulator.txt)
- The Admin suite has failures under Add Member, Add Coach, responsive shell, branches and scoped calendar navigation. The machine log shows an unprovided `Provider<AuthBloc>` in the mounted `AdminShell` tree followed by failed navigation/widget assertions and layout exceptions in these fixture graphs. Review the dependency composition and rerun the named cases. It is unresolved whether all thirteen have the same cause under a normal authenticated browser. [Failure list](evidence/test_logs/admin-portable.txt)
- Mobile failed to load 25 test files because `apps/mobile/lib/app/shells/member_shell.dart:609` passes `onOpenGroupClasses` to `buildFirebaseCoachDirectory` without a corresponding factory parameter. Sixteen separate assertion failures concern Coach navigation or viewport renders, booking history, Move & Catch or routine history. Selected passing unit files bypass the affected shell composition and do not verify the normal Mobile entry point. [Failure list](evidence/test_logs/mobile-portable.txt)
- Grouped configuration gates matter. Default Vitest excludes the four retained-evidence test files by design, and explicitly gated provider/emulator and rendering paths may be marked skipped. Such skips preserve the boundary of the default run. Standalone guarded cohorts and real-device/provider tests are not promoted to passing based on nearby assertions.

## Archived results and unresolved acceptance

Dates, snapshots, fixture data and suite membership differ. Keep historical counts out of current totals.

| Report | Archived result | Still unresolved for current Chapter 5 |
| --- | --- | --- |
| `docs/qa/fyp-demo-integration-acceptance.md:37-71` | Historical backend 2,087 pass and three failed assertions, plus two failed test-file load cases. Selected Member, Admin and Firestore emulator gates and both builds passed | Compare specific historical case identities and environment with current runs |
| `docs/qa/progress-checkpoint-2026-11-13.md:13-41` | Admin 608 pass, six skipped, seven failed before final corrections. 12 focused rating/publication/private-path follow-ups passed | Report current Admin failures separately |
| `docs/integration/module4-sandbox-purchase-renewal-uat-results-2026-10-24.md` | Three historical approved Billplz Sandbox payments and corresponding M4 records verified | Current provider-specific acceptance, Android receipt/PDF and refund scenarios remain bounded |
| `docs/integration/module5-xiaomi-final-uat.md` | Prior physical Member device and native PDF observations | Current APK and repeat physical/offline/account-switch checks |
| `docs/integration/module13-final-gemini-acceptance-20261118.md` | Dated permission-bound provider acceptance | Findings depend on exact model, data and release gates; follow [Core AI evaluation](10_CORE_AI_EVALUATION/) |

Report app compilation, emulator persistence, UI assertion status, manual acceptance and physical inference as independent outcomes. See [UAT](11_USER_ACCEPTANCE_TESTING.md) for participant evidence and field testing boundaries.

The separate [Training Report render fixture](evidence/test_logs/training-report-render.txt) passed one case with screenshot capture enabled and produced [two report figures](evidence/screenshots/README.md). This is a scoped repeat and is excluded from suite totals.
