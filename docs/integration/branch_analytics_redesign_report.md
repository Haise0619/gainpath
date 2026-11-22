# GainPath Admin Portal — Multi-Branch Performance Dashboard Redesign Report

## 1. Executive Summary

This report documents the architectural redesign and implementation of the GainPath **Branch Analytics** module (`ReportsCategory.branches`) in `apps/admin_web`. Inspired by modern multi-location fitness platforms (EGYM Business Suite Analytics, Virtuagym Multi-Club Management, Mindbody Multi-Location Reporting, and Microsoft Power BI guidelines), the redesign transforms the previous developer-oriented dialog and flat 12-item metric grid into a structured, responsive, and production-grade **Multi-Branch Performance Dashboard**.

The implementation preserves 100% of underlying business data sources, aggregation algorithms, date filtering semantics, branch scopes, and CSV export structures (`gainpath-branch-report.csv`), while resolving visual clutter, unstyled charts, dark axis lines, generic tooltip series labels, and coach attribution ambiguity.

---

## 2. Key UI/UX Improvements Completed

### 2.1 Re-Architected Information Hierarchy
The previous implementation mixed 12+ metrics with disparate temporalities (current facility snapshots versus date-scoped event aggregations) in a flat grid. The redesign introduces 6 cohesive sections:

1. **Branch Overview (Current Census & Capacity)**:
   - 3 primary KPI cards with 40×40 icon containers, bold values, and context notes:
     - `Active branches · current`: highlighted with primary accent border and background tint.
     - `Home branch members · current`: registered home facility members.
     - `Assigned coaches · current`: distinct active coach assignments across the organization.
   - For single-branch drill-down views, 3 dedicated equipment inventory metric cards seamlessly expand:
     - `Equipment units · current` (Total catalog inventory)
     - `Usable units · current` (Ready for training)
     - `Maintenance units · current` (Under repair/service)

2. **Location Performance & Benchmarks (Comparison Charts)**:
   - 4 independent chart cards organized in a responsive 2-column desktop grid (collapsing to 1 column on narrower viewports):
     - `Home Branch Members` (Horizontal BarSeries, Primary Purple palette).
     - `Recorded Gym Visits` (Horizontal BarSeries, Indigo palette).
     - `Coach Bookings` (Horizontal BarSeries, Blue palette).
     - `Confirmed Sandbox Receipts (RM)` (Horizontal BarSeries, Emerald palette with currency formatting).
   - Removed dark Cartesian axis borders (`plotAreaBorderWidth: 0`), set hairline gridlines (`MajorGridLines(width: 0.6, color: AppColors.hairline)`), and eliminated generic `"Series 0"` tooltips with explicit formatting (`format: isCurrency ? 'point.x: RM point.y' : 'point.x: point.y $unit'`).
   - Integer ticks on Y-axes (`decimalPlaces: 0` for counts) preventing confusing fractional ticks like `0.5`, `1.5`.

3. **Booking Activity**:
   - Dedicated section isolating appointment-related operational metrics:
     - `Bookings created`: appointments created within the selected date range.
     - `Completed sessions · appointment date`: scheduled appointments completed.
     - `Cancelled sessions · appointment date`: client or coach cancellations.

4. **Gym Visit Insights**:
   - Footfall and attendance monitoring section (active for non-unassigned scopes):
     - `Recorded gym visits`: total check-in scan count.
     - `Unique visiting members`: distinct member attendance count.
     - `Members with multiple visits`: repeat attendance count.
     - `Peak recorded hours · MYT`: formatted busiest facility check-in hours in Malaysia Time (e.g., `17:00 · 18:00 · 19:00`).

5. **Financial Coverage & Sandbox Transparency**:
   - Separates synthetic test transactions from non-existent live processor settlements:
     - `Confirmed sandbox coaching receipts · RM`: highlighted currency card showing simulated test payments.
     - `Actual coaching revenue · RM`: clear, professional `Unavailable` card explaining that actual coaching settlement is not integrated into this sandbox environment (never misleadingly displayed as `RM 0.00`).
     - Preserves the disclaimer notice: *"Membership revenue remains in the organization-wide report."*

