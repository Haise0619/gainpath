# M02 — AI virtual coach, routine execution and voice feedback

| Evidence axis | Assessment |
|---|---|
| Implementation | Implemented. Six registered on-device movement analyzers, video-timed and manual execution, persisted routines and optional cloud backup. |
| Verification | Source-inspected. Host/software regressions exist for algorithms, routing, voice and recovery. Historical physical evidence covers limited recordings and specific debug/profile builds. |
| Deployment | Historical release records are product- and date-specific. The audited checkout was not deployed and current cloud/app parity was not tested by this audit. |

## Entry points, screens and execution

Member Workout Hub loads scoped published routines and local checkpoints, builds resumable attempts and links to catalog, history and backup. Published routines and Programs reuse local progress but retain different enrollment semantics. The journey can select an exercise/day, step through preparation and rest, switch to another exercise, skip, save or finish. Camera setup includes framing guidance, consent/permission gating, calibration, tracking state, reps, partials, set targets, correction hints and counter/voice controls. Live views surface camera opening, failed camera, recalibration and pause states; a scoped input error may render Unavailable. Summary is produced after successful local save and shows the measurement provenance. Pose-sensitive settings and Cloud Backup have separate screens.

The dispatcher matches exact organization/exercise identity and available installed tracker; changing catalog title, video or pose metadata does not create a tracker. Currently supported AI trackers are Bodyweight Squat, Single-arm Dumbbell Curl, Standing Calf Raise, Standard Floor Push-Up, Dumbbell Shoulder Press and Standing Lateral Raise. Legacy Wall Push-Up, Single-arm Dumbbell Row and Reverse Lunge retain manual execution and independent history. Commit 92ef3a7 records the tracker retirement; older Voice V1 discussion of nine session owners reflects the earlier configuration. The resolver distinguishes measured, timed, legacyManual and unavailable. Timed requires a valid timed prescription, valid MP4 media contract and matching generation/source revision/stamp; manual records self-confirmed sets; unknown explicit AI mode is unavailable. A camera failure is distinct from a manual exercise classification.

| Layer | Identifiable evidence |
|---|---|
| Entry and routing | apps/mobile/lib/app/routing/workout_prep_route.dart:134–202,331–381; routine_journey_route.dart:438 onward; exercise_tracker_route.dart; guided_timed_workout_route.dart:109 onward |
| Exact identity and routing | packages/gainpath_domain/lib/src/workout/exercise_tracking.dart:44–73; apps/mobile/lib/features/workout/domain/exercise_tracker_dispatcher.dart:6–74 and exercise_execution_resolver.dart:20–73 |
| Live screens | apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart; pose_preview_view.dart; widgets/workout_session_sheet.dart; workout_result_screen.dart; workout_ai_consent_guard.dart |
| Measured orchestration | apps/mobile/lib/app/routing/real_squat_route.dart:133–184 and floor_push_up_workout_route.dart:86–101,192–205; features/workout/application/floor_push_up_workout_session.dart and measured_workout_session.dart |
| Timed persistence | apps/mobile/lib/features/workout/application/guided_timed_workout_controller.dart:181–374; routine_journey_controller.dart:459–510 |
| Published catalog | apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart and firebase_workout_program_catalog.dart; functions/src/modules/workouts/workout-backup-validation.ts |

## Sequence and storage

~~~mermaid
sequenceDiagram
  participant M as Member
  participant J as RoutineJourneyController
  participant T as Workout route and session
  participant L as Scoped private files
  participant B as Backup callable
  M->>J: Open published plan and select exercise
  J->>L: Load or write routine checkpoint
  J->>T: Resolve exact measured/timed/manual path
  T-->>M: Consent/setup or media preparation
  T->>T: Measure movement, time a set or record manual sets
  T->>L: Persist bounded summary or progress
  J->>L: Reconcile reviewed/skipped/set status
  opt User-authorized, eligible backup
    J->>B: Send descriptive payload and expected digest
    B-->>J: Confirm digest or return conflict/error
  end
~~~

