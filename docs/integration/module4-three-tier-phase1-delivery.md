# Three-tier membership Phase 1 — local delivery, 23 October 2026

Project `gainpath-0619`; organization `gainpath`. The owner's “proceed” authorizes the local Phase 1 scope in [the separate proposal](../planning/module4-three-tier-approval-proposal.md). This delivery introduces the membership foundation only. Nothing in this report approves prices, catalogue activation, later feature restrictions, deployment, APK installation or financial UAT.

The owner subsequently replied “approve” to the single overview Function deployment. It has been executed; see [the deployment record](module4-three-tier-phase1-deployment.md), including the explicit maximum-instance configuration exception. Catalogue, installation and financial gates remain separate.

## Requirements and result

| Phase 1 requirement | Local result |
|---|---|
| Effective Free entitlement | Eligible, currently verified active Member with no paid facts resolves to Free, without a transaction, account write or expiry. A pending first checkout remains Free. |
| Active Basic/Premium | Read-only server resolution checks organization/member/lifecycle authority and matching cleared Membership payment evidence. It does not trust client tier, legacy account text alone or benefits as authorization. |
| Expiry | `expiry <= serverNow` resolves to Free while retaining the previous paid tier, plan, expiry and ledger. No scheduler, deletion or account migration is needed. |
| Invalid or unauthorized state | Suspended, deactivated, stale-session, wrong-role and wrong-organization callers are denied. Missing/corrupt/unsupported paid evidence becomes unknown, never Free. Current Auth deletion, disablement, verification loss or lookup failure cannot yield Free. |
| Organization-wide membership | No branch-specific paid entitlement or new module gate. Existing Booking, Workout, AI, reports, rewards and Google integration permissions are unchanged. |
| Shared domain/repository/UI | One injected mock/Firebase dashboard, comparison and renewal UI. Free is informational and has no checkout. Paid cards use configured Basic/Premium plans, exact two-decimal MYR display and wrapping layout. No Elite card is exposed. |
| Previous paid period | Expired paid members see Free plus the retained tier/expiry and a manual renewal route. Existing payment receipts, history, invoices and refund screens remain available. |
| Cache and older servers | Cached status is explicitly historical; checkout/renewal shortcuts are disabled. Missing entitlement from an older overview shows unavailable instead of inventing Free. Nested account/organization identity is validated before caching or displaying an entitlement. |
| Renewal and payment | Existing trusted quotes, paid-time preservation, duplicate settlement protection and manual renewal are reused. Active cross-tier changes stay blocked. No automatic recurring billing or new payment operation was added. |
| Refund | Existing review remains separate from money transfer. Review/approval alone does not revoke paid time. Membership refund execution and the existing Billplz HTTP 422 issue remain unresolved and separate. |

Expiry is evaluated using trusted time on each overview read. Existing refresh on entry, resume, return and manual refresh is retained; an open screen is not a continuous admission proof. Staff verification is a later phase. This resolver supports the current Billplz Sandbox receipt schema; unsupported legacy paid plan identifiers remain unknown pending explicit mapping decisions.

RM49 Basic, RM89 Premium and 30-day terms remain **suggested business values**, not approved catalogue configuration. This phase writes no plans, benefits or promos. Mock catalogue values and synthetic test prices do not enter Firebase mode. Future gym entry, workout/report limits, Premium points and coach vouchers remain deferred; their proposed benefit matrix is not advertised as delivered functionality.

## Reuse, architecture and changed files

Reused the existing overview callable, Auth reader, App Check enforcement, transaction adapter, scoped transport, optional account-scoped display cache, Membership navigation and polished shared components. Reused all deployed Module 4 financial commands and Module 7 provider/webhook/Admin infrastructure. No new Function, collection, Rules, index, Admin dashboard or CRUD interface was introduced.

Phase 1 backend changes:

