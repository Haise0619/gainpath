# Billplz Sandbox booking payment delivery

Date: 2026-10-19. Implementation commits: `14acdb3` (backend/contracts), `b7b26bf` (shared mobile UI).

## Current activation status

Implemented and locally verified; not deployed or verified against the real Sandbox. No credentials have been committed, provisioned or embedded in the APK. No live payment/booking records were changed. Owner manual UAT remains pending.

Read-only Firebase inspection: project `gainpath-0619`, organization `gainpath`, region `us-central1`; 27 active functions, none of the five payment targets deployed. Existing hold policy is 15 minutes. Exact deployed Firestore Rules were used for the focused authorization emulator checks. No Rules, indexes, Storage, Hosting or Scheduler changes are proposed.

Selective activation requires approval for `getBookingPaymentQuoteCommand`, `createBookingPaymentCommand`, `getBookingPaymentCommand`, `paymentWebhook`, and `billplzSandboxReturn`. Provision server-side secrets `BILLPLZ_SANDBOX_API_KEY` and `BILLPLZ_SANDBOX_X_SIGNATURE_KEY`, with runtime access only where required. Configure `BILLPLZ_SANDBOX_COLLECTION_ID`, `BILLPLZ_SANDBOX_ORGANIZATION_ID=gainpath`, and `BILLPLZ_SANDBOX_ENABLED=true`. Default is disabled. Only the Sandbox provider host is supported.

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
- These results do not establish real Firebase/Billplz success. No broad CI rerun was required.

## Consolidated Sandbox UAT after activation approval

Use only separately approved disposable identities and synthetic records; retain audit history and leave any disposable public listing inactive afterward. Never modify canonical accounts or bypass time policies.

1. Member selects an eligible Coach/day/time. Verify real fee, branch and 15-minute pending hold. Continue opens genuine Sandbox hosted checkout. Cancel/back/reopen must reuse the same bill and booking.
2. Complete Sandbox payment. Return to GainPath and check status: only independently verified payment confirms. Verify the same confirmed booking in Member, assigned Coach and Admin, with matching amount/time/branch.
3. Replay the signed callback and retry status reads; observe one payment event/confirmation, no duplicate booking. Tampered signature, identity or amount must fail without confirmation. Redirect success alone must do nothing.
4. Complete payment after genuine expiry, cancellation or a conflicting replacement reservation. Observe paid reconciliation state, unchanged replacement locks and no refund claim. Do not edit timestamps to shorten the wait.
5. Exercise provider timeout/lag, double taps, background/resume and account switch. Show useful pending/error states; reject unrelated users and never expose credentials or private provider payloads.

APK installation requires exact-artifact approval, matching installed signing identity and backup of existing APK/private data; update in place without clearing data. Build includes the owner's preserved uncommitted mobile work and is not represented as a clean-HEAD artifact.

Built Firebase debug APK: `build/billplz-sandbox/gainpath-billplz-sandbox-firebase-debug.apk`. SHA256: `f72194f7db18281ff5901a4cdf78bd0b3265d07ccb82ca9008b11ec550a89dcc`. APK signature verification passed; certificate SHA256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450` matches the previously installed chat-fix artifact. Installation has not occurred; actual installed signature must be rechecked before updating.
