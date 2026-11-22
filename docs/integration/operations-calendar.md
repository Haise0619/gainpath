# Operations Calendar

The Admin console uses [Kalender 0.34.0](https://pub.dev/packages/kalender/versions/0.34.0) for its Month, Week and Day schedules. It runs on the existing Flutter 3.38.9 and Dart 3.10.8 toolchain. Kalender provides the month overflow, overlapping events, multiday lanes and timezone-aware ranges. GainPath renders the tiles, filters, daily agenda, details drawer and the Insights heatmap.

## Data and navigation

- The sidebar opens the current month across all branches. Branch overview opens the same screen with its branch selected. Branch names and inactive branch options come from the existing paginated directory.
- Month uses the visible grid, including adjacent days. Week uses a seven-day hourly timeline and Day uses a single day. Schedule and Insights share the selected day and branch. Schedule retains its view selection.
- Bookings use the stored booking branch and canonical status. A verified receipt can mark payment cleared. A checkout in progress or an unresolved payment remains distinct. View Booking opens the existing Admin booking presentation focused on the original record. View Coach opens Coach Management.
- Availability uses published coaches, active assigned branches and the existing week, dated override and exception resolver. Existing Schedule Management receives the coach, branch and requested date. When the selected date is historical, management opens today's schedule and the historical event remains visible in the Calendar.
- Announcements use the saved publication status, effective period and audience. Organization-wide notices appear once. Drafts and deactivated records are excluded. Timed notices spanning midnight retain their exact start and end in the details drawer. View Announcement opens the existing composer with its authorized edit baseline. The deployed Firestore rules include the branch audience fields.
- The Calendar performs reads. Changes are made through the respective management module. Closure announcements are informational.

## Insights

All dates are in Asia/Kuala_Lumpur (UTC+08:00). Range reads use inclusive starts and exclusive ends. The heatmap deep-links to Reports → Branches with the selected MYT day and its branch scope.

| Metric | Date and source | Intensity above zero |
| --- | --- | --- |
| Gym Visits | Successful branch QR check-ins by check-in date | 1–5, 6–15, 16–30, 31+ |
| Coach Bookings | Booking creation date across canonical statuses, matching Branch Reports | 1–2, 3–5, 6–10, 11+ |
| Confirmed Sandbox Receipts (MYR) | Verified coaching settlement dates for eligible cleared and fulfilled Sandbox transactions | RM0.01–100, RM100.01–300, RM300.01–600, RM600.01+ |

Future days and failed sources have unavailable values. Zero indicates that the source was read and has no qualifying records. Receipt values are reported in MYR from integer minor units.
Receipt range queries use the verification timestamp index. An old record missing that timestamp cannot be placed on a calendar day. The broader Branch Report can flag such a record for review.

## Query bounds and permissions

The Singapore App Check-protected `branchManagementCommand` serves `calendarEvents` and `calendarInsights`. It verifies email, active canonical Admin membership, organization, and any requested branch before publishing results. It rechecks authorization after reads. Event payloads exclude member identity and payment instrument data.

Each request covers at most 42 complete MYT days. Bookings and Insights transactions use indexed dates. The server reads only requested categories and batches coach assignments, profiles, schedules and payment projections. Individual reads have explicit record limits and report partial availability. The notification query retains long-running announcements by indexing expiry and post-filtering start. The client debounces requests for 100 ms, ignores stale responses and retains successful reads in a short-lived range and branch cache tied to the active Admin scope.

Availability looks ahead through the existing 30-day schedule horizon. Past availability needs a dated source because the weekly roster has no historical versions. The Calendar can still show historical bookings and announcements in their actual branches.

## Verification and acceptance

The release checks passed 37 affected Flutter tests (including captures), 353 backend tests and one Firestore Emulator integration test. The final calendar-only smoke passed 13 tests, and TypeScript passed. Dart analysis returned no errors or warnings and six existing style notices in coach scheduling.

- Flutter coverage includes Month, Week and Day range requests, overflow and agenda interactions, event and report links, rapid filter changes, cache reuse, responsive widths and MYT boundaries. A 420-event fixture month exercised repeated period changes, a branch switch and Month, Week and Day transitions with five bounded repository reads. This measures the Flutter test harness and does not establish live production latency. The twelve `fixture-*.png` captures are actual Flutter widget renderings with synthetic data, under `build/operations-calendar/`.
- Backend checks include the real Firestore Emulator with booking and roster projections, tenant rejection and parity with the existing Branch Report counts. The live function rejected requests lacking authentication, App Check or canonical Admin access. A demo identity lacked canonical Admin permission for the existing report. Positive production data acceptance requires the owner's canonical Admin session.
- The production source-only update is active on Singapore revision `branchmanagementcommand-00007-yel`. Source SHA-256 `83c6fd5cbe4d2fdf9f119e67b603da7f1b205959120fed41bd71b19f6c56c57f` matches the reviewed archive. Existing runtime and IAM were verified. The previous function and Admin build are available for rollback.
- The private Admin is serving release SHA-256 `076550fb8b3aa76a26df7c1dcf2aef14cf396ea0e2edff3edc506e3ff71daf9c` at port 7359. The clean build was captured from 471 source and configuration files. Local and backend evidence are under `build/operations-calendar/release/`.
- To accept using the canonical Admin account, open [local GainPath Admin](http://localhost:7359/). Open Operations Calendar from the sidebar and switch Month → Week → Day. Open a real booking, a published availability block and a published announcement. Then open a branch directly from its Branch overview, switch to Insights, select each metric and compare a past day using View Full Report.

See [Multi-branch management and reporting](multi-branch-gym-management-and-map-integration.md) for existing branch and reporting contracts.
