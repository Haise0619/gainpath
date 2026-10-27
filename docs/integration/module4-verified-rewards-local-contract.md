# Verified physical rewards — local implementation contract

23 October 2026. This is the Task 2 source contract from the remaining three-tier roadmap. No configuration, event producer, stock, exchange rate, account, deployed Function or Rules has been published. No prototype points are migrated. The synthetic values in tests are test fixtures only.

## 26 October local journey extension

The owner selected and separately approved deployment/activation of Basic/Premium redemption, persistent My Rewards with snapshotted details/conditions/expiry and QR/manual reference, Admin scan-to-inspect then explicit collection confirmation, and no refund/restock for unused expiry. New publication and history/voucher paths, exact price/publication revision consent, QR rendering/scanning and current-session guards are active after exact two-Function/private Admin/Xiaomi approval. Existing 50-point app check-in balances are reused; no earning producer/rate/stock is invented. This supersedes the earlier latest-50 UI limitation with owner-scoped 25-document history pages. New rich vouchers have per-item 1–365-day validity; legacy vouchers keep unknown expiry. See STATUS and build/module3-reward-journey-20261026/release-review.json for exact artifacts, checks, deployed source/installed/served hashes and remaining UAT boundaries. No live central rate/stock was populated. Historical Premium earning and Coach vouchers remain held.

## Integration and callable

Export `verifiedRewardsCommand` from `functions/src/modules/gamification/verified-rewards-callables.ts` through the root Functions entry point. It is one App Check-enforced callable and also explicitly checks `request.app`, verified Auth, current Auth user status, current organization membership, lifecycle and session revocation. Set `VERIFIED_REWARDS_ORGANIZATION_ID` explicitly at any future authorized deployment; its empty default disables access. No deployment is included here.

Input is an exact object; unknown fields are rejected. Every action contains `schemaVersion: 1`, `organizationId` and `action`:

| Action | Additional input | Authority and result |
|---|---|---|
| `overview` | None | Current verified Member. Returns the owner-scoped snapshot below. |
| `award` | `eventId` | Current verified Member, owner-scoped persisted trusted event. Returns `{schemaVersion:1, award}`. |
| `redeem` | `itemId`, `requestId` | Current verified Basic/Premium Member for a new redemption; Premium required for exclusive items. Returns `{schemaVersion:1, redemption}`. |
| `inspect` | `redemptionId` | Current verified active Admin in the same organization. Read-only current receipt lookup; no debit or fulfilment. |
| `fulfil` | `redemptionId` | Current verified active Admin in the same organization. Returns `{schemaVersion:1, redemption}`; repeats return the existing fulfilment. |

Identifiers use 1–128 letters, numbers, underscores or hyphens. Inputs never contain a member ID, tier, balance, points, score, time, stock or price. App/organization/account authority is checked again on retries and duplicate commands. Auth service lookups occur outside retryable Firestore transactions.

Overview: `{schemaVersion:1, organizationId, memberId, available, policyVersion:string|null, balance:integer|null, effectiveTier:'free'|'basic'|'premium'|null, canRedeem:boolean, items:[], redemptions:[], resolvedAtMillis}`. An absent verified ledger has a null balance, rather than a manufactured initial balance. Missing or malformed policy returns unavailable with an empty catalogue, retains any existing verified balance and recent issued vouchers, and denies new awards/redemptions. Unknown entitlement never permits redemption.

Each public item contains `{itemId,title,pointCost,stock,premiumOnly}`. Each redemption contains `{schemaVersion:1,organizationId,memberId,redemptionId,requestId,itemId,title,points,status:'issued'|'fulfilled',issuedAtMillis,policyVersion,exchangeRateVersion}` and, after fulfilment, `{fulfilledBy,fulfilledAtMillis}`. The server snapshots cost/title/rate/policy when issued. An issued physical reward remains fulfilable after membership expiry or catalogue retirement; fulfilment validates its stored evidence and current Admin authority, without requiring a currently enabled earning/catalogue policy. It never issues another reward or charges points again.

