# Billplz Sandbox booking payment delivery

Date: 2026-10-19. Implementation commits: `14acdb3` (backend/contracts), `b7b26bf` (shared mobile UI).

## Current activation status

Implemented, selectively deployed and verified against real Firebase and Billplz Sandbox after explicit owner approval. Credentials are held in server-side Secret Manager and are not committed or embedded in the APK. Only approved synthetic fixture records were created/changed. Owner manual UAT remains pending.

Read-only Firebase inspection: project `gainpath-0619`, organization `gainpath`, region `us-central1`; 27 active functions, none of the five payment targets deployed. Existing hold policy is 15 minutes. Exact deployed Firestore Rules were used for the focused authorization emulator checks. No Rules, indexes, Storage, Hosting or Scheduler changes are proposed.

Owner approved activation of `getBookingPaymentQuoteCommand`, `createBookingPaymentCommand`, `getBookingPaymentCommand`, `paymentWebhook`, and `billplzSandboxReturn`. All five are ACTIVE on Node.js 22. Secret Manager API was enabled as a provisioning prerequisite; the two secrets have secret-level runtime accessor bindings. API key version 2 and signature key version 1 are bound only to the appropriate functions. Collection, organization and enabled configuration read-back passed. Default in code remains disabled; only the Sandbox provider host is supported.

Post-deployment read-back found 32 functions: the five new targets and all 27 previous functions with unchanged revisions. Exact Firestore/Storage Rules hashes are unchanged. Anonymous calls to each of the three payment callables returned 401 UNAUTHENTICATED. Firebase CLI reported a build-image cleanup warning after successful deployment; no unrelated cleanup was attempted.

## Behavior and boundaries

- Existing purple booking selection/summary and confirmation widgets are retained. Hosted checkout opens externally; GainPath collects no banking credentials. Confirmation is shown only from trusted backend status, never redirect parameters.
- Server quotes the published consultation fee in MYR minor units. The existing fee is per booking; no invented duration proration. Missing real values use a truthful placeholder or disable checkout.
- One server-owned transaction per existing booking under `orgs/{org}/transactions/{bookingId}`. Creation reserves this identity before the external request. Ambiguous creation is quarantined for reconciliation instead of risking a second bill.
- Signed callback verification precedes processing. Independent Get Bill verification binds bill, collection, references, amount and paid status. Duplicate callbacks are idempotent; provider lag is retried. Client read-back also checks authoritative provider status.
- Booking confirmation atomically promotes only the original eligible hold, its own reservation locks, daily reservation and expiry job. Current identity, verification, publication, branch, roster, policy, capacity and deadlines are rechecked. Existing Coach/Admin booking interfaces observe the same booking record.
- Paid after expiry/cancellation, lost slot, changed eligibility or policy records cleared payment with `reconciliation_required`. It does not confirm, overwrite another reservation, or claim a refund. Automatic refunds, payouts and commission accounting are outside this delivery.
- Financial events use deterministic create-only audit entries. Existing Rules deny direct client access; authorized payment callables expose only the relevant participant/admin view.

## Essential verification

- 45 focused backend tests passed: provider adapter, payment service, callback and existing booking lifecycle.
- 16 focused Flutter/domain tests passed: payment UI/repository/contracts and existing booking composition/cubit.
- Three real Firestore emulator tests passed: concurrent creation/confirmation, expiry/conflict reconciliation and direct financial-record denial for Member/Coach/Admin.
- Functions build, test TypeScript checking and targeted Flutter analysis passed. Independent security review completed; identified branch eligibility, shortened booking window and cancellation-during-request issues were fixed with regressions.
- No broad CI rerun was required. The separate live results below establish the tested Firebase/Billplz behavior; they do not replace owner UI acceptance.

## Observed live Sandbox results

- Two newly registered, verified disposable identities (Member and Coach), synthetic professional/credential eligibility fixtures, and dated availability were used. Synthetic credentials are test setup, not evidence of a genuine professional qualification or of exercising Admin credential review. No canonical identity or existing booking was modified.
- Server-authoritative RM1.00 quote produced a genuine Sandbox bill for the original pending hold. Hosted Billplz Simulator completed payment. Before any Member refresh, the real provider callback independently verified the bill and persisted cleared payment plus confirmed booking. Member and assigned Coach payment read-back agreed.
- Live invalid-signature request returned 401. Correctly signed replay, duplicate replay and an older due callback returned accepted without changing the confirmed booking or four financial audit entries. Repeating checkout returned the same bill.
- A second bill was created while its hold was pending. The Member cancelled through the existing callable, then completed the hosted Sandbox simulator payment. Payment became cleared/reconciliation_required while the booking remained cancelled, with no refund claim.
- Member/Coach booking-list consistency and disposable listing cleanup are recorded in sanitized delivery evidence. Audit and fixture history are retained. Admin visual UAT and account-switch mobile UAT remain manual. The elapsed-expiry/replacement-slot case, initially pending, was completed in the extension below. No live timestamp or policy bypass occurred.

