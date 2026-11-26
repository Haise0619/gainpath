# Cross-module integration

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## X-01 · Authenticate → verify → profile → application

| Field | Evidence |
| --- | --- |
| Test case ID | X-01 |
| Test case name | Authenticate → verify → profile → application |
| Module | M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Authenticate → verify → profile → application |
| Preconditions | TD-ROLE with verified/unverified and TD-PROFILE |
| Test data | TD-ROLE with verified/unverified and TD-PROFILE |
| Test steps | Sign in with synthetic fixture, complete verification and save profile; reopen entitled app routes |
| Expected result | Protected routes and data unlock only after valid Auth/profile state |
| Actual result | 3 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/fitness_profile_gate_test.dart:19 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-02 · Provisioned Coach → private draft → Admin publish → Member discovery

| Field | Evidence |
| --- | --- |
| Test case ID | X-02 |
| Test case name | Provisioned Coach → private draft → Admin publish → Member discovery |
| Module | M08/M11/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Provisioned Coach → private draft → Admin publish → Member discovery |
| Preconditions | Disposable Coach/Admin/Member |
| Test data | Disposable Coach/Admin/Member |
| Test steps | Save Coach draft, approve/publish as Admin, open directory as Member |
| Expected result | Only approved public attributes become discoverable with own-scope restrictions |
| Actual result | 4 pass/0 fail/0 skip [emulator-full] |
| Status | Pass |
| Environment | Firebase loopback demo |
| Evidence | evidence/test_logs/emulator-full.txt |
| Source reference | functions/emulator/coach-directory.test.ts:34 |
| Remarks | Executed on the local Firebase SDK/Rules path. This result does not cover browser or native interaction. |

## X-03 · Publish routine → complete activity → backup → History

| Field | Evidence |
| --- | --- |
| Test case ID | X-03 |
| Test case name | Publish routine → complete activity → backup → History |
| Module | M11/M02/M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Publish routine → complete activity → backup → History |
| Preconditions | Staged published routine, Member and approved camera |
| Test data | Staged published routine, Member and approved camera |
| Test steps | Publish blended routine, exercise mixed modes, save and read exact same workout in History |
| Expected result | Stable activity ID and metric counts retained across layers |
| Actual result | 1 pass/0 fail/0 skip [mobile-portable]; 30 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/hybrid_routine_journey_test.dart:77; functions/test/workout-backup.test.ts:6 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-04 · Completed activity → reward/achievement → analytics

| Field | Evidence |
| --- | --- |
| Test case ID | X-04 |
| Test case name | Completed activity → reward/achievement → analytics |
| Module | M02/M03/M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Completed activity → reward/achievement → analytics |
| Preconditions | TD-TRAIN eligible completed record |
| Test data | TD-TRAIN eligible completed record |
| Test steps | Back up, reopen receipt, claim and replay workout points, examine dashboard totals |
| Expected result | One ledger award where qualified, one measurement record, stable counts |
| Actual result | 10 pass/0 fail/0 skip [backend-portable]; 7 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/test/workout-rewards.test.ts:12; apps/mobile/test/workout_rewards_status_test.dart:33 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-05 · Form evidence → candidates → review → Member inbox

| Field | Evidence |
| --- | --- |
| Test case ID | X-05 |
| Test case name | Form evidence → candidates → review → Member inbox |
| Module | M02/M13 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Form evidence → candidates → review → Member inbox |
| Preconditions | Consent and scoped measured workout fixture |
| Test data | Consent and scoped measured workout fixture |
| Test steps | Accept normalized evidence, generate candidates, review and execute approved fixture delivery |
| Expected result | Strict evidence binding and stable recipient record |
| Actual result | 42 pass/0 fail/0 skip [backend-portable]; 20 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/workout-backup-recommendations.test.ts:60; functions/test/recommendation-delivery.test.ts:5 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-06 · Sandbox checkout → clearance → entitlement

