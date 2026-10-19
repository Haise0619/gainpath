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
- Member/Coach booking-list consistency and disposable listing cleanup are recorded in sanitized delivery evidence. Audit and fixture history are retained. Admin visual UAT, account-switch mobile UAT and real elapsed 15-minute expiry/replacement-slot UAT remain manual; expiry/concurrency/lock integrity passed focused unit and Firestore emulator tests. No live timestamp or policy bypass occurred.

## Consolidated Sandbox UAT after activation approval

Use only separately approved disposable identities and synthetic records; retain audit history and leave any disposable public listing inactive afterward. Never modify canonical accounts or bypass time policies.

1. Member selects an eligible Coach/day/time. Verify real fee, branch and 15-minute pending hold. Continue opens genuine Sandbox hosted checkout. Cancel/back/reopen must reuse the same bill and booking.
2. Complete Sandbox payment. Return to GainPath and check status: only independently verified payment confirms. Verify the same confirmed booking in Member, assigned Coach and Admin, with matching amount/time/branch.
3. Replay the signed callback and retry status reads; observe one payment event/confirmation, no duplicate booking. Tampered signature, identity or amount must fail without confirmation. Redirect success alone must do nothing.
4. Complete payment after genuine expiry, cancellation or a conflicting replacement reservation. Observe paid reconciliation state, unchanged replacement locks and no refund claim. Do not edit timestamps to shorten the wait.
5. Exercise provider timeout/lag, double taps, background/resume and account switch. Show useful pending/error states; reject unrelated users and never expose credentials or private provider payloads.

APK installation requires exact-artifact approval, matching installed signing identity and backup of existing APK/private data; update in place without clearing data. Build includes the owner's preserved uncommitted mobile work and is not represented as a clean-HEAD artifact.

Built Firebase debug APK: `build/billplz-sandbox/gainpath-billplz-sandbox-firebase-debug.apk`. SHA256: `f72194f7db18281ff5901a4cdf78bd0b3265d07ccb82ca9008b11ec550a89dcc`. Installed and launched on approved Xiaomi `23013RK75C` after actual installed-signature verification and backup. Certificate SHA256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450` matched. Private backup was 98,854,400 bytes; before/after private archives were byte-identical. Installed APK hash matched the approved artifact. No app data was cleared.
