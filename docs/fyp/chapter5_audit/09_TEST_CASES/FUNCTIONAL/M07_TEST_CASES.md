# M07 · Coach booking

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M07-01 · Discovery and availability

| Field | Evidence |
| --- | --- |
| Test case ID | F-M07-01 |
| Test case name | Discovery and availability |
| Module | M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Discovery and availability |
| Preconditions | TD-BOOK synthetic published coaches and slot grid |
| Test data | TD-BOOK synthetic published coaches and slot grid |
| Test steps | Filter coach list, inspect available date and select eligible slot |
| Expected result | Only scoped/discoverable coaches and offered slots are shown |
| Actual result | 8 pass/0 fail/0 skip [mobile-portable]; 37 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/browse_coaches_search_ux_test.dart:104; functions/test/member-booking-options.test.ts:16 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M07-02 · Reservation, payment and collision

| Field | Evidence |
| --- | --- |
| Test case ID | F-M07-02 |
| Test case name | Reservation, payment and collision |
| Module | M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Reservation, payment and collision |
| Preconditions | TD-BOOK and TD-COMMERCE, existing hold and alternative slot |
| Test data | TD-BOOK and TD-COMMERCE, existing hold and alternative slot |
| Test steps | Select, quote, confirm fake paid checkout and replay duplicate or overlapping request |
| Expected result | Correct confirmation and single reservation for same slot |
| Actual result | 50 pass/0 fail/0 skip [backend-portable]; 19 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/booking.test.ts:12; functions/test/booking-payment.test.ts:24 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M07-03 · Cancel, reschedule, refund request or review

| Field | Evidence |
| --- | --- |
| Test case ID | F-M07-03 |
| Test case name | Cancel, reschedule, refund request or review |
| Module | M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Cancel, reschedule, refund request or review |
| Preconditions | Confirmed booking with constrained dates and synthetic financial state |
| Test data | Confirmed booking with constrained dates and synthetic financial state |
| Test steps | Exercise alternatives inside and outside policy, refresh booking and compare result state |
| Expected result | Authorized transitions preserve booking/financial state. Blocked transitions remain unchanged |
| Actual result | 6 pass/0 fail/0 skip [backend-portable]; 4 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/member-booking-change.test.ts:27; functions/test/booking-review.test.ts:41 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M07-04 · Booking messaging history

| Field | Evidence |
| --- | --- |
| Test case ID | F-M07-04 |
| Test case name | Booking messaging history |
| Module | M07 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Booking messaging history |
| Preconditions | Pertinent participants and staged confirmed booking |
| Test data | Pertinent participants and staged confirmed booking |
| Test steps | Open thread, send and retry via emulated/fixture transport, load history |
| Expected result | Own thread reads and safe retry preserve one effect |
| Actual result | 6 pass/0 fail/0 skip [backend-portable]; 5 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/test/booking-communication.test.ts:28; apps/mobile/test/booking_communication_ui_test.dart:37 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