| Field | Evidence |
| --- | --- |
| Test case ID | X-06 |
| Test case name | Sandbox checkout → clearance → entitlement |
| Module | M04/M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Sandbox checkout → clearance → entitlement |
| Preconditions | Staged Free Member and Sandbox provider |
| Test data | Staged Free Member and Sandbox provider |
| Test steps | Quote and start payment, wait signed settlement, refresh exact entitlement |
| Expected result | No membership activation before cleared and correlated payment |
| Actual result | 17 pass/0 fail/0 skip [backend-portable]; 6 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/test/membership-payment.test.ts:23; apps/mobile/test/membership_access_gate_test.dart:41 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-07 · Membership expiry → paid function restricted

| Field | Evidence |
| --- | --- |
| Test case ID | X-07 |
| Test case name | Membership expiry → paid function restricted |
| Module | M04/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Membership expiry → paid function restricted |
| Preconditions | Expired membership and valid booking option |
| Test data | Expired membership and valid booking option |
| Test steps | Open booking action and call gated backend with expired account |
| Expected result | Protected paid function rejects expired entitlement without side effect |
| Actual result | 6 pass/0 fail/0 skip [mobile-portable]; 25 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/membership_access_gate_test.dart:41; functions/test/membership-entitlement.test.ts:24 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-08 · Redeem → debit → voucher → Admin visibility

| Field | Evidence |
| --- | --- |
| Test case ID | X-08 |
| Test case name | Redeem → debit → voucher → Admin visibility |
| Module | M03/M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Redeem → debit → voucher → Admin visibility |
| Preconditions | Published reward and eligible balance |
| Test data | Published reward and eligible balance |
| Test steps | Redeem, repeat request, reopen valid voucher as correct role |
| Expected result | Exactly one debit/voucher and consistent fulfillment status |
| Actual result | 5 pass/0 fail/0 skip [emulator-full]; 7 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Firebase loopback demo; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/emulator-full.txt; evidence/test_logs/backend-portable.txt |
| Source reference | functions/emulator/reward-journey.test.ts:35; functions/test/reward-journey.test.ts:14 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-09 · Coach availability → Member slot → verified payment → roster

| Field | Evidence |
| --- | --- |
| Test case ID | X-09 |
| Test case name | Coach availability → Member slot → verified payment → roster |
| Module | M10/M07/M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Coach availability → Member slot → verified payment → roster |
| Preconditions | Approved Coach, compatible schedule and staged Checkout |
| Test data | Approved Coach, compatible schedule and staged Checkout |
| Test steps | Load slot, create hold, use verified paid fixture and refresh both role views |
| Expected result | Reservation stable and visible to participants, competing requests rejected |
| Actual result | 25 pass/0 fail/0 skip [backend-portable]; 19 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/coach-availability.test.ts:15; functions/test/booking-payment.test.ts:24 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-10 · Complete booked session → consultation/report

| Field | Evidence |
| --- | --- |
| Test case ID | X-10 |
| Test case name | Complete booked session → consultation/report |
| Module | M09/M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Complete booked session → consultation/report |
| Preconditions | Assigned confirmed session, approved Coach and scoped Admin |
| Test data | Assigned confirmed session, approved Coach and scoped Admin |
| Test steps | Finish consultation via configured path, read report interval and evidence status |
| Expected result | Valid complete transition reflected in authorized reporting scope |
| Actual result | 4 pass/0 fail/0 skip [backend-portable]; 13 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/booking-consultation.test.ts:20; functions/test/admin-reporting.test.ts:13 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-11 · Cancellation → request refund → Admin review → status

