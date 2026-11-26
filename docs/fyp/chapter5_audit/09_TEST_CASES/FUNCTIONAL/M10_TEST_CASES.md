# M10 · Coach availability and roster

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M10-01 · Weekly availability and exceptions

| Field | Evidence |
| --- | --- |
| Test case ID | F-M10-01 |
| Test case name | Weekly availability and exceptions |
| Module | M10 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Weekly availability and exceptions |
| Preconditions | TD-BOOK recurring, blocked and special date data |
| Test data | TD-BOOK recurring, blocked and special date data |
| Test steps | Read weekly configuration, change a dated exception and inspect applied dates |
| Expected result | Effective slot follows authoritative weekly/dated schedule policy |
| Actual result | 0 pass/1 fail/0 skip [mobile-portable]; 26 pass/0 fail/0 skip [backend-portable] |
| Status | Fail |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/coach_availability_flow_test.dart:48; functions/test/coach-roster.test.ts:22 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M10-02 · Constraints and conflict

| Field | Evidence |
| --- | --- |
| Test case ID | F-M10-02 |
| Test case name | Constraints and conflict |
| Module | M10 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Constraints and conflict |
| Preconditions | Existing reserved booking and altered availability or capacity |
| Test data | Existing reserved booking and altered availability or capacity |
| Test steps | Attempt an overlapping blocked interval and adjust future work period |
| Expected result | Conflict safety preserved and valid future changes represented |
| Actual result | 25 pass/0 fail/0 skip [backend-portable]; 4 pass/0 fail/0 skip [emulator-full] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Firebase loopback demo |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/emulator-full.txt |
| Source reference | functions/test/coach-availability.test.ts:15; functions/emulator/coach-availability.test.ts:24 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
