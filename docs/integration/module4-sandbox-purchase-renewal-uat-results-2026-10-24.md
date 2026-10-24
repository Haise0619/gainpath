# Membership Sandbox purchase and renewal — execution results

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

24 October 2026 · Asia/Kuala_Lumpur · Firebase `gainpath-0619` · Organization `gainpath`.

**The three approved Sandbox purchases/renewal completed successfully.** The owner approved the [exact financial scope](module4-sandbox-purchase-renewal-uat-2026-10-24.md) by replying “proceed”. Exactly **three creation attempts, three distinct bills and three successful hosted simulator payments**, totaling **MYR307.00** (8,900 + 8,900 + 12,900 minor units), were used. No replacement bill, provider reconciliation command, Admin financial mutation, refund or production-money operation was executed.

## Verified financial results

| Scenario | Existing test Member UID | Bill ID | Amount | Server clearance, MYT | Verified expiry, MYT |
|---|---|---|---|---|---|
| Free → Basic | `member-a-uid-redacted` | `basic-purchase-bill-id-redacted` | RM89.00 | 24 Oct 2026 10:31:02.211 | 23 Nov 2026 10:31:02.211 |
| Basic manual renewal | Same Member | `basic-renewal-bill-id-redacted` | RM89.00 | 24 Oct 2026 10:33:08.462 | **23 Dec 2026 10:31:02.211** |
| Free → Premium | `member-b-uid-redacted` | `premium-purchase-bill-id-redacted` | RM129.00 | 24 Oct 2026 10:35:39.591 | 23 Nov 2026 10:35:39.591 |

Both existing disposable identities were active, enabled, email-verified and effectively Free before purchase. Their exact emails and previously authorized fixture provenance are in the approved scope. No account was created, reverified, reset, granted a role or directly edited. Existing credentials and the already-registered App Check context were reused. Normal sign-ins can update Auth login metadata.

All three payments used collection `cd9oovf8`, organization reference `gainpath`, and HTTPS Billplz Sandbox hosted checkout. The provider receipts independently displayed **PAID**, the expected amount, membership description and exact transaction reference. The provider paid timestamps were 10:30:50, 10:33:03 and 10:35:36 MYT; these differ from persisted server settlement times and were not substituted into expiry calculations.

Every transaction became `paymentStatus: cleared`, `fulfilmentStatus: confirmed`, `invoiceStatus: paid`. All three genuine signed paid callbacks have a processed inbox entry under `system/paymentIngress/events`. The existing ingress independently fetches and verifies bill ID, collection, amount, paid amount and references before settlement. All three settlements occurred **before any explicit Member/Admin provider reconciliation**, so this run demonstrates callback-driven activation rather than redirect-driven success. The neutral return page continued to say that it does not confirm payment or activation.

The exact stored kinds are `MembershipPurchase`, `MembershipRenewal`, `MembershipPurchase`. Their server-owned records contain the approved plan versions and foundation benefits, with no booking, branch or Coach association. Each transaction has exactly one logical `membership_activated` audit event.

## Renewal and account isolation

The initial Basic term satisfies `E1 = C1 + 2,592,000,000 ms`. Renewal satisfies `E2 = max(C2, E1) + 2,592,000,000 ms`; because C2 was before E1, **E2 − E1 = exactly 30 days**, and **E2 − C1 = exactly 60 days**. The approximately two minutes of elapsed time between purchase and renewal were retained; the term was not restarted from the renewal payment time.

Premium was purchased only on the separate eligible Free Member. No active Basic-to-Premium conversion was attempted. Member A remained Basic with the same renewed expiry after Member B's Premium payment. Authenticated overviews returned two membership payments for A and one for B; all projected transaction owners matched their authenticated Member. Pending transactions did not activate membership. Both current accounts retain `autoRenew: false`; recurring billing remains unavailable. Paid terms are organization-wide and are not restricted to a branch.

The same immutable create request was replayed once per clean checkout, before simulator completion. Each replay returned the original transaction, bill and checkout URL, and no fourth bill or transaction appeared. No live forged/duplicate webhook or deliberately failed/late payment was sent. Failure, ambiguity, callback replay and concurrent settlement/renewal coverage remains the separately identified local/emulator evidence from preapproval; it is not relabelled as new live-provider coverage.

## Invoice and Admin evidence

The production shared `membershipInvoice` renderer was exercised with the actual three cleared records. It rendered the correct invoice identity, member, organization, kind, plan, provider bill, payment amount and paid status, with an explicit Sandbox/no-real-money statement. The corresponding three pending snapshots were rejected by the same renderer. The original Basic purchase and renewal remain separate paid history entries.

