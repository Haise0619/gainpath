# Earned points leaderboard implementation plan

**Goal:** Weekly/all-time top20 and the signed-in Member's own rank, using genuine earned points. Reuse GainPath purple presentation. Manual credits, spending and old demo credits never change ranking.

**Execution:** Direct continuation in the existing checkout, preserving unrelated work; no commits, cleanup or worktree copying. Use focused TDD and one scoped independent review. The owner opted for direct implementation.

**Design:** Read-only action on existing verifiedRewardsCommand. Paginate bounded same-organization active Member receipts: check-in, spendable participation and known workout/game awards. Validate persisted receipts with existing validators. Monday00:00 Asia/Kuala_Lumpur week; competition ranking for ties, deterministic internal ordering. Return display names, ranks, earned totals and self markers, without emails/UIDs/private histories. Top20 plus own rank even outside the list. Unknown/no earnings renders unranked, not invented ranks. No materialized data, earning-policy changes, Rules/indexes or new Function required.

## Tasks

- [x] Backend: functions/src/modules/gamification/earned-points-leaderboard.ts plus callable dispatch; tests for periods, ties, receipt validation, canonical scope, concurrency, pagination and excluded credits/spending.
- [x] Contract/transport: shared earned_points_leaderboard.dart, VerifiedRewardsRepository read and guarded Firebase transport; parse ownership, totals, own row, periods and bounds.
- [x] UI: replace connected placeholders with real rankings; preserve legacy injected prototype, add loading/retry/refresh/self/empty states and narrow-screen tests; connect Rewards, live legacy dashboard and Home Ranking routes.
- [x] Verify affected tests/analysis/builds and independent review; prepare source-only update and signed APK, update six operational references. Request exact release approval only after concrete artifacts exist; no cloud/device activation under local implementation scope.

## Review focus

No manual/test or redeemed balance influence; no cross-organization/session disclosure; corrupt or incomplete scans must not return misleading partial rankings; weekly Malaysia boundary and tied ranks; Member outside top20 and stale responses after switching periods/accounts.

## Completion evidence

- 68 focused checks pass: 50 backend,17 Member and one connected-screen compatibility check. Analysis, backend source/test compilation, architecture and signed Android profile build pass. Independent scoped review found no actionable issues.
- Source-only package changes the existing callable dispatch and adds only the leaderboard module. All other deployed package bytes are preserved, including the history-only participation validator's inert flag; the separate live game earning service is untouched.
- Evidence: build/earned-points-leaderboard-20261027/. No cloud/device activation, data migration, reward policy/points/stock/voucher or Admin change.
- A broader auxiliary screen run independently reproduced its older Redeem points title expectation failure. That screen/source was not changed; only the affected Leaderboard compatibility case is reported passing.

## Owner-approved release complete

- Owner answered **Approve Leaderboard release**. The exact existing verifiedRewardsCommand source-only update is active with source hash/runtime/environment/IAM verified. All68 other Functions, Rules/indexes, Admin and earning configuration remain unchanged; anonymous leaderboard request returns401.
- Exact signed APK installed/launched in place on Xiaomi7c4cbff with hash/signer/UID/data directory/first-install verification and previous APK retained. No point transactions, data migration, initialization or production test claims. Signed-in/device acceptance remains pending.
