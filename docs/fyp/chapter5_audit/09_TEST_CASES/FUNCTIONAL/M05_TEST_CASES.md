# M05 · Member analytics and progress

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M05-01 · Report and History aggregation

| Field | Evidence |
| --- | --- |
| Test case ID | F-M05-01 |
| Test case name | Report and History aggregation |
| Module | M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Report and History aggregation |
| Preconditions | TD-TRAIN measured and partially measured workouts |
| Test data | TD-TRAIN measured and partially measured workouts |
| Test steps | Load report and filter by time/exercise, compare chart and history totals |
| Expected result | Only scoped eligible records contribute to the selected metric and filter |
| Actual result | 5 pass/0 fail/0 skip [mobile-portable]; 14 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/member_progress_cubit_test.dart:39; apps/mobile/test/training_report_consumer_render_test.dart:24 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M05-02 · No data, offline and local progress

| Field | Evidence |
| --- | --- |
| Test case ID | F-M05-02 |
| Test case name | No data, offline and local progress |
| Module | M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | No data, offline and local progress |
| Preconditions | Empty user and fixture with local progress |
| Test data | Empty user and fixture with local progress |
| Test steps | Open Progress while no cloud results are available and reload changed period |
| Expected result | Shows empty or local data truthfully and preserves separate sync state |
| Actual result | 9 pass/0 fail/0 skip [mobile-portable]; 0 pass/1 fail/0 skip [mobile-portable] |
| Status | Fail |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/local_member_progress_repository_test.dart:99; apps/mobile/test/member_local_progress_flow_test.dart:63 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M05-03 · Physical export and comparison

| Field | Evidence |
| --- | --- |
| Test case ID | F-M05-03 |
| Test case name | Physical export and comparison |
| Module | M05 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Physical export and comparison |
| Preconditions | Approved current APK, synthetic scoped report and labelled session |
| Test data | Approved current APK, synthetic scoped report and labelled session |
| Test steps | Open native PDF, compare totals and chart, exercise real filter exclusions and long pagination |
| Expected result | Export reconciles with filtered current report and displays correctly |
| Actual result | Historical 30 October limited native UAT; exact current build pending |
| Status | Not Executed |
| Environment | Proposed staged environment |
| Evidence | Source only |
| Source reference | Pending |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
