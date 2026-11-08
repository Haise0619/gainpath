# Member Coaches tabs and compact cards — 8 November 2026

Implemented the owner-approved reference refinement. The separate Admin plan remains deferred.

## Member experience

- Coaches header now has Find Coach and My Bookings segmented tabs beneath it. Header booking/sort icons and the introductory Find your coach/Compare expertise text are removed.
- My Bookings is real inline content, lazily built on first selection, with no route push or duplicate header. Both tabs retain state. Former-account content is hidden; a changed session scope resets the cached tab.
- The search field is compact, with a purple Filter and sort button beside it. The bottom sheet supports specialty, sorting, Reset, Apply and cancellation without applying drafts. An active-filter count is shown. Existing specialty chips remain nearby.
- Search/sort scope is explained inside the filter sheet instead of adding a large metadata block to the main page. Pagination and retries remain below results.
- Cards now retain only avatar, name, certification indicator, primary specialty, real rating with review count and real session price. Location, full specialization tags and certification explanations remain on the profile. Normal cards use a compact reference-like arrangement; narrow/large-text layouts stack instead of clipping.
- Styling reuses the member app's Barlow typography, purple primary controls, white/neutral surfaces, soft lavender accents, rounded shapes and existing booking widgets. No global theme, bottom navigation or unrelated pages were redesigned.

## Booking behavior and privacy

The standalone and embedded booking screens share buildBookingListContent, preserving existing payment, cancellation, reschedule, review, message and notes dependencies. Standalone routes retain their own header. Embedded mode removes only the inner header. Hidden booking tabs skip automatic refresh; revisiting refreshes authoritative data. No Firebase, payment, cancellation, authorization, certification or rating contract was changed.

Actual persisted-booking testing at 320/360px and 200% text exposed an existing BookingCard header overflow: the status pill squeezed the coach/date column. Moving the constrained status pill below that row fixes the layout without changing actions.

## Files

Production: apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart; member/widgets/coach_card.dart; member/widgets/booking_card.dart; member/booking_schedule_screen.dart; shared/live_booking_list_view.dart; shared/live_coach_directory_views.dart; apps/mobile/lib/app/di/booking_factory.dart; coach_profile_factory.dart.

Tests: apps/mobile/test/member_coach_tabs_test.dart (new); member_coach_ux_test.dart; member_coach_ux_render_test.dart; live_booking_composition_test.dart; coaching_mock_presentation_continuity_test.dart.

Plan: docs/superpowers/plans/2026-11-08-member-coach-tabs-compact-cards.md.

## Fresh verification

- 71 affected Flutter tests passed across 12 test files, including actual inline booking navigation, lazy construction/state retention, former-account privacy, hidden refresh/resume, filtering/apply/cancel and existing server-bound booking/directory tests.
- Eight render scenarios generated 40 PNGs: directory, filter sheet, empty embedded booking page and retained profile views at 320/360px, normal/200% system text plus the member app's 1.1 scale, light/dark harnesses. Representative normal/large-text/filter/booking renders visually inspected. Coach text uses bundled Barlow fonts; shared test-only Google font setup uses the existing offline substitution helper. These are widget renders, not physical-phone screenshots.
- Actual persisted booking contents also pass 320/360px 200% text tests, including scrolling.
- Analysis across 13 changed source/test files: no errors/warnings; the eight existing string-interpolation style infos in live_booking_list_view.dart match the untouched committed baseline. No new lint findings remain.
- Fresh scoped independent review: no actionable findings, including the final booking-card overflow correction.
- Isolated debug APK build passed from committed source plus the exact requested source allowlist; unrelated dirty Admin/workout/run-configuration changes are excluded. Previous artifacts are preserved.

## Limits and acceptance

No backend/data writes, Admin redesign, phone installation or physical acceptance claimed. Previous profile/data limitations remain: branch display names, review details and next-slot enhancements require authorized contracts and are deferred. Real phone acceptance should verify tab state, keyboard/search, filter drag/close/apply, photos, system text size/safe area, booking controls and logout without initiating an unintended financial action.

Evidence, hashes, isolated build and APK: build/member-coach-tabs-20261108/. The scoped commit hash is recorded in that directory and the delivery response. Existing unrelated working/staged changes are preserved.
