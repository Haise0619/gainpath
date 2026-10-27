# GainPath supervisor demonstration guide

**Git checkpoint —27 October:** implementation 583773d is pushed to main. The current module-by-module progress, fresh 2,079-test checkpoint results, demonstration route and remaining priorities are consolidated in [PROGRESS_REPORT](PROGRESS_REPORT.md). This source checkpoint makes no new deployment or data changes.

**Owner demo bonuses — CREDITED and ranking package CORRECTED (27 October):**4 active verified Members received 100 spendable points each (400 total), once, with immutable owner_demo_bonus receipts. The first ranking update package incorrectly retained the previous filter: its receipt-projection check validated local source rather than the packaged module. This was reproduced with a package-level test, then corrected by traversing the callable root and replacing the ranking module. The corrected source-only verifiedRewardsCommand is ACTIVE in Singapore with exact source hash/runtime/environment/IAM verified, all 68 other Functions/Rules/indexes/Admin/config unchanged and anonymous401 rejection verified. Package-level weekly/all-time checks now count the100-point bonus;38 affected backend checks also pass. No points were credited again. History labels bonuses Demo bonus; ordinary manual credits remain excluded. Existing check-in/workout receipts, policies, stock and vouchers remain unchanged. Evidence: build/member-demo-bonus-fix-20261027/verification.json and prior credit-verification.json.

**Leaderboard reference UI — INSTALLED after owner approval (27 October):** the connected leaderboard reuses the supplied screenshot’s purple period selector, compact rank-gap banner, silver/gold/bronze2/1/3 podium, rounded rows with initials/formatted points and highlighted own row. All values remain server-confirmed; no trend arrows are fabricated. One/two participants and tied ranks remain supported; outside-top20 Members retain their own row without invented gaps. Accessible announcements identify the current Member as You;320px/double-text checks pass. All12 focused checks and analysis passed; scoped review fixes are covered by regressions. The exact signed UI-only APK is installed/launched in place on Xiaomi7c4cbff, with installed hash/signer and UID/data directory/first-install time preserved; its previous APK is retained. No Firebase, Rules/indexes, Admin, earning-policy, point or voucher change occurred. Phone visual acceptance remains pending. Evidence: build/leaderboard-ui-20261027/verification.json.

**Earned-points Leaderboard — ACTIVE after owner approval (27 October):** the approved source-only update of verifiedRewardsCommand is active in Singapore. Deployed source hash, runtime/environment and existing IAM are verified; all 68 other Functions, Rules/indexes, Admin bundle and captured earning configuration remain unchanged (69 total). The exact signed APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install time preserved and its previous APK retained. Weekly and all-time top20 plus the current Member’s own rank use validated same-organization earned receipts, tied scores share rank, and weeks start Monday00:00 Malaysia time. Check-in, spendable game participation and known workout/game awards count; manual/test credits, redemptions and legacy demo records do not. Paginated bounded scans and canonical authority/source-drift checks avoid partial standings. Public rows contain only display name, rank, earned points and self marker; no other Member IDs, emails or private history. Purple presentation includes own-rank hero, medal rows, period switching, refresh/retry/empty states and small-screen/large-text support. Rewards, Home Ranking and the live legacy dashboard use the scoped real repository. Preparation passed68 focused checks, analysis/typechecks, architecture, signed build and independent review. Anonymous leaderboard requests reject401. No data initialization/migration, earning-policy change, points/stock/voucher transaction or production test claim was performed. Active spendable mini-game/check-in and held Workout/Premium Stage B/C remain unchanged. Signed-in rankings/device acceptance remains pending. Evidence and recovery: build/earned-points-leaderboard-20261027/verification.json.

**Unified spendable points and mini-game journey — ACTIVE after owner approval (27 October):** the owner selected one spendable balance for check-in and mini-game earnings. Both source-only updates, miniGameRewardsCommand and verifiedRewardsCommand, are ACTIVE in Singapore; deployed source hashes, runtime/environment and IAM are verified. All67 other Functions, Rules/indexes and earning configuration remain unchanged (69 total). Owned completed40s Move & Catch rounds can earn20 default points once/game/Malaysia day, with60 shared mini-game points/day, into the existing rewardBalances wallet. Scores stay separate and camera/pose/score stay on device. Stable receipts and atomic shared/per-game caps protect retries and concurrent devices; receipts recover after redemption without re-crediting. The existing shop spends the same points. One purple Points History offers All/Earned/Spent and source filters, without Demo/type labels or long explanations; results link directly to history and returning from games refreshes Rewards. Legacy history clients remain compatible; old demo requests stay held and historical records are not migrated. The private Admin is activated with served hashes verified; its stopped loopback server was restarted. The exact signed APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install preservation verified. Previous source/Admin/APK artifacts are retained. Workspace participation issuance now matches the owner-approved active source. Preparation passed195 affected checks plus one additional post-approval gate regression (196 unique), analysis/typechecks, architecture, independent review and both builds. Anonymous requests to both services return401. No production test round/claim, conversion/migration, policy initialization, stock/voucher mutation or Hosting publication was performed. Daily Check-in 50/day, held Workout Rewards and Premium Stage B/C remain unchanged. Signed-in gameplay/claim acceptance remains pending; enable Earn points for this round before testing a full round. Evidence: build/unified-points-20261027/verification.json. Only the *-final.zip archives are released; unsuffixed intermediate archives are superseded.

**Participation mini-game demo RELEASED after owner approval; production issuance DISABLED (27 October):** the source-only update of miniGameRewardsCommand is active in Singapore; deployed source hash, Node22/60s/max5/512MiB/concurrency1, environment, Auth/App Check and existing IAM are verified. All 68 other Functions, Rules/indexes and captured earning configuration remain unchanged (69 Functions total); anonymous participation requests return401. The private Admin candidate is activated with served hashes verified, and the exact signed APK is installed/launched in place on Xiaomi7c4cbff with hash/signer and UID/data directory/first-install preservation verified. Previous source/Admin/APK artifacts are retained. The owner-selected FYP flow uses owned completed40s sessions for participation, without physical attestation, staff witnessing or camera/landmark uploads. Defaults are20 points once per game per Malaysia day and60 shared across games; scores do not set points and local play/personal bests are unlimited. Any future approved demo credits go only to separate nonredeemable participation balances/receipts/counters. Member UI clearly labels Participation points / Demo · Not redeemable and shows allowance, eligibility and retry states. Production issuance remains hardcoded false: this release performed no claim, balance mutation, policy initialization or production test round. Redeemable balances/shop/vouchers, Daily Check-in 50/day, held Workout Rewards, Premium Stage B/C and Hosting remain unchanged. Preparation passed220 affected checks, analysis/typechecks, architecture, independent review and both app builds; review retry and map-order recovery regressions are covered. Evidence: build/mini-game-participation-20261027/. Signed-in/device participation acceptance remains pending. Separate explicit approval is still required to enable production participation-point issuance; redemption of demo points remains separately unapproved.