An award contains `{schemaVersion:1,organizationId,memberId,eventId,awardId,sourceId,producerVersion,policyVersion,occurredAtMillis,awardedAtMillis,basePoints,points,premiumBonus,tierEvidence,membershipTransactionId}`. Base-only awards explicitly record `tierEvidence:'unverified_or_not_premium_base_only'` and a null membership transaction ID. Successful historical Premium proof records `verified_historical_premium` and the proved transaction ID.

## Trusted configuration and event evidence

All paths are under `orgs/{organizationId}` and remain inaccessible directly under the existing Rules. No Rules changes were made.

`rewardPolicies/current` must explicitly contain:

- `schemaVersion:1`, matching `organizationId`, unique `version`, `enabled:true`, and valid `effectiveFromMillis`/`effectiveUntilMillis` covering both current award processing and the event earning time.
- A valid IANA `timezone`, and `unknownHistoricalTier:'base_only'`. Base-only treatment is an explicit policy choice, not an inferred paid tier. If this choice is absent, operations requiring policy are unavailable.
- `exchangeRate:{version,currency:'MYR',pointsPerUnit,unitValueMinor}` with positive safe integers. No rate is supplied by implementation. Every item's conversion must satisfy the exact integer equality `valueMinor * pointsPerUnit == pointCost * unitValueMinor`. This preserves a uniform configured conversion and introduces no rounding policy.
- `itemIds`: distinct configured identifiers, at most 100; `sources`: at most 50 distinct source entries. An empty list enables no source/item. Every source explicitly provides `{sourceId,producerVersion,basePoints,maxEventAgeMillis,dailyEvents,dailyAwardPoints}`, with positive safe integers and multiplication-safe points. Caps apply per owner/source/earning day and include the Premium bonus. A policy version edit does not reset the daily cap.

`rewardItems/{itemId}` must contain `{schemaVersion:1,organizationId,itemId,title,active:true,pointCost,valueMinor,stock,premiumOnly,exchangeRateVersion}`. Cost/value are positive safe integers; stock is a nonnegative safe integer; `premiumOnly` is an explicit boolean. Metadata-only `rewardCatalog` draft/archived records are never interpreted as spendable stock.

`rewardEvents/{eventId}` must be created by a separately reviewed trusted producer and contain `{schemaVersion:1,organizationId,memberId,eventId,sourceId,producerVersion,rewardPolicyVersion,verification:'trusted',occurredAtMillis,recordedAtMillis,membershipTransactionId?}`. The source and producer must match the configured source entry; the event policy version must match the active configured policy. `occurredAtMillis` must be trustworthy producer time, within policy boundaries, no later than the trusted recorded time/current processing time and within the configured maximum age. Reusing raw client workout timestamps, game scores, local check-in flags, fixtures, or merely a workout upload's server acceptance time is not an eligible producer implementation.

No producer is enabled or created by this change. A future source needs a reviewed source-specific verification procedure and business-approved amounts/caps/timezone before any receipt can be written. Old-policy events are rejected rather than silently repriced using a new version.

Historical Premium proof follows the event's trusted `membershipTransactionId` to the existing immutable cleared membership transaction. It validates matching organization/owner/transaction identity, supported membership kind, sandbox Billplz/MYR cleared/confirmed evidence, positive amount, bill/collection/name, bounded duration and timestamps. The paid grant interval is `[expiresAtMillis-durationDays*86400000, expiresAtMillis)`, with payment clearance no later than its start. The event must lie inside that interval. Early-renewal future time cannot apply to an earlier event. Current/latest account state alone is never proof of a historical bonus. If proof is absent or invalid, the explicitly configured base-only policy records no Premium bonus. Bonus arithmetic is integer `floor(basePoints*3/2)` and never modifies an existing balance retroactively.

