# M08 · Coach account and profile

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M08-01 · Profile, phone and photo state

| Field | Evidence |
| --- | --- |
| Test case ID | F-M08-01 |
| Test case name | Profile, phone and photo state |
| Module | M08 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Profile, phone and photo state |
| Preconditions | TD-PROFILE current Coach identity |
| Test data | TD-PROFILE current Coach identity |
| Test steps | Edit profile and invalid phone, reopen and compare fields |
| Expected result | Only valid edits for authorized Coach are accepted, display recomposes correctly |
| Actual result | 2 pass/0 fail/0 skip [mobile-portable]; 6 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/coach_profile_state_test.dart:49; apps/mobile/test/coach_phone_settings_test.dart:74 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M08-02 · Certification review and member projection

| Field | Evidence |
| --- | --- |
| Test case ID | F-M08-02 |
| Test case name | Certification review and member projection |
| Module | M08 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Certification review and member projection |
| Preconditions | Staged draft and approved public record |
| Test data | Staged draft and approved public record |
| Test steps | Update profile/certification, approve via fixture and read as Member |
| Expected result | Public profile follows verification/publication state and excludes private data |
| Actual result | 22 pass/0 fail/0 skip [backend-portable]; 4 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/coach-profile.test.ts:22; functions/test/coach-public-profile.test.ts:11 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