**Optional mini-game round timing ACTIVE after owner approval; rewards still DISABLED (27 October):** the isolated miniGameRoundCommand is active in Singapore on Node22/30s/max5/512MiB/concurrency1 with verified Auth/App Check and canonical Member/organization checks. Server-generated attempt/challenge IDs, one cross-device Member lease and ordered idempotent checkpoints constrain timing. The exact signed APK is installed/launched in place on Xiaomi7c4cbff; installed hash/signer, UID, data directory and first-install time are preserved, with its prior APK retained. The timing-sharing checkbox is separate, optional and initially unchecked; ordinary play makes no round calls. Only round IDs, active/paused timing and server timestamps are stored privately; video, pose coordinates and scores stay on device. Timing completion remains awaiting physical verification and awards zero points. All 68 existing Functions, reference IAM, Admin bundle, Rules/indexes and captured content/reward configuration are unchanged (69 Functions total); deployed source hash/runtime and anonymous401 rejection are verified. No seeding, production test rounds, reward-policy initialization, balance/voucher transaction or Hosting change occurred. Preparation passed218 focused checks, analysis/typechecks, architecture and the signed build. The separate reviewer was unavailable; manual review and focused regression evidence are retained, along with an initial emulator contention failure and passing focused run. Evidence: build/mini-game-rounds-20261027/. Signed-in/physical acceptance remains pending. Timing does not prove physical movement; a trusted evidence producer and separate point-issuance release remain required. Current-round retries are in memory only; reset/exit abandons unfinished timing. Daily Check-in, held Workout Rewards, Premium and Stage B/C remain unchanged.

**Mini-game journey ACTIVE after owner approval; reward issuance DISABLED (27 October):** Member Mini-games now uses a featured cover and challenge cards for the one supported Move & Catch game. Details show managed instructions, cover, optional video, scoring and local personal best before camera consent. Results show score/caught/missed/obstacles, save status, Replay and Back to games; unfinished exits confirm and completed exits wait for local-best persistence. Existing responsive tracking and three-second warning are preserved. Admin Content → Mini-games includes a disabled-policy editor: draft 20 points per eligible round, once per game per Member per Malaysia day, with a shared 60-point daily cap. With one supported game the proposed effective maximum is 20/day. Member details/results show confirmed earned/remaining values or unknown totals on failure and Not active eligibility. Future claims require owned server-verified evidence, consumed-attempt receipts, immutable policy snapshots and atomic shared/per-game limits; client scores cannot authorize points. The source issuance gate stays false, accepted verification versions stay empty and no trusted gameplay producer exists. The owner-approved isolated miniGameRewardsCommand is ACTIVE in Singapore on Node22/60s/max5/512MiB/concurrency1 with Auth/App Check and canonical scope enforcement; deployed source hash/runtime are verified. All 67 previous Functions, reference IAM, Rules/indexes and captured content/reward configuration remain unchanged (68 total Functions); anonymous requests return 401. The private Admin is activated with served hashes verified; the exact signed APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID, data directory and first-install time preserved. Previous Admin/APK artifacts are retained. Preparation passed 212 focused checks, analysis/typechecks, architecture, scoped review and both app builds; local backend tests used Node24 while deployment targets Node22. Artifacts: build/mini-game-journey-20261027/. No policy initialization, point transaction, production test data or Hosting publication occurred. Check-in 50/day, held workout rewards, Premium and Stage B/C remain unchanged; Exercise/Routine removal controls stay disabled. Signed-in/physical acceptance and trusted gameplay production remain pending, and point issuance requires separate future work and release approval.

**Mini-game content, activated after owner approval (27 October):** Admin Content → Mini-games → Edit content for Move & Catch. Change its display title/introduction, numbered instructions, cover file or short MP4 preview, then Save changes. New game modes and gameplay/reward settings are system-managed. The prepared Member guide shows saved content, a cover and optional preview before explicit camera consent. Fixed safety/privacy stay visible; the game itself remains unchanged. All 185 focused checks and both app builds pass. The isolated service and private Admin are active, and the exact APK is installed/launched on Xiaomi with app data preserved. Rehearse signed-in uploads/playback and Member device display before claiming acceptance; no production test media or seeded content was created.

**Move & Catch responsiveness, installed after owner approval (27 October):** the prepared fix follows movement faster and supports a visible shoulder/hip pair after full calibration. Move partly toward either edge: the basket follows that side. If tracking disappears, it holds its last position with a three-second warning while the local game continues. Returning in time continues automatically; after timeout use Resume with fresh tracking. Manual pause/background remain immediate. All 45 focused checks and the signed build pass. The approved APK is installed/launched on Xiaomi7c4cbff with app identity/data preserved. Physical motion acceptance remains pending; game scores award no reward points.

**Rewards reference layout, installed after owner approval (27 October):** the prepared APK restores the original purple points card, streak progress, Explore grid and activity styling with confirmed data. Daily claim sits in the streak panel. Mini-games opens Move & Catch; Badges jumps to actual check-in badges; Redeem points opens the shop. My Rewards and Points History remain below the grid, and history is also in the header. Leaderboard remains unavailable. Recent check-ins shows confirmed receipts, while View all activity opens full points history. All 15 focused checks and the APK build pass. The approved exact APK is installed/launched on Xiaomi7c4cbff with app identity/data preserved; phone visual acceptance remains pending.

**Move & Catch, installed after owner approval:** Rewards → Mini-games → Play Move & Catch. Explain on-device privacy, enable the camera, face it with shoulders and hips visible, hold the starting position, then start. Lean gently to catch stars and avoid diamonds for 40 active seconds. Show Pause/Resume, tracking-loss freeze, results and the personal best saved only for this Member on this device. Game scoring awards no reward points. All 38 focused checks and the signed APK build pass. The approved APK is installed/launched on Xiaomi7c4cbff with app identity/data preserved. Physical-camera acceptance remains pending; demonstrate movement before calling it accepted.

