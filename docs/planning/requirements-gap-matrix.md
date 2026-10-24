# GainPath requirements gap matrix

Audit and planning only, 12 October 2026. Repository baseline: `codex/real-squat-flow`, HEAD `162e173e53f9e18ac0e6c2d1e2f47f4640af0d51`. This document changes no application, backend, device, deployment, or acceptance policy. It preserves the original project scope; phase placement is a proposal, not approval to remove or defer a requirement.

The source documents are `C:\Users\Ngzhe\Documents\A-FYP\Final Md file\c1.md`, `c3.md`, and `c4.md`. References below use their filename and one-based text line, not printed page number. Chapter text and UML describe intended behavior, not evidence that it is implemented. The 87 FR titles below reproduce Table 3.35 descriptions, joining text split across extraction lines. Their full normative statements remain in `c3.md:7185–7516`; all 128 use-case identifiers are explicitly retained.

## Reading the evidence

**Software partial** means a real adapter or measured local workflow exists but the complete normative requirement is not accepted. **Prototype** means mock, seeded, simulated, or in-memory behavior; a passing prototype test does not establish Firebase integration. **Unavailable** means the live route is disabled or no real implementation was found. **Unverified** means the audit lacks acceptance evidence. No completion percentage is inferred from code volume, test counts, or screens.

Most requirements have no individual MoSCoW assignment. Only nine FR statements visibly carry a tier: FR-2.1 and FR-5.1 Must; FR-3.4, FR-3.5, FR-7.2, FR-9.2, FR-12.1 Should; FR-3.2 and FR-6.1 Could. FR-2.4 is unmarked in its statement but marked Must in the RTM (`c3.md:7710`), an unresolved source inconsistency. The prose claims fourteen marked requirements (`c3.md:7171`); it does not justify marking every FR Must.

Table 3.11 (`c3.md:1738`) supplies the original baseline: Must = real-time posture correction, on-device inference, personalized progress dashboard, voice corrections, repetition counting; Should = rewards/vouchers, streaks, booking/consultation, four admin operational metrics, coach client-progress metrics; Could = chatbot and motion mini-games; Won't = medical diagnosis and direct facility POS integration. These priorities survive the implementation phases below.

## Objectives and Chapter 4 design keys

O1–O6 are audit aliases for six **unnumbered** Chapter 1 objectives, not new dissertation IDs.

| Alias and original objective | Chapter 1 | FR scope and principal remaining outcome |
| --- | --- | --- |
| O1 Personalized workout guidance | `c1.md:187` | FR-1.7, FR-2.5–2.6, FR-5.5, FR-6.3, FR-11.6, FR-13.1–13.4: profiles and published content exist; actual personalization and recommendations remain P4/P8. |
| O2 Evaluate and integrate pose detection with corrective voice feedback and rep counting | `c1.md:196` | FR-2.1–2.9: real local side-view squat software exists; reference evaluation, physical validation, supported exercise coverage, and trustworthy metrics remain P1–P3/P8. Injury-risk reduction is an objective, not a demonstrated clinical outcome. |
| O3 Gamified environment, motion mini-games, achievements | `c1.md:203` | FR-3.1–3.7, FR-11.7–11.8, FR-12.6/12.8: prototypes; accepted-session rewards P7, optional motion game P9. |
| O4 Professional coach consultation and session/class appointments | `c1.md:210` | FR-7.1–10.4, FR-11.5/11.9, FR-12.4/12.9: identity and backend holds are partial; staff authority P5, consultation and sandbox commerce P6. Explicit class/group booking requirements need clarification. |
| O5 Reporting for members, coaches, administrators | `c1.md:221` | FR-5.1–5.7, FR-9.2/9.6, FR-12.1–13.4: local measured history exists; personalized dashboard P4, coach access P5/P6, real aggregates P8. |
| O6 Flexible mobile coaching across locations | `c1.md:228` | Identity, FR-2, offline continuity and compatibility: no location restriction is evident; device, offline, and usability acceptance remain P2/P10. |

| Design key | Verified Chapter 4 reference |
| --- | --- |
| D1 | Account/profile UI §4.7.1 `c4.md:2036`; sequence §4.8.1 `c4.md:2545`; authentication §4.6.1 `c4.md:1875`. |
| D2 | Workout UI §4.7.2 `c4.md:2113`; sequence §4.8.2 `c4.md:2562`; pose/filter pipeline `c4.md:2765`, tracking health `c4.md:2794`, four-phase FSM `c4.md:2814`, form scoring `c4.md:2838`, audio arbiter `c4.md:2870`. |
| D3 | Gamification UI `c4.md:2162`; sequence `c4.md:2587`; silhouette matching `c4.md:2885`; points/streak algorithm `c4.md:2927`. |
| D4 | Membership/payment UI `c4.md:2202`; sequence `c4.md:2609`; enforcement `c4.md:1923`. |
| D5 | Member reports UI `c4.md:2243`; sequence `c4.md:2629`. |
| D6 | Chatbot UI `c4.md:2280`; sequence `c4.md:2642`; educational boundary in security design. |
| D7 | Booking UI `c4.md:2314`; sequence `c4.md:2651`; concurrency §4.6.4 `c4.md:1971`. |
| D8 | Coach account UI `c4.md:2356`; sequence `c4.md:2664`; authorization `c4.md:1896`. |
| D9 | Coach consultation UI `c4.md:2390`; sequence `c4.md:2677`. |
| D10 | Coach availability UI `c4.md:2406`; sequence `c4.md:2691`. |
| D11 | Admin account/content UI `c4.md:2434`; sequence `c4.md:2697`; enforcement `c4.md:1923`. |
| D12 | Admin reports UI `c4.md:2497`; sequence `c4.md:2726`. |
| D13 | Recommendations UI `c4.md:2517`; sequence `c4.md:2735`; lead scoring `c4.md:2904`. |
| DX | Architecture `c4.md:27`, BLoC `c4.md:153`, data dictionary `c4.md:316`, packages `c4.md:1467`, deployment `c4.md:1799`, security `c4.md:1868`, state diagrams `c4.md:2946`. Command/reactive split and proposed schedulers/triggers are design intent (`c4.md:90–152`). |

## Repository evidence keys

Each FR row cites these source/test groups. Tests establish the behavior exercised by their fixtures/fakes; they do not substitute for physical users, deployed providers, browser coverage, or acceptance measurements.

