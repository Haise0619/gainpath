# 5.2 Testing strategies and approaches

Current counts and run boundaries are in [12 Test execution results](12_TEST_EXECUTION_RESULTS.md). Test source establishes intended assertions. A fresh run, a dated report, and a pending case each have their own evidence status.

## 5.2.1 Testing objectives

| Objective | Evidence approach | Boundary |
| --- | --- | --- |
| Functional correctness and domain rules | Pure Dart and Vitest assertions for exercise phases, membership terms, amount calculations, booking transitions and reward eligibility | Synthetic inputs control the state and timing |
| Consistency and authorization | In-memory command tests for validation, idempotence and state transitions. Firestore emulator suites for SDK transactions, Rules and permitted actor/ownership combinations | Emulator requests prove the configured Rules and local adapter behavior for the case |
| Role journeys and user-facing errors | Flutter widgets mounted with test graphs, repository fakes and overridden transports. Controlled walkthroughs for selected historical workflows | Widget assertions apply to the viewport, input and fake responses exercised |
| Recovery and responsiveness | Local file/checkpoint and retry tests, controlled Completer/Future delays, renderer fixtures with large text and small viewports | These verify behavior under modeled interruption. Physical camera, OS lifecycle and browser measurements require separate runs |
| AI contribution | Deterministic landmark processing, optional fixture replay, on-device observations, mocked provider contract tests and separately scoped real-provider evaluations | Each only supports its own metric and environment |
| Acceptance | Historical operator checks and a proposed Member/Coach/Admin protocol | See [11 UAT](11_USER_ACCEPTANCE_TESTING.md) for completion and participation boundaries |

## 5.2.2 Unit testing

Pure Dart `test` covers the domain, transport/data and pose packages. Domain checks exercise value constraints and planning calculations. Data tests inspect serialized requests and response interpretation with injected transports. The pose package tests exercise phase changes, camera geometry, confidence, dwell, scoring eligibility and state invalidation from constructed frames. `packages/gainpath_pose/test/squat_delivery_timing_test.dart` is useful evidence for delivery timing because the clock/sequence is controlled independently of physical inference. `packages/gainpath_pose/test/floor_push_up_fixture_evaluator_test.dart` exercises fixture ingestion and diagnostic outcomes and includes tool execution cases. These suites establish regression behavior against supplied samples.

Vitest runs TypeScript service tests matching `functions/test/**/*.test.ts`. `functions/vitest.config.mts` excludes four retained-evidence suites from default mode. `functions/test/booking-fixture.ts`, `workout-backup-fixture.ts` and `reward-journey-fixture.ts` provide test data or backing stores for service assertions. Injected SDK adapters, provider callbacks and deterministic times isolate external services. Do not count a pass against an in-memory store as a committed Firestore transaction.

## 5.2.3 Widget and user interface testing

Flutter `testWidgets` covers rendering, taps, routes, asynchronous loading and failure, the entitlement gate, presentation of no-data states and narrow/large-text layouts. Representative cases include `apps/mobile/test/membership_access_gate_test.dart`, `booking_payment_screen_test.dart`, `chatbot_recovery_test.dart` and `coach_profile_and_certifications_ux_test.dart`. Admin cases include `apps/admin_web/test/operations_calendar_screen_test.dart`, `announcements_test.dart`, `reward_management_screen_test.dart` and `payment_review_screen_test.dart`. Offline capture harnesses have fixture fonts and seeded membership/booking/reward data. Window manipulation in these tests assesses a layout under the stated configuration. Screen-reader speech, TalkBack traversal and device-specific visual parity need separate verification.

## 5.2.4 Integration testing

`functions/emulator/run-suites.cjs` runs a legacy core plus separately guarded backup, checkin, reporting, rounds, participation and catalogstatus groups. It copies the exact local Firestore Rules, indexes and Storage Rules into a temporary config and selects only loopback services with `demo-` project IDs. More specialized FYP/recommendation suites use dedicated config files, ports and in some cases prepared Functions. Flutter emulator tests under `apps/{mobile,admin_web}/test/emulator/` use explicitly enabled test compositions and local HTTP clients. The default Vitest run and the Firebase suite answer different questions.

