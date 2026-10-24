# Exact controlled UAT activation — awaiting approval

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Read-only check: 23 October 2026, 07:17 MYT. No activation, deployment, payment or delivery performed.

- Organization gainpath; Coach Jackson `controlled-uat-coach-uid-redacted`.
- Booking `controlled-uat-booking-id-redacted`, pending_hold.
- Member Firebase Auth email owner-google-account-redacted@example.invalid, verified, enabled; active Member membership.
- Billplz Sandbox, MYR 100.00, payment pending / awaiting_payment.
- Session 26 October 2026, 09:30–10:00 Asia/Kuala_Lumpur.
- Created 23 October 2026 07:15:12.653 MYT; expires 07:30:12.653 MYT. Not expired at verification.
- Complete externalDelivery list is empty. Both worker and connection Callable remain ACTIVE with automation false, timestamp absent and empty recipient/Coach/booking scope.

## Exact proposed settings — do not apply before explicit approval

```dotenv
GOOGLE_GYM_ORGANIZATION_ID=gainpath
GOOGLE_BOOKING_AUTOMATION_ENABLED=true
GOOGLE_BOOKING_AUTOMATION_ACTIVATED_AT=2026-10-22T23:15:12.653Z
GOOGLE_BOOKING_AUTOMATION_TEST_RECIPIENTS=owner-google-account-redacted@example.invalid
GOOGLE_BOOKING_AUTOMATION_TEST_COACH_ID=controlled-uat-coach-uid-redacted
GOOGLE_BOOKING_AUTOMATION_TEST_BOOKING_ID=controlled-uat-booking-id-redacted
```

The cutoff is the canonical creation timestamp of this fresh hold (equality qualifies); it is not an arbitrary historical date. Exact Coach/booking filters and canonical creation-time checks exclude all other bookings and historical edits. The earlier draft's placeholder T0 is now populated from the authoritative fresh-hold record. No prior confirmed/paid transition exists to backfill.

## Approval and test sequence

1. Obtain explicit approval to activate this exact org/Coach/booking/recipient scope and its automatic lifecycle notifications. This does not authorize operator-driven reschedule/cancel commands or additional bookings without agreed UAT action approval.
2. Recheck unexpired hold, current verified recipient, canonical payment and receipts. Stop on expiry or mismatch; never extend or mutate the hold to force eligibility.
3. After approval only, update configuration and selectively deploy only synchronizeGoogleBooking and googleGymConnectionCommand. No IAM, secrets, unrelated Functions, Rules, Hosting or APK change. Read back all exact filters, disabled/default behavior outside scope and private worker IAM. If deployment outlasts the hold, stop and do not pay; a replacement ID needs new scope approval.
4. Only after activation readback, tell the owner to complete the existing Sandbox payment once. Verify cleared/confirmed proof, one automatic private Calendar event and actual Gmail receipt. Do not manually press Send/Sync to simulate automation.
5. Continue duplicate/reschedule/cancellation UAT only within specifically agreed test actions, using the same booking and receipt safeguards; no automatic Gmail retry after uncertainty. Refunds remain separate.
6. After UAT, disable automation through the agreed deployment scope and retain receipts. No broad or permanent activation is approved by this proposal.

Evidence: build/google-oauth-setup/controlled-uat-hold-preflight.json. No settings applied to deployed resources or local .env by this preparation.
