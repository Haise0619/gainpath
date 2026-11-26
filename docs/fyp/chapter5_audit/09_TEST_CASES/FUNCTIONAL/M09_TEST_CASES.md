# M09 · Coach scheduling and consultation

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M09-01 · Coach roster and consultation notes

| Field | Evidence |
| --- | --- |
| Test case ID | F-M09-01 |
| Test case name | Coach roster and consultation notes |
| Module | M09 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Coach roster and consultation notes |
| Preconditions | TD-BOOK assigned confirmed and inactive booking states |
| Test data | TD-BOOK assigned confirmed and inactive booking states |
| Test steps | Open roster, inspect selected session, try valid/ineligible consultation action |
| Expected result | Shows scoped booked clients and accepts valid consultation transition only |
| Actual result | 12 pass/0 fail/0 skip [mobile-portable]; 4 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/coach_roster_ui_test.dart:77; functions/test/booking-consultation.test.ts:20 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M09-02 · Confirmed session communication and lifecycle

| Field | Evidence |
| --- | --- |
| Test case ID | F-M09-02 |
| Test case name | Confirmed session communication and lifecycle |
| Module | M09 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Confirmed session communication and lifecycle |
| Preconditions | Pending/confirmed/elapsed/cancelled fixtures |
| Test data | Pending/confirmed/elapsed/cancelled fixtures |
| Test steps | Run status transitions and attempt allowed participant thread actions |
| Expected result | Closed or inaccessible booking applies correct limits while valid history stays available |
| Actual result | 6 pass/0 fail/0 skip [backend-portable]; 13 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/booking-communication.test.ts:28; functions/test/booking-lifecycle.test.ts:20 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