**Configurable workout rewards LOCAL ONLY, DISABLED (26 October):** owner-selected draft defaults are 100 points per eligible routine and one claim per Malaysia calendar day. Admin can prepare versioned points, eligible routine IDs, minimum completion/reps/tracked time, daily limits and future Beginner/Intermediate/Advanced amounts; every saved policy remains disabled, with no activation toggle and no difficulty multipliers. Published routine difficulty is preserved when present; legacy absence stays unknown. Routine completion remains separate from the Member summary’s Workout rewards · Not active status. Normal completion uses only a local hold repository, and the prepared status adapter cannot claim points. Future server transactions require a trusted AI-only routine attempt, accepted owned sessions meeting current publication targets and thresholds, no manual/mixed evidence, unconsumed session receipts, stable attempt ID and atomic award/balance/Malaysia-cap updates. Every receipt snapshots its policy/version; retries recover without duplicate credits. Physical release is hardcoded false, accepted model tuples remain empty and the prepared Member callable is not exported from index.ts. Provisional form scores, Premium1.5x and Stage C coaching vouchers remain held; existing daily check-in50/day and issued rewards are unchanged. All 222 focused checks pass (137 backend, 26 Admin, 53 Member, three domain, three local emulator), with analysis/typechecks/architecture, scoped review, private Admin Web and signed Android profile builds. Existing Rules deny forged policy/approval/attempt/cap records from clients. Artifacts: `build/module3-workout-rewards-20261026/`. No deployment, local Admin activation, device installation, Rules/index/IAM, reward-policy/balance/stock mutation or financial/provider operation occurred. Physical workout validation, a trusted routine-entry producer and separate release approval are still required; repeated exercise IDs within a day fail closed until trusted attribution exists.

**Main Rewards Points History entry ACTIVE after owner approval (26 October):** the main Rewards header now offers a history icon with the Points History accessibility label, opening the existing scoped history screen directly. The check-in-only list is renamed Recent check-ins. The shop balance shortcut remains available. Eight focused checks, changed-widget analysis and the Android profile build pass; the APK is retained in `build/module3-history-entry-20261026/`. The owner-approved UI-only APK is installed and launched in place on Xiaomi7c4cbff, with installed hash/signing, UID, data directory and first-install-time preservation verified. Backup/check-in flags remain enabled. No backend, data, Rules or earning changes occurred.

**Member Points History ACTIVE after owner approval (26 October):** tap the Rewards wallet points balance to open newest-first confirmed point movements, with All/Earned/Spent filters, Malaysia timestamps, signed points, source/title and redemption voucher links. The approved read-only pointsHistory action on verifiedRewardsCommand combines owned daily claims, reward awards, manual owner credits and reward redemptions with current canonical Member checks before/after, per-row scope validation and balance-change detection. Each source is capped at 200 with a sentinel that rejects incomplete results; unavailable historical movements are disclosed instead of invented. The isolated source-only update is ACTIVE in Singapore with source hash and preserved runtime/environment/IAM verified. All 65 other Functions, both Rules release references, earning policy and points catalog remain unchanged (66 total); anonymous requests return 401. The exact signed APK is installed/launched in place on Xiaomi7c4cbff with installed hash, signer, UID, data directory and first-install-time preservation verified; backup/check-in build flags remain enabled. Preparation passed 90 focused checks, analysis/typechecks/architecture, scoped review and Android profile build. Artifacts and rollback APK are retained in `build/module3-points-history-20261026/`. No point/earning/stock/voucher mutation, Member transaction, Admin/Hosting change, uninstall or data clearing occurred. Positive signed-in device history/filter/voucher navigation acceptance remains pending.

**Reward cover browser preview fix ACTIVE (26 October):** the user’s saved cover URL was present, returned HTTP200 with image/jpeg and the allowed local origin, and decoded as a valid RGB JPEG. The reward card/editor still used the default canvas image path. They now use the same browser-native Image.network strategy as the existing Exercise/Equipment catalogs, retaining full-image containment and fallback handling. All 21 affected widget checks, changed-file analysis and Web build pass. The private local Admin was updated with served hashes verified and its prior bundle retained in `build/module3-reward-cover-preview-20261026/`. No backend, Rules, upload, reward, points, stock or voucher mutation occurred. This confirms saved-image persistence; browser visual acceptance remains pending.

**Reward cover upload fix ACTIVE after owner approval (26 October):** the previous direct Storage upload was denied because its Rules read three Firestore documents against Firebase Storage’s two-document limit. Covers now use the existing rewardCatalogCommand uploadCover action with App Check, fresh verified Auth and canonical active Admin/organization/session checks before and after upload. The service validates nonempty JPG/PNG/WebP MIME/magic, canonical base64 and <=5MB bytes, controls the uploader path, creates immutable objects and recovers same-content retries by hash/type/size. The Admin preserves upload IDs after uncertain failure and shows upload-specific safe error codes. The approved source-only update is ACTIVE in Singapore with exact source hash and unchanged runtime/environment/IAM verified; anonymous requests return 401. All 65 other Functions, both Rules release references, earning policy and points-catalog data remain unchanged (66 Functions total). The reviewed private Admin is activated with served index/bootstrap/main hashes verified and the previous bundle retained. Preparation passed 48 focused checks, typechecks, analysis, architecture, Web build and scoped review. Evidence: `build/module3-reward-cover-fix-20261026/`. No production test image, Member transaction, existing reward/image/point/voucher mutation, financial/provider, Hosting or device action occurred. A subsequent user upload/save produced a valid persisted JPEG URL; browser preview follow-up is recorded above.

