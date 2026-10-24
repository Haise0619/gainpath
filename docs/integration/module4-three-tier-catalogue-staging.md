# Approved Membership Catalogue — inactive staging completed

23 October 2026 · Project `gainpath-0619` · Organization `gainpath`.

Subsequent status: the owner separately approved activation, and both plans are now active as recorded in `module4-three-tier-catalogue-activation.md`. The inactive values and approval gate below preserve the completed staging evidence at that time.

The owner approved the catalogue proposal and creation of the two inactive records, with the explicit revision: **Basic RM89, Premium RM129**. The approved 30-day term, foundation benefit arrays and initial versions remain unchanged. The earlier RM49/RM89 amounts were an unpublished draft, not existing paid terms being repriced.

## Verified records

| Firestore path | Name/tier | MYR price | Integer sen | Duration | Version | Active |
|---|---|---:|---:|---|---|---|
| `orgs/gainpath/membershipPlans/basic` | Basic / `basic` | 89.00 | 8900 | 30 × 24 hours | `basic-three-tier-uat-v1` | **false** |
| `orgs/gainpath/membershipPlans/premium` | Premium / `premium` | 129.00 | 12900 | 30 × 24 hours | `premium-three-tier-uat-v1` | **false** |

Both documents were created atomically at **`2026-10-23T14:05:39.629068Z`** (22:05 Malaysia time). Each readback `createTime` equals its `updateTime`; all seven record fields match the approved JSON exactly. Tier is represented by document ID. Neither record includes a branch ID, Auth role, recurring flag or authorization policy.

The foundation benefits in both approved records are:

- Organization-wide GainPath membership.
- Membership dashboard with tier, status and expiry.
- Manual renewal preserving remaining paid time.
- Membership billing history and cleared-payment PDF invoices.
- Refund request/review tracking under the existing seven-day policy.

These records do not advertise activated advanced-report/reward/voucher benefits. Those policies and commercial decisions remain separately gated. Free remains a derived entitlement with no paid-plan document, expiry or payment.

## Safety and verification evidence

1. The revised local catalogue tests were run failing against the old draft, then **all 3 passed** against the approved prices and inactive-only approval metadata.
2. The validator from the actual isolated Stage A deployed source rejects both `active:false` records. In-memory active previews quote precisely 8900/12900 sen, MYR, 30 days and the expected versions, with no writes/provider calls. No live authenticated quote or checkout was invoked.
3. Read-only preflight verified an active GainPath organization and that **both target records were absent**. No existing catalogue was overwritten.
4. One read/write Firestore transaction reread the organization and both target paths, then committed exactly two creates using `currentDocument.exists:false`. The transaction validates the organization read without updating its record. Only the seven approved plan fields were written.
5. Both complete documents were read back and canonically compared. Equal creation timestamps confirm atomic creation. The script preserves commit-request evidence before the mutation and refuses automatic resend after an uncertain outcome; separate readback is available for recovery.

Approved exact JSON: `docs/integration/module4-three-tier-catalogue-proposal.json`, SHA-256 **`dca3c5d6ed82bdfe282a650c025a2df7c12531c5adfb76f25be51382188e1e97`**. Outer approval/free/procedure metadata is local evidence and was not written to Firestore.

Canonical data digests (sorted object keys, array order preserved):

- Basic: `302b1135a186dd9e3b336d5cec8999b5a2550ecbc650081e289b12d8833bb82d`.
- Premium: `f701cdd203532871894b71aaf5bcedf20ebbd14a7f470d25bdda7e5fb58ea407`.

Evidence under `build/module4/`:

- `three-tier-catalogue-preapproval.json` — preserved unpublished draft.
- `catalogue-staging-validation.json` — approved digest and deployed-code local validation/previews.
- `catalogue-staging-preflight.json` — active organization and target absence.
- `catalogue-staging-commit-request.json`, `catalogue-staging-commit-result.json` — exact two creates and commit receipt.
- `catalogue-staging-readback.json` — full records, timestamps/digests and exact comparison.
- `stage-catalogue.cjs` — bounded validate/preflight/stage/readback tool. The write mode refuses an existing staging-attempt evidence file; do not bypass it to retry blindly.

No Functions/Rules/indexes/Hosting deployment, Member account/subscription mutation, promo/feature-policy publication, provider call, payment/refund, APK installation or UAT was performed. Automatic recurring billing remains unavailable; manual renewal is supported by the existing flow. Billplz HTTP 422 refund transfers and entitlement reversal remain unresolved separately.

## Next gate and rollback

**Activation has not been approved or performed.** Both plans remain unavailable for purchase. A later explicit activation approval would authorize only two `active:true` field updates, retaining prices, terms, benefits and versions. The local `build/module4/catalogue-activation-proposal.json` contains exact proposed writes with `updateMask:['active']` and captured update-time preconditions; it is not an executed request.

Before any later activation, recheck organization status, complete record contents/digests and current update times. Stop on unexpected changes rather than overwriting them. Commit both activation updates atomically and read them back. Activation would make these plans available to the existing Sandbox checkout; it does not authorize test-account changes, payment/refund execution or APK installation. The two currently shared benefit arrays should not be interpreted as activated Premium differentiation.

No rollback mutation is necessary now because both records are inactive. Do not delete them or alter accounts/transactions as cleanup. If a later activation needs rollback, separately authorize a preconditioned atomic `active:false` update of these same documents; this stops new sales without cancelling existing bills, deleting receipts or removing already paid membership time.