| Key | Source | Existing verification and limit |
| --- | --- | --- |
| E1 Identity | [mobile composition](../../apps/mobile/lib/app/mobile_app.dart), [Firebase auth repository](../../packages/gainpath_data/lib/src/firebase_auth_repository.dart), [gateway](../../apps/mobile/lib/infrastructure/firebase/firebase_auth_gateway.dart), [member provisioning](../../functions/src/modules/identity/member-provisioning.ts) | [Firebase auth contract tests](../../packages/gainpath_data/test/firebase_auth_repository_test.dart), [auth lifecycle](../../packages/gainpath_data/test/auth_lifecycle_test.dart), [provisioning tests](../../functions/test/member-provisioning.test.ts), [auth errors](../../apps/mobile/test/firebase_auth_error_test.dart). Real provider adapters; end-to-end external mail and complete erasure not accepted. |
| E2 Profile/settings | [profile repository](../../packages/gainpath_data/lib/src/firebase_fitness_profile_repository.dart), [preferences](../../apps/mobile/lib/infrastructure/firebase/firebase_member_preferences_repository.dart), [settings screen](../../apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart) | [profile flow](../../apps/mobile/test/fitness_profile_flow_test.dart), [settings flow](../../apps/mobile/test/member_settings_flow_test.dart). Saved preferences do not prove notification delivery; contact/picture support incomplete. |
| E3 Local measured workout | [real route](../../apps/mobile/lib/app/routing/real_squat_route.dart), [session controller](../../apps/mobile/lib/features/workout/application/real_squat_session_controller.dart), [SquatAnalyzer](../../packages/gainpath_pose/lib/src/squat/squat_analyzer.dart), [CPU detector](../../apps/mobile/lib/infrastructure/pose/blazepose_detector.dart), [real view](../../apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart) | [analyzer tests](../../packages/gainpath_pose/test/squat_analyzer_test.dart), [session tests](../../apps/mobile/test/real_squat_session_test.dart), [UI/history tests](../../apps/mobile/test/real_workout_ui_test.dart), [fixture evaluator tests](../../packages/gainpath_pose/test/squat_fixture_evaluator_test.dart). Camera/CPU BlazePose are real; event fixture and physical reference acceptance remain open. |
| E4 Audio | [audio controller](../../apps/mobile/lib/features/workout/application/workout_audio_controller.dart), [Android audio](../../apps/mobile/lib/infrastructure/audio/android_workout_audio.dart) | [audio scheduling](../../apps/mobile/test/workout_audio_controller_test.dart), [Android adapter](../../apps/mobile/test/android_workout_audio_test.dart), [lifecycle](../../apps/mobile/test/workout_audio_lifecycle_test.dart). Optional Android TTS software; audible timing/intelligibility on a human workout unverified. |
| E5 Persistence/sync | [local store](../../apps/mobile/lib/infrastructure/local/file_workout_session_store.dart), [outbox](../../apps/mobile/lib/features/workout/data/real_workout_outbox_repository.dart), [Firebase gateway](../../apps/mobile/lib/infrastructure/firebase/firebase_real_workout_gateway.dart), [server policy](../../functions/src/modules/workouts/workout-service.ts) | [outbox tests](../../apps/mobile/test/real_workout_outbox_test.dart), [sync UI](../../apps/mobile/test/real_workout_sync_ui_test.dart), [server contract tests](../../functions/test/workout-v2-contract.test.ts). No accepted human workout is demonstrated by this audit; current source enables no tuple (`ENABLED_WORKOUT_TUPLES` is empty at server source line 20). No real-flow server reward is demonstrated. Consent opt-in/outbox are software foundations. |
| E6 Content | [published routine reader](../../apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart), [routine screen](../../apps/mobile/lib/features/workout/presentation/member/routine_screen.dart), [admin catalog](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart), [admin routines](../../apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart), [publish command](../../functions/src/modules/content/publish-routine.ts) | [published routine tests](../../apps/mobile/test/published_routine_test.dart), [admin authoring UI](../../apps/admin_web/test/firebase_routine_authoring_ui_test.dart), [publish tests](../../functions/test/publish-routine.test.ts). Real catalog/routine CRUD and publication; member tutorial playback unavailable, routine assignment/personalization incomplete. |
| E7 Gamification | [in-memory rewards repository](../../packages/gainpath_data/lib/src/gamification/in_memory/in_memory_gamification_repository.dart), [random mini-game](../../apps/mobile/lib/features/gamification/presentation/member/live_mini_game_screen.dart) | [prototype repository tests](../../packages/gainpath_data/test/legacy/gamification/in_memory_gamification_repository_test.dart), [reward policy tests](../../packages/gainpath_domain/test/legacy/gamification/reward_policy_test.dart). Random timer scoring is not motion matching; no accepted-session ledger or real vouchers. |
| E8 Commerce/booking | [booking transaction service](../../functions/src/modules/coaching/booking-service.ts), [webhook](../../functions/src/modules/commerce/payment-webhook.ts), [payment ingress](../../functions/src/modules/commerce/payment-ingress.ts), [in-memory membership](../../packages/gainpath_data/lib/src/membership/in_memory/in_memory_membership_repository.dart) | [booking tests](../../functions/test/booking.test.ts), [payment tests](../../functions/test/payment.test.ts), [prototype membership tests](../../packages/gainpath_data/test/legacy/membership/in_memory_membership_repository_test.dart). Holds exist; app integration absent. Webhook passes an undefined verifier and fails closed; no functioning payment provider/activation/refund integration. |
| E9 Reports | [seeded analytics](../../packages/gainpath_data/lib/src/analytics/in_memory/in_memory_analytics_repository.dart), [measured local history route](../../apps/mobile/lib/app/routing/saved_squat_sessions_route.dart) using E5 persistence/scope | [prototype analytics tests](../../packages/gainpath_data/test/legacy/analytics/in_memory_analytics_repository_test.dart), [measured UI/history tests](../../apps/mobile/test/real_workout_ui_test.dart). Measured history filters real-camera records and guards the account scope. Seeded charts do not aggregate accepted workouts. |
| E10 Chatbot | [in-memory chat](../../packages/gainpath_data/lib/src/chatbot/in_memory/in_memory_chat_repository.dart), [ReplyGenerator](../../packages/gainpath_domain/lib/src/chatbot/policies/reply_generator.dart) | [reply tests](../../packages/gainpath_domain/test/legacy/chatbot/reply_generator_test.dart), [chat repository tests](../../packages/gainpath_data/test/legacy/chatbot/in_memory_chat_repository_test.dart). Local generated/template replies; no third-party LLM/data-aware audit integration. |
| E11 Coach/admin operations | [mobile role gate](../../apps/mobile/lib/app/mobile_app.dart), [admin auth gate](../../apps/admin_web/lib/app/admin_app.dart), [admin DI](../../apps/admin_web/lib/app/di/app_repositories.dart), [coach repository](../../packages/gainpath_data/lib/src/identity/in_memory/in_memory_coach_repository.dart), [availability](../../packages/gainpath_data/lib/src/coaching/in_memory/in_memory_availability_repository.dart) | [admin gate](../../apps/admin_web/test/admin_auth_gate_test.dart), [prototype availability tests](../../packages/gainpath_data/test/legacy/coaching/in_memory_availability_repository_test.dart). Live coach is identity-only. Admin Firebase mode still binds all operational repositories to mocks except tutorial/routine; this is a UI honesty risk, not real authority. |
| E12 Recommendation | [in-memory leads](../../packages/gainpath_data/lib/src/recommendation/in_memory/in_memory_recommendation_repository.dart), [risk policy](../../packages/gainpath_domain/lib/src/recommendation/policies/risk_policy.dart) | [prototype recommendation tests](../../packages/gainpath_data/test/legacy/recommendation/in_memory_recommendation_repository_test.dart), [policy tests](../../packages/gainpath_domain/test/legacy/recommendation/risk_policy_test.dart). No accepted-data evaluator/reactive matching workflow. |
| E13 Architecture/security | [architecture checker](../../tool/check_architecture.dart), [verification script](../../tool/verify.ps1), [CI](../../.github/workflows/verify.yml), [rules](../../firebase/firestore.rules), [backend exports](../../functions/src/index.ts) | Audit coordinator fresh results: mobile 249 pass/15 skip; domain 26, data 77, pose 57 via Dart, identity 19, UI 1, admin 9, checker regression 16 pass; backend 114 unit/28 emulator and TypeScript no-emit pass. Architecture gate fails with 21 current import/tool findings; broad analysis has 38 errors in ignored Step 2m build snapshots; focused maintained-source analysis passes. These are software results, not NFR metric acceptance. |

