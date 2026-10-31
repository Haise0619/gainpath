# GainPath Complete Gamification Journey

29 October 2026 · Approved Member-first Fitness Arcade direction · P1A/P1B/P1C and competition/goal/sharing implementation released; held issuance and physical acceptance remain pending

## 1. Direction and boundaries

Make the daily experience **check in → play → celebrate → compete → redeem → return**. Members should see games and achievable progress before transaction details. Keep the existing Rewards entry point; “Fitness Arcade” describes its experience, not a new navigation system or backend.

Preserve all working features, real user data, balances, immutable point receipts, voucher history, game histories, published content and existing Firebase services. Reuse current Auth/App Check, organization/ownership checks, repositories and role boundaries. The original revision was plan-only. The owner subsequently requested full implementation on29October; the release record below supersedes its implementation-only hold while preserving earning-policy holds. No migration or service replacement is introduced.

Existing foundations: daily app check-in and first/3-day/7-day badges; one spendable points wallet/history; Move & Catch participation earning; two managed playable games; earned-points rankings; reward catalog, redemption, My Rewards and Admin collection. Separate game rankings are now implemented. Reach & Tap timing/competitive integration is implemented while participation issuance remains outside the unchanged Move-only issuer. Real first/3/7 check-in badges remain the supported progression; additional definitions remain deferred rather than invented.

Current approved policies take precedence over historical Chapter 4 examples. Preserve Malaysia app-check-in days and participation rewards; do not restore historical UTC streaks, accuracy-based earning formulas or invented form metrics. Workout rewards remain disabled until separately approved and validated.

## 2. Screen hierarchy: an arcade, not a ledger

```text
Home → Rewards / Fitness Arcade
  ├─ Points wallet + Daily check-in
  ├─ Play: Move & Catch / Reach & Tap
  │    ├─ Game details + instructions
  │    ├─ Camera alignment → Ready → countdown → play → results
  │    └─ This game's leaderboard
  ├─ Compact Weekly Rank
  ├─ Compact Reward Goal (P3)
  ├─ Shop
  └─ More: Badges / My Rewards / Points History / All Leaderboards
```

These are existing or child routes, not additional bottom-navigation tabs. Keep direct access to My Rewards from a successful redemption and the hub shortcut, so collecting an issued reward is never buried.

### Primary hub, top to bottom

| Section | Member sees | Interaction |
| --- | --- | --- |
| Wallet + check-in | Confirmed spendable balance; prominent Check in +50 / Checked in today; compact seven-day strip and streak | Claim directly; small History shortcut opens secondary page |
| Play | Move & Catch and Reach & Tap cover cards near the top | Each shows personal best with its scope label, 40-second duration, actual earning status, and Play |
| Weekly Rank | One compact rank summary with an explicit context label | Prefer selected game's weekly rank once P2 exists; until then label the existing summary “Earned-points weekly rank”; never silently switch metrics |
| Reward Goal | One chosen published reward and balance-to-current-cost progress, when P3 is delivered | Open its detail; before P3 use a compact Browse rewards action, not a fake goal |
| Shortcuts | Shop, My Rewards, Badges, History, Leaderboards | Open full secondary screens |

Layout intent: wallet/check-in and the start of Play are visible immediately on a typical phone; both games are accessible within a short scroll. Use two compact cards when readable, stacked cards for narrow/large-text views. Reserve image space; keep labels concise. Do not squeeze text or hide actions just to meet an above-the-fold target.

Avoid a separate long earning-opportunities list, duplicate balance/streak panels, full standings, badge grids or recent-history tables on the hub. Do not repeat the same status in multiple sections. Load independent summaries without blocking the whole page; returning from a confirmed action refreshes only affected state. Show unavailable/last-confirmed information honestly, not fabricated zeros.

## 3. Mini-game journey

**Game Details → Instructions → Camera Alignment → Ready → 3-2-1 → Gameplay → Results.**

Instructions are a section of Game Details, not a mandatory extra confirmation page. Reuse managed cover/introduction/steps and optional preview. First-time Members can read the full guide; returning Members see a compact reminder and can reopen it. The existing explicit camera-start/consent action remains the necessary handoff to alignment; remove redundant content or confirmations, not consent safeguards. Do not change a two-second hold into a touch confirmation away from the phone.

### Choosing a mode