## Consolidated Sandbox UAT after activation approval

Use only separately approved disposable identities and synthetic records; retain audit history and leave any disposable public listing inactive afterward. Never modify canonical accounts or bypass time policies.

1. Member selects an eligible Coach/day/time. Verify real fee, branch and 15-minute pending hold. Continue opens genuine Sandbox hosted checkout. Cancel/back/reopen must reuse the same bill and booking.
2. Complete Sandbox payment. Return to GainPath and check status: only independently verified payment confirms. Verify the same confirmed booking in Member, assigned Coach and Admin, with matching amount/time/branch.
3. Replay the signed callback and retry status reads; observe one payment event/confirmation, no duplicate booking. Tampered signature, identity or amount must fail without confirmation. Redirect success alone must do nothing.
4. Complete payment after genuine expiry, cancellation or a conflicting replacement reservation. Observe paid reconciliation state, unchanged replacement locks and no refund claim. Do not edit timestamps to shorten the wait.
5. Exercise provider timeout/lag, double taps, background/resume and account switch. Show useful pending/error states; reject unrelated users and never expose credentials or private provider payloads.

APK installation requires exact-artifact approval, matching installed signing identity and backup of existing APK/private data; update in place without clearing data. Build includes the owner's preserved uncommitted mobile work and is not represented as a clean-HEAD artifact.