## Functional requirements: complete original inventory

The “remaining” column names the next acceptance work for the complete statement; a short title does not remove subclauses such as filtering, export, verification, rest intervals, or notice periods. Objective and design keys are defined above. “Unmarked” is implied unless a tier is written.

| FR ID — exact RTM title | Use cases | Objective / design | Evidence / current status | Remaining phase and acceptance work |
| --- | --- | --- | --- | --- |
| FR-1.1 Register New Account | UC-1.1, UC-1.2 | O6 / D1 | E1 software partial | P0/P10 verify registration/provisioning/email unlock across real sessions. |
| FR-1.2 Login to Account | UC-1.3 | O6 / D1 | E1 software partial | P0/P10 end-to-end scoped member login and failure paths. |
| FR-1.3 Recover Password | UC-1.4 | O6 / D1 | E1 software partial | P0/P10 verify secure expiring email flow and non-enumeration. |
| FR-1.4 Deactivate Account | UC-1.5 | O6 / D1 | E2 prototype/unavailable live | P5 implement pending deletion, recovery window, permanent purge and audit. |
| FR-1.5 Manage Account Settings | UC-1.6 | O6 / D1 | E2 software partial | P5 complete credentials/contact preferences; distinguish saved choice from delivery. |
| FR-1.6 Logout | UC-1.7 | O6 / D1 | E1/E3/E5 software partial | P0/P10 verify logout clears scoped session and stops capture/sync requests. |
| FR-1.7 Manage Fitness Profile | UC-1.8, UC-1.9, UC-1.10, UC-1.11, UC-1.12 | O1 / D1 | E2 software partial | P4/P5 complete metrics/goals/experience/picture edits and real personalization inputs. |
| FR-2.1 Start AI-Guided Workout Session | UC-2.1 | O2,O6 / D2 | E3/E4 software partial; Must | P1/P2 evaluate reference fixtures and physical squat/voice quality; P8 approved exercise expansion. |
| FR-2.2 Accept Biometric Data Consent Policy | UC-2.5 | O2,O6 / D2 | E3/E5 software partial | P3 distinguish local capture consent from logged upload consent; device-first-use persistence/revocation. |
| FR-2.3 Pause Workout Session | UC-2.8 | O2 / D2 | E3 software partial | P2/P10 validate pause/resume/end and retained records under lifecycle failures. |
| FR-2.4 View Workout Result Summary | UC-2.9 | O2,O5 / D2 | E3/E5 local measured summary; priority conflict | P2/P3 reference-validate reps/form/duration, truthful local/accepted provenance. |
| FR-2.5 Watch Exercise Tutorial | UC-2.2 | O1,O2 / D2 | E6 prototype; unavailable in live routine | P8 real published instructional media playback/access/error paths. |
| FR-2.6 View Exercise Routine | UC-2.3 | O1,O2 / D2 | E6 software partial | P4/P8 assignment/personalization and correct sets/reps/rest; current screen has fixed 90s rest text. |
| FR-2.7 Review Camera Setup Guidance | UC-2.4 | O2,O6 / D2 | E3 setup gate/guidance partial | P2 demonstrate guidance yields supported side-view framing across users/devices. |
| FR-2.8 Recalibrate Camera Position | UC-2.6 | O2 / D2 | E3 automatic standing recalibration; prototype bounding-box UI | P1/P2 real deliberate position/box adjustment and geometry invalidation; no fake calibration claim. |
| FR-2.9 Toggle Voice Feedback Preference | UC-2.7 | O2 / D2 | E4 on/off partial | P2/P8 Full Coaching/Alerts Only/Muted semantics and audible timing; current real view offers on/off. |
| FR-3.1 Browse Mini-Game Challenges | UC-3.1 | O3 / D3 | E7 prototype | P9 real catalog only when validated motion game exists. |
| FR-3.2 Play Motion-Based Mini-Games | UC-3.2, UC-3.3 | O3 / D3 | E7 random simulation; Could | P9 implement skeleton target matching and measured summary; no reward credit for random demo. |
| FR-3.3 Claim Daily Attendance Reward | UC-3.4 | O3 / D3 | E7 prototype | P7 server-authoritative day/check-in evidence and once-per-day idempotency. |
| FR-3.4 View Gamification Dashboard | UC-3.5, UC-3.6 | O3 / D3 | E7 prototype; Should | P7 accepted activity points/streak/achievements with reconciliation. |
| FR-3.5 Generate Reward Redemption Voucher | UC-3.8 | O3 / D3 | E7 prototype; Should | P7 atomic debit/code issuance, staff manual redemption and expiry. |
| FR-3.6 View Leaderboard Standings | UC-3.9, UC-3.10 | O3 / D3 | E7 prototype | P7 real accepted-score standings and time/peer filters. |
| FR-3.7 Share Achievement to Social Media | UC-3.7 | O3 / D3 | E7 prototype/unverified native integration | P9 native share only for provenance-labelled real scorecard/badge. |
| FR-4.1 Purchase Membership Plan | UC-4.1, UC-4.3 | O4,O6 / D4 | E8 prototype; provider disabled | P6 sandbox gateway checkout/promos and verified activation. |
| FR-4.2 View Membership Dashboard | UC-4.2, UC-4.5 | O4,O6 / D4 | E8 prototype | P6 real tier/renewal/billing/invoice derived from verified transactions. |
| FR-4.3 Cancel Subscription Renewal | UC-4.4 | O4,O6 / D4 | E8 prototype | P6 provider cancellation preserving current paid entitlement. |
| FR-4.4 Renew Membership Subscription | UC-4.6 | O4,O6 / D4 | E8 prototype | P6 idempotent sandbox renewal/reactivation and entitlement transition. |
| FR-4.5 Request Refund | UC-4.7 | O4,O6 / D4 | E8 prototype | P6 eligibility window, staff review and gateway reversal/reconciliation. |
| FR-5.1 View Personalized Progress Dashboard | UC-5.1 | O1,O5 / D5 | E9 seeded; local history E5; Must | P4 real recent activity/consistency aggregates with source and empty states. |
| FR-5.2 View Workout Performance Report | UC-5.2 | O5 / D5 | E9 prototype | P4 real volume/muscle distribution from supported captured fields. |
| FR-5.3 View Posture Accuracy Score Trend | UC-5.3 | O5,O2 / D5 | E9 seeded | P4 validated/versioned form estimates over measured/accepted history. |
| FR-5.4 View Progression History Timeline | UC-5.4 | O5 / D5 | E5 local workout history partial; E9 prototype | P3/P4 accepted history plus real mini-game/milestone events when available. |
| FR-5.5 View Goal Progress Comparison | UC-5.5 | O1,O5 / D5 | E2 goals; E9 prototype comparisons | P4 define measurable goals and compare actual records without fabricated values. |
| FR-5.6 Filter Report Parameters | UC-5.6 | O5 / D5 | E9 prototype | P4 real date-range filters against correct datasets. |
| FR-5.7 Export Performance Report PDF | UC-5.7 | O5 / D5 | E9 unavailable/unverified real PDF | P4/P10 printable device PDF containing current real report/filter/provenance. |
| FR-6.1 Consult AI Fitness Coach | UC-6.1 | O1,O6 / D6 | E10 local replies; Could | P9 third-party AI integration with scoped data and educational safety checks. |
| FR-6.2 Acknowledge Educational Disclaimer | UC-6.2 | O1,O6 / D6 | E10 prototype | P9 persistent once-only versioned acknowledgement before live chat. |
| FR-6.3 Request Automated Progress Audit | UC-6.3 | O1,O5 / D6 | E10 seeded reply | P9 grounded audit from real tracked data and explicit insufficient-data response. |
| FR-6.4 View Bookmarked Advice Library | UC-6.4, UC-6.7, UC-6.8 | O1 / D6 | E10 prototype | P9 scoped persistent bookmark/review/removal. |
| FR-6.5 Clear Conversation Logs | UC-6.5 | O1 / D6 | E10 prototype | P9 clear working memory/display and document retention boundary. |
| FR-6.6 Rate AI Response Helpfulness | UC-6.6 | O1 / D6 | E10 prototype | P9 persist qualitative feedback tied to actual response. |
| FR-7.1 Browse Professional Coaches | UC-7.1, UC-7.2 | O4 / D7 | E11 seeded directory | P5/P6 directory/filter of credential-verified coaches only. |
| FR-7.2 Book Coaching Session | UC-7.3 | O4 / D7 | E8 backend hold partial; Should | P6 member app + availability + sandbox payment confirmation/expiry. |
| FR-7.3 View Booking Schedule | UC-7.4 | O4 / D7 | E11 prototype | P6 real upcoming/past bookings scoped to member. |
| FR-7.4 Reschedule or Cancel Coaching Session | UC-7.5, UC-7.6 | O4 / D7 | E11 prototype | P6 enforce 24h/12h notice and atomic slot/refund transitions. |
| FR-7.5 Message Assigned Coach | UC-7.7 | O4 / D7 | E11 prototype | P6 persist booking-linked messages with member/assigned-coach authority. |
| FR-7.6 Rate Completed Coaching Session | UC-7.8 | O4 / D7 | E11 prototype | P6 completed-only one rating/review per booking. |
| FR-8.1 Login to Account (Coach) | UC-8.1 | O4 / D8 | E1 real identity; E11 identity-only live | P5 verified provisioned coach authority and full account journey. |
| FR-8.2 Recover Password (Coach) | UC-8.2 | O4 / D8 | E1 shared adapter partial | P5/P10 coach recovery/email/security acceptance. |
| FR-8.3 Logout of Account (Coach) | UC-8.3 | O4 / D8 | E1 software partial | P5/P10 clear coach session and stop scoped subscriptions. |
| FR-8.4 Manage Account Settings (Coach) | UC-8.4 | O4 / D8 | E11 prototype/unavailable live | P5 actual credentials/contact updates. |
| FR-8.5 Manage Professional Profile | UC-8.5, UC-8.7 | O4 / D8 | E11 prototype | P5 persistent biography/specializations/picture with publication control. |
| FR-8.6 Upload Certification Documents | UC-8.6 | O4 / D8 | E11 prototype | P5 protected upload, review status and verification audit. |
| FR-9.1 View Upcoming Session Schedule | UC-9.1, UC-9.4 | O4 / D9 | E11 prototype | P6 actual upcoming/pending client bookings and date/client filtering. |
| FR-9.2 View Client Posture History | UC-9.5 | O4,O5 / D9 | E11 prototype; Should | P5/P6 confirmed-booking consent/authority and real versioned member history. |
| FR-9.3 Respond to Member Message | UC-9.6 | O4 / D9 | E11 prototype | P6 assigned-coach-only booking message replies. |
| FR-9.4 Cancel Assigned Session | UC-9.7 | O4 / D9 | E11 prototype | P6 atomic cancellation, notices and policy-bound refund handling. |
| FR-9.5 Generate Post-Workout Consultation Notes | UC-9.2 | O4 / D9 | E11 prototype | P6 notes submission is required for Completed status. |
| FR-9.6 View Performance Metrics Dashboard | UC-9.3, UC-9.8 | O4,O5 / D9 | E11 prototype | P6/P8 real ratings/commission ledger and export summary. |
| FR-10.1 View Availability Calendar | UC-10.1 | O4 / D10 | E11 prototype | P6 persistent hours/blocked-slot calendar and time-zone display. |
| FR-10.2 Set Recurring Working Hours | UC-10.2 | O4 / D10 | E11 prototype | P6 recurring rule persistence and generated bookable windows. |
| FR-10.3 Manage Blocked Time Slots | UC-10.3, UC-10.4, UC-10.5 | O4 / D10 | E11 prototype | P6 create/edit/remove exceptions atomically against confirmed bookings. |
| FR-10.4 Configure Roster Scheduling Limits | UC-10.6 | O4 / D10 | E8 member daily cap is not coach capacity; E11 prototype | P6 coach daily capacity and advance window enforced before checkout. |
| FR-11.1 Login to Admin Account | UC-11.1 | O4,O5 / D11 | E1/E11 real identity partial | P0/P5 retain role/branch authority and mark mock operational panels honestly. |
| FR-11.2 Recover Password (Admin) | UC-11.2 | O4,O5 / D11 | E1 shared adapter partial | P5/P10 verify secure admin email recovery. |
| FR-11.3 Logout of Admin Account | UC-11.3 | O4,O5 / D11 | E1 software partial | P0/P5 revoke local access/subscriptions and clear console state. |
| FR-11.4 Manage Admin Account Settings | UC-11.4 | O4,O5 / D11 | E11 prototype | P5 real settings/credential updates under staff authority. |
| FR-11.5 Manage User Accounts | UC-11.5, UC-11.6, UC-11.7, UC-11.8, UC-11.9 | O4 / D11 | E11 mock operations in Firebase mode | P0 honest gating; P5 real search/provision/deactivate/suspend/credential verification. |
| FR-11.6 Manage Platform Content | UC-11.10, UC-11.11, UC-11.12, UC-11.13, UC-11.14, UC-11.15 | O1,O3,O6 / D11 | E6 catalog/routines real; E11 remaining content mock | P8 tutorial media/disclaimer/announcements; P7 rewards; test each distinct content type. |
| FR-11.7 Process Reward Redemption Voucher | UC-11.16 | O3 / D11 | E11 mock | P7 atomic staff code validation/redemption, expired/reused rejection. |
| FR-11.8 Configure System Settings | UC-11.17, UC-11.18, UC-11.19 | O3,O6 / D11 | E11 mock | P5 compliance text governance; P7 uniform exchange rate/settings history. |
| FR-11.9 Process Refund Request | UC-11.20 | O4 / D11 | E11 mock; E8 provider unavailable | P6 review approval/reason, signed provider reversal and reconciliation. |
| FR-12.1 View Admin Dashboard | UC-12.1 | O5 / D12 | E9/E11 seeded; Should | P8 four R1 operational metrics: hourly facility utilization, posture trends, coach utilization, dropout risk; resolve location-data gap. |
| FR-12.2 View Platform Usage Pattern Report | UC-12.2 | O5 / D12 | E9 seeded | P8 server aggregate rolling usage windows. |
| FR-12.3 View Posture Accuracy Trend Report | UC-12.3 | O5,O2 / D12 | E9 seeded | P8 versioned validated exercise-category form aggregates. |
| FR-12.4 View Coach Booking Utilization Report | UC-12.4 | O5,O4 / D12 | E9/E11 seeded | P8 real confirmed/completed bookings versus declared availability. |
| FR-12.5 View Member Retention and Dropout Risk Report | UC-12.5 | O5 / D12 | E9 seeded | P8 defined transparent disengagement score and real activity window. |
| FR-12.6 View Reward Redemption Report | UC-12.6 | O5,O3 / D12 | E9 seeded | P7/P8 voucher generation/redemption/expiry ledger aggregates. |
| FR-12.7 View Membership and Revenue Report | UC-12.7 | O5 / D12 | E9/E8 seeded | P6/P8 verified transaction/tier aggregate with refunds reconciled. |
| FR-12.8 View Gamification Engagement Report | UC-12.8 | O5,O3 / D12 | E9 seeded | P7/P8 accepted activity and true game engagement counts. |
| FR-12.9 View Coach Performance Comparison Report | UC-12.9 | O5,O4 / D12 | E9/E11 seeded | P8 rating/completion ranking with defined comparability. |
| FR-12.10 Filter Dashboard Report Parameters | UC-12.10 | O5 / D12 | E9 prototype | P8 real date/cohort/category filters over appropriate aggregate data. |
| FR-12.11 Export Dashboard Report Data | UC-12.11 | O5 / D12 | E9 prototype export/unverified real dataset | P8/P10 spreadsheet of currently displayed real filtered report. |
| FR-13.1 View High-Risk Exercise Leaderboard | UC-13.1, UC-13.4, UC-13.5, UC-13.6 | O1,O5 / D13 | E12 prototype | P8 aggregate posture-risk ranking/configurable threshold; educational framing. |
| FR-13.2 View Content Gap Report | UC-13.7 | O1,O5 / D13 | E12 prototype | P8 cross-reference real high-risk exercise evidence with published tutorials. |
| FR-13.3 View Trainer Matching Leads | UC-13.2, UC-13.8, UC-13.9, UC-13.10, UC-13.14 | O1,O4,O5 / D13 | E12 prototype | P8 real available-coach candidates, member eligibility, admin approval/dismissal audit. |
| FR-13.4 View Content Recommendation Leads | UC-13.3, UC-13.11, UC-13.12, UC-13.13, UC-13.15 | O1,O5 / D13 | E12 prototype | P8 relevant real tutorial candidates and persisted approval/dismissal. |

