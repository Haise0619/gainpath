# Consultation notes — 20 October 2026

FR-9.5 / UC-9.2 / BR-14 source implementation. No Firebase activation or device installation performed; manual connected UAT is pending.

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

The implementation is not live until separately approved selective deployment of `bookingConsultationNotesCommand` (new, App Check enforced) and `getBookingListCommand` (updated history range). Do not blanket-deploy Firebase resources. Existing Firestore Rules deny direct access to the nested note path; only the participant-authorized callable exposes it. No Rules/Storage/Scheduler/Secret Manager changes are proposed.

After approved activation, verify one legitimate ended confirmed booking through the real Coach UI: empty-text rejection, publish, read-only reopen, Member readback and matching completed status. Test unrelated account denial and account switch. Do not fabricate confirmed bookings or alter timestamps, payment state or personal records to shortcut this UAT.
