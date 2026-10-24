# Controlled automatic-delivery UAT activated

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Owner explicitly approved the fully populated activation proposal. Selectively updated only synchronizeGoogleBooking and googleGymConnectionCommand. No operator payment, booking mutation, manual Calendar sync or Gmail send performed.

Readback 23 October 2026 07:23 MYT:

- Worker ACTIVE, revision synchronizegooglebooking-00003-wub.
- Status Callable ACTIVE, revision googlegymconnectioncommand-00005-zoc.
- Both Node.js 22, dedicated runtime account gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com.
- Enabled=true; org gainpath; Coach controlled-uat-coach-uid-redacted (Jackson).
- Exact booking controlled-uat-booking-id-redacted.
- Sole approved verified recipient owner-google-account-redacted@example.invalid.
- Cutoff 2026-10-22T23:15:12.653Z, equal to the fresh booking's canonical creation time.
- Worker remains private; IAM, Eventarc, all five secrets' metadata/policies, Rules and the other 48 Functions unchanged against pre-activation snapshot.

Final hold read at 07:23:48 MYT: pending_hold, payment pending, expiry 07:30:12.653 MYT, no externalDelivery receipts. Owner can now complete the existing Sandbox payment once before expiry. If it expires first, stop; do not pay or reuse another ID under this scope. No historical bookings/backfill qualify.

Real automatic confirmation delivery is pending the owner's payment and canonical cleared/confirmed transition. Receipt/provider and actual Gmail/Calendar verification must follow; do not infer UAT pass from deployment success or manually press Send/Sync to simulate it. No automatic retry of uncertain Gmail. Reschedule/cancellation test commands require the agreed owner action scope. After controlled UAT, disable automation as part of the agreed test shutdown; do not broaden recipients/booking scope silently.

Firebase repeated its build-image cleanup warning; no artifact deletion or extra deployment performed. Machine-readable proof: build/google-oauth-setup/controlled-activation-verification.json and controlled-activation-hold-readback.json.
