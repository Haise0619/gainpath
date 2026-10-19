# Module 10 — Coach Availability and Roster Management

## Delivery and acceptance boundary

Source implementation is complete for C3 **FR-10.1–FR-10.4**, with focused verification and an integrated Firebase Android build. **The approved six-function production activation is complete; real CRUD save/reload and owner manual UAT remain pending.** Emulator results do not establish real Firebase CRUD success. Do not start another module until the owner reports PASS/FAIL.

- Backend commit: `d0e8a8fd6efd93939dfc936b4fbe97decb2207bb`.
- Shared presentation/adapter commit: `9e5bafc2d6b4423b11618a4b0074861269dfec0d`.
- Accepted Admin checkpoint: `18e4130`; pushed integration milestone `e5f9c99` passed [CI run 39183693687](https://github.com/Haise0619/gainpath/actions/runs/39183693687).
- The Module 10 commits remain local. The owner explicitly approved the six-function deployment, which completed successfully. No new business-module push, APK installation or canonical account modification occurred.

## Original requirement coverage

| Original FR | Implemented behavior |
| --- | --- |
| FR-10.1 / UC-10.1 | Existing interactive week/date calendar now shows authoritative working hours, blocked markers and selected-day blocked intervals. Existing dated editing remains available. |
| FR-10.2 / UC-10.2 | Seven recurring weekdays, active/off state, organization-local half-hour start/end and current branch assignment. Dates with existing overrides keep precedence. Weekly edits retain genuine old schedule overrides for dates whose active reservations need them. |
| FR-10.3 / UC-10.3–10.5 | Private Break/Off-day/Leave exceptions, optional reason, same-day future or multi-day range, edit/remove, optimistic revision and retry identity. Server rejects conflicts with confirmed bookings and unexpired holds. Overlapping remaining masks survive removal. |
| FR-10.4 / UC-10.6 | Daily capacity in **bookable hours** and inclusive advance booking days, enforced in trusted options and checkout transactions. Existing organization Member booking-count limit stays separate. |

C3 UC-10.6 and C4 Table 4.13 define capacity in hours; the C4 screen narrative also mentions sessions. This implementation follows the explicit use case/schema units. Supported controls are 1–24 hours and 1–30 advance days, preserving the existing server's 30-day horizon rather than expanding it.

## Architecture and preservation

The existing canonical Availability layout, date cards, working-hour panels, time-off section and limits section remain. Firebase repositories implement the shared roster contract. Missing configuration displays `-`; editable drafts are not represented as saved data. Forms provide validation, loading/error states, duplicate-submit protection, same-intent retry, stale-edit blocking, discard protection and authenticated-session guards. Shared draft protection was extracted into `gainpath_ui`; Member's existing wrapper keeps its behavior.

The parent of the existing `orgs/{org}/coachAvailability/{coach}/days/{date}` collection now stores the weekly configuration and a bounded private exception array (maximum 64). Existing day documents remain authoritative dated overrides. This avoids a duplicate availability collection and allows atomic multi-day exception CRUD. Existing immutable command receipts retain timestamped save snapshots. No migration is required: missing parent configuration preserves dated-only behavior. Read-only live inspection found two Coach identities and no existing parent documents.

Options and checkout share the same resolution: dated override, otherwise weekly baseline, then exception masks. Daily occupied half-hours come from existing confirmed/unexpired reservation locks, so no duplicate capacity counter or cancellation/expiry bookkeeping is added. Limits-only updates read no slot locks; coverage changes inspect only affected dates within the bounded horizon. Existing reservations and replayed commands survive lowered limits. No cancellation, expiry, Scheduler, consent/outbox, pose, workout history or protected content changes were made.

Member schedules contain effective windows without private reasons. Current Coach and organization Admin may read roster details through authenticated callables; only the current Coach may write. Admin's existing schedule view displays hours, limits and private exceptions read-only.

## Focused verification

- Backend build and test typecheck passed.
- Five focused backend unit files: **140 passed**, including existing availability, booking/options and lifecycle regressions.
- Real local Firestore adapter: **8 passed** across roster/availability suites, including different-member/different-slot capacity contention, exception-versus-hold races, weekly-change reservation pinning, and server-only aggregate access.
- One additional authorization test passed against the **exact deployed Firestore Rules snapshot**; other tests were deliberately excluded by the targeted name filter. All client aggregate reads/writes remained denied.
- Coach/Member calendar, roster and same-day exception tests: **17 passed**. Shared-guard verification also included two Member editor tests: **19 passed** together.
- Admin schedule/roster reads and session handling: **2 passed**; shared contract boundaries: **3 passed**.
- Architecture checker and targeted changed-source analysis passed. Scoped review found no remaining important findings after calendar and same-day corrections.
- Full CI was not repeated for this ordinary module change. The integration milestone above is green; Module 10 has the focused evidence listed here.

Evidence is retained under ignored `build/module-10/`, `build/module10-backend-emulator/` and `build/non-core-crud-sprint/module-10-activation/`. Expected denied Rules requests produce stderr. Local Node 24 reports a declared-Node-22 warning; production build/typechecks passed and deployment runtime remains Node 22.

## Exact live configuration and approved selective activation

Read-only project: `gainpath-0619`, organization `gainpath`, region `us-central1`; 24 ACTIVE Node 22 functions. Booking policy remains Asia/Kuala_Lumpur, 15-minute holds and one active booking per Member/day.

- Firestore Rules SHA-256: `3b11087f0d21639249374ae17035fbc4d734a0827f1c7390acd118b0c486e2db`.
- Storage Rules SHA-256: `50138b9c519882e03005c1f7f5821b306d9d35baf3aca701c716c1feb8b3fc8d`.

**No Rules, indexes, Storage, Hosting, project/service-account IAM roles or Scheduler changes were made.** The owner-approved deployment was restricted to these six function names:

1. `getCoachRosterCommand` — new private read, App Check enforced.
2. `saveCoachRosterCommand` — new own-Coach aggregate command, App Check enforced.
3. `getCoachAvailabilityCommand` — shared weekly/exception resolution.
4. `saveCoachAvailabilityDayCommand` — roster revision and reservation-safe dated editing.
5. `getMemberBookingOptionsCommand` — Coach capacity/advance enforcement.
6. `createBookingHold` — same trusted enforcement at checkout.

Live Rules hashes and target revisions were rechecked immediately before deployment. The CLI deployed only the six explicit function names, without a blanket Firebase deployment or account-data rewrite. Readback confirmed **26 functions**, all six targets ACTIVE on Node 22, every unrelated function revision unchanged, and both Rules hashes unchanged. New read/write roster endpoints each rejected anonymous calls with HTTP 401/UNAUTHENTICATED. Revisions: `getcoachrostercommand-00001-gub`, `savecoachrostercommand-00001-nar`, `getcoachavailabilitycommand-00003-yin`, `savecoachavailabilitydaycommand-00003-xon`, `getmemberbookingoptionscommand-00003-lir`, `createbookinghold-00003-mew`.

The new client dated-save payload includes a roster revision; the reviewed server handlers are now deployed for compatibility. Real save/reload checks remain pending owner UAT; no canonical identities were used for automated writes. The official Admin build was reloaded and its authenticated shell opened; this is not a claim of owner acceptance or live roster CRUD success. Firebase CLI reported an image-cleanup warning after successful deployment; no build images were deleted or unrelated redeployment attempted. Sanitized deployment/readback evidence remains in the ignored activation directory.

## Builds and official entry

- Official Admin: **http://localhost:7359/**, final build served with HTTP 200 and matching JavaScript SHA-256 `ba988f9094c57267452171dfb14247f8d253e6ba8c31872d706ca9327eae568f`. No per-module website or route was created.
- Android: `build/module-10/gainpath-module10-firebase-debug.apk`.
- APK SHA-256: `014fc5c0bbd0eb40688c09f72561037702d0e1536771ebcf6c69a89aae33fd95`.
- Signing certificate matches the previously installed unified-mobile artifact. **Not installed.** No phone private data was accessed or changed.

The six pre-existing modified files remain uncommitted and byte-for-byte preserved. The APK includes the unchanged owner roster-routing fix already in the working tree; it is not silently included in the Module 10 commits. Source provenance and owner-file hashes are retained in ignored delivery evidence.

## Consolidated manual UAT after activation

1. **Coach:** open Availability; set/review all seven working days, branch and limits; save, leave and reopen. Confirm persisted values, calendar hours, dated overrides and empty `-` states. Try back/discard and a failed/retried save.
2. **Coach:** add a future break today, a future full day and a multi-day Leave; save/reopen, edit and remove them. Confirm organization-local labels and calendar masks; past starts and today's full-day option are unavailable.
3. **Member:** use an appropriately verified and published Coach. Confirm effective slots respect weekly hours, dated overrides, blocks, duration, capacity and inclusive advance limit. Unpublished Coaches must remain unavailable under BR-5.
4. **Conflict protection:** use a test booking/active hold, then attempt an overlapping exception. Expect rejection; change weekly hours and confirm the existing reservation is preserved. Lower limits and confirm existing reservations remain while new checkout is blocked appropriately. Confirmed-lock behavior is also covered by emulator tests; do not manufacture confirmation on existing records.
5. **Admin + session:** at the official Admin URL open the same Coach's schedule, inspect private working hours/time off/limits and refresh. Confirm no Admin roster-write controls; sign out and verify private routes/data disappear. Existing directory/certification/publication behavior must still work.

Record the owner's real Firebase observations and PASS/FAIL here after testing. No owner manual PASS is claimed by this delivery.
