# Module 6 — AI Fitness Chatbot

Implementation date: 2026-10-21, Asia/Kuala_Lumpur. Status: implemented, locally verified and activated with owner approval. Real Gemini reply and equipment read-tool inference passed. Xiaomi installation and physical-device UAT remain pending.

## Implementation

FR6.1: existing ChatbotScreen and saved-advice widgets now serve Mock and Firebase via ChatRepository. Firebase uses one authenticated, App-Check-enforced fitnessAssistantCommand callable and server-side Gemini; no client key or hardcoded live FAQ response. Mock retains existing seeds/rich attachments.

FR6.2: bootstrap reads the existing orgs/{org}/chatbotDisclaimer/config. Inactive, missing or malformed content fails closed. Acknowledgement is revision-specific and enforced on the server, so publishing a new version gates the next operation. The shared dialog also explains external AI use and session retention. No duplicate disclaimer configuration exists.

FR6.3: get_my_progress reads only authenticated-member accepted workoutSessions. Device progress comes from the existing scoped real-camera local progress reader, bounded to 30 sessions within 90 days. Server and device counts are separately labelled; overlapping session IDs are not double-counted. Unavailable data stays unknown. Numeric progress summaries are computed from these facts rather than trusting generated numbers. Estimated pose form is not a medical or diagnostic accuracy measurement. Current summary reports sessions/repetitions, not invented calories, weight change or clinical improvement.

FR6.4: explicit saved advice is durable in the member's chatbot state; add/remove uses the authoritative server list and serializes client mutations. Cap 50 tips, at most 6000 characters each. Saved tips entry and chat bookmark button use the same shared library.

FR6.5: active messages exist only in the screen Bloc. Clear removes messages and ephemeral ratings, invalidates pending replies, and keeps bookmarks. Leaving the screen ends this conversation; identity changes reset the app routes and scoped repository, preventing cross-account late replies. Clearing local chat cannot retract a request already sent to a provider.

FR6.6: thumbs-up/down ratings are persisted with response IDs/timestamps, bounded to the last 100 ratings. Reply bodies are not stored for ratings. UI indicates accepted rating and retries failures.

The only new durable feature document is orgs/{org}/members/{uid}/chatbot/state, containing disclaimer revision, explicit bookmarks, bounded ratings and per-user rate counters. There is no chat-history/message collection. Clients access this state through the callable, not broad new security rules. No existing Firestore rules, indexes, Storage rules or pose functionality are changed by Module 6.

## AI/tool foundation

The native Gemini function-calling loop uses a small registry with tool schemas, per-tool argument validation, read-only policy and data classification. The registry owns validation; new argument-bearing read tools can be added without replacing the loop or UI. Full model content, including function-call thought signatures, is retained during tool turns. Limits: three provider turns, four total tool calls, 15-second provider-request timeout, 60-second Function timeout, ten reply requests/member/minute, two maximum Function instances and ten concurrent requests/instance.

Tools implemented: get_my_progress and find_equipment. The latter returns at most 50 active scoped equipment records with descriptions, usage and safety steps, explicitly marking truncation. Tool access is server-bound to authenticated identity; model arguments cannot choose another member or organization. Canonical membership and lifecycle authorization are checked initially, before tools, and before reply delivery. Mutating tools are never registered. Booking, payment, Google Calendar and Email actions are not implemented or executable. Future tools require their own authorization/consent and data-policy checks.

Medical boundaries use server input/output guards plus the model system instructions: education only, no diagnosis/prescription, no unsafe drug or injury advice; urgent symptoms direct users to appropriate emergency help. These are risk controls, not clinical validation or a guarantee of perfect language understanding.

## Provider policy and secure setup

Default mode is public/free: Gemini receives only the current generic question and nonpersonal approved equipment tool content. It does not receive chat history, device progress or personal-progress tool results. Personal progress is computed inside GainPath. Obvious identifiers and personal medical/measurement disclosures are rejected before an external call. This filter is heuristic and is not a formal anonymization guarantee. Production access requires provider/privacy review, clear notices and appropriate eligibility controls.

GEMINI_CHAT_DATA_MODE=private-approved is an explicit operator-only option for a separately reviewed provider setup that permits personal data; it enables prior history and personal read-tool context. Do not enable this option using an unpaid Gemini project. No user request can override the server mode.

