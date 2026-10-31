# Fitness Arcade P1A implementation

Approved Member-first direction and final mode/competition-privacy adjustments are in docs/planning/gamification-complete-user-journey.md. P1A is the hub slice, not all of P1 or P2.

- [x] Test and implement managed Move & Catch/Reach & Tap compact cards with scoped local PBs and actual participation overview (read-only). Unknown status stays unknown, Reach rewards inactive. Coalesce requests, refresh on returning, reject late foreign-session results.
- [x] Replace long Rewards dashboard with wallet, existing compact daily claim, near-top games, compact explicitly earned-points weekly rank, shop and secondary navigation. Move only real check-in badges to a secondary view. Keep history and My Rewards reachable; no duplicate ledger or fake goal.
- [x] Focused test-first cases, affected game/check-in/reward/navigation suite, strict analysis/architecture, scoped review and signed Android build. Use standing in-place Xiaomi release authority if verified and no active unsaved camera game. No backend/Admin/content/account/reward mutation.

Interfaces: FitnessArcadeHost(onReturn: Future<void> Function()) renders FitnessArcadeGames; FitnessArcadeGames accepts optional MiniGameContentReader reader, MoveCatchBestScoreStore bestScoreStore, ReachTapHistoryStore reachTapHistory, MiniGameParticipationRepository participation, and required onReturn. FitnessArcadeRank accepts optional VerifiedRewardsRepository repository and required VoidCallback onTap; FitnessArcadeRankHost wraps existing RewardsFeatureHost for actual authenticated composition. Root owns dashboard/composition/badge-secondary and tests; delegated implementer owns new arcade-games and rank widgets/tests. No game-engine changes.

Preserve current checkout/unrelated work and all data. Direct SDK tools, read-only remote operations only, no clean/reset/stage/commit. Evidence build/fitness-arcade-p1a-20261029.


Completed29October:381affected tests/five existing skips, strict analysis/architecture, scoped independent review and signed Android build; exact standing-authorized in-place Xiaomi installation/launch preserves installed hash/signer/app data/identity/previous APK. No backend/Admin/data or earning-policy mutation. Visual fixture inspected; signed-in physical acceptance pending. See private release-verification.json.
