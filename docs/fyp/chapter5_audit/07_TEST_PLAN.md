# 5.3 Test plan

## 5.3.1 Test scope and objectives

The unit of audit is the GainPath Member/Coach Flutter application, Admin Flutter web, the five shared packages, callable/HTTP/triggered/scheduled Functions, Firestore/Storage access, and third-party adapters. Priority 1 is the Member exercise pipeline through durable record, recovery and analytics, separated from physical accuracy. Priority 1 also includes verified access and data separation, and transaction invariants where a failure can change points, slot availability or a payment record. Priority 2 covers Coach profile, schedule, consultation, exercise and program publication, workshop operations, navigation and responsive UI. Priority 3 includes usability acceptance and environmental breadth. Tests involving participant recruitment, genuine payments, production accounts, provider charges, deployments or production mutations were outside fresh audit execution.

## 5.3.2 Testing environment

| Environment | What runs there | Evidence boundary |
| --- | --- | --- |
| Dart VM / Flutter widget harness | Packages, file-backed temp storage, mocked camera/voice/plugins, state and UI, fixture transports | VM math and widget behavior on Windows. No optical, platform sensor, native audio or provider observation |
| Vitest Node | Real TypeScript service modules, in-memory or stubbed adapters and selected local callable wrappers | Service contract/logic and mock response routing |
| Firebase local emulators | Guarded demo projects and loopback, real SDK/Rules behavior, optionally demo Auth/Functions/Storage | Emulator behavior for staged source and known fixtures |
| Historical Android debug/profile, physical Xiaomi handset | Installed APK and selected owner-assisted flows, recorded pose and interface observations | Applies to dated APK and recorded conditions |
| Historical browser | Prepared Admin web with fixture, localhost and separately documented authorized existing Admin account | Deployment report pairs the exact served build with the scenario. Broad browser compatibility is open |
| Historical Firebase cloud controlled cohort | Permission-bound synthetic dataset, reports, inbox, admin and role checks | Isolated verified observations exist in the dated integration reports. No fresh cloud inspection |
| Historical payment sandbox | Exact provider simulator with approved test accounts and mock settlement | Real settlement/refunds and production reconciliation remain outside the historical scope |
| Historical AI service testing | Mocked AI transport and bounded live Gemini runs described separately | Assessment results only apply to their exact model and evaluation set |

The base `firebase.json` maps Auth 9099, Functions 5001, Firestore 8080, Storage 9199, Hosting 5000 and Emulator UI 4000 on loopback. `functions/emulator/run-suites.cjs` uses separately reserved ports for audited grouped tests. Several acceptance tests run on dedicated ports/configs and should not be folded into the base command.

## 5.3.3 Testing tools and resources

| Tool | Configured or resolved version | Baseline command and limitations |
| --- | --- | --- |
| Flutter / Dart | Flutter 3.38.9, Dart 3.10.8, pure Dart test 1.26.3 | From package directory `dart test` (domain, data, pose), `flutter test --no-pub` (apps and other packages). Flutter cache, platform runtime and resolved packages must be accessible |
| Node / pnpm | Firebase runtime Node 22, CI pnpm 11. Local Node 24.19.0 and pnpm 11.25.0 | From `functions/`: `pnpm test`, `pnpm run typecheck:tests`, `pnpm run build` on a prepared host with the locked dependencies |
| Vitest / TypeScript | 2.1.9 / 5.9.3 | `vitest run` from the workspace dependency tree. `vitest.config.mts` excludes retained-evidence suites by default. `tsc -p tsconfig.test.json` checks test compilation |
| Firebase CLI / emulator | Functions dependency 13.35.1, cache includes Firestore 1.19.8/1.22.0 and Storage Rules 1.1.3. CI backend Java 21. Local explicit Java 20.0.2 | `pnpm run test:emulator`. Use the intended loopback ports and guarded demo project. Keep separately prepared configurations separate |
| Architecture rules | Dart tooling `tool/check_architecture.dart` | `dart run tool/check_architecture.dart`. Enforces source boundaries, separate from linter/build/test status |
| CI / build | `.github/workflows/verify.yml` | GitHub Actions on push and PR, Ubuntu runner, Flutter and backend jobs. Flutter debug APK and debug Admin builds are distinct from signed release verification |
| Test data | [Test data inventory](08_TEST_DATA.md) | Use authored fixtures or deliberately isolated test accounts and record the dataset/file revision |

Fresh audit commands, exit codes and duration are in [12 Test execution results](12_TEST_EXECUTION_RESULTS.md).

## 5.3.4 Testing schedule

The dates below reconstruct milestones from evidence. They do not establish a preregistered schedule.

