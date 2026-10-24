# Module 7 Member booking changes — deployed, owner UAT passed

Owner update, 2026-10-21: owner reports final Module 7 UAT PASS and authorizes proceeding to AI Booking → Calendar → Email. This supersedes the earlier owner-UAT-pending status below. It does not independently establish that the prior provider HTTP 422 refund attempt completed.

2026-10-21. Local implementation and focused verification are finished. The owner approved the documented rollout with “proceed”; all fifteen scoped Functions have now deployed successfully. Owner booking/device UAT and actual provider acceptance remain pending. Live smoke checks did not change bookings or payments.

## Behavior

- Confirmed paid Sandbox sessions: Member cancellation requires at least 12 elapsed hours before start (BR-12); rescheduling requires at least 24 hours (BR-11). Exact boundaries are accepted using trusted server time. Pending-hold cancellation remains separate.
- Only the current verified, active owning Member in the canonical organization can change a booking. App Check is enforced. Client-controlled identities, amounts, branches and Coach changes are rejected.
- Cancellation atomically releases reservations and marks the existing cleared payment for Admin/provider review. This does not execute a refund, guarantee eligibility or mark the payment refunded.
- Rescheduling retains booking ID, Coach, branch, duration and original paid amount. Current credentials, availability, advance-booking horizon and both Member/Coach capacity are checked. Original reservations are released only within the successful atomic replacement transaction.
- Replacement options come from trusted current data. The owned source booking alone is excluded from capacity calculations, avoiding a false same-day cap conflict.
- Review shows old/new schedules and cancellation consequences. An uncertain response freezes the proposal; retry uses the identical request. Account drift discards late responses. Audit receipts, existing in-app notifications and conversation notices are reused.
- The payment screen labels its schedule as the original checkout schedule; My bookings shows the current appointment. No second charge or automatic financial operation is introduced.

## Changed files

Backend: new member-booking-change-service.ts and member-booking-change-callable.ts; index.ts export; booking-record.ts, booking-validation.ts, member-booking-options-service.ts and booking-list-service.ts; focused service, callable, payment, list and emulator tests.

Domain/mobile: new member_booking_change.dart, FirebaseMemberBookingChangeRepository, MemberBookingChangeScreen and focused tests; coaching.dart export, booking_read_contracts.dart decoding, BookingFactory, LiveBookingListView, FirebaseBookingListRepository and BookingPaymentScreen. Existing booking list JSON request/response contracts are updated. The availability, Equipment, chatbot and frozen pose implementations are not changed by this work.

## Verified

- 207 backend tests passed across 14 affected files; TypeScript build/export loading and test typecheck passed.
- Three dedicated Firestore emulator tests passed: replacement versus another Member's hold, two simultaneous replacements, cancellation versus replacement. They use synthetic fixtures in demo-module7-uat at 127.0.0.1:18385, with a guard against any other host.
- 37 mobile tests passed across nine affected files: new retry widget/transport plus existing payment, pending cancellation, Coach cancellation, list/composition, communication and review flows.
- Final focused analysis of the five new/wired mobile files: no issues. The wider shared list analysis has eight existing informational interpolation lints, no errors or warnings.
- Firebase debug APK built with BACKEND=firebase, USE_FIREBASE_EMULATORS=false, APP_CHECK_MODE=debug. No Gemini key supplied. Artifact: build/module7-booking-completion/gainpath-module7-firebase-debug.apk.
- APK SHA256: 7a9f5fe824f3b520f08b5eea75d41b2381de0a11690848d44ec84b4111d5177e.
- Signing certificate SHA256 matches the previously installed Xiaomi artifact: 38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450. Fresh installed-certificate comparison passed before the approved in-place update. APK installation and launch succeeded; the installed artifact hash matches. Previous APK and 99,430,400-byte private-data backup were saved. Private data archives were byte-identical before first launch. No uninstall or data clear. Evidence: build/module7-booking-completion/install-result.json.
- No full test suite was run. Local Node is 24.19.0; deployed runtime is Node 22, with actual deployed HTTP smoke results below. Physical rescheduling/cancellation UI acceptance remains pending.

## Approved selective deployment

New cancelled resolution is stored as member_confirmed_cancelled. New booking-list requests explicitly opt into it through includeMemberChangeDetails. Without that flag the new projection strips resolution metadata so old strict clients still read cancelled rows. Deploy the compatible reader BEFORE enabling new writes or installing this APK, which sends the new flag.