- New `functions/src/modules/commerce/membership-entitlement.ts`: reusable transaction-scoped read resolver and policy `gainpath-effective-membership-v1`.
- `functions/src/modules/commerce/membership-payment-service.ts`: additive overview `entitlement` projection; preserves legacy `account`, plans and transactions. Financial command implementations are unchanged by Phase 1.
- `functions/src/modules/commerce/membership-payment-callables.ts`: existing overview injects the current Auth identity reader. Other callable options and handlers retain their previous behavior.
- New `functions/test/membership-entitlement.test.ts`; extended `functions/emulator/membership-payment.test.ts`; local-only port configuration in `firebase/membership.emulator.test.json`.

Phase 1 domain/mobile changes:

- New `packages/gainpath_domain/lib/src/membership/membership_entitlement.dart` and export in `lib/membership.dart`; new `test/membership_entitlement_test.dart`.
- `apps/mobile/lib/infrastructure/firebase/firebase_membership_repository.dart`: strict entitlement scope/contract validation and injectable display cache for verification.
- Existing shared `membership_dashboard_screen.dart`, `browse_plans_screen.dart`, `renew_screen.dart` and `widgets/plan_card.dart` under `apps/mobile/lib/features/membership/presentation/`.
- `apps/mobile/lib/features/membership/data/mock_membership_commerce.dart`: same effective-tier contract, informational Free, supported paid tiers only.
- `apps/mobile/test/firebase_membership_repository_test.dart`, `membership_screens_test.dart` and new `mock_membership_commerce_test.dart`.
- Planning record: `docs/superpowers/plans/2026-10-23-three-tier-phase1.md`; this delivery report.

The checkout contains earlier uncommitted Module 4 and unrelated work. This list identifies this phase's additions/edits; it is not a claim that every working-tree difference belongs to Phase 1. No broad reset, staging or commit was performed. No frozen workout/pose, Module 7, Google delivery, AI, Admin source or deployed Rules changes were made by Phase 1.

## Fresh verification

| Focused check | Result |
|---|---|
| Functions build/load and test typecheck | Passed |
| Entitlement unit tests | 25 passed: Free, pending, Basic/Premium, exact expiry, receipt mismatch, review retention, authorization, identity outage and read-only legacy compatibility |
| Existing membership/payment/Admin/callback/chatbot/Google backend regressions | 65 passed across six files |
| Dedicated local Firestore emulator | 5 passed: Free→paid→expired projection without read-time writes; one bill under contention; duplicate settlement; final promo capacity; distinct concurrent renewals; existing Rules deny direct financial writes and cross-account reads |
| Domain entitlement/invoice tests | 7 passed |
| Mobile membership, mock contract, legacy membership and Module 7 payment tests | 39 passed across six files |
| Existing Admin payment/refund repository and screen tests | 11 passed |
| Focused Dart analysis | No issues |
| Independent read-only review | No important findings; cached status wording corrected and tested |
| Firebase Android debug APK | Built successfully; signature and package checked; not installed |

Total: **152 focused tests passed**, including five emulator tests. These are not a claim that the complete repository suite or provider/device UAT passed. Local backend runtime is Node 24; the configured deployment runtime remains Node 22. Expected denial/error logs exercise negative cases. The first emulator attempt could not bind port 18409; the isolated local test configuration now uses loopback 54142/54143/54144 and the complete retry passed. No production project or provider writes occurred.

Reproducible checks:

- In `functions`: `pnpm run build`; `pnpm run typecheck:tests`; `pnpm exec vitest run test/membership-entitlement.test.ts test/membership-payment.test.ts test/booking-payment.test.ts test/booking-payment-admin.test.ts test/booking-payment-callback.test.ts test/chatbot-callable.test.ts test/automatic-google-delivery.test.ts`.
- In `functions`: `pnpm exec firebase emulators:exec --project demo-gainpath-membership --config ../firebase/membership.emulator.test.json --only firestore "pnpm exec vitest run --config vitest.emulator.config.ts emulator/membership-payment.test.ts"`.
- In `packages/gainpath_domain`: `dart test test/membership_entitlement_test.dart test/membership_commerce_test.dart`.
- In `apps/mobile`: `flutter test --no-pub test/membership_screens_test.dart test/firebase_membership_repository_test.dart test/mock_membership_commerce_test.dart test/legacy/membership/membership_bloc_test.dart test/booking_payment_screen_test.dart test/firebase_booking_payment_repository_test.dart`.
- In `apps/admin_web`: `flutter test --no-pub test/payment_review_repository_test.dart test/payment_review_screen_test.dart`.