6. **Branch Comparison Table**:
   - Clean, full-width tabular view with `AppColors.surface` background, rounded corners (14px), and subtle `AppColors.hairline` borders.
   - Preserves all 9 columns: `Branch`, `Status` (Active/Inactive badge), `Home branch members`, `Assigned coaches`, `Recorded gym visits`, `Coach bookings`, `Completed sessions`, `Confirmed sandbox receipts (RM)` (with formatted currency), and `Action`.
   - `View details` button on each branch row enables instant drill-down to the specific branch dashboard.

7. **Daily Activity Trends (Single-Branch View)**:
   - When a specific branch is selected, renders daily trend line charts (Visits, Bookings, Coaching Receipts) with smooth lines, circular data markers, and clean date axes.
   - Includes an interactive Daily Activity Log table with pagination (`Show more dates`).

8. **Definitions & Coverage Disclosure**:
   - Standardized expandable panel explaining Malaysia Time (UTC+08:00), differentiating current census snapshot metrics from date-scoped activity, and providing clear guidance on multi-branch coach attribution.

### 2.2 Refined Controls & Toolbar
- **Branch Scope Selector**: Replaced the default underlined `DropdownButton` with a pill-shaped container (`height: 32`, `borderRadius: 999`, subtle border) integrated directly into `AnalyticsDateRangeToolbar`.
- **Top Action Bar**: Displays active Malaysia Time range badge and a prominent primary button for CSV export (`Export branch CSV`).

---

## 3. Investigation: Assigned Coaches Attribution (3 vs 4)

In multi-branch fitness organizations, personal trainers and coaches can be licensed or assigned to train clients across multiple physical facilities.
- **Observed Data**: In the GainPath database, Coach Jackson is assigned to both `Main Branch` and `GainPath 2`. Two other coaches are assigned strictly to `Main Branch`.
- **Branch Rows**:
  - `Main Branch` assigned coaches = 3
  - `GainPath 2` assigned coaches = 1
  - Sum of branch rows = 3 + 1 = 4.
- **Organization-Level Metric**: The backend computes `assignedCoaches` as a **distinct set of unique coaches** (`{Jackson, Coach B, Coach C}.length = 3`).
- **Resolution**:
  - The organization-level overview card correctly reports `3` distinct coaches and must never be naively summed from table rows.
  - The Definitions & Coverage disclosure explicitly documents:
    *"Coaches may be assigned to multiple branches; organization-level assigned coach totals represent distinct active coaches, not a naive sum of branch rows."*

---

## 4. Visual Verification Screenshots

