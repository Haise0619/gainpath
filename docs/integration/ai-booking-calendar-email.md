# AI booking and Google delivery foundation

2026-10-21. Owner reports Module 7 final UAT PASS and authorizes moving to AI Booking → Google Calendar → Email. This records owner acceptance; the older HTTP 422 refund outcome is not independently proven resolved. No provider refund retry is part of this work.

## Status

AI booking is deployed through fitnessAssistantCommand and the updated APK is installed on Xiaomi. Real Gemini inference and the read-only Coach directory tool passed; a real session proposal/checkout device UAT remains pending. Calendar/Email provider adapters and delivery coordinator are implemented and tested locally but intentionally unexported and disconnected: OAuth consent/connect UI, trusted connection storage/authorization wiring and real provider acceptance remain required. This is not a claim that Calendar or Email is complete.

## User flow and authority

The existing shared chatbot screens and attachment system are reused. Registered read-only model tools are list_coaches, get_coaching_options and propose_booking, alongside the existing progress/equipment tools. Coach directory reads use bounded pages with an explicit next cursor, not a claim that the first twenty Coaches are the whole directory. Public names/prices are derived from current canonical publication, branch scope, verified Auth eligibility and approved credentials. Available times and prices come from existing trusted options/quote services. Model arguments cannot select a Member, organization, price or recipient.

The model can propose an available session, not reserve or charge it. A structured suggestion includes real Coach, branch, date, time, timezone, 30/60-minute duration and MYR price; it expires within five minutes. Review in checkout opens the existing Member booking screen. That screen reloads options and the authoritative price; it preselects only an exact still-valid Coach/branch/start match. Expired/unavailable suggestions show feedback immediately and create nothing. A deliberate Continue to payment action remains necessary to create the hold and start the existing payment flow. Repeated navigation taps and account changes are guarded. No new booking/payment command or automatic financial action is introduced.

Booking follow-ups use a narrow, short-lived Coach/date/duration hint in repository memory, separate from chat history. The server never forwards the raw hint: it re-reads current public eligible options/prices under current membership before model context. Stale Coach hints are discarded after checking that the account itself is still authorized. Hydration is silent and does not replace unrelated fitness answers. Clear chat, route disposal and account invalidation clear the context; late replies cannot restore it. Default free/public mode still omits personal conversation history and Member identifiers/progress from Gemini. Suggestions and context are not persisted with chatbot state.

Text claims such as “Booking confirmed” or “Your booking has been confirmed” are replaced with a truthful no-action message when no actual booking occurred. Known slot/directory summaries and review cards are assembled from server facts. Unknown or mutating model tools fail closed. Existing medical-safety, rate limiting, disclaimer acknowledgement, bookmarks and ratings remain.

## Google foundation and current gate

GoogleBookingGateway uses fixed official Calendar/Gmail hosts and server-provided access tokens only. Calendar events use a stable SHA256-derived booking event ID, private ownership metadata, private visibility and no attendees; existing events are checked before creation, and updates require their ETag. It does not expose recipient emails in Calendar descriptions. Gmail uses plain-text UTF-8 MIME, strict address validation and one send attempt. Message-ID alone is not treated as idempotency.

deliverConfirmedBooking is not a Callable or AI tool. Before any future use it requires explicit confirmation, current canonical verified owning Member, unchanged confirmed session, cleared matching Sandbox payment, no refund state and a trusted connection authorization port. The email recipient is the verified authenticated account address, not model/client input. A per-booking-version externalDelivery receipt reserves the attempt before provider IO. Concurrent/repeated requests do not resend; timeouts become uncertain and require reconciliation. An already-issued outcome is recorded even after revocation, but returning results still requires current authorization. A changed/cancelled booking during delivery is flagged for reconciliation. These receipt documents would only be created by an authorized future delivery action; this implementation created none in production.

Owner corrected the architecture on 2026-10-22: ONE Admin-managed gym Google account owns separate secondary Coach calendars and sends booking email; Coaches do not connect personal accounts. This choice authorizes preparation, not access to Google accounts or external delivery. Owner approved gainpath-0619 as the OAuth project. Google Calendar (calendar-json.googleapis.com) and Gmail (gmail.googleapis.com) APIs were enabled and independently read back as ENABLED. No OAuth-named Secret Manager configuration was found. An OAuth client in a separate project has not been ruled out. OAuth authorization-code/PKCE callback, shared UI, Secret Manager storage, revocation handling and an explicit Admin delivery handler are now implemented locally under the corrected gym-owned design. They remain undeployed and require OAuth/IAM setup and external acceptance. Local Admin delivery controls and cancellation synchronization are prepared, but not active in production. Automatic triggers, personal-calendar conflict reads and real email/event delivery remain disabled. Do not wire the current adapter directly to model arguments.

