# Reach & Tap participation release and clean Rewards header

Owner request explicitly approves Reach & Tap20RewardPoints and removal of refresh icons. Preserve once/game/Malaysia day/shared60cap; no workoutearning or scoretowallet conversion.

1. Backend/shared contracts: schema3 explicitgameId and Reach-specific effective sourcepolicy while legacy schema1/2Move and historical receipts remain valid; same existing wallet/daily transaction/idempotency. ExactReach20once, sharedcap<=60; no live configuration rewrite.
2. Mobile: separate pergame eligibility/counters, explicitFun/Earn, freshserverrechecks atcamera/replay, Reach ownedcompleted timing with independentcompetition/local persistence, confirmedrewardresult/retry. No automaticoptin.
3. Rewards UI: remove all3visibleRefresh icons (toolbar/games/rank), preservepullrefresh and automaticreturn/claimupdates.
4. Fresh focus+broad affectedtests, analysis/typechecks/architecture/builds, scopedindependentreview. Source-only existingRewards and Historyfunctions preservingruntimeenvIAM/otherfunctions/policies/content. ActivateprivateAdminonlyifchanged. InplaceverifiedXiaomiAPK preservingprevious/data/signer. No liveMembertestcredits or syntheticcompetitiveattempts.

Ledger: refreshiconredtestreproduced;33focusedcard/dashboard/ranktests pass afterremoval. Backendschema3sourcepolicy selected to preservelegacy/historicalsnapshots. Reachphysicalverification remainsfalse; participation rewardonly.
