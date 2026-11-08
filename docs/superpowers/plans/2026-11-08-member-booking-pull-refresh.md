# Member booking refresh and historical range

Owner request: remove Member My Bookings automatic30-second sync, remove its refresh icon, use whole-page pull-to-refresh, and restore Past30days session visibility.

Root cause: date query switches independently of retained Upcoming/History and history-category state. A selected Upcoming/Completed tab can hide the returned past confirmed records. Failed range switches also retain old rows while changing the range label.

- [x] Add regression tests for explicit Upcoming → Past range, category reset, failed range rollback, manual pull on empty/short lists, no Member timer/listener polling, retained paging range, and current scope/uncertain action guards.
- [x] Member-only manual refresh; preserve Coach roster behavior and action/return-driven updates. Await actual refresh completion. Range changes select the matching main tab and reset category All; same-range refresh preserves filters. Commit selected range only after successful data loading. Request30days explicitly for Member.
- [x] Run affected booking/chat/navigation tests and scoped analysis, small/large text renders if layout changes, final review, isolated APK, exact-scope commit and operational notes. Preserve unrelated Admin/workout work. No backend/data deployment needed.

Related continuity correction: ensure Member booking Message action uses the existing shared pair conversation router rather than the obsolete per-booking UI. This is completion of the already-authorized shared-chat work; add a regression test.


Result: Member polling/change subscription and refresh icon removed; whole-page pull refresh works on empty/short lists and awaits completion. Date-range success selects matching main tab and All category; failed changes preserve prior range/rows. Historical range includes today plus 29 previous calendar days, anchored by an authorized server date lookup; paging keeps its original bounds while a fresh refresh advances them. Member booking messaging is verified to use the shared pair router. Coach roster polling is unchanged.

Verification: 95 affected tests across 17 files pass, including source-scope drift between anchor/history reads, midnight and fixed-range pagination. Eight fixture renders cover 320/360px at 100%/200% text. Scoped analysis: zero errors/warnings, eight unchanged baseline style infos. Final review: no actionable findings. Isolated APK built successfully with source allowlist and unchanged dependency lock verified.

Artifact: build/booking-pull-refresh-20261108/gainpath-booking-pull-refresh-debug.apk. No backend deployment or booking/payment/attendance changes. Phone initially exposed an idle booking page; old APK and 59 saved files were backed up and signer matched. It returned to the always-on lock screen before the final install check, so installation was aborted before any install command ran. No physical-device acceptance claimed. Evidence: build/booking-pull-refresh-20261108/.