- **Play for Fun:** local score, hits, history and personal best; no Reward Points attempt is implied.
- **Play & Earn:** offered for a game only when server eligibility and policy allow it. Explain “Complete a round for +20 points” without making score determine points. Reuse owned server round/participation infrastructure.
- A claimed daily allowance shows “Today's reward earned · Play again for fun.” Inactive Reach & Tap shows “Rewards not active · Play for fun.” Failed eligibility reads show “Earning status unavailable” with Retry and an available fun-play option; do not advertise a guaranteed award.
- Select the mode on Details, then use one clear Play/Start camera action. Do not stack a mode-confirmation screen, earning-confirmation screen and another Play screen. Preserve existing unchecked earning consent until the Member explicitly chooses Play & Earn; Replay never silently enrolls them.
- Keep the chosen mode for the current play session and offer an inline Change action. Replay reuses that choice while checking current eligibility; if earning is exhausted, clearly offer Continue for fun without sending another claim. Do not store a permanent earn opt-in or add per-round mode dialogs.

Camera permission/consent is requested when starting camera play, not while browsing covers, details or previews. Reuse valid OS permission and established app consent according to existing controls; do not repeatedly request permission per round. Denial offers Retry/settings guidance and Back. Close preview playback before camera use.

### Competitive participation, when P2 ships

Add a separate **Include my result in this game's rankings** choice with a short privacy/trust explanation. It is independent of camera consent and Play & Earn. Remember an explicit choice for the current authenticated account and competition-policy version, with a visible way to change or withdraw it. Never inherit it across accounts or enable it by choosing an earning mode. Ask again only when missing, revoked or materially changed—not after every Replay. Withdrawal follows the visibility and retention rule below.

**Opt-out rule, decided before implementation:** opting out stops future competitive submissions and removes all of this Member's previously published scores from both game leaderboard views (Weekly and All-time), including public top lists and own competitive-rank projections. The server recalculates affected standings. Retain private accepted-round/audit receipts and device-local history/PBs under existing retention controls; withdrawal does not erase Reward Points, point receipts or vouchers. Until server confirmation, show Updating ranking visibility; on failure show Retry and do not claim scores were hidden. Re-enabling starts eligibility for newly consented rounds only and does not automatically republish old scores. Explain this effect beside the opt-out control. This affects game-score rankings only; the separate existing earned-points leaderboard retains its current policy.

Local play remains available without competitive submission. Completed ranking-eligible play can improve ranking after the daily Reward Points allowance is exhausted.

### Gameplay and interruption

Keep the implemented game engine, responsive cursors, hit confirmation, score rules and pause/recovery behavior. Hide details/history controls during active play. Tracking loss freezes active time/scoring and gives brief on-camera guidance; supported automatic recovery avoids walking back to the phone. Manual Pause, backgrounding and actual camera errors retain deliberate Resume/retry controls. Unfinished exits keep existing confirmation/save safeguards.

## 4. Results: celebrate the game first

Results hierarchy:

1. **Final Game Score** as the hero.
2. **Targets hit** (Reach & Tap) or **Stars caught** (Move & Catch), plus relevant existing game metrics without inventing accuracy.
3. **Personal best** with “On this device” until a competitive best is confirmed. If this round exceeds the previous valid local best, show New personal best! after successful local persistence. Unknown previous best must not produce a false record celebration; show save failure/retry separately.
4. **Reward Points** in a distinct compact row: Confirming / +20 confirmed / Already earned today / Limit reached / Not participating / Not active / Could not confirm—Retry. Never convert Game Score into wallet credit or show a pending +20 as earned.
5. **Competitive status** when opted in: Submitting / Best accepted score / Rank / Could not submit—Retry. Submission failure must not erase the saved local result or imply the reward claim failed.
6. **Play Again** primary, **View Leaderboard** secondary when available; Back to games remains clear. Before P2, do not show a dead leaderboard button or fabricated standings.

Replay goes straight to fresh alignment/countdown once existing consent is valid; it does not reopen instructions/mode confirmations unless the Member changes their choice. Clear old hit effects, abandoned attempts and result state. Preserve authoritative earning eligibility on Replay.

Use brief score-count/new-record/badge feedback, optional subtle sounds and haptics. Respect current mute settings, reduced motion and background audio lifecycle. No blocking celebration modal; never replay an old celebration after resume. Badge unlock feedback is meaningful only for a real confirmed unlock.

## 5. Separate mini-game leaderboards (P2 priority)

| Ranking | Metric | Independence |
| --- | --- | --- |
| Move & Catch | Best eligible accepted completed 40-second score | Never mixed with Reach & Tap |
| Reach & Tap | Best eligible accepted completed 40-second score | Never mixed with Move & Catch |
| Existing earned-points leaderboard | Eligible earned point receipts | Preserve current behavior; spending points does not lower earned ranking |

