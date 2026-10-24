# GainPath three-tier roadmap — local delivery and release gate

23 October 2026 · Project `gainpath-0619` · Organization `gainpath`.

Subsequent approvals: Stage A was deployed and verified as recorded in `module4-three-tier-stage-a-deployment.md`. The owner then approved Basic **RM89** and Premium **RM129**, each 30 days, and both inactive catalogue records were created/read back in `module4-three-tier-catalogue-staging.md`. Earlier price/approval statements below describe the local handoff at that time; the new staging record supersedes them. Activation and all remaining policy/device/financial gates remain pending.

Further approval: catalogue activation was subsequently approved and completed in `module4-three-tier-catalogue-activation.md`; both approved plans are now active. Policy/device/financial UAT and Stages B/C remain pending.

Further device approval: the Firebase APK was subsequently installed/launched on Xiaomi with app data preserved, and 13 authenticated read-only API checks passed. See `module4-authenticated-readonly-uat-phone-install.md` for actual results and the remaining manual Membership-screen/Admin-positive gaps. Stages B/C and financial UAT remain pending.

The remaining roadmap has been implemented locally to the extent supported by trusted data and specified business rules. **346 focused tests passed.** This is a tested implementation handoff, not acceptance of a live three-tier product. No cloud deployment/configuration, catalogue/account/reward writes, provider payment/refund, APK installation or financial/device UAT was performed in this remaining-implementation run.

The user's “direct implement all” authorized local source work. The selected three-tier direction does not approve RM49/RM89, reward amounts/stock, Free exercise/history limits or voucher finance choices. The earlier approved overview deployment remains separate, including its unresolved maximum-instance exception.

## Requirements and remaining decisions

| Requirement | Reused/completed locally | Remaining before operational acceptance |
|---|---|---|
| Purchase and plan selection | Existing shared Membership UI, trusted catalogue/quote snapshots, Billplz Sandbox bill creation, current Auth/App Check and server prices; no artificial Free checkout | Approve and publish real paid catalogue. Proposed inactive records remain local |
| Dashboard and organization scope | Server-derived Free/Basic/Premium, retained previous paid facts, exact expiry/unknown/review states; one paid membership across branches | Authenticated device/read UAT; no Member account migration performed |
| Renewal | Manual, same-tier `max(server now, paid expiry) + snapshotted duration`; duplicate clearance cannot extend twice | Approved catalogue and Sandbox UAT. Active cross-tier conversion/proration remains unavailable |
| Payment history/invoices | Existing distinct Membership/Coaching transaction kinds, snapshots, cleared-payment PDF invoices and shared history | Xiaomi export/view UAT |
| Refund request/tracking | Existing seven-day request/review handling and Admin management; review approval retains paid facts and does not transfer money | Billplz HTTP 422 refund-transfer issue and explicit entitlement reversal policy remain unresolved |
| Free/paid workout access | Trusted, versioned exact-ID policy and outer launch gate; admitted workout retains complete guidance even if expiry occurs | Approved supported/free IDs. Enforcement is **off by default**, including this APK; no new restrictions activated |
| Advanced reporting | Versioned report gate, real measured trends and saved numeric-goal comparison; explicit missing weight/volume data | Approved report ID matrix and Free history limits; no invented cutoff or deletion. Local captures remain provisional, not trusted reward evidence |
| Gym verification | Fresh server-side target identity/entitlement, organization-wide; existing Admin Member Details panel | Admin-only verifier initially. Broader staff capability and coaching-appointment admission exceptions require decisions; no attendance/hardware integration |
| Premium points | Trusted event ledger, historical cleared Premium proof, integer `floor(base × 1.5)`, once-only awards, timezone caps and preserved balances | Approved source-specific event verification/producers, amounts/caps/timezone. No daily/game/workout producer is enabled or represented as trusted |
| Physical reward redemption | Verified balance, real configured cost/stock/rate, Free earning but paid-only redemption, Premium-exclusive items, atomic debit/stock; server receipts; restart-safe uncertain request references | Approved operational items, stock and uniform exchange rate. Existing Admin metadata CRUD is retained; it does not become spendable stock |
| Reward fulfilment | Read-only current receipt inspection then separate once-only Admin fulfilment action in existing Reward Catalogue | Physical desk/device UAT. First Member reader shows most recent 50; all ledger records retained, full paging remains additional reader work |
| Premium Coach voucher | One earned 30-day term, early-renewal protection, optional trusted net quote, reservation/settlement/recovery, snapshots and Admin finance disclosure | Approve explicit finance/rounding/eligibility policy, then financial deployment/UAT. No legacy voucher backfill |
| Auto-renewal and promos | Automatic recurring billing remains unavailable; manual renewal supported. Existing promo validation retained/tested | Promo configuration deferred; no new promo written |
| Module 7/Google/AI compatibility | Existing provider, signature verification, independent provider GET, Admin recovery and booking infrastructure reused; focused regressions pass | Provider/device end-to-end acceptance is pending; no Google/AI/availability redesign |

