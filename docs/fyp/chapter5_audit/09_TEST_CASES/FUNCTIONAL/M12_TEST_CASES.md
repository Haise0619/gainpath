# M12 · Admin dashboard and reports

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M12-01 · Operational totals and reporting filters

| Field | Evidence |
| --- | --- |
| Test case ID | F-M12-01 |
| Test case name | Operational totals and reporting filters |
| Module | M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Operational totals and reporting filters |
| Preconditions | Synthetic roles, bookings and commerce projections |
| Test data | Synthetic roles, bookings and commerce projections |
| Test steps | Compare dashboard/analytics results with fixture data and change dates/filters |
| Expected result | Aggregate totals match expected projection and filters, preserve relevant provenance |
| Actual result | 11 pass/0 fail/0 skip [admin-portable]; 13 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/admin_web/test/business_dashboard_test.dart:107; functions/test/admin-reporting.test.ts:13 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M12-02 · Branch and financial reporting

| Field | Evidence |
| --- | --- |
| Test case ID | F-M12-02 |
| Test case name | Branch and financial reporting |
| Module | M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Branch and financial reporting |
| Preconditions | Fixtures with separate branch/organization and payment states |
| Test data | Fixtures with separate branch/organization and payment states |
| Test steps | Open branch and organization scopes, compare exports/projection rows |
| Expected result | Each scope shows the intended totals, with settlement and recorded values distinct |
| Actual result | 3 pass/0 fail/0 skip [admin-portable]; 5 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/admin_web/test/admin_reporting_regression_test.dart:21; functions/test/unified-admin-reporting.test.ts:5 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M12-03 · Automation and check-in metrics

| Field | Evidence |
| --- | --- |
| Test case ID | F-M12-03 |
| Test case name | Automation and check-in metrics |
| Module | M12 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Automation and check-in metrics |
| Preconditions | Check-in/report fixture, observed narrow and large-text content |
| Test data | Check-in/report fixture, observed narrow and large-text content |
| Test steps | Load chart and data, change selection and simulate transient error |
| Expected result | UI presents relevant measures and controls responsive state predictably |
| Actual result | 4 pass/0 fail/0 skip [admin-portable]; 17 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/admin-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/admin_web/test/admin_check_in_reporting_ui_test.dart:52; functions/test/admin-check-in-reporting.test.ts:18 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
