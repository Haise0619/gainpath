# Unified points history implementation plan

> Execute inline with executing-plans and focused TDD. The owner requested direct completion in the existing working checkout; preserve unrelated uncommitted work, with no worktree copying, commits or cleanup.

**Goal:** Complete the existing participation journey with a single filterable Points History for all recorded point activity.

**Architecture:** Extend the existing protected history command to read immutable participation receipts alongside check-ins, awards, manual credits and redemptions. Following the owner's explicit follow-up, new game credits use the existing spendable rewardBalances wallet. Keep historical demo records immutable, without a data migration. Reuse current consent, timing, claim/retry and daily-limit services.

**Spec:** Owner confirmed “Yes, use one spendable balance” and requested removal of Demo/not-redeemable labels and explanations. Mini-game policy defaults: 20 points, one per game/day, shared 60/day in Asia/Kuala_Lumpur. Camera/pose/score stay local. Check-in50/day and held Workout/Premium/Stage B/C remain independent. Production issuance stays disabled until separate release approval. Prepare a concrete source-only activation candidate; no cloud/device mutation now.

## Tasks

- [x] Backend: v2 participation credits rewardBalances atomically with immutable receipt and shared/per-game counters. v1 clients stay held; existing demo records are preserved. Add unified read while preserving installed legacy history contracts.
- [x] Shared contract/UI: one balance, All/Earned/Spent and source filters, concise result messages, empty/error/retry/session states.
- [x] Journey: completed-round checking → automatic award/retry → same history → existing redemption; returning from games refreshes Rewards balance.
- [x] Affected tests, analysis/typechecks, architecture, signed APK and private Admin build; independent review and operational references updated.

## Review focus

Foreign/malformed receipts must never render; historical demo credits must not be silently migrated; session changes must hide private rows; prior receipts remain valid after spending; concurrent balance changes force refresh.

## Ledger

- Started: reused existing checkout per the owner's direct-continuation request. No source gate activation or redemption-policy change.
- Owner clarification supersedes the earlier demo-only policy for future v2 mini-game credits. UI removes wallet classification and long explanations. No historical balance migration.
- Verification: 195 affected checks passed (127 backend, 48 Member, nine Admin, five domain, three data, three isolated Firestore emulator); analysis/typechecks and architecture passed. Android profile and private Admin release builds succeeded. The first sandboxed emulator hub attempt timed out; the elevated isolated local retry passed.
- Independent review: one P2 historical receipt wording finding reproduced RED, corrected and verified GREEN; no other actionable findings. Full Member suite48 passed after the fix.
- Release candidate: build/unified-points-20261027/*-final.zip only. The miniGameRewardsCommand archive deliberately sets the participation-only release gate true; workspace source and live service remain false. verifiedRewardsCommand adds read-only unified history. No other source gate, earning policy, data, Rules/indexes/IAM, Hosting or installed artifact changed.
- The initial unsuffixed archives were prepared before the first-wallet compatibility fix and are superseded; preserve them as intermediate evidence, never release them.

## Owner-approved release completion

- Owner answered **Approve unified points release**. Exact two source-only updates are active with source/runtime/environment/IAM verified. All67 other Functions, Rules/indexes/config remain unchanged. Both anonymous calls reject401.
- Private Admin served hashes verified; loopback server restarted because it was stopped. Xiaomi installation/launch verified against approved APK hash/signature, preserving UID/data directory/first-install time and retaining previous APK.
- Workspace participation gate now true under this approval. An additional v2 callable regression passed, with34 affected participation/callable checks and fresh test typecheck (196 total unique checks including preparation). No production test claim or data migration was performed.
