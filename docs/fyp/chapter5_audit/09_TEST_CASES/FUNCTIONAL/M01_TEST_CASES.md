# M01 · Authentication, profile and recovery

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M01-01 · Sign-in and identity lifecycle

| Field | Evidence |
| --- | --- |
| Test case ID | F-M01-01 |
| Test case name | Sign-in and identity lifecycle |
| Module | M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Sign-in and identity lifecycle |
| Preconditions | A detached member account in the fake Auth graph |
| Test data | A detached member account in the fake Auth graph |
| Test steps | Submit normal then rejected credentials, dispose the user session and reopen the protected route |
| Expected result | Correct members receive scoped session. Auth and lifecycle failures remain visible and scoped |
| Actual result | 0 pass/1 fail/0 skip [mobile-portable]; 4 pass/0 fail/0 skip [mobile-portable] |
| Status | Fail |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/mobile_auth_lifetime_test.dart:67; apps/mobile/test/member_account_lifecycle_repository_test.dart:30 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M01-02 · Fitness profile setup and preferences

| Field | Evidence |
| --- | --- |
| Test case ID | F-M01-02 |
| Test case name | Fitness profile setup and preferences |
| Module | M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Fitness profile setup and preferences |
| Preconditions | TD-PROFILE and incomplete profile |
| Test data | TD-PROFILE and incomplete profile |
| Test steps | Load gated route, complete fields, save, navigate away and reopen |
| Expected result | Profile completion and own preferences persist. Missing required state prevents completion |
| Actual result | 0 pass/1 fail/0 skip [mobile-portable]; 3 pass/0 fail/0 skip [mobile-portable] |
| Status | Fail |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/fitness_profile_flow_test.dart:83; apps/mobile/test/fitness_profile_gate_test.dart:19 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M01-03 · Password recovery state

| Field | Evidence |
| --- | --- |
| Test case ID | F-M01-03 |
| Test case name | Password recovery state |
| Module | M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Password recovery state |
| Preconditions | An existing synthetic address and injected recovery outcomes |
| Test data | An existing synthetic address and injected recovery outcomes |
| Test steps | Submit request, exercise challenge/verification and rejected input then confirm permitted transition |
| Expected result | Wizard only advances when its command and validation succeed |
| Actual result | 1 pass/0 fail/0 skip [mobile-portable]; 0 pass/1 fail/0 skip [mobile-portable] |
| Status | Fail |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/password_recovery_screen_test.dart:13; apps/mobile/test/password_reset_test.dart:27 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M01-04 · Legal, privacy and lifecycle

| Field | Evidence |
| --- | --- |
| Test case ID | F-M01-04 |
| Test case name | Legal, privacy and lifecycle |
| Module | M01 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Legal, privacy and lifecycle |
| Preconditions | Current synthetic session and legal document |
| Test data | Current synthetic session and legal document |
| Test steps | Open current policy, exercise consent/lifecycle UI and verify account state changes stay isolated |
| Expected result | Current disclosure and authorized controls use the authenticated account |
| Actual result | 3 pass/0 fail/0 skip [mobile-portable]; 13 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/member_legal_privacy_test.dart:8; functions/test/member-account-lifecycle.test.ts:23 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
