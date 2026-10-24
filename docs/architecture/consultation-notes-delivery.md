# Consultation notes — 20 October 2026

FR-9.5 / UC-9.2 / BR-14 implementation. Selective Firebase activation and the compatible Xiaomi update completed on 20 October 2026 after the owner's deployment request. Manual connected UAT remains pending.

## Behavior

Existing Coach roster cards use the existing consultation notes editor. Assigned active Coaches may publish once, only after the original confirmed booking ends according to server time. The transaction creates an immutable note at `orgs/{org}/bookings/{booking}/consultation/current`, sets the existing booking to completed and creates a payload-bound receipt. Exact retries return the saved note; changed payloads and overwrite attempts are rejected. No financial records, locks, job records or daily reservation accounting are changed.

The existing editor retains its shared panels, session header, outline button and text field. Connected save waits for trusted completion, retains failed text, freezes an uncertain intent for same-request retry and offers server reload. Published notes reopen read-only. Unpublished changes require confirmation before leaving. Root application session keys dispose pushed routes when account identity/assignments change; transport checks also reject late responses.

Members access the saved note from completed booking cards. Both roles can select Past 30 days; the default upcoming range remains. The existing paged listing remains limited to 31 dates per request and now accepts ranges from 90 days ago through 30 days ahead, under the same owner/branch authorization. No indexes are added.

Notes are limited to 5,000 characters and require nonempty text. No server draft storage, editing of published notes, generated observations, ratings, earnings/payouts, confirmed cancellation or Admin note viewing is included. Existing mock workflows remain injectable; connected failures never fall back to mock success.

## Essential verification only

- New notes service: 4 tests (atomic completion/readback/idempotency/preservation; authorization; early/unpaid/invalid denial; immutable/replayed intent).
- Affected existing booking-list suite, including one new recent-history case: 52 tests.
- Existing editor and booking-route smoke groups: 4 Flutter tests, including a 430px editor viewport and session-drift route clearing.
- Source and test TypeScript typechecks pass. Targeted Dart analysis: no issues.
- Existing Mobile presentation and architecture guards pass; git whitespace check passes.
- Focused static review of authorization, transaction/receipt, UI confirmation, privacy and route lifetime. Root MaterialApp's existing session key addresses the conditional idle-note route concern.

No full workspace suite, APK/Web build, emulator matrix, provider request or live-data write was run, in accordance with the requested minimum testing.

## Activation boundary

The approved deployment targeted only `bookingConsultationNotesCommand` (new, App Check enforced) and `getBookingListCommand` (updated history range). Existing Firestore Rules deny direct access to the nested note path; only the participant-authorized callable exposes it. No Rules/Storage/Scheduler/Secret Manager changes were made.

After approved activation, verify one legitimate ended confirmed booking through the real Coach UI: empty-text rejection, publish, read-only reopen, Member readback and matching completed status. Test unrelated account denial and account switch. Do not fabricate confirmed bookings or alter timestamps, payment state or personal records to shortcut this UAT.

## Verified activation and phone update

Source commit: `1206468bb3423749d1f7346118788f0eae120781`. Fresh Functions build and Firebase Android debug APK build passed; no source changes were introduced during deployment.

Project `gainpath-0619`, region `us-central1`: both targets ACTIVE on Node 22. Notes revision `bookingconsultationnotescommand-00001-vab`; booking list revision `getbookinglistcommand-00003-sep`. Live function count increased from 35 to 36; all 34 unrelated function revisions are unchanged. Exact Firestore/Storage Rules release IDs and complete source hashes are unchanged. Anonymous probes to both targets returned 401 UNAUTHENTICATED. No booking, consultation, financial or personal record was created/changed for deployment verification.

Firebase CLI completed successfully and separately warned that build-image cleanup failed. No unrelated image cleanup was attempted.

APK: `build/consultation-notes-1206468/gainpath-consultation-notes-firebase-debug.apk`, SHA256 `336588f8859db05105b5bea0c430dc653bacf3705009d97d7f3967f670fea336`. Built with Firebase, real services and existing debug App Check mode. Installed and launched on Xiaomi `23013RK75C` as an in-place update. The actual installed signer matched before installation. Previous installed APK and 99,081,216 bytes of private app data were backed up under the ignored activation directory; private archives were byte-identical after installation and before launch. Installed APK hash matched the new artifact. No uninstall, downgrade or app-data clear occurred.

Sanitized read-back/artifact/install evidence is in ignored `build/consultation-notes-1206468/`; private backups are underneath its private directory and must not be committed/shared.

## Short owner test

1. Choose a genuine confirmed booking whose scheduled end has passed, with access to its assigned Coach and Member accounts. An existing eligible booking is sufficient; otherwise use the normal Sandbox booking/payment flow and wait for its real session end.
2. Coach: open Roster, select Past 30 days if necessary, then Write notes on that booking. Confirm the correct Member and session.
3. Try Publish notes with empty text; expect validation. Enter the actual consultation note and publish. Wait for Published notes and the read-only completed state.
4. Go back, refresh and reopen View notes. The same text must persist and the booking must be Completed.
5. Member: open My bookings, select Past 30 days, find the same completed booking and open View consultation notes. Confirm identical read-only text. Pending holds and sessions that have not ended must not be completable.
