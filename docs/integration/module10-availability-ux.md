# Module 10 availability workflow repair

2026-10-21. Requested after owner UAT reported slow interaction, duplicate date editors and unclear relationships between working hours and booking limits. UI/UX Pro Max Flutter layout guidance was used; existing domain/booking rules and shared Mock/Firebase screens are retained.

## Workflow

- Calendar is a read-only schedule preview. Selecting a day is local and cannot edit weekly hours. Draft weekly changes and blocked periods appear immediately without an API request, labelled unsaved until persisted.
- Weekly working hours are the main recurring schedule editor. A single **One-off date changes** entry remains below it. The duplicate Dated overrides footer and calendar Edit date action are removed.
- A one-off edit replaces the working windows for that date only; it can include extra windows but is not an additive-only backend feature. It never edits the weekly template. Existing custom dates retain precedence and are explicitly labelled. They were not silently deleted or migrated, including the owner's existing extra midnight window. The date editor now initially proposes a new window after existing hours when possible instead of defaulting every addition to midnight.
- Breaks/off-days/leave subtract time from working windows. The calendar calls the result open hours, rather than falsely treating all scheduled hours as still-free booking slots.
- Daily coaching capacity is a total across all Members. Existing confirmed bookings and unexpired holds consume capacity. An eight-hour working day with a six-hour cap permits at most six booked hours; increasing the cap does not create working windows. Existing reservation preservation remains server-authoritative.
- Advance-booking days controls the inclusive last bookable organization-local date, independently of weekly working hours or session length. The exact date is shown. Dates outside the window are marked in the preview; eligibility is still revalidated on the server.
- One Save changes action persists weekly hours, blocked periods and limits together. One-off date changes save separately within their editor, clearly explained in both flows. Draft/discard/conflict/idempotency guards remain in place.

## Responsiveness changes and limits

Weekly saves previously launched a calendar reload in both the editor callback and the screen save handler. The screen now performs one refresh. Date editor opening reuses the already-authorized current snapshot instead of requesting the same week again; writes still check current server revisions. Background refresh retains the prior calendar until replacement arrives and preserves selected dates when they remain in the returned range. Loading failures have visible feedback and a single primary retry.

Tests verify initial calendar read plus one post-save read (two total), and no additional read when opening the cached date editor. These are request-count checks, not measured physical-device latency. First-load network latency and Cloud Function cold starts can still occur. No paid minimum-instance setting, server deployment or billing change was introduced.

## Verification

- Initial focused baseline: 17 tests passed.
- Final focused verification: **24 tests passed** across availability_preview_test.dart, coach_roster_ui_test.dart, coach_availability_flow_test.dart and coach_specific_date_sheet_test.dart. Covers instant draft preview, custom-date precedence, one-refresh saves/cached opening, full dated-save readback, horizon navigation, unknown-outcome retry identity, conflicts, account drift and unsaved-editor dismissal.
- Changed-file analysis: no errors/warnings; two brace-style informational lints remain in the screen. Existing tests were adjusted for the clearer labels and realistic scrolling through the longer explanatory preview. No full suite was run.
- Firebase Android debug APK built successfully with BACKEND=firebase, USE_FIREBASE_EMULATORS=false and APP_CHECK_MODE=debug. No Gemini key supplied. Artifact: build/module10-availability-ux/gainpath-availability-firebase-debug.apk; SHA256 c9ddbffda6cf6c593e918316e14c4fe017ed0cc79a9a5a6b7e9c3fda728fd05d. Signing certificate matches the prior Xiaomi app. Installation evidence is recorded separately in that directory; physical acceptance is not implied by build or installation.
- No Firebase resources, saved availability, bookings, payments, private evidence or frozen pose functionality were changed by automated UAT.

## Changed source

Shared availability_screens.dart; new pure availability_preview.dart; existing CoachAvailabilityCubit and CoachSpecificDateSheet for refresh/snapshot handling. Focused tests above. Existing CoachRosterEditor persistence, Firebase adapter, backend availability/options/checkout logic and data/security contracts are unchanged.

## Owner retest

1. Toggle/edit an ordinary weekly day. Check that its non-custom calendar preview updates immediately and says unsaved; no backend change should occur until Save changes.
2. Save/reopen; verify persisted hours. Calendar refresh should happen once. Select different dates without opening an editor.
3. Open the single one-off date editor, review full-date replacement wording, add a future test window and save. Weekly template must remain unchanged. Existing custom dates must remain labelled and preserved; remove an unintended midnight window only if that is the owner's intended schedule.
4. Apply/remove a test break; confirm preview subtraction, then Save changes. Cancellation/discard must keep the saved version.
5. Set six booked hours/day and fourteen advance days. Confirm the preview explains the total cap and inclusive last date. Member options/checkout must continue enforcing actual reservations and availability, not just the visual preview.
6. Test offline retry, another-device revision conflict, date-editor next/previous week and logout. Preserve genuine appointments. Record PASS/FAIL and device latency observations; no end-to-end acceptance is claimed yet.

## Xiaomi installation

Installed and launched the verified artifact on Xiaomi 23013RK75C as an in-place routine update under the owner's standing approval. Fresh installed/new signing certificates matched; previous APK and private data were backed up. Private data archives were byte-identical before launch, and installed APK hash matched the artifact. No uninstall or data clear. Evidence: build/module10-availability-ux/install-result.json. Physical page responsiveness and owner acceptance remain pending.