## Security and transaction behavior

New sensitive operations use current verified Firebase identity, organization membership/lifecycle and App Check. Staff target lookup uses current Admin SDK identity, rather than impersonating a Member token. Target Auth reads happen outside retryable Firestore transactions; current actor authority is checked in the transaction. Entitlement remains independent of Auth role and branch assignments.

Missing/malformed access policy preserves existing feature behavior. A configured policy plus unavailable authority returns unknown, not paid access. New reward/debit/discount operations require complete trusted policy and fail closed when absent. Cached Member display, catalogue benefits text, screenshots and client tier/price/time/score claims never authorize mutations or gym admission. Existing Rules remain deny-by-default for new paths; no Rules/index changes are included.

Reward event production and economic policy are intentionally separate. Current account Premium status cannot retroactively award a bonus. Historical proof binds the earning time to an immutable cleared paid interval. Duplicate events/commands reauthorize the caller and return existing receipts without a second credit/debit. Points and receipts survive expiry. The app-private retry file contains only organization/member/item/request references; it is an idempotency hint, not authority. Invalid/partial storage fails closed. Clearing app data removes this local hint; the server ledger remains authoritative.

Voucher support is limited to an explicitly approved **gym-funded, gross-fee commission** policy, exactly `sandbox-coach-80-v1`, with an explicit `floor` or `half_up` rounding choice, eligibility lists, cycle-end expiry, no stacking, no refund reinstatement and release only after independently verified permanent unpaid bill deletion. These are supported code paths, not approved commercial choices. Alternate choices require implementation/review rather than silently mapping to these values.

The supported commission projection preserves Coach 80% of original fee, separately records net collected/discount, and derives platform amount from collected cash minus Coach amount. It does not execute payouts. Independent review found the original net-fee commission mismatch; it was fixed and covered by regression tests. Refund review/approval is not a transfer and does not silently revoke an earned Membership term. Existing paid Booking capacity, reservations and Google synchronization remain on their existing paths. Uncertain provider outcomes retain voucher reservations; duplicate/late clearance consumes once, including payments requiring Admin review.

## Changed source map

This shared checkout already contained substantial unrelated and earlier Module 4 work. The following identifies this remaining phase; it does not attribute every dirty file to this task. Nothing was broadly staged/reset/committed, and frozen pose/workout engine source was not edited by this phase.

| Area | New/modified source |
|---|---|
| Backend exports and effective authority | `functions/src/index.ts`; `modules/commerce/membership-entitlement.ts`, `membership-access-service.ts`, `membership-access-callables.ts`, `membership-payment-callables.ts` (overview preserves external configuration) |
| Backend rewards | `functions/src/modules/gamification/verified-rewards-service.ts`, `verified-rewards-callables.ts` |
| Voucher and finance | `functions/src/modules/commerce/premium-coach-voucher.ts`, `membership-payment-service.ts`, `booking-payment-service.ts`, `booking-payment-callables.ts`, `booking-payment-admin.ts`; `functions/src/modules/coaching/coach-performance-service.ts` |
| Shared domain | `packages/gainpath_domain/lib/src/membership/membership_access.dart`, `src/gamification/verified_rewards.dart`, `src/analytics/fitness_goal_comparison.dart`, `src/coaching/booking_payment.dart`; exports `membership.dart`, `gamification.dart`, `analytics.dart` |
| Mobile injection/recovery | `apps/mobile/lib/app/di/membership_factory.dart`, `rewards_factory.dart`; `infrastructure/firebase/firebase_membership_access_repository.dart`, `firebase_verified_rewards_repository.dart`, `firebase_booking_payment_repository.dart`; `infrastructure/local/reward_redemption_intents.dart` |
| Mobile integration | `app/routing/workout_prep_route.dart`, `member_progress_route.dart`, `app/home/member_home_screen.dart`; `features/membership/presentation/shared/membership_access_gate.dart`; `features/analytics/presentation/member/goal_comparison_report.dart`, `goal_progress_screen.dart`, `workout_performance_screen.dart`; `features/analytics/presentation/shared/progress_dashboard_screen.dart`; existing reward shop/voucher and booking/payment screens |
| Admin integration | `apps/admin_web/lib/infrastructure/firebase/firebase_admin_member_directory_repository.dart`; existing `member_details_dialog.dart`, new `member_membership_verification_panel.dart`; existing `reward_catalog_screen.dart`, new `reward_fulfilment_panel.dart` and `reward_fulfilment_repository.dart`; existing `payment_review_repository.dart` and `refunds_screen.dart` |
| Tests and evidence | Focused tests named below; `functions/emulator/loopback-emulator.ts` and the three financial/reward emulator suites; local proposal/contract/delivery documents and `build/module4/remaining-*` evidence |

