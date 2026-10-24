# Refund review and empty booking date — UAT fixes

Owner update, 2026-10-21: owner reports PASS after deployment and the multiple-session change; proceed to AI Booking → Calendar → Email. Earlier physical UAT-pending statements below describe verification at implementation time. Provider HTTP 422 refund reconciliation is not independently verified by this acceptance.

2026-10-21. Owner approved the refund deployment and explicitly requested multiple sessions per Member per day. All six scoped Functions are deployed and ACTIVE, and the daily policy setting is updated and verified. No refund execution, retry or production payment-record edit is part of this work.

## Diagnosed

At the time of the reported failure, the live booking policy had maxActiveBookingsPerMemberPerDay=1 in Asia/Kuala_Lumpur. A confirmed session or unexpired pending hold counts toward the Member's cap for that local day across Coaches. Cancelled, expired and refunded reservations do not consume active capacity. The empty options response already reports daily_limit, but the explanation was separated from the Available times area, whose empty state was just a dash. The same server reason can also reflect Coach daily capacity; the revised message accurately describes both conditions without changing the policy.

The Admin payment projection omitted checkout localDate/startLabel/endLabel and refund recovery fields. The queue showed IDs and raw status strings instead of enough information to identify a request. The immutable checkout snapshot can also differ from the current session after rescheduling, so it must not be presented as the current appointment.

Read-only Cloud Logging diagnostics found BILLPLZ_V5_HTTP_ERROR 422 at 2026-10-21T11:23:23.449023Z followed by SANDBOX_REFUND_CREATE_ERROR. This explains the uncertain path but not the provider's detailed validation reason: that response detail was not retained. No new provider create call was made to reproduce it. Existing logic reserves the original attempt and blocks duplicate execution after uncertainty; that financial behavior remains unchanged. Do not claim that the refund completed or that no provider order exists based only on the generic error.

## Changes

- Backend booking-payment-admin.ts exposes allowlisted invoice schedule, refund reference/provider state, decision/attempt timestamps; joins the canonical same-org booking to show current session date/time/timezone/status and cancellation reason/time, separately from original checkout. It validates booking/member/Coach association and includes only the related Member display name, never contact or bank details. Missing legacy booking data retains an explicitly labelled invoice fallback. Existing Admin authority checks remain in place for every projection.
- Admin PaymentReviewRecord and RefundsScreen show schedule and request context in the queue; current versus original schedule in details; cancellation reason and review note separately; readable statuses and explicit safe recovery instructions. Refunds filter includes paid requests awaiting their first decision. Approval means not sent; execution means a Sandbox Payment Order with dummy details; uncertain means reconcile the original attempt, never blindly resend. Actor labels no longer misidentify every history event as an Admin action.
- Shared BookingSelectionPage has a real empty-state region. Live BookSessionScreen places limit/off-day/loading/failure guidance immediately under Available times and offers View My bookings. The inaccurate claim that the payment-enabled flow has no payment was corrected.
- Member BookingPaymentScreen distinguishes approved/not sent, submitted/processing and outcome unknown. It no longer claims an uncertain attempt is being processed successfully.

## Verification

- 36 focused backend tests passed (Admin payments 17, booking payments 13, Member changes 6), including schedule/recovery allowlists, current versus original schedule, owner mismatch denial, existing uncertain-create quarantine, concurrency/replay and payment preservation. TypeScript build/export load and test typecheck passed. Local Node 24 versus runtime Node 22 warning remains.
- 10 Admin widget/repository tests passed, including queue date visibility, uncertain instructions without an execution button, no action on render, narrow layout, scoped transport and account change protections.
- 19 mobile tests passed, including daily-limit guidance and My bookings navigation, useful empty states, approved versus uncertain labels, payment resume/retry/lifecycle and existing live booking behavior.
- Changed-file Admin/mobile analysis: no issues. Diff whitespace check passed. No full suite run.
- Existing local Admin web rebuilt at http://localhost:7359/ through tools/admin_web/build.cjs. Hash da2bc221e48b95386b163b983c7f9864c0d25fabba8f412c2a6f31358f972933. The enriched backend projection is now deployed; refresh the browser to load the rebuilt UI. Authenticated Admin visual acceptance has not been claimed.
- Fresh Firebase debug APK built with the existing Firebase/debug App Check flags and no Gemini key. Artifact: build/module7-refund-clarity/gainpath-refund-clarity-firebase-debug.apk. Installed and launched on Xiaomi 23013RK75C as an in-place update. Fresh installed/new signing certificates matched, previous APK and 99,480,064-byte private data were backed up, and private archives were byte-identical before launch. Installed APK hash matches 5222b5ea6515358647ea4a13fd726220deeeb6616990ec49abe81caad793b90f. No uninstall/data clear. Evidence: build/module7-refund-clarity/install-result.json. Physical booking/refund acceptance remains pending.