## Required Google API setup

1. Use a designated Google Cloud OAuth project; review enabling Calendar and Gmail APIs. Create an OAuth consent configuration and Web OAuth client for the implemented server callback. The callback does not yet exist, so do not invent or register an unverified production redirect URL.
2. Prefer a dedicated GainPath secondary Calendar per Coach with calendar.app.created scope. Existing owned calendars instead need a separately reviewed scope such as calendar.events.owned. The current foundation does not read private personal-calendar conflicts. Request only gmail.send for the gym sender; it does not require inbox-reading access. Scope references: [Calendar authorization](https://developers.google.com/workspace/calendar/api/auth), [Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes).
3. Keep OAuth client secret and refresh tokens server-side in Secret Manager; bind only the connection/delivery handlers that need them. Never store them in Flutter, chat, downloadable configuration or logs. Nonsecret grant metadata must bind organization, actual Google subject, Coach or gym sender, approved purpose/scopes and revocation state. One gym-owned grant serves app-created Coach calendars and the gym sender.
4. Authorize the chosen test account interactively. External OAuth apps left in Testing commonly receive refresh tokens expiring after seven days; plan appropriate publishing/verification or an eligible internal organization configuration before unattended operation. [Google OAuth lifecycle](https://developers.google.com/identity/protocols/oauth2/).
5. Only after connection and permissions pass, expose explicit app confirmation actions over the tested coordinator. First test a designated paid Sandbox booking and consenting recipient. Do not claim delivery success until a real Calendar event and Gmail message are independently verified. The existing Gemini key/free-tier project need not change for this step.

## Changed source

Backend: assistant-booking-tools.ts; chatbot-service.ts/tool registry/context/bounded provider loop; chatbot-callable.ts/authenticated execution and trusted attachments; google-booking-delivery.ts; booking-external-delivery.ts. Focused tests accompany each new unit.

Domain/mobile: BookingSuggestionAttachment in chat_message.dart; clearSessionContext on ChatRepository; FirebaseChatRepository and ChatBloc session context; existing ChatbotScreen card; chatbot_factory.dart and booking_factory.dart handoff; existing LiveMemberBookingView and BookSessionScreen fresh-option selection. Existing financial/provider modules, equipment, availability policy and frozen pose implementation are unchanged by this step.

## Verification and limitations

- 38 focused backend tests passed across six files, including actual Callable handler injection, tool schema allowlists, trusted scope/price/slot, zero booking/payment mutation during inference, revoked Member, public follow-up context, unrelated-answer preservation, unsupported booking claims, Google adapter validation and no duplicate uncertain delivery. TypeScript build and test typecheck passed.
- 32 mobile tests passed across chatbot repository/shared UI, legacy chat Bloc, checkout and live booking composition. Covers explicit review, no hold/payment merely opening a suggestion, fresh price overriding a suggested price, expired/unavailable slot feedback, account drift and clearing late context.
- Two domain contract tests passed. Changed-file mobile and domain analysis passed. No full suites were run. Local Node 24 differs from configured deployed Node 22; actual runtime/provider checks remain deployment UAT.
- Independent read-only security review found two P2s (lost public follow-up context and unsupported confirmation wording), then a hydration-overwrites-unrelated-answer regression. All were corrected with focused tests; reviewer confirmed no remaining actionable P1/P2 in the focused review. A final expired-slot UI test exposed footer-only feedback; feedback now appears immediately in the header.
- Live Gemini inference and list_coaches execution now pass using the disposable Member fixture. Actual slot proposal/checkout owner acceptance, authenticated Admin/provider integration, OAuth connect/revoke and Xiaomi owner acceptance remain pending. Coach pages/tool calls are bounded (20 Coaches per page, four tool calls and five model turns); more pages may require a new request. Default public mode does not send arbitrary personal chat history. Existing free-tier quotas and cold starts remain possible.

## Approved activation scope

Deploy only fitnessAssistantCommand to gainpath-0619, preserving GEMINI_API_KEY Secret Manager binding and public/free data mode. No other Functions, payment setting, policy, Firestore/Storage rules/indexes, Hosting, billing or OAuth resources are included. Do not export Google delivery handlers yet. Existing clients ignore optional suggestion/context fields; the prepared APK renders them. After the Function and notice are verified, use the existing approved in-place Xiaomi update procedure with fresh installed signature comparison and data backup.

The existing Admin chatbot disclaimer configuration must be reused. Owner-approved wording, published as revision 4:

> The AI coach provides general educational fitness and nutrition information. It cannot diagnose injuries, prescribe treatment or replace a qualified professional. Do not rely on it in an emergency. AI can be wrong.
>
> General questions and relevant public gym equipment, Coach names, prices and available session times are sent to Google Gemini. Do not enter sensitive, confidential or identifying information. In default free-tier mode, personal conversation history and personal workout summaries are not sent to Gemini; progress counts are calculated within GainPath. Short-lived booking selections are revalidated against current public options to support follow-up questions. The provider's own data terms apply to submitted questions and responses.
>
> Your conversation and booking suggestions stay in session memory. Clearing chat removes current messages and selection context, but cannot retract information already sent to a provider. Only advice you explicitly bookmark, helpfulness ratings and disclaimer acknowledgement are saved with your account. A suggestion is not a reservation. Review the session in GainPath checkout before choosing to continue to payment. The AI itself cannot take payments, send email or change calendars. Google delivery requires a separately connected account and explicit confirmation and is not active yet.

Owner approved activation. Revision 4 was published with compare-and-swap protection through the existing configuration and version history; revision 3 was preserved.

## Consolidated Manual UAT after activation

1. Review/acknowledge the approved existing notice. Ask for published Coaches and a future 30/60-minute session. Compare public names, price, date/timezone and available slots with the regular Coach booking screen.
2. Ask a short follow-up such as “the 10 am option please”. Verify it uses the selected Coach/date after fresh server reads. Ask an unrelated squat/nutrition question next; it must answer that question rather than replace it with times.
3. Before tapping Review, confirm no booking/transaction exists from the AI request. Review opens normal checkout and refreshes availability/price. Only a separate deliberate Continue action may create a hold/payment. Do not perform a provider payment without explicit test authorization.
4. Wait for expiry or have an authorized test account take the slot. Review must show the stale-time explanation and create nothing; manual current selection remains available. Repeated Review taps must not stack routes.
5. Clear chat/sign out while a reply is pending; no late context, suggestion or former account content may return. Try unknown tool/Member/org/recipient injection and false “booking confirmed” wording; no mutation or false success should occur.
6. Check offline, empty/off-day slots, unavailable Coach, 402/429, quota and unavailable model behavior. Confirm existing equipment/progress/bookmark/rating behavior is intact.
7. Calendar/Email UAT is blocked until connection setup: verify consent owner/scopes, no keys in app, revoke/refresh behavior, one event/message after explicit confirmation, stable Calendar update on approved reschedule and authorized cancellation handling. Simulate lost response; an uncertain Gmail attempt must not resend. Verify actual external delivery before marking this integration complete.

Prepared Firebase debug APK: build/ai-booking-integration/gainpath-ai-booking-firebase-debug.apk. SHA256 34dbc79f7755de1f1719c3d506e5540a0787f9d68b5ee690fe851e674957672d. Signing certificate matches the previous Xiaomi build (38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450). Installed and launched on Xiaomi after a fresh installed-certificate comparison and private-data backup. The installed APK hash matches; private data was byte-identical before launch. APK build flags: BACKEND=firebase, USE_FIREBASE_EMULATORS=false, APP_CHECK_MODE=debug. No Gemini credential was supplied to Flutter.


## Activation verification — 2026-10-22 (owner timezone)

Only fitnessAssistantCommand was updated: ACTIVE, Node.js 22, revision fitnessassistantcommand-00002-bab. All 45 unrelated Functions and existing Firestore/Storage rule releases are unchanged. GEMINI_API_KEY remains bound to Secret Manager version 2 and public/free data mode remains active. Missing App Check and missing authentication both returned 401 UNAUTHENTICATED. A real Gemini answer and real list_coaches tool execution passed; this does not establish a successful real slot proposal or booking. Only the disposable fixture acknowledged notice revision 4. No booking, payment, Calendar event or email was created.

Firebase CLI reported build-image cleanup failure; retained image storage may incur charges. No unapproved registry cleanup or lifecycle change was performed.


## Google project setup — 2026-10-22 (owner timezone)

Owner approved using gainpath-0619 and enabling only Calendar and Gmail APIs. Both changed from DISABLED to ENABLED; the service operation completed successfully. No OAuth client, account grant, Calendar event or email was created. No additional Function or APK deployment was needed for API enablement.

Next external configuration: configure Google Auth Platform branding, audience and support/developer contact using the gym-owned account. OAuth Web client redirect registration must wait for the implemented and verified server callback; do not register a guessed callback. The OAuth callback/connect UI and secure token wiring remain implementation work. Never paste client secrets or refresh tokens into chat.


## Corrected gym-owned architecture — 2026-10-22

The owner explicitly replaced per-Coach OAuth with one gym-owned account. This supersedes earlier connection-choice/setup notes above. See [exact current setup and deployment scope](google-deployment-2026-10-22.md) for the implemented server, shared Admin/Coach UI, recovery limits, focused verification and activation gates. No new Google integration Function was deployed and no external account was connected.