No new dependency, expiry scheduler, reward worker, gateway, Admin dashboard, account role, stock CRUD or direct client financial-write permission was introduced.

## Final verification

| Check | Final result |
|---|---|
| Functions build/load and test typecheck | Passed; local Node 24.19.0, configured cloud runtime remains Node 22 |
| Backend — 16 focused files | **202 passed** |
| Firestore emulator — 3 isolated files | **9 passed** against final source, then emulator shut down |
| Shared domain — 5 files | **19 passed** |
| Mobile — 15 files | **76 passed** |
| Admin — 6 files | **40 passed** |
| Targeted Dart analysis | No issues in integrated source; final recovery/Admin disclosure files checked again |
| Independent read-only core review | One important commission issue found and fixed; no other important findings. Later retry-persistence/Admin disclosure additions received focused tests and coordinator review |
| Firebase Android debug APK | Build/package/signature verified; **not installed** |

**346 focused tests passed.** Full repository, live provider, authenticated cloud account and Xiaomi UAT are not claimed. Expected permission-denial/refund-error logs exercise negative cases. One repeat emulator start found its prior port unavailable; fresh loopback ports 62241/62242/62243 were allocated and the complete final rerun passed. No production project fallback is allowed by the test helper; all three suites use isolated demo namespaces. The Rules copy in the local emulator build directory is the existing Rules, not a proposed Rules deployment.

Backend selection, from `functions`:

```powershell
pnpm run build
pnpm run typecheck:tests
pnpm exec vitest run test/membership-entitlement.test.ts test/membership-access.test.ts test/membership-payment.test.ts test/membership-overview-manifest.test.ts test/three-tier-catalogue-proposal.test.ts test/verified-rewards.test.ts test/verified-rewards-callables.test.ts test/premium-coach-voucher.test.ts test/booking-payment.test.ts test/booking-payment-admin.test.ts test/booking-payment-callback.test.ts test/coach-performance.test.ts test/module9-member.test.ts test/gym-booking-sync.test.ts test/automatic-google-delivery.test.ts test/chatbot-callable.test.ts
pnpm exec firebase emulators:exec --project demo-gainpath-membership --config ../build/module4/remaining.emulator.test.json --only firestore "pnpm exec vitest run --config vitest.emulator.config.ts emulator/membership-payment.test.ts emulator/verified-rewards.test.ts emulator/premium-coach-voucher.test.ts"
```

Coverage includes purchase/quote price tampering, catalogue version changes, promo dates/tier/final capacity, exact expiry, distinct concurrent renewal and duplicate callbacks, failed/expired/uncertain checkout and verified recovery, refund authorization/review without transfer, cross-account/org isolation, current identity/lifecycle changes, historical Premium timing, last-stock contention, read-only inspection/once-only fulfilment and voucher reservation/clearance/recovery. Existing undiscounted Module 7/Google/AI tests remain in the selection.

Domain: `membership_entitlement_test.dart`, `membership_access_test.dart`, `membership_commerce_test.dart`, `fitness_goal_comparison_test.dart`, `booking_payment_test.dart`.

Mobile: `membership_screens_test.dart`, `firebase_membership_repository_test.dart`, `mock_membership_commerce_test.dart`, `membership_access_gate_test.dart`, `firebase_membership_access_repository_test.dart`, `verified_rewards_screens_test.dart`, `firebase_verified_rewards_repository_test.dart`, `reward_redemption_intents_test.dart`, `booking_payment_screen_test.dart`, `firebase_booking_payment_repository_test.dart`, `goal_comparison_report_test.dart`, `local_member_progress_ui_test.dart`, `member_progress_route_test.dart`, `coach_earnings_ui_test.dart`, `legacy/membership/membership_bloc_test.dart`.

