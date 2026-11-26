# M02 · AI virtual coach and voice

A functional Pass means each cited component test file recorded passes with zero failures. Skipped cases remain visible in the result counts. Scoped Firebase SDK/Rules verification can pass a cross-module or non-functional scenario when the executed test matches that scope. Other rows list component evidence and retain the proposed scenario status. Source anchors point to the first assertion in each cited suite.

## F-M02-01 · Rep phase progression and dropout

| Field | Evidence |
| --- | --- |
| Test case ID | F-M02-01 |
| Test case name | Rep phase progression and dropout |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Unit/service contract |
| Objective | Rep phase progression and dropout |
| Preconditions | Valid and rejected squat landmark sequences with controlled timing |
| Test data | Valid and rejected squat landmark sequences with controlled timing |
| Test steps | Replay authored movement and stale/missing samples through analyzer |
| Expected result | A qualifying full cycle counts once. Invalid geometry or temporal discontinuity does not credit a rep |
| Actual result | 29 pass/0 fail/0 skip [dart-pose-portable]; 2 pass/0 fail/0 skip [dart-pose-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/dart-pose-portable.txt |
| Source reference | packages/gainpath_pose/test/squat_analyzer_test.dart:82; packages/gainpath_pose/test/squat_delivery_timing_test.dart:6 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M02-02 · Mixed exercise progression

| Field | Evidence |
| --- | --- |
| Test case ID | F-M02-02 |
| Test case name | Mixed exercise progression |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Mixed exercise progression |
| Preconditions | TD-ROUTINE, mixed execution modes |
| Test data | TD-ROUTINE, mixed execution modes |
| Test steps | Apply manual and guided set input, complete timed bout and rest, check route progression |
| Expected result | Correct set offset, completion state and persistence for configured mode |
| Actual result | 1 pass/0 fail/0 skip [mobile-portable]; 2 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/hybrid_routine_journey_test.dart:77; apps/mobile/test/guided_timed_progress_test.dart:6 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M02-03 · Voice eligibility and feedback freshness

| Field | Evidence |
| --- | --- |
| Test case ID | F-M02-03 |
| Test case name | Voice eligibility and feedback freshness |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Voice eligibility and feedback freshness |
| Preconditions | TD-POSE-FP with fresh/late cue inputs |
| Test data | TD-POSE-FP with fresh/late cue inputs |
| Test steps | Drive a valid form cue, invalidate its source and introduce a late/repeated event |
| Expected result | Policy and lifecycle gates admit only fresh, eligible cues |
| Actual result | 3 pass/0 fail/0 skip [mobile-portable]; 4 pass/0 fail/0 skip [mobile-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture |
| Evidence | evidence/test_logs/mobile-portable.txt |
| Source reference | apps/mobile/test/floor_push_up_voice_feedback_test.dart:12; apps/mobile/test/coach_voice_policy_test.dart:6 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |

## F-M02-04 · Workout backup request and local history

| Field | Evidence |
| --- | --- |
| Test case ID | F-M02-04 |
| Test case name | Workout backup request and local history |
| Module | M02 |
| Requirement reference | See module mapping (audit; original requirement ID separate) |
| Test type | Widget/unit or staged manual |
| Objective | Workout backup request and local history |
| Preconditions | TD-TRAIN valid and repeated records |
| Test data | TD-TRAIN valid and repeated records |
| Test steps | Save measured and declined/invalid data, retry and verify receipt/history counts and ownership |
| Expected result | Complete record has stable identity. Offline/pending does not pretend cloud acceptance |
| Actual result | 8 pass/0 fail/0 skip [mobile-portable]; 30 pass/0 fail/0 skip [backend-portable] |
| Status | Pass |
| Environment | Dart/Flutter VM fixture; Vitest Node sandbox/fakes |
| Evidence | evidence/test_logs/mobile-portable.txt; evidence/test_logs/backend-portable.txt |
| Source reference | apps/mobile/test/workout_backup_test.dart:89; functions/test/workout-backup.test.ts:6 |
| Remarks | Execution result is derived at the cited file level. See individual named assertions in the execution inventory. |
