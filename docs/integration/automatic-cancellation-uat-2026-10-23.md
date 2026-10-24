# Controlled automatic cancellation UAT — provider delivery verified

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Read-only Firebase verification confirmed booking `controlled-uat-booking-id-redacted` is cancelled. It previously occupied 26 October 2026, 10:00–10:30 Asia/Kuala_Lumpur with Jackson.

Both cancellation receipts finished as delivered by `google-booking-worker`. Calendar cancellation targets the same original event ID. Gmail provider message ID is `automatic-cancellation-message-id-redacted`. The first email read was sending; a subsequent read confirmed delivered. No manual sends, retries, booking mutations or payment/refund actions were performed.

Evidence: `build/google-oauth-setup/controlled-automatic-cancellation-outcome.json`.

Actual Calendar removal and Gmail receipt remain pending owner observation because Chrome access was unavailable. Owner screenshot separately confirms the earlier reschedule email reached Inbox with the correct previous and new times. Reschedule Calendar UI verification remains pending.

Automation remains limited to the original approved single-booking scope; disabling and any broader rollout have not been performed.