Admin: `reward_fulfilment_panel_test.dart`, `reward_catalog_test.dart`, `member_membership_verification_test.dart`, `admin_member_directory_test.dart`, `payment_review_repository_test.dart`, `payment_review_screen_test.dart`. Run these explicitly using `flutter test --no-pub`; domain files use `dart test`.

## Signed APK

`build/module4/gainpath-three-tier-remaining-firebase-debug.apk`, 219,819,545 bytes. Build flags: `--debug --no-pub --dart-define=BACKEND=firebase --dart-define=APP_CHECK_MODE=debug`. `MEMBERSHIP_ACCESS_ENFORCEMENT` is false by default; changing it is a separate rollout/build decision after approved policy and backend availability. The APK comes from the shared checkout, including existing unrelated changes, so it is a development UAT artifact rather than an isolated production release.

- Package `com.zyang.gainpath`, version `0.1.0+1`, minimum SDK 26, target SDK 36.
- APK SHA-256: `fc1b1cf3bd34815bb8546cf5732e9ad8dd42dd08cbfa1b3b1041a050d8019034`.
- APK Signature Scheme v2: verified; one RSA-2048 Android Debug signer, DN `C=US, O=Android, CN=Android Debug`.
- Signing certificate SHA-256: `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`, matching the earlier development identity.
- Exact signing/package/hash output: `build/module4/remaining-apk-verification.txt`. No install/device/App Check-registration command was run.

## Catalogue and configuration gate

See `module4-three-tier-catalogue-business-proposal.md` and the exact `module4-three-tier-catalogue-proposal.json`. Free is derived with no document. Proposed Basic 4900 sen/Premium 8900 sen, 30-day duration, versions and benefits remain **not approved**, both records `active:false`. Exact proposal file SHA-256: `275140d818f84e5ec1f0cf7e15447f37b88e7f86ffa60bfb0ae5461a58cde96f`.

The proposal specifies create-only atomic inactive staging, unexpected-record stop, full readback/digest comparison and separate preconditioned activation approval. Later rollback would deactivate new sales using current update-time preconditions, preserving pending bills, immutable paid snapshots and existing paid time. No catalogue write is bundled with Functions deployment.

Access policy path: `orgs/gainpath/membershipPolicies/access` (exact supported exercise/free/report IDs and version required). Rewards policy/items/events: detailed in `module4-verified-rewards-local-contract.md`; no source producer/configuration supplied. Voucher finance policy: `orgs/gainpath/settings/premiumCoachVoucher`, exact supported fields in `../planning/premium-coach-voucher-local-contract.md`. No policy record is written by this handoff.

## Exact selective deployment proposal — Stage A subsequently executed

The owner subsequently approved **Stage A only**. Its isolated three-Function deployment and fresh verification are complete in `module4-three-tier-stage-a-deployment.md`. The implementation/test report above records the preceding local handoff; Stages B/C and business/data/device/financial gates below remain pending. The executed command used `../build/module4/stage-a.firebase.json` to exclude all pending financial/reward source rather than deploying from the entire dirty checkout.

Before any approved deployment: capture current metadata/revisions/source and environment/configuration hashes, compare current selected source with its deployed bundle, confirm Node 22/App Check/secrets bindings, and exclude unrelated dirty work. Capture each selected Function's runtime/scaling settings and abort unexpected configuration changes. Preserve rollback bundles for each selected existing Function. Do not upgrade dependencies or deploy wildcard scopes as part of this release.

**Stage A, separately approvable read-only scope (3 Functions):**

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:getMembershipOverviewCommand,functions:getMembershipAccessCommand,functions:verifyMemberMembershipCommand --non-interactive
```

The overview local change sets `preserveExternalChanges:true` and its manifest test rejects generated min/max reset fields. This is prevention only: the currently recorded live overview maximum **20** has not been restored or changed by this run. No selected existing maximum should be changed without an explicit scaling decision. The last verified deployed compatibility evidence is the earlier Phase 1 deployment record; this run made no fresh live metadata/provider calls.

**Stage B, separately approved reward command (1 new Function):**

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:verifiedRewardsCommand --non-interactive
```

Explicit organization parameter `VERIFIED_REWARDS_ORGANIZATION_ID=gainpath` requires approval at that release; empty default is disabled. No parameter/environment file was changed for this new command. Deploying the command does not publish earning sources, stock, exchange rate or data. Policy/event production and Admin/client publication need separate approvals.

