# Three-tier membership — Phase 0 design and repository audit

23 October 2026. Project `gainpath-0619`; organization `gainpath`. **Design review only. No implementation, catalogue publication, account migration, deployment, device installation or financial UAT authorized or performed.**

Source policy: [user Draft 1.0](module4-three-tier-policy-draft1.md), preserved from the attachment. The user selected the Free/Basic/Premium product direction. Proposed prices, durations, detailed entitlements and implementation mechanisms still require explicit approval. The earlier [two-tier catalogue proposal](../integration/module4-three-tier-catalogue-staging.md) and its JSON are historical drafts, not an executable/approved catalogue for this roadmap.

## Findings that determine the roadmap

1. The existing paid-membership payment foundation can be reused. Free requires a derived entitlement, not an RM0 bill or a fake plan with an expiry. `membershipPlan()` deliberately rejects zero-price paid records.
2. Account/organization membership is authorization; paid membership is a separate commercial entitlement. Never set `orgs/{org}/members/{uid}.status` to expired when a paid term ends. That would break Booking, AI and other account-authorized flows.
3. Catalogue benefits are text only. None of the proposed exercise, reporting, reward or voucher restrictions is implemented by publishing text/flags in a plan document.
4. Only one local real-camera development exercise binding was found. Two active Firestore catalogue entries do not imply two validated pose exercises. The Free whitelist is **not yet approved**.
5. Real measured progress exists, but live detailed volume/goal reporting is incomplete. Premium analytics requires functional reporting work and definitions, not merely locking existing tiles.
6. Member points and redemption are still prototypes; the real Admin reward catalogue stores draft/archived metadata only. A trusted reward ledger/redemption lifecycle must precede monetary-value Premium benefits.
7. The proposed coach voucher changes settlement/commission accounting. Current commission derives from the cleared booking amount; reducing that amount silently reduces coach earnings unless a separately approved funding rule changes the calculation.
8. Staff verification has no dedicated current workflow. The Flutter role enum contains `member`, `coach`, `admin`; the generic backend recognizes a `staff` role, but that does not establish an end-to-end staff sign-in or verification permission.

## Verified baseline

Source review covered membership domain/UI/commands; workout launch, supported binding and acceptance; local progress/report routes; gamification/reward metadata; booking price/settlement/commission; chatbot tools; Admin role gates and Rules.

Read-only live inventory at **15:59 MYT** (`build/module4/three-tier-phase0/inventory.json`, per-collection query limit 500):

| Resource | Observed state | Meaning |
|---|---|---|
| `membershipPlans` | 0 documents | No business catalogue is published. |
| `membershipAccounts` | 0 documents in bounded query | No paid account migration is justified by this inventory. Recheck before any future rollout; this is not authority to create accounts. |
| `exerciseVideos/F3b8xIr8ynBDd3gEICKX` | Active; “Verification Squat 1” | Matches the explicit local development binding; not proof of accepted model quality. |
| `exerciseVideos/EmiJSDbCAwcVnyDwS6OA` | Active; “Testing” | Published content references it, but the inspected real-camera route has no matching binding. Do not whitelist it as pose-supported. |
| `exerciseVideos/s1ERYwaBd19TqXoHpk2R` | Inactive; CRUD UAT entry | Not a publishable Free exercise candidate. |
| `content/routine_PTe4DxLS3WZ2DsfpGTOy` | Published “Verification Routine”; references the two active IDs | Publication proves content availability, not pose-rule support. |
| `rewardCatalog` | 2 archived metadata records | No active physical reward product or real redemption stock/points contract established. |

At **16:01 MYT**, all **55 Function metadata records**, Rules and Hosting release metadata matched the accepted post-Module-4 deployment. Evidence: `build/module4/three-tier-phase0/preservation.json` and `build/module4/deployment-three-tier-phase0.json`. No authenticated financial commands or provider calls were made. Application source and frozen workout/pose code were not modified. No new-feature runtime test or device acceptance is claimed by this design audit.

