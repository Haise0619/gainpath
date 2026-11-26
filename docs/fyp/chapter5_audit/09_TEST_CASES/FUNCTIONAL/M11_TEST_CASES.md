# M11 · Admin system management

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M11-01 · Member and Coach administration

| Field | Evidence |
| --- | --- |
| Test case ID | F-M11-01 |
| Test case name | Member and Coach administration |
| Module | M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Member and Coach administration |
| Preconditions | TD-ROLE scoped Member/Coach/Admin and contact fixtures |
| Test data | TD-ROLE scoped Member/Coach/Admin and contact fixtures |
| Test steps | View/update allowed settings and attempt cross-scope action |
| Expected result | Only authoritative actor can perform scoped change, interface indicates outcome |
| Actual result | 10 pass/0 fail/0 skip [admin-portable]; 17 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt |
| Source reference | apps/admin_web/test/admin_shared_people_test.dart:149; apps/admin_web/test/admin_account_contact_test.dart:241 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M11-02 · Routine and program authoring

| Field | Evidence |
| --- | --- |
| Test case ID | F-M11-02 |
| Test case name | Routine and program authoring |
| Module | M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Routine and program authoring |
| Preconditions | TD-ROUTINE current and stale revision |
| Test data | TD-ROUTINE current and stale revision |
| Test steps | Edit and publish valid exercise/routine, try invalid media/version |
| Expected result | Valid publication and stable downstream identifiers. Incomplete media or stale state has clear rejection |
| Actual result | 7 pass/0 fail/0 skip [backend-portable]; 18 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/publish-routine-v2.test.ts:7; functions/test/exercise-catalog.test.ts:12 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M11-03 · Rewards, announcements and groups

| Field | Evidence |
| --- | --- |
| Test case ID | F-M11-03 |
| Test case name | Rewards, announcements and groups |
| Module | M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Rewards, announcements and groups |
| Preconditions | Admin scope and staged content/eligibility fixtures |
| Test data | Admin scope and staged content/eligibility fixtures |
| Test steps | Create or manage entries and check saved/restricted state from intended role |
| Expected result | Only published and eligible content is usable by intended Member |
| Actual result | 13 pass/0 fail/0 skip [admin-portable]; 6 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt |
| Source reference | apps/admin_web/test/reward_management_screen_test.dart:170; apps/admin_web/test/announcements_test.dart:201 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M11-04 · Payment review and branch configuration

| Field | Evidence |
| --- | --- |
| Test case ID | F-M11-04 |
| Test case name | Payment review and branch configuration |
| Module | M11 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Payment review and branch configuration |
| Preconditions | TD-COMMERCE and scoped branch data |
| Test data | TD-COMMERCE and scoped branch data |
| Test steps | Navigate from report to financial detail and verify status/actions and managed facility context |
| Expected result | Read-only inspection and eligible actions remain distinct with correct filters |
| Actual result | 11 pass/0 fail/0 skip [admin-portable]; 7 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt |
| Source reference | apps/admin_web/test/payment_review_screen_test.dart:44; apps/admin_web/test/facility_settings_test.dart:190 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