````carousel
![Branch Overview & Header (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_overview_1440.png)
<!-- slide -->
![Location Performance Comparison Charts (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_comparison_1440.png)
<!-- slide -->
![Booking Activity Section (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_booking_activity_1440.png)
<!-- slide -->
![Gym Visit Insights Section (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_gym_visits_1440.png)
<!-- slide -->
![Financial Coverage & Receipts Section (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_financial_1440.png)
<!-- slide -->
![Branch Comparison Table (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_table_1440.png)
<!-- slide -->
![Single Branch Drill-Down View (1440px)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/branch_analytics_single_branch_1440.png)
````

---

## 5. Mandatory Feature-Parity Audit

| Original Metric / Feature | Original Data Source | Original Aggregation | Original Filter Behavior | New UI Location | Export Behavior | Verification Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Active branches · current** | `result['activeBranches']` | Exact backend count of active status branches | Current snapshot (`scope == 'all'`) | Section 1: Branch Overview KPI card 1 | Preserved in `gainpath-branch-report.csv` metadata rows | `branch_analytics_redesign_render_test.dart` passes |
| **Home branch members · current** | `result['homeMembers']` | Count of members registered with branch as home/primary | Current snapshot | Section 1: Branch Overview KPI card 2 | Preserved in CSV metadata rows & comparison rows | Tested at 48 members (`render_test.dart`) |
| **Assigned coaches · current** | `result['assignedCoaches']` | Distinct count of coaches assigned to branch/org | Current snapshot | Section 1: Branch Overview KPI card 3 | Preserved in CSV metadata rows & comparison rows | Tested at 3 coaches (`render_test.dart`) |
| **Equipment units · current** | `result['equipmentUnits']` | Sum of equipment quantities from inventory | Current snapshot (single branch view) | Section 1: Equipment Inventory row | Preserved in CSV metadata rows | Tested at 45 units in Single Branch test |
| **Usable units · current** | `result['usableUnits']` | `equipmentUnits - maintenanceUnits` | Current snapshot (single branch view) | Section 1: Equipment Inventory row | Preserved in CSV metadata rows | Tested at 42 units in Single Branch test |
| **Maintenance units · current** | `result['maintenanceUnits']` | Sum of maintenance quantities | Current snapshot (single branch view) | Section 1: Equipment Inventory row | Preserved in CSV metadata rows | Tested at 3 units in Single Branch test |
| **Bookings created** | `result['bookingsCreated']` | Count of appointments created | Date-range filtered | Section 3: Booking Activity KPI card 1 | Preserved in CSV metadata rows & daily table | Tested at 28 bookings (`render_test.dart`) |
| **Completed sessions** | `result['completedSessions']` | Count of appointments with `status == 'completed'` by scheduled start date | Date-range filtered | Section 3: Booking Activity KPI card 2 | Preserved in CSV metadata rows & comparison table | Tested at 22 sessions (`render_test.dart`) |
| **Cancelled sessions** | `result['cancelledSessions']` | Count of cancelled appointments by scheduled start date | Date-range filtered | Section 3: Booking Activity KPI card 3 | Preserved in CSV metadata rows & daily table | Tested at 4 cancellations (`render_test.dart`) |
| **Confirmed sandbox coaching receipts** | `result['coachingMinor']` | Sum of cleared sandbox transactions in minor units (`coachingMinor / 100`) | Date-range filtered | Section 5: Financial Coverage (highlighted RM card) | Preserved in CSV metadata rows, comparison table & daily table | Tested at RM 2400.00 (`render_test.dart`) |
| **Actual coaching revenue** | `result['actualCoachingMinor']` | `null` (unavailable in sandbox) | Unavailable indicator | Section 5: Financial Coverage (informative card) | Preserved in CSV metadata rows | Tested unavailable card (`render_test.dart`) |
| **Recorded gym visits** | `result['gymVisits']` | Count of QR check-in records | Date-range filtered | Section 4: Gym Visit Insights KPI card 1 | Preserved in CSV metadata rows, comparison table & daily table | Tested at 185 visits (`render_test.dart`) |
| **Unique visiting members** | `result['uniqueVisitors']` | Distinct count of member IDs in visit records | Date-range filtered | Section 4: Gym Visit Insights KPI card 2 | Preserved in CSV metadata rows | Tested at 42 unique members (`render_test.dart`) |
| **Members with multiple visits** | `result['repeatVisitors']` | Count of members with visit count > 1 | Date-range filtered | Section 4: Gym Visit Insights KPI card 3 | Preserved in CSV metadata rows | Tested at 29 repeat members (`render_test.dart`) |
| **Peak recorded hours · MYT** | `result['peakHours']` | List of top hours (`HH:00`) in UTC+08:00 | Date-range filtered | Section 4: Gym Visit Insights KPI card 4 | Preserved in CSV metadata rows | Formatted as `17:00 · 18:00 · 19:00` |
| **Home members comparison chart** | `branches[i]['homeMembers']` | Per-branch member census | Current snapshot | Section 2: Chart Card 1 | Preserved in CSV branch table | Chart verified with integer axis ticks |
| **Visits comparison chart** | `branches[i]['gymVisits']` | Per-branch visit count | Date-range filtered | Section 2: Chart Card 2 | Preserved in CSV branch table | Chart verified with indigo styling |
| **Bookings comparison chart** | `branches[i]['bookingsCreated']` | Per-branch booking count | Date-range filtered | Section 2: Chart Card 3 | Preserved in CSV branch table | Chart verified with blue styling |
| **Receipts comparison chart** | `branches[i]['coachingMinor']` | Per-branch receipts in MYR | Date-range filtered | Section 2: Chart Card 4 | Preserved in CSV branch table | Chart verified with RM currency formatting |
| **Branch comparison table** | `branches` array | Per-branch operational stats | Mixed current & date-range | Section 6: Branch Comparison Table | Preserved in CSV branch table | Verified columns, status badges & `View details` |
| **Daily Activity Trends** | `daily` array | Daily timeseries records | Date-range filtered | Section 7: Daily Activity (single branch view) | Preserved in CSV daily log | Line charts & DataTable with pagination pass |
| **CSV Export** | `gainpath-branch-report.csv` | Full multi-table structured CSV | Preserved | Top action bar export button | Exact filename and schema preserved | `branch_report_dialog_test.dart` & navigation pass |

---

## 6. Automated Verification Results

### 6.1 Scoped Static Analysis
```
$ flutter analyze lib/features/analytics/presentation/admin/branch_report_dialog.dart lib/features/analytics/presentation/admin/reports_screen.dart
Analyzing 2 items...
No issues found! (ran in 1.4s)
```

### 6.2 Unit and Widget Test Suites
```
$ flutter test test/branch_report_dialog_test.dart test/branch_analytics_redesign_render_test.dart test/reports_navigation_test.dart
00:00 +0: branch_report_dialog_test: historical branch report keeps the selected date range
00:00 +1: branch_analytics_redesign_render_test: Render Multi-Branch Performance Dashboard at 1440 and capture verification PNGs
00:01 +2: branch_analytics_redesign_render_test: Render Single Branch view with equipment units and daily activity trends
00:01 +3: reports_navigation_test: branch scope belongs only to Branch Analytics
00:02 +4: reports_navigation_test: returning to same category retains fresh workouts and refreshes expired data
00:02 +5: reports_navigation_test: URL changes retain one Reports instance through direct entry and history
00:04 +6: reports_navigation_test: Reports fits 1440.0 pixels at 1.0 text scale
00:05 +7: reports_navigation_test: Reports fits 1440.0 pixels at 2.0 text scale
00:05 +8: reports_navigation_test: Reports fits 1024.0 pixels at 1.0 text scale
00:05 +9: reports_navigation_test: Reports fits 1024.0 pixels at 2.0 text scale
00:06 +10: reports_navigation_test: Reports fits 768.0 pixels at 1.0 text scale
00:06 +11: reports_navigation_test: Reports fits 768.0 pixels at 2.0 text scale
00:06 +12: reports_navigation_test: Reports sidebar opens Overview and selects Fitness without hero tabs
00:07 +13: All tests passed!
```

### 6.3 Web Release Compilation
```
$ flutter build web --no-tree-shake-icons
Compiling lib\main.dart for the Web...                             70.4s
√ Built build\web
```

---

## 7. Modified Files

1. [branch_report_dialog.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/analytics/presentation/admin/branch_report_dialog.dart): Complete Multi-Branch Performance Dashboard redesign with 6 structured sections, 4 styled Syncfusion comparison charts, responsive layout, dedicated financial coverage, single-branch daily activity trends, and expandable definitions.
2. [reports_screen.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/analytics/presentation/admin/reports_screen.dart): Updated `_buildBranchAnalytics()` to use standardized `_header()` and refined `_branchSelector()` with pill-styled container matching `AnalyticsDateRangeToolbar`.
3. [branch_analytics_redesign_render_test.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/test/branch_analytics_redesign_render_test.dart): New comprehensive test suite asserting all dashboard sections, single-branch drill-down, and generating verification screenshots.