## Requirement trace and gaps

`TP-*` identifiers below are audit aliases for sections of the user draft, not newly approved dissertation FRs. Chapter references use `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c3.md` / `c4.md`. The older requirements-gap matrix supplies FR/UC references only; its historical implementation assessments are not treated as current evidence.

| Trace | User policy / Chapter 3–4 relationship | Current evidence | Gap and proposed phase |
|---|---|---|---|
| TP-01 §1, §3.1 | New explicit Free/Basic/Premium model. C4 Table 4.12 mentions Basic/Premium; UI/enum also mention Elite. | Paid plan identity is `planId`; no Free resolver. | Phase 1: derived effective Free; no Elite in this scope; preserve authorization roles. |
| TP-02 §2.1, §3.2 | FR-4.1/4.2/4.4; UC-4.1/4.2/4.5/4.6 support trusted purchase/dashboard/history/renewal. RM49/RM89 and 30 days remain proposed. | Deployed verified purchase/renewal, snapshots, invoices and review recovery. | Reuse billing; extend projections/domain/UI for effective tier; separately approve paid catalogue. |
| TP-03 §3.3–3.4 | UC-4.6 explicitly preserves paid remaining time. Free fallback and deferred tier conversion are new clarified business rules. | Same-tier `max(now,expiry)+duration`; active different-tier blocked; overview currently returns `none`/`expired`. | Phase 1: derived Free at expiry while retaining paid tier/history; no prorated switch or member-status mutation. |
| TP-04 §3.2.6 | Historical FR-4.3/UC-4.4/C4 show auto-renew; new draft explicitly keeps it unavailable. | No recurring mandate; server returns unsupported. | Retain manual-only behavior; align FYP diagrams/text, do not invent subscription IDs. |
| TP-05 §2.1, §6 | Manual gym admission/verification is new product work; not existing voucher processing UC-11.16. | No current staff membership-verification service/screen. | Phase 2: permission-scoped, server-authoritative read in existing account-management surface; approve verifier role and admission exception. |
| TP-06 §2.2 | FR-2.1–2.9 define workout/pose/safety features, not a Free whitelist or paid content limit. | One development binding; live catalogue has two active IDs; source accepted-model allowlist is empty. | Phase 2: approved ID-based content/start eligibility wrapper; preserve all pose/safety components and existing validation gates. |
| TP-07 §2.2/2.3 | FR-5.1–5.7 cover summaries, reports, history, goals, filtering/export. Exact Free limits and Premium allocation are new. | Real local summary/history/form data; detailed volume/goal views have placeholders; no tier report endpoint. | Phase 2: define history boundary and report metrics, implement real reports, gate entry/computation without deleting data. |
| TP-08 §2.4 | FR-3.1–3.7 cover games, daily rewards, streaks, points, vouchers, leaderboards; they do not establish Premium 1.5×. | In-memory points and local claim flag; synthetic game scoring; no exported trusted points-award/redemption command. | Phase 3: real server-verified award ledger, source policy and anti-abuse; then multiplier. Do not promote mock points into earned balances. |
| TP-09 §2.4, §4 | Paid-only physical redemption and Premium-exclusive stock are new. C3 BR-8/9 require once-only manual fulfilment; BR-10 requires uniform Admin-set exchange rate. | Admin metadata schema excludes stock, point cost, tier eligibility and fulfilment states. | Phase 3: reviewed schema/Rules and transactional debit/stock/voucher fulfilment; preserve uniform exchange rate. Earning multiplier is separate from redemption conversion. |
| TP-10 §2.5 | FR-6.1–6.6 support existing AI assistance; no new paid AI quota requested. | Gemini callable, scoped progress and coach/booking suggestion tools exist; role/auth checks, not paid membership. | Regression only. Preserve current tools/limits across tiers. Clarify interaction between Free history display limits and existing chatbot aggregate facts; do not silently add AI gating. |
| TP-11 §2.6 | FR-7.1–7.6 support paid coaching for members; no exclusive tier discount is specified in original FRs. | Coach fee comes from trusted publication; holds, settlement, cancellation/refund and Google delivery are implemented. | Keep all current coaching functionality for all eligible tiers; Phase 4 adds an explicitly reviewed voucher quote/lifecycle only. |
| TP-12 §5 | One voucher/cycle, 10%, RM15 cap are new proposed finance rules. | No cycle ledger or booking-discount input in trusted pricing; settlement matches one full `amountMinor`. | Phase 4: cycle grants, issuance/reservation, integer quote snapshot, provider recovery and cancellation rules. Finance decision blocks implementation. |
| TP-13 §2.1/§3.3 | FR-4.5/UC-4.7 and FR-11.9/UC-11.20 separate claims and review from transfer. | Seven-day owner-authorized request, Admin decisions; membership execution blocked. | Reuse request/status flows. Do not enable transfers, infer entitlement reversal or claim existing Billplz HTTP 422 resolved. |
| TP-14 related M12, Phase 5 | FR-12.6/12.7/12.8 concern redemption/revenue/engagement reporting. New cycle/discount events change their definitions. | Admin reporting gateway defaults to unavailable; no verified new tier/reward/discount aggregates. | Phase 5: real paid-vs-effective counts and discount/reward accounting once source ledgers exist; no fabricated metrics. |

