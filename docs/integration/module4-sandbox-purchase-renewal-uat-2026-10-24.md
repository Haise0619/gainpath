# Membership Sandbox purchase and renewal — exact approval scope

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Prepared 24 October 2026, Asia/Kuala_Lumpur. Project `gainpath-0619`; organization `gainpath`.

**Historical approval proposal.** The owner subsequently approved this exact scope by replying “proceed”; the three approved Sandbox payments completed on24 October2026. See the [execution report](module4-sandbox-purchase-renewal-uat-results-2026-10-24.md). The original proposed limits and procedure below are preserved. The accepted read-only UAT remains PASS for its original scope. This document authorizes nothing by itself. The owner's request explicitly asks for separately approvable financial UAT; “proceed now, no need planning” was applied to completing the checks and this concrete execution scope without another design cycle.

## Verified identities and current state

Fresh privileged read-only preflight: **24 October, 10:16:20 MYT**. Fresh normal Member sign-ins, App Check and deployed overview/quote calls completed at **10:18:30 MYT**. No account setup, role assignment, email-verification change, credential reset or debug-token registration was performed. Normal sign-in can update Firebase Auth login metadata; it does not modify account configuration.

| Use | Existing authorized identity | UID | Current financial eligibility |
|---|---|---|---|
| A: Basic purchase, then Basic renewal | `member-a-fixture-email-redacted@example.invalid` | `member-a-uid-redacted` | Active organization Member; Auth enabled/email verified; resolved Free; no paid expiry; no membership account, membership transactions or pending checkout |
| B: separate Premium purchase | `member-b-fixture-email-redacted@example.invalid` | `member-b-uid-redacted` | Active organization Member; Auth enabled/email verified; resolved Free; no paid expiry; no membership account, membership transactions or pending checkout |

These are retained disposable identities from the already-authorized Module 1 lifecycle and Module 7 Sandbox UAT fixtures. Possession of their existing private fixture credentials was checked; both subsequently authenticated successfully. Passwords and Auth/App Check tokens are not included in evidence. Their prior authorization does **not** imply approval of the new membership transactions.

The current `transactions` queries scoped by each exact `memberId` returned no rows, including no currently visible CoachingBooking rows. This is a current scoped ledger observation, not deletion of or a denial that historical Module 7 UAT occurred. Existing canonical users, the real Xiaomi Member session and Coach/Admin identities are outside the proposed purchase targets. Admin review uses the owner's existing authorized Admin session; no new Admin account or credentials will be created or extracted.

Effective membership was first resolved locally through the preserved deployed entitlement implementation using current authoritative Auth/Firestore facts, then independently confirmed by each Member's deployed `getMembershipOverviewCommand`. Before execution, repeat the read-only overview, catalogue and pending-checkout checks. Stop on any changed identity, eligibility, paid history, pending checkout, unknown state or catalogue terms.

## Fixed financial ceiling and catalogue

| Step | Member | Intent / stored kind | Catalogue and version | Amount | Duration |
|---|---|---|---|---|---|
| 1 | A | `purchase` / `MembershipPurchase` | `basic`, `basic-three-tier-uat-v1` | MYR 89.00 / 8,900 minor units | 30 × 24 hours |
| 2 | A | `renewal` / `MembershipRenewal` | Same Basic catalogue/version | MYR 89.00 / 8,900 minor units | Additional 30 × 24 hours |
| 3 | B | `purchase` / `MembershipPurchase` | `premium`, `premium-three-tier-uat-v1` | MYR 129.00 / 12,900 minor units | 30 × 24 hours |

**Maximum: three provider bill-creation attempts, three distinct Sandbox bills, three successful Sandbox simulator payments, MYR 307.00 total simulated face value.** There is no allowance for an additional failure, expiry or replacement bill. An ambiguous create consumes its attempt allowance even if no bill ID is returned. No fourth bill or success is permitted. A failed, expired, ambiguous or partially completed step stops the sequence for reconciliation; it is not automatically replaced. After Step 1 succeeds, A holds Basic; Premium must use B, never an active Basic-to-Premium conversion.