Official Google references checked 2026-10-21:
- [Function calling and signatures](https://ai.google.dev/gemini-api/docs/generate-content/function-calling)
- [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing): gemini-3.5-flash-lite offers a free tier subject to eligibility/quotas, with different provider data use from paid service.
- [Gemini terms](https://ai.google.dev/gemini-api/terms): unpaid-service data may be reviewed; do not submit sensitive, confidential or personal information. Eligible regions and adult-user restrictions also apply.
- [Rate limits](https://ai.google.dev/gemini-api/docs/rate-limits): quota is project-wide, so the scanner and assistant share capacity if they use the same key project.

Existing Firebase project: gainpath-0619. Existing GEMINI_API_KEY secret version 2 is ENABLED; its value was not retrieved. The implementation binds that secret server-side. Default model: gemini-3.5-flash-lite, with GEMINI_CHAT_MODEL available as a server setting. No API key, model URL or Google Gemini credential is supplied to Flutter build flags. Firebase billing, Gemini billing and App Check settings were not changed; no credits were purchased. Firebase Functions usage is distinct from Gemini free-tier eligibility.

Activation procedure (steps 1, 2 and 5 completed on 2026-10-21; see live evidence below):
1. Review and approve a real educational/data-use notice in the EXISTING Admin Chatbot Disclaimer editor. The current inactive revision 2 is explicitly a CRUD persistence test draft that says it must remain inactive; it must not be enabled as-is. Save replacement content and activate it through the existing versioned authoring flow.
2. Approve deployment of ONLY fitnessAssistantCommand to gainpath-0619, region us-central1, with existing GEMINI_API_KEY binding and default public data mode. Review runtime identity's existing Secret Accessor permission; do not broaden unrelated access. No other Functions, rules, indexes, Hosting or billing resources are needed.
3. If the existing free-tier provider/key is ineligible or returns 402/429, stop and review model/provider configuration. Never purchase credits, enable billing or switch to paid usage automatically. For private-context AI, first choose and approve a compliant provider/data policy; do not silently rotate the shared scanner key to a paid project.
4. Build/run the prepared Firebase debug APK with existing Xiaomi debug App Check registration. Installation is not part of this request; use an approved in-place update after fresh signature/data-preservation checks.
5. Verify one real generic Gemini reply and a read-only equipment tool call, then perform the single UAT checklist below. Until then, live inference and feature acceptance remain pending.

## Proposed replacement notice for Admin review

GainPath's AI assistant provides general fitness, equipment and nutrition education. It can make mistakes and is not a doctor, physiotherapist or dietitian. It cannot diagnose an injury, prescribe treatment or replace professional advice. Stop exercising if you feel unwell; seek urgent help for severe symptoms or immediate danger.

General questions are sent to Google Gemini. Do not enter sensitive, confidential or identifying information. In the default free-tier mode, previous chat history and personal workout summaries are not sent to Gemini; progress counts are calculated within GainPath. The provider's own data terms apply to submitted questions and responses.

Your active conversation stays in session memory. Clearing chat removes it from this app's current conversation, but cannot retract information already sent to a provider. Only advice you explicitly bookmark, helpfulness ratings and disclaimer acknowledgement are saved with your account. The assistant cannot make bookings, take payments, send email or change calendars.

This wording was approved by the owner and activated as revision 3 on 2026-10-21. The previous inactive test draft remains preserved in revision 2.

## One consolidated Manual UAT checklist

Run after approved activation with two accounts and a Xiaomi test device; record result/date and error text without keys or private chat logs.

1. Sign in as an eligible verified Member; open AI coach from Member Home. Missing/inactive disclaimer or missing Function must block sending with a clear retry state. Unverified/nonmember/cross-organization requests must be denied.
2. Activate the reviewed Admin notice. First entry shows its exact current wording and the data-use note; sending stays disabled until acknowledgement. Reopening does not demand the same revision again. Publish a new revision and verify acknowledgement is required again.
3. Ask fresh generic fitness, workout-planning, equipment and general nutrition questions that are not FAQ seeds. Confirm a real generated answer and no canned Firebase fallback. In public mode, avoid personal data; test follow-ups knowing provider history is intentionally omitted.
4. Ask an equipment question and verify facts come from active equipment in this organization; hidden or another organization's equipment must not appear. Confirm the answer never claims it changed a record.
5. Request progress with no tracked records, with actual local real-camera sessions, and with an unavailable local store. Compare counts with the existing Progress screen; zero and unknown must remain distinct. Check server/device source labels and bounded-sample wording. Do not expect calories, weight loss or medical improvements to be invented.
6. Ask for another member's records or attempt prompt injection/unknown tools. Request booking/payment/calendar/email changes. Confirm no unauthorized data or side effect occurs. Personal progress remains within GainPath in public mode.
7. Bookmark a reply, reopen Saved tips from both Home and chat, restart/sign back in and verify persistence. Remove it and confirm removal survives reload. At the 50-item limit verify UI matches the retained server list; check another-device update does not disappear after a new mutation.
8. Submit Helpful and Not helpful on generated responses; confirm visible state and persisted response-ID feedback. Verify duplicate taps do not create unbounded duplicates. Do not expect cleared conversation text to be recoverable from ratings.
9. Clear chat normally and while a reply is pending. Confirm no late answer returns, bookmarks remain, and no chat-history collection or response-text log was created. Leave/reopen to confirm the session conversation resets.
10. Sign out or switch accounts while a request/library is open. Verify previous messages, bookmarks, ratings and delayed replies are not visible to the new account.
11. Test offline/network timeout, empty/blocked provider output, unavailable model and 429 limits. Verify sanitized errors and retry, no API keys/URLs in UI or logs, no purchases or silent fallback to paid models.
12. Ask diagnosis, severe-symptom, unsafe drug, extreme-diet and injury-training questions. Confirm educational boundaries rather than diagnosis, treatment or dangerous instructions. Spot-check existing Equipment Catalog/Scanner/Tutorial navigation; frozen BlazePose behavior must remain unchanged.

## Remaining limits

No streaming, audio or attachments were introduced. Public/free mode intentionally does not send prior conversation context or personal metrics to Gemini. Personal summaries are deterministic factual counts, not AI clinical or trend judgments; 100 server-record and 30 device-record bounds are disclosed. English intent/safety/privacy guards are heuristic. Equipment tool is bounded to 50 records with explicit truncation. Bookmarks are capped at 50 and ratings at 100. Real provider and authenticated App Check transport passed the smoke checks below; this does not establish ongoing free quota, account eligibility or Xiaomi behavior. Local tests use injected provider/Firestore ports and shared widget tests; physical-device UAT remains pending.

## Final local verification and prepared artifact

- Backend: **20 focused tests passed** (chatbot.test.ts and chatbot-callable.test.ts). Includes actual callable-handler auth/App Check/role/org/lifecycle/disclaimer guards, secret binding, persisted rate/feedback bounds, read-tool authorization/revocation, provider failures, privacy mode, signed function parts, and personal-metric evidence guards. Provider/Firestore ports are injected; these are not live Google inference tests.
- Mobile: **15 focused tests passed** across Module 6 flow/repository tests and existing legacy chat Bloc regressions. Includes current-notice gating/recovery, shared widgets, API-generated FAQ, bookmark/rating mutations, actual local progress context, account drift, clear-during-request and saved-list cardinality/ordering.
- Shared domain contract: **1 passed**. Existing in-memory repository: **1 passed**. Total: **37 focused tests passed**. No full test suite run.
- Focused source/test analysis: no issues. Functions source/export build and test typecheck passed. Local Node is v24.19.0; configured Firebase runtime is Node 22, so pnpm prints an engine-version warning. Node 22 runtime transport is a live-activation check, not claimed verified here.
- The first APK build exposed an in-memory adapter implementing instead of extending the enlarged contract. That compile failure was corrected, its regression test passed, and the subsequent APK build succeeded.
- APK: `build/module6/gainpath-module6-firebase-debug.apk`, 219,696,207 bytes, SHA-256 `de7d597e74a0de50e13dc7368ad6b7f0e0c8b1f37b2c936be6cb617a93f22247`. Signing certificate SHA-256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`, matching the previously installed Xiaomi artifact. Kernel check found no `GEMINI_API_KEY` define or direct Gemini endpoint. The APK reflects the current shared workspace, including pre-existing changes outside Module 6. It was not installed.
- Initial read-only preflight: existing secret version 2 enabled, fitnessAssistantCommand not yet deployed, existing Admin notice inactive revision 2 with explicitly unapproved test text. Subsequent approved activation is recorded below.
- Independent review findings about personal metric claims and bookmark cache divergence were addressed with additional regression tests. Natural-language intent/safety/privacy guards remain conservative English heuristics rather than a formal semantic guarantee.

## Approved live activation — 2026-10-21

- Deployed ONLY fitnessAssistantCommand to gainpath-0619/us-central1. Readback: ACTIVE, Node.js 22, revision fitnessassistantcommand-00001-bob; GEMINI_API_KEY version 2 bound, public/free data mode. All 44 pre-existing Functions retained their revisions and update times; total is now 45. No rules, indexes, Hosting, Storage, billing, secret rotation or permission grants were deployed.
- Existing Admin notice was replaced with the approved wording above and activated as revision 3, using the existing config and versions/3 paths. Revision 2 remains inactive and preserved. Owner-authorized maintenance used Firebase CLI OAuth and retained the existing Admin author fields; notice-activation.json records this distinction. Readback confirmed the exact approved text in both revision 3 and current config. An initial raw JSON comparison was sensitive to field ordering; subsequent field checks verified the saved state.
- Existing registered Web debug App Check exchange succeeded. Actual deployed Callable rejected missing App Check and registered App Check without authentication (both 401 UNAUTHENTICATED). Existing verified disposable lifecycle-UAT member signed in, bootstrapped the current notice and acknowledged revision 3; only this disposable member's bounded chatbot state was written by smoke testing. No real member chat or metrics were submitted.
- Two real Gemini requests passed: generic progressive-overload education (200 response characters), and catalog equipment guidance (232 characters) with find_equipment in returned sources. Response bodies, credentials and tokens were not stored. This verifies real inference and a scoped read-tool round trip on the deployed Node 22 runtime. Physical Xiaomi UI behavior, actual progress comparison and the remaining checklist are still pending.
- Existing secret/key was reused; no additional API setup is required for this deployment. Free-tier quota is shared with the scanner; 402/429 must remain visible errors and never trigger a purchase or billing change. Do not enable private-approved mode against this unpaid provider.
- Firebase CLI reported successful deployment followed by an unhandled build-image cleanup warning. Build-image cleanup and any retained image storage cost remain unverified; no repository deletion, cleanup policy or billing setting was changed.
- Evidence: build/module6/deployment-readback.json and notice-activation.json. The single prepared APK remains uninstalled; its signing certificate matches the prior Xiaomi artifact. An approved in-place installation and the consolidated checklist above are the next device acceptance steps.

## Changed implementation files

- Shared contracts: packages/gainpath_domain/lib/src/chatbot/entities/chat_message.dart and repositories/chat_repository.dart; in-memory adapter packages/gainpath_data/lib/src/chatbot/in_memory/in_memory_chat_repository.dart.
- Shared mobile UI/state: apps/mobile/lib/features/chatbot/application/{chat_bloc,chat_event,chat_state}.dart and presentation/member/{chatbot_screen,saved_advice_screen,widgets/chatbot_about_sheet}.dart.
- Firebase wiring: apps/mobile/lib/infrastructure/firebase/firebase_chat_repository.dart; apps/mobile/lib/app/di/chatbot_factory.dart; scoped AI coach and Saved tips entries in apps/mobile/lib/app/home/member_home_screen.dart.
- Backend: functions/src/modules/chatbot/chatbot-service.ts, chatbot-callable.ts and the single export in functions/src/index.ts.
- Focused tests: functions/test/chatbot*.test.ts; apps/mobile/test/module6_chat*_test.dart; the existing legacy chat test fake now extends the shared repository; packages/gainpath_domain/test/chat_session_contract_test.dart. Existing in-memory test was run unchanged.
- Plan: docs/superpowers/plans/2026-10-21-module-6-ai-assistant.md. Artifact and sanitized preflight metadata: build/module6/.

## Approved Xiaomi installation — 2026-10-21

Owner approved installation after reporting the old unavailable placeholder. Installed the prepared Module 6 APK using an in-place update on Xiaomi 23013RK75C. Fresh signing certificates matched; private app data was backed up and verified byte-identical before launch. Installed APK hash matched the approved artifact. App launched successfully; no uninstall or data clear occurred. Evidence: build/module6/install-result.json. Chat interaction and the consolidated physical-device UAT checklist remain pending.
