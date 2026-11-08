# Member Coaches Tabs and Compact Cards Implementation Plan

Status: approved by owner request to implement on 8 November 2026. Admin optimization remains deferred.

Goal: Match the supplied reference while retaining the member app's Barlow typography, purple/neutral palette, existing radii, safe areas and navigation.

- [x] Add Find Coach / My Bookings segmented tabs below Coaches header; lazy embed the existing authorized booking screen without a nested header or route jump. Preserve both tabs' state and account guards.
- [x] Remove introductory headings. Make search compact with a nearby Filter and sort button. Use one bottom sheet for specialty/sort, clear/apply and honest loaded-result scope. Retain specialty chips.
- [x] Simplify coach cards to avatar, name, verification icon, specialty, real rating/review count and price. Location, tags and verification explanation remain in profile. Stack naturally at narrow widths/large text.
- [x] Reuse booking composition so cancellation, payment, messages, notes and reviews retain their existing dependencies and authority. Pause automatic background refresh when embedded bookings are hidden.
- [x] Test inline tabs, lazy loads, filter apply/cancel, retained query/scroll/state, compact cards, 320/360px and 200% text/light-dark, existing booking/account isolation; run analysis and isolated debug APK build, scoped review and commit.

Implementation: extend BrowseCoachesScreen with bookingsBuilder; add embedded mode to BookingScheduleScreen and LiveBookingListView; extract shared buildBookingListContent from openBookingList in the existing booking factory. No Firebase architecture or backend changes. Existing standalone booking routes keep their header.

Constraints: preserve unrelated work and staged run-configuration deletion. No fabricated reviews/prices/availability or private data. Existing verification/booking rules remain authoritative. No physical-device acceptance without actual testing.

Completed verification: 71 affected tests, 40 widget renders, scoped review and isolated debug APK build pass. See docs/ux/member-coach-tabs-implementation.md for analysis baseline and physical acceptance limits.
