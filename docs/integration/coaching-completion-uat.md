# Coaching completion — Module 8 → 10 → 7 → AI integrations

Started 2026-10-21 at the owner's request. Preserve the existing shared Flutter UI, authentication, organization boundaries, App Check, sandbox payment authority and frozen pose implementation. Earlier module documents remain historical evidence, not a current acceptance result. No production changes are authorized merely by a passing automated test.

## Current evidence

- Module 8: Coach account/profile, phone, certifications and Admin review/publication already implemented. Earlier disposable live review demonstrated reject/approve/publish/archive with retained audit. Owner's current phone/browser acceptance is still unreported.
- Module 10: six selected Functions were previously deployed. Fresh read-only inventory confirms roster and availability endpoints ACTIVE, one configured weekly roster, and one published Coach with public credential eligibility. This does not establish that the owner has completed live roster CRUD UAT.
- Module 7: directory, trusted options, holds/expiry, Sandbox payment verification/reconciliation, booking lists, assigned messaging and completed-session reviews exist. Confirmed-booking Member cancellation and rescheduling require completion: the live Member UI disables rescheduling and cancelBookingHoldService accepts only pending/cancelled/expired holds. Do not describe Coach cancellation as Member cancellation.
- Module 6: deployed assistant remains read-only; get_my_progress and find_equipment are its current tools. No booking, Google Calendar or email mutation tool is registered.
- Fresh focused backend run: **141 passed** across nine selected files (Coach profile/callables, roster, availability, member options, booking lifecycle/payment/communication/review). Focused mobile run: **29 passed** across five files (phone settings, profile state, certifications, roster UI, availability flow). No full suite, code deployment, live writes or new APK installation performed in this phase.
- Read-only inventory: three public Coach documents, one published/public-credential-eligible; one configured weekly roster; nine bookings (one completed, one confirmed, four cancelled, three expired). No booking IDs, personal fields or credentials appear in the report. Counts do not establish acceptance or eligibility of every underlying record.
- Current Rules hashes differ from old Module 8/10 snapshots. Use fresh deployed snapshots for any future security/emulator comparison; never redeploy historical Rules to make a test pass.
- Sanitized metadata: build/coaching-final-uat/readiness.json. Current app is the installed Module 6 APK, which contains the existing Coach/availability workflows; a separate legacy Module 8 APK is unnecessary.

## Module 8 owner checklist

Use authorized Coach/Admin accounts and test evidence. Do not publish a synthetic credential as a real qualification or cancel a real appointment for testing.

1. Coach on Xiaomi: open Profile; verify shared purple layout and small avatar. Edit biography/specializations, save, leave/reopen and confirm persistence. Replace/clear a test photo and reopen.
2. Settings: save a valid phone with the correct country, reopen, test invalid input, then restore the intended value. Verify visible success/error and no stuck spinner. Test password recovery/change and logout privacy using the owner's own account when ready; never share credentials in chat.
3. Certifications: select an authorized PDF/image, preview, submit, reopen and verify pending/history; invalid/oversized files must show errors. Archive only disposable evidence.
4. Admin at http://localhost:7359/: select that Coach, preview evidence, reject with reason or approve genuine test-authorized evidence. Approval alone must not publish. Explicit publication requires valid reviewed credentials; verify Member directory behavior before/after and preserve existing bookings.
5. Sign out/switch roles; prior private profile/evidence must no longer be accessible. Report PASS or the failing step/message. Owner acceptance remains pending until observed.

## Next stages and acceptance boundaries

### Module 10 live acceptance

Use the same eligible Coach and latest app. Save/reopen weekly hours, assigned branch, capacity in hours and advance-day window; add/edit/remove test Break/Off-day/Leave; verify dated override precedence and Member effective slots. Confirm existing reservations survive edits and overlapping exceptions are rejected. Admin schedule remains read-only and private reasons do not reach Members. Restore intended schedule after testing. Automated disposable live tests may use only a proven fixture and must leave it unpublished/inactive; do not reactivate canonical accounts merely to produce evidence.

### Module 7 completion