Endpoint must remain `https://www.billplz-sandbox.com/api/`; checkout must be HTTPS on `www.billplz-sandbox.com` or `billplz-sandbox.com`, with no user info or unexpected port. Collection: **`cd9oovf8`**; organization reference: **`gainpath`**. Production Billplz is excluded. The official [Billplz API documentation](https://www.billplz.com/api/) separates Sandbox and production accounts and documents callback signatures, bill states and smallest-unit amounts. Only the hosted Sandbox simulator may mark a bill paid; no real bank/card funding is part of this proposal.

Both active catalogue documents exactly matched approved activation readback, including their five foundation benefits, 30-day durations and versions. Authenticated quotes matched 8,900 and 12,900 MYR minor units; no discount. Promo configuration stays deferred, `promoCode: ''`. Auto-renew remains unavailable; `autoRenew: false`. Membership and paid time remain organization-wide across GainPath branches. No future Premium voucher/reward promise or restriction on Workout, Reports, Rewards, Booking, AI or Google integration is activated.

## Exact execution sequence after approval

1. Record the approval and its bill/payment/value ceilings in a local journal. Use only A and B. Keep the existing real Xiaomi account/session and installed APK intact; use isolated authenticated fixture sessions for financial UAT. No deployment, installation or account configuration change is needed. Capture fresh Auth eligibility, membership overview, account/transaction snapshots, catalogue versions and Function/policy metadata. Pin the approved benefits and prices. Recheck App Check; stop if unavailable, never disable enforcement or register another token.
2. Fetch a fresh trusted Basic quote as A through `getMembershipQuoteCommand`. Confirm amount/base amount 8,900, MYR, duration 30, version `basic-three-tier-uat-v1`, the five approved benefits and a nonempty `quoteId`. Persist the immutable quote and request ID **before** sending the create request. Submit `createMembershipPaymentCommand` once with the payload below. Mark the bill-attempt budget consumed before transmission. Never add an amount, member ID, branch, benefit, expiry or duration override.
3. Capture the returned transaction/bill/checkout identity. Verify a single pending `MembershipPurchase` row, 30-minute checkout deadline, no paid invoice or entitlement activation. A remains Free. Repeat the **same** create request at most once to check same-request recovery only if the first response was unambiguous and successful. It must return the same transaction/bill, without an additional provider create. Do not issue a fresh request ID to escape pending state. A transient response loss goes to recovery instead of another create.
4. Open only the returned approved Sandbox checkout. Complete **one successful simulator payment** well before the real 30-minute deadline. Capture the provider completion/bill ID and callback evidence. A redirect or screenshot alone is not clearance. First inspect Firestore through read-only inspection/overview to determine whether the genuine callback settled independently. If pending, bounded trusted status recovery may reconcile the same bill; record whether activation was by callback or recovery, without claiming callback-only success.
5. Confirm independently verified bill identity, collection, references, amount, `paid: true`, `state: paid`, `paid_amount: 8900`. The transaction must become cleared/confirmed, invoice paid, and A's effective tier Basic. Let its persisted server `clearedAtMillis` be **C1**, and account/transaction expiry **E1**. For this verified empty baseline, require **E1 = C1 + 2,592,000,000 milliseconds**. Compare organization-wide account, overview, invoice/history and Admin review. Record UTC milliseconds and MYT display time.
6. While A's Basic is active, record E1 and fetch another Basic quote with the same approved terms. Submit the single renewal create with its distinct fixed request ID; ensure `MembershipRenewal`, MYR89, a new bill and no expiry change while pending. Complete one simulator payment on this renewal bill. Let server clearance be **C2**. Require **E2 = max(C2, E1) + 2,592,000,000**. Because this sequence renews before E1, require **E2 = E1 + 2,592,000,000** exactly. Reject `C2 + 30 days` if it discards remaining time. A now has two distinct cleared transactions/invoices and approximately 60 paid days from C1, with no double renewal.
7. Independently recheck B is still eligible Free with no pending checkout/history. Obtain B's fresh trusted Premium quote, submit its single purchase create and complete one simulator payment at MYR129. Require cleared/confirmed/paid invoice, effective Premium and **EP = CP + 2,592,000,000**, where CP is that transaction's server clearance time. Verify A's two Basic transactions and expiry remain unchanged. B's record must not reference A, a branch or a CoachingBooking.
8. Reopen overview/history and the existing Admin payment/refund management screens. Inspect each of the three exact transaction IDs. Review only; no refund request, approval, rejection or transfer is included. Verify refunds remain unavailable for membership execution, paid history/invoice projections agree with ledger, and Admin shows the real membership kind and organization-wide scope. Validate cleared-only invoice content through the existing shared invoice/domain path; any separate Xiaomi paid-fixture PDF save/view test requires an explicitly approved device account switch and is not claimed here.
9. Check final ceilings, single activation per transaction, expiry arithmetic, account isolation, catalogue/policy immutability and compatibility evidence. Preserve all audit records and resulting test membership terms. Do not reset test accounts to Free, delete transactions or “clean up” paid history. Report PASS/FAIL per step and any unverified evidence separately.

All create bodies share `schemaVersion: 1`, `organizationId: 'gainpath'`, `promoCode: ''`, and the freshly verified quote's `quoteId`:

```json
[
  {"planId":"basic","intent":"purchase","requestId":"m4-20261024-a-basic-purchase-v1"},
  {"planId":"basic","intent":"renewal","requestId":"m4-20261024-a-basic-renewal-v1"},
  {"planId":"premium","intent":"purchase","requestId":"m4-20261024-b-premium-purchase-v1"}
]
```

The server derives `transactionId = membership_ + keyOf(authenticatedUid, requestId)`. Preflight each derived path for absence before the first create. If a path already exists, inspect/reconcile it and do not silently choose a new ID. Quote drift or a stale quote stops before provider creation. These IDs bind this one approved run; a later run requires a fresh approved scope.

## Expected Firestore and evidence

| Location | Expected effects after approval | Required proof |
|---|---|---|
| `orgs/gainpath/transactions/{membership_transaction_id}` | Exactly three new membership records on a full successful run; amounts/kinds/version/benefits snapshotted by server; `sandbox`, `billplz`, MYR, no stored `bookingId`, branch or Coach | Before/pending/cleared snapshots; transaction/bill IDs; `paymentStatus`, `fulfilmentStatus`, `invoiceStatus`; C1/E1/C2/E2/CP/EP; no unexplained fourth row |
| `orgs/gainpath/membershipAccounts/{A_UID}` | New pending pointer then Basic term, last transaction and `autoRenew:false`; renewal extends the term once | Pending leaves paid facts unchanged; E1 then E2; both original invoices remain |
| `orgs/gainpath/membershipAccounts/{B_UID}` | New pending pointer then Premium term, last transaction and `autoRenew:false` | Free before clearance; Premium only after verified CP; EP arithmetic |
| `.../transactions/{id}/events/{deterministic_event_id}` | `checkout_reserved`, `bill_created`, `membership_activated` for each clean payment; `payment_review_required` instead on ineligible/late paid outcomes | One logical activation event and one expiry application per transaction despite duplicate delivery |
| `system/paymentIngress/events/{callback_digest}` | Existing verified webhook inbox/claim/processed audit; retries may update claims | Signed callback accepted and independent provider bill verification; mapping to the exact membership transaction; no forged live replay |
| Existing Admin read APIs / UI | Read projections for these exact records; legacy `bookingId` **request routing argument** equals membership transaction ID | Correct displayed kind/amount/status and no claim of a CoachingBooking; `refundExecutionAvailable:false`; ordinary Member denied Admin scope |
| Existing member billing/invoice projection | Two paid Basic records for A, one paid Premium record for B, chronological timestamps/amounts and correct member/organization | Cleared-only invoice content; no invoice counted as paid while pending; no CoachingBooking intermixing |
| Existing unrelated records/config | No UAT changes to catalogue, identity/profile, policies, CoachingBooking, reservations, availability, earnings, Google jobs or Rules/indexes/Hosting | Before/after document hashes for fixture user/member docs and scoped existing Module7 records where present; selected existing Module7/earnings/Google record snapshots plus Function metadata; any background changes investigated rather than overwritten |

Do not invent provider transaction reference fields if absent from this integration's response. Attach provider verification evidence only as exposed by trusted server/Admin review or sanitized server logs; never copy provider keys, App Check secrets, bearer tokens or passwords into screenshots/reports. Keep raw private fixture files local. The approval includes normal trusted financial commands' ledger/account/audit writes and any built-in status-check timestamps; it does not authorize direct financial-document edits.

## Failure, duplicate and concurrency verification

Fresh checks completed before this approval request:

- **87 passed, 0 failed** against the preserved deployed Stage A source: membership quote/price protection, duplicate settlement, concurrent renewal, create uncertainty, failed/deleted/late payment handling, account isolation, refund authorization, entitlement, original Module7/Admin callback and Google delivery/sync regressions. **Two Stage C voucher cases intentionally excluded** because voucher financial code was not deployed. This is regression evidence, not a new cloud deployment or live paid checkout.
- **5 passed, 0 failed** against a local Firestore emulator on demo project `demo-gainpath-membership`: Free/paid/expired resolution, six-way checkout/settlement contention, last promo allocation, distinct concurrent renewals and direct financial-write/cross-account read denial. These exercise the current local implementation; deployed-source domain tests above establish the matching deployed core behavior. Emulator data never targets `gainpath-0619`.
- An additional current-working-tree focused run passed **134 tests across seven files** (overlapping coverage; do not add these counts together as unique cases). All provider responses/refund errors there are test doubles, including simulated HTTP422. No refund operation was sent to Billplz.
- Four fresh authenticated deployed reads passed: overview and quote as A, overview and quote as B. Existing registered App Check was reused. Zero payment, reconciliation or refund endpoints were invoked.

The local cases cover duplicate callbacks/signature validation through the existing ingress regression tests and membership duplicate settlement/concurrency through the domain/emulator tests; they are not evidence of a live Membership callback replay. **No deliberately failed payment, fabricated/signed replay, uncertain-provider injection, cancellation, provider bill deletion, live timestamp edit or late payment is proposed.** Billplz documents a failed attempt as potentially leaving the bill `due`; the app must show unpaid/pending, never infer a terminal failure or paid activation from the return screen. Expired checkout and ambiguous create stay gated by trusted verification. A local passing refund test does not resolve the existing provider HTTP422 problem.

## Reconciliation and recovery limits

1. On timeout, unexpected amount/reference/state, wrong identity, HTTP error, checkout expiry, provider lag, mismatched history or budget ambiguity, **stop new create/payment attempts across the whole sequence**. Journal the attempt as consumed. Do not create a replacement bill, re-pay a bill, directly patch membership or execute a refund.
2. Preserve transaction ID, request ID, member UID, quote, known bill ID, creation/deadline times and sanitized observed responses. Inspect the existing row and webhook inbox read-only. Unknown does not mean failed or Free entitlement approved for another checkout. The existing implementation may retain a pending pointer for reconciliation.
3. With a known bill, use `getMembershipPaymentCommand` for **at most six explicit status checks per bill, at least ten seconds apart**. This is a **financial reconciliation command that can write**, not a read-only operation. No overlapping background poller is permitted in the scoped harness. Prefer read-only overview first to identify independent callback clearance. Never keep paying while waiting.
4. Admin can perform **at most two `verify` commands per bill** within this proposed approval, using the existing `manageAdminBookingPaymentCommand`, exact membership transaction ID as its legacy routing key and a persisted command request ID. That command may reconcile and write an audit record. No `execute_refund`, `check_refund`, `recover_refund`, approval/rejection or provider Payment Order operation is authorized.
5. If bill creation returned an uncertain result without an ID, the attempt remains quarantined. Ask the owner to inspect the existing Sandbox dashboard for an exact matching collection/reference/amount. No automated provider-key extraction or broad speculative bill matching. Once the original bill ID is conclusively identified, **at most one Admin `recover_bill` command per affected transaction** is proposed, with an auditable reason and immutable ID; the backend must independently verify it before binding. Recovery reuses the original bill and consumes no replacement bill allowance. If the ID cannot be established, leave pending/review and report blocked.
6. A fully paid matching bill inside the eligible deadline may activate/renew once through trusted settlement. A paid late/ineligible/different-plan bill must remain **cleared / reconciliation_required**, invoice paid, with the paid money fact retained and no forced activation. Further remediation requires a separate decision; do not reinterpret refund approval as a completed transfer. An unpaid due bill before deadline stays pending; a trusted deleted/expired result does not authorize a fourth create.
7. Stop if bounded recovery cannot establish a consistent final result. Supply a reconciliation table of provider/ledger/entitlement facts and the next required decision. Preserve financial history and account state; never roll back paid facts by restoring the pre-UAT absent account snapshot.

## Compatibility, risk and exclusions

All **57 Function revisions/update times** still match Stage A readback. The live quote/create/status/webhook/return/Admin financial functions are ACTIVE, Sandbox enabled for `gainpath` / `cd9oovf8`, and retain the existing Module7 payment infrastructure. No new Functions are required. No access, reward or Premium Coach voucher policy document is active/present. No recurring billing is available.

Risk is bounded but real for application data: successful simulator payments create durable ledger history and change these two test Members' paid tier/expiry in the actual Firebase project. Callback lag, response loss and a 30-minute checkout boundary may cause review states, so reserve before external effects and stop rather than creating replacement bills. Existing Module7/Coach earnings/Google behavior is protected through unchanged deployment/policies, transaction-kind routing, scoped before/after evidence and local regressions; this does not claim a new full live Booking, earnings or Google E2E test. Natural concurrent/background changes must be investigated and never “restored” automatically.

Approval excludes new/modified accounts or roles, catalogue/promo/policy writes, Basic-to-Premium conversion, billing/service purchases, production money, subscriptions, refunds/HTTP422 retries, account resets/data deletion, APK install/account switch, Rules/indexes/Hosting/Functions deployment and reward/voucher activation. No new module access restrictions or frozen workout/pose changes are included. Historical overview maxInstances=20 remains a separate unresolved configuration exception.

Local evidence:

- `build/module4/financial-uat-readonly-preflight.json`: current exact identities, Auth/organization/entitlement/history/catalogue and deployed compatibility; 16 read requests, zero document writes/provider calls.
- `build/module4/financial-uat-authenticated-readback.json`: four deployed Member reads and trusted quotes; no credentials/tokens saved.
- `build/module4/financial-uat-deployed-source-tests.json`: 87 passing / two intentionally excluded cases.
- `build/module4/financial-uat-emulator-tests.json`: five passing local emulator cases.
- `build/module4/financial-uat-approval-scope.json`: exact immutable transaction requests, derived IDs and ceilings.

## Explicit approval requested

**Approve this single Sandbox run for existing Members A and B: at most three bill-creation attempts / three distinct bills / three successful simulator payments, MYR307 total (89 + 89 + 129), with only the bounded same-bill status/Admin verification/recovery described above and their normal server-managed financial records. No refunds, replacement bills, account setup, device account switch or deployment.**

No financial action starts until approval of this concrete scope. A smaller approval may omit B's Premium step, reducing the ceiling to two bills/two successes/MYR178; do not silently substitute accounts or spend the unused allowance on another scenario.
