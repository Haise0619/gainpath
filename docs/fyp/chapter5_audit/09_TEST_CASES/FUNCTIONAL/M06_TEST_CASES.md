# M06 · Fitness chatbot

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M06-01 · Contextual request and response

| Field | Evidence |
| --- | --- |
| Test case ID | F-M06-01 |
| Test case name | Contextual request and response |
| Module | M06 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Contextual request and response |
| Preconditions | TD-CHAT prompt, goal and optional scoped workout context |
| Test data | TD-CHAT prompt, goal and optional scoped workout context |
| Test steps | Build valid request with scoped context and invoke fake provider response |
| Expected result | Assistant validates input, constructs approved context and returns supported response schema |
| Actual result | 12 pass/0 fail/0 skip [backend-portable]; 8 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/chatbot.test.ts:5; functions/test/chatbot-optimization.test.ts:5 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M06-02 · Provider or UI recovery

| Field | Evidence |
| --- | --- |
| Test case ID | F-M06-02 |
| Test case name | Provider or UI recovery |
| Module | M06 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Provider or UI recovery |
| Preconditions | TD-CHAT invalid or unavailable provider response |
| Test data | TD-CHAT invalid or unavailable provider response |
| Test steps | Submit, inject timeout/retry and compare visible message state |
| Expected result | UI retains understandable recovery state and ignores stale output |
| Actual result | 5 pass/0 fail/0 skip [mobile-portable]; 23 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/chatbot_recovery_test.dart:51; functions/test/chatbot-callable.test.ts:15 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