**Points-only rewards ACTIVE after owner approval (26 October):** the normal Admin Reward Catalog removes RM values and the Shop policy panel. Admin sets each reward’s direct points cost; image uploads, stock, validity, membership eligibility and QR collection remain. Both approved source-only updates (verifiedRewardsCommand then rewardCatalogCommand) are ACTIVE in Singapore with source hashes and preserved runtime/environment/IAM verified; anonymous requests return 401. All 64 other Functions and both Rules release references remain unchanged (66 Functions total). The private local Admin is activated with served index/bootstrap/main hashes verified and the previous build retained. Deployment performed no data migration or initialization: the first explicit Admin points-only save/removal creates rewardShops/current and carries forward the existing catalog IDs at their current points costs. Existing earning policy, balances and issued vouchers remain preserved. Confirmed retries recover; stale legacy mutations are rejected after points-only activation. The owner explicitly replaces historical BR-10/UC-11.18 conversion behavior for this journey; original requirements are retained. Preparation passed 143 focused checks (86 backend, 52 Admin, five local emulator), analysis/typechecks/architecture/Web build and scoped review. Evidence: `build/module3-points-only-rewards-20261026/`. No Rules/index, new earning source, financial/provider, Member transaction, Hosting or device action occurred. Signed-in production create/edit/redeem acceptance remains pending.

**Earlier Reward Catalog redesign (26 October; conversion UI superseded by points-only release):** that private Admin release used white/lavender Shop policy panels, purple section icons and responsive reward cards with uncropped images. Add/Edit uses one form; Create reward atomically saves information and inventory without a saved-draft step. Covers use a local JPG/PNG/WebP picker (5 MB), preview and save-time Firebase Storage upload; reward records retain only URLs. Unchanged retries reuse uploaded covers and command identities; edits preserve concurrent stock debits and enforce publication revisions. Removal retires the reward while issued vouchers keep their terms. The exact source-only rewardCatalogCommand update is ACTIVE in Singapore; reviewed source hash, runtime/environment/IAM preservation and anonymous 401 rejection are verified. The bucket gainpath-0619.firebasestorage.app now has the exact rewardImages-only immutable upload overlay, with active verified same-organization Admin, active-organization and lifecycle checks; unrelated Storage Rules and Firestore Rules are preserved. All 65 other Functions remain unchanged (66 total). The prepared private local Admin is activated at localhost:7359 with served index/bootstrap/main hashes verified and the preceding bundle retained. Preparation passed 134 focused checks plus analysis, typechecks, architecture and Web build. Evidence: `build/module3-reward-direct-crud-20261026/`. No reward-policy/conversion/stock population, Member transaction, financial/provider, Hosting or device change occurred. Signed-in browser upload/save acceptance remains pending.

Updated 27 October 2026 from the original 26 October navigation audit and the subsequent approved releases. The latest retained read-only production inventory contains **69 active Node22 Functions:65 Singapore handlers and four US compatibility transports**. The source checkpoint/report update creates no new payments, claims, deployments or device actions. Earlier explicitly approved releases and the four one-time demo bonuses retain their own evidence; this document is not a new end-to-end phone/browser acceptance of every feature.

## Best meeting story

Show how an Admin-authored routine becomes an actual Member workout, saved results and progress. Then show the daily app check-in and the separate coaching/membership workflows. These are stronger demonstrations than touring every screen.

| Priority | Demonstration | Honest description |
|---|---|---|
| 1 | Exercise catalog → routine publication → Member routine | Connected Admin-to-Member content journey |
| 2 | Squat/curl camera session → next exercise → routine summary | Implemented measured workout journey; physical accuracy is still being evaluated |
| 3 | History, progress and resume/repeat | Real account-local results; self-reported work is labelled separately |
| 4 | Daily app check-in | Deployed server-controlled 50-point daily claim, streak and badges; rehearse the first signed-in claim |
| 5 | AI assistant | Deployed educational Gemini assistant, saved advice and booking suggestions |
| 6 | Coach directory, availability and booking history | Connected booking flow with retained owner Module 7 UAT PASS |
| 7 | Membership and Admin payment review | Real Sandbox purchase/renewal evidence and authoritative membership history |

## Architecture explanation for the supervisor

- Flutter provides the Member/Coach Android app and the separate Admin Web console. Firebase Auth identifies the user; role, organization and ownership checks apply to connected data/actions.
- Firestore stores structured profiles, catalog/routine metadata, bookings, membership records and check-in receipts/balances. Firebase Storage holds uploaded images/videos and private documents; media bytes are not embedded in Firestore documents.
- Admin authors exercises and routine blueprints. The trusted publisher creates the Member-readable routine snapshot. Mobile intersects exact registered exercise identity with its installed analyzers; the catalog itself does not train or enable a new model.
- BlazePose and the supported exercise analyzers run on the device. Measured summaries/routine checkpoints are saved locally; optional backup archives them separately from accepted cloud workout evidence. Camera frames are not part of this backup.
- Cloud Functions own sensitive operations such as payment clearance, slot reservation, trusted daily point credit and assistant/provider access. Real-time camera counting does not wait for a cloud request on every frame.

## Every module: functions you can explain and show

### M1 — Member account management

**Connected features:**

- Member registration and sign-in, email-verification gate, password-reset request, sign-out and session isolation.
- Fitness profile and physical details, activity level, experience level and training focus.
- Numeric fitness goals and revision history.
- Contact/profile-photo and account preference changes.
- Password change with reauthentication.
- Account deactivation status and recovery/cancellation of pending deactivation.

**Demo route:** Member → Profile → physical/profile sections, Goals and Settings. Use an existing verified account for the main presentation; email delivery and the full new-account journey need rehearsal.

**Boundary:** Full consolidated owner account UI acceptance is pending. Permanent account purge is disabled. Saving push/email preferences does not establish notification delivery. The Settings copy still says voice coaching is inactive even though the workout screen now has its own implemented voice modes; demonstrate voice from the workout screen.

**Source anchors:** `apps/mobile/lib/features/identity/presentation/member/member_profile_screen.dart`, `account_settings_screen.dart`; `apps/mobile/lib/infrastructure/firebase/member_profile_repositories.dart`, `firebase_member_account_lifecycle_repository.dart`; M1 in [progress report](PROGRESS_REPORT.md).

### M2 — AI workout, routines and equipment

**Connected/installed features:**

