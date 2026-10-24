# Controlled automatic confirmation UAT — PASS

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Organization: gainpath. Coach: Jackson. Booking: `controlled-uat-booking-id-redacted`.

Owner completed Sandbox payment. Read-only Firebase verification at 2026-10-22T23:25:19.299Z confirmed booking `confirmed`, payment `cleared`, fulfilment `confirmed`, Sandbox MYR100.

Both Calendar and Gmail receipts are delivered, with actor `google-booking-worker` and notification type `confirmed`. No manual delivery or retry was triggered during verification.

Actual Google Calendar observation confirmed a private event on GainPath — Jackson for 26 October 2026, 09:30–10:00 GMT+8, Main Branch. The previous 09:00–09:30 manual-test event remains distinct.

Actual Gmail observation in owner-google-account-redacted@example.invalid confirmed the Inbox message “GainPath session confirmation”, received 23 October 2026 at 07:25, with the matching coach, location and session times. Provider message ID: `automatic-confirmation-message-id-redacted`.

Evidence: `build/google-oauth-setup/controlled-automatic-confirmation-outcome.json`, `automatic-confirmation-gmail.png`, and `automatic-confirmation-calendar.png` in the same directory.

Automation remains confined to the approved organization, coach, recipient and this one booking. Rescheduling, cancellation, live duplicate replay and shutdown UAT remain pending. No booking changes were made by this verification.