## Non-functional requirements and numbering reconciliation

Canonical IDs below follow the **21 statements in Table 3.34** (`c3.md:7536`). The RTM has **22 concepts** because it inserts offline tracking as NFR-10 at `c3.md:8016`; its IDs from atomic booking onward are one greater. Both sets remain visible. No measured performance, usability, compatibility, or formal compliance target is considered satisfied by this audit.

| Table 3.34 ID | RTM ID | Requirement / source | Design, evidence and current gap | Remaining acceptance |
| --- | --- | --- | --- | --- |
| NFR-1 | NFR-1 | Per-frame pose processing under 33ms (`c3.md:7538`) | D2/DX, E3: CPU pipeline exists; full processing path/physical latency acceptance unverified. | P1/P2 instrument decode/preprocess/inference/postprocess/render/audio separately and prove chosen device budget. |
| NFR-2 | NFR-2 | Server-side coach/admin analytical aggregation (`c3.md:7543`) | D9/D12/D13, E9/E12: client seeded arrays, no real report aggregates. | P8 aggregate correctness/security and realistic dataset performance. |
| NFR-3 | NFR-3 | Loaded-data client filters; no request per change (`c3.md:7548`) | D3/D7/D13, E7/E11/E12: prototype filters only. | P6/P7/P8 assert filter network behavior and loaded-data bounds. |
| NFR-4 | NFR-4 | Authentication/recovery must not disclose account existence (`c3.md:7554`) | D1/D8/D11, E1: generic error handling/tests partial. | P0/P10 real provider errors, email flows and user-visible messages. |
| NFR-5 | NFR-5 | Gateway-hosted isolated Webview handles all card data (`c3.md:7559`) | D4/D7, E8: payment simulation; no provider. | P6 sandbox hosted checkout, inspect logs/cache/navigation for raw-card isolation. |
| NFR-6 | NFR-6 | Signed server webhook alone confirms payment (`c3.md:7569`) | D4/D7/DX, E8: undefined verifier deliberately rejects all ingress. | P6 configure sandbox verifier, tamper/replay tests, bill mapping and entitlement/booking transaction. |
| NFR-7 | NFR-7 | Role-scoped access/data (`c3.md:7575`) | DX, E1/E11/E13: claims/rules partial, live admin operational mocks. | P0/P5 role/branch adversarial tests for every new repository/command. |
| NFR-8 | NFR-8 | Immediate local logout invalidation, authenticated request cessation (`c3.md:7581`) | DX, E1/E3/E5 lifecycle guards partial. | P0/P10 verify capture/outbox/subscription logout races and documented server token expiry behavior. |
| NFR-9 | NFR-9 | On-device inference; no raw video or skeletal streams transmitted; Must (`c3.md:7585`) | D2/DX, E3/E5 local inference and summary-only contracts. | P1/P3 payload/network review, no raw frames/streams in telemetry, diagnostics or sync. |
| No statement ID | NFR-10 | Offline core tracking continuity (`c3.md:8016`; also `c1.md:343`) | D2, E3/E5 local capture/history/outbox partial; automatic server sync not accepted. | P2/P3 airplane-mode capture/restart/reconnect with consent; reconcile wording before renumbering. |
| NFR-10 | NFR-11 | Atomic booking, no double slot allocation (`c3.md:7590`) | D7/DX, E8 transaction holds tested; full booking/payment journey absent. | P6 simultaneous hold/payment/cancel/reschedule tests and expiry worker integration. |
| NFR-11 | NFR-12 | Atomic single-use voucher redemption (`c3.md:7594`) | D3/D11/DX, E7/E11 mock. | P7 concurrent redeem/retry/expiry ledger invariants. |
| NFR-12 | NFR-13 | Audio workout feedback without mid-exercise screen reliance (`c3.md:7599`) | D2, E4 TTS software partial. | P2 human audible/intelligible timely feedback under gym noise and interruptions. |
| NFR-13 | NFR-14 | Accessible nontechnical coaching/chat language (`c3.md:7604`) | D2/D6, E4/E10 strings/prototype replies. | P2/P9/P10 participant comprehension checks across intended language. |
| NFR-14 | NFR-15 | First registration/workout without external support (`c3.md:7607`) | D1/D2, E1/E3 setup flow partial. | P10 first-use task observation, record blockers/time/success; define acceptance before study. |
| NFR-15 | NFR-16 | Android 6/API23 minimum (`c3.md:7616`) | DX, current [Android config](../../apps/mobile/android/app/build.gradle.kts) line 29 uses API26. | P0 reconcile requirement/runtime decision; P2/P10 approved minimum-device coverage. |
| NFR-16 | NFR-17 | Current Chromium and Gecko admin browsers (`c3.md:7620`) | D11/D12/DX, E11 web code exists; no browser acceptance matrix. | P10 real Firefox/Chromium UI, auth, content authoring and export checks. |
| NFR-17 | NFR-18 | Document non-GMS risk; explain failure (`c3.md:7624`) | DX, E1/E3 compatibility behavior unverified; model stack changed. | P0/P10 document actual Firebase/custom-TFLite dependencies and test representative failure. |
| NFR-18 | NFR-19 | Biometric consent/retention compliance per BR-1/BR-3 (`c3.md:7631`) | DX, E5 logged upload consent partial; deletion/purge incomplete. | P3/P5 retention/erasure/consent implementation and formal compliance assessment; no legal assurance here. |
| NFR-19 | NFR-20 | Educational/technical guidance, diagnostic exclusion (`c3.md:7639`) | D2/D6/DX, E3 provisional guidance; E10 prototype. | P2/P9/P10 review all claims/cues/LLM responses; no diagnosis or proven injury-prevention claim. |
| NFR-20 | NFR-21 | Tutorials/routines/disclaimer/rewards editable without release (`c3.md:7647`) | D11, E6 catalog/routines real; others mock. | P7/P8 live publication/versioning for all named content, real member consumption. |
| NFR-21 | NFR-22 | Prefer direct Firestore where server logic unnecessary (`c3.md:7653`) | DX, E6 direct content operations; E8/E5 protected commands. | P0/P5/P8 preserve simple reads/writes, retain server authority for money/rewards/acceptance/concurrency. |

