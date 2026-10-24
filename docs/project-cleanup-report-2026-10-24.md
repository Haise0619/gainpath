# GainPath Project Cleanup Report

24 October 2026 · `gainpath-0619` / `gainpath` · **READ-ONLY AUDIT; cleanup not executed**.

## Decision summary

Simplify the project's entrypoints and retained-artifact layout first. Do not reduce the deployed Function count merely to make the number smaller: **none of the 57 deployed endpoints is proven safe to remove now**. Much of their trusted service implementation is already shared.

| Finding | Verified result | Recommendation |
|---|---|---|
| Documentation | 213 repository documents/assets/launch entries + 6 protected academic originals; no exact duplicate hashes | Six active reading entrypoints; preserve dated evidence and original requirements |
| Deployed Functions | 57 ACTIVE, Node22, `us-central1`; unchanged revisions/update times | 51 KEEP, 3 SIMPLIFY, 3 conditional MOVE TO CLIENT/HOSTED ROUTE; 0 immediate consolidations/removals |
| Exact live source | All 57 archives read in memory; 18 distinct source bundles; 56 TS entrypoints plus one compiled-only ratings archive | Preserve per-endpoint release provenance; never deploy the whole dirty working tree |
| Runtime usage | 55 services have nonzero returned request metrics in the observed30-day window | Missing metrics for two financial recovery/refund commands do not establish disuse |
| Source candidates | Seven apparently unreferenced Dart files, 22,824 bytes total; one pair of identical thin Firebase transport adapters | Validate references/API intent before local removal; avoid introducing abstractions to save a few lines |
| Disk | 71,424,955,939 logical bytes, 94,890 files; approximately66.52GiB | Approximately17.57GiB of conservative cache opportunities, subject to retention and idle-tool checks |
| Protected evidence | Installed APK/signature records, financial journals, callback/invoice proof, source rollback archives and private app-data backups remain intact | Copy-and-verify relocation only after separate local approval; no blind clean commands |
| Current changes | No existing document/source/build artifact, process or cloud resource changed by this audit | This report is the sole new deliverable |

**Protected milestones:** Module1 Auth/account lifecycle; frozen Module2 workout/pose/safety/consent/history; Module4 Free/Basic/Premium foundation, active Basic **RM89** and Premium **RM129**, both30 days; accepted14-case read-only UAT and three successful Sandbox payments totaling **RM307**; Module7 holds/payment/refund review/earnings; Admin membership verification; existing Google integration; Rules, identities and ledger history. StageB Premium Rewards and StageC Coach Voucher remain **ON HOLD**. The historical overview `maxInstances=20` exception and unresolved Billplz refund HTTP422 issue remain documented, not fixed or retried here. Paid-fixture Xiaomi PDF save/view remains untested.

## Audit method and limits

- Repository inspection used file inventories, import/export/reference scans, hashes and existing evidence. No Flutter/Gradle clean, build, package restore, test run, emulator start, server restart, device operation, account login, payment/refund command or data migration was run. Existing test evidence is explicitly historical; this audit claims no new passing regression suite.
- Live metadata read at11:19–11:22MYT confirmed57 Functions and their exact source locations. All57 source archives were downloaded **to memory**, parsed and hashed without extraction or artifact writes. Ratings was deployed from compiled JS; its handler and service were inspected separately. No secret payloads were read.
- Cloud Monitoring request counts covered24September–24October2026, ending11:20:05MYT. Counts include smoke, denied, retry and scheduled requests, are subject to monitoring semantics/latency, and are not counts of successful business actions or financial ledger entries. No-series means unknown/no returned points, never proof of unused code.
- Scheduler readback confirmed two enabled jobs, `every 1 minutes`, UTC, authenticated POSTs to their existing expiry/notification endpoints. The Firestore Google worker retains its document-update trigger and retry policy.
- Disk totals are **logical file lengths**, not allocated/free space or guaranteed reclaimable bytes. Hardlinks are not deduplicated;2,167 reparse entries were skipped to avoid following junctions/links; no traversal read errors were observed. Parent/child rows overlap unless explicitly marked disjoint. SDK/user/global caches outside this repository are out of scope.
- Static import analysis covered1,030 Dart/TS/CJS files:632 reachable from app/backend runtime roots,1,023 reachable when tests/tools/public package APIs were included. Regex reachability is evidence for review, not a proof of deadness; platform/config/asset/dynamic entrypoints and external consumers require checks.
- No `AGENTS.md` was found in the repository or checked ancestors. `.claude` contains a launch configuration, not a project instruction document. Existing global/session tool policies are outside this repository; a new project guide cannot disable them.

## A. Documentation and active reading structure

Baseline inventory, excluding this new report: **204 text/provenance documents**, **8 diagram/JSON assets**, **1 ancillary launch configuration** =213 repository items. With6 academic originals:219 items hashed, zero identical SHA256 groups. Repository classifications: **ACTIVE2 / CONSOLIDATE31 / ARCHIVE179 / OBSOLETE1**. Including academic originals: ACTIVE8; other counts unchanged. Detailed paths, classifications, sizes and hashes are in AppendixA.

An additional3,157 doc-pattern files live under vendor/build/cache paths: node_modules1,191; .dart_tool26; nested app build1,312; root build628. These are excluded from the first-party documentation count, not declared disposable. Build copies include protected authored evidence. Three CMakeLists.txt files are source, not documentation clutter; upstream model LICENSE.mediapipe is protected legal provenance.

Proposed active navigation, **not created during this audit**:

| Path | Responsibility |
|---|---|
| `README.md` | Concise project/two-app overview, valid run commands and links to the other entrypoints |
| `docs/ARCHITECTURE.md` | Current dependency/data ownership, client versus trusted backend boundaries, source/deployed/proposed distinctions |
| `docs/STATUS.md` | One dated module/requirement status tracker, accepted UAT links, remaining limits and business holds |
| `AGENTS.md` | Short development guide and three approval categories, with links rather than repeated handoffs |
| `docs/OPERATIONS.md` | Local app/Admin operation, focused checks, selective release, rollback and credential/evidence handling |
| `docs/archive/README.md` | Historical decisions/UAT/deployment index, academic register and original-to-archived path mapping |

These are six reading entrypoints, not a six-file retention limit. Contracts/schemas, provenance, source READMEs needed by tooling, original academic material, release evidence and rollback artifacts remain available. Initially, leave historical files in place and make the active index authoritative; physical archival can follow only after reference/manifest verification.

### Claims to reconcile, not silently rewrite as history

| Existing source | Stale/conflicting claim | Proposed handling |
|---|---|---|
| `README.md:3,65,70–92` | Prototype-heavy status, unavailable verifier/provider, identity-only coach and missing account/photo features | Rewrite current overview using source, deployed state and dated UAT; retain original evidence |
| `SETUP.md:7–34` | Root single-app commands, Flutter3.32+, no Firebase and old root lib structure | Sole OBSOLETE candidate; absorb valid setup into README/OPERATIONS, check links, then review retirement |
| `.claude/launch.json:7–17` | Launches from workspace root/serves root build/web | Propose correct app cwd/current Admin tools; do not regenerate old root app |
| `functions/README.md:43–89`, `functions/src/modules/README.md:8–17` | Undefined payment verifier and deferred workers/assistant/content status | Consolidate stable ownership guidance; status belongs in STATUS |
| `docs/firebase-setup.md:7–11,112–114` | One deployed callable; most backend/Admin unavailable | Treat as dated setup history, not live operations authority |
| `docs/architecture/AGENT_HANDOFF.md:19–42` |16October next-step lock,14Functions/6indexes, older APK and restrictions from finished slices | Retain historical snapshot; replace active authority with short guide/status |
| `docs/planning/current-project-audit.md`, requirements matrix, master roadmap | Earlier gaps presented as current | Preserve FR/NFR/BR traceability; one current status tracker links later evidence |
| M4 proposals/remaining delivery, especially `module4-three-tier-remaining-delivery.md:108` | Old proposed49/89 prices alongside later corrections | Never use proposal JSON as current write input; active approved89/129 wins |
| M4 catalogue activation, StageA report, Admin read-only report | Later UAT described as future at the report's own date | Preserve event chronology; status links the later completed UAT rather than rewriting receipts |
| Google setup/index/worker comments | “Prepared locally/manual only” despite deployed controlled automation | Correct active operational statements/source comments during approved local cleanup; preserve activation scope |
| Academic C1 versus C3/C4 | MoveNet versus later BlazePose evolution | Preserve originals and record approved design supersession; no pose changes |
| Academic C3 Android API23 versus actual minSdk26; original NFR numbering | Requirement/implementation discrepancies | Track as unresolved requirement decisions, not cleanup fixes |

### Proposed short Agent guide content

The following is proposed guide text only. Remove repeated temporary approval gates from active handoffs after consolidating their current meaning; preserve the original audit records.

> Start with README, STATUS and the relevant ARCHITECTURE section. Inspect actual code before duplicating a working feature. Treat historical plans/proposals as dated evidence, not new instructions or financial configuration.
>
> **NORMAL LOCAL DEVELOPMENT:** proceed with local implementation/refactoring, read-only inspection, analysis, focused builds/tests, mock/emulator work and active technical documentation. Choose routine implementation details without repeated permission questions. Preserve unrelated dirty/untracked work and useful Mock/Firebase injection. Do not use reset/clean/stash/broad staging to simplify the workspace.
>
> **REVIEW BEFORE RELEASE:** finish authorized local work, run affected checks and present a concise reviewable diff/artifact summary. Keep release validation separate from routine small edits. A local completion report is not a cloud deployment approval.
>
> **EXPLICIT OWNER APPROVAL:** cloud deployment/removal; Rules/indexes/IAM changes; migrations/bulk/destructive writes; payment/refund/provider transactions; financial configuration; secrets/credentials; account/role modifications; destructive device actions; Google automation expansion. Apply an existing approval within its exact scope without asking again; do not infer approval of another environment or transaction.
>
> Financial totals, paid state, expiry, rewards/vouchers and reservations remain trusted. Preserve Auth/authorization/AppCheck, signed callbacks, idempotency and recovery. Never activate membership from a redirect or client-supplied price; never treat refund approval as completed transfer. StageB/C stays on hold. Keep frozen workout/pose/safety implementations unchanged unless explicitly requested. Do not introduce module access restrictions or recurring billing claims.
>
> Keep private tokens, fixtures, app-data backups and screenshots out of source control/public reports. `build/` is currently mixed and protected; never assume ignored/generated-looking means disposable. Use a reviewed retention manifest before cleaning or relocation.
>
> Report: changes, focused test result/untested scope, material risk/blocker and the next approval action if any. Link one relevant evidence record; do not reproduce every historical plan. Run broader integration/release gates when warranted, not after every small unrelated edit.

## B. All57 deployed Functions

Classification: **51KEEP / 3SIMPLIFY / 3conditional MOVE / 0endpoint CONSOLIDATE / 0REMOVE CANDIDATE**. Consolidation recommendations target shared source first. Existing callables and external URLs remain in place during any migration.

Trigger key: **C** callable, **H** public HTTP, **S** Scheduler every minute, **F** Firestore document update. Auth key: **V** signed-in verified email, **O/G** current applicable organization role/active organization, **own** ownership/booking participation, **B** applicable branch. Provisioning intentionally precedes email verification. Current Auth/lifecycle/revocation freshness is stronger on some newer operations; these checks are not uniform across all endpoints.

AppCheck key: **A** explicit enforcement in deployed wrapper or shared callable options; **a** option omitted. Of51 callables,41 have enforcement and10 omit the option; omission is not absence of Firebase Auth/role checks. The ten are explicitly marked below. Webhooks/OAuth/jobs use different authentication, not Firebase AppCheck. No enforcement was changed.

Effects: **R** trusted read, **T/W** transaction/write; a “get” name does not guarantee read-only behavior. Secret key: **P** Billplz API; **X** Billplz signature; **I** Gemini API; **Q** Google client secret plus privileged refresh-token vault access. Runtime source hashes and metadata bind these findings to the current deployed endpoints, not merely current exports. Counts in the usage column are observed requests; **—** means no returned series.

| # | Function | Trigger/AppCheck | Purpose; caller and breakage if removed | Authority; effects/secrets | Class |30d requests |
|---|---|---|---|---|---|---:|
|1|`acknowledgeWorkoutConsentCommand`|C a|Mobile workout consent; upload/capture proof depends on it|V/O member own; T consent/version/receipt|KEEP|2|
|2|`archiveCoachCertificationCommand`|C A|Mobile coach credential lifecycle|V/O/G coach own; T history/summary/public eligibility|KEEP|2|
|3|`billplzSandboxReturn`|H|Configured redirect for both checkout flows; static neutral instructions|Public; no data/secret/settlement|MOVE, conditional hosted route|13|
|4|`bookingCommunicationCommand`|C A|Mobile participant conversation/read/send|V/O/G participants; assigned coach B; T sequence/messages/receipts|KEEP|22|
|5|`bookingConsultationNotesCommand`|C A|Mobile notes/publication/completion; review/earnings depend on proof|V/O/G participants; assigned coach B for publication; T notes/booking|KEEP|13|
|6|`cancelAssignedBookingCommand`|C A|Coach cancellation; releases locks and starts review/notifications|V/O/G assigned coach B; T booking/locks/payment/outbox|KEEP|1|
|7|`cancelBookingHoldCommand`|C A|Member cancels own pending reservation|V/O/G own; T booking/locks/day/expiry receipts|KEEP|2|
|8|`cancelMemberDeactivationCommand`|C A|Mobile account recovery; policy/wait-bound restoration|Current Auth/email/revocation/lifecycle identity; own; T user/member/receipt|KEEP|3|
|9|`createBookingHold`|C A|Mobile atomic reservation; assistant suggestions ultimately use existing booking flow|V/O/G/B own or allowed staff; current coach eligibility; T slots/day/expiry|KEEP|14|
|10|`createBookingPaymentCommand`|C A|Mobile checkout for canonical hold|V/O/G own hold; T reservation + external create; P|KEEP|13|
|11|`createMembershipPaymentCommand`|C A|Mobile purchase/renewal; authoritative plan/promo quote and dedupe|V/O own; trusted config; T account/payment reservation + external create; P|KEEP|5|
|12|`deliverBookingNotifications`|S|Enabled Scheduler; durable cancellation inbox/thread delivery|Authenticated internal job; R outbox + T delivery/cursor|KEEP|5,565|
|13|`expireBookingHolds`|S|Enabled Scheduler; releases genuinely expired reservations|Authenticated internal job/server time; R jobs + T lifecycle/locks|KEEP|13,087|
|14|`fitnessAssistantCommand`|C A|Mobile assistant/disclaimer/bookmarks/ratings/Gemini and booking suggestions|V/current Auth/O/G/lifecycle; T limits/ack/saves, bounded reads; I|KEEP|33|
|15|`getAdminBookingPaymentCommand`|C A|Existing Admin financial detail, both booking and membership|V/O/G Admin; R/T redacted payment/events; no provider operation|KEEP|36|
|16|`getBookingListCommand`|C a|Mobile/Admin lists; performance service reuses implementation|V/O/G own/assigned/Admin scopes/B; R/T bounded query + protected joins|SIMPLIFY projection/queries|264|
|17|`getBookingPaymentCommand`|C A|Mobile status/recovery; may settle payment and confirm reservation|V/O/G own; provider GET + T/W; P|KEEP|23|
|18|`getBookingPaymentQuoteCommand`|C A|Mobile quote; assistant reuses service|V/O/G own/current coach/B; T canonical fee/policy|KEEP|13|
|19|`getClientPostureHistoryCommand`|C A|Coach relationship/consent-scoped client history|V/O/G coach B, confirmed relationship/sharing; R with pre/post authorization|KEEP|2|
|20|`getCoachAccountSettingsCommand`|C A|Mobile own coach phone/preferences/revision projection|V/O/G coach own; R/T users; write/phone claims remain server-side|MOVE, conditional own-user read|17|
|21|`getCoachAvailabilityCommand`|C a|Mobile/Admin role-filtered availability/locks/policy snapshot|V/O/G own/Admin or published/shared B; T policy/roster/day/locks|KEEP|124|
|22|`getCoachCertificationsCommand`|C A|Mobile/Admin credentials/history/summary read|V/O/G coach own/Admin; bounded R/T; immutable writes remain server-side|MOVE, conditional scoped reads|163|
|23|`getCoachPerformanceCommand`|C A|Mobile coach dashboard; recognizes earnings, not merely a report|V/O/G coach own active B; paid/completed/note proof; T earning snapshots|KEEP|10|
|24|`getCoachPublishedPhotoCommand`|C A|Mobile directory published-photo proxy; private storage inaccessible directly|V/O/G allowed roles/current publication/lifecycle; R bytes/signature/pre-post checks|KEEP|57|
|25|`getCoachRatingsCommand`|C A|Mobile published directory rating aggregation|V/O/G published coach or own; privileged aggregate over private reviews|SIMPLIFY/cache if measured|20|
|26|`getCoachRosterCommand`|C A|Mobile/Admin own/authorized weekly roster snapshot|V/O/G coach own/Admin; T policy/assignments/date|KEEP|35|
|27|`getMemberAccountLifecycleCommand`|C A|Mobile account state/revocation recovery|Current Auth/email/revocation identity; T/W lease/receipt/user, possible Admin Auth revoke|KEEP|8|
|28|`getMemberBookingOptionsCommand`|C A|Mobile options; shared by reschedule and assistant services|V/O/G own, current coach/B; T grid/locks/roster/conflicts|KEEP|63|
|29|`getMembershipAccessCommand`|C A|Mobile policy-aware entitlement decision, legacy behavior while policy absent|V/current Auth/O/G/lifecycle; T paid ledger/server time/policy|KEEP|2|
|30|`getMembershipOverviewCommand`|C A|Mobile dashboard/catalogue/own payment history|V/current Auth/O/G; R plans/history + T paid evidence; no financial mutation|SIMPLIFY bounded history|27|
|31|`getMembershipPaymentCommand`|C A|Mobile uncertain/pending payment recovery; may activate/extend membership|V/O own, current target identity at settlement; provider GET + T/W; P|KEEP|—|
|32|`getMembershipQuoteCommand`|C A|Mobile authoritative price/promo/version/duration quote|V/O own; T trusted catalogue/promo; no client price authority|KEEP|9|
|33|`googleGymConnectionCommand`|C A|Shared mobile/Admin Google adapter: status/connect/disconnect/recovery/calendar setup|V/current Auth/O/G; Admin mutations/coach own status; T grants/state, provider/Vault; Q|KEEP|31|
|34|`googleGymOAuthCallback`|H|Google browser redirect; consumes expiring single-use PKCE state|State + initiating Admin/current org/email/scopes; T grants/provider/Vault; Q|KEEP|4|
|35|`identifyEquipmentCommand`|C A|Mobile equipment photo classifier|V active member/user org; Gemini secret; R + provider I|KEEP|15|
|36|`listAdminBookingPaymentsCommand`|C A|Existing Admin queue includes booking AND membership|V/O/G Admin; bounded R/T validation/redaction|KEEP|46|
|37|`manageAdminBookingPaymentCommand`|C A|Admin verify/recover/decision/refund handling; common settlement|V/O/G Admin; T audit/receipts/financial reservation + provider; P/X|KEEP|21|
|38|`memberBookingChangeCommand`|C A|Mobile own cancellation/reschedule; shares option service|V/O/G own/current coach; T locks/day/payment/messages/outbox|KEEP|18|
|39|`module9MemberCommandCallable`|C A|Mobile sharing/inbox/mark-read; whole endpoint has mutations|V/O/G own/notification recipient; T sharing/read flags + bounded inbox R|KEEP|30|
|40|`paymentWebhook`|H|Billplz configured callback for BOTH payment kinds|Signature + collection/bill/reference/amount + independent GET; T ingress/settlement; P/X|KEEP|21|
|41|`provisionMemberRegistration`|C a|Mobile registration creates fixed-authority Member records|Signed-in Auth email, intentionally pre-verification; T fixed org/default branch/user/member|KEEP|10|
|42|`publishRoutineCommand`|C a|Admin routine publication; canonical content client writes denied|V/O staff/Admin; T blueprint/exercise/public snapshot/receipt|KEEP|8|
|43|`requestMemberDeactivationCommand`|C A|Mobile deactivation with recoverable revocation lease; no purge|Current/recent Auth identity, own lifecycle; T user/member/receipt + Admin Auth revoke|KEEP|3|
|44|`requestMembershipRefundCommand`|C A|Mobile eligible own refund request/status; no money transfer|V/O own cleared payment/seven-day eligibility; T payment/review audit|KEEP|—|
|45|`reviewCoachCertificationCommand`|C A|Admin approval/rejection of credential state|V/O/G Admin/current target authority; T history/summary/public eligibility|KEEP|7|
|46|`revokeWorkoutConsentCommand`|C a|Mobile revocation; coach access depends on effective consent|V/O member own/current acknowledgement; T revocation/receipt|KEEP|1|
|47|`saveCoachAccountSettingsCommand`|C A|Mobile coach phone/preferences; uniqueness cannot be client-controlled|V/O/G coach own; T phoneClaims/user/revision/receipt|KEEP|6|
|48|`saveCoachAvailabilityDayCommand`|C a|Mobile coach day mutation without overwriting reservations|V/O/G coach own/B; T roster/day/policy/revision/locks|KEEP|14|
|49|`saveCoachProfileCommand`|C a|Mobile private professional profile; cannot self-publish|V/O/G coach own; T revision/profile/receipt|KEEP|9|
|50|`saveCoachRosterCommand`|C A|Mobile weekly roster with reservation consistency|V/O/G coach own/B; T roster/day pins/policy/locks/receipt|KEEP|7|
|51|`setCoachDirectoryStatusCommand`|C a|Admin controlled public projection/publication|V/O/G Admin/current Auth target/B; T projection/revision/receipt|KEEP|28|
|52|`submitBookingReviewCommand`|C A|Mobile review of own completed consultation|V/O/G own completed booking; T note proof/immutable review/public review/receipt|KEEP|2|
|53|`submitCoachCertificationCommand`|C A|Mobile owned upload submission and history|V/O/G coach own; Storage generation/bytes checks + T credentials/summary|KEEP|3|
|54|`submitWorkoutSessionCommand`|C a|Mobile trusted workout acceptance; intentionally disabled tuples stay disabled|V/O own consent/authoritative routine/allowed tuple; T session/receipt|KEEP|9|
|55|`syncGymBookingCommand`|C A|Admin explicit Google delivery/reconciliation; shared coordinator|V/current Auth/O/G Admin/confirmation/current paid booking; T receipts/leases + Calendar/Gmail; Q|KEEP|11|
|56|`synchronizeGoogleBooking`|F|Booking update worker, not a Dart caller; controlled async delivery|Dedicated identity/activation/scope/recipient/revision gates; T receipt/lease + provider; Q|KEEP|4|
|57|`verifyMemberMembershipCommand`|C A|Admin verification through existing member directory|V/current Auth/Admin/O/G/lifecycle; target current Auth + T paid evidence projection|KEEP|4|

### Dependencies and source comparison

-51 C +3 H +2 S +1 F =57. Scheduler jobs are `firebase-schedule-expireBookingHolds-us-central1` and `firebase-schedule-deliverBookingNotifications-us-central1`; both remain ENABLED. `synchronizeGoogleBooking` listens to updates of `orgs/{organizationId}/bookings/{bookingId}`, with retry enabled. External callbacks/jobs need no Dart callsite to be in use.
- Mobile production callsites are in `apps/mobile/lib/infrastructure/firebase/`: Auth, real workout, booking, booking payment, membership, lifecycle, coach account/profile/availability/directory, posture, notes/communication/reviews and module9 repositories. Equipment calls are under `infrastructure/vision`; photo proxy is called by shared live directory views. Admin production callsites include `payment_review_repository.dart`, certification adapter, booking/availability/profile/routine/member directory repositories. Shared Google calls originate in `packages/gainpath_data/lib/src/google_integration_repository.dart`, transported by each app's thin Firebase adapter. These paths are caller evidence, not merely tests.
- Assistant booking tools call the shared quote/options **services**, not a duplicate payment authority. Reschedule uses the same options contracts. Coach performance reuses booking-list logic. Certification mutations share `changeCoachCertification`; hold cancellation and expiry share lifecycle release logic. Callback, Member status and Admin verification share settlement. Manual/automatic Google delivery share the coordinator. Preserve this existing reuse.
- `paymentWebhook` is exported through `commerce/payment-webhook.ts` into the real `booking-payment-callables.ts` implementation. The legacy generic `payment-ingress.ts` is not that live endpoint. Admin functions named “BookingPayment” also handle Membership; renaming/removing them as duplicates would break M4 and M7.
- Current `functions/src/index.ts` exports58 endpoints:57 deployed plus **`verifiedRewardsCommand`**, an undeployed StageB export. Current financial services also contain StageC voucher work. A broad deploy can release held changes even if no new file is intentionally added.
- Source comparisons show independently deployed revisions/bundles, not one exact current backend tree. All57 archives were inspected;18 unique hashes. M4 financial nine-endpoint bundle SHA256 `7dd3550194539da6c8c21c22ac01dcc9c4fbdb6e2c7873234771181f442229e7`; three StageA read commands `8cf413aef4eaabbeaac1fe4cf2e0e7ee33ba1e7369cd5d77259841e88d0ea97f`. Google connection/worker, OAuth callback and manual sync have separate source bundles. One old bundle is not a compatible rollback for every endpoint.
- The StageA live source differs from current local `index.ts`, coach-performance service, booking-payment admin/callables/service and membership-payment service; new rewards/voucher files are not in its approved release. A file shared by several deployed entrypoints must be considered across all affected endpoint revisions before future release.
- Ten deployed legacy callable wrappers omit AppCheck enforcement; existing Auth/role checks remain. Record this accurately instead of claiming universal enforcement or weakening newer endpoints to match. Any consistency/security hardening is a separate reviewed local change and selective cloud release, outside cleanup execution.

### Conditional migrations and exact cloud boundary

| Candidate | Equivalent existing capability | Missing validation before replacement | Cloud action today |
|---|---|---|---|
|`billplzSandboxReturn`|Static hosted return route; no settlement authority|Migrate both gateway redirect construction, keep neutral wording, validate all outstanding callback/return URLs and deploy target route|None; preserve current URL|
|`getCoachAccountSettingsCommand`|Own user read already available under `firestore.rules:186–194`|Match current coach/org/session behavior and safe projection; keep phoneClaims/settings mutation server-side|None; keep endpoint until all callers migrate|
|`getCoachCertificationsCommand`|Owner/Admin credential/history/summary reads allowed at Rules663–679|Paging/history bounds, active organization/current-scope equivalence; preserve trusted uploads and mutation/audit|None; keep endpoint until migration/Rules review passes|
|Inbox-only branch of module9|Own notification reads allowed at Rules648–651|Sharing and mark-read mutations stay trusted; do not retire the whole callable|None; source-level optional simplification|

Booking raw reads at Rules610–634 do not reproduce joined payment/name/review projections. Client posture reads need relationship/sharing/consent authority; published photo proxy exposes approved bytes from otherwise private Storage; membership paths are protected. Quotes and financial “get” commands remain trusted. No catch-all replacement endpoint or broad new Rules grant is proposed.

**Exact immediate cloud proposal: zero deployments, deletions, disablements, Rules/indexes/IAM changes, policy activation or configuration changes.** If conditional migrations are later approved and implemented, the only possible retirement targets from this audit are the three named conditional MOVE rows; they are not ready for deletion. Their route/client/Rules compatibility and usage observation must be reviewed first. Source consolidation may eventually require selective deployments for the actually changed endpoints, but there is no deployable diff in this audit. StageB/C, Google expansion, scaling changes, refund retries and data migrations remain excluded.

## C. Codebase simplification candidates

| Candidate | Evidence | Proposed action / risk |
|---|---|---|
|`apps/admin_web/lib/app/admin_feature_availability.dart` (1,620B)|No runtime/test/public-API import; presentation check only rejects placeholder use|Review removal of stale placeholder; retain checker itself|
|`apps/mobile/lib/app/unavailable_action.dart` (68B)|Unreferenced reexport of shared UI helper|Review deleting alias; do not remove shared `showUnavailable` used by many screens|
|`apps/mobile/lib/features/coaching/presentation/coach/block_type_icon.dart` (429B)|No imports in inspected maintained graph|Review deletion after widget/reference check|
|`.../coach/coach_roster_sections.dart` (16,722B)|Unreferenced older component; newer roster editor is connected|Compare rendered/interaction coverage before removal; preserve reservation/availability logic|
|`.../identity/presentation/coach/live_coach_account_settings.dart` (274B)|Historical typedef/reexport shim, no current imports|Review external/legacy import compatibility before retiring|
|`.../identity/presentation/coach/live_coach_certifications.dart` (210B)|Historical typedef/reexport shim, no current imports|Same compatibility check|
|`.../membership/presentation/member/payment_confirmation_screen.dart` (3,501B)|No current imports; old client-supplied amount terminal screen|Review removal after confirming named routes/current trusted payment confirmation; do not change settlement|
|`functions/src/modules/commerce/payment-ingress.ts`|Generic prototype used by `test/payment.test.ts` and `emulator/transactions.test.ts`, not live webhook|Conditional source/test consolidation, **not** an unused deployed Function; keep until intentional contract/test purpose is resolved|
|`functions/src/modules/coaching/booking-external-delivery.ts`|Test-only legacy Google path|Compare retained tests/coordinator coverage; archive rationale or consolidate tests before any source removal|
|Two identical `firebase_google_integration.dart` app adapters|Exact source hash match; both delegate to already-shared `ScopedGoogleIntegrationRepository`|Low-value duplication at app composition boundary; retain unless a simple existing shared home fits—no new package just to deduplicate this|
|Live availability/profile compatibility wrappers and workout audio lifecycle helpers|Runtime-unreachable in heuristic graph but **tests/tools reference them**|Retain, not dead code. Frozen workout/audio safety is excluded from cleanup|
|In-memory repositories and shared Mock/Firebase UI|Reachable in mock composition/tests; mock is a supported development backend|Retain; remove only obsolete disconnected prototype paths with proof|
|Firebase transport/context boilerplate|Existing scoped guards, AppCheck readiness, ownership and stale-session checks|Consolidate only identical behavior in an existing layer; avoid a universal abstraction that hides financial authority|

No deletion is authorized by a zero-import result. Preserve public APIs, conditional platform imports, generated registrations, source assets, contracts, Rules tests and fixtures. Large CPU/GPU/pose experiment trees are milestone evidence, not abandoned business features. Root `lib/` has no files; the workspace root is not a third app—do not run `flutter create .` from stale instructions.

## D. Build, generated and private artifact audit

Inventory: **71,424,955,939 logical bytes / 94,890 files / 18,882 directories** including `.git`; root `build/` alone **37,549,094,722B / 10,530 files**. Ignore rules cover these build/cache roots; no tracked files were found under the major generated roots. **Ignored does not mean disposable.** `.tmp-appdata`, Python bytecode and authored Admin UAT tool sources are untracked; authored tools must not be swept into cache deletion.

Classification key used below: **G REGENERATABLE** (potential future selective cleanup after prerequisites); **R RETAIN** (0 proposed recovery); **A ARCHIVE** (preserve, then verified relocation,0 proposed recovery); **L RELOCATE** (authored tool/private state,0 recovery). For G rows, logical recovery ceiling equals the shown bytes; risk is medium until dependent tools are idle and rebuild/toolchain/provenance checks pass. R/A/L deletion risk is high/unknown and no deletion is proposed. Mixed loose groups remain RETAIN pending file-level review.

### Largest nonoverlapping cleanup opportunities

| Directory/group | Current bytes | Files | Purpose/class | Proposed action | Deletion risk / logical recovery ceiling |
|---|---:|---:|---|---|---|
|`apps/mobile/build/windows`|10,858,746,157|506|Windows build, G|Selective removal after runner/toolchain and no-release-evidence check|Medium;10,858,746,157B|
|`apps/mobile/.dart_tool`|3,585,483,356|899|Flutter cache, G|Remove only after no special fixture/profile files and package restoration plan|Medium;3,585,483,356B|
|`apps/mobile/build/test_cache`|1,834,119,792|33|Test cache, G|Selective cache cleanup|Low/medium;1,834,119,792B|
|`apps/admin_web/.dart_tool/flutter_build`|1,767,719,043|792|Compiled cache, G|Keep sibling browser profile; clean only this subtree|Medium;1,767,719,043B|
|Root `.dart_tool`|448,552,967|182|Workspace/package cache, G|Restore package config before tools run|Medium;448,552,967B|
|Mobile Windows `flutter/ephemeral`|295,721,886|47|SDK-generated output, G|Regenerate after link-safe selective cleanup|Medium;295,721,886B|
|Mobile Android `.gradle`|70,266,853|16|Project Gradle cache, G|Ensure Gradle idle and SDK/source/lock provenance retained|Medium;70,266,853B|
|**Disjoint conservative total**|**18,860,610,054**|**2,475**|**Approximately17.57GiB**|**Separate future cache-cleanup approval**|**Not guaranteed physical free space**|

The eleven historical root-generated directories total **1,511,856,450B / 1,290 files**. Their source/build provenance is unresolved because today's root lib is empty; classify them **ARCHIVE pending provenance**, not immediately regeneratable. They are excluded from the conservative17.57GiB set. The earlier broad19.36GiB estimate would overstate verified reproducibility and is not proposed for cleanup. Adding only two root DILL caches, four Admin DILL caches, functions/lib and Python bytecode gives a **conditional17.96GiB / 19,279,537,444B / 2,680 files** ceiling; the extra compiler caches also require provenance/retention checks first. A further2,710,489,431B of generated caches exists inside the protected Module9 source snapshot, but it is **conditional later work**, excluded from both figures until the snapshot is manifested and verified. No protected artifacts, vendor dependency store or duplicate rollback archive is counted as reclaimable evidence.

### Root build groups — exhaustive, disjoint first level

For each G row: proposed action is selective future regeneration/cleanup with byte ceiling shown. For R: retain/protect; A: manifest and archive-copy; L: migrate reusable source/private configuration with references updated. No row is an execution instruction.

| Under `build/` | Bytes | Files | Purpose / class |
|---|---:|---:|---|
|`.cxx`|742,683|97|Historical CMake output, A pending provenance|
|`12aa4f36d89c680b50a7a717a0f76b1a`|2,422|8|Historical Flutter output, A pending provenance|
|`a1-integration-b1-design`|253,490|9|Integration evidence, A|
|`a1-routine-discovery`|27,533|13|Evidence/emulator logs, A|
|`admin-equipment-tutorial`|33,013,186|32|Historical web bundle, A|
|`admin-local-private`|1,171|2|Authored local server, L|
|`admin-unified-review`|53,670|15|Review evidence, A|
|`admin-web`|33,111,334|38|Current served Admin/output metadata, R|
|`admin-web-local`|32,998,507|32|Historical web bundle, A|
|`ai-booking-integration`|858,230,721|15|Release/private phone backups, R|
|`app`|1,240,800,977|669|Historical Android output, A pending source/release provenance|
|`b1-coach-directory`|98,322|27|Evidence, A|
|`b1-integration-b2-plan`|259,115|10|Evidence, A|
|`b2-availability`|98,694|37|Evidence, A|
|`b2-integration-b3-design`|258,550|10|Evidence, A|
|`b3-b4-integration`|316,533|17|Evidence, A|
|`b3-implementation`|792,920|40|Evidence/source preservation, A|
|`b4-implementation`|59,267|21|Evidence/source preservation, A|
|`billplz-sandbox`|219,585,072|2|Financial/release evidence, R|
|`checkpoint-ci`|1,279,625|21|CI/preservation evidence, A|
|`coaching-final-uat`|8,226|2|UAT, R|
|`coaching-review-ui`|22,497|1|UI evidence, A|
|`consultation-notes-1206468`|856,948,379|10|Release/private backups, R|
|`crud-priority-review`|1,864|2|Review evidence, A|
|`equipment-image-edit-regression`|31,491,915|32|Regression bundle, A|
|`equipment-picker-probe`|31,153,731|32|Probe bundle, A|
|`equipment-scanner-ai`|1,936,221,731|50|Release/private backups, R|
|`equipment-tutorial`|952,489,013|52|Release/private backups/tools, R/L|
|`equipment-tutorial-preview-progress`|857,786,510|8|Release/private backups, R|
|`firebase-demo-preparation`|845,278,768|175|Shared API tools/fixtures/private evidence, R/L|
|`flutter_assets`|3,257,797|8|Historical generated assets, A pending provenance|
|`gate0-catalog`|170,685|12|Evidence, A|
|`gate0a-integration`|460,261|28|Evidence, A|
|`google-oauth-setup`|1,398,984|79|Connection/session material, R|
|`jni`|3,704,635|246|Historical generated JNI, A pending provenance|
|`jni_flutter`|84,875|34|Historical generated JNI, A pending provenance|
|`mobile-unified-ui`|245,292,577|17|Preserved release/evidence, A|
|`module-10`|219,476,386|12|Release/UAT, A|
|`module-8-activation`|218,847,521|1|Preserved release, A|
|`module-8-architecture`|219,415,331|6|Preserved release/evidence, A|
|`module-8-shared-ui`|219,638,709|10|Preserved release/evidence, A|
|`module-8-uat-fix`|219,359,073|1|Preserved release, A|
|`module-9`|658,458,629|3|Preserved releases, A|
|`module10-availability-ux`|857,961,651|8|Release/private backups, R|
|`module10-backend-emulator`|40,736|2|Emulator evidence, A|
|`module4`|1,342,461,034|1,096|Financial UAT/source/rollback/installed release, R|
|`module6`|857,943,664|15|Release/private backups, R|
|`module7-booking-completion`|858,019,053|13|Release/private backups, R|
|`module7-refund-clarity`|858,148,599|13|Financial/release/private backups, R|
|`module9-completion`|3,595,439,118|5,463|Source snapshot/release/private backups, R|
|`module9-review-button`|857,662,261|8|Release/private backups, R|
|`native_assets`|45|1|Historical generated metadata, A pending provenance|
|`native_hooks`|32|1|Historical generated metadata, A pending provenance|
|`non-core-crud-sprint`|16,846,584,544|1,437|Activation/rollback/UAT/private fixtures/backups, R|
|`p0-logs`|221,365|14|CI evidence, A|
|`p8-1a-logs`|50,152|8|CI/preservation evidence, A|
|`p8-1b-preflight`|11,946,252|16|Preflight evidence, A|
|`p8-1br-review`|23,739|9|Review evidence, A|
|`payment-review`|219,625,657|3|Financial/release evidence, R|
|`reports`|142,775|1|Diagnostic evidence, A|
|`review-state-repair`|858,309,768|153|Backend snapshot/release/private backups, R|
|`test_cache`|80,358,624|1|Historical root test cache, A pending provenance|
|`tutorial-logs`|280,772|33|Evidence, A|
|`unit_test_assets`|129,197|6|Historical generated assets, A pending provenance|
|`web`|32,948,840|33|Historical root preview; old launch references, A|
|`windows`|182,775,163|219|Historical desktop output, A; no current root-app rebuild provenance|
|Loose files|145,069,792|41|Two DILL caches144,800,408B/2 conditional G; other269,384B/39 R/A/L pending review|

### App and other generated roots

| Directory/group | Bytes | Files | Purpose/class; proposed action |
|---|---:|---:|---|
|`apps/mobile/build` **parent total**|26,719,953,941|47,113|Mixed; never delete wholesale|
|↳`windows`|10,858,746,157|506|G; listed in conservative opportunity table|
|↳`pose-quality`|8,520,452,307|37,707|Original recordings/APKs/source snapshots/scripts/experiments, R/A|
|↳`app`|3,257,553,501|1,939|G intermediates; verify named release preservation first|
|↳`test_cache`|1,834,119,792|33|G|
|↳`flutter_assets`|80,476,684|10|G|
|↳14 Android plugin output dirs|53,618,029|6,475|G; camera/Firebase/file selector/JNI/TFLite/URL/video outputs|
|↳`.cxx`|2,245,323|291|G|
|↳hash-named output|2,683|8|G|
|↳native_assets/native_hooks|77|2|G|
|↳unit_test_assets|11,191,556|10|G|
|↳web|31,313,622|26|G only after preview/reference check|
|↳member-progress-install|295,951,609|3|Installation evidence, A|
|↳password-reset-install|295,461,628|2|Installation evidence, A|
|↳step6-development|147,191,661|5|Release/evidence, A|
|↳step7-diagnostics|147,435,718|3|Evidence, A|
|↳step7-performance|620,994,116|53|Performance evidence, A|
|↳pose-debug|4,401,647|9|Evidence, A|
|↳audio-owner-test|2,452|2|Evidence, A|
|↳reports|147,939|1|Evidence, A|
|↳tutorial-logs|0|0|Empty evidence directory; no meaningful space benefit|
|↳loose files|558,647,440|28|Mixed, RETAIN pending file-level classification|
|`apps/admin_web/build` **parent total**|369,793,346|65|Mixed; never blanket-delete|
|↳four DILL caches|273,004,336|4|G|
|↳test_cache|58,815,464|1|G|
|↳web|33,093,374|32|Hosting public target in firebase.json; RETAIN until release/reference review|
|↳flutter_assets/unit_test_assets|4,864,394|14|G|
|↳hash/native metadata|2,584|10|G|
|↳gate0a-integration|9,698|1|Evidence, A|
|↳other loose metadata|3,496|3|R/A pending individual classification|
|Root `.dart_tool`|448,552,967|182|G; package-config consumers must be restored|
|Mobile `.dart_tool`|3,585,483,356|899|G after profile/source check|
|Admin `.dart_tool` **parent total**|1,769,195,508|996|Mixed; no blanket cleanup|
|↳flutter_build|1,767,719,043|792|G|
|↳chrome-device|1,475,211|202|Browser profile/session, **RETAIN PRIVATE**, not compiler cache|
|↳dartpad/pub|1,254|2|G|
|Mobile Android `.gradle`|70,266,853|16|G project cache; global Gradle not audited|
|Mobile Windows ephemeral|295,721,886|47|G; links skipped|
|Five package `.dart_tool` roots|7,605,515|9|G; data2,663,472/domain2,485,608/identity40/pose2,453,928/UI2,467B|
|`functions/lib`|1,073,479|194|G compiled TS; package main requires rebuild before serving/release|
|`functions/node_modules`|339,277,851|29,113|G in principle; **defer** because active tools/junctions/dynamic imports depend on it|
|`.pnpm-store`|8,192|1|G; negligible benefit; link skipped|
|`.tmp-appdata`|1,256|6|Local client/session state, L; negligible benefit|
|Mobile tool/__pycache__|49,167|5|G Python bytecode|
|Admin tool/|6,596|2|Authored Dart UAT/probe sources, RETAIN/L, not generated|
|Root tool/|80,903|3|Tracked verification/architecture source, RETAIN|
|Root tools/|17,217|9|Tracked local Admin/server/check source, RETAIN|

Logs outside the already-counted build/cache/vendor/.git roots total **78 files / 320,683B**. These are not another recovery allowance:

| Group | Files | Bytes | Classification / proposed action |
|---|---:|---:|---|
|Admin step1-catalog-regression.log|1|1,867|RETAIN/ARCHIVE test evidence|
|Mobile step*.log|53|165,366|RETAIN/ARCHIVE pose/build/device evidence|
|Functions step*.log|11|136,544|RETAIN/ARCHIVE backend/emulator evidence|
|Pose-package step*.log|10|13,480|RETAIN/ARCHIVE pose tests|
|Admin flutter_01.log|1|3,426|Diagnostic review first; ARCHIVE or REMOVE CANDIDATE, negligible benefit|
|Functions firestore-debug.log|1|0|Empty REMOVE CANDIDATE; no space benefit|
|Local telemetry log|1|0|Empty REMOVE CANDIDATE; no space benefit|

Six Functions emulator evidence logs within the protected step*.log row total132,225B; emulator TS/JSON/Rules configurations are maintained source, not disposable output. Keep the **61,011B / three ignored Android Gradle bootstrap files**,128B local SDK properties and tracked Gradle wrapper/build configuration. Keep the **2,566B / three tracked Windows plugin registration files** and tracked CMake files despite generated names. Android app/src/debug and src/profile manifests are tracked source. The Kotlin session directory is empty. No additional root/Admin Android output, app/debug/profile/release output, coverage/dist/out/.cache/.firebase/package-build roots were found in the completion scan.

### Protected artifact integrity

Fresh hash/structure verification was read-only. Structural parsing does not establish that restoring a backup works, and signing identity below is retained prior verification evidence rather than a new device/signing-tool run.

| Protected artifact | Bytes | SHA256 / completeness |
|---|---:|---|
|`build/module4/gainpath-three-tier-remaining-firebase-debug.apk`|219,819,545|`fc1b1cf3bd34815bb8546cf5732e9ad8dd42dd08cbfa1b3b1041a050d8019034`; ZIP338 entries, manifest/classes.dex/three Flutter ABI libraries present|
|Private installed-after APK|219,819,545|Same hash; retain both copies until owner approves any deduplication|
|Phase1 Firebase APK|219,775,191|`82b5d547a66ede95ad44acb889c45217dd82ef0032c1c7cc7803493edd675960`|
|Original Module4 Firebase APK|219,763,563|`bc6b1169175bfd99499e56c5dc8630c36c41b837030a31c48d5fed808e9899d3`|
|Private installed-before APK|219,726,283|`34dbc79f7755de1f1719c3d506e5540a0787f9d68b5ee690fe851e674957672d`|
|Phase1 overview rollback ZIP|592,626|`7dd3550194539da6c8c21c22ac01dcc9c4fbdb6e2c7873234771181f442229e7`;284 entries|
|Approved upload/final deployed/StageA overview rollback ZIPs|598,933 each|`86b56335541bcb1098bcae8835883428ee33fc6116bbf65c516986f41c370bda`;287 entries each|
|Three StageA deployed-command ZIPs|609,336 each|`8cf413aef4eaabbeaac1fe4cf2e0e7ee33ba1e7369cd5d77259841e88d0ea97f`;293 entries each|
|Private Xiaomi before/after app-data TARs|99,529,216 each|`9419bf48a6e2544f473c0ea26d3f1a29d1f13022a9d0bfbe02ebf7d7f955677b`;42 parsed entries each|
|Retained signing identity|—|Cert SHA256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`; package `com.zyang.gainpath`;v2 signing evidence retained|

All seven retained source ZIPs contain source, compiled entrypoint, package metadata, lockfile and project environment files. Identical archives/backups are **not** automatic remove candidates: their roles differ and the only-copy/restore/retention decision is unresolved. Private files remain out of source control and public reports; no credentials, session payloads, test-persona contact details or private screenshots are reproduced here. Web bundles compiled with a debug AppCheck token and raw environment/configuration archives require private classification before relocation; do not publish or commit them as ordinary sanitized evidence or releases.

Within `build/module4`, private material is669,993,793B/52 files (phone-install638,617,297B/5; readonly Admin web30,991,631B/32; financial UAT346,066B/13). StageA source2,124,101B/358, StageA rollback1,697,469B/287, Phase1 rollback1,679,410B/284 are retained. Do not delete extracted source just because its ZIP exists: scripts currently import the compiled modules inside it. Module4 financial journal/callback/invoice/Admin evidence and all Module7 financial evidence remain RETAIN.

### Required path/dependency work before any relocation

| Current dependency | Migration prerequisite |
|---|---|
|`tools/admin_web/build.cjs` → build/admin-web/current, build logs and Module8 private registered AppCheck fixture|Parameterize output/evidence/private inputs; move configuration securely; update README/serve/cache tests together|
|`tools/admin_web/serve.cjs`, current Module4 UAT server → current Admin/private readonly bundles|Keep live local review usable; controlled switch after new bundle hashes/readback; do not stop servers during audit|
|`firebase.json` → apps/admin_web/build/web|A local path move does not authorize Hosting publication/config deployment; review separately|
|Many build scripts → build/firebase-demo-preparation/live-api.cjs|Promote reusable read/mutation clients into tools/firebase with explicit read-only/write modes and scoped approval guards|
|Catalogue/preflight scripts → stage-a-source/lib finance/entitlement modules|Separate immutable evidence from reusable library dependency; update import paths and tests before relocating source snapshots|
|Deployment scripts → firebase-tools internal auth/api modules; preserved source junctions → functions/node_modules|Keep dependencies available until stable supported tooling/refactor is verified; never follow junction targets during deletion|
|Equipment/pose media scripts → sibling private/media-tools/video-tools paths|Move authored scripts with explicit input/tool paths; preserve source recordings/ffmpeg provenance and frozen analyzer behavior|
|Pose benchmarks → root .dart_tool/package_config and generated pose-quality harness|Restore packages and redirect only new generated output; retain old experimental evidence|
|Historical reports → old build paths/hashes|Maintain original→target path/hash mapping; validate links and extraction completeness before retiring old paths; never rewrite immutable evidence to imply a different historical event|

Proposed long-term roots:

```text
releases/<date>-<module>/          immutable APK, source/lock/build/signing provenance
evidence/<module>/<run>/          sanitized UAT/deployment/readbacks/rollback manifests
tools/{admin_web,firebase,pose}/  reusable authored tools, explicit input/output roots
.localprivate/<module>/<run>/     ignored restricted fixtures, sessions, app-data/backups
build/                           reproducible compiler/test output only
docs/archive/                    retained decisions/plans/reports plus index/path mapping
```

This structure is a proposal, not a move instruction. Before relocation: manifest every source/target, byte count, full SHA256, privacy/retention role, source/lock version, linked release, required companion files and restoration instructions. Copy to a **new** target with no overwrite, compare file counts/hashes/ZIP/TAR structure, validate dependent imports/config/links and rebuildability, then seek approval for retirement of the old copy. Recheck protected integrity at execution time. Use native Windows literal paths, resolve them inside the approved workspace, reject unexpected reparse targets and never compose recursive deletes across shells. A storage move on the same disk does not recover disk space.

## E. Proposed local phases and regression gates

| Phase | Exact local scope after approval | Verification and stop condition |
|---|---|---|
|1: active documentation/guide|Create the proposed active architecture/status/operations/agent/archive-index entries; shorten README; reconcile current source READMEs/setup/launch guidance; preserve original historical/financial/academic records|Validate219 baseline hashes for preserved originals, current catalogue/UAT facts, internal links and no credentials; no source/cloud/build artifact change required|
|2: small source cleanup|Review seven named Dart candidates and two test-only TS prototypes; consolidate only proven redundancies; retain mock/public/compatibility intent where uncertain|Architecture/import checks and focused affected tests; stop if reference/behavior cannot be proven. No endpoint/API retirement or frozen core changes|
|3: retention/tool separation|Prepare complete release/evidence/private manifests; parameterize authored tools; copy/verify any separately approved relocation with explicit original-path mapping|Hashes/counts/archives, safe dry-run source→target diff, local server/tool smoke with nonfinancial read-only or emulator endpoints; keep originals until retirement approved|
|4: selective caches|Only separately approved exact G subtrees; prioritize17.57GiB conservative set; preserve browser profiles, release copies and evidence|Tools idle, validated literal paths, retention manifest excludes all protected files; restore locked dependencies and perform relevant builds/checks afterward|
|5: optional backend/client simplification|Implement measured pagination/query improvements or conditional client reads, preserving endpoint contracts until migration complete|Rules emulator/cross-account/current-role tests plus affected service/client tests; separate cloud release approval for an exact reviewed diff|

Required focused checks at implementation time (not run now):

- Documentation-only: link/path/manifest validation; no unrelated full app rebuild. Source-only aliases/UI cleanup: `dart run tool/check_architecture.dart`, presentation checks, maintained-source analysis and the affected widget/repository tests. Keep full verify/CI for integration/release, not every paragraph edit.
- Identity/Auth: lifecycle, provisioning, session-change/revocation, cross-account and role/suspension tests; no account/role changes to set up live scenarios without approval.
- Membership/commerce: quote/version/amount tampering, paid-only activation, duplicate callback/settlement, failure/expired/uncertain bill recovery, concurrent/manual renewal preserving time, invoice/refund authorization and account isolation. Keep financial tests local/emulator unless a specific new provider run is approved.
- Module7: reservation contention, hold expiry/cancellation/reschedule, locks/day counters, payment/Admin reconciliation/refund review and coach-earnings recognition; preserve the unchanged financial records as read-only comparison baselines.
- Google: OAuth state/PKCE/scopes/revocation, bounded leases/idempotency/revision checks, automatic confirmation/reschedule/cancel scope and manual coordinator tests. Tests use doubles/emulators; no actual Gmail/Calendar sends or automation expansion under cleanup approval.
- Mock/Firebase: both composition paths, session guards and navigation; no mock plan/price substitution in Firebase mode. Future client-read migrations require Rules tests proving owner/Admin/foreign-account/organization denial before any rollout.
- Protected releases/evidence: verify APK/certificate records and source/private backup manifests. A passing test cannot justify deleting the only release/rollback/session copy. Frozen pose/model/audio/counting/scoring fixtures and physical evidence remain outside source cleanup.

## F. Approval requested

**Approve LOCAL Phase1 only:** consolidate the six active reading entrypoints and short Agent guide, reconcile stale current documentation/setup guidance, and validate links while preserving all historical, academic, financial, rollout and UAT evidence in place. No source removal, artifact cleanup/relocation, secret/account change or cloud action is included in this first approval.

Later source pruning, artifact relocation and cache retirement should be presented as concrete bounded local batches using the inventories above. **No cloud change is requested or authorized by this report.** No endpoint is ready for deletion; any future release/removal or Rules/IAM/config change needs its own exact review and owner approval.

## AppendixA — exhaustive document inventory and preservation hashes

The following baseline inventory was captured before creating this report. ACTIVE means current reference/entrypoint, CONSOLIDATE means reconcile into the six active references, ARCHIVE means retain immutable historical/traceability evidence, and OBSOLETE means a reviewed future candidate only. Full hashes protect originals during future work; classification is not permission to delete or move them.

<details>
<summary>219 baseline items: full classification, byte count and SHA256</summary>

| Path (repository-relative unless absolute) | Class | Bytes | SHA256 |
|---|---|---:|---|
| `.claude/launch.json` | CONSOLIDATE | 409 | `80a0676785f86b779e06f612d2f429959e4c036baff393cdb63dcb9acaac5363` |
| `README.md` | ACTIVE | 8,643 | `0150846276eb3e68c5f6b1ca29b1f884a7304b59ca2c42f5b6c919fc5d004e46` |
| `SETUP.md` | OBSOLETE | 967 | `288738c27ad46608e0fdbbdfef2ef2d1e202af73370519af9c788536bdfd5b38` |
| `SUPERVISOR_DEMO_CHECKLIST.md` | CONSOLIDATE | 10,508 | `d1053b64ebb72b1b3dd9be531147607218a54ff67bdfd5774a3d40d9350afb09` |
| `apps/mobile/assets/models/SOURCES.md` | ACTIVE | 1,952 | `9edd0c691ceb9cbb17823b594339ef03877bafdf4ed29a276cd6ae79de2a4b8e` |
| `docs/2026-09-06-architecture-restructure-report.md` | ARCHIVE | 23,366 | `1c59023016827cae7528467c6e10372d93acd2cd220b46e0081ca6eff9dd34ff` |
| `docs/architecture/2026-09-17-gainpath-target-architecture.md` | CONSOLIDATE | 32,228 | `1d7a32e5c320100fe611157592042b2e6a54e8cb9f31f3ac4e0b100d29da0cb4` |
| `docs/architecture/2026-09-19-architecture-implementation.md` | ARCHIVE | 12,616 | `1799e0e9d9c9bcd803b6bdde35f13aacdd1b3e8e35eced1bde3fbe6fb8aae4bb` |
| `docs/architecture/2026-10-02-pose-phone-validation.md` | ARCHIVE | 8,095 | `7f8bfdfa1777a7b7b05b67f7814c55afc6afd07420dbb9d9db4800df06581e41` |
| `docs/architecture/2026-10-02-pose-quality-validation.md` | ARCHIVE | 27,981 | `c0775bc643a3f3295cb006ea2102fe384283ac46b9b0922ad10a69f16bd9ea20` |
| `docs/architecture/2026-10-02-pose-rendering-diagnosis.md` | ARCHIVE | 8,293 | `4cb1b82fa3e3b8b4be158c0e09d11a103b1298b98351222f8c50d0b0c0dc0dd5` |
| `docs/architecture/2026-10-02-real-squat-contract.md` | ARCHIVE | 21,551 | `6f8ccf4e7739c7bf74df79c765e622605ab11b0f4de6f512395479f5210f6cb1` |
| `docs/architecture/2026-10-03-pose-dynamic-joint-lag.md` | ARCHIVE | 59,200 | `9ebf47a53bc1b15b029fbfd4c4349cf5080bf88c5926135ef61e48429ba1cdd3` |
| `docs/architecture/2026-10-03-pose-external-video-analysis.md` | ARCHIVE | 8,246 | `a48433b6a6acc366196185b636dbcc9985a65d39490f87b61d85ad37c4098b4a` |
| `docs/architecture/2026-10-03-pose-physical-latency-baseline.md` | ARCHIVE | 10,579 | `5c408c13e45e7ce83ceeb0eeea4603cee7d2394005a52d1f334c788890d299a1` |
| `docs/architecture/2026-10-03-pose-preprocessing-optimization.md` | ARCHIVE | 12,975 | `f680777f82c77eb420e06160578daa3e42ebf252e56e533a4b875a808fec23ca` |
| `docs/architecture/2026-10-03-pose-step2c-physical-comparison.md` | ARCHIVE | 18,869 | `c647428e1e839f674b2fcf6f0393c3be8874c989ee9417bc99d549352bfa6079` |
| `docs/architecture/2026-10-05-pose-beta-external-recording-protocol.md` | ARCHIVE | 6,334 | `f28e4a4749869b5ff71f611e4fae250cebfcbaa36e1c6dc56e9deb3e7918cee9` |
| `docs/architecture/2026-10-05-pose-beta-responsiveness-experiment.md` | ARCHIVE | 40,722 | `d638e734fb4d8846f7c82392f500c62c3b2e24238120b665f550e8e9d00bba79` |
| `docs/architecture/2026-10-05-pose-beta-screen-video-comparison.md` | ARCHIVE | 30,815 | `d33dd6532abe21d2f83eab2255caaeede6120378849d4f2f789eff93d98284f4` |
| `docs/architecture/2026-10-05-pose-interpreter-thread-experiment.md` | ARCHIVE | 13,293 | `72ca7b97f3a3cc16598ea861d888e69543ca49e224955b2978991c0da4616e62` |
| `docs/architecture/2026-10-05-pose-refined-lag-and-blanks.md` | ARCHIVE | 41,573 | `e5d8141693061b7c18fcd7570db034e1b3de78f9de39ba47ee04039261a3d13a` |
| `docs/architecture/2026-10-05-pose-refined-screen-video-analysis.md` | ARCHIVE | 18,003 | `0adc5afac72e6989ff22fec1850a4ebfffae4273e48aaf169559c2adbe660c8c` |
| `docs/architecture/2026-10-05-pose-sampler-clamp-optimization.md` | ARCHIVE | 12,290 | `9d82875deb1eb94abc7c1de570d1ed8d000ac5b6c717fc133815792b194f1f5e` |
| `docs/architecture/2026-10-06-pose-beta12-external-comparison.md` | ARCHIVE | 18,552 | `d435372ebef8b8eb188b387edbaee0aa25afb582631024ba06d4003fad23d274` |
| `docs/architecture/2026-10-06-pose-beta12-gpu-experiment.md` | ARCHIVE | 28,053 | `ada634d2c37518f182091d8ae562000198fda565e5e79abc475ca838b4750af5` |
| `docs/architecture/2026-10-06-pose-filter-responsiveness-screening.md` | ARCHIVE | 12,675 | `8ed5e260863073ea538ca25602dd5f917633c9dbd1c233da0d1cde212c159f1e` |
| `docs/architecture/2026-10-06-pose-filtered-gpu-validation.md` | ARCHIVE | 24,401 | `aae14a746a6204b63d556894b06d23d3f01bd637d0eb440494166e126d040468` |
| `docs/architecture/2026-10-06-pose-gpu-feasibility-audit.md` | ARCHIVE | 17,882 | `dd05058625a362e026997433778106cb8580185c889f9b4431fb1d9a73c3f5dd` |
| `docs/architecture/2026-10-06-pose-held-bias-and-temporal-response.md` | ARCHIVE | 12,117 | `681afa9bca8162ba992f8340b666d7c6621aa1a5cd270bf986a65ff6e4de7696` |
| `docs/architecture/2026-10-06-pose-live-gpu-candidate.md` | ARCHIVE | 25,401 | `4b2e35621dd7c99c6a8f7254169835270f46968dc4600bc29c853f9c41a4a4db` |
| `docs/architecture/2026-10-06-pose-refined-skeleton-ablation.md` | ARCHIVE | 46,842 | `634abae7d8735d2216ba4f1754086a66794136f9f9e4604ad8b6e4b244d26171` |
| `docs/architecture/2026-10-06-pose-step2i-screen-comparison.md` | ARCHIVE | 18,024 | `20bce93612e31766f8909569f9fb07a295854805060c5b3f4dae077a467e86e1` |
| `docs/architecture/2026-10-06-pose-step2k-screen-review.md` | ARCHIVE | 14,794 | `c32f12d17aecf26b7349da8f470b5a342362cc3f31f3e27ef7c7563684934f35` |
| `docs/architecture/2026-10-06-pose-step2m-screen-comparison.md` | ARCHIVE | 25,147 | `ccebc70bc19ab3712b72523b5e5b16843337439d71ebec31a3d00a24fbae1ce3` |
| `docs/architecture/2026-10-07-step3-audio-handoff.md` | ARCHIVE | 7,890 | `038a9b381eb5e90039b8aa6c58b908177c75ca9c1e7bdd1a35e24866ab832c57` |
| `docs/architecture/2026-10-08-step3-squat-processing.md` | ARCHIVE | 5,093 | `0e913cf45098e3706e2d2759fd924027a4406cc3eada9ef74b2e779123ab6c98` |
| `docs/architecture/2026-10-08-step4-persistence-handoff.md` | ARCHIVE | 5,466 | `2ce32fa17d47389cd8e5a16a0c6aeff5161b8774a390eef0a8d0bb58875e95fd` |
| `docs/architecture/2026-10-12-squat-fixture-validation.md` | ARCHIVE | 5,694 | `8668a8886f57294c2ef7be39b9fcb173d7e1c4208666f20857344050062b9878` |
| `docs/architecture/2026-10-12-step4-real-workout.md` | ARCHIVE | 2,465 | `8d0b6829fe4975259886c44dab1d21dd3c0dec75bf3b5fc6e3a43a370c026fa2` |
| `docs/architecture/2026-10-12-step5-backend-handoff.md` | ARCHIVE | 7,556 | `fa64612439860daf57ad5365304e3edb754e49a7f3d412676e38a72cd52a54b9` |
| `docs/architecture/2026-10-12-step5-mobile-sync.md` | ARCHIVE | 4,403 | `64e534c74c8e1db867b64fbfffbdf7ef52d05f63502632ea82d079dac7d52a5a` |
| `docs/architecture/2026-10-12-step6-development-deployment.md` | ARCHIVE | 5,674 | `c22dd857489670fb36745908ef4f8a8d92c7ed9f940c91a2ca070a32eb48879a` |
| `docs/architecture/2026-10-13-local-member-progress.md` | ARCHIVE | 19,342 | `f1f858649ac10b623f358c37f2cd4d7cc512cf9c8a63722fe8c41b5ba72d72f3` |
| `docs/architecture/2026-10-13-member-tutorial-playback.md` | ARCHIVE | 10,241 | `fd4544facaa6edb4b1370969836bece04a52c65d7e9eca31ce095194fedce132` |
| `docs/architecture/2026-10-13-p0-ci-recovery.md` | ARCHIVE | 13,223 | `cba45ae2a9c9ee36a24ce3712ba700b4edb58c0ebaf073e31f298ab86abd57d7` |
| `docs/architecture/2026-10-13-p8-1a-source-integration-ci.md` | ARCHIVE | 5,281 | `f5934ec39c3dbb3b7b94e15019df4e061cfda902b0bb1b2e5c00dd43a31ea4f4` |
| `docs/architecture/2026-10-13-password-reset-fix.md` | ARCHIVE | 5,115 | `bf18c85cf85408808d6534b91a7c0d78702a9fce9b912c3bf4552e47ee158d94` |
| `docs/architecture/2026-10-13-real-squat-performance-diagnosis.md` | ARCHIVE | 14,819 | `15554184692a0940824a66bc22c28121f4497a60b039e71ce8f9524c35cb0c25` |
| `docs/architecture/2026-10-13-squat-video-and-algorithm-review.md` | ARCHIVE | 8,118 | `03abe4acaa2023dab8e54e27b8aafe324f8cf8d28a7db9e5c0b675bc2d302c1c` |
| `docs/architecture/2026-10-13-step7-physical-protocol.md` | ARCHIVE | 7,425 | `97621b0246e722794cf34426578a8fbd82b0c7babfc6fbe298c3f0b9c9c73291` |
| `docs/architecture/2026-10-13-step7-squat-diagnostics.md` | ARCHIVE | 10,360 | `ef9e0903c4969795a73f26518d0f0164b53c147724339ce9bb397a87a3daf354` |
| `docs/architecture/2026-10-14-a1-published-routine-discovery.md` | ARCHIVE | 14,016 | `9f0e4093947f83326a74a2f596ec4f59e653f75de5e0f0776561dbbbd8ac5052` |
| `docs/architecture/2026-10-14-a1-source-integration-ci.md` | ARCHIVE | 5,848 | `606078a94c0efed764e064a7235bc2d6a6fea4303d224ede794943455748ad76` |
| `docs/architecture/2026-10-14-b1-coach-directory-implementation.md` | ARCHIVE | 17,949 | `92469e9f9eed222f6f3b41b30eee6913f5f2470de29622a56163cf0accda6f89` |
| `docs/architecture/2026-10-14-b1-source-integration-ci.md` | ARCHIVE | 8,420 | `c3a41d421f40fefd03251ed8eb5bc6e90529851d121c20628b6aa6a5373527ca` |
| `docs/architecture/2026-10-14-b2-availability-implementation.md` | ARCHIVE | 19,082 | `1ac763e13053fe86b901be82ab050ebf2de64649ce54ea70f70991623e912a09` |
| `docs/architecture/2026-10-14-b2-source-integration-ci.md` | ARCHIVE | 6,274 | `ba1c18e6d2ed9fe4ee0b6317cfd9ba20bf40c030e9401670c845826ce85a24d0` |
| `docs/architecture/2026-10-14-gate0-catalog-concurrency.md` | ARCHIVE | 11,007 | `18c41be3de22383a569e395f9995e3a60ccecccb6c9a79902b78d82ee09f592e` |
| `docs/architecture/2026-10-14-gate0a-source-integration-ci.md` | ARCHIVE | 10,862 | `ea0ce33b9275fb29f96336927b01d7dcc6ba3a2f122f407c8350f7d1d11282df` |
| `docs/architecture/2026-10-14-p8-1b-read-only-preflight.md` | ARCHIVE | 12,397 | `3c513d73f86133d5789e9dbe16a913e925f3b2837e23f02c8b437b7bb0656bbb` |
| `docs/architecture/2026-10-14-p8-1br-exercise-rename-impact.md` | ARCHIVE | 17,266 | `12e51b9b9c98e467d6c8e47fdd21e39db3024681191e1e87bbd217ffd9ee67c3` |
| `docs/architecture/2026-10-15-admin-crud-reliability.md` | ARCHIVE | 7,431 | `232bf0af0190459d554f8ce57ced16f9f53dde7628ef7f2180d9113ae126c32e` |
| `docs/architecture/2026-10-15-b3-b4-source-integration-ci.md` | ARCHIVE | 9,293 | `9ef9261291180d836d79842f033013ffbb67599e31b8cfc28a49f1c13b6167dc` |
| `docs/architecture/2026-10-15-b3-pending-booking-implementation.md` | ARCHIVE | 26,533 | `10788e1bb6edbc2da43a4a37583f82ed44ddb5add324b523aa46d1d8ccd7cec5` |
| `docs/architecture/2026-10-15-b4-hold-lifecycle-implementation.md` | ARCHIVE | 16,498 | `e0184091d7ff9b7bcdf1d350d1152ee26838489b0f394c8892e9cabb078720db` |
| `docs/architecture/2026-10-15-firebase-demo-execution.md` | ARCHIVE | 32,559 | `bd3a1ec5ba8920cea8ae8bddb56f3f6351bc8f04ea577477209cd4727b87e6af` |
| `docs/architecture/2026-10-15-member-private-crud-repair.md` | ARCHIVE | 8,500 | `316c639d48e0d4c1f6aa2537aa2ca539d1cea0a46dbff9757f8ab67119504c73` |
| `docs/architecture/2026-10-15-non-core-crud-execution.md` | ARCHIVE | 22,652 | `967046cbed97a42147bad26764d602a03fc41f1ed84075cfffc102435b24b7f0` |
| `docs/architecture/2026-10-15-non-core-crud-matrix.md` | ARCHIVE | 32,292 | `1073b6af181176bdf76da4a8ee904db347a5b6f8f737194e24405c99adbb6908` |
| `docs/architecture/2026-10-16-agent-technical-handoff.md` | ARCHIVE | 245,304 | `92b83740b8033a8fe07145ab1ef60223a6f24587ff3b66199013847023e61244` |
| `docs/architecture/2026-10-19-integration-checkpoint.md` | ARCHIVE | 9,735 | `dd93dc030ce3cd17b83854182a7d814957a0f6e2fc6ce40a62a5bbfa538ac9ba` |
| `docs/architecture/2026-10-20-module-9-completion.md` | ARCHIVE | 6,095 | `26d4ca1ac23f5df01168cf0a477d26da85564ee5700323cb3d075442bcd8d323` |
| `docs/architecture/2026-10-20-review-state-and-responsiveness.md` | ARCHIVE | 2,802 | `e19030479c99d8654da94796965db140ad906835cfd9984713905fa5f8770ed3` |
| `docs/architecture/AGENT_HANDOFF.md` | CONSOLIDATE | 8,059 | `fcbba705df3ad940ffca73742c5a47743c4ddcc3539acaf349ce31bfb7fff820` |
| `docs/architecture/admin-unified-ui-delivery.md` | ARCHIVE | 4,103 | `4982628f0ed88fb6df94619747c6a1ec6bab660a6d047e657bc8095140f1de76` |
| `docs/architecture/billplz-sandbox-delivery-evidence.json` | ARCHIVE | 8,809 | `7012462cd8cdddc98794e6ee77746362c867c64eda6fe96190a96878781f8390` |
| `docs/architecture/billplz-sandbox-uat.md` | ARCHIVE | 17,020 | `b0e0e238af4cf19c332e8b85a57c0f8d11bd6947c38e3bf30abb3b7d809663d8` |
| `docs/architecture/consultation-notes-delivery.md` | ARCHIVE | 6,214 | `bc0346bb7e5ba92790a27ae343fee437593512ac5199adb2da236ed52ab1f993` |
| `docs/architecture/diagrams/gainpath-system.dot` | CONSOLIDATE | 3,805 | `eb7dc06baf5861ecd2ec7ee95c19cdfea70db4999a9847b5746f41f10cfba548` |
| `docs/architecture/diagrams/gainpath-system.png` | CONSOLIDATE | 617,620 | `90c24423f8312a142d488103fc35b978868613e9b49bd4646ad3d583a640a2a6` |
| `docs/architecture/diagrams/gainpath-system.svg` | CONSOLIDATE | 23,739 | `9624bb72068ff29072bf0c62dfb9960693db91cf0707b269221000557d38e6a6` |
| `docs/architecture/member-firebase-data.md` | CONSOLIDATE | 5,279 | `1a94c6b1420b46c0e12f2bbf456a1b054753e6e49f01a7f3c7a10501b841a5c8` |
| `docs/architecture/mobile-unified-ui-delivery.md` | ARCHIVE | 5,093 | `3c34f7c6a2e2b2adefc119855a761ca3dfb7ffa963dd3c919d45216d7038caaa` |
| `docs/architecture/module-1-data-contract.md` | CONSOLIDATE | 15,303 | `a4c765ae12eede1d103406a087b630a3444a27a30f8dd22ad8f016bf5ad7fc51` |
| `docs/architecture/module-1-uat.md` | ARCHIVE | 6,883 | `dbe4b768167c768092727effc6475f50315d8bb9a94e8b9c7d71a1cc25d3a1d0` |
| `docs/architecture/module-10-uat.md` | ARCHIVE | 11,353 | `d2481148f79ebf96e814cf6b7bd49af45b777c2af6fd5f9fab24b8dc4d8bf943` |
| `docs/architecture/module-8-canonical-ui-delivery.md` | ARCHIVE | 4,718 | `5047d4ff62e4abd62e60d65d481386584dbdeced083456f83e8fb5490446f1b0` |
| `docs/architecture/module-8-data-contract.md` | CONSOLIDATE | 3,943 | `ef79f22e0036e1683edef3ddb3dde45fe6b72972e8cf708aec885ba9dd8f1c95` |
| `docs/architecture/module-8-delivery.md` | ARCHIVE | 4,937 | `e44c03ae3a5ea74dc1ac50b883fc803ccc33a66aaba16f10c22ac792421c0f7d` |
| `docs/architecture/module-8-uat-fix.md` | ARCHIVE | 8,871 | `b5c201eeacbf285a2ffb7f9e2d5e18e50ec7bf177a5ebf67db3784cfb6408f45` |
| `docs/architecture/module-8-uat-live-results.json` | ARCHIVE | 1,578 | `989bdcb7d58bf121e7eb4a0387702f22ff62487f10712fcd37938d4502805309` |
| `docs/architecture/module-8-uat.md` | ARCHIVE | 3,705 | `029513ae3a6f5fb1f5b5ca66537fcd7b05356c9c506195b616d9101ab7859efb` |
| `docs/architecture/module-9-uat.md` | ARCHIVE | 16,034 | `5f47b6fb79b21aab3973368e443acc86652a62971b6bc0459051addbdc23a2d9` |
| `docs/architecture/ui-data-boundary.md` | CONSOLIDATE | 4,626 | `7015c3135b5815c18716fe36bd24e5c608992a8a2c7963149ccfce89d5c3264b` |
| `docs/firebase-setup.md` | CONSOLIDATE | 5,244 | `8720ec801093370185c0efbdf72d7003428ae85a0bc8eab83dd368a31f280017` |
| `docs/integration/2026-10-19-main-integration-review.md` | ARCHIVE | 10,777 | `297b629fa3d81227e9449c28b2bb517f33709e004f5da3938b41b335dda65220` |
| `docs/integration/2026-10-19-preexisting-working-tree.txt` | ARCHIVE | 6,212 | `34ab01dbc88b1d3f0cd5d4ef5f066b216c5976ec24ceaff3a54765dc916b5e53` |
| `docs/integration/2026-10-20-pr1-readiness.md` | ARCHIVE | 2,049 | `e7c9fe4e88a33c4728a2749126034bc87c3940891de3ab645965470cfa9bc61c` |
| `docs/integration/2026-10-20-remaining-integration.md` | ARCHIVE | 6,019 | `8536e1c877a77d06045d1fbce19ddbbe070dc8962cf3ed82237e1ff3aa91e425` |
| `docs/integration/ai-booking-calendar-email.md` | CONSOLIDATE | 17,245 | `b6a28d1bdea35ff3657285e25252f4fbba7b0a010baff6a4a80694b25769b889` |
| `docs/integration/automatic-cancellation-uat-2026-10-23.md` | ARCHIVE | 1,114 | `02bf6bce124660c8d25ae58275729c6bca7f30543a9bcd2f920c41fb11153cf2` |
| `docs/integration/automatic-confirmation-uat-2026-10-23.md` | ARCHIVE | 1,377 | `677db7191f044114120539ac44b2a4447577e3aa4d20f2c5a39d80247caaf681` |
| `docs/integration/automatic-google-controlled-activation-proposal-2026-10-22.md` | ARCHIVE | 6,852 | `c371d20abbbcf796ffdf33c2ed09a185591937d1e64e51d567a16545189ccbe2` |
| `docs/integration/automatic-google-delivery-design-2026-10-22.md` | CONSOLIDATE | 5,873 | `b2b51b68be06fae910f0723bef3955dc9b4a64d23447de14205bc2f1803fc3db` |
| `docs/integration/automatic-google-delivery-implementation-2026-10-22.md` | ARCHIVE | 8,192 | `a571134e47956d4cb72e505d458ee522b004fb9542c9f8c935cbad8d3e017e80` |
| `docs/integration/automatic-google-deployment-2026-10-22.md` | ARCHIVE | 7,842 | `f7da59e07924af3065f0c139831cffa417e497d1ff50977ae93b3161c07c3d4a` |
| `docs/integration/automatic-google-deployment-stopped-2026-10-22.md` | ARCHIVE | 6,160 | `53ebbb0f15393524d0236efa3f0f024524a71708e85e8e6bea992e00afa4e799` |
| `docs/integration/automatic-google-scope-deployment-2026-10-22.md` | ARCHIVE | 2,574 | `7fd965ffb5844543e20e1b0a161238bb5a4cfacebf55acbd58c0892d14cdab61` |
| `docs/integration/automatic-google-scope-hardening-2026-10-22.md` | ARCHIVE | 3,831 | `01f5fc3a3ea72995f50cf278b58c0638aae289574deba3f6f82ba166d97396f6` |
| `docs/integration/automatic-reschedule-uat-2026-10-23.md` | ARCHIVE | 948 | `6d7b57eb591a24a1d6b549c75c656fd887e83d211ad87fef394d76da86006109` |
| `docs/integration/coaching-completion-uat.md` | ARCHIVE | 10,093 | `9a2226219e2fac55376aa17ca9e0ab2e5a70eae0842506dc766828194b4f3e71` |
| `docs/integration/controlled-uat-activated-2026-10-23.md` | ARCHIVE | 2,058 | `6e976c324f7121c1dbbcef6daec9aeb857920f0721cf07910473396eebd67b26` |
| `docs/integration/controlled-uat-activation-approval-2026-10-23.md` | ARCHIVE | 3,232 | `f3eb6a4080a299267bcfb9ae0aab99b1d16bcb3b0b1138dd7048851264135a55` |
| `docs/integration/equipment-image-edit-repair.md` | ARCHIVE | 2,638 | `e20c84b455192ed6fc8bfd96bd057e1d69cbb82ee5e677c760d4e41b28e18fd5` |
| `docs/integration/equipment-scanner-secure-setup.md` | CONSOLIDATE | 8,773 | `2c9b45fe6db98f554d38534db9ac55af5d713aaf9be7e724536f946cf7cd1165` |
| `docs/integration/equipment-tutorial-video.md` | CONSOLIDATE | 10,851 | `5dcc0e0365332974a8e12fe17506c0b0ce78cf95d88c9a74a767ac6638485af0` |
| `docs/integration/gmail-controlled-uat-2026-10-22.md` | ARCHIVE | 4,034 | `71d2369de98b42085dcd4132617abfc1c404807023aeb76ec834be21120dd8bf` |
| `docs/integration/google-connection-uat-2026-10-22.md` | ARCHIVE | 3,423 | `66a3108368100677eeef94cf0c6e6ffb6651575f0e0530582d8f9d103ad3b2a9` |
| `docs/integration/google-console-verification-2026-10-22.md` | ARCHIVE | 1,575 | `ed4ea6c6585857deb2c81dd642fbe689ab1eeec09a8d11b4545c1a550b6f7f11` |
| `docs/integration/google-deployment-2026-10-22.md` | ARCHIVE | 4,076 | `f668a12e3fbf28d782f9883a32c81f8c29a3e0a399dba31f43ecbc124dc83b4c` |
| `docs/integration/google-gym-iam-proposal.json` | ARCHIVE | 5,791 | `bef6ccd10d484a66eb3d7502587e57ab630471e1492f793c4c5e130ac5fc8cc6` |
| `docs/integration/google-iam-applied-2026-10-22.md` | ARCHIVE | 2,295 | `f384a27fabfa4b54563fe6e7b837c9691b25ac9faddcce054c9ee23bd3a63faa` |
| `docs/integration/google-oauth-preparation-2026-10-22.md` | ARCHIVE | 9,503 | `22abc2e54fc130400e8723796a75bd39ec08e458c3714c3b73027c89d7609f59` |
| `docs/integration/google-oauth-verification-2026-10-22.md` | ARCHIVE | 6,430 | `42c8c09390de24cc5d15d33ee0829d94193c60111f12bd05ccee8b688ab88ed0` |
| `docs/integration/gym-google-setup.md` | CONSOLIDATE | 13,567 | `ec3e7bde3b39218284b420ff6c0fe3490ed5deeba901075cb4ae104bcb078a3f` |
| `docs/integration/module10-availability-ux.md` | ARCHIVE | 6,545 | `987e25244f236ad158a95df588c925837f5baa0262319278f88891ad320f9913` |
| `docs/integration/module4-admin-readonly-uat-2026-10-24.md` | ARCHIVE | 6,021 | `bd1dd19eccff87437a9fb6b54e6b30fb0482bb6b4f44d38e6fe04a2fbfea7522` |
| `docs/integration/module4-authenticated-readonly-uat-phone-install.md` | ARCHIVE | 10,110 | `8ce4fb694b8517d0a540d8327522afbfa71a94b1cb78f23edce0a1e2ec85b643` |
| `docs/integration/module4-catalogue-business-proposal.md` | ARCHIVE | 18,174 | `e41fbfdf4c69482cae8fc4900bb5c38277bae48bdaa67be155d108bbf26bc528` |
| `docs/integration/module4-catalogue-proposal.json` | ARCHIVE | 2,105 | `3cd4fbedbdb90b086ad8fe1d905240bbbc2ab2f261afac8d476646e6b12c6509` |
| `docs/integration/module4-membership-delivery.md` | ARCHIVE | 15,820 | `966614d656738c2f461c63f022682bb67bff7becfde7ba3fc7d315457cddf078` |
| `docs/integration/module4-membership-deployment.md` | ARCHIVE | 3,999 | `e99274533e77e2a7081e18f70f4ed54a97a34e75e16991ffa3ab24425bd91b0f` |
| `docs/integration/module4-membership-plan.md` | CONSOLIDATE | 3,600 | `53efb68c88c05507501ffd9c55038c6d2775ec768eada0dfa2e8b66f4cebff3a` |
| `docs/integration/module4-sandbox-purchase-renewal-uat-2026-10-24.md` | ARCHIVE | 22,708 | `64eab47fa12b20addae123dac094cdec05f69551c68e5dc197774dfdc022f01d` |
| `docs/integration/module4-sandbox-purchase-renewal-uat-results-2026-10-24.md` | ARCHIVE | 10,247 | `dc1b6697d24b1aaae8966a7ac4eba12e280bc93bbe8fbbcafb356fa7c4ef30f9` |
| `docs/integration/module4-three-tier-catalogue-activation.md` | ARCHIVE | 4,991 | `1695958ac11ae8e209ba8fd00e00051379f4f10a595a236f08777197160051cf` |
| `docs/integration/module4-three-tier-catalogue-business-proposal.md` | ARCHIVE | 7,201 | `8f61a7083157b580d89c44030dda50c5a6c7e1f3f405c1ed3532262572c39533` |
| `docs/integration/module4-three-tier-catalogue-proposal.json` | ARCHIVE | 2,352 | `dca3c5d6ed82bdfe282a650c025a2df7c12531c5adfb76f25be51382188e1e97` |
| `docs/integration/module4-three-tier-catalogue-staging.md` | ARCHIVE | 6,132 | `5f9c640dfd8efdd96539a56de503a32fa7c85de1c3e8ea00f9f8345a5fddde5c` |
| `docs/integration/module4-three-tier-phase1-delivery.md` | ARCHIVE | 14,046 | `d4235e2f59c65c87022ebf96fe998cb93661f6eef43b26a249b40ea4833ded89` |
| `docs/integration/module4-three-tier-phase1-deployment.md` | ARCHIVE | 6,776 | `3e8e2e16e765af049a7937563bebff9d2108219fe4a03ac4584785570d3d9a8a` |
| `docs/integration/module4-three-tier-remaining-delivery.md` | ARCHIVE | 25,872 | `56092c37deb3be7195530ffa8181dd1d968134f51ad1ca3f09d432ff030ad4c4` |
| `docs/integration/module4-three-tier-stage-a-deployment.md` | ARCHIVE | 8,069 | `0a0537b470592c05fcf3051744774f8f65657c0971802e9ef9b7ec308c9ff526` |
| `docs/integration/module4-verified-rewards-local-contract.md` | CONSOLIDATE | 11,923 | `e4dbf793c466af39656f805b6fb368024a81f4159715972578aa3b5e0c809d9d` |
| `docs/integration/module6-ai-assistant.md` | CONSOLIDATE | 20,138 | `0b37351e110bb97bd8d110e8cdadfc23fe893027abf4b31f76e0f85a5478d995` |
| `docs/integration/module7-booking-completion.md` | ARCHIVE | 10,395 | `e6503412ddf27240ade1d73ab2463ff7398d831036714231c5c6904982ab7033` |
| `docs/integration/module7-refund-booking-uat-fixes.md` | ARCHIVE | 10,338 | `e8ee34922c937df3eceec269957c92234f72130a64a025389d0262219904ff37` |
| `docs/planning/2026-10-14-b1-coach-profile-directory-design.md` | ARCHIVE | 28,212 | `31a794622733bd869a98370d942b82e6e3a9f073f7c8ef4b3c9a6e0734aa4404` |
| `docs/planning/2026-10-14-b2-dated-availability-plan.md` | ARCHIVE | 24,168 | `f05cdcd64a9531695ae54a4b451052c841d324c16584c9d2100af0389b876576` |
| `docs/planning/2026-10-14-b3-pending-booking-plan.md` | ARCHIVE | 33,520 | `6246a2d2359b572f54c6fd31632d05affb599a2aacdbae20fd88fee627294d29` |
| `docs/planning/2026-10-14-crud-integration-matrix.md` | ARCHIVE | 17,391 | `b1c335fc9163f763a6360a9eff8bc2bef77d03acb5a375f0990da8b6ebeb33c0` |
| `docs/planning/2026-10-14-mvp-vertical-slices.md` | ARCHIVE | 16,043 | `3eb7f1c36bdb38d3a34db62a56b5925d9dee9ed9c04aa5d2e1a75022a463b7e4` |
| `docs/planning/2026-10-15-b1-b2-predeployment-repair-proposal.md` | ARCHIVE | 6,164 | `f6cfeaf53439dcb0b9a08c34219d8ee59d607f862f144b66ab937838ebc1a700` |
| `docs/planning/2026-10-15-b4-hold-lifecycle-plan.md` | ARCHIVE | 2,879 | `72a28e1ee3c9661e744c0d260d3369ce7d50a4e18c6b06a7492834c50ae469b5` |
| `docs/planning/2026-10-15-coaching-read-performance.md` | ARCHIVE | 6,219 | `09724a58746c9510c517e27fca110f97cf6d8bcf707ac28c9d23fc0674b73d6b` |
| `docs/planning/2026-10-15-coordinated-firebase-activation-preflight.md` | ARCHIVE | 20,718 | `ffbb500e26732c77ffec8baca4257ddc57e0eecad94458d43bdd3d7ae4dc544f` |
| `docs/planning/2026-10-15-non-core-crud-sprint.md` | ARCHIVE | 4,274 | `c811a280b02ad739d4c16aa11277cee61cc31b657e5d575321178632dbe9e278` |
| `docs/planning/2026-10-20-consultation-notes.md` | ARCHIVE | 1,897 | `20ca43417543834f7b0314d994c0bcf8c9833afca5c382c77e62846437096716` |
| `docs/planning/current-project-audit.md` | CONSOLIDATE | 43,954 | `19772ef7d233db2939f2bf9b649a33535cf07a7cc8c6035a9fba20ac80d58eb0` |
| `docs/planning/master-implementation-roadmap.md` | CONSOLIDATE | 58,553 | `e465e776f285748759a2a5ca87e93c9e8a42320ad3df454666d4ca0f44b9f696` |
| `docs/planning/module4-three-tier-approval-proposal.md` | ARCHIVE | 3,798 | `48965771784e1868da8e6d9e7ab7633704ee497dfbf029d48b8af273b82c795f` |
| `docs/planning/module4-three-tier-phase0-audit.md` | ARCHIVE | 30,234 | `e8c04194afa751f7f1e8881a3c732b82da2bdba67a5924df37a339aa5e255149` |
| `docs/planning/module4-three-tier-policy-draft1.md` | CONSOLIDATE | 15,651 | `5380b2772afba2b7f5cd89358f4cd2260ef00efa490b347bd7879779cad5e939` |
| `docs/planning/next-implementation-handoff.md` | CONSOLIDATE | 24,362 | `2289f14e7716bbd492b293dbe91fd7843516ef75790af2cce3ec03c18424f608` |
| `docs/planning/p8-1b-bodyweight-squat-activation-approval.md` | ARCHIVE | 11,043 | `1972de22efaa842c3fce4f48a096caea579d92047a12e53d5f2b71f3c9205106` |
| `docs/planning/p8-1b-bodyweight-squat-rename-activation-plan.md` | ARCHIVE | 14,696 | `c437ebabc0c696d65ede78d8dd76856273c8974415b55ba6c00a170a0d8de6db` |
| `docs/planning/p8-1b-live-activation-next-gate.md` | CONSOLIDATE | 9,143 | `e2ba8ad40cdecffc292834d2352294322962a4d1d08fc5d219df183b1459329e` |
| `docs/planning/p8-1b-tutorial-activation-handoff.md` | ARCHIVE | 18,741 | `c3f3afbd53af024a843d599eac7ca3f122cc871e484b379fe1be8522ee7f0c35` |
| `docs/planning/pose-core-technology-assessment.md` | ARCHIVE | 55,454 | `00452893e41a09925e507b9502cc2926855509af6436f708931c163c844a3309` |
| `docs/planning/premium-coach-voucher-local-contract.md` | CONSOLIDATE | 6,238 | `59e3f463e0916325062f401cb8cae6e8e67461cb17d6c4bb5b0ef48c2f1d1c21` |
| `docs/planning/requirements-gap-matrix.md` | CONSOLIDATE | 49,550 | `cf39941d274cc84f5f9856f17b9ce68230f39ab4d52b1c273553b5a179e403c6` |
| `docs/superpowers/plans/2026-08-16-chatbot-module-redesign.md` | ARCHIVE | 33,120 | `04ac883b6d7ff047f502543547848743abdefadefbbfcf70f917c6c23b7d3917` |
| `docs/superpowers/plans/2026-08-16-progress-report-module-redesign.md` | ARCHIVE | 54,638 | `42989a6c945577688bb34b4727f3ec3458c0d4e0ce426b58c7e76a219eac9e8e` |
| `docs/superpowers/plans/2026-09-06-architecture-restructure.md` | ARCHIVE | 49,009 | `a9f10857c4cc58f2dfce2b89d692e83ad252f5a3f7772c2b3d76397555665cd8` |
| `docs/superpowers/plans/2026-09-18-complete-architecture.md` | ARCHIVE | 3,388 | `591957b1b0d3ff1c080ae4e3ecf05b23ff4baa0777d8b34484cd328e78abab98` |
| `docs/superpowers/plans/2026-09-20-firebase-identity-bootstrap.md` | ARCHIVE | 5,867 | `02e07fd22858e092845a2b4416e7d3fcb33c6d32b29c750c80f913739626866c` |
| `docs/superpowers/plans/2026-09-25-feature-implementation-roadmap.md` | ARCHIVE | 19,613 | `597fe822059f68e49a9bcc0696b65c506639ebb805d19117e316a8548a24477e` |
| `docs/superpowers/plans/2026-10-01-workout-content-vertical-slice.md` | ARCHIVE | 3,977 | `67ee6847f580e695e516a2ca4a9d041ea9c552c66bfb1b9a06e5132cfaf43a0e` |
| `docs/superpowers/plans/2026-10-02-blazepose-foundation.md` | ARCHIVE | 8,051 | `42f52d64d88503285c3bf6a766458a333032814c33fcc7bcb8f4c327564e83cd` |
| `docs/superpowers/plans/2026-10-02-real-pose-workout-handoff.md` | ARCHIVE | 19,880 | `998736b02cf6001fb4231b8b87378e09a4826ad473626780b37d402064f68203` |
| `docs/superpowers/plans/2026-10-03-dynamic-joint-lag.md` | ARCHIVE | 4,560 | `dd485678cab33c703374ba6bfd25df524294b2e29bf451afe3c9fb7f5d6ff89d` |
| `docs/superpowers/plans/2026-10-07-step3-squat-processing.md` | ARCHIVE | 6,875 | `7d9ca44bbdc6479e568798252c0771ddceb0e728e30b7f01dde467250511d0c7` |
| `docs/superpowers/plans/2026-10-08-step4-real-workout.md` | ARCHIVE | 2,713 | `57bec88f08394d884b6e25e8d7190ef96f9a0b71fcdfc001befb5e62f5db2758` |
| `docs/superpowers/plans/2026-10-12-squat-fixture-validation.md` | ARCHIVE | 4,326 | `0a3f38aca3f11cb1a3b4264a02d3745f934fb1cf0be99135f75382d254a5070a` |
| `docs/superpowers/plans/2026-10-12-step5-trusted-sync.md` | ARCHIVE | 1,839 | `f00152ba428038bb6b37124bc66f07ec2223613d2db37acb58e851481dcc222d` |
| `docs/superpowers/plans/2026-10-13-local-member-progress.md` | ARCHIVE | 8,008 | `5b6e4865df0fb8311a4596f0506df3105cfe00d944d8a2ddc51d3ff392d3219f` |
| `docs/superpowers/plans/2026-10-13-member-tutorial-playback.md` | ARCHIVE | 7,649 | `ff0454853c606f435f18db3bd8ca7994153e7c66bba8a17d539948c169cda98e` |
| `docs/superpowers/plans/2026-10-13-p0-ci-recovery.md` | ARCHIVE | 4,652 | `0143961ceec3f2b05cb83e50f0d9211e57ebe187f1a3c1b4ae6019d4d04656c5` |
| `docs/superpowers/plans/2026-10-13-real-squat-direct-preview.md` | ARCHIVE | 3,927 | `eb684e90fa4bbbd348d15d5e9d0fad315d968613cd8a67803849e2a4e1d36725` |
| `docs/superpowers/plans/2026-10-13-real-squat-gpu-comparison.md` | ARCHIVE | 2,909 | `a1ad79bd209100a8f71995e141c27fecaa2c240a86e10024c33ba1789c30f53f` |
| `docs/superpowers/plans/2026-10-13-real-squat-performance-diagnosis.md` | ARCHIVE | 2,759 | `fb5afe22783003fc168fae9eb29e4ed5999cdd8c16334a5801bb6a23a81d9617` |
| `docs/superpowers/plans/2026-10-13-squat-quality-and-3d-comparison.md` | ARCHIVE | 5,692 | `d0459106c304ec905741bf9d67986ae952be2c6f189354e06b4c98e4f9b449f5` |
| `docs/superpowers/plans/2026-10-13-step7-implementation.md` | ARCHIVE | 4,548 | `b55899a3b17e46c016e9e8dd7de9dd9c415791257ab623ef4e99be22cb330a57` |
| `docs/superpowers/plans/2026-10-14-gate0-catalog-concurrency.md` | ARCHIVE | 1,939 | `2ad25fe6e3b08e26a391c385ecf95fb14dab20844a5c1d493c15c315e2f9bd29` |
| `docs/superpowers/plans/2026-10-18-unified-admin-web-integration.md` | ARCHIVE | 26,683 | `90b52e7247d0c15bc03925ac9017d0d5cca4a09103694354437b56511d69732b` |
| `docs/superpowers/plans/2026-10-20-equipment-scanner-review-fixes.md` | ARCHIVE | 1,252 | `d12cbf2858c18b4bf40616bf0bba1f9b250272fb7682c24bdce27b9a8a156217` |
| `docs/superpowers/plans/2026-10-20-module-9-completion.md` | ARCHIVE | 25,825 | `c1d7f87d4fc032257bc3bb226635a1fdddf67067287532f0f6b08cc5dc660e73` |
| `docs/superpowers/plans/2026-10-20-module-9-final-execution.md` | ARCHIVE | 1,414 | `1c31e7adea981b4671f46a650435e4af06d56fad1494b6b87b489ef599316409` |
| `docs/superpowers/plans/2026-10-21-ai-booking-calendar-email.md` | ARCHIVE | 3,985 | `71df81cdb43c29d12b1b3a842576ba5e061df73c0588b016d4800157128a1aee` |
| `docs/superpowers/plans/2026-10-21-module-6-ai-assistant.md` | ARCHIVE | 2,593 | `21eed26fd1ad3413f3cc157f2fb7ea4a6e1287696fcd12a06e9741d738f3aa04` |
| `docs/superpowers/plans/2026-10-21-module7-booking-completion.md` | ARCHIVE | 2,396 | `7c145a099afc0d4add0de53d5cd2695a2cffe22ed68b51c4091b1ec276f5dc99` |
| `docs/superpowers/plans/2026-10-22-automatic-google-delivery.md` | ARCHIVE | 2,847 | `30e9bffab47b83cd6e0265b5a4937d877836b78711c872d970c075a6c543535a` |
| `docs/superpowers/plans/2026-10-22-gym-google-integration.md` | ARCHIVE | 3,905 | `8f99e92e3cbf7f09dd01d5fed8c9e13d568c3f1daaa2adc2acd46fa9329bc94d` |
| `docs/superpowers/plans/2026-10-23-membership-authenticated-read-only-uat.md` | ARCHIVE | 19,338 | `b2806c392be2dd90eeda6a5e72eeade4e8774a4783718c814c98484e1673f56f` |
| `docs/superpowers/plans/2026-10-23-three-tier-phase1.md` | ARCHIVE | 4,122 | `a9fb64e5252d8f470f6f33ac765c3a2578e1e674c98fd1628aa236d42dcc5711` |
| `docs/superpowers/plans/2026-10-23-three-tier-remaining.md` | ARCHIVE | 7,914 | `dbf875ce502acd5dccd22c2797ba0418b76844d9ed2cc8ae2ab43fafa6a3c10d` |
| `docs/superpowers/specs/2026-08-16-chatbot-module-redesign-design.md` | ARCHIVE | 14,608 | `42b87067004b4e8c6e2e107f065f0352ae90dc3538ce914ba0eef6c2c04fc34e` |
| `docs/superpowers/specs/2026-09-06-architecture-restructure-design.md` | ARCHIVE | 9,408 | `cefd949f91c7dbac0f9d571572b256093a03466d1d0c6ae11bce08e4dc548c16` |
| `functions/README.md` | CONSOLIDATE | 4,906 | `bee780bf81716245c321b03f0e3936c3fa49985266cefa6d8d2d71c5031b1258` |
| `functions/src/modules/README.md` | CONSOLIDATE | 2,648 | `5713565b8eb6052842500d57ea439b1f90954edc7bc22236abc6873e8fd3eac8` |
| `functions/src/platform/README.md` | CONSOLIDATE | 1,885 | `b66fd29619be0ba08bde3f6d931e00989e5aae4d557c01fd7e607944a35e935d` |
| `tools/admin_web/README.md` | CONSOLIDATE | 1,143 | `0a7e68a0d8f3577ebae92f2c4968c6112478bd6599486066e34c2c8177e3081d` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c1.md` | ACTIVE | 56,381 | `ffe6e7930d37d5fa693b03e8dc7af44e822baec70222bc56882aa006a67264e3` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c2.md` | ACTIVE | 277,129 | `31c1c7ae1eec982dd8b4fadca813137cc3e9f82b735cb9bcf9ca9b6bdcd0e7ee` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c3.md` | ACTIVE | 447,308 | `ed55a2b8dbfb697ffec023ccd91d6332410fb6bd1751b9318c3bf349e3bead2b` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c4.md` | ACTIVE | 187,322 | `67aafcd6117601ad5fe6aa34e90f755be85753bd3188363cae39e2ef263e05e7` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/GainPath_Chapter_4_9_Aligned_Algorithm_Design.md` | ACTIVE | 20,841 | `15bacbd04d883f9f48ae969224f8c150c8077488cbf505112d9f86d59cc1841d` |
| `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/sequence_diagram.md` | ACTIVE | 106,601 | `df9a10228c1007deb1a422e50da9c4d2f2b34e8dab4fd81c08ded9ad531a83e2` |

</details>


## Phase 1 entrypoint baseline

The owner subsequently approved documentation consolidation only on 24 October 2026. The original audit above remains a dated baseline; Phase 1 completion and checks are recorded below. Existing historical evidence remains in its original location.

The pre-consolidation README contained uncommitted guidance. Its original text is preserved here before replacement; SHA256 `0150846276eb3e68c5f6b1ca29b1f884a7304b59ca2c42f5b6c919fc5d004e46`.

<details>
<summary>Original README — historical snapshot, not current instructions</summary>

````markdown
# GainPath

Two independent Flutter apps in one Dart workspace, with shared packages and a modular Firebase backend foundation. The architecture migration is implemented; most product workflows still use isolated prototype data, not live backend services.

## Run

From this repository root:

```powershell
flutter pub get
cd apps/mobile
flutter run --dart-define=BACKEND=mock
```

The mobile app opens on a shared sign-in page. In mock mode, use
`coach@example.com` to preview the coach area; other email addresses open the
member area. Mock authentication does not check the password. Firebase mode
routes from the account's stored role.

For the separate admin console:

```powershell
cd apps/admin_web
flutter run -d chrome --dart-define=BACKEND=mock
```

Use Flutter 3.38.9 / Dart 3.10.8 (the versions used for local verification and CI). Mobile includes Android and Windows runners; only Android was build-verified. The root is a workspace, not a third Flutter application.

## Structure

```text
apps/
  mobile/                 Member/coach app, Android and Windows runners
    lib/app/              Composition, guarded routes, navigation shells
    lib/navigation/       Names and arguments, no destination construction
    lib/features/         Feature BLoCs and presentation; scoped workout slice
    lib/infrastructure/   Account-scoped durable workout storage
  admin_web/              Independent staff/admin app and web runner
    lib/app/              Composition, guarded home, admin shell
    lib/navigation/       App-local navigation primitives
    lib/features/         Administrative feature screens
packages/
  gainpath_domain/        Pure Dart entities, policies and repository ports
  gainpath_data/          Pure Dart adapters, DTO mapping, isolated demo data
  gainpath_identity/      Shared AuthBloc and role policy; domain contracts only
  gainpath_ui/            Shared Flutter design tokens and visual primitives
  gainpath_pose/          Pure Dart pose-processing engine and detector port
functions/src/
  modules/                Coaching command, commerce ingress, workout contracts
  platform/               Authorization, validation, transactions, idempotency
contracts/                Versioned backend request/result schemas
firebase/                 Rules, indexes and emulator configuration
tool/                     Architecture enforcement and workspace verification
```

Dependency direction: presentation → application → domain ← data. App composition selects concrete implementations. Apps never import each other; domain and pose never import Flutter/Firebase; features navigate across boundaries using names/arguments. Shared source does not mean shared runtime state.

## What is functional now

- Member/coach and admin prototype screens reside in their respective apps.
- Authentication contracts support restoration, stale-result cancellation and role gates. Demo repository state is recreated per authenticated session.
- In Firebase mode, verified members complete a private fitness profile (gender, age, height, weight, goals, activity and experience), then enter the existing member shell. Home shows saved profile data; the existing Profile tab edits and persists all fitness fields. Account Settings persists notification and voice preferences, and Change password uses Firebase reauthentication. Missing profiles open setup; load failures offer retry. Logout returns to the shared login and discards the previous account's UI state.
- Guided workout simulation saves account/organization-scoped records atomically in application-support storage on native mobile/desktop. History retains pending uploads; the default uploader does not pretend that a server accepted them.
- Booking-hold backend transactions validate membership, branches, availability, overlapping slots, daily caps and idempotent retries.
- Payment ingress has a tested verification/persistence boundary; the deployed handler deliberately returns unavailable until a provider-specific verifier is supplied.
- Firestore rules and real-emulator transaction tests cover ownership and authorization failures. Hosting targets only `apps/admin_web/build/web`.

## Production gates

`BACKEND=firebase` connects authentication, membership provisioning, member fitness profiles and published routine reads. Members enter the same five-tab shell and screen layouts as mock mode. Home and Workout display a published organization routine when one exists; other unconnected controls respond with an unavailable message instead of opening mock data. Profile and Settings use real Firebase data. Coaches see the authenticated account screen while their feature adapters are built. Mock mode is prohibited in release/production builds. Build the current demonstration with `--debug`; do not deploy it as a production service.

Firebase member identity, profiles/settings and published routine contracts are connected. Native Android BlazePose and the provisional side-view squat analyzer save measured, account-scoped local results. Member Home/Progress/History read those records and matching durable upload metadata. Estimated form is a versioned rule metric, not AI accuracy. Default CPU behavior and experimental GPU artifacts remain separate; trusted workout tuples remain disabled until physical acceptance. Provider checkout/refunds, coach workflows, authoritative rewards and remote history remain separate work.

### Member fitness profiles

Run the connected app from `apps/mobile` on Android. Use `flutter devices` to find your Android device ID:

```powershell
flutter run -d <android-device-id> --dart-define=BACKEND=firebase
```

The checked-in Firebase options cover Android only. If Windows is the default device, `flutter run --dart-define=BACKEND=firebase` displays a configuration message instead of opening the connected app. To preview the Windows interface with demo data, run `flutter run -d windows --dart-define=BACKEND=mock`. Windows Firebase would require a registered Windows app configuration and support for the callable Functions flow used during member registration.

Profiles are stored at `orgs/{organizationId}/profiles/{userId}` with schema version 1 and a server timestamp. The Firestore rules require an active, verified member to read or write their own profile; they reject extra privilege fields, incomplete payloads and invalid measurements. The new rules in `firebase/firestore.rules` must be deployed before the feature can use a live project. This implementation does not deploy them automatically. From the workspace root, the deployment command is:

```powershell
pnpm --dir functions exec firebase deploy --only firestore:rules --project gainpath-0619
```

Profile loading requires a server response so an offline cache miss cannot overwrite an existing profile. Save errors retain the current answers for retry. A timeout means confirmation is still pending; a queued Firestore write may complete when connectivity returns. Profile photos, numeric goal targets and the remaining member dashboard features are separate follow-up work. The existing mock screens remain available through `BACKEND=mock`. See [member Firebase data ownership](docs/architecture/member-firebase-data.md) for the source-record and aggregate boundary.

Member Settings saves three opt-in choices at `orgs/{organizationId}/preferences/{userId}`. An absent document means each choice is off. Saving a choice does not activate push or email delivery; those services are still separate work. Change password reauthenticates with Firebase before updating the credential. Firebase mode hides the prototype-only deactivation control because no account-deletion service exists yet.

## Verify

```powershell
./tool/verify.ps1 -BuildApps -Backend -Emulators
```

Requires Flutter, Node/pnpm, Java and the Android SDK on PATH. The script stops on failures. CI runs the equivalent checks without deploying. Architecture violations remain blocking. Root tooling plus pure-Dart domain/data/pose suites run with `dart test`; Flutter identity/UI packages and applications run with `flutter test --no-pub`. Analysis targets maintained lib/bin/test/integration_test/tool folders, preserving historical build snapshots without treating them as current source. The root `pubspec.lock` and `functions/pnpm-lock.yaml` pin dependency resolution.

See [implementation report](docs/architecture/2026-09-19-architecture-implementation.md) for the implementation map, evidence and next process. The [target blueprint](docs/architecture/2026-09-17-gainpath-target-architecture.md) includes the longer-term backend/runtime diagram.

````

</details>



## Phase 1 completion — 24 October 2026

Owner-approved scope completed locally: documentation consolidation, agent workflow simplification and source-based Admin architecture clarification. No Phase 2 work was started.

- Established the six active references: `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/OPERATIONS.md`, `docs/archive/README.md`. The new references own current guidance; original paths remain discoverable through the archive index and Appendix A.
- Added supersession notices to 12 general setup/handoff/source-guide documents, preserving their original bodies byte-for-byte. Replaced the root README after preserving its exact original UTF-8 content in the historical snapshot above. The original audit body remains byte-for-byte intact (baseline SHA256 `564abd0c5922d388ae7b7a75de0bd90013f7a390e20df589a0ee373cbb309350`).
- Validated **144 local links/anchors** across the six active references and 12 new notices: no missing targets or anchors. External links were not fetched. Historical body links were retained, not represented as newly repaired or validated.
- Verified all **219 baseline items**: 206 unchanged originals, 12 unchanged original bodies after their added notices, and the exact original README snapshot. All six protected external academic files and original financial/deployment/provenance/rollback records are preserved.
- Rehashed **1,347 non-document source/configuration/compiled-tooling files** against the pre-edit baseline: zero changes. Existing unrelated Git status entries remain intact; new status entries are documentation only. No build/test generation, clean, source/configuration edit, cloud access/mutation, payment/account change, installation, private-data change or Google action was performed in this phase.
- Admin findings: normal entrypoint is `apps/admin_web/lib/main.dart`; authenticated navigation is sidebar/widget state with 13 destinations and additional account/nested coach views, not page URL routing. Each normal app main currently pins Firebase. `BACKEND=mock` alone does not switch modes; explicit Mock injection is supported, but no standalone Mock launch/build entrypoint exists. Operations records exact existing Firebase build/serve commands and the supported Mock composition test without inventing a CLI mode.
- Repository findings: normal Firebase services coexist with neutral/unavailable presentation capabilities, not seeded mock business records. Explicit constructor overrides can mix backends; there is no universal mode-homogeneity guarantee. The temporary same-origin membership UAT page/server is separate from the normal Admin application.

Remaining recommendations, requiring a new authorized scope: verify/fix entrypoint backend selection and mode isolation; review the audit's small source candidates before any removal/refactor; prepare a retention manifest before artifact relocation or selective cache cleanup. Held Stage B/C work, the Billplz refund 422 issue, scaling/App Check exceptions and cloud cleanup remain separate. No release, source, artifact, device or cloud action is queued by this completion.

## Owner-approved Markdown pruning

The owner subsequently requested deletion of obsolete/redundant Markdown rather than archive relocation. The reviewed allowlist removed **46 files**, reducing source-repository Markdown from **209 to 163**. No source code, non-Markdown files, directories, cloud resources, accounts, payment records or build artifacts were deleted. The six active entrypoints and original FYP/financial UAT/deployment/provenance/rollback evidence remain retained.

Twenty-five affected links in 16 retained documents now point to retained guides/implementation records. Four pre-existing broken references were also corrected (three old Admin view paths and one model-source relative path); source/license/measurement content is unchanged. The removed-path replacement table is in `docs/archive/README.md`. Appendix A and Phase 1 preservation statements above remain dated baseline history; they are not a claim that removed paths still exist.

The exact allowlist, original hashes and deletion journal are in ignored `build/documentation-prune-20261024/manifest.json`. The ignored recovery ZIP contains 68 pre-edit documents (46 deletions plus link/index originals), SHA256 `27cef622b0ba6bb333999f7c1fd52fd25f103013c27810f433c21dc03edab2ad`. No files were moved into `docs/archive/`; no new Markdown report was created.


## Second owner-approved Markdown pruning

On the owner's request to identify and delete further redundant documents, the second reviewed allowlist removed **28 additional Markdown files**, reducing **163 → 135**, or **74 deleted cumulatively from the original 209**. Completed plans, superseded Membership/Google proposals, intermediate CI summaries and slice handoffs were replaced by retained delivery/current guides. The existing historical index consolidates source heads, CI run references, evidence locations and validation limits. No new Markdown report or archive tree was created.

Eight affected Markdown links in seven retained files were redirected. The original academic sources, requirements matrix, actual financial UAT, catalogue staging/activation, deployment/rollback reports, raw evidence and all model/physical provenance remain protected. The superseded technical handoff's exact historical compliance/source/deployment ledger is retained in the recovery ZIP rather than remaining an active reading dependency.

Exact allowlist, hashes, replacement map and extracted provenance references: ignored `build/documentation-prune-round2-20261024/manifest.json`. The recovery ZIP contains **37 pre-edit originals** (28 deletions plus nine retained link/index/status/audit originals), SHA256 `91ec08cfdf19a0a8039a6e01d035e6365ed0627c1ca9a404b884e28af346fc97`. Every entry was hash-verified before deletion. No source, account, cloud, provider, build-cache or device operation was part of this pass.

Second-pass verification: **990 local links/anchors checked, zero missing targets, broken anchors or references to the newly deleted paths; 1,492 non-Markdown files unchanged by SHA-256; exactly nine retained Markdown files changed, all in the backup allowlist; scoped git diff --check passed.** Application tests/builds were not rerun for this documentation-only pass.
