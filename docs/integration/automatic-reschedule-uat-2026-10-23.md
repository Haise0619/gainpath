# Controlled automatic reschedule UAT — provider delivery verified

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Read-only Firebase verification at 2026-10-22T23:31:33.320Z confirmed booking `controlled-uat-booking-id-redacted` remains confirmed and moved to 26 October 2026, 10:00–10:30 Asia/Kuala_Lumpur.

Exactly one rescheduled Calendar receipt and one rescheduled email receipt were found, both delivered by `google-booking-worker`. Calendar provider event ID matches the original event, indicating an update rather than a second event. Gmail provider message ID: `automatic-reschedule-message-id-redacted`.

Evidence: `build/google-oauth-setup/controlled-automatic-reschedule-outcome.json`.

No manual delivery or retry was triggered. Actual Gmail receipt and Calendar UI observation remain pending: Chrome browser access was unavailable during this verification. Do not mark end-to-end reschedule UAT PASS until these are observed or confirmed by the owner. Cancellation and shutdown UAT remain pending.