The user matrix is the proposed future access policy. Existing unrestricted access remains unchanged throughout Phase 0. New restrictions on workouts, reports and redemption require their phase-specific authorization; selecting the business direction does not activate them.

## Inventory: supported exercises and report surfaces

The actual live Firestore exercise ID candidate is **`F3b8xIr8ynBDd3gEICKX`**, organization `gainpath`. `DevelopmentSquatBinding.resolve()` in `apps/mobile/lib/features/workout/domain/real_workout_contract.dart` resolves only that pair, with `bodyweight-squat-side-v1` and `side` view. Its own comment says this is a development candidate, not enabled/device-validated acceptance. The starter/mock ID `bodyweight_squat` is not an alternative live catalogue ID.

`functions/src/modules/workouts/workout-service.ts` currently contains an empty `ENABLED_WORKOUT_TUPLES` default, with deliberate quality-acceptance comments. This is a **source finding**, not proof that a historical deployed workout binary has identical model support. No deployed source archive/model validation was activated or changed. A membership plan must not bypass that existing quality gate or market additional pose exercises. If the validated supported catalogue has only one usable exercise, Free and paid exercise availability may initially be identical; do not invent paid exercises to create differentiation.

Reports use `MemberProgressRoute` views `dashboard`, `history`, `performance`, `form`, backed by `StoredLocalMemberProgressRepository` and `calculateLocalMemberProgress` over account-owned measured summaries/outbox status. The inspected source has no member premium-analytics callable. `WorkoutPerformanceScreen` cannot derive real kg volume from captured repetitions alone and displays unavailable live volume fields. `GoalProgressScreen(live:true)` marks its mock goal comparisons unavailable. “Deep dives” is a UI grouping, not a trusted entitlement or finished reporting service.

Before Phase 2 approve: exact Free history window/count; whether the limit applies to timeline, drill-downs, charts and exports; report metric definitions/data sufficiency; and the boundary between paid visualizations and existing account-owned retained data. Local cached data cannot become tamper-proof through a Flutter visibility check. Future trusted server report APIs/content reads need their own authorization; existing owner data must not be deleted or falsified. Current `firebase/firestore.rules` permits owner-scoped workout-session reads without a paid-tier test; hiding a route does not enforce a new trusted data restriction. Decide whether the commercial limit concerns UI projections or new protected computations before proposing any read-rule change. No Rules change is authorized now.

