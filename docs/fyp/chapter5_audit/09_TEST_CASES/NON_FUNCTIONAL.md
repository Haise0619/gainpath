# Non-functional verification

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## N-01 · Startup, detector and voice timing

| Field | Evidence |
| --- | --- |
| Test case ID | N-01 |
| Test case name | Startup, detector and voice timing |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Startup, detector and voice timing |
| Preconditions | Approved physical build and measured repetition |
| Test data | Approved physical build and measured repetition |
| Test steps | Record time from startup to first frame, frame capture/inference/delivery and feedback |
| Expected result | Export median and p95 by device/exercise with sample count and outliers |
| Actual result | Historical physical trials in pose reports. Current dataset pending |
| Status | Not Executed |
| Environment | Proposed staged environment |
| Evidence | Source only |
| Source reference | Pending |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-02 · Reporting responsiveness and workload

| Field | Evidence |
| --- | --- |
| Test case ID | N-02 |
| Test case name | Reporting responsiveness and workload |
| Module | M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Reporting responsiveness and workload |
| Preconditions | Supplied report query fixtures and controlled Future delays |
| Test data | Supplied report query fixtures and controlled Future delays |
| Test steps | Load, switch filters rapidly and capture app timing with declared dataset size |
| Expected result | No stale result overwrites active scope. Record p50/p95 for the proposed browser run |
| Actual result | 8 pass/0 fail/0 skip [admin-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt |
| Source reference | apps/admin_web/test/admin_read_latency_test.dart:133 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-03 · Authorization and stale membership scope

| Field | Evidence |
| --- | --- |
| Test case ID | N-03 |
| Test case name | Authorization and stale membership scope |
| Module | M01/M04/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Authorization and stale membership scope |
| Preconditions | Role- and org-specific test actors |
| Test data | Role- and org-specific test actors |
| Test steps | Request same protected resource as scoped, expired and cross-scope roles |
| Expected result | Correct allow/deny, authoritative update only for current scoped actor |
| Actual result | 15 pass/0 fail/0 skip [backend-portable]; 3 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/membership-commerce-security.test.ts:8; functions/test/authorization.test.ts:4 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-04 · Owner-centric backup authorization

| Field | Evidence |
| --- | --- |
| Test case ID | N-04 |
| Test case name | Owner-centric backup authorization |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Owner-centric backup authorization |
| Preconditions | Local Firestore Rules and staged backup |
| Test data | Local Firestore Rules and staged backup |
| Test steps | Attempt a direct SDK write without callable and read authorized receipt through service |
| Expected result | No direct backup access through client Rules, valid service path works |
| Actual result | 5 pass/0 fail/0 skip [emulator-full] |
| Status | Pass |
| Environment | Firebase loopback demo |
| Evidence | evidence/test_logs/emulator-full.txt |
| Source reference | functions/emulator/workout-backup.test.ts:19 |
| Remarks | Executed on the local Firebase SDK/Rules path. This result does not cover browser or native interaction. |

## N-05 · Concurrency and duplicate handling

| Field | Evidence |
| --- | --- |
| Test case ID | N-05 |
| Test case name | Concurrency and duplicate handling |
| Module | M03/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Concurrency and duplicate handling |
| Preconditions | Synthetic ledger/stock and booking overlap fixtures |
| Test data | Synthetic ledger/stock and booking overlap fixtures |
| Test steps | Issue simultaneous eligible and competing requests, observe persisted results |
| Expected result | At most one final stock/booking effect; exact retry preserves identity |
| Actual result | 4 pass/0 fail/0 skip [emulator-full]; 5 pass/0 fail/0 skip [emulator-full] |
| Status | Not Executed |
| Environment | Firebase loopback demo |
| Evidence | evidence/test_logs/emulator-full.txt |
| Source reference | functions/emulator/coach-availability.test.ts:24; functions/emulator/reward-journey.test.ts:35 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-06 · Verified callback and financial correctness

| Field | Evidence |
| --- | --- |
| Test case ID | N-06 |
| Test case name | Verified callback and financial correctness |
| Module | M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Verified callback and financial correctness |
| Preconditions | TD-COMMERCE synthetic outcome and mismatch cases |
| Test data | TD-COMMERCE synthetic outcome and mismatch cases |
| Test steps | Replay persisted event and compare provider amount/reference and approval state |
| Expected result | Malformed/mismatched event cannot settle. Exact accepted replay is idempotent |
| Actual result | 7 pass/0 fail/0 skip [backend-portable]; 17 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/booking-payment-callback.test.ts:51; functions/test/membership-payment.test.ts:23 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-07 · Privacy, consent and account isolation

| Field | Evidence |
| --- | --- |
| Test case ID | N-07 |
| Test case name | Privacy, consent and account isolation |
| Module | M01/M13 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Privacy, consent and account isolation |
| Preconditions | TD-ROLE two identities and TD-REC consent |
| Test data | TD-ROLE two identities and TD-REC consent |
| Test steps | Change active session/consent and request existing recommendation data |
| Expected result | No wrong-account or unauthorized sharing/read; closed workflow retains proper status |
| Actual result | 3 pass/0 fail/0 skip [mobile-portable]; 19 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/privacy_and_data_settings_test.dart:50; functions/test/recommendation-consent-v2.test.ts:8 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-08 · Camera image and landmark privacy

| Field | Evidence |
| --- | --- |
| Test case ID | N-08 |
| Test case name | Camera image and landmark privacy |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Camera image and landmark privacy |
| Preconditions | Device permissions and dedicated test identity |
| Test data | Device permissions and dedicated test identity |
| Test steps | Deny/regrant camera on physical device and review debug/runtime persistence and disclosure under camera modes |
| Expected result | Permission state and processing scope match documented app behavior |
| Actual result | No fresh physical camera or production network capture |
| Status | Not Executed |
| Environment | Proposed staged environment |
| Evidence | Source only |
| Source reference | Pending |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-09 · Sync, interruption and recovery

| Field | Evidence |
| --- | --- |
| Test case ID | N-09 |
| Test case name | Sync, interruption and recovery |
| Module | M02/M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Sync, interruption and recovery |
| Preconditions | Local file-backed workout with delayed/failed backup |
| Test data | Local file-backed workout with delayed/failed backup |
| Test steps | Pause/restart, relay reconnect and retry; verify once-only history/receipt |
| Expected result | Recovery neither loses successful record nor repeats cloud effects |
| Actual result | 12 pass/0 fail/0 skip [mobile-portable]; 5 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/file_real_workout_sync_store_test.dart:27; apps/mobile/test/features/workout_sync_test.dart:8 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-10 · Camera interruption and low confidence

| Field | Evidence |
| --- | --- |
| Test case ID | N-10 |
| Test case name | Camera interruption and low confidence |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Camera interruption and low confidence |
| Preconditions | Injected pose errors and stale frame timing |
| Test data | Injected pose errors and stale frame timing |
| Test steps | Interrupt camera frames, lose device scope and recover session |
| Expected result | Analyzers invalidate stale input and resume under documented readiness conditions |
| Actual result | 8 pass/0 fail/0 skip [mobile-portable]; 2 pass/0 fail/0 skip [dart-pose-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/dart-pose-portable.txt |
| Source reference | apps/mobile/test/pose_failure_recovery_test.dart:51; packages/gainpath_pose/test/squat_delivery_timing_test.dart:6 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-11 · Narrow layout and larger type

| Field | Evidence |
| --- | --- |
| Test case ID | N-11 |
| Test case name | Narrow layout and larger type |
| Module | M04/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Narrow layout and larger type |
| Preconditions | Compact portrait, wide view and large text fixture |
| Test data | Compact portrait, wide view and large text fixture |
| Test steps | Render booking/checkout views and visit pending/error panels |
| Expected result | Readable content/action controls at viewport configurations actually tested |
| Actual result | 0 pass/0 fail/1 skip [mobile-portable]; 12 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/commercial_booking_checkout_render_test.dart:15; apps/mobile/test/membership_commercial_render_test.dart:71 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-12 · Admin accessibility and browser compatibility

| Field | Evidence |
| --- | --- |
| Test case ID | N-12 |
| Test case name | Admin accessibility and browser compatibility |
| Module | M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Admin accessibility and browser compatibility |
| Preconditions | Approved desktop and alternate browser, keyboard and screen reader |
| Test data | Approved desktop and alternate browser, keyboard and screen reader |
| Test steps | Walk keyboard focus, chart descriptions, route switching and optional zoom |
| Expected result | Record completion, unavailable actions, focus order and clippings by browser/viewport |
| Actual result | Widget rendering is distinct from keyboard and assistive-technology acceptance |
| Status | Not Executed |
| Environment | Proposed staged environment |
| Evidence | Source only |
| Source reference | Pending |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## N-13 · Mobile hardware compatibility and long session resources

| Field | Evidence |
| --- | --- |
| Test case ID | N-13 |
| Test case name | Mobile hardware compatibility and long session resources |
| Module | M02/M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Non-functional |
| Objective | Mobile hardware compatibility and long session resources |
| Preconditions | Target Android devices/orientations and staged lesson |
| Test data | Target Android devices/orientations and staged lesson |
| Test steps | Record resource use and performance over a defined full session, rotate where supported |
| Expected result | Record crashes, dropped frames, device-specific limitations, CPU/memory and process recovery |
| Actual result | No fresh alternate device or resource measurement |
| Status | Not Executed |
| Environment | Proposed staged environment |
| Evidence | Source only |
| Source reference | Pending |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |
