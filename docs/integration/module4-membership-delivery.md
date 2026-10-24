# Module 4 — local delivery and deployment gate

23 October 2026. Project `gainpath-0619`, organization `gainpath`. This report records the original local handoff. The owner subsequently approved the ten-Function deployment, now completed and verified in [module4-membership-deployment.md](module4-membership-deployment.md). The APK remains uninstalled. No provider payment/refund calls, production subscription edits, billing changes, secret payload reads or catalogue writes were performed.

## Requirements and remaining decisions

| Requirement | Local result | Remaining acceptance / limitation |
|---|---|---|
| Plan selection and purchase, UC-4.1 | Shared catalogue/cards, trusted server quote, secure hosted Sandbox checkout, durable pending transaction, verified activation | Live catalogue is absent; approved plan names, MYR prices, duration in days, benefits and versions must be supplied. No invented live catalogue. |
| Dashboard, UC-4.2 | Organization-wide tier/status/expiry/benefits, recent membership billing, account-scoped offline display cache | Deployment/device UAT pending. Refresh on entry, resume, return and manual action; no new Firestore listeners because existing Rules deny these financial paths. |
| Promo, UC-4.3 | Server date/tier/percent/capacity checks; atomic allocation; price-change quote protection | No live promo configuration exists. Allocation conservatively counts reserved checkouts, including uncertain attempts; no automatic release of potentially paid allocations. |
| Auto-renew cancellation, UC-4.4 | Explicit unavailable/manual-renewal explanation; no fake recurring toggle or mandate | Current integration has no verified recurring charge capability or subscription to cancel. No existing subscription was modified. |
| History/PDF invoice, UC-4.5 | Own membership ledger, chronological states and recovery; local Android PDF save and viewer action from cleared records | Xiaomi save/view and offline acceptance pending. Coaching records stay in bookings. |
| Renewal, UC-4.6 | Current configured plan; atomic `max(serverNow, existingExpiry) + snapshottedDuration`; duplicate settlement applies once | Active different-tier changes are blocked until a paid-time conversion/proration policy is approved. Expired members can select another plan. |
| Refund request/status, UC-4.7 | Server-enforced seven-day clearance window, owner authorization, pending review/disputed invoice, reason/notes; existing Admin approval/rejection | Approval does not transfer money or remove paid access. Membership refund execution is blocked pending provider resolution and an entitlement-reversal policy. Existing Billplz HTTP 422 issue is **not fixed**. |

Normative audit and implementation plan: [module4-membership-plan.md](module4-membership-delivery.md). Chapter 3 sources include UC-4.1–4.7 and FR-4.1–4.5; Chapter 4 includes membership/payment UI, transaction/promo/refund schemas and sequences. The source explicitly supplies the seven-day request window; it is not an invented refund rule.

## Read-only Firebase findings

Evidence: `build/module4/read-only-audit.json` (23 October 2026).

- Top-level collections: `orgs`, `phoneClaims`, `system`, `users`.
- Organization collections include existing bookings, transactions and settings, but no plan, promo, membership-account or subscription collection.
- Shared settings contain only the booking settings document; projected membership configuration fields are absent.
- Ten sampled organization transactions are all `CoachingBooking` (query limit 1,000).
- Eight users, eight organization members and three profiles have none of the checked legacy membership billing fields. This is a field-presence audit, not a claim that arbitrary undocumented data was exhaustively migrated.
- No trusted prices/durations/benefits/promos were found. Mock catalogue values are preview fixtures only and are never used by Firebase mode.

## Reuse and financial guarantees

Reused the existing Billplz Sandbox gateway, signature verifier, independent bill GET verification, durable webhook inbox/claim, App Check readiness, authenticated scoped transport, Firestore transaction adapter, organization membership authorization, Admin review screen/commands and Android native PDF writer. Member Home/Profile/named Membership routes retain the existing screen names and inject the repository at the feature boundary.

Membership transactions use `kind: MembershipPurchase|MembershipRenewal`, `transactionId`, and no booking/branch reference. The existing Admin command contract retains its legacy `bookingId` **routing argument** for compatibility, but the stored membership transaction has no booking ID and the UI labels its actual type and organization-wide scope. Settlement never invokes booking holds, reservations, coach earnings or Google delivery jobs.

Only independently verified, fully paid, matching bills may activate membership. Callback signatures and collection/amount/reference identity are checked through the existing ingress. Duplicate callbacks and concurrent settlement cannot extend expiry twice. Current organization authority and Firebase Auth eligibility are checked at settlement. Invalid/late paid attempts remain cleared-money review cases; they are never silently discarded. An ambiguous create blocks another bill across fresh client request IDs. Admin can attach and verify the original bill, including its trusted URL, without creating another payment.

The checkout lifetime is a technical 30-minute safety limit, separate from plan duration. Closed/deleted/expired checkouts support a fresh intent after trusted status verification; late paid bills enter Admin review. A quote identifier prevents silently charging changed configured terms after the member reviewed a quote. All monetary arithmetic uses server-controlled integer minor units.

Plan/account/promo paths use `orgs/gainpath/{membershipPlans,membershipAccounts,promoCodes}`. Existing Rules deny direct financial writes and unauthorized ledger reads; authenticated App Check commands provide the scoped reads. **No Rules or index changes are proposed.** No redundant Admin catalogue CRUD was introduced.

Billplz documents bills and Payment Orders as separate flows; a Payment Order is a disbursement, not evidence that a refund approval has transferred funds. See [official API documentation](https://www.billplz.com/api/). Current code contains no recurring collection mandate; auto-renew is therefore unavailable.

## Changed files

New backend:

- `functions/src/modules/commerce/membership-payment-service.ts`
- `functions/src/modules/commerce/membership-payment-callables.ts`

Backend extensions:

- `functions/src/index.ts` — export five membership commands only as this task's addition.
- `functions/src/modules/commerce/booking-payment-callables.ts` — route verified membership callbacks; neutral return-page text.
- `functions/src/modules/commerce/booking-payment-admin.ts` — membership validation/projection/settlement dispatch/recovery/review; block membership refund execution.
- `functions/src/modules/commerce/booking-payment-admin-callables.ts` — membership-specific execution capability.

Domain and mobile:

- `packages/gainpath_domain/lib/membership.dart` and new `lib/src/membership/membership_commerce.dart` — asynchronous repository contract and cleared invoice content.
- New `apps/mobile/lib/app/di/membership_factory.dart`, `lib/infrastructure/firebase/firebase_membership_repository.dart`, `lib/infrastructure/local/membership_cache.dart`, `lib/features/membership/data/mock_membership_commerce.dart`, and `lib/features/membership/presentation/shared/membership_data_view.dart`.
- Existing membership dashboard, browse, purchase, renewal, history, refund and plan-card files under `apps/mobile/lib/features/membership/presentation/` — one shared UI for mock/Firebase.
- `apps/mobile/android/app/src/main/kotlin/com/zyang/gainpath/CoachStatementPlugin.kt` — reuse PDF writer with membership filename and saved-invoice viewer action; retain coach statement method.
- Incidental formatting only in `membership/application/membership_state.dart` and `presentation/member/payment_confirmation_screen.dart`. A restore-from-HEAD cleanup was rejected by automatic approval review because it could discard uncommitted work; formatting was left in place.

Admin:

- `apps/admin_web/lib/features/membership/payment_review_repository.dart`
- `apps/admin_web/lib/features/membership/presentation/admin/refunds_screen.dart`

Tests/evidence:

- New `functions/test/membership-payment.test.ts`, `functions/emulator/membership-payment.test.ts`, `firebase/membership.emulator.test.json`.
- New mobile `test/firebase_membership_repository_test.dart`, `test/membership_screens_test.dart`; new domain `test/membership_commerce_test.dart`.
- Existing Admin `test/payment_review_repository_test.dart`, `test/payment_review_screen_test.dart` updated for membership and neutral empty wording.
- This report, the audit/plan document, and local `build/module4/` evidence/APK.

The checkout already contained substantial uncommitted work. It was not committed, reset or broadly staged. Frozen workout/pose code, calendar/Gmail automation, AI/Gemini, account data and deployed Security Rules were not changed by this task.

## Verification

| Check | Result |
|---|---|
| `pnpm run build` and `pnpm run typecheck:tests` in functions | Passed |
| Membership, booking payment/Admin, Billplz gateway/refund and payment ingress unit tests | **101 passed** across six files; includes **13 membership tests** |
| Dedicated local Firestore emulator | **4 passed**: contention creates one bill; duplicate settlement; last promo capacity; distinct concurrent renewals preserve paid time; existing Rules deny financial tampering/cross-account reads |
| Mobile membership/repository/booking and legacy membership tests | **29 passed**; final membership-only rerun **9 passed** after resume-refresh change |
| Admin payment repository/screen tests | **11 passed** |
| Domain cleared invoice test | **1 passed** |
| Focused Dart analysis | Clean |
| Independent financial-safety review | Two recovery findings fixed and regression tested; focused recheck found no further important findings |
| Firebase Android debug APK | Built; package `com.zyang.gainpath`, version `0.1.0+1`, min SDK 26, target 36; signature verified; **not installed** |

Backend tests used local Node 24; configured deployment runtime remains Node 22. No provider end-to-end payment/refund or Xiaomi UAT is claimed. An incidental broader reviewer test attempt encountered a separate equipment-scanner localhost `EACCES`; this is not included as a passing full-suite result.

APK build flags: `--debug --no-pub --dart-define=BACKEND=firebase --dart-define=APP_CHECK_MODE=debug`. Debug App Check requires the existing approved debug setup; no token registration or console change was performed here. This is a development/UAT APK, not a production-signed release.

APK artifact: `build/module4/gainpath-module4-firebase-debug.apk`. Certificate DN `C=US, O=Android, CN=Android Debug`. Certificate SHA-256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`; SHA-1 `3640944054af4167ed26c9881df7c2d051352cd2`. Final APK file hash is recorded beside the artifact in `build/module4/apk-verification.txt`.

## Exact selective deployment proposal — subsequently approved and executed

Review the final dirty-tree source diff first. Preserve current Billplz Sandbox enabled/organization/collection parameters and secret bindings. No new secrets, schedules, Rules, indexes, IAM, billing, provider services or data seeding are included.

After explicit approval, from repository root:

```powershell
pnpm --dir functions run build
pnpm --dir functions exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:getMembershipOverviewCommand,functions:getMembershipQuoteCommand,functions:createMembershipPaymentCommand,functions:getMembershipPaymentCommand,functions:requestMembershipRefundCommand,functions:paymentWebhook,functions:billplzSandboxReturn,functions:listAdminBookingPaymentsCommand,functions:getAdminBookingPaymentCommand,functions:manageAdminBookingPaymentCommand
```

Five new functions: overview, quote, create, payment recovery, refund request. Five existing functions modified: webhook, hosted return page, Admin list/detail/manage. Do not deploy all Functions.

Admin Hosting requires **separate explicit approval** for the reviewed Firebase Admin bundle. The repository has unrelated uncommitted Admin changes, so a broad Hosting deployment must not be implied by approval of these ten Functions. Build/review the intended bundle first; only then propose `firebase deploy --project gainpath-0619 --only hosting` for that exact bundle. APK installation likewise requires separate approval.

Catalogue publication requires business-approved values and explicit data-write approval. Expected plan fields: `active`, `name`, `amountMinor`, `currency: MYR`, `durationDays`, `benefits`, `version`. Promo fields: `active`, `discountPercent`, `validFromMillis`, `validToMillis`, `maxRedemptions`, `currentRedemptions`, `planIds`. No prices or example production records are provided here.

## Xiaomi and Admin UAT checklist — future owner-approved sandbox actions

1. Approve a trusted test catalogue and any promo definitions; verify names/prices/durations/benefits against the business source. With no catalogue, confirm a clear empty state and no fabricated plan.
2. After separately approved installation, verify Firebase login, email verification and App Check. Enter Membership from Home, Profile and named navigation; compare shared UI with mock preview.
3. Complete one explicitly approved Sandbox purchase. Confirm one pending row, independent clearance, correct tier/expiry/benefits across branches, and no coaching booking/earnings/reservation or Google-delivery mutation.
4. Leave checkout, background/resume the app, interrupt connectivity, reject payment and reopen history. Verify no false success and no replacement bill while outcome is uncertain. Ask Admin to recover the original bill where needed.
5. Retry duplicate callbacks/checks and rapid checkout taps; confirm one activation. Renew early and verify all remaining time is retained; reactivate an expired plan from clearance time. Verify a changed quote is rejected before billing.
6. Exercise valid/expired/wrong-tier/exhausted promos and concurrent final allocation with approved fixture accounts. Confirm final server total and no client price override.
7. Confirm history excludes coaching transactions; save/open a PDF invoice from a cleared membership row. Offline records must be labelled cached. Switch accounts/logout during a pending request; previous financial data must disappear.
8. Submit an authorized refund inside seven days and reject an outside-window or other-account request. Verify disputed invoice, one review case, reason/notes, and pending/approved/rejected tracking in the existing Admin desk.
9. Approve/reject only within the agreed Sandbox UAT scope. Verify approval never displays money returned, never executes a membership transfer, and leaves paid access intact. Keep the existing Billplz HTTP 422 investigation separate.
10. Recheck Module 7 booking/payment/refund, coach reservations and current automatic Calendar/Gmail flows through their existing UAT protocol. Do not broaden existing automation recipient/booking scope or trigger real payments/refunds.

**Gate status:** the owner approved and the agent completed deployment of the ten listed Functions; see the deployment record. Trusted plan configuration, Admin Hosting, Xiaomi installation and any Sandbox financial UAT remain separately scoped approvals.
