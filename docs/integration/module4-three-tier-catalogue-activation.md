# Membership Catalogue — approved activation completed

23 October 2026 · Firebase project `gainpath-0619` · Organization `gainpath`.

After verified inactive staging, the owner explicitly approved the separate activation gate. Both existing documents were atomically updated at **`2026-10-23T14:20:31.128634Z`** (22:20 Malaysia time). Only `active` changed from false to true.

| Record | Price | Duration | Version | Readback |
|---|---:|---|---|---|
| `orgs/gainpath/membershipPlans/basic` | **RM89 / 8900 sen** | 30 × 24 hours | `basic-three-tier-uat-v1` | `active:true` |
| `orgs/gainpath/membershipPlans/premium` | **RM129 / 12900 sen** | 30 × 24 hours | `premium-three-tier-uat-v1` | `active:true` |

Membership remains organization-wide. Both approved foundation benefit arrays, names, prices, currencies, durations and versions are unchanged from staging. No branch restriction, recurring billing, reward/voucher policy or new module restriction was introduced. Free remains derived with no plan document or payment.

## Fresh verification

- Read-only preflight confirmed the organization is active, both complete records match the staged canonical digests and both update times still equal `2026-10-23T14:05:39.629068Z`.
- Local request validation confirmed exactly two writes, `updateMask.fieldPaths:['active']`, `active:true` and the original update-time precondition on each existing document. The write tool rejects all other changes and refuses blind resend after an activation attempt.
- The Firestore transaction reread the organization and both documents, then committed the two masked updates atomically. The organization record was not modified.
- Full readback matches each original staged record with only `active:true`. Original create times are preserved, both update times match the commit receipt and share the same atomic update time.
- Using the actual deployed Stage A payment code locally against the readback values, both records pass validation and quote **8900/12900 sen, MYR, 30 days** with their correct versions. These were in-memory quote checks, not authenticated live calls, Member reads or provider payments.

Canonical activated-record SHA-256 digests:

- Basic: `3689b101fc94e701df3d4d0e3976397f2f7793587f0ca6a19aabaef5ad7995c0`.
- Premium: `623c49e3a4e0f61fd012a4885730b0ec438bd62e5f27627238a8003bbb14a523`.

Evidence under `build/module4/`:

- `catalogue-activation-proposal.json` — separately approved masked writes; SHA-256 `50c8170de24977f4538a231e9fa5ed875692a9d474bff68f9260525f3d9585a9`.
- `catalogue-activation-preflight.json` — complete original values and update-time comparison.
- `catalogue-activation-commit-request.json`, `catalogue-activation-commit-result.json` — exact writes and transaction receipt.
- `catalogue-activation-readback.json` — complete activated values, timestamps, canonical digests and deployed-code local quotes.
- `activate-catalogue.cjs` — bounded validation/preflight/activation/readback tool. Do not remove attempt evidence to force another mutation.

The staging JSON in `docs/integration/module4-three-tier-catalogue-proposal.json` and its earlier readback remain immutable historical inactive snapshots. Their `active:false` fields describe approved staging, not the current live catalogue. This activation record and its readback supersede that live-status statement without changing past evidence.

## Current scope and next gate

The catalogue is enabled for the existing Billplz **Sandbox** Membership flow. Live authenticated overview/quote, device display, purchase, renewal and financial UAT have not been performed. Catalogue activation does not establish end-to-end payment acceptance or activate the pending Premium reward/discount/report policies.

No Member account/subscription changes, payment creation, refund execution, provider calls, promo/feature-policy writes, Functions/Rules/indexes/Hosting deployment or APK installation were performed. Automatic recurring billing remains unavailable. Existing paid Coaching Bookings, accounts and financial receipts were not modified. The Billplz HTTP 422 refund-transfer issue remains separate.

Next is separately scoped authenticated/read-only UAT and, if desired, explicit Xiaomi installation approval. Sandbox purchase/renewal/refund operations and any test-persona changes require their own explicit scope. Stage B rewards and Stage C voucher/finance deployment remain pending.

## Rollback plan — not executed

If separately authorized, re-read both complete active records and their latest update times, then atomically update only `active:false` with `updateMask:['active']` and those exact update-time preconditions. Stop on unexpected record changes. Read back both inactive documents. This disables new catalogue purchases; it does not cancel existing provider bills, reverse cleared paid time, delete invoices or alter accounts. Do not delete records or restore organization/account snapshots as catalogue rollback.