Each game has **Weekly / All-time**, Top 3, Top 20, pinned personal rank and best accepted score. A Member contributes one best eligible round per game, period and comparable scoring version—not accumulated replay scores. Equal scores share rank (1,2,2,4); stable row ordering does not create unequal tied ranks. Use existing organization scope. Weeks start Monday 00:00 Asia/Kuala_Lumpur, based on server completion time.

Entry points: game Details, Results, compact hub rank and secondary Leaderboards game selector. When outside Top 20, keep the own-rank summary visible. No eligible result means Unranked with Play, not rank0. Empty/error/loading states remain distinct. Existing bounded earned-points scans must not silently truncate standings; do not expand infrastructure unless actual demo scope requires it.

### Practical FYP score acceptance

Reuse existing Firebase callable/auth/session patterns and round ownership. Extend the supported game contract rather than replacing the timing service. Validate identity, organization, game/scoring version, owned completed attempt, active duration, monotonic event sequence, allowed event types, timing/rate bounds and once-only submission. Derive accepted score server-side from bounded game-specific hit/obstacle events where available; do not accept an unrestricted client score field. Store minimal accepted result/receipt and update best/rank idempotently. A retry recovers the original result without a duplicate entry.

This provides **server-validated game results**, not proof that a human physically performed every action. For the FYP demo, label competition “Gameplay results · not physically verified” in ranking information, with concise first-opt-in copy. Client-reported events remain a trust limitation; do not claim cheating is impossible. No camera upload, raw landmark retention, physical-attestation subsystem or enterprise anti-cheat project is required. Do not grant new Reward Points based on ranking position or high score.

Keep validation as a bounded extension of existing round services: ownership/completion, ordered event and timing checks, deterministic score calculation and idempotent acceptance. No device-attestation service, external fraud system, human verification queue or generalized anti-cheat engine is part of P2.

Reject incomplete, foreign, duplicate-conflicting, malformed, out-of-order and implausibly fast submissions. Preserve local scores even if a competitive result is not accepted. Keep incomparable scoring/round-rule versions separate; archived local scores are not automatically backfilled. Public rows expose only approved display name/alias, rank and score; personal achievement time may remain in the own summary. No private IDs, email, raw events, camera media or voucher codes in standings. Existing privacy/account isolation controls remain.

## 6. Rewards that Members can understand

| Source | Policy to preserve |
| --- | --- |
| Daily app check-in | **+50**, once per Malaysia calendar day; engagement, not physical gym attendance |
| Move & Catch | Approved **+20 participation reward**, once per game/day for an eligible owned completed round |
| Reach & Tap | **+20 proposed, currently inactive**; implementation in P2 does not authorize activation |
| Mini-games shared limit | **60 Reward Points/day** across eligible games; per-game limits still apply |
| Badges | Existing check-in unlocks add no bonus points |
| Workouts | Earning remains disabled until separately approved and validated |

Keep Game Score separate from spendable Reward Points everywhere. With the two current earning sources the described attainable maximum is70/day; approving Reach & Tap at20 would make it90/day. The shared60 game cap is not an allowance to claim60 from one game. Show actual source availability rather than advertising a misleading theoretical daily maximum. Do not add multipliers, new point expiry, attendance/referral/prize bonuses or Premium benefits.

### Check-in

Eligible → Claiming → Confirmed / Already claimed / Retry. Only a server receipt updates points, today's strip and streak. Consecutive Malaysia days extend the streak; a missed day breaks the current streak, not longest streak or existing badges. No point penalty, artificial catch-up or streak-freeze mechanics. Refresh at server day change/resume. Multiple taps/devices cannot credit twice.

### Redemption

**Shop → Reward detail → Redeem confirmation → My Rewards QR/reference → Admin inspection → Confirm collection → Used.**

- Show cover, direct point cost, confirmed balance, stock, membership eligibility, validity and collection instructions before redemption. Give specific unavailable/insufficient-balance/out-of-stock explanations.
- One intentional confirmation protects spending. If cost/revision changes, reload and reconfirm. Preserve atomic debit/stock/voucher issue, stable request IDs and existing receipts.
- After confirmed redemption, refresh wallet/history and open the issued reward with Show QR. My Rewards retains Available / Used / Expired and issued terms.
- Scanning inspects; authorized Admin explicitly confirms collection once. Duplicate/foreign/expired references do not consume again.
- Preserve current rules: issued vouchers remain collectible after membership expiry until voucher expiry; unused expired vouchers remain spent with no automatic refund or stock credit. Legacy unknown expiry stays honestly unknown.
- An uncertain response shows Confirming/Retry, never a fabricated voucher or automatic second purchase. Offline cannot claim points, redeem or confirm collection successfully; existing local game play/history remains available.