- Local persistence uses application-support files. FileWorkoutSessionStore stores scoped exercise summaries. FileRoutineJourneyStore uses a lock plus revisioned checkpoint writes and validates scope/size. RoutineCheckpoint carries selected index, pending/completed session relationships, manual sets, guided progress, reviewed/skipped indices and finished state. Reload reconciles checkpoints with local sessions. Video-timed progress has saved working/rest/paused state and active time. A pause cannot award a set by itself. This evidence does not establish exact recovery of an in-flight camera inference, and users recalibrate after interruption.
- Local storage responsibility is independent of network backup. FileRealWorkoutSyncStore tracks acknowledged consent and durable queued operations for the legacy verified submission path. RealWorkoutOutboxRepository scopes records and consent, validates acknowledgement identity and preconditions, queues only a permitted request and handles revoke/epoch. The server's ENABLED_WORKOUT_TUPLES is an empty frozen array. A valid camera count, a descriptive backup and a verified server tuple are independent.
- Optional descriptive backup uses workoutBackupCommand and a separate coordinator/local store. Server verifies email, UID ownership, active canonical Member/organization, explicit consent and current account session before reading or writing validated versioned payloads (functions/src/modules/workouts/workout-backup.ts:12–66). The normal callable writes orgs/{org}/members/{uid}/workoutBackups/{kind}-{id}, with immutable revisions keyed by digest. The principal row stores kind, id, key, digest, payloadJson, provisional_member_backup classification and update timestamp. The client factory gates dataset-aware contexts separately. List/save use a digest, and local conflict actions support keeping a local version or safe reconciliation. Transactions prevent an equivalent retry from requiring a duplicate record. App captures pose locally and backs up derived summaries/checkpoints as authorized. Workout privacy settings govern backup; a skipped upload does not erase an already-saved local summary.
- Newer gamification source provides claimAiWorkoutPoints (10 points per eligible, distinct exercise/day with a confirmed routine backup) and videoWorkoutPoints (5 points per eligible timed exercise/day after the configured sets, with ordered server-side timing records). These are points policy rules, separate from verified exercise/scoring upload. Server code references shared daily/award and receipt documents. The Floor route still displays legacy wording that rewards are unavailable, so exact UI/runtime acceptance of the newest policy needs review. See functions/src/modules/gamification/ai-workout-points.ts:10,31–127 and video-workout-points.ts:10,18–119.

## Evidence, scope and limitations

| Area | Software or retained evidence |
|---|---|
| Routing and hybrid routine | apps/mobile/test/hybrid_routine_journey_test.dart, routine_camera_continuity_test.dart, routine_journey_flow_test.dart, guided_timed_workout_flow_test.dart |
| Algorithm | packages/gainpath_pose/test/{squat,curl,calf_raise,lateral_raise,shoulder_press,floor_push_up}_analyzer_test.dart; deterministic trajectories and optional fixture replay |
| Persistence and security | apps/mobile/test/features/workout_pose_persistence_test.dart, workout_backup_integration_test.dart, workout_backup_dataset_test.dart; functions/src/modules/workouts/workout-backup-callable.ts:9 onward, workout-service.ts:20,103 onward |
| Voice | apps/mobile/test/coach_voice_policy_test.dart, floor_push_up_voice_feedback_test.dart and retained_voice_boundary_test.dart |
| Historical release | docs/integration/hybrid-workouts.md and standard-floor-push-up.md describe release subsets. Their historical approvals and test counts do not cover later local changes. |
| Device evidence | docs/integration/floor-push-up-physical-acceptance.md and docs/ux/module-2-phase5a-release-readiness.md. Physical left/right labels, audio timing, app lifecycle on a phone and score agreement remain pending. |

See the pose, movement, scoring and voice technical notes and the [P01–P10 evidence index](../evidence/code_snippets/POSE_AND_WORKOUT_INDEX.md). For figures, record synthetic Member data from Workout Hub → routine → camera setup/calibration → an accepted full and partial movement → rest → summary → local history → backup status. Capture an interrupted/resumed timed set and a revoked-permission state separately. Store clips privately and only export consented/redacted report frames.