- Discover, select and refresh published routines; choose a routine day and exercise; view prescribed set/rep targets.
- Exercise tutorials: overview, complete cover preview, video, difficulty, equipment/setup notes and ordered image/text steps from published snapshots.
- System-owned exact exercise-ID registry determines AI support. Renaming an exercise or uploading a video cannot enable an analyzer.
- Side-view **squat**, standing single-arm **dumbbell curl**, and **wall push-up** routes are installed. Curl supports left only, right only or both arms, with explicit arm switch/recalibration and per-arm targets.
- Camera-first preview with skeleton overlay, compact cues, collapsed/expanded draggable information sheet, pause/resume, end/save and confirmed discard.
- Calibration/tracking-health checks, full/partial reps and provisional form estimates.
- Guided sets, configurable rest, next-set/skip-rest actions, Full Coaching / Alerts Only / Muted, and manual realignment.
- Durable exercise save → next-exercise sheet → fresh setup for the next exercise → routine completion/partial summary. The next exercise starts through an explicit action; it is not a claim that calibration is skipped or one camera session spans every exercise.
- Unsupported exercises use tutorial/manual set completion with undo and resume; they generate no AI rep or form result.
- Interrupted routine checkpoints, completed/partial/skipped/unfinished distinctions, history, Resume, Repeat and Next routine day.
- Opt-in cloud backup/restore of provisional measured summaries and routine checkpoints, with duplicate/conflict protection. Backup defaults off.
- Equipment catalog browsing, equipment image identification through a server-side service, and linked instructional information/video where content is available.

**Demo route:** Admin → Content → Exercise Catalog / Routine Templates, then Member → Workout → select published routine → Start guided session / View routine. Complete a short known squat/curl routine, save, start the next exercise, then show the summary and history.

**Boundary:** Calf raise camera tracking is deliberately held after failed physical trials; it remains Guided only. Human rep/form accuracy and physical latency acceptance are not complete. The server accepted-workout tuple allowlist is empty: local measured results and provisional cloud backup must not be described as accepted cloud workout evidence or workout-earned points. Backup deployment/install is verified, but a positive Member backup/restore trial remains pending. Equipment recognition must find a valid active catalog result; it is not guaranteed for every machine/photo.

**Source anchors:** `apps/mobile/lib/features/workout/domain/exercise_tracker_dispatcher.dart`; `packages/gainpath_domain/lib/src/workout/exercise_tracking.dart`; `apps/mobile/lib/app/routing/routine_journey_route.dart`, `real_squat_route.dart`; `apps/mobile/lib/features/workout/presentation/member/routine_next_exercise_sheet.dart`; `functions/src/modules/workouts/workout-service.ts`, `workout-backup-callable.ts`.

**Reward management UI:** the points-only reward card grid has no RM values or Shop policy. Add reward opens one form with a local image picker, details, points cost, stock, validity and collection conditions. Create reward requires no conversion setup; Edit reward updates it and Remove from shop stops new redemptions while preserving issued vouchers.

**Reward journey active after approval:** Basic/Premium shop → details/explicit confirmation → My Rewards → QR/manual reference → Admin inspect/confirm collection is deployed and installed in the approved private Admin/Xiaomi release. Expired vouchers remain spent. Admin has explicit policy/publication/stock/validity controls, with no seeded live values. Use an explicitly created in-stock reward before redemption. Check-in and participation game points are active; workout points and live physical collection acceptance remain separate.

### M3 — Gamification and rewards

**Active features:**

- Home and Rewards share a server-confirmed point balance and claim status.
- Explicit app check-in: **50 base points once per Asia/Kuala_Lumpur calendar day**, for every active verified Member tier.
- Duplicate/retry/concurrent requests cannot award the same daily claim twice.
- Current and longest streak, seven-day strip and recent immutable claim receipts.
- First check-in, three-day and seven-day streak badges; no extra badge points or Premium multiplier.

**Demo route:** Member → Home → Check in, or Rewards. If already claimed today, show the recorded receipt and claimed state; a second valid daily credit is intentionally unavailable.

**Boundary:** Check-in, Move & Catch participation points, shared spendable wallet, source-filtered Points History, weekly/all-time Leaderboard and the points-only shop/My Rewards/Admin collection journey are active. Create or edit a reward directly with explicit points/stock/terms; no conversion or draft-first step is required. The game awards 20 points once/game/Malaysia day within the shared 60/day cap; replay is unlimited. The recorded 100-point/four-Member demo bonus is one-time. Rehearse signed-in reward/scan/expiry and refreshed rankings; physical workout acceptance, workout points, new streak bonuses, Premium multipliers and Stage C remain held.

**Source anchors:** `apps/mobile/lib/app/routing/app_check_in_host.dart`; `apps/mobile/lib/features/gamification/presentation/member/app_check_in_dashboard.dart`; `functions/src/modules/gamification/app-check-in-service.ts`; `apps/mobile/lib/features/gamification/presentation/member/{mini_games_screen,leaderboard_screen,reward_shop_screen}.dart`.

### M4 — Membership and payment

**Connected and previously Sandbox-tested features:**

- Organization-wide Free, Basic **MYR89 / 30 days**, Premium **MYR129 / 30 days**.
- Current plan, paid expiry, authoritative quote, Billplz Sandbox checkout and verified settlement.
- Manual same-tier renewal preserves remaining paid time.
- Payment/billing history and cleared-payment invoice rendering.
- Refund request/review workflow and Admin membership verification.
- Profile badge and Membership screen use the same current entitlement; unavailable/offline data is labelled.

**Demo route:** Member → Profile → Membership, then billing history / a previously cleared invoice. Admin → Refunds → existing membership payment details. Existing history is enough to demonstrate the flow without making another payment.

**Boundary:** The retained acceptance is Sandbox, not commercial live payment. Recurring billing, Basic-to-Premium conversion/proration and promotion policy are unavailable. Refund transfer is blocked by the unresolved provider HTTP 422; approval is not a completed refund. Actual Xiaomi invoice download/open still needs testing. Premium reward bonuses and Coach voucher benefits remain held.

**Source anchors:** `apps/mobile/lib/features/membership/presentation/shared/membership_dashboard_screen.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_membership_repository.dart`; `functions/src/modules/commerce/membership-payment-callables.ts`; [Sandbox acceptance](integration/module4-sandbox-purchase-renewal-uat-results-2026-10-24.md).

### M5 — Member progress and reports

**Implemented with real local measurements:**

- Home/Progress workout activity and routine-day completion totals.
- Account-local exercise and routine history with dates, targets, source labels and measured/self-reported distinctions.
- Full/partial reps, tracked duration and provisional form trends.
- Workout-performance, activity-timeline and estimated-form views.
- Body/profile facts and numeric-goal comparison where a supported measurement exists; absent data stays unavailable.
- Open a saved result, refresh, resume an unfinished attempt, repeat a routine or open its next day.
- Installed Member report: date/routine/exercise filters, measured reps/time and separate manual sets, compatible form charts and Android PDF save/open. Open Progress → Workout report & PDF. Installation is verified; physical PDF save/open and visual output trial remain pending.

