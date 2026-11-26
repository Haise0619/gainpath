# M03 · Gamification and rewards

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M03-01 · Check-in receipt

| Field | Evidence |
| --- | --- |
| Test case ID | F-M03-01 |
| Test case name | Check-in receipt |
| Module | M03 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Check-in receipt |
| Preconditions | TD-REWARD fixed Malaysia-day operation and eligible role |
| Test data | TD-REWARD fixed Malaysia-day operation and eligible role |
| Test steps | Check in, retry same action, inspect dashboard and projected receipt |
| Expected result | An eligible check-in writes its intended progress once |
| Actual result | 14 pass/0 fail/0 skip [backend-portable]; 6 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes; Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/backend-portable.txt; evidence/test_logs/mobile-portable.txt |
| Source reference | functions/test/app-check-in.test.ts:10; apps/mobile/test/app_check_in_test.dart:109 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M03-02 · Reward eligibility and stock

| Field | Evidence |
| --- | --- |
| Test case ID | F-M03-02 |
| Test case name | Reward eligibility and stock |
| Module | M03 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Reward eligibility and stock |
| Preconditions | TD-REWARD normal, Premium and insufficient balances |
| Test data | TD-REWARD normal, Premium and insufficient balances |
| Test steps | Redeem eligible fixture then try blocked or repeated request and inspect wallet/voucher |
| Expected result | Qualified actor receives one voucher and correct deduction. Invalid eligibility/stock paths do not settle |
| Actual result | 7 pass/0 fail/0 skip [backend-portable]; 4 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/reward-journey.test.ts:14; functions/test/premium-reward-redemption.test.ts:30 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M03-03 · Arcade participation and award

| Field | Evidence |
| --- | --- |
| Test case ID | F-M03-03 |
| Test case name | Arcade participation and award |
| Module | M03 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Arcade participation and award |
| Preconditions | TD-GAME authored game round and eligibility state |
| Test data | TD-GAME authored game round and eligibility state |
| Test steps | Play with approved play mode, record score and retry participation settlement |
| Expected result | Correct round/points state. Fun or ineligible session cannot falsely claim an award |
| Actual result | 4 pass/0 fail/0 skip [mobile-portable]; 20 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/mini_game_round_flow_test.dart:13; functions/test/mini-game-participation.test.ts:21 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M03-04 · Workout points and achievements

| Field | Evidence |
| --- | --- |
| Test case ID | F-M03-04 |
| Test case name | Workout points and achievements |
| Module | M03 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Workout points and achievements |
| Preconditions | TD-TRAIN and saved workout fixtures |
| Test data | TD-TRAIN and saved workout fixtures |
| Test steps | Complete eligible guided/AI work and replay duplicate event; inspect award and achievement projection |
| Expected result | Correct one-time event and source-linked achievement, preserving account/isolation |
| Actual result | 10 pass/0 fail/0 skip [backend-portable]; 10 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/backend-portable.txt |
| Source reference | functions/test/workout-rewards.test.ts:12; functions/test/member-achievements.test.ts:32 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
