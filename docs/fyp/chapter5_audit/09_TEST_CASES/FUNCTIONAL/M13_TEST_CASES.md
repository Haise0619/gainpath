# M13 · AI training and content recommendation

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M13-01 · Consent, candidate and ranking guard

| Field | Evidence |
| --- | --- |
| Test case ID | F-M13-01 |
| Test case name | Consent, candidate and ranking guard |
| Module | M13 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Consent, candidate and ranking guard |
| Preconditions | TD-REC in/out-of-scope, stale and authorized data |
| Test data | TD-REC in/out-of-scope, stale and authorized data |
| Test steps | Build candidates, introduce unavailable/stale result and compare output and trace |
| Expected result | Only eligible consented/context-supported candidates survive; model output remains bounded |
| Actual result | 19 pass/0 fail/0 skip [backend-portable]; 24 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/recommendation-consent-v2.test.ts:8; functions/test/workout-recommendation-ranking.test.ts:33 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M13-02 · Admin review and controlled Member delivery

| Field | Evidence |
| --- | --- |
| Test case ID | F-M13-02 |
| Test case name | Admin review and controlled Member delivery |
| Module | M13 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Admin review and controlled Member delivery |
| Preconditions | TD-REC prepared output and fixture revision |
| Test data | TD-REC prepared output and fixture revision |
| Test steps | Review, confirm/dismiss and reopen output as Member with matching scope |
| Expected result | Decision/revision and recipient preview remain consistent, invalid target stays blocked |
| Actual result | 20 pass/0 fail/0 skip [backend-portable]; 28 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/admin-portable.txt |
| Source reference | functions/test/recommendation-delivery.test.ts:5; apps/admin_web/test/admin_recommendation_queue_test.dart:12 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M13-03 · Recommendation inbox and current action

| Field | Evidence |
| --- | --- |
| Test case ID | F-M13-03 |
| Test case name | Recommendation inbox and current action |
| Module | M13 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Recommendation inbox and current action |
| Preconditions | Typed simulated inbox and destination entries |
| Test data | Typed simulated inbox and destination entries |
| Test steps | Open inbox, dismiss/read and navigate current permitted destinations |
| Expected result | Membership/consent/current target gates preserve scope and acknowledgement state |
| Actual result | 11 pass/0 fail/0 skip [mobile-portable]; 27 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/member_recommendation_navigation_test.dart:172; functions/test/recommendation-member-service.test.ts:6 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