**Demo route:** Finish the M2 routine, then Home → Progress / History / Routine history. Open the result just created, rather than an empty dashboard.

**Boundary:** No inferred lifted kilograms, calories, longitudinal weight change or clinical improvement. Provisional backup is separate from accepted workout reporting. Member PDF now has implementation/build evidence, but actual Android save/open and visual output acceptance are pending; Coach earnings PDF and membership invoices remain separate features.

**Source anchors:** `apps/mobile/lib/app/routing/member_progress_route.dart`; `apps/mobile/lib/features/analytics/data/local_member_progress_repository.dart`; `apps/mobile/lib/features/analytics/presentation/member/goal_comparison_report.dart`; `apps/mobile/lib/features/workout/presentation/member/routine_history_screen.dart`.

### M6 — AI fitness assistant

**Deployed features:**

- Educational Gemini chat with a revision-specific disclaimer acknowledgement and bounded provider/tool calls.
- Equipment guidance and supported progress questions; deterministic progress counts use real available data.
- Explicit saved advice/bookmarks and helpful/not-helpful ratings.
- Session conversation context, clear and account-change guards.
- Coach discovery, availability/options and short-lived booking suggestions that open normal checkout after revalidation.

**Demo route:** Home → assistant entry. Ask a general exercise question, save the response, open Saved tips, then ask for Coach options if the directory has eligible content.

**Boundary:** Requires network/provider quota; full phone UAT remains pending despite retained real provider smoke. A suggestion does not itself reserve a slot, charge money or send Calendar/email. Do not present personal-history sharing to Gemini as broadly enabled; public/free mode omits private progress context. Streaming voice/attachments and permanent full conversation history are not established.

**Source anchors:** `apps/mobile/lib/app/di/chatbot_factory.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_chat_repository.dart`; `functions/src/modules/chatbot/chatbot-callable.ts`; [assistant delivery](integration/module6-ai-assistant.md).

### M7 — Member coaching and bookings

**Connected features with retained owner Module 7 UAT PASS:**

- Eligible published Coach directory, profile/photo, fees, ratings and trusted available booking options.
- Atomic booking holds, payment quote, Billplz Sandbox checkout, expiry, cancellation of unpaid holds and payment resume/recovery.
- Upcoming/past booking lists and booking status/details.
- Participant-only session messaging.
- Member rescheduling and cancellation with server notice limits: 24 hours for rescheduling, 12 hours for cancellation.
- One review after an eligible completed session.

**Demo route:** Member → Coaches → eligible Coach → date/time/options; Home → Bookings → an existing booking → messages/details. Show existing paid Sandbox booking history if available.

**Boundary:** A suitable published Coach and real availability are required. Refund review does not establish money returned. Group/class booking is not a completed capacity feature. The regional migration preserved contracts but did not repeat every financial UAT scenario.

**Source anchors:** `apps/mobile/lib/app/di/booking_factory.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_booking_repository.dart`, `firebase_member_booking_change_repository.dart`; [owner acceptance](integration/module7-booking-completion.md).

### M8 — Coach account and credentials

- Coach account/settings, password recovery/change and session guards.
- Biography, specialties, experience, fee, contact/phone uniqueness and profile photo.
- Private image/PDF qualification upload, bounded preview, certification details/history and archival.
- Admin approve/reject with reasons; explicit directory publication/revocation is separate from credential approval.

**Demo route:** Coach → Profile → edit profile / Settings / Certifications, then Admin → Users & Coaches → Coaches → that Coach → certification decisions and draft/public view.

**Boundary:** Full consolidated Coach phone/browser acceptance remains pending; retained scoped live credential review evidence exists. A qualification approval does not automatically publish a Coach. Role creation/provisioning is not a generic self-service feature to promise.

**Source anchors:** `apps/mobile/lib/app/di/coach_profile_factory.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_coach_account_repository.dart`; `apps/admin_web/lib/infrastructure/firebase/coach_certification_admin_adapter.dart`; `functions/src/modules/coaching/coach-management-callables.ts`.

### M9 — Coach consultation and performance

- Scoped roster/booking details and participant communication.
- Eligible ended/confirmed-session consultation notes with immutable publication and atomic completion; Member can view the notes.
- Coach cancellation and Member coaching-update/inbox read state.
- Separate Member posture-sharing grant/revoke and guarded Coach history access.
- Coach earnings/performance using completed/noted bookings, verified cleared payments and real reviews.
- Android Coach statement PDF export through the destination picker.

**Demo route:** Coach → Roster → an eligible existing session; Coach → Earnings. Member → Home → coaching updates / corresponding booking notes.

**Boundary:** Notes/completion need a legitimate eligible booking; full end-to-end owner acceptance remains pending. Real accepted posture history is constrained by M2's empty acceptance policy. Earnings calculations are not payouts; the retained Sandbox split is 80% Coach / 20% platform. Physical PDF export needs rehearsal. Original client progression/fatigue reporting is incomplete.

**Source anchors:** `apps/mobile/lib/app/di/coach_profile_factory.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_consultation_notes_repository.dart`, `firebase_module9_repository.dart`; `functions/src/modules/coaching/booking-consultation-callable.ts`; [M9 delivery](architecture/2026-10-20-module-9-completion.md).

### M10 — Coach availability and roster configuration

- Organization-local recurring weekly working hours with visible draft preview and save.
- Dated override precedence; Break / Off-day / Leave creation, edit and removal.
- Booking-hour daily capacity and advance-booking horizon.
- Revision/idempotency checks and reservation-conflict handling.
- Member checkout uses the trusted options; Admin can inspect Coach schedule read-only.

**Demo route:** Coach → Availability, then weekly hours, dated exceptions and booking limits. Admin → Coaches → schedule.

**Boundary:** Server/emulator evidence and screen-loading checks exist, but full owner save/reopen/exception/conflict phone UAT remains pending. Technical capacity is bookable hours, not gym occupancy or a Member daily-count restriction.

