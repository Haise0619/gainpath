# ADD · Equipment, groups, notices and operations

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-ADD-01 · Equipment scanner recognition flow

| Field | Evidence |
| --- | --- |
| Test case ID | F-ADD-01 |
| Test case name | Equipment scanner recognition flow |
| Module | ADD |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Equipment scanner recognition flow |
| Preconditions | TD-EQUIP, valid and invalid response fixture |
| Test data | TD-EQUIP, valid and invalid response fixture |
| Test steps | Choose permitted image, simulate supported match and unknown or invalid response |
| Expected result | Provides matched tutorial/unknown result and handles provider errors securely |
| Actual result | 23 pass/0 fail/0 skip [mobile-portable]; 24 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/equipment_scanner_test.dart:136; functions/test/equipment-scanner.test.ts:22 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-ADD-02 · Group class, capacity and visibility

| Field | Evidence |
| --- | --- |
| Test case ID | F-ADD-02 |
| Test case name | Group class, capacity and visibility |
| Module | ADD |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Group class, capacity and visibility |
| Preconditions | Synthetic session capacity and group roster fixtures |
| Test data | Synthetic session capacity and group roster fixtures |
| Test steps | Publish/open session, exercise Member registration and capacity boundary |
| Expected result | Eligible class/roster, registration state and last-place rule are correct |
| Actual result | 6 pass/0 fail/0 skip [admin-portable]; 0 pass/0 fail/1 skip [backend-portable] |
| Status | Not Executed |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/admin_web/test/group_classes_widget_test.dart:76; functions/test/group-classes-emulator.test.ts:12 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-ADD-03 · Scoped announcement and notification

| Field | Evidence |
| --- | --- |
| Test case ID | F-ADD-03 |
| Test case name | Scoped announcement and notification |
| Module | ADD |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Scoped announcement and notification |
| Preconditions | Synthetic published content and Member branch membership |
| Test data | Synthetic published content and Member branch membership |
| Test steps | Render announcement in Admin/Member and mark eligible Member alert read |
| Expected result | Only eligible audience sees intended publication and read state |
| Actual result | 6 pass/0 fail/0 skip [admin-portable]; 6 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | apps/admin_web/test/announcements_test.dart:201; apps/mobile/test/member_announcements_test.dart:59 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-ADD-04 · Operations calendar and provider integration states

| Field | Evidence |
| --- | --- |
| Test case ID | F-ADD-04 |
| Test case name | Operations calendar and provider integration states |
| Module | ADD |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Operations calendar and provider integration states |
| Preconditions | Staged mixed events, Provider connection and disabled state |
| Test data | Staged mixed events, Provider connection and disabled state |
| Test steps | Change day/window and inspect Member booking and event projection plus integration status |
| Expected result | Scope and no-data/error states remain truthful |
| Actual result | 8 pass/0 fail/1 skip [admin-portable]; 1 pass/0 fail/0 skip [admin-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/admin-portable.txt |
| Source reference | apps/admin_web/test/operations_calendar_screen_test.dart:293; apps/admin_web/test/google_integration_settings_test.dart:8 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
