# 5.4 Test data

Test fixture identifiers below are audit labels. Record counts describe the cited fixture or execution boundary. Dataset storage paths, screenshots, logs and records containing participant or environment information stay in their original restricted locations. A proposed collection template is included under [evidence/datasets](evidence/datasets/).

## 5.4.1 Accounts and role configuration

| ID | Provenance | Content and expected outcome | Use / limit |
| --- | --- | --- | --- |
| TD-ROLE | `functions/test/read-batch2-fixture.ts`, `membership-commerce-security.test.ts` and `booking-fixture.ts` | In-memory identities and organization records model authenticated verified actor, missing/invalid authorization, mismatched ownership/scope, and current or stale entitlements. Expected outcome comes from the service policy under test | Business rule coverage. Fake identity constructors are distinct from real Auth sessions |
| TD-COHORT | `functions/src/modules/dataset/fyp-dataset.ts`, `functions/test/fyp-dataset.test.ts` | Deterministically generated fictional dataset, 27 account assignments historically comprising 18 Members, 8 Coaches and 1 Admin. Copied structured records and source digests are verified in the generator test | Historical runtime in staged demo and permission-bound controlled environment. Counts of source documents and projections vary with revision and operation |
| TD-ACCESS | `apps/mobile/test/membership_access_gate_test.dart`, `functions/test/membership-entitlement.test.ts` | Free, active Basic and Premium, expired or unresolved membership, presentation/loading inputs and server-owned payment/term facts | No account credentials or real status copied |

## 5.4.2 User profile and fitness data

TD-PROFILE uses generated profile/publication fixtures from `fyp-dataset.ts` and `functions/test/fyp-dataset.test.ts`. Fixture records cover display/profile identity, assignment, declared preference/goal and separate profile and consent scenarios. Flutter test fixtures in `apps/mobile/test/member_settings_flow_test.dart`, `coach_phone_settings_test.dart`, `coach_profile_state_test.dart` and `member_legal_privacy_test.dart` exercise ordinary, missing and persisted settings/profile state. Phone validation and populated/empty goals are demonstrably tested where asserted. Exact age, height and weight boundary coverage is not established by fixture presence. Reuse synthetic labels and documented form validators in any author-facing data table.

## 5.4.3 Exercise and workout routine data

| ID | Source and format | Count/attributes | Expected use |
| --- | --- | --- | --- |
| TD-TRAIN | `functions/test/workout-fixture.ts`, `workout-backup-fixture.ts`, `apps/mobile/test/support/workout_analytics_fixture.dart` | Constructed exercise/set/session records. Includes rep and time fields, measured/unscored distinction and stable exercise/session identifiers | Verify serialization, totals, form evidence provenance and sync retries |
| TD-PROGRAM | `functions/test/fyp-dataset.test.ts:32-62` | Three 28-day program fixtures and 12 instructional content entries. Tutorial exercise snapshot has three instructions in the asserted case | Verify publication materialization and stable publisher destinations |
| TD-ROUTINE | `functions/test/publish-routine-v2.test.ts`, `apps/mobile/test/guided_timed_progress_test.dart`, `guided_workout_progress_test.dart` | A test routine uses 3 sets, 45 second timed bouts and 30 second rest. Distinct synthetic input models measured AI, manual and video-guided scenarios | Verify mixed modes, progress and publication, rather than infer real training dose |

## 5.4.4 Pose and exercise movement datasets

| ID | Type and path | Scope and limitation |
| --- | --- | --- |
| TD-POSE-SQ | Synthetic sample metadata/landmarks in `packages/gainpath_pose/test/support/squat_fixture_sample.dart`, `squat_analyzer_test.dart` and `squat_delivery_timing_test.dart` | Controlled timestamps, side/framing/confidence and joint angle patterns. Expected labels are encoded by developer-authored assertions. Report suite pass/skip counts separately from subject count |
| TD-POSE-FP | Synthetic test inputs in `packages/gainpath_pose/test/support/floor_push_up_projection_fixture.dart`, `floor_push_up_dwell_fixture.dart`, `floor_push_up_camera_fixture.dart` | Valid and interrupted tracks with alternate projection/side and dwell. The projection and temporal guards can be exercised independently of image inference |
| TD-POSE-IO | Optional diagnostic/readback fixtures and authored sample/evaluator code. `packages/gainpath_pose/tool/{squat_fixture_evaluator,floor_push_up_fixture_evaluator}.dart` and respective `test/` evaluator and CLI cases | The retained recording paths are not self-contained public datasets. Historic captures depend on exact platform, geometry and package. Raw recordings and ground-truth reports must be checked for provenance before publication |
| TD-POSE-PHYS | Dated reports `docs/architecture/2026-10-03-pose-physical-latency-baseline.md`, `2026-10-12-squat-fixture-validation.md`, `docs/integration/standard-floor-push-up.md` | Developer/owner captures and limited analytic labels/observations, including physical screen vs movement temporal measurements. Current generalization, held-out subjects, measured non-default lighting and per-exercise annotation counts require a dedicated dataset |

For the final evaluation record a run ID and artifact hash, masked participant, exercise, supported angle and side, camera resolution/frame rate, lighting, occlusion, set timestamp, human rep count and per-event form label. Have independent reviewers label before seeing app outputs, reconcile disagreement and retain unknown/unobservable labels. Keep consent and raw media in authorized storage. Export only a pseudonymous derived table and report missing/dropped frames and sample-level exclusions. See [pose and related evaluation reports](10_CORE_AI_EVALUATION/).

## 5.4.5 Gamification and rewards

TD-REWARD draws synthetic balance, reward stock, publication/revision, point-only/Premium modes and redemption records from `functions/test/reward-journey-fixture.ts`, `verified-rewards.test.ts`, `premium-reward-redemption.test.ts`, `reward-direct-save.test.ts` and related tests. Cases model sufficient/insufficient balance, duplicate retry, stock contention, eligibility/status and voucher outcomes. TD-GAME uses `apps/mobile/test/support/{reach_tap_fixture,mini_game_round_fixture,mini_game_participation_fixture}.dart` and `functions/test/mini-game-rewards.test.ts` for authored motion/round inputs and accounting policy. In-memory game events and actual physical hand movement are different dataset types.

## 5.4.6 Membership and payment

TD-COMMERCE is a set of authored quotes, amounts in minor units, accepted/pending/denied provider states, and transaction IDs in `functions/test/membership-payment.test.ts`, `membership-flexible-renewal.test.ts`, `booking-payment-callback.test.ts`, `billplz-sandbox.test.ts` and `xendit-booking.test.ts`. Provider JSON and webhook inputs are synthetic. Historic TD-SANDBOX includes two disposable Member identities and three verified simulator results (Basic purchase RM89, same-Member Basic renewal RM89, separate Premium purchase RM129) dated 24 October. It exercises real hosted sandbox payment and signed callback follow-up. The workflow did not include real funds, denied or late real payment, or a refund. See [UAT](11_USER_ACCEPTANCE_TESTING.md).

## 5.4.7 Coach booking and scheduling

TD-BOOK uses deterministic booking fixture time (1 October 2026 00:00 UTC) and appointment start (2 October 2026 02:00 UTC), and draft/current schedule, hold, paid status and pseudo-members in `functions/test/booking-fixture.ts:1-29`. Exceptions, recurrence and limits have separate authored data in `coach-availability.fixture.ts` and `coach-roster.fixture.ts`. Actual date formatting uses timezone-aware fixtures and tests. `booking-lifecycle.test.ts`, `booking-consultation.test.ts`, `coach-availability.test.ts` and `group-classes-emulator.test.ts` exercise alternate status, collision, notes or capacity under their respective harnesses.

## 5.4.8 AI chatbot and recommendations

TD-CHAT and TD-EQUIP are generated prompts/context and mocked Gemini payloads from `functions/test/chatbot*.test.ts` and `equipment-scanner.test.ts`, including malformed responses and network/secret failure handling. Sample MIME/base64 data verifies payload constraints independently of actual visual capability. TD-REC uses generated member summaries, independent consent and proposed candidates. `functions/test/recommendation-independent-evaluation-fixtures.test.ts:5-13` verifies 22 disjoint held-out synthetic scenarios, zero/one/three scoped candidates per scenario, no embedded labels and pre-call provenance. `recommendation-evaluation.fixture.ts` defines fixed scenarios for regression. Separately dated Gemini and independent relevance studies have their own assessment labels, provenance and denominators. No general relevance result follows from the fixture count.

## 5.4.9 Invalid, boundary and exceptional data

| Condition | Confirmed source coverage | Remaining verification |
| --- | --- | --- |
| Missing/malformed fields, invalid identifiers, unsupported currency or mismatched payment response | `functions/test/membership-payment.test.ts`, `billplz-sandbox.test.ts`, `booking-payment-callback.test.ts` | Current sandbox end-to-end error journey on approved fixtures |
| No/expired entitlement, stale session, retry or simultaneous effects | `membership-entitlement.test.ts`, `membership-commerce-security.test.ts`, emulated reward journey, Mobile gate | Full Android and browser session expiry/refresh with the staged build |
| Missing camera input / confidence recovery and partial exercise | `packages/gainpath_pose/test/`, `apps/mobile/test/real_squat_session_test.dart` | Device rotations, exposure, interrupt and recovery distributions |
| Network timeout, deferred sync, account switch | `apps/mobile/test/features/workout_sync_test.dart`, `file_real_workout_sync_store_test.dart`, `chatbot_recovery_test.dart` | Physical device/offline queue restoration and transport evidence |
| Empty and partial layouts | `apps/mobile/test/member_progress_dashboard_render_test.dart` and `apps/admin_web/test/admin_reporting_regression_test.dart` | Browser/OS accessibility and workload breadth |

Per-case executed status appears in [Test Execution Results](12_TEST_EXECUTION_RESULTS.md).