**Source anchors:** `apps/mobile/lib/features/coaching/presentation/coach/availability_screens.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_coach_availability_repository.dart`; `functions/src/modules/coaching/coach-availability-callables.ts`; [availability workflow](integration/module10-availability-ux.md).

### M11 — Admin account, content and governance

- Independent authenticated Web console with lazy sidebar navigation, account/contact/photo/preferences and password-reset request.
- Member search/directory/details and trusted membership verification.
- Coach draft/public profile, qualifications, decision reasons/history, publication and review alerts; nested booking/schedule views.
- Exercise catalog creation/editing: title/classification/difficulty/status/overview, cover upload, tutorial MP4 upload, equipment notes and up to 12 ordered image/text steps.
- System-derived AI tracking / Guided only labels; full cover preview and saved/local video controls.
- Routine templates: day/exercise structure, prescribed sets/reps, metadata and trusted publication. Save alone does not refresh a published Member snapshot.
- Equipment catalog with image/video workflow, announcements and versioned AI disclaimer.
- Facility/compliance settings and Google integration controls.
- Reward catalog metadata drafts/archive.
- Combined membership/coaching payment review through the separate connected Admin payment route.

**Demo route:** [Local Admin](http://localhost:7359/) → sidebar. Content → Exercise Catalog / Routine Templates is the best link to the Member demonstration. Use the running prepared Admin service; these are sidebar destinations, not standalone URL routes.

**Boundary:** Reward metadata does not enable redemption. Reports and Recommendations have separate incomplete live services. Refund review is not money transfer. Broad account/role creation, permanent purge, complete cross-browser/export acceptance and every content consumer have not been accepted. Admin is a local Web build; do not describe it as public Firebase Hosting deployment.

**Source anchors:** `apps/admin_web/lib/app/shells/admin_shell.dart`; `apps/admin_web/lib/app/di/app_repositories.dart`; `apps/admin_web/lib/features/workout/presentation/admin/{exercise_tutorials_screen,routine_templates_screen}.dart`; `apps/admin_web/lib/infrastructure/firebase/firebase_exercise_media_store.dart`, `firebase_routine_template_repository.dart`.

### M12 — Admin analytics and reports

**What exists:** New prepared base operational reports: current canonical active accounts, booking creation/status/scheduled starts, classified Sandbox receipt totals, Malaysia filters/charts and aggregate CSV. Tests/build and approved deployment/local activation pass; signed-in browser/CSV UAT remains pending.

**Actual normal Firebase behavior:** The scoped Firebase gateway, isolated Admin-only read service and reviewed private local bundle are active after owner approval, with source/served hashes verified. Signed-in report/filter/CSV browser UAT remains pending.

**Workout analytics active:** Dashboard → Workout activity and Reports → Workouts now use the approved read-only backup aggregate endpoint. Show saved camera sessions, routine-day progress, daily/weekly trends, exercise usage, separate manual sets, compatible provisional form estimates and workout CSV. These cover current active Members with retained backups, not all workouts or accepted posture scores. Signed-in browser rehearsal/UAT remains pending.

**Check-in analytics active:** Reports → Gamification uses the separately approved read-only endpoint for confirmed daily claims, distinct claimants, points awarded, daily/weekly engagement, current/longest streak distributions and selected CSV. Streaks are current over all-time history of active Members; claim totals use selected Malaysia dates. This is app engagement, not gym attendance. The 50-point policy is unchanged; signed-in browser rehearsal/UAT remains pending.

**Meeting treatment:** The base operational Dashboard/Reports and CSV are activated; rehearse them in the signed-in browser, labelling receipts as Sandbox amounts rather than net revenue. Posture, occupancy, retention risk, Coach utilization, reward redemption and full M12 remain unfinished.

**Source anchors:** `apps/admin_web/lib/app/di/admin_presentation_dependencies.dart`; `apps/admin_web/lib/features/analytics/application/admin_reporting_gateway.dart`.

### M13 — Recommendations and Coach matching

**What exists:** Risk/content-gap/lead layouts, prototype policies and repository interfaces.

**Actual normal Firebase behavior:** `NeutralRecommendationRepository` returns empty leads/content gaps; no accepted live scoring, matching, Admin dispatch or recommendation outcome pipeline is established.

**Meeting treatment:** Present as planned work requiring supported data and defined scoring. The AI assistant's Coach suggestion is a separate implemented flow; it does not complete M13's risk/content/Coach-matching pipeline.

**Source anchors:** `apps/admin_web/lib/app/di/admin_presentation_dependencies.dart`; `apps/admin_web/lib/features/recommendation/presentation/admin/admin_recommendation_screens.dart`; M13 in [progress report](PROGRESS_REPORT.md).

## Google Calendar and email integration across coaching modules

One Admin-managed gym Google connection supports separate app-created Coach calendars and trusted booking synchronization. Connection/status/manual coordination and automatic confirmation/reschedule/cancellation transports are deployed. Confirmation has retained controlled Calendar/Gmail observation; reschedule/cancellation have provider receipts, with narrower remaining UI-observation checks. This is not a new full post-migration provider acceptance.

For the meeting, show existing integration status and previously delivered booking artifacts if appropriate. A fresh AI chat suggestion does not itself send an email or create an event. Do not use a real appointment mutation merely to demonstrate that the integration exists.

## Suggested 15–20 minute demonstration

1. **1 minute:** explain Member, Coach and Admin roles, and the Flutter/Firebase architecture.
2. **3 minutes:** Admin exercise catalog: show cover/video/steps, AI label and a two-exercise published routine. Explain save versus publish.
3. **6 minutes:** Member selects that routine, views a tutorial, performs a short squat/curl session, expands/collapses stats, saves, starts the next exercise and opens the routine summary.
4. **2 minutes:** history/progress, measured versus manual labels, and resume/repeat. Explain optional provisional backup; avoid promising accepted cloud exercise data.
5. **3 minutes:** daily check-in or today's receipt, Move & Catch introduction/results, shared points/history, and the live reference-style Leaderboard; show My Rewards/QR collection only with an approved redeemable item.
6. **2 minutes:** assistant question and saved tip; Coach suggestions if time permits.
7. **3 minutes:** existing Coach booking/availability and membership Sandbox history; briefly show Admin payment/Coach review.
8. **1 minute:** state remaining physical workout acceptance/workout points, M12/M13 work, broader owner UAT and the known refund limitation.

## Before the meeting

- Rehearse on the installed Xiaomi and the existing local Admin build; have the intended verified Member/Coach/Admin sessions available.
- Confirm the selected routine is published and visible after Member refresh. Ensure cover/video/steps exist in that published snapshot; catalog edits alone do not update it.
- Use squat/curl for the main physical demo and rehearse camera framing/calibration. Avoid calf tracking. Wall push-up is optional after a successful rehearsal.
- Have actual saved history, eligible booking records and Sandbox membership history ready; empty data is not a broken feature, but weakens the presentation.
- Test the first signed-in daily claim before relying on it. If already claimed, show its receipt; the app will not issue a second daily award.
- If demonstrating backup, first rehearse the explicit opt-in and restore/conflict behavior. Installation alone is not a positive backup trial.
- Keep network/provider quota available for video, assistant, check-in and coaching services. Show retained Sandbox evidence if a new payment or email would consume the presentation.

Suggested progress statement: **“The routine workout journey and Admin content workflow are connected. Booking and membership have retained Sandbox/UAT evidence. Daily check-in, the camera mini-game, shared reward points, history, Leaderboard and reward collection flow are implemented. I am validating physical workout accuracy, rehearsing end-to-end acceptance and completing broader reporting and recommendations.”**

## Backend inventory

The following appendix combines the retained inventory with the approved releases through27 October. Frontend and direct Firestore/Storage features do not each require their own Function. Counts are infrastructure records, not a count of completed product features.

| Primary responsibility | Active Functions |
|---|---|
| M1 Member identity (4) | `provisionMemberRegistration`; `getMemberAccountLifecycleCommand`; `requestMemberDeactivationCommand`; `cancelMemberDeactivationCommand` |
| M2 Workout/equipment/backup (5) | `acknowledgeWorkoutConsentCommand`; `revokeWorkoutConsentCommand`; `submitWorkoutSessionCommand`; `identifyEquipmentCommand`; `workoutBackupCommand` |
| M3 Daily app check-in (1) | `appCheckInCommand` |
| M4 Membership (7) | `getMembershipOverviewCommand`; `getMembershipQuoteCommand`; `createMembershipPaymentCommand`; `getMembershipPaymentCommand`; `requestMembershipRefundCommand`; `getMembershipAccessCommand`; `verifyMemberMembershipCommand` |
| M4/M7 Payment transports (4) | `paymentWebhook` (Singapore + US transport); `billplzSandboxReturn` (Singapore + US transport) |
| M6 Assistant (1) | `fitnessAssistantCommand` |
| M7 Booking/communication/reviews/workers (12) | `createBookingHold`; `memberBookingChangeCommand`; `getMemberBookingOptionsCommand`; `getBookingListReadCommand`; `cancelBookingHoldCommand`; `expireBookingHolds`; `getBookingPaymentQuoteCommand`; `createBookingPaymentCommand`; `getBookingPaymentCommand`; `bookingCommunicationCommand`; `submitBookingReviewCommand`; `deliverBookingNotifications` |
| M8 Coach profile/credentials (7) | `saveCoachProfileCommand`; `setCoachDirectoryStatusCommand`; `submitCoachCertificationCommand`; `archiveCoachCertificationCommand`; `reviewCoachCertificationCommand`; `saveCoachAccountSettingsCommand`; `getCoachPublishedPhotoCommand` |
| M9 Consultation/performance (6) | `bookingConsultationNotesCommand`; `cancelAssignedBookingCommand`; `getClientPostureHistoryCommand`; `module9MemberCommandCallable`; `getCoachPerformanceCommand`; `getCoachRatingsPilotCommand` |
| M10 Availability/roster (4) | `getCoachAvailabilityReadCommand`; `saveCoachAvailabilityDayCommand`; `getCoachRosterCommand`; `saveCoachRosterCommand` |
| M11 Admin publication/payment review (4) | `publishRoutineCommand`; `listAdminBookingPaymentsCommand`; `getAdminBookingPaymentCommand`; `manageAdminBookingPaymentCommand` |
| Cross-module Google integration (6) | `googleGymConnectionCommand`; `googleGymOAuthCallback` (Singapore + US transport); `syncGymBookingCommand`; `synchronizeGoogleBooking` (Singapore + US transport) |

M5 uses local measured stores and related shared services. M12 now has the separately approved read-only adminReportingCommand, adminWorkoutReportingCommand and adminCheckInReportingCommand; M13 still has no operational recommendation engine. Four duplicate-name US transports preserve payment/OAuth/event compatibility; they are not four additional user journeys.

| Additional approved responsibility | Active Function |
|---|---|
| M3 reward shop/history/rankings/Admin publication (2) | `verifiedRewardsCommand`; `rewardCatalogCommand` |
| M3 supported-game content, earning and timing (3) | `miniGameContentCommand`; `miniGameRewardsCommand`; `miniGameRoundCommand` |
| M12 Admin operational/workout/check-in reports (3) | `adminReportingCommand`; `adminWorkoutReportingCommand`; `adminCheckInReportingCommand` |

### Source exports that are not live under their old names

| Source export | Actual current position |
|---|---|
| `verifiedRewardsCommand` | Active Singapore points-only shop/history/leaderboard and collection journey. Check-in/game participation use the shared wallet; direct reward CRUD requires explicit stock/terms, without RM conversion. Premium/workout/Stage C holds remain. |
| `getBookingListCommand` | Retired logical endpoint; normal clients select `getBookingListReadCommand` in Singapore. |
| `getCoachAvailabilityCommand` | Retired logical endpoint; normal clients select `getCoachAvailabilityReadCommand` in Singapore. |
| `getCoachRatingsCommand` | Normal clients select the deployed `getCoachRatingsPilotCommand` in Singapore. |
| `getCoachCertificationsCommand` | Authorized direct Firestore reads replace this retired read Function. |
| `getCoachAccountSettingsCommand` | Authorized direct Firestore reads replace this retired read Function. |

The original26 October inventory reached66 Function records after the two-callable reward journey and three M12 reporting services. The later mini-game content, rewards and round services bring the retained current total to69 (65 Singapore and four US transports). Reporting readbacks remain under build/module12-admin-reporting-20261026/, build/module12-workout-analytics-20261026/ and build/module12-check-in-analytics-20261026/; later release evidence is linked from the progress report. No full end-to-end browser acceptance is implied by deployment verification.