| Dated evidence | Observed checkpoint |
| --- | --- |
| 2–13 Oct 2026 | BlazePose and Squat pose geometry, preprocessing, latency and fixture refinement experiments. See `docs/architecture/2026-10-03-pose-physical-latency-baseline.md` and `2026-10-12-squat-fixture-validation.md` |
| 19–24 Oct | Scoped coaching chat manual retest, Google delivery/controlled automation and membership sandbox evidence. See `docs/architecture/module-9-uat.md`, `docs/integration/automatic-confirmation-uat-2026-10-23.md` and `module4-sandbox-purchase-renewal-uat-results-2026-10-24.md` |
| 30 Oct | Owner-assisted Xiaomi Module 5 test captures and implementation fixes. Further recovery and layout observations still needed. See `docs/integration/module5-xiaomi-final-uat.md` |
| 4–7 Nov | Controlled FYP cohort and Admin/browser integration, floor push-up and shared workout/camera regressions. See `docs/integration/gainpath-fyp-live-integration.md` and `standard-floor-push-up.md` |
| 12–13 Nov | Local fixture/emulator demo acceptance and app builds, with residual full-suite failures documented in the 13 Nov progress checkpoint |
| 18–23 Nov | Restricted recommendation provider acceptance, portability/concurrency CI corrections and Premium upgrade rollout. See `docs/integration/module13-final-gemini-acceptance-20261118.md`, `95ef039`, `98c9830`, `1cc481f` |
| 25 Nov | Audited working-tree snapshot and safe fresh suite attempts in this package |

Proposed next schedule: session 1 repeats full gates on Windows or the pinned CI configuration and triages deltas against the previous snapshot. Session 2 replays isolated cross-role and sandbox workflows. Session 3 records physical movement, voice and layout metrics on the approved build. Session 4 runs multi-role UAT. Session 5 repeats corrected scenarios, freezes evidence and reconciles all traceability.

## 5.3.5 Test entry and exit criteria

Historical release and device gates are scenario-specific. For example, `docs/integration/floor-push-up-physical-acceptance.md` requires exact artifact, camera and rep-boundary evidence and distinguishes field readiness from debug candidate checks. Before proposed final evaluation, pin commit plus working-tree digest, identify environment/emulator ports/API mode, establish role-specific synthetic data and reset strategy, confirm exact APK/UI artifact and obtain recording consent. Start destructive or financial-like scenarios only on approved disposable data within a sandbox.

Proposed exit: complete all priority-1 rows in [Test Case Index](09_TEST_CASES/TEST_CASE_INDEX.csv) with a signed outcome, explain unresolved full-suite failures by test and impact, verify role/organization isolation, reconcile payment/points and booking invariants, complete the independent pose exercise evaluation with uncertainty and excluded cases, and retain an anonymized matrix of participants and task outcomes. A material failed authorization, double settlement or unrecoverable loss of a completed workout blocks claiming that its end-to-end path passed. Missing device or provider exercises retain their pending status.

## 5.3.6 Test acceptance criteria

These prospective evaluation gates do not substitute for original Chapter 3 targets where the source report is unavailable.

| Area | Proposed observable acceptance rule |
| --- | --- |
| Access | Every tested approved role/action pair succeeds and every tested denied case leaves business data unchanged. Repeat with mismatched scope, suspended and unverified identities |
| Commerce, points, bookings | Independent transaction and ledger/receipt reconciliation matches the amount, currency, owner and resulting entitlement/booking. An exact replay creates one effect. Collision leaves only one confirmed reservation |
| Workout continuity | Exercise progress and completed-session totals agree before/after resume for every staged case. Reconnect creates one cloud copy and one reward event if eligible |
| Pose, rep, posture and voice | Freeze exercise thresholds, supported side/view and exclusion policy before collection. Compare independent human count and form labels with system output. Report counts, absolute error, per-label precision/recall and outcome uncertainty. Adopt numeric effectiveness gates before new measurement |
| Usability | No blocking task failures for sign-in, saving a workout, coaching schedule read/update or Admin reporting in scripted UAT. Report denominators and all observed assisted/abandoned tasks. Capture talkback/manual compatibility as separate checks |

## 5.3.7 Requirements traceability

[Requirements traceability matrix](13_REQUIREMENTS_TRACEABILITY_MATRIX.csv) records the provenance of identifiers and current implementation mapping. Individual reported requirement IDs in architecture checklists are secondary evidence. [Test Case Index](09_TEST_CASES/TEST_CASE_INDEX.csv) links academic scenario IDs to original test source and results. The IDs beginning `F-`, `X-` and `N-` are audit scenario IDs.