Approved project: gainpath-0619. No rules, indexes, Storage, Hosting, secrets, billing, unrelated Functions or provider settings are included. No new API credentials are required. Existing Sandbox payment configuration is reused without changing it.

1. Deploy getBookingListCommand first. Verify legacy and new list requests without modifying bookings.
2. Update the existing exported handlers that share the strict storedBooking parser: bookingCommunicationCommand, bookingConsultationNotesCommand, cancelBookingHoldCommand, cancelAssignedBookingCommand, expireBookingHolds, submitBookingReviewCommand, getCoachPerformanceCommand, getBookingPaymentQuoteCommand, createBookingPaymentCommand, getBookingPaymentCommand, billplzSandboxReturn, paymentWebhook, manageAdminBookingPaymentCommand. The quote handler shares the payment callable bundle and is included conservatively; existing Admin list/detail handlers do not parse stored bookings and are excluded.
3. Deploy memberBookingChangeCommand last. Stop on a dependency deployment or read verification failure; do not enable writes with mixed readers.
4. Recheck installed Xiaomi signature, back up existing app data/APK, then perform the authorized in-place update. Do not clear data or uninstall. Recheck authentication and App Check.

This is a 15-export rollout (one compatible list reader, thirteen related existing handlers, one new command). Existing getMemberBookingOptionsCommand does not need an update for this rollout: new replacement reads use the new command's internally imported options service.

## Live deployment verification

All fifteen approved exports are ACTIVE in us-central1 on nodejs22. New command revision: memberbookingchangecommand-00001-waz. The compatible list reader was deployed and checked first, all thirteen dependency updates succeeded next, and the new command was created last. Inventory increased from 45 to 46 Functions. Comparison against the pre-rollout metadata found no unrelated Function revision/update changes; Firestore and Storage rules releases are unchanged.

Live smoke checks with the existing verified disposable Member and registered Web debug App Check passed: legacy and new list requests both HTTP 200; missing App Check and App Check without authentication both HTTP 401 UNAUTHENTICATED; authenticated malformed input HTTP 400 INVALID_ARGUMENT; foreign-organization options request HTTP 403 PERMISSION_DENIED. No real booking change, provider payment, refund, Calendar or Email action was executed. The fixture has zero bookings, so successful list transport is not proof that a real Member's reschedule/cancellation works end to end. Xiaomi App Check/booking behavior still needs physical UAT.

Evidence: build/module7-booking-completion/deployment-readback.json and reader-smoke.json. Tokens and response contents are not stored in those reports. Google API credentials remained in memory. Firebase CLI reported an existing build-image cleanup failure after successful deployments; stored images may incur charges. Cleanup remains unresolved; no registry deletion, lifecycle policy or billing change was performed.

## Consolidated owner Sandbox UAT after activation

Use explicitly designated test bookings/accounts, not genuine appointments. Obtain approval before any provider payment/refund operation; these steps do not authorize one.

1. Owning Member opens an eligible confirmed paid test booking. Check displayed schedule, timezone and notice limits. Wrong account, logout and inactive membership must not expose actions or accept writes.
2. Reschedule more than 24 hours ahead to a genuinely free same-Coach/branch/duration time. Review exact old/new times. Verify Member and Coach lists agree; old time is freed, new time reserved, original amount and invoice remain unchanged, no second payment, Coach notice appears.
3. Test a competing reservation and a stale original schedule using designated fixtures. A failed replacement must preserve the original booking. Verify daily capacity, original Member daily cap and advance window still apply.
4. Disconnect immediately after confirmation, then retry. One intent must produce one change and one notice. Check My bookings before making a different change if outcome is uncertain.
5. Cancel an eligible paid test session at least 12 hours ahead. Confirm status cancelled and slots released. Admin Payments must show cleared payment requiring review, never an automatic refund. Verify Coach notice and that a duplicate payment callback does not restore the cancelled booking.
6. Less-than-24-hour rescheduling and less-than-12-hour cancellation must be rejected server-side. Existing pending-hold cancellation, payment resume, Coach cancellation, completion, consultation notes and reviews must still work in their proper states.
7. Record actual Xiaomi PASS/FAIL and observed errors. Local automated success is not owner acceptance.

AI Booking, Calendar and Email mutations remain disabled. After booking acceptance, add explicit proposal/confirmation tools over these trusted commands; provider OAuth, minimum scopes, permissions and idempotent external delivery still require separate design/setup and approval. Session-memory chatbot UI needs no redesign.
