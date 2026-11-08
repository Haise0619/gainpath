# Coach session status presentation and lifecycle

Owner approved status optimization after the Confirmed-in-History explanation.

One presentation policy derives Confirmed (future), In progress (start <= server time < end), Awaiting notes (confirmed and ended), and authoritative Completed/Cancelled/Expired/Refunded. Pending holds whose deadline elapsed display Hold time elapsed pending server resolution, never fabricated Expired. No stored status/payment/attendance rewrites. Existing notes publication remains the only completion operation; cancellation is available only before confirmed start, matching backend rules.

- [x] Add boundary, terminal precedence, filter/action and card/detail consistency regressions RED→GREEN.
- [x] Shared Coach presentation helper for badges/colors/descriptions/history/filters/actions. Add Awaiting notes, Hold time elapsed and Refunded categories. Completed notes are read-only. Payment status is never inferred from booking status.
- [x] Update local display at known start/end/hold boundaries using a server-anchored local clock, without network polling; refresh resynchronizes. Use the same clock in list and details.
- [x] Run affected tests, source analysis, narrow/large text fixture renders and final source review; isolated APK and exact-scope commit. Preserve unrelated work and Member-specific terminology. No backend deployment required; existing completion/cancellation/expiry backend guards stay authoritative.


Verification: 80 affected Mobile tests across 13 files pass; scoped analysis reports no issues. Eight history fixture renders cover 320/360px at 100/200% text and long-list controls. Final independent review found one important detail-header overflow: four 320/360px 200% regressions reproduced it RED; wrapping status/duration badges fixes it GREEN and the full 80-test affected suite passes. Boundary, terminal precedence, exact history filtering, action gates and local clock disposal are covered. Backend completion/cancellation guards were inspected and remain unchanged; no backend deployment or stored status rewrite.

The isolated APK contains HEAD plus only four scoped source files and three new test files; dependency lock and all other committed files match. APK: build/coach-status-lifecycle-20261108/gainpath-coach-status-debug.apk. Installed/launched in place on authorized idle Xiaomi 7c4cbff account screen; matching signer and installed APK hash verified, all 59 saved app files unchanged before launch, previous APK/data retained. Actual roster/detail interaction and device suspend/resume timing remain unverified. Android automated input is unavailable from the earlier INJECT_EVENTS denial; no attempt to bypass it. Existing History date/page limits remain unchanged.