## Proposed entitlement design — for approval, not implemented

Keep three independent concepts:

1. **Account authority:** Firebase Auth, verified email, lifecycle/suspension, organization membership and role. A paid plan never confers Coach/Admin privileges; `Free` is not an Auth role.
2. **Paid membership facts:** existing `membershipAccounts` and immutable payment/grant history, retaining previous tier, expiry and source transactions.
3. **Effective entitlement:** a server-derived, policy-versioned result at a trusted time; optional client display cache is never gym-admission authority.

Proposed resolution:

| Current trusted facts | Effective result | Retained facts |
|---|---|---|
| Eligible verified active Member, no paid plan (including an unpaid pending checkout) | Free, no expiry | Any pending checkout stays pending; no invented bill/plan. |
| Same account, recognized cleared Basic/Premium with `expiresAt > serverNow` | Basic/Premium | Current paid tier, expiry, grant/source transaction. |
| Same account, previous paid expiry `<= serverNow` | Free | Previous paid tier and exact expiry, receipts, workouts, points and confirmed bookings. |
| Suspended/deactivated, wrong organization, unverified or unauthorized | Denied/ineligible | Do not present this as a valid Free member. |
| Entitlement data unavailable/corrupt or unsupported tier | Unknown/error for decisions | Do not silently grant paid access or record a false downgrade. |
| Coach/Admin role | Separate role authorization | Do not derive member benefits or change permissions from plan names. Staff purchases, if ever needed, require a separate rule. |

Retain a paid `refundStatus: pending_review/approved` as a review state rather than silently treating it as paid membership revocation; current approval has no reversal effect. Effective expiry should be computed on authoritative reads/commands, so no expiry scheduler is required merely to change a displayed effective tier. Exact response DTO, policy configuration and any new storage paths remain design decisions to approve; no operational schemas are created by this document.

A future shared resolver must return enough context to distinguish effective tier, previous paid tier/status/expiry, policy version, trusted resolution time and eligibility reason. All financial/redemption/entry commands re-resolve against current authority. Safe core workout guidance must not be interrupted or stripped when connectivity fails or expiry occurs during a session. Apply approved restrictions at catalogue access, launch or report entry; preserve the complete correction/audio path for any available workout.

## Premium earning and cycle design dependencies

The current mock `RewardPolicy.dailyCheckIn = 50` and `(score / 10).round()` are prototype constants, not approved server earning sources/caps. `GamificationBloc` increments local points and stores a local checked-in flag. The connected reward shop uses unavailable placeholders; `VoucherScreen` is prototype presentation. Admin `rewardCatalog` is metadata-only, draft/archived and Admin-readable under current Rules. There is no trusted balance/debit/fulfilment lifecycle to which a 1.5× flag can safely be added.

Proposed future event receipt: stable organization/member/source-event identity; approved base amount and source-policy version; trustworthy eligible earning time; effective tier/policy at that time; awarded integer amount; immutable once-only ledger entry plus atomic balance update. Premium arithmetic can be integer `floor(base × 3 / 2)` with safe bounds. Do not multiply current balances, re-award old receipts, accept raw mini-game scores, use pose fixtures as financial evidence or change the central redemption exchange rate.

**Temporal blocker:** receipt/upload time is not necessarily activity time. Existing workout payload timestamps are client assertions with validation, not automatically an authoritative membership earning clock. A late upload must not acquire Premium bonus for pre-activation activity. Approve eligible event sources and their time evidence before choosing event-time lookup; an online server check-in and an offline workout may need different trust policies. Daily timezone, streak boundaries, event caps and whether caps apply before/after multiplication also need decisions. No source is enabled by this audit.

