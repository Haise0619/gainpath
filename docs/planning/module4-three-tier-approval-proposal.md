# Three-tier membership — separate approval proposal

**Status: proposal only.** Read with the [Phase 0 audit](module4-three-tier-phase0-audit.md) and [user Draft 1.0](module4-three-tier-policy-draft1.md). No implementation or cloud change is authorized by these documents.

## Product decisions to confirm

Free is a derived entitlement for eligible verified Members without active paid time, with no paid checkout/expiry. Basic/Premium remain organization-wide paid memberships. Prices RM49/RM89 and 30-day terms remain proposed. Role, suspension, identity and organization authorization remain separate. Expiry preserves the previous paid facts and all account-owned data/bookings. Manual renewal preserves remaining time; recurring billing and active cross-tier conversion remain unavailable.

The new exercise/report/reward gates, Premium 1.5× and one 10%-up-to-RM15 coaching voucher are selected product directions whose detailed mechanisms remain unapproved. The exact Free whitelist/history limits, staff admission exceptions, reward earning/stock rules and discount funding/commission rules must be resolved at their respective phase gates. Existing account access is unchanged now.

## Proposed next implementation scope — Phase 1 only

If separately authorized, implement and locally test:

1. Shared server-side effective entitlement resolution: eligible Free, active Basic/Premium, expired paid-to-Free with retained facts, and distinct unauthorized/unknown states.
2. Domain/repository/read projection and the existing shared membership comparison/dashboard. Reuse paid checkout, renewal, history/invoice and refund-request behavior.
3. Identity/account isolation, authoritative expiry and backward compatibility tests. Preserve current organization/branch authority, Rules, financial history, frozen workout/pose code and existing Booking/AI/Google flows.

Exclude from Phase 1 authorization: exercise/report locks, staff verification workflow, points/reward changes, coach vouchers/commission changes, automatic recurring billing, refund transfers, catalogue writes, Member account edits, cloud deployment, APK installation and financial UAT.

Phase 1 implementation approval would authorize local application changes and focused tests **only**. No deployment or catalogue activation is bundled. A concrete diff, test evidence and exact selective deployment/data proposal must be reviewed afterward.

## Later independent gates

| Gate | Required before work/operation |
|---|---|
| Phase 2 implementation | Exact validated Free exercise IDs, history/report rules, staff authority/admission policy; reviewed access/data design; preserve complete safety feedback. |
| Phase 3 implementation | Verified points-event/time/cap policy; operational reward cost/stock/redemption design; uniform conversion and concurrency protections. |
| Phase 4 implementation | Discount funding/commission, rounding, cycle/expiry/stacking and cancellation/refund/reinstatement approval. Existing paid-booking guarantees must be preserved. |
| Catalogue/data changes | Approved exact paid-plan records and available benefits, target paths/preconditions, readback/rollback; no zero-MYR Free plan. Approval must specify staging vs activation and organization-wide visibility. |
| Rules/index/deployment | Concrete reviewed changes and selective target list, preservation check and rollback; no broad deployment from a dirty checkout. |
| Device/financial UAT | Explicit test accounts/scope and installation approval; Sandbox actions separately specified; no real payments/refunds or widened Google automation scope. |

The previous two-tier JSON remains historical and must not be applied as approval for this three-tier roadmap. No operational script or current catalogue payload is introduced here.
