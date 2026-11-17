# Reports navigation and UI density — 17 November 2026

Implemented against the owner's authenticated Admin Web screenshots. This is a frontend closeout: no Functions deployment, Firestore document change or Rules change was performed in this round.

## Delivered

- Existing Sidebar Reports group now opens Overview and exposes Overview, Financial, Fitness, Coaching and Engagement with the same submenu styling as Payments/Content. The existing independently scrolling navigation and fixed bottom Admin profile remain.
- Report URLs are `/#/reports/overview`, `/financial`, `/fitness`, `/coaching`, `/engagement` (each suffix follows `/#/reports`). `/#/reports` defaults to Overview. Other Sidebar destinations use recoverable `/#/console/<destination>` history entries. Authentication still owns access to the console.
- One retained ReportsScreen instance owns queries, section state, scroll positions, lazy sections and shared workout data. Returning from another Sidebar area checks freshness even when the category is unchanged. Fresh returns reuse data; expired returns revalidate after 30 seconds.
- Removed the duplicate Reports hero, icon, subtitle and horizontal tabs. Each category has one short Analytics title, category breadcrumb and compact date/Refresh/Export toolbar. Reporting coverage and the recorded-revenue definition are collapsed together.
- Balanced responsive metric rows replace fixed-width orphan cards. Workout cards use the existing compact StatTile style. Short workout date labels retain full source dates in tooltips and CSV. Exercise dropdowns use readable names; compatible score-group values are unchanged, with full scoring/model identity available in Scoring details and CSV.
- Toolbar CSV exports business categories, current workout results, or an explicitly requested engagement read. Existing detailed section exports remain available. Engagement export discards a result if the date query or category changed while it was loading; the production gateway still verifies the current session.
- Fixed the existing Financial empty-state text overflow at 768px/200% by allowing constrained empty-state content to scroll.

The commit also records the already implemented, previously uncommitted frontend workout summary/score-band model dependencies needed by these report components. No backend files are included. Pre-existing Sidebar logo changes and unrelated Admin/Mobile edits are intentionally left in the working tree.

## Verification

- 74 Admin Reporting and Sidebar tests passed. This includes parser/scope checks, loading/error/retry, date changes, lazy sections, CSV data and retained request behavior.
- Five categories tested at 1440px, 1024px and 768px, each at 100% and 200% Flutter text scale.
- URL/category regression retains the same ReportsScreen state through direct category changes and leaving/returning to another console destination.
- Deterministic cache test: initial workout reads 1; fresh same-category reactivation remains 1; reactivation after 31 seconds becomes 2. This is a test-clock result, not a real Firebase latency measurement.
- Scoped Dart analysis: no issues found.
- Admin Web Release build: success; final compilation 38.1 seconds. Existing build warning about an absent CupertinoIcons font remains; MaterialIcons are bundled successfully.
- Independent staged-code review: no blocking correctness/security findings after history and reactivation fixes.

Logs and local build: `build/reports-navigation-20261117/`. Release output: `main-web/`. Build uses the existing private local Firebase/App Check file and recommendations flag, with token output redacted. No credentials are included in Git.

## Authenticated browser evidence

The owner restarted and signed into the real canonical Admin at localhost:7361. Actual Flutter Web screenshots were saved under:

- `build/reports-navigation-20261117/screenshots/live-overview-wide.jpg`
- `build/reports-navigation-20261117/screenshots/live-sidebar-overview.jpg`
- `build/reports-navigation-20261117/screenshots/live-fitness-wide.jpg`
- `build/reports-navigation-20261117/screenshots/live-financial-wide.jpg`

These are authenticated browser captures, not fixtures. Observed real totals: 23 active Members, 9 Coaches, 119 workout observations, 7 completed workout attempts and MYR 5,972 recorded revenue. This recorded value includes scenario entries; it is not settled cash. Sidebar scrolling preserved the fixed profile; Overview/Fitness/Financial category selection, breadcrumbs, active styling and browser Back/Forward were observed. Captures are at the maximized desktop window (1536px outer width), separate from the exact-width automated checks. They precede the final Toolbar label change to Export CSV and the final non-Reports history edge fixes.

## Performance impact and owner handoff

No new dependency, background reporting request, animation or backend work is introduced by the navigation/layout. Direct Fitness/Engagement entry loads only its required report family. Existing 30-second reuse is covered above. Engagement toolbar export performs an explicit read when clicked. No new real-network before/after latency benchmark is claimed for this UI-only round.

At the owner's request, browser automation stopped and further UI acceptance belongs to the owner. Before checking the final source, use Flutter Hot Restart once with the existing main.dart entrypoint and additional run args unchanged. Check:

1. Reports parent opens Overview; each submenu and breadcrumb matches the URL. Back/Forward, refresh and direct category URLs work after authentication.
2. At 1440/1024/768 and large text, inspect the drawer/Sidebar, fixed profile, KPI rows, tables, chart legends/tooltips and readable score dropdowns.
3. Select dates, switch categories and return: filters/sorts/scroll remain; Refresh reloads; fresh returns reuse results. Download toolbar and detailed CSVs for the desired category.
4. Confirm real Empty/Partial/Error cases when available; no synthetic source state was written to Firebase to force them.

The isolated local release preview server uses localhost:7363; the Android Studio localhost:7361 run was not replaced. The final browser screenshots are of 7361.