Map FR-7.1–7.6 against current source and actual Sandbox lifecycle. Implement confirmed Member cancellation and rescheduling through trusted transactions and existing locks/command receipts. Resolve C3's 24h/12h timing and financial/refund behavior against existing policy before choosing a new financial rule. Preserve pending-hold retry, expiry and late-payment reconciliation. A reschedule must not release the old confirmed slot before the replacement is secured, double-count Member limits, or copy payment settlement without authority. Add focused contention, replay, unauthorized, stale edit and failed-payment tests before implementation. Only genuine Sandbox provider confirmation may confirm paid bookings; no synthetic timestamps, fake settlement, live payments or payouts.

### AI Booking / Calendar / Email

First expose approved published Coach/availability reads through the existing tool registry, with bounded arguments and trusted organization/member identity. Personal bookings and provider credentials must stay outside unpaid Gemini requests; do not silently enable private-approved mode.

AI may propose a concrete booking, but the user reviews the Coach, branch, local time, duration, price and payment consequence before a trusted existing booking command executes. Confirmation is bound to the exact proposal and current identity; revalidate availability/price and use idempotency. Model text cannot authorize payment or bypass the booking lifecycle.

Calendar/email require a separate account/provider decision: each user's own Google account versus an organization-controlled integration. Use minimum OAuth scopes, server-held refresh credentials, revocation/account-switch handling, and explicit action consent. Never reuse Codex's connected personal Calendar/Gmail as GainPath's application backend. Build read/draft/preview paths before external writes. Automatic event creation/email delivery must follow an authoritative confirmed booking, use retry-safe event identities, and reflect cancellation/rescheduling without duplicates. Paid provider settings, OAuth consent configuration, new secrets/IAM and deployments remain reviewable approval gates. No real email/calendar write is part of this inspection phase.

## Completion status

Module 8 owner UAT: pending. Module 10 owner live CRUD: pending. Module 7 gaps: identified, not implemented by this inspection. AI mutation/OAuth integrations: not implemented or activated. No claim of end-to-end booking/calendar/email acceptance.

## Module 8 UAT repair — Admin profile-review alerts

Reported gap: Coach profile edits require explicit Admin publication, but the Firebase shell hid its demo notification bell and no live profile-review alert existed. Added a live Admin bell derived from existing scoped Coach draft/publication revisions, including complete pagination and canonical authority checks. It excludes inactive Coach memberships, preserves alerts until the latest draft is published, does not treat deactivation alone as a new edit, refreshes every 60 seconds/manual refresh, and opens the selected Coach review with discard protection. No duplicate notification collection, auto-publication, email or push delivery was added.

Verification: 10 focused alert/widget, publication and shell tests passed; changed-file analysis reports no issues. Existing main Admin rebuilt; stale equipment-specific local server was replaced with tools/admin_web/serve.cjs at the same localhost:7359 entry. Served JavaScript SHA-256 matches c292a3c6f72a0b0f3ef39ac401b451726342be811c0df4bc0d5798d8ec540d4a. No Firebase deployment, business-data mutation or APK installation. Owner must refresh Admin and verify a real Coach edit appears and opens the review; live UI acceptance remains pending.

## Coach review details UI — UI/UX Pro Max

Reorganized the existing review into four numbered sections: draft/published profile comparison with changed-field labels, publication eligibility and branch/credential status, private certification review/history, and publication/directory actions. The selected review opens before the Coach directory. Profile fields, draft/public fees, fee-change consequences, no-price checkout warning, revision/status metadata, membership/BR-5 blockers, private preview/rejection/revocation/history, pagination, booking/schedule navigation, publish/deactivate/reload and discard protection remain available. Revision/identity timestamps are grouped in expandable Record details. Comparison columns adapt to stacked cards at narrow widths; status text wraps.

Added CoachReviewOverview presentation component and two focused responsive/eligibility tests. Updated the existing end-to-end publication widget test to scroll to actions as a user would. Thirteen selected UI/state/adapter tests passed. Focused analysis had no errors or warnings; seven pre-existing certification-panel brace-style info lints remain. Local Web build passed. Real authenticated Admin review was inspected read-only at localhost:7359 on a narrow viewport; no business record was published, deactivated or edited. Screenshot: build/coaching-review-ui/review-overview.png. Served build SHA-256: 892fcc2278771db132b555bd5213a9cb492853ab0500e9cc8c24888ea0c58471. No Firebase deployment or APK change.