## Activation scope

Approved refund deployment: listAdminBookingPaymentsCommand, getAdminBookingPaymentCommand and manageAdminBookingPaymentCommand to gainpath-0619. The third returns the enriched detail after decisions, so it shares the new projection. The owner's additional multiple-session request also requires createBookingHold, getMemberBookingOptionsCommand and memberBookingChangeCommand. No payment provider configuration, Firebase rules/indexes, unrelated Function, Hosting deployment or financial execution is included. Routine APK update follows the owner's standing approval with fresh installed signature/data backup checks.

After activation, refresh the local Admin and check an existing cancelled session's amount, current date/time, original invoice date/time, Member/Coach, cancellation reason and decision/attempt times. Verify uncertain attempts show recovery instructions and no Execute action. Check the original attempt in the provider dashboard; attach an order ID only after authorized verification, or arrange provider/manual reconciliation if no order can be identified. This work does not resolve the original HTTP 422 provider condition or mark its refund successful.

## Multiple sessions requested by owner

The requested policy change uses the existing supported maxActiveBookingsPerMemberPerDay setting, from 1 to 32, retaining a technical safety ceiling rather than claiming unlimited bookings. No other policy field, hold duration or version is changed. Update uses the original Firestore updateTime as a compare-and-set precondition; readback compares all other fields. Coach working hours, daily coaching capacity, advance window and publication/credentials requirements remain authoritative.

New bounded memberBusySlots helper reads only the existing authenticated Member-day booking IDs in the same transaction. Holds and reschedules reject overlapping sessions across different Coaches; options hide those times. Shared Member-day writes serialize competing allocations, without a new collection. Confirmed accounting entries retained after consultation completion are accepted as completed historical windows; they must not block a later nonoverlapping booking that day.

116 focused backend tests passed after this change (including 45 booking and 35 options tests), plus four real Firestore emulator races. Added regressions cover multiple nonoverlapping bookings, cross-Coach overlap rejection, options filtering, and later same-day booking after an earlier completed session. The new contention test races two Coaches' slots for one Member and allows exactly one allocation. TypeScript build and test typecheck passed. Emulator ran on dedicated localhost port 18386 after the old 18385 port was already occupied; no existing process was stopped.

On Xiaomi, open a booked 23 October date: later nonoverlapping times should remain available, including with another Coach. An overlapping interval must be unavailable; failed attempts must retain existing reservations. Check an off-day and a request failure separately for visible guidance. Verify that an earlier completed session does not prevent another later session the same day. Real booking/payment acceptance remains owner UAT; no synthetic production booking or provider payment is created to demonstrate success.

## Live activation evidence

All six approved exports are ACTIVE on Node.js 22 in us-central1. Refund projection updates deployed first with the initial booking changes; the three booking exports received a second narrowly scoped update to include the completed-session compatibility correction before raising the live daily setting. Final revisions and checks are recorded in build/module7-refund-clarity/deployment-readback.json. Unrelated Function update times/revisions and Firestore/Storage rules releases match the pre-rollout baseline.

Actual HTTP checks passed: legacy/new list requests HTTP 200; missing App Check/authentication HTTP 401; malformed input HTTP 400; foreign organization HTTP 403; all three Admin payment endpoints reject the disposable Member with HTTP 403 before any provider action. These are transport/security checks, not proof of a real refund or booking change.

The existing policy document was changed from 1 to 32 using an update-time precondition, then verified that every other field was identical. Evidence: build/module7-refund-clarity/policy-update.json. No new collection, policy-version change or billing/provider setting was introduced. Firebase CLI again reported a build-image cleanup warning after successful deployments; registry cleanup remains unresolved and may incur storage charges.