`rewardAwards` uses a deterministic owner/event key; `rewardCaps` uses owner/source/timezone/earning date; `rewardBalances` preserves the verified points and a bounded index of the most recent 50 redemption IDs; `rewardRedemptions` retains every issued/fulfilled document. Award, cap and balance writes share one transaction. Debit, stock and issue share one transaction. Balances and all ledger records survive expiry. The recent UI index dropping an old ID does not delete history. Full historical paging/report aggregation is a remaining separate reader; this first UI shows the latest 50 records.

## Flutter integration

`gainpath_domain/gamification.dart` exports typed `VerifiedRewardsRepository`, `VerifiedRewardsSnapshot`, `VerifiedRewardItem` and `VerifiedRewardRedemption`. `FirebaseVerifiedRewardsRepository` in `apps/mobile/lib/infrastructure/firebase/firebase_verified_rewards_repository.dart` uses `BookingTransport`, `SessionScope`, `isCurrent`, optional `currentUid`/injected `BookingCallable`, and `FirebaseAppCheckReadiness`. It checks account/organization ownership of parsed data, rejects late responses after logout/account switching, and has no cached money fallback.

`RewardShopScreen(connected:true)` uses `RewardsFeatureHost` to capture the current Auth session and construct that repository. It also accepts an explicit `repository` for injection/testing, retaining the existing mock presentation. The connected shop shows actual null/unavailable/empty/Free/unknown states, validated real stock/cost, Premium labels and recent server-issued redemptions. Mutation errors display an uncertain result. `RewardRedemptionIntents` persists only the owner/item/request references in app-private support storage and serializes access across repository instances. A recreated repository reuses the unresolved request; only a validated, owner-bound server receipt clears the matching intent. Invalid/partial storage fails closed rather than creating a new debit. No amount, points or entitlement is trusted from this file. Clearing application data/uninstalling removes local recovery hints; server receipts/idempotency remain authoritative. `VoucherScreen` accepts the real redemption plus repository, displays its server reference/status and is guarded on Auth changes. Its displayed status is a server snapshot; staff must verify current server status before fulfilment. It does not generate a fake QR/code. A full paged historical viewer remains outside this first reader.

The existing Admin Reward Catalogue now opens a voucher verification panel through the existing scoped Member-directory repository capability. `inspect` reads the current server receipt without mutation; a separate explicit action records once-only fulfilment, and fulfilled receipts warn against issuing again. Account changes hide the prior receipt. No separate dashboard, stock publication interface or new Rules access is added. Physical desk/device UAT remains pending.

## Local verification

- Focused backend: `pnpm exec vitest run test/verified-rewards.test.ts test/verified-rewards-callables.test.ts`: 44 passed in the final combined selection. Covers historical tier boundaries, early renewal, no retroactive bonus, malformed/missing policy/evidence, current Auth/lifecycle, client authority rejection, same-event duplicates, timezone caps and policy edits, bonus-inclusive cap, Free/Premium eligibility, idempotency, competing last balance/stock, read-only Admin inspection and once-only Admin fulfilment.
- Source/test typechecks: `pnpm exec tsc --noEmit` and `pnpm exec tsc -p tsconfig.test.json --noEmit`: passed at the final local Task 2 verification.
- Focused Flutter: rewards screens (3), repository (7) and persisted intents (3): 13 passed in the final mobile selection. Admin fulfilment panel: 2 passed in the Admin selection. Targeted analysis passed with no issues.
- `functions/emulator/verified-rewards.test.ts`: 2 passed in the final combined 9-test emulator run: real retry contention (duplicate awards, last stock and repeated fulfilment), and existing Rules rejecting Member/Admin direct read/write bypasses. The final local configuration uses loopback ports 62241/62242/62243 in `build/module4/remaining.emulator.test.json`; each suite refuses non-loopback endpoints before initialization or fixture cleanup.

No full suite, deployment, live data write, device installation, real-finance test, or reward source acceptance is claimed here.