## Business rules: complete original register

| ID / original rule | Governing use cases from Chapter 3 | Design/evidence and gap | Remaining phase |
| --- | --- | --- | --- |
| BR-1 Explicit logged consent before skeletal tracking (`c3.md:6949`) | UC-2.1, UC-2.5, UC-11.19 | D2/D11, E3 local gate and E5 upload acknowledgement; first-use/device local consent logging needs verification. | P3 capture/upload boundaries, version/timestamp/revocation, no assumed consent. |
| BR-2 Educational/technical only; no diagnosis/treatment (`c3.md:6954`) | UC-2.1, UC-6.1, UC-6.2 | D2/D6, E3/E10 partial framing, no live LLM. | P2/P9/P10 review all guidance and evaluation claims. |
| BR-3 Pending deletion retention before purge (`c3.md:6961`) | UC-1.5 | D1/DX, E2 prototype UI; no real purge workflow. | P5 approved retention window, recovery, erasure scope and scheduler audit. |
| BR-4 Coaches provisioned only by Admin Staff, no self-registration (`c3.md:6975`) | UC-11.6, UC-8.1 | D8/D11, E1 member-only self-registration; staff coach provisioning missing. | P5 real privileged provisioning and negative self-registration tests. |
| BR-5 Credentials verified before directory visibility/bookability (`c3.md:6981`) | UC-8.6, UC-11.9, UC-7.1 | D7/D8/D11, E8 requires published coach, but certification-to-publication chain missing. | P5/P6 protected credential review and visibility/bookability enforcement. |
| BR-6 Refund request within seven days (`c3.md:6993`) | UC-4.7 | D4, E8 prototype policy only. | P6 server clock/policy and boundary tests. |
| BR-7 Admin approval before reversal; automatic objectively verified failure exception (`c3.md:6996`) | UC-4.7, UC-11.20, UC-7.3 | D4/D7/D11, E8 provider absent. | P6 define objective failure events and audited idempotent reversals. |
| BR-8 Voucher processed once; Redeemed/Expired rejected (`c3.md:7005`) | UC-3.8, UC-11.16 | D3/D11, E7 mock. | P7 atomic state/ledger and concurrent staff redemption. |
| BR-9 Manual staff code fulfilment; no facility POS integration (`c3.md:7011`) | UC-3.8, UC-11.16 | D3/D11, E7 prototype; exclusion preserved. | P7 staff manual validation journey; direct POS remains outside original scope. |
| BR-10 Admin-set uniform point exchange rate (`c3.md:7018`) | UC-11.18, UC-3.8 | D3/D11, E7/E11 prototype. | P7 server versioned rate applied identically at issuance. |
| BR-11 Reschedule at least 24h before start (`c3.md:7034`) | UC-7.5 | D7, E11 prototype. | P6 server notice boundary/time-zone and atomic new slot. |
| BR-12 Cancel at least 12h before start (`c3.md:7039`) | UC-7.6 | D7, E11 prototype. | P6 server notice boundary/refund/notification handling. |
| BR-13 Coach configured daily capacity and advance window before checkout (`c3.md:7044`) | UC-10.6, UC-7.3 | D7/D10, E8 checks member daily cap and availability, not full original coach policy. | P6 enforce both coach capacity and advance window transactionally. |
| BR-14 Completed only after assigned coach notes (`c3.md:7050`) | UC-9.2, UC-7.8 | D7/D9, E11 prototype. | P6 authorized notes/status transition; no client bypass. |
| BR-15 One rating per completed session (`c3.md:7056`) | UC-7.8 | D7, E11 prototype. | P6 member ownership/completed state and single-rating transaction. |