For Premium vouchers, propose explicit immutable paid grant intervals `[start,end)` linked to the verified membership transaction. Early renewal appends the next 30-day interval after existing expiry; it does not open an extra current-cycle voucher. Use a stable cycle identity tied to the grant/period, not a client date, calendar-month string or callback ID. Issue/materialize at the cycle's start or lazily on first eligible access, idempotently; the mechanism is not yet approved. Current account expiry alone is insufficient as a durable multi-cycle issuance ledger.

Keep **three separate concepts**: Module 3 physical-reward redemption vouchers; Module 4 membership promo codes; and the proposed Premium coach-discount voucher. They must not spend/issue each other. For a future booking discount, atomically reserve the cycle voucher against the existing booking checkout and snapshot base fee, discount, net fee, voucher identity and policy version. The Billplz amount and paid-amount verification use the snapshotted net fee. Preserve existing undiscounted booking schemas/behavior and never let a user-supplied discount override price.

Candidate rounding for approval: `discountSen = min(1500, floor(baseFeeSen × 10 / 100))`. The draft does not resolve fractional-sen rounding, eligible coaches/branches/sessions, unused-voucher expiry/carryover, reinstatement after failure/cancellation/refund, or future policy edits. Unknown provider outcomes retain the reservation until reconciled; elapsed client timeout alone is not safe evidence for release.

**Commission blocker:** `commissionFor()` currently applies `sandbox-coach-80-v1` (8000 basis points) to cleared `payment.amountMinor`. On a RM100 booking discounted to RM90, unchanged arithmetic recognizes RM72 for the coach rather than RM80. Gym-funded subsidy preserving RM80, shared discount, or a new commission base are different financial policies. None is approved. Gross/list price, collected cash, subsidy and coach/platform splits must be separately recorded and reconciled with refunds before Phase 4. No commission code or earning record is changed now.

## Affected-file map — future work only

Paths identify existing integration points, not authorization to edit them. New names below are proposals; no application files were created.

