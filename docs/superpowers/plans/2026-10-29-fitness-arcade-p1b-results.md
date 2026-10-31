# P1B first delivery: game-first results

Scope: ship the next bounded Member-facing slice of approved P1B: consistent Reach & Tap results, honest new-record feedback for both games, local save retry for Move & Catch, and quick replay with existing consent. Preserve all engines, camera consent, timing/participation contracts, account isolation and held policies. The subsequent P1B mode-entry consolidation remains a distinct follow-up; do not imply it ships in this slice.

1. Add failing tests for new-record unknown/tie/save-failure/reset and results layout/save/replay.
2. Snapshot known pre-round PB in each controller; celebrate only strictly higher successfully persisted results. Unknown previous best never celebrates. Retry same completed score without starting/rewarding another round.
3. Reuse the existing game-first result panel for Reach & Tap with hits, separate inactive Reward Points, save/retry, quick Play again and collapsed local history. Keep Move & Catch metrics and confirmed reward widget.
4. Focused full affected suite, analysis, architecture, Android build, scoped review and verified in-place Xiaomi update under standing authority. No Firebase mutation or earning activation.

Acceptance: readable at320px/2x; score/hits/PB distinct from Reward Points; no false record, no duplicate save/claim, replay clears record and goes to alignment, account changes reject late results. No unavailable leaderboard action.