| Field | Evidence |
| --- | --- |
| Test case ID | X-11 |
| Test case name | Cancellation → request refund → Admin review → status |
| Module | M07/M04/M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Cancellation → request refund → Admin review → status |
| Preconditions | Staged cancelled paid booking |
| Test data | Staged cancelled paid booking |
| Test steps | Request refund, inspect review approval and settlement states separately |
| Expected result | Refund approval distinct from provider completion, correct status projected |
| Actual result | 20 pass/0 fail/0 skip [backend-portable]; 11 pass/0 fail/0 skip [admin-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/admin-portable.txt |
| Source reference | functions/test/booking-payment-admin.test.ts:13; apps/admin_web/test/payment_review_screen_test.dart:44 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-12 · Exercise publication → Member catalogue

| Field | Evidence |
| --- | --- |
| Test case ID | X-12 |
| Test case name | Exercise publication → Member catalogue |
| Module | M11/M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Exercise publication → Member catalogue |
| Preconditions | Authorized catalog draft and Member fixture |
| Test data | Authorized catalog draft and Member fixture |
| Test steps | Publish valid exercise and reload participant catalogue |
| Expected result | Only active published entry surfaces and catalog identity preserved |
| Actual result | 18 pass/0 fail/0 skip [backend-portable]; 41 pass/0 fail/0 skip [emulator-full] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes; Firebase loopback demo |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/emulator-full.txt |
| Source reference | functions/test/exercise-catalog.test.ts:12; functions/emulator/exercise-catalog-status.test.ts:40 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-13 · Publish class → register → participant management

| Field | Evidence |
| --- | --- |
| Test case ID | X-13 |
| Test case name | Publish class → register → participant management |
| Module | ADD/M11/M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Publish class → register → participant management |
| Preconditions | Demo branch class of finite capacity |
| Test data | Demo branch class of finite capacity |
| Test steps | Publish and register staged Member, attempt full capacity case |
| Expected result | One slot per accepted request, correct role completion |
| Actual result | 0 pass/0 fail/1 skip [backend-portable]; 6 pass/0 fail/0 skip [admin-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/admin-portable.txt |
| Source reference | functions/test/group-classes-emulator.test.ts:12; apps/admin_web/test/group_classes_widget_test.dart:76 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-14 · Compliance publication → Member acceptance

| Field | Evidence |
| --- | --- |
| Test case ID | X-14 |
| Test case name | Compliance publication → Member acceptance |
| Module | M11/M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Compliance publication → Member acceptance |
| Preconditions | Staged revised legal document |
| Test data | Staged revised legal document |
| Test steps | Publish authorized preview version and inspect current authenticated Member prompt |
| Expected result | Correct version appears and acceptance attaches to authorized Member |
| Actual result | 10 pass/0 fail/0 skip [admin-portable]; 3 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | apps/admin_web/test/compliance_documents_test.dart:175; apps/mobile/test/member_legal_privacy_test.dart:8 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-15 · Offline completion → reconnect → backup → analytics

| Field | Evidence |
| --- | --- |
| Test case ID | X-15 |
| Test case name | Offline completion → reconnect → backup → analytics |
| Module | M02/M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Offline completion → reconnect → backup → analytics |
| Preconditions | Synthetic interrupted workout |
| Test data | Synthetic interrupted workout |
| Test steps | Save locally, restart, reconnect, replay failed sync and compare scoped persisted history |
| Expected result | One correct cloud backup, no false clearance or duplication |
| Actual result | 5 pass/0 fail/0 skip [emulator-full]; 5 pass/0 fail/0 skip [mobile-portable] |
| Status | Not Executed |
| Environment | Firebase loopback demo; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/emulator-full.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/emulator/workout-backup.test.ts:19; apps/mobile/test/features/workout_sync_test.dart:8 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |

## X-16 · Consent revoked before delivery → inbox reflects eligibility

| Field | Evidence |
| --- | --- |
| Test case ID | X-16 |
| Test case name | Consent revoked before delivery → inbox reflects eligibility |
| Module | M13/M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Cross-module / system |
| Objective | Consent revoked before delivery → inbox reflects eligibility |
| Preconditions | Authorized fixture decision, changed consent |
| Test data | Authorized fixture decision, changed consent |
| Test steps | Generate proposed content, change consent prior to send then attempt delivery |
| Expected result | Consent re-evaluated on delivery; invalid output is not sent |
| Actual result | 20 pass/0 fail/0 skip [backend-portable] |
| Status | Not Executed |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/recommendation-delivery.test.ts:5 |
| Remarks | Component assertions and archived observations do not constitute a fresh full-path scenario execution. |