The Node callable transport tests use actual handlers under localhost HTTP where specified. `functions/test/batch2-read-callables.test.ts` checks server rejection on an unauthenticated request, without invoking the core read handler. Provider adapters use mocked transport in `billplz-sandbox.test.ts`, `xendit-booking.test.ts`, `google-gym-provider.test.ts` and `equipment-scanner.test.ts`. Such checks evidence request construction and parsing under injected responses. Historical sandbox settlements and live Gemini checks belong to the exact approved scenarios in the original reports.

## 5.2.5 System and functional testing

`docs/qa/fyp-demo-integration-acceptance.md` assembles earlier controlled fixture/Firestore emulator and build results for Member membership and booking, rewards and check-in, and Admin financial operations. Read the Results and Remaining Acceptance sections together. `docs/integration/gainpath-fyp-cohort-integration.md` documents an earlier ordinary-client-path emulator test of the same role-based workflows with a fictional FYP cohort. `docs/integration/gainpath-fyp-live-integration.md` and `gainpath-unified-admin-integration.md` record subsequent constrained cloud/Admin acceptance with native verification held. These scoped acceptance snapshots are not current retests.

## 5.2.6 Non-functional testing

Source-based checks cover authorization, data isolation, recovery, controlled concurrency, lifecycle and UI readability. Examples are `functions/test/membership-commerce-security.test.ts`, `functions/emulator/coach-availability.test.ts`, `apps/mobile/test/features/workout_sync_test.dart` and the built-in compact dashboard/viewport tests. See [non-functional cases](09_TEST_CASES/NON_FUNCTIONAL.md) for coverage holes. Device compute and end-to-end latency must be read in the historical pose evaluation context. The audit found no basis to generalize device support, latency, memory, accessibility or security from a generic test count.

## 5.2.7 Regression testing

| Earlier defect | Correction and regression | Historical result |
| --- | --- | --- |
| Admin Payments initial booking detail failed to open because its loader gate was still raised | `0404c32` opens detail after loading state resolves. `apps/admin_web/test/payment_review_screen_test.dart` | Focused acceptance covered linked details in `docs/qa/fyp-demo-integration-acceptance.md` |
| Fixed-port emulator cases were routed through the legacy emulator with mismatched ports | `11e4e65` separates standalone configurations from the legacy registry. `functions/emulator/run-suites.cjs` and `functions/test/emulator-suites.test.ts` | Historical registry failure cleared, while other failures remained in the full backend report |
| Configured short booking calendar ranges were rejected by a fixed range expectation | `2606933` accepts a roster window of 1 to 30 days with configured range enforcement. See `docs/architecture/module-9-uat.md` | Dated regression and corrected Android artifact reported there |
| A steady delayed pose stream could repeatedly reset a phase watchdog | Dated pose work separates capture freshness and accepted geometry delivery. `packages/gainpath_pose/test/squat_delivery_timing_test.dart` and the physical acceptance reports | Deterministic replay evidence. Repeat the affected physical conditions before claiming accuracy |
| Concurrent emulator fixtures and a visit fixture used unstable time assumptions | `95ef039` fixes the visit test timezone and stabilizes emulator fixtures | Commit evidence. Earlier unrelated suite failures should be compared by test identity and snapshot |

## 5.2.8 AI model and algorithm evaluation

Use separate evidence labels for detector inference, constructed landmark sequence, retained recording replay, physical observed behavior, and a formal labelled trial. Fixed-angle sequences can verify rep counting and rejection paths when the estimator input is controlled. Physical capture with an independent reference is needed to evaluate counting accuracy, form-class decisions, voice timing, dropout and recovery. Equipment API parsing tests cannot establish recognition accuracy. Chatbot provider transport/safety handling and blinded fitness-response assessment are different outcomes. Admin ranking/queue/delivery fixtures verify deterministic constraints and transitions. Report Gemini ranking and instructor relevance under their respective scopes. See [10 Core AI evaluation](10_CORE_AI_EVALUATION/).

## 5.2.9 User acceptance testing

The repository contains checklists and dated highly scoped owner, browser, phone and sandbox checks. The records located do not document a formal multi-role participant study for this snapshot. [11 UAT](11_USER_ACCEPTANCE_TESTING.md) contains the historical evidence classification and proposed role-specific study.
