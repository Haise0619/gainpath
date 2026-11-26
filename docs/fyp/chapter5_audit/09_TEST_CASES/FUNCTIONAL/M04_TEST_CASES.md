# M04 · Membership and payment

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M04-01 · Purchase and verification

| Field | Evidence |
| --- | --- |
| Test case ID | F-M04-01 |
| Test case name | Purchase and verification |
| Module | M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Purchase and verification |
| Preconditions | TD-COMMERCE synthetic response set |
| Test data | TD-COMMERCE synthetic response set |
| Test steps | Create payment, settle unpaid then valid paid bill/session and read membership |
| Expected result | Pending stays pending. Verified clearance updates authorized membership |
| Actual result | 17 pass/0 fail/0 skip [backend-portable]; 14 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/test/membership-payment.test.ts:23; apps/mobile/test/membership_commercial_ui_test.dart:108 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M04-02 · Extension and expired entitlement

| Field | Evidence |
| --- | --- |
| Test case ID | F-M04-02 |
| Test case name | Extension and expired entitlement |
| Module | M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Extension and expired entitlement |
| Preconditions | TD-COMMERCE fixed current expiry and configurable term |
| Test data | TD-COMMERCE fixed current expiry and configurable term |
| Test steps | Compare active renewal behavior and expired/unknown entitlement state |
| Expected result | Term extension preserves unused term where allowed. Invalid, expired or unknown authorization remains restricted |
| Actual result | 21 pass/0 fail/0 skip [backend-portable]; 25 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/membership-flexible-renewal.test.ts:77; functions/test/membership-entitlement.test.ts:24 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M04-03 · Gateway selection and reconciliation view

| Field | Evidence |
| --- | --- |
| Test case ID | F-M04-03 |
| Test case name | Gateway selection and reconciliation view |
| Module | M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Gateway selection and reconciliation view |
| Preconditions | Mock provider and Admin financial detail |
| Test data | Mock provider and Admin financial detail |
| Test steps | Open payment detail and compare expected provider, charge status and resulting business state |
| Expected result | Provider and Admin labels reflect transport, payment and fulfilment states |
| Actual result | 15 pass/0 fail/0 skip [backend-portable]; 11 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/admin-portable.txt |
| Source reference | functions/test/membership-commerce-security.test.ts:8; apps/admin_web/test/payment_review_screen_test.dart:44 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M04-04 · Expired or conflicting scope

| Field | Evidence |
| --- | --- |
| Test case ID | F-M04-04 |
| Test case name | Expired or conflicting scope |
| Module | M04 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Expired or conflicting scope |
| Preconditions | TD-ACCESS unauthorized or stale identity and callable input |
| Test data | TD-ACCESS unauthorized or stale identity and callable input |
| Test steps | Attempt paid route and command with failing entitlement conditions |
| Expected result | Controlled UI block and service rejection; no settlement side effect |
| Actual result | 6 pass/0 fail/0 skip [mobile-portable]; 25 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/membership_access_gate_test.dart:41; functions/test/membership-entitlement.test.ts:24 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