APK: `build/module4/gainpath-three-tier-phase1-firebase-debug.apk`, built from the current shared checkout using `--debug --no-pub --dart-define=BACKEND=firebase --dart-define=APP_CHECK_MODE=debug`. Package/signature/hash evidence: `build/module4/phase1-apk-verification.txt`. It is a debug UAT artifact; no device command or App Check registration was performed. The earlier Module 4 APK was preserved.

Verified package `com.zyang.gainpath`, version `0.1.0+1`, minimum SDK 26, target SDK 36. APK Signature Scheme v2 verification passed with one RSA-2048 signer, DN `C=US, O=Android, CN=Android Debug`. Certificate SHA-256: `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450` (same development identity as the earlier APK). Artifact SHA-256: `82b5d547a66ede95ad44acb889c45217dd82ef0032c1c7cc7803493edd675960`. The batch-wrapper signing check stalled; it was stopped and the Android SDK verifier was rerun successfully with the bundled Android Studio Java runtime.

## Exact deployment proposal — subsequently approved and executed

Only the existing `getMembershipOverviewCommand` needs a Phase 1 backend update. No financial handler, webhook, provider secret, Booking Function, Rules, index, Hosting, catalogue or Member data deployment is proposed.

After explicit approval and a fresh source/preflight review, from `functions`:

```powershell
pnpm run build
pnpm exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:getMembershipOverviewCommand
```

Before execution, capture the currently deployed overview's region/runtime/revision/config and preserve a reproducible copy of its prior source/build. Confirm the selected bundle contains only reviewed changes and retain the configured Node 22 runtime/App Check behavior. After deployment, compare metadata to ensure only the overview changed; verify unauthenticated rejection and, only with separately approved account-read UAT, eligible Free/paid/expired and denied cases. Keep all other Functions and cloud release references unchanged. No new secret or provider capability is required.

Rollback: selectively redeploy the preserved previous overview source/build with the same single-Function target. No data rollback is needed because the resolver performs no writes. Existing clients ignore the additive entitlement field; the new client deliberately displays unavailable against an old overview. If needed, revert the client through its separately approved distribution process. Do not restore whole organization data, remove receipts or change Member accounts.

No fresh deployed metadata/provider checks were performed during Phase 1. Compatibility evidence here is local build, source review and focused regressions against the existing infrastructure; the prior deployment evidence remains [the Module 4 deployment record](module4-membership-deployment.md).

## Later Xiaomi/Admin acceptance checklist — NOT performed

After separate deployment, installation, catalogue and account/UAT approvals as applicable:

1. Enter Membership through Home/Profile/navigation in Firebase mode; check loading, retry and empty paid catalogue without fabricated prices. Verify Free has no expiry or checkout and all branches share one membership.
2. Check approved Basic/Premium test cases against a fresh overview; no account mutation is bundled with this checklist. Refresh after exact expiry and verify Free plus retained previous tier/expiry and billing history.
3. Check offline historical wording, disabled membership checkout shortcuts, account switch isolation and denied suspended/unverified access. Refresh online before any eligibility decision; do not use screenshots/cache for gym entry.
4. After approved catalogue activation and Sandbox financial UAT, verify purchase, manual early renewal, duplicate callback recovery, uncertain outcome recovery, paid-time preservation and unavailable active cross-tier changes. Verify invoice saving/viewing and history on Xiaomi.
5. In existing Admin payments/refunds, verify Membership and Coaching labels remain distinct, receipt/review information is retained and approval never claims transferred funds. Do not execute membership refunds or represent the HTTP 422 issue as resolved.
6. Regression-check existing Booking payments, coach reservations/availability, AI booking and Calendar/Gmail behavior within their already-approved operational scope. No new membership restriction, reward multiplier, voucher or staff access workflow should appear in Phase 1.

The single overview Function deployment was subsequently approved and executed as recorded above. Catalogue configuration/activation, APK installation, financial UAT and later implementation phases remain separate gates.