## 7. Badges and secondary screens

**P1:** reuse only real First check-in, Three-day streak and Seven-day streak evidence. The secondary Badges screen shows Unlocked / In progress, a concise requirement, actual progress and unlock date. Connect existing check-in badge data; replace unavailable general placeholders without seeding achievements. A brief confirmed unlock message can link to details; no full badge grid on the hub.

**P3:** consider additional supported definitions only when evidence and useful Member value exist. No artificial achievements, fabricated form accuracy, unverified workout badges or bonus-point rules. Preserve existing unlocks and immutable history; version/backfill decisions must be explicit when definitions actually change. A generic badge-rule engine is unnecessary for the initial demo.

Secondary screens remain focused:

- **Points History:** existing All/Earned/Spent and source filters; real receipt dates/amounts. No duplicate ledger on the hub.
- **My Rewards:** quick issued QR access and collection status; direct route from redemption and hub.
- **Leaderboards:** game rankings first in game context; existing earned-points ranking clearly named.
- **Reward Goal (P3):** choose a published item; show balance toward current cost. It reserves neither price nor stock. Retired/changed rewards refresh honestly.
- **Sharing (P3):** optional explicit native share of a real badge or labelled scorecard. No auto-posts, referral points, camera media, private account data or redemption QR/token.

## 8. Existing architecture and Admin responsibilities

Reuse `appCheckInCommand`, mini-game content, round/participation services, `verifiedRewardsCommand`, `rewardCatalogCommand`, existing repositories, wallet, receipt and voucher identities. Extend only contracts needed for separate competitive results and future Reach & Tap participation. Do not create another wallet, migrate real histories or rename collections to match an older conceptual model.

Server authority remains over spendable points, daily limits, stock, vouchers, accepted competitive scores and server-earned badges. Camera frames/landmarks stay on-device. Local personal best is not relabelled as server-accepted or physically verified. Rewards, competitive submission and local saving have separate result states and identities.

Preserve scoped caches/session invalidation. Confirmed check-in/redemption/claim refreshes affected wallet/history/progress; a ranking refresh does not reopen the camera. Never show another account's cached results. Failed reads retain an honestly labelled last confirmed state where safe; no invented zero or optimistic credit.

Admin continues using the released desktop shell, game content editor, catalog, collection and existing policy/report pages. Add only necessary per-game standings/submission inspection to support P2. Descriptive game editing cannot modify recognition or scoring algorithms. Existing draft/active earning distinctions and permissions remain. No broad Admin redesign, automatic balance adjustment, retrospective badge migration or generalized fraud/moderation platform is part of this plan. Correcting a result, if needed, must preserve audit evidence and follow existing authority rather than deleting receipts or editing balances.

## 9. Delivery priorities and acceptance

### P1 — A complete enjoyable daily loop

**P1A — approved first implementation slice:** compact Rewards hub with existing wallet/check-in, near-top two-game managed cards, per-game device-local PB and actual earning availability, compact existing earned-points weekly-rank summary, Shop/My Rewards/History/Leaderboard navigation, and real check-in badges on a secondary screen. Reuse existing detail/consent/game/result/redemption flows. No mode/result engine rewrite, competitive score submission, Reach & Tap earning, reward goals, extended badge criteria or backend/service/policy changes in this slice. Game mode simplification and Results polish belong to P1B; complete redemption acceptance belongs to P1C. Implementation tests must cover compact/large-text layouts, real/unknown values, scoped asynchronous refresh, eligibility and unchanged daily claim/navigation behavior.

**Deliver:** compact Member hub with wallet/check-in and both game cards; per-game labelled personal best and actual earning availability; inline Details instructions and clear Fun/Earn choice; preserved camera consent/alignment/countdown; game-first Results and quick Replay; real existing check-in badge screen; complete Shop→voucher→Admin collection and cross-screen refresh. Keep compact earned-points weekly rank until game rankings exist; defer an interactive reward goal to P3.

**Accept when:**