| Phase / area | Existing source integration points | Proposed change / boundary |
|---|---|---|
| 1 domain | `packages/gainpath_domain/lib/src/membership/membership_commerce.dart`, `lib/membership.dart`; `lib/src/identity.dart` read-only boundary | Separate effective-tier model from `AppRole`; no Free role or zero-price paid plan. A new domain entitlement contract and backend resolver may be appropriate. |
| 1 backend | `functions/src/modules/commerce/membership-payment-service.ts`, `membership-payment-callables.ts` | Extend read projection/resolver; reuse verification/snapshot/renewal/refund logic. Preserve organization-role records and existing paid schema compatibility. |
| 1 shared UI | `apps/mobile/lib/app/di/membership_factory.dart`; `infrastructure/firebase/firebase_membership_repository.dart`; `infrastructure/local/membership_cache.dart`; `features/membership/presentation/shared/{membership_dashboard_screen,membership_data_view}.dart`; `member/{browse_plans_screen,purchase_plan_screen,renew_screen}.dart` | Derived Free card and upgrade action; paid renewal remains existing pipeline; cache/unknown/ineligible states differentiated. |
| 1 navigation/profile | `apps/mobile/lib/app/home/member_home_screen.dart`, `app/shells/member_shell.dart`, `features/identity/presentation/member/member_profile_screen.dart` | Consistent effective-tier display, no stale mock `memberTier` or branch-scoped paid status. |
| 2 staff | `apps/admin_web/lib/app/admin_app.dart`, `app/shells/admin_shell.dart`; `apps/admin_web/lib/features/identity/presentation/admin/{members_screen,member_details_dialog}.dart` and its `AdminMemberDirectoryRepository` contract; `functions/src/platform/auth-context.ts` | Approved verification capability/role and minimal identity lookup. New backend read operation may be required; reuse account detail, not another financial dashboard. Do not expose unrestricted member search to all staff. |
| 2 workout entry | `apps/mobile/lib/app/routing/workout_prep_route.dart`, `features/workout/presentation/member/workout_prep_screen.dart`, `infrastructure/firebase/firebase_published_routine_repository.dart`, published catalogue cubit | Future entitlement adapter around catalogue/launch. `RealSquatRoute`, `DevelopmentSquatBinding`, pose detector/analyzer/controller, existing storage and acceptance quality checks stay frozen unless separately authorized. |
| 2 report entry | `apps/mobile/lib/app/routing/member_progress_route.dart`; `features/analytics/{application/member_progress_cubit.dart,data/local_member_progress_repository.dart}`; `presentation/shared/progress_dashboard_screen.dart`; `presentation/member/{activity_timeline_screen,workout_performance_screen,posture_accuracy_screen,goal_progress_screen}.dart`; domain `src/analytics/local_member_progress.dart` | Approved projections/time limits and real metric definitions; preserve underlying saved records and current account isolation. Future protected server report/content reads need separate design. |
| 3 points | `apps/mobile/lib/features/gamification/application/gamification_bloc.dart`; domain `src/gamification/policies/reward_policy.dart`; data `src/gamification/in_memory/*` | Keep mock mode separate; add real transactional award/balance ledger and event validation rather than extend prototype mutation into Firebase. Backend reward module is new work. |
| 3 catalogue/redemption | domain `src/gamification/{entities/reward_item.dart,repositories/reward_catalog_repository.dart}`; Admin `infrastructure/firebase/firebase_reward_catalog_repository.dart`; mobile `features/gamification/presentation/member/{reward_shop_screen,voucher_screen}.dart`; `firebase/firestore.rules` | Operational reward schema, tier checks, cost/stock/limits, atomic debit and staff fulfilment; existing metadata CRUD and Rules preserved until an explicit scoped Rules/data migration approval. |
| 4 booking quote/settle | `functions/src/modules/commerce/{booking-payment-service,booking-payment-callables,booking-payment-admin,billplz-sandbox}.ts`; mobile `infrastructure/firebase/firebase_booking_payment_repository.dart` and `features/coaching/presentation/member/booking_payment_screen.dart`; domain coaching payment contracts | Discount quote/reservation/net snapshot compatible with existing bookings; no provider duplicate bill or client price control. Reuse shared callback signature/independent GET. |
| 4 downstream finance | `functions/src/modules/coaching/{coach-performance-service,module9-member-service,member-booking-change-service,gym-booking-sync}.ts`; Admin `features/membership/{payment_review_repository.dart,presentation/admin/refunds_screen.dart}` | Finance-rule-aware earnings/refund reconciliation and old-record compatibility. Review current assumptions about `amountMinor`; do not silently reprice bookings. |
| Regression boundary | `functions/src/modules/chatbot/{chatbot-callable,assistant-booking-tools}.ts`; `coaching/{automatic-google-delivery,automatic-google-worker,google-booking-delivery,gym-booking-sync}.ts` | Keep AI capabilities and Google triggers/recipient scopes unchanged; test them after future pricing changes. No redesign or messaging authorization. |
| 5 Admin reporting | `apps/admin_web/lib/features/analytics/application/{admin_reporting_gateway,admin_reporting_cubit}.dart`, Admin presentation sections | Effective vs paid membership counts; actual net revenue/subsidy/refund/reward sources. Current unavailable gateway is not a ready aggregator. |

## Security, migration and testing impact