**Stage C, only after voucher finance decisions and review (9 existing Functions deployed as one compatible scope):**

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:getBookingPaymentQuoteCommand,functions:createBookingPaymentCommand,functions:getBookingPaymentCommand,functions:getMembershipPaymentCommand,functions:paymentWebhook,functions:manageAdminBookingPaymentCommand,functions:listAdminBookingPaymentsCommand,functions:getAdminBookingPaymentCommand,functions:getCoachPerformanceCommand --non-interactive
```

This covers every independently deployed path executing changed financial settlement/recovery/projection logic, including the Membership grant hook, both webhook kinds, Admin reconciliation and Coach gross-fee recognition. `billplzSandboxReturn` is unchanged static return HTML and does not settle money. Membership quote/create/refund commands do not execute the changed grant hook. Existing AI quote callers omit voucher flags and retain the full-price contract, so no AI deployment is needed. Full-price paths continue when voucher policy is absent/disabled. Do not enable finance policy before all selected handlers and the approved client/Admin build are verified.

These stages contain **13 unique Functions**. No Rules, indexes, Hosting, Google/Gmail/Calendar, Gemini, availability/reservation worker or other resource deployment is proposed. Existing Admin/mobile build publication and APK installation are separate approvals.

After an authorized release, read back only the approved targets, compare configuration/revisions against the captured baseline and verify unauthenticated/App Check rejection. Authenticated account reads and financial calls require their own approved test scope. Rollback existing handlers selectively from preserved compatible bundles. New financial/reward state must not be deleted or reverted from snapshots: disable new policy-driven operations under a separately approved configuration change and retain compatible recovery readers/handlers for outstanding vouchers/bills. Never roll old full-price settlement over an outstanding discounted payment without a reviewed recovery plan. Read-only Stage A needs no data rollback.

## Xiaomi and Admin UAT — prepared, not performed

Run only after the corresponding deployment, configuration, test-persona, installation and Sandbox financial approvals:

1. Verify the APK hash/certificate on Xiaomi before installation. Use explicitly authorized Free/Basic/Premium personas; do not alter existing production subscriptions/accounts to create scenarios. Check email verification, suspension, account switching, offline historical wording and unknown states.
2. Navigate Home/Profile/Membership, compare approved catalogue prices/versions/benefits, confirm Free has no checkout/expiry and all GainPath branches share the paid status. Check invoices/history and distinct Coaching labels.
3. In the existing Admin Member Details, refresh server verification for Free/paid/expired/suspended/wrong-organization targets. Check identity/expiry/time and denial/unknown states. A cached screenshot is insufficient for admission.
4. With separately approved access rollout, test supported/free/paid exercise IDs, unavailable policy, direct route entry, advanced report IDs and saved goal comparisons. Expiry during an admitted workout must retain all pose/audio safety. No fake weight/volume, arbitrary history deletion or chatbot restriction should appear.
5. After approved catalogue/Sandbox scope: purchase, early manual renewal, exact expiry, duplicate callback, failed/expired checkout, app closure/restart and uncertain/orphan recovery. Verify no duplicate bill, activation or added time. Do not infer clearance from return HTML.
6. With approved reward producers/items: earning-time Premium boundaries, no retroactive balance bonus, caps, Free accumulation but no physical redemption, Premium-only items and simultaneous last-stock attempts. Restart after an uncertain response and verify the same receipt/debit. Switch accounts and verify isolation.
7. In existing Admin Reward Catalogue, inspect a real authorized receipt without mutation, explicitly record physical fulfilment once, inspect again from another session, and verify issued receipts remain reviewable after membership expiry. Do not dispense from a screenshot alone.
8. With approved finance policy: earned-cycle voucher before/after early renewal, net quote/cap/rounding, one concurrent reservation, uncertain bill retention, provider-verified deleted recovery, duplicate/late paid settlement and no automatic refund reinstatement. In existing Admin details verify gross/discount/net/finance reference; in Coach reporting verify supported gross-fee commission without claiming a payout.
9. Review Membership refund requests/approval in existing Admin screens and confirm no transfer/revocation claim. Preserve the separate HTTP 422 issue; no refund execution is authorized by this checklist.
10. Regression-check the already-approved Booking/capacity/Coach Availability flows and existing Calendar/Gmail/AI behavior. Record device/provider acceptance evidence and outstanding limitations before calling the roadmap operationally complete. FYP acceptance personas, diagrams/use-case alignment and real financial evidence remain a later acceptance deliverable.

**Stage A was subsequently approved and technically completed**, without catalogue, policy, account, finance or installation changes; see `module4-three-tier-stage-a-deployment.md`. Stages B/C and all remaining business/data/device/UAT gates stay independently reviewable and unperformed.