## Contradictions and decisions requiring reconciliation

| Finding | Evidence | Planning consequence; original requirement retained |
| --- | --- | --- |
| Model specification drift | `c1.md:319–323` selects MoveNet/17 keypoints; `c3.md:2615–2618` specifies ML Kit BlazePose/33; current E3 uses custom TFLite BlazePose. | P0 record approved model/landmark contract; P1 evaluate exact shipped model/input. A different model name cannot be treated as compliance by assumption. |
| API23 promised, API26 built | Table 3.34 NFR-15 and `c3.md:7095`; Android build line 29. | P0 requirement change needs approval or technical support must be restored; P2 validate approved devices. |
| Offline sync promise versus disabled acceptance | `c1.md:343–346` promises automatic reconnect sync; E5 currently keeps results local/queued because server allowlist is empty. | P3 implement reviewed accepted-history sync after P2; distinguish local saved, queued, rejected, accepted. No silent enablement. |
| No skeletal-stream upload versus cloud/history wording | NFR-9 `c3.md:7585` prohibits raw video and skeletal coordinate transmission; UC-2.1 queues joint-angle telemetry for cloud at `c3.md:2564`; UC-5.3 requires historical joint coordinate logs at `c3.md:3656`; UC-9.5 reads shared cloud kinematic telemetry at `c3.md:4842–4867`. | Keep inference/coordinates local, send bounded summaries only. Define allowed aggregate angle/deviation summaries and reconcile coordinate-history obligations explicitly; do not infer permission for skeletal stream upload from a history design. |
| Stationary phone accelerometer is not independent body-motion truth | `c4.md:2824–2830` proposes phone linear acceleration confirming a squat inflection; camera setup props the phone. | P1/P2 record an experiment/design limitation: a stationary camera phone measures its own motion, not the user's reversal. No independent squat-validity claim without body-mounted/other reference instrumentation and approved scope. |
| Generic exercise/form design exceeds present supported scope | `c4.md:2814–2862` proposes rule strategies, valgus/trunk/ROM penalties; E3 real analyzer supports side-view squat depth/trunk, not proven general multi-exercise or frontal valgus assessment. | P1/P2 validate exact squat rule/score; P8 introduce other exercise/view/rule versions only after separate acceptance. Do not claim clinical risk or all-joint correctness. |
| Full three-mode voice versus on/off | FR-2.9 `c3.md:7243`, E3 real view provides voice on/off; E4 has scheduling foundation. | P2/P8 specify and verify required Full Coaching/Alerts Only/Muted behavior. |
| Persistent platform content versus live consumer gaps | FR-11.6, E6 admin catalog/routines real; routine live text says tutorials unavailable; other admin content mocks. | P0 capability labels, P8 real instructional media/content consumption. |
| Admin Firebase mode shows mocked operational repositories | E11 admin DI binds seeded users/coaches/payments/rewards/reports/recommendations except tutorial/routine. | P0 hide/label/gate mock actions; P5–P8 attach real services. Successful login is not evidence of real administrative operations. |
| Reactive design is broader than exported implementation | `c4.md:105–119` describes two schedulers/15 reactive functions; E13 backend exports commands, no complete reactive/scheduled catalog. | P5–P8 implement necessary audited consumers/expiry/purge; avoid describing design functions as deployed. |
| Objective mentions classes; FR model centres individual sessions | O4 `c1.md:217` mentions class appointments, FR-7/FR-9/FR-10 describe selected-coach sessions. | P0 clarify whether class capacity/rosters are required; preserve objective wording until approved scope decision. |
| Coach activation workflow has no numbered Module 8 use case | UC-11.6 `c3.md:5408–5410` requires “Accept Onboarding Invitation and Set Initial Password” before first login, but the seven numbered Module 8 cases do not include it. | P5 preserve provisioning/invitation/initial-password activation as an explicit derived obligation; reconcile UC inventory without silently inventing an official ID. |
| Interview coach metrics exceed narrowed FR titles | R2 requests routine completion, load progression, movement consistency and client-logged fatigue (`c3.md:813–815`); FR-9.2 addresses posture history, FR-9.6 ratings/commission. | P0/P5/P8 reconcile elicited coach dashboard obligations and necessary captured fields. Do not substitute commission charts for the original client progress metrics. |
| Facility utilization cannot be inferred from app usage | R1 requests hourly facility utilization (`c3.md:643`, `c3.md:715`), while UC-12.2 explicitly records no gym-versus-other-location distinction (`c3.md:5965–5966`); Chapter 1 also lists broader engagement/redemption measures. | P0/P8 agree source/definition for occupancy or approve an explicitly labelled app-usage proxy. App traffic is not evidence of facility occupancy; retain four R1 metrics in the baseline. |
| Risk, accuracy and compliance scores lack a single agreed direction/meaning | UC-13.1 ranks ascending average compliance (`c3.md:6283–6288`); matching selects rolling accuracy below a threshold (`c3.md:6697`, `c3.md:6729`); Chapter 4 lead scoring describes risk exceeding a threshold (`c4.md:2909–2913`). Current squat score is provisional depth/trunk evidence. | P1/P8 define score units, direction, denominator, unsupported/absent states and version conversion before ranking or matching. An estimated form score is not a medical risk probability. |
| Matching recipients must remain explicit | UC-13.9 writes a recommendation to the member and expressly does not book for them (`c3.md:6552–6560`); UC-13.12 sends content to the member feed (`c3.md:6636–6643`). Generic “trainer matching leads” wording can obscure recipient/action. | P8 define member recipient, selected coach/content, admin approval, dispatch receipt and member choice; resolve any coach-notification interpretation before implementation. |
| NFR and priority numbering/prose disagree | 21 Table 3.34 vs 22 RTM concepts; nine marked FR vs prose fourteen; FR-2.4 mismatch. | P0 reconcile dissertation identifiers/tiers with supervisor; preserve both NFR mappings and original Table 3.11. |
| “Cross-platform” aspiration versus initial Android scope | `c1.md:312–316` describes Flutter Android/iOS but initial implementation focuses Android; `c3.md:7144` excludes initial iOS. | P10 Android FYP acceptance; P11 iOS only with approved extension. Flutter scaffolding does not establish iOS support. |
| Sandbox gateway was already original scope | `c1.md:336–339` explicitly calls for sandbox/test payments. | P6 implement verified sandbox flow; production finance integration belongs P11. “No real money” does not excuse absent sandbox integration. |

