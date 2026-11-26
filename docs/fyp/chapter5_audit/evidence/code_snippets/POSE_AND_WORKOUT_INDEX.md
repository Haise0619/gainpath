# Workout, pose, audio and arcade source evidence

Corresponding report sections are 5.1.3 and 5.1.4. Excerpts retain original code and exact line order. Code before and after each stated line range is omitted. Paths are relative to the audited GainPath repository.

| ID | Lines | Symbol or local context | Academic relevance | Associated test |
|---|---|---|---|---|
| [P01](P01.md) | apps/mobile/lib/infrastructure/pose/blazepose_detector.dart:470–507 | BlazePose worker, detector refresh and model inference | Shows the processed-frame cadence and verified 224-pixel detector crop in the worker. | apps/mobile/test/blazepose_contract_test.dart |
| [P02](P02.md) | packages/gainpath_pose/lib/src/pose/one_euro_filter.dart:23–50 | OneEuroFilter.filter | Shows adaptive smoothing and the actual derivative from the prior filtered position. | packages/gainpath_pose/test/shared_foundation_test.dart |
| [P03](P03.md) | packages/gainpath_pose/lib/src/squat/squat_analyzer.dart:297–339 | SquatAnalyzer._advance | Shows hysteresis, valid return gating and fixed penalties with independent full and partial counts. | packages/gainpath_pose/test/squat_analyzer_test.dart |
| [P04](P04.md) | packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart:824–856 | FloorPushUpAnalyzer._complete | Shows independent ROM, alignment, speed and extension components. | packages/gainpath_pose/test/floor_push_up_analyzer_test.dart |
| [P05](P05.md) | apps/mobile/lib/features/workout/application/coach_voice_policy.dart:195–225 | CoachVoicePolicy.select | Shows semantic correction cooldown, tracking and encouragement eligibility. | apps/mobile/test/coach_voice_policy_test.dart |
| [P06](P06.md) | apps/mobile/lib/features/gamification/domain/reach_tap.dart:476–509 | ReachTapEngine, contact branch | Shows two-signal projected collision, same-arm dwell and time guard. | apps/mobile/test/reach_tap_engine_test.dart |
| [P07](P07.md) | apps/mobile/lib/features/gamification/domain/move_and_catch.dart:221–262 | MoveCatchEngine._advance | Shows progression, crossing collision and separate hit, avoid and missed behavior. | apps/mobile/test/move_catch_responsiveness_test.dart |
| [P08](P08.md) | apps/mobile/lib/features/workout/domain/exercise_execution_resolver.dart:36–73 | ExerciseExecutionResolver.resolve | Shows execution-mode selection and schema-bound published media evidence. | apps/mobile/test/hybrid_routine_journey_test.dart |
| [P09](P09.md) | functions/src/modules/workouts/workout-backup.ts:43–66 | backupWorkout | Shows validation, same-digest replay and compare-and-set conflict retention. | apps/mobile/test/workout_backup_integration_test.dart |
| [P10](P10.md) | packages/gainpath_pose/lib/src/squat/squat_geometry.dart:55–71 | SquatGeometry.fromFrame | Shows aspect-corrected vector angle geometry for knee and trunk. | packages/gainpath_pose/test/squat_analyzer_test.dart |
