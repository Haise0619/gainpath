# Member booking history and coach identity fix

Approved task: fix old21October confirmed bookings still in Upcoming and missing coach identity; optimize current list/details without modifying financial or completion records.

Root causes: Upcoming checks legacy status alone; live projection hardcodes coachName '-'; existing public-profile/name loader is only used for chat. Expired is an authoritative unpaid-hold resolution, not a confirmed session's automatic outcome.

- [x] Classify live records with serverNowMillis and absolute endAtMillis. Past confirmed sessions move to History/Past with Session ended; do not invent completion/expiry or mutate records. Keep true expired holds separate from cancellations; elapsed pending holds stay explicit pending server resolution.
- [x] Resolve/cache deduplicated authorized public coach profiles/names per widget session; use guarded late results, honest unavailable states, actual published photo when supported. Carry identity/photo into details without legacy/mock fallback.
- [x] Update booking details to explain ended vs confirmed source state, suppress elapsed-session management actions, remove fabricated certification/payment claims, and preserve actual payment details access.
- [x] Tests: ended/future/in-progress/exact boundary, pending hold elapsed/expired, coach cache/unavailable/late account, list/detail consistency, history filters, timezones, 320/360px large text. Focused suite, analysis, render checks, isolated debug APK and scoped review/commit.

Preserve all unrelated work, booking/payment/hold/cancellation server authority and privacy; no live data rewrites. Retain existing member visual style.

- [x] Latest owner refinement: History category chips stay on one horizontally scrollable row, including at 320px and 200% text.

Validation: 56 affected tests pass; 12 rendered fixtures at 320/360px and 100/200% text; scoped analysis has no errors/warnings and eight existing style infos. Final review found no remaining actionable issues. Build evidence and limitations: docs/ux/booking-history-coach-fix.md.