## Proposed remaining phases and gates

Phases sequence dependencies; they do not reassign original priorities. P9 optional work follows the original Could tier. Any proposed FYP deferral, narrowing of exercise coverage, replacement of API23, removal of class booking, or reduced report scope requires an explicit approved change to the baseline. The audit does not grant that approval.

| Phase | Required outcome / exit evidence |
| --- | --- |
| P0 Truthful capabilities and CI | Reconcile source contradictions; label/gate live admin mocks and disabled member features; make maintained-source analysis and architecture gate reliable. Preserve full FR/UC/NFR/BR inventory and approved exceptions. |
| P1 Exact-input diagnostics and event fixture evaluation | Record the exact model hashes/input transformations/coordinate convention; evaluate timestamped pose events against annotated repetitions, partials, loss and form events; distinguish synthetic landmarks, replayed input, recorded frames and physical ground truth. |
| P2 Physical validation | Human squat evaluation with independent annotated reference, camera placement, diversity/occlusion, tracking failure, measured motion-to-feedback latency, rep/form errors, audio and lifecycle results. Freeze accepted model/rule/view tuple only after evidence review. |
| P3 Reviewed server acceptance and history | Reviewed acceptance-policy change after P2, pre-capture consent, revocation/owner/branch checks, idempotent bounded summary upload, restart/reconnect outbox, accepted/history states and network privacy checks. No rewards yet by implication. |
| P4 Real progress | Deliver original Must personalized progress dashboard using real provenance-labelled records, then trends/volume/goals/filter/timeline/PDF. Exclude invented data when unsupported fields/history are absent. |
| P5 Staff/coach identity and authority | Real staff provisioning, credential review/publication, profile media/settings, suspension/deactivation/purge, client-history authorization and truthful admin surfaces. |
| P6 Booking and commerce | Real availability/roster policy and app holds, sandbox signed payments, confirmation/expiry, membership entitlement, cancellations/reschedules/refunds, messages/notes/rating/commission. Concurrency/idempotency/provider failure evidence. |
| P7 Rewards | Accepted-source immutable ledger, server day/streak/idempotent awards, achievements, uniform rate, single-use manual vouchers and real leaderboard. No points from simulated/random sessions. |
| P8 Content, analytics and recommendations | Real instructional content and assignment/personalization, approved exercise expansion, server report aggregates, four original admin metrics, coach metrics, auditable trainer/content recommendation approval. |
| P9 Optional mini-game/chatbot | Validate actual motion matching and third-party educational chatbot with real data/consent/bookmarks/feedback; original Could priority preserved. Deferral still needs approved scope record if original objectives are narrowed. |
| P10 Final FYP demo | Rehearse real member/coach/admin journeys and failure cases; first-use, supported Android and Chromium/Gecko acceptance; collect final evidence against every retained requirement and distinguish remaining exceptions. |
| P11 Production beyond FYP | Production payment/provider operations, wider devices/iOS if approved, operational monitoring/support/security/compliance and scale hardening. These are additions beyond the original sandbox/demo scope, not grounds to omit original FYP functionality. |

Completeness check target: **87 distinct FR IDs, 128 distinct UC IDs, 21 canonical NFR IDs plus the RTM-only offline concept, and 15 BR IDs**. The table is a gap inventory, not a statement that the full system, physical model quality, or non-functional targets have been accepted.

Document verification: identifier scan found 87 full FR IDs and exactly 87 FR table rows; 128 distinct UC IDs match every numbered case in all 13 modules; all repository links resolved. NFR-22 appears only as the final RTM alias, not an invented additional Table 3.34 statement. Existing software test results above were supplied by the audit coordinator; this document-authoring task performed no new device, deployment or provider trial.
