# Member booking history and coach information

Implemented 8 November 2026 against b78fde8e7be86b5c1d7164e2380a804ee01a4e0a.

Old confirmed bookings stayed in Upcoming because the presentation checked status without the server clock. The live projection also discarded coach identity, while the existing name reader was only used for chat.

## Result

- Confirmed sessions whose absolute end time has passed move to History / Past with **Session ended**. Details explain that completion has not been recorded and retain the source status. No booking records are rewritten.
- An unpaid hold whose deadline passed displays **Hold time elapsed** pending server resolution. Authoritative **Expired**, **Cancelled**, **Completed**, and **Refunded** remain distinct. In-progress and future confirmed sessions remain Upcoming.
- History categories use one horizontal scroll row without wrapping, including at large text sizes.
- Cards show the authorized published coach name and photo, date with year, duration, fee, and clear status. Details receive the same public information and update if opened before the lookup finishes. Reads are deduplicated, bounded to four concurrent requests, cached briefly, and guarded against account/scope drift. Missing or withdrawn public profiles have honest unavailable states. These are current published details, not an invented historical snapshot.
- Details remove invented certification and payment-success claims; the existing payment-details flow remains authoritative. Past/elapsed sessions do not offer inappropriate management actions. Existing member typography, spacing, purple palette and rounded controls remain consistent.
- Unresolved branch identifiers are not displayed as human location names. The existing fallback is shown until a trusted branch label is available.

## Verification

56 affected Flutter tests pass across ten files. Regression tests include the original past-confirmed issue, exact end boundary, in-progress sessions, elapsed and expired holds, refunded records, unavailable/failed coach reads, late account results, and opening details during a pending lookup. The lookup race and wrapping categories were reproduced before their fixes.

Twelve fixture PNGs cover history/details/coach sections at 320/360px and 100/200% text. Layouts were inspected; these are widget fixtures, not signed-in device captures. Scoped analysis has zero errors/warnings and eight pre-existing interpolation style infos. Final source review found no remaining actionable issues.

Evidence: `build/booking-history-coach-fix-20261108/`. The isolated Android debug build uses HEAD plus only this task's seven source files and six tests, excluding unrelated dirty Admin/workout changes. APK: `build/booking-history-coach-fix-20261108/gainpath-booking-history-coach-debug.apk`; build/hash/allowlist results are recorded in `verification.json`.

No backend deployment, financial/attendance state rewrite, or APK installation is part of this change. Signed-in physical-device acceptance remains pending.