- At375px, wallet/check-in and game access are prominent; at320px/2× text, actions remain readable and reachable without overflow. No duplicated wallet/earning/history sections or unnecessary long scroll; reduced motion/mute settings work.
- Both games launch through the stated flow without redundant confirmations; permission is not requested while browsing, replay does not reopen full instructions and required exit/save safeguards remain.
- Check-in credits50 once despite retry/two devices; Malaysia midnight and missed-day streak behavior are correct; existing real badge unlocks persist without bonus points.
- Results show honest score/hits/PB/record state, local-save retry and independent server-confirmed reward status. No score-to-wallet conversion or false success after timeout.
- A real eligible Move & Catch attempt can earn20 once; Fun mode and inactive Reach & Tap earn nothing; capped/unknown states are clear. No new game earning policy is activated.
- Last-stock concurrency, insufficient balance, changed price, lost redemption response, duplicate/foreign QR, expiry and membership-change scenarios preserve correct balances/stock/vouchers. My Rewards is easy to reach.

### P2 — Game competition and Reach & Tap earning integration

**Deliver:** separate Move & Catch/Reach & Tap Weekly/All-time score leaderboards, remembered independent competitive choice, owned completed-round validation, result submission/retry and competitive PB/rank; necessary Admin inspection. Extend existing timing/participation contracts for Reach & Tap and add correct eligibility/result UI, remaining inactive until separate earning approval. Competition is independent of daily reward limits.

**Accept when:**

- Each leaderboard shows Top3/Top20/own rank/best accepted score. Only one best eligible round per Member/game/period/version contributes; replay totals are never accumulated.
- Ties, Monday Malaysia reset, two-device best updates, unknown/unranked states and game/version separation behave correctly. Existing earned-points rankings remain unchanged by spending or game-score submission.
- Invalid ownership, incomplete/implausible/out-of-order submissions fail; retries are once-only; results retain local scores if submission fails. Privacy choice survives Replay for the same account/version and does not leak across accounts.
- Trust labels state server validation without physical verification. No raw media/landmarks upload or new anti-cheat infrastructure. Declining competition does not block Fun mode or eligible reward participation.
- Reach & Tap earning tests cover disabled policy, daily20 proposal, once/game/day and atomic shared60 cap in controlled tests only. Live issuance remains off until approved; exhaustion affects earning, not ranking eligibility.

### P3 — Optional progression polish

**Deliver:** selected reward goal, useful extended evidence-backed badges and explicit optional sharing. Keep these small enhancements after the full P1/P2 flows work.

**Accept when:** goal progress uses confirmed balance/current cost and promises no stock; badges use real supported evidence with preserved previous unlocks; sharing excludes private data/tokens and never posts automatically. No new point bonus or unverified workout achievement is introduced.

### Release discipline and demo walkthrough

For future implementation, use focused Domain/Data/Functions/Admin/Mobile tests, scoped review, analysis/typechecks/architecture and affected builds. Preserve existing release/rollback practices and data. Technical deployment authority does not approve held earning policies. This document revision performs none of those implementation/release actions.

Demo in one coherent pass: open hub → check in → see50 confirmed and real badge progress → choose Move & Catch Fun/Earn → align/play → see score/PB and separate earning status → Replay without repeated prompts → view its own rankings once P2 exists → try Reach & Tap without implying Reward Points → browse an eligible reward → redeem once → show My Rewards QR → Admin inspects/confirms collection → Member sees Used and reconciled balance/history. Include one retry, one cap/disabled state and one tracking-loss recovery to demonstrate honest behavior.

**Out of scope until separately requested/validated:** workout-earned points, unverified workout badges, new paid benefits/multipliers, ranking prizes, physical-movement attestation and enterprise-scale competition infrastructure.


## 29 October implementation and usage

Release: backend ACTIVE, private Admin at localhost:7359 ACTIVE, exact Xiaomi update INSTALLED. Evidence: `build/arcade-complete-20261029/release-verification.json`.

