# Coach roster manual refresh and session summaries

Owner request: remove Coach30second auto-sync and the top technical text; show date/time inside summary cards; improve long History browsing.

Design: retain current dashboard and History range. Manual pull-to-refresh only, existing action-driven refresh retained. Pin Schedule/History tabs and horizontal History status chips so All remains reachable while scrolling. Show organization-local date with year plus start/end labels inside every appointment summary. Preserve pagination and current newest-first ordering of loaded History rows; do not claim complete/global history or expand backend scope.

- [x] Regression tests RED→GREEN for no Coach poll/subscription/metadata, awaited pull refresh, summary date/time and pinned All after a long scroll.
- [x] Implement scoped live view and roster refinements, preserving Member behavior and authorization.
- [x] Focused checks/analysis, small/large text renders, final review, isolated APK and exact-scope commit. No backend changes or production-data writes.

History advice: current default is past 30 days with20records/page. Additional server-backed date selection/date grouping and genuine newest-first backend pagination are separate enhancements; All means all statuses within the loaded range.


Verification: 111 affected Mobile tests across 21 files pass. Eight fixture renders cover History at 320/360px and 100%/200% text before/after long scrolling; pinned All remains hit-testable. Large-text action rows wrap; completed persisted sessions show View notes rather than relying on absent legacy note text. Scoped analysis has no errors/warnings and eight unchanged baseline style infos. Final source review found no blockers.

The isolated APK contains HEAD plus only two roster/live-view source files and the two new tests; unchanged dependency lock and source allowlist verified. APK: build/coach-roster-summary-20261108/gainpath-coach-roster-debug.apk. Installed and launched in place on authorized idle Xiaomi 7c4cbff; signer/installed APK hash match, all 59 saved app files are byte-identical before launch, and previous APK/data backup is retained. Automated post-install tab navigation was denied by Android INJECT_EVENTS permission; no security-setting change or workaround was attempted. Installation is verified, but Roster physical interaction acceptance remains pending. No backend deployment or production booking/payment/message writes.

Current History is approximately the past 30 days, with at most 20 records per server page; All means all statuses within the loaded range. The UI already reverses loaded History rows, but genuine global newest-first pagination requires a backend query change. Suggested next increment: history date/day/week controls and date-group headings, plus a server-side descending cursor. No wider-history or global search claim is made.