The owner's existing Admin sign-in was reused in the existing payment/refund management screen. The current local Admin UI shows all three records as membership purchase/renewal, their approved plans, **Organization-wide** scope, exact amounts and **Cleared · Confirmed**, together with activation audit history. No Verify payment, refund decision, transfer or recovery control was executed. Membership refund execution remains unavailable; approval is not represented as money returned.

The local browser initially served an old cached Admin bundle with booking-only labels. A local rebuild of the existing Admin application succeeded, and the current bundle was served on loopback port 7359. Its SHA-256 is `55fd0ff0386d8d4c64170161f5fbba7acc8c2033cf04277779ae4dee3f4a6266`. A versioned local URL bypassed the stale document/asset cache while preserving the existing Admin session. This was a local build/server change, **not a Hosting or Functions deployment**. The test server remains bound to 127.0.0.1.

Android PDF save/view with these paid fixtures was **not** exercised: the approved scope preserved the real Xiaomi Member session and excluded device account switching. The earlier installed APK and its accepted read-only Dashboard/Plan List UAT remain unchanged. Invoice content/history is verified here; a future paid-fixture Xiaomi PDF interaction must be reported separately.

## Preservation checks

Read-only before/after comparison found:

- All **14 pre-existing Booking documents**, **10 pre-existing transaction documents** and **one Coach Earnings document** unchanged by canonical data hash. Transaction count increased from10 to13 solely by the three approved membership payments; no Booking or earnings record was added.
- The two test Members' existing user/organization-membership documents, Basic/Premium catalogue, booking settings and absent access/reward/voucher policy documents unchanged. The new membership accounts and financial records were written only by the deployed trusted payment infrastructure.
- All **57 Function revisions/update times**, Firestore/Storage Rules release metadata, indexes and Hosting metadata unchanged. The rewards command remains undeployed, with no new policy activation or module restriction.
- No reservation/availability command, Coach earnings-recognition command, AI command, Google integration command, APK installation or device account switch was performed. Unchanged Booking data and unchanged Function/policy configuration support preserving the Google trigger path; no new live Google/Gmail/Calendar E2E run or exhaustive external-system snapshot is claimed.

The provider's existing collection title still says **GAINPATH COACH BOOKING - SANDBOX**. Bill descriptions correctly say **Membership: Basic/Premium**, references point to membership transactions, and Admin/Firestore kinds distinguish membership. The shared provider title was not changed because provider configuration changes were outside approval.

The unresolved Billplz HTTP422 refund issue and historical overview maxInstances=20 exception remain separate and unchanged. No automatic refund, refund retry, membership reset, transaction deletion, direct financial patch, catalogue/promo write, billing/service purchase, deployment or frozen workout/pose change occurred. Paid test history and the resulting Basic/Premium terms are retained.

## Evidence and limits

- `build/module4/financial-uat-live-result.json`: three successful payments, bill/transaction identities, clearance/expiry and unchanged unrelated state.
- `build/module4/financial-uat-final-verification.json`: final approval ceilings, invoice checks, all three saved Admin membership detail checks, expiry arithmetic and preservation assertions passed at 10:44:30 MYT.
- `build/module4/financial-uat-callback-evidence.json`: one genuine processed paid callback per bill; no synthetic live callback or recovery command.
- `build/module4/financial-uat-invoice-evidence.json`: three real cleared invoice renders, three pending invoice denials; Android PDF interaction explicitly untested.
- `build/module4/financial-uat-compatibility-check.json`: unchanged57 Functions, Rules, indexes, Hosting and disabled/unpublished policy gates.
- `build/module4/private/membership-financial-uat-20261024/journal.json`: approval-bound immutable requests, quotes, reservation-before-create journal, pending/cleared/account/history snapshots, same-request replay and before/after hashes. No bearer tokens or passwords are written by this harness.
- Private screenshots/text under that directory: all three provider paid receipts and current Admin membership review evidence. These contain test identity/contact information and remain local.
- Preapproval regression evidence: **87 deployed-source tests passed**, two undeployed voucher cases explicitly excluded, plus **five local Firestore emulator tests passed**. These are previous focused checks attached to this run's approval, not additional live financial transactions.

The approved purchase/renewal financial scope is complete. Refund transfer testing, additional/replacement bills, Premium conversion, future benefit/policy activation, paid-fixture Xiaomi testing and cloud publication require their own explicit scope. No further financial action is scheduled or implied.