- Preserve Auth, email verification, App Check and live account/organization authority before all entitlement decisions. Never trust a screenshot, client clock, benefit array, cached card or token-embedded stale paid flag for admission or money.
- Paid membership remains organization-wide; general account/booking branch assignments retain their current distinct semantics. Approve staff visibility across branches separately from member paid scope.
- Phase 1 should not require a mass write of Free accounts. Derive Free when eligible; recheck live paid records before migration. Do not invent activation dates, paid cycles or point balances from prototype seeds.
- Future entitlement/grant/reward/voucher paths need versioned schemas, immutable financial evidence, backward readers and a reviewed Rules/index plan. Do not weaken existing Rules merely to support new client screens. Reuse authenticated commands for financial mutations.
- Do not introduce a periodic scan/job solely to expire effective paid access. If future voucher issuance is eager/scheduled, approve its cost/retry/concurrency separately; lazy idempotent materialization may avoid a new worker.
- Retain old paid receipts, workouts, points and confirmed bookings on expiry/downgrade. Catalogue deactivation does not cancel an already-created Billplz bill or revoke previously cleared paid time.
- Test plan before each implementation approval: Free/active/expired/pending/refund-review/suspended/wrong-role/wrong-org; exact expiry boundary and repeated early renewals; stale/offline/unknown state; direct navigation and unauthorized API access; no loss of safety feedback; real-data insufficiency; once-only/capped event awards including late uploads; point/stock concurrent redemption; cycle boundary/early renewal/duplicate issuance; concurrent voucher checkout, provider timeout, late payment and refund rules.
- Existing regression anchors include `functions/test/{membership-payment,booking-payment,booking-payment-callback,booking-payment-admin,workout-v2-contract,chatbot,chatbot-callable,automatic-google-delivery,gym-booking-sync}.test.ts`; mobile membership/progress/booking tests and legacy gamification tests; Admin reward-catalog/payment-review tests. Existing tests do not establish the new entitlement rules. No new feature has been implemented or accepted in Phase 0.

## Decisions required before implementation

| Decision | Required answer / consequence |
|---|---|
| D1 prices/term/launch scope | Approve or amend Basic RM49/Premium RM89, 30 × 24-hour days, participating branch definition and when each advertised benefit is actually available. Do not publish future rewards/vouchers as fulfilled today. |
| D2 Free exercise IDs | Approve exact supported/validated IDs and exercise launch policy. Current development candidate is identified above; no full Free exercise list has been approved. |
| D3 Free history and Premium metrics | Exact days/count/detail/export rules; measured fields and goal definitions; interaction with existing chatbot facts. No arbitrary “last 7/30 days” assumption. |
| D4 verification roles/admission | Which existing role/capability may verify, which identity lookup, cross-branch scope, and whether/when Free paid coaching appointments confer limited entry. No turnstile/attendance integration. |
| D5 eligible rewards/time/caps | Event sources, trustworthy earning timestamps, daily timezone, caps/rounding order and handling verified late/offline activity. Existing points are preserved; mock points are not migrated as earned. |
| D6 redemption catalogue | Real items, point cost/stock, tier labels, exchange-rate version, per-member limits, fulfilment/expiry and once-only staff rules. Archived metadata is not stock. |
| D7 voucher finance | Discount funder/commission base, integer rounding, eligible sessions/coaches/branches, cycle/unused voucher expiry, stacking, cancellation/refund and reinstatement rules. Blocks Phase 4. |
| D8 rollout and permissions | Per-phase source implementation scope, test gates, explicit catalogue writes, separate selective deployment and Xiaomi/financial UAT approvals. No inherited blanket approval. |

## Phase recommendation and approval boundary

Proceed next only after a separately approved **Phase 1 foundation implementation scope**: effective-tier resolver/domain/read projection/shared UI, no new module access restrictions or reward/discount grants. This isolates Free/expired/suspended semantics from the larger rewards/finance work. It need not create an RM0 plan or a Free account record, and must retain all paid settlement guarantees.

Phase 2 follows D2–D4 and real report readiness, leaving frozen analysis/safety code untouched. Phase 3 requires a trusted points/redemption foundation and D5–D6. Phase 4 is blocked on D7 and has the widest Module 7 financial regression scope. Phase 5 adds three explicitly authorized test personas and real acceptance evidence; it does not create those accounts now.

The [separate approval proposal](module4-three-tier-approval-proposal.md) separates business decisions, application implementation, catalogue/data writes, Rules/index changes, deployment and UAT. **This audit requests no operational action and grants none.**