Built Firebase debug APK: `build/billplz-sandbox/gainpath-billplz-sandbox-firebase-debug.apk`. SHA256: `f72194f7db18281ff5901a4cdf78bd0b3265d07ccb82ca9008b11ec550a89dcc`. Installed and launched on approved Xiaomi `23013RK75C` after actual installed-signature verification and backup. Certificate SHA256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450` matched. Private backup was 98,854,400 bytes; before/after private archives were byte-identical. Installed APK hash matched the approved artifact. No app data was cleared.

## Payment review and recovery extension — 2026-10-19

Implementation: `512a0eb` backend/contracts, `12d844c` mobile/domain and `69f4663` shared Admin UI. Activation is pending a separate exact approval. The earlier live payment results above remain valid for the original deployment; they are not evidence of executing the new refund functions. The official Admin entry remains http://localhost:7359/ using `tools/admin_web/build.cjs` and the existing canonical server.

The existing Admin Refunds navigation and purple/shared StatTile, Panel, list/detail and history presentation now connect to server-owned booking payment records. Search and filters apply to the displayed page, cursor pagination is bounded, and page statistics do not claim organization-wide totals. Missing records have truthful empty states. Actions show consequences, required reasons, loading/error feedback and duplicate-submission protection. Identity changes invalidate the captured Admin session.

New Admin-only/Auth/App Check callables: `listAdminBookingPaymentsCommand`, `getAdminBookingPaymentCommand`, `manageAdminBookingPaymentCommand`. They reuse `orgs/{org}/transactions/{bookingId}` and create-only events plus command/result receipts underneath each transaction. There is no duplicate payment/refund collection. Admin can independently verify a bill, recover an uncertain bill by provider ID, approve/reject a paid reconciliation case, execute a Sandbox refund, and check/recover its original Payment Order. Recovery validates exact collection, references and full amount; it never creates a replacement bill or payout. A repeated request with changed payload is rejected.

Refund decisions are distinct from money movement. Only cleared, unfulfilled reconciliation cases are eligible; confirmed bookings are excluded because their cancellation/refund policy is outside this change. A payout attempt is reserved atomically before any external request. Uncertain outcomes cannot be resent. Provider order ID is retained before independent GET verification; only verified `completed` becomes refund completion. Provider `refunded` means a reversed/failed disbursement, not successful customer refund. An issued/reversed order cannot be reapproved for another attempt. Booking records and reservation locks are not changed by refund execution.

Billplz refunds use separate V5 Payment Orders, not a reversible FPX bill: https://support.billplz.com/guide/issue-a-refund and https://www.billplz.com/api/#v5. This adapter is hardcoded to the Sandbox host, synthetic recipient, `DUMMYBANKVERIFIED`, and dummy account only. It never accepts real bank details. V5 requests use the documented ordered HMAC-SHA512 checksum. Stable refund references, bound provider identities, ten-second timeout and no blind retries protect ambiguous operations.

The new optional `BILLPLZ_SANDBOX_REFUND_COLLECTION_ID` must identify a separate Sandbox Payment Order collection. Missing/invalid configuration disables execution while preserving review/recovery actions. A sufficient Sandbox Payment Order limit is also required; no real-money funding is authorized. Activation proposal: create/configure one Sandbox Payment Order collection; selectively deploy the three new Admin callables plus `getBookingPaymentCommand` (adds payment/refund status to Member read-back). Existing API/signature secrets are reused with the management function's declared bindings. No Rules, indexes, Storage, Hosting, Scheduler or unrelated function changes. Exact live Rules and 32-function baseline were read again at 11:20 UTC; Rules match the earlier hashes.

Mobile payment checks now wait at least ten seconds and schedule up to six followups, including return during cooldown. Background/session drift/disposal/confirmation stop polling. Last-check/wait feedback is visible. Unpaid closed checkout, paid reconciliation, approved/processing/uncertain/rejected/failed/completed refunds have distinct copy; refunds never show booking confirmation.

Focused verification: 61 backend tests across payment/provider/Admin suites (including one added retry regression), 4 Firestore emulator tests including concurrent refund execution, 11 payment widget tests, 3 domain tests and 13 focused Admin tests. Functions build/test typecheck and targeted Flutter analysis passed. Independent review found and verified fixes for reapproval, collection rotation, changed replay payload and transient settlement retries; no remaining actionable P1/P2 findings in scope. Broad CI was not rerun. A read-only authenticated Sandbox Payment Order limit request returned HTTP 200 but insufficient capacity for both RM1 refund tests; this setup prerequisite remains unresolved. No real funds were loaded.

Prepared Android artifact: `build/payment-review/gainpath-payment-review-firebase-debug.apk`, SHA256 `6e5a2ed1b0f9c15a26a944b7bb7649856846828ce36b7f456b273b3d6a901170`. Signature matches the existing debug certificate. This new artifact is not installed yet; exact-artifact approval and backup remain required. Builds include preserved owner changes and are not clean-HEAD artifacts.

Consolidated retest: (1) Member hosted checkout, background/return/cooldown and manual status; (2) Admin queue/search/page/detail/history and unauthorized/session-drift denial; (3) mismatched bill recovery rejected, exact bill recovered without another bill; (4) cancelled/expired paid case approval/rejection with reasons, one dummy Sandbox payout, independent completion, timeout/order recovery and replay; (5) confirm Member/Coach/Admin booking agreement and retained cancellation/expiry/locks. Owner visual PASS remains pending. No real-money refund is implemented or claimed.

Canonical web verification found an old Flutter worker serving cached application code despite fresh server assets. `ba194f1` versions both bootstrap and app code with `?build=<bundle hash>` so old workers cannot match their cache-first resource keys; it preserves the same official root URL and does not clear app/session data. Two focused Node server/cache regressions passed. The rebuilt/served app SHA256 is `d6b598be983ad4816fcd9810eaca35df0288934732cfba73f7b10c1bcac1622b`. Browser inspection verified the new payment-review screen and unchanged navigation; its live list currently reports an error because the new backend callables are not yet approved/deployed. This is not a successful live Admin queue test.

Real elapsed-expiry UAT completed at approximately 11:37 UTC using the already approved disposable Member/Coach. The original hold genuinely expired at 11:34:19.934 UTC and the existing Scheduler persisted `expired`. A new pending hold reserved the identical slot. The old hosted Sandbox bill was then paid after expiry; independent backend verification recorded `cleared`/`reconciliation_required` and left the original booking expired. Both replacement slot-lock records matched their complete pre-payment snapshots. The disposable replacement was cancelled through the existing Member command, and the disposable Coach listing was set inactive again. All records/audit history were retained. No timestamps, policy, existing bookings or canonical accounts were changed.

## Approved activation update — 2026-10-19 (supersedes pending activation notes above)

Explicitly approved activation completed. Active Sandbox Payment Order collection `e3f422f7-00c6-4cdb-a85b-22c3d2fdd0f2` was created/read back and its nonsecret ID configured. Only the three Admin payment callables and getBookingPaymentCommand were deployed. All four are ACTIVE on Node 22; unrelated revisions and exact Rules remain unchanged. All four anonymous probes returned 401; six live Member/Coach requests against Admin functions returned 403. No Rules, indexes, Storage, Hosting or Scheduler changes.

Canonical Admin http://localhost:7359/ now loads the real queue and synthetic private detail/history. Rejection then approval with reasons persisted both immutable decision events. Member and Coach read back approved refund/reconciliation status. Booking remains cancelled, payment cleared, no payout/order created. Canonical records were untouched.

Approved APK SHA256 6e5a2ed1b0f9c15a26a944b7bb7649856846828ce36b7f456b273b3d6a901170 was installed and launched at 11:53 UTC, with actual installed signer matched, APK/private backup, installed hash matched and byte-identical private archives. No data cleared.

Refund execution remains unverified: Sandbox limit RM0.00 and credit RM-1.70. A virtual RM10 limit reload bill opened on the genuine Sandbox host, but Simulator did not respond and Proceed to pay stayed disabled after reload. No real funds loaded, payout attempted or refund completion claimed. Complete only provider Sandbox simulator setup before resuming dummy refund UAT and independent completion verification. Owner manual UI PASS remains pending.