- Member: Rewards → a game card → Details/instructions → choose Fun (default) or eligible Play & Earn → Start playing → explicit Start camera consent → alignment/Ready/countdown →40active seconds → score/hits/PB, independent reward/competitive status → Play again or View leaderboard. Preview never starts camera. Replay retains the session choice and rechecks server eligibility. Unknown/exhausted earning falls back to Fun; no repeated mode dialog.
- Competition: enable Include my results in game rankings independently of earning. Leaderboards offer game and Weekly/All-time selectors with Top3/20 and own best/rank. Opt-out requires server confirmation and hides prior public scores in both games; local history and private receipts/points/vouchers remain. Re-enable applies only to newly consented rounds. These are server-validated gameplay events, not physically verified exercise.
- Rewards: My Reward Goal → Choose goal → a published item. Progress uses current confirmed balance/cost; stock and price are not reserved. Shop → Details shows balance/cost/stock → Confirm redemption once → issued voucher QR → My Rewards → Admin collection. Unknown response retries the same request; never redeem another item to resolve an uncertain purchase. Issued voucher terms/expiry and prior histories remain.
- Badges: Rewards → Badges shows real first/3/7 check-in progress and dates. Share badge opens Android's chooser only for an unlocked badge with fixed achievement text, without account details, camera media or voucher QR.
- Admin: refresh localhost:7359 → Mini-games → Game standings; choose game and period. This is read-only and cannot edit score/reward balances.

Validation:417Mobile +85Admin +182Domain +152Data +1379Functions =2215 tests, five pre-existing Mobile skips, plus38 exact-package tests. Scoped strict analysis clean; wider unchanged sources retain21Mobile/9Admin informational lints documented in protected logs. No live competitive consent/score/credit/redemption test writes occurred. Physical gameplay, signed-in browser/native chooser and end-to-end physical collection acceptance remain pending. Additional badges require real evidence-backed criteria; no new point bonus or workout achievement is created. Reach & Tap20points and workout-earned points remain inactive pending separate approval/validation.


### Fresh acceptance checkpoint

**Fitness Arcade acceptance checkpoint (29 October):** fresh49Mobile journey +86contract +26Firestore/Storage emulator tests pass (161total). Real emulator transactions verify both-game score submission/retry/opt-out/re-entry with wallet/private receipts preserved, earning daily caps, and claim→redeem→My Rewards→Admin once-only collection/expiry/last-stock behavior. Live signed-in App Check preference/four standings reads and anonymous rejection pass with no live data/consent/score/reward/redemption writes. Physical game accuracy/framing/recovery/latency/thermal, native share chooser and real collection remain pending; browser acceptance is blocked because local browser use is disabled in Work settings. No new build/deployment/policy activation occurred. Evidence: `build/arcade-acceptance-20261029/acceptance.json`.

Hands-on remaining: play both40-second games with real movement and one tracking loss, check saved result/Replay; inspect native Share badge chooser without publishing; confirm signed-in Admin standings in an enabled browser. Real Member point spending/QR collection was not used as a test substitute. The complete redemption flow passed in isolated demo emulators instead.


## Reach & Tap earning approval and release —29October

**Reach & Tap +20 earning / refresh cleanup — RELEASED (29 October):** owner-approved participation reward is active at20 once/game/Malaysia day under the shared60 game cap, using the existing spendable wallet. Explicit Fun/Earn, server eligibility,40active-second owned timing, confirmed result/retry and game-specific claims/PB separation are integrated; Fun never claims. Reach uses negotiated schema3 and exact source-defined effective policy, preserving legacy Move clients, historical receipts and current configuration. All three main Rewards refresh icons are removed; pull-to-refresh and automatic game/check-in updates remain. Fresh2242affected tests (five existing skips),33exact-package tests and one real Firestore concurrent both-game earning transaction pass, with strict analysis/typechecks/architecture, independent32-file review and Android/Admin builds. Two source-only existing Functions preserve runtime/environment/IAM,68 others and Rules/index/config/content/accounts. Verified in-place Xiaomi APK/hash/signer/data/identity and previous APK preserved; private Admin unchanged. Live authenticated App Check overview confirms activeReach20/once/shared60 and samewallet; anonymous rejected, no live test credits. Workout rewards remain disabled; physical/browser acceptance pending. Evidence: `build/reach-tap-earning-20261029/release-verification.json`.

Member flow: Rewards → Reach & Tap (+20points when servereligible) → Details → choose Play & Earn → Start playing → explicit Start camera → align/countdown → complete40active seconds → RewardPoints confirmed byserver. Hit GameScore remains separate. Replay retains chosenmode but rechecks allowance; after today’s reward it switches toFun and cannot creditagain. Move & Catch has its own20/once allowance, sharing the60gamecap. Check-in remains50. Rewards pull-down refresh remains; decorative refreshicons are removed. No workout reward activation is included. Earlier Reachinactive statements in this historical plan are superseded by this explicit ownerapproval and release.


Catalogue presentation follow-up: View all → All challenges now uses the same card component for both games, including cover/play/title/metadata, while retaining each game’s managed details and rewards.434affected Mobile tests and verified Xiaomi installation passed; visual owner retest remains pending.
