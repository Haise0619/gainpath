# Google connection UAT — 2026-10-22

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Designated booking Calendar delivery passed

Owner supplied booking `manual-calendar-booking-id-redacted` for the previously proposed Calendar sync test. Submitted that exact reference through the authenticated Admin UI and confirmed Calendar sync once. GainPath returned “Synchronized” and recorded last successful sync `2026-10-22 17:34:53.733`.

Independently opened Google Calendar under `owner-google-account-redacted@example.invalid` on 26 October 2026. The day view showed one event: `GainPath coaching session`, 09:00–09:30, GMT+08, location Main Branch, calendar `GainPath — Jackson`. Event details showed private visibility and the description pointing to GainPath as authoritative. No attendees or email action was requested.

Evidence: `build/google-oauth-setup/booking-calendar-event.png`. This verifies real initial Calendar delivery, not repeated-sync idempotency, reschedule/cancellation synchronization or Gmail delivery. Those live tests remain pending. No booking/payment state changed; no personal primary Calendar event was edited; no email sent.

## Subsequent approved Coach calendar test

Owner replied “proceed” to creation of one Coach secondary calendar. The only published Coach offered by the live Admin selector was Jackson. Selected Jackson, confirmed creation once through the existing UI, and received “Coach calendar created” / “Calendar ready”. Refreshed status and verified the same ready state persisted; create button disabled. The provider implementation names this secondary calendar `GainPath — Jackson`, timezone Asia/Kuala_Lumpur. No personal primary Calendar operation, event creation or email sending was requested.

Evidence: `build/google-oauth-setup/jackson-calendar-ready.png`. Last sync remains “Not synchronized”. A designated confirmed paid booking and explicit recipient approval are still needed for event/email delivery UAT. Earlier statements below describe the pre-calendar connection checkpoint.

Owner completed the Google consent flow. The deployed OAuth callback displayed “GainPath gym Google account connected.” A subsequent refresh through the authenticated Firebase Admin UI at `http://localhost:7360/` displayed:

- Gym connection: Connected.
- Booking sender: `owner-google-account-redacted@example.invalid`.
- No automatic background delivery enabled.

This verifies the live consent/code exchange and persisted connection status through the dedicated runtime. Secret values were not manually retrieved for verification. The callback tab was closed after verification. Do not preserve or share callback query parameters or authorization URLs as evidence.

Evidence: `build/google-oauth-setup/connected-admin.png`.

Current local Firebase Admin build succeeded with private App Check debug configuration and emulators disabled. The old localhost:7359 tab had continued showing mock content; current live UI at port 7360 displays actual Firebase records and the shared Google integration panel.

No Coach secondary calendar, Calendar event, Gmail message, booking change or payment action was performed. Calendar/Gmail delivery and reschedule/cancellation/idempotency UAT remain pending. Next step requires approval to create one named Coach secondary calendar, followed by separately scoped delivery UAT on a designated confirmed paid Sandbox booking and consenting recipient. Personal primary Calendar remains untouched.
