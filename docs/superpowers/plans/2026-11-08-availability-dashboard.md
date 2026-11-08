# Coach Availability dashboard

Owner supplied the complete implementation specification and prioritizes UI/UX. Preserve current backend/contracts, weekly single-window model, conflict/idempotent retry guards and organization/account boundaries.

- [x] RED→GREEN: copy one weekday's supported active/off configuration to selected weekdays atomically, without changing limits/exceptions or persisting before Save.
- [x] Compact date range/horizontally scrolling day rail and selected-day card with source, working hours, breaks, capacity, quick weekly/date/time-off edits and concise booking distinction. Compact weekly rows and 30-minute-validated time picker.
- [x] Fixed SafeArea save bar for dirty/saving/uncertain drafts, accurate save/error/retry/conflict feedback; Done means local draft only. Protect both back and Coach bottom-tab navigation, keep one-off saves independent.
- [x] Collapsible Time Off/Booking Limits/Google details, real Google summary, trusted branch names where available, bounded loading/error states, clean typography and 320/360px at200% text.
- [x] Affected controller/widget/route/conflict/account tests, render verification, analysis, one final independent review, isolated debug APK, authorized idle-device update if safe, scoped operational notes and commit. No backend, payment or Member/Admin behavior changes.


Completed 9 November 2026. Structure: compact organization-date range/horizontal rail → selected-day source/windows/breaks/capacity/quick actions → weekly rows → collapsible Time Off and Booking Limits → compact real Google status. SafeArea bottom save bar appears only for dirty/saving/uncertain drafts. Done edits the local draft; Save Changes uses existing authoritative save/readback. Failed/uncertain saves preserve request identity; tab and back navigation protect unsaved work. Weekly editing uses a30-minute validated time picker and copies supported active/off configuration to selected weekdays without multi-shift model changes. Explicit setup distinguishes missing configuration from Off. One-off dates remain independently saved, with trusted branch labels and selected-date time-off prefill.

Final independent source review found one important stale-preview error issue. Initial-success→failed-refresh and saved-roster→failed-preview-readback tests reproduced it RED; explicit cached-data warning/retry and distinct saved-vs-preview failure feedback now pass GREEN.39 affected Mobile tests across7 files and7 shared Google tests pass. Scoped analysis is clean.20 actual-font renders cover320/360px at100/200% text for overview, weekly editor, sticky save, date editor and quick settings; large-text weekly controls stack without shrinking labels.

Isolated Android Debug APK built from HEAD plus only the10 scoped source files and6 scoped test/support files; all other committed bytes and dependency lock verified unchanged. APK: build/availability-dashboard-20261108/gainpath-availability-dashboard-debug.apk. Phone was Dozing/locked at inspection, so not installed; physical interaction and live Google/backend acceptance remain unverified. No backend/Rules/index changes or product data writes. Booking/hold/capacity rules, conflict validation, reservations and gym-managed Google actions remain unchanged. Unknown branch names retain explicit IDs until an authorized name is available; no names or bookable slots are invented.

Source files:
- apps/mobile/lib/app/di/coach_profile_factory.dart
- apps/mobile/lib/app/shells/coach_shell.dart
- apps/mobile/lib/features/coaching/presentation/coach/availability_page.dart
- apps/mobile/lib/features/coaching/presentation/coach/availability_screens.dart
- apps/mobile/lib/features/coaching/presentation/coach/coach_roster_editor.dart
- apps/mobile/lib/features/coaching/presentation/coach/coach_specific_date_sheet.dart
- apps/mobile/lib/features/coaching/presentation/coach/coach_time_exception_sheet.dart
- apps/mobile/lib/features/coaching/presentation/coach/weekly_hours_sheet.dart
- apps/mobile/lib/features/coaching/presentation/coach/availability_navigation_scope.dart
- packages/gainpath_ui/lib/src/google_integration_panel.dart

Tests/support:
- apps/mobile/test/availability_dashboard_test.dart
- apps/mobile/test/availability_dashboard_render_test.dart
- apps/mobile/test/support/availability_dashboard_fixture.dart
- apps/mobile/test/coach_roster_ui_test.dart
- apps/mobile/test/coach_availability_flow_test.dart
- packages/gainpath_ui/test/google_integration_panel_test.dart
