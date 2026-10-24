# P8.1B-R — Safe exercise rename impact review

Read-only review on 2026-10-14, source `58efe0e1edeea6161da1bce75da823e3d6927077`. Fresh sanitized live reference read completed at **10:33 Malaysia time**. The requested rename is `Codex Verification Squat` → `Bodyweight Squat` on the existing catalog ID `F3b8xIr8ynBDd3gEICKX`, organization `gainpath`, Firebase project `gainpath-0619`.

**Conclusion:** The rename is identity-safe for the implemented real squat/tutorial/workout/history contracts. It does not require a new exercise ID, model ID, rule ID, workout schema or historical-result migration. A fresh trusted publication copies the new catalog name into the published exercise row, and Member routine/tutorial screens display that row's name. The routine/blueprint title remains **Codex Verification Routine**.

**Blocking limitation:** The current Admin catalog save supports changing name and URL, but **does not provide stale-edit/concurrent-write protection**. Do not approve the existing blind save as a concurrency-safe activation operation. A bounded source fix or an explicitly approved conditional write method must precede the live edit. No such fix or write was implemented in this review.

This supplements the [read-only media preflight](2026-10-14-p8-1b-read-only-preflight.md) and supersedes the earlier URL-only/no-rename activation proposal. Use the [revised rename activation/rollback plan](../planning/p8-1b-bodyweight-squat-rename-activation-plan.md). All deployment, live writes, republishing and APK replacement remain unapproved.

## Runtime impact trace

| Area | Actual implementation and rename effect |
|---|---|
| Catalog mapping/Admin editing | [FirebaseExerciseCatalogRepository](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart) maps `exerciseName` → `TutorialVideo.title` and encodes edited title → `exerciseName`. [Exercise Tutorials form](../../apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart) retains `widget.existing.id`; a nonempty ID uses `update`, not a new document. `Bodyweight Squat` satisfies the UI/Rules name constraints. List ordering may change because catalog results sort by title. |
| Blueprint references/Admin captions | [FirebaseRoutineTemplateRepository](../../apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart) persists rows as ID/sets/reps; decode joins `catalogEntry.title` by exercise ID for display. The [RoutineExerciseRef contract](../../packages/gainpath_domain/lib/src/workout/entities/routine_blueprint.dart) distinguishes joined `exerciseName` from persisted ID. No blueprint rewrite is needed; loaded Admin views may need refresh. |
| Trusted publication | [publishRoutine](../../functions/src/modules/content/publish-routine.ts) transactionally reads the active catalog by ID and sets row `name: source.exerciseName.trim()`, optional validated `videoUrl`, unchanged category/ID/day/sets/reps. Root `title` comes from `blueprint.name`, not exercise name. Catalog editing alone does not change existing published snapshots. |
| Member parsing/display | [PublishedRoutine](../../apps/mobile/lib/features/workout/domain/published_routine_view.dart) reads row `name` separately from `exerciseId`; [RoutineScreen](../../apps/mobile/lib/features/workout/presentation/member/routine_screen.dart), [WorkoutPrepScreen](../../apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart) and [tutorial screen](../../apps/mobile/lib/features/workout/presentation/member/published_exercise_tutorial_screen.dart) use that display value. The routine header remains the unchanged published title. |
| Tutorial navigation | [WorkoutPrepRoute](../../apps/mobile/lib/app/routing/workout_prep_route.dart), [typed navigation](../../apps/mobile/lib/navigation/workout_navigation.dart) and [ExerciseTutorialRoute](../../apps/mobile/lib/app/routing/exercise_tutorial_route.dart) pass the exact published row and account scope. No route lookup by the old/new name exists. |
| DevelopmentSquatBinding | [real_workout_contract.dart](../../apps/mobile/lib/features/workout/domain/real_workout_contract.dart) resolves only organization `gainpath` + exercise ID `F3b8xIr8ynBDd3gEICKX`, with valid targets. Rule version remains **`bodyweight-squat-side-v1`**, view **side**. It accepts no display-name argument. |
| RealSquatRoute | [real_squat_route.dart](../../apps/mobile/lib/app/routing/real_squat_route.dart) uses `widget.exercise.exerciseId` for binding/controller identity and passes `widget.exercise.name` only to the guided view's label. Detector/model version remains the existing BlazePose contract. An already-open route can retain its prior row/name; no retroactive relabeling is performed. |
| Analyzer/correction/scoring | [SquatProcessingController](../../apps/mobile/lib/features/workout/application/squat_processing_controller.dart) constructs the existing [SquatAnalyzer](../../packages/gainpath_pose/lib/src/squat/squat_analyzer.dart), whose inputs are pose/time/rules, not catalog display strings. No 2D/3D geometry, filter, counter, correction or score change is needed or made. |
| Local summaries/results/history | [WorkoutSessionSummary](../../apps/mobile/lib/features/workout/domain/workout_contracts.dart) stores exercise ID and measured metrics, not catalog name. [RealSquatSessionController](../../apps/mobile/lib/features/workout/application/real_squat_session_controller.dart) persists the ID; [measured result](../../apps/mobile/lib/features/workout/presentation/member/workout_result_screen.dart) uses generic measured-squat wording. Existing records require no rename/backfill or JSON migration. |
| Member Progress/history grouping | [StoredLocalMemberProgressRepository](../../apps/mobile/lib/features/analytics/data/local_member_progress_repository.dart) and [pure progress model](../../packages/gainpath_domain/lib/src/analytics/local_member_progress.dart) group/match exercise ID, rule/model/view/coverage and session facts; no catalog-name query occurs. Existing history/analytics may continue displaying raw IDs or generic labels. A rename does not automatically add a human-readable catalog label to those screens. |
| Submission/consent/outbox | [RealWorkoutSubmission](../../apps/mobile/lib/features/workout/domain/real_workout_contract.dart) has a strict field set with ID/version fields and no exercise name. [Outbox](../../apps/mobile/lib/features/workout/data/real_workout_outbox_repository.dart) and local progress receipt matching use these identities, account scope and consent IDs. Catalog text is not part of their stored submission fingerprint. No consent/outbox rewrite or reset is needed. |
| Trusted acceptance | [workout-service.ts](../../functions/src/modules/workouts/workout-service.ts) checks organization/exercise/detector/version/rule/view tuples and active catalog/published row IDs/targets, not names. `ENABLED_WORKOUT_TUPLES` stays empty. This rename does not make workout acceptance operational. |

## Hardcoded names and fixtures

The maintained-source search found **no comparison to `Codex Verification Squat` or `Bodyweight Squat` controlling real analysis, navigation, persistence or acceptance**. Names remain required nonempty display fields in catalog/published parsing; this is validation, not a name-based binding.

- [workout_contracts.dart](../../apps/mobile/lib/features/workout/domain/workout_contracts.dart) has a prototype/local plan label `Bodyweight Squat` with mock ID `bodyweight_squat`. That ID is intentionally different from the real catalog ID and is rejected by the real binding. Do not rename/rekey the prototype to mimic the Firebase record.
- [LiveWorkoutScreen](../../apps/mobile/lib/features/workout/presentation/member/live_workout_screen.dart) has a default label `Bodyweight squat`; the real route supplies the actual published name. Generic `Measured squat result` and `Opening squat session` strings are presentation text, not matching conditions.
- Admin/mobile/backend test fixtures use `Squat`, `Goblet squat`, mock IDs and other labels. These are synthetic fixture data, not live migrations; no bulk replacement is warranted. The new isolated tests also confirm that an arbitrary display label cannot alter the ID/rule binding.
- Prototype [recommendation seeds](../../packages/gainpath_data/lib/src/recommendation/in_memory/recommendation_seed.dart) use name-like `riskExercises`/tutorial `coversExercise` strings (for example `Barbell Squat` in [workout seeds](../../packages/gainpath_data/lib/src/workout/in_memory/workout_seed.dart)). These are mock/legacy sources disconnected from the real catalog workflow. They remain unchanged and should not be treated as trusted catalog-ID contracts. The chatbot's `e.name.toLowerCase()` match is for equipment, not this exercise record.

## Live reference audit

The fresh read listed the scoped blueprint and content collections with pagination. It found **one blueprint and one content document**, both referencing this exercise. No other current published routine needs a rename republish. This is an observed inventory, not a guarantee that no one will add/edit records before activation.

| Resource | Current verified values |
|---|---|
| Catalog | `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX`; `exerciseName: Codex Verification Squat`, active, schema 1, `muscleCategory: Compound Lower-Body` |
| Blueprint | `PTe4DxLS3WZ2DsfpGTOy`; **Codex Verification Routine**, **45 minutes**; only target: Day 1, same exercise ID, **3 sets × 8 reps** |
| Published content | `routine_PTe4DxLS3WZ2DsfpGTOy`; same source blueprint/title/duration/target; row name **Codex Verification Squat**, no video URL |
| Catalog document revision | Firestore metadata `updateTime: 2026-10-02T01:20:14.697765Z`; distinct from the application's `updatedAt` field |
| Catalog existing fields | Exactly `createdAt`, `exerciseName`, `isActive`, `muscleCategory`, `schemaVersion`, `updatedAt`, `videoUrl`; no extra unrelated fields observed |

Blueprint rows contain ID/sets/reps; published rows are snapshots containing name/category too. Any future additional published references retain their old names until deliberately republished; do not rewrite them globally. Historical results are not published routine rows and must never be updated by this operation.

## Exact proposed catalog before/after

Target document is unchanged: `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX`.

| Field | Before, from live read | Proposed after |
|---|---|---|
| `exerciseName` | `Codex Verification Squat` | **`Bodyweight Squat`** |
| `videoUrl` | Existing private URL, intentionally not printed | Verified Download URL for bucket `gainpath-0619.firebasestorage.app`, object `tutorials/bodyweight-squat-v1.mp4`, acquired privately in memory |
| `updatedAt` | Firestore Timestamp `2026-10-02T01:20:14.658Z` | Authorized commit's server timestamp |
| `schemaVersion` | `1` | **Unchanged** |
| `muscleCategory` | `Compound Lower-Body` | **Unchanged** |
| `isActive` | `true` | **Unchanged** |
| `createdAt` | Firestore Timestamp `2026-10-02T01:20:14.658Z` | **Unchanged** |
| ID/all other fields | Same document; no extras observed | **Preserved; do not set/replace the whole document or create another ID** |

The timestamp values above are normalized report representations, not instructions to store strings in Timestamp fields. The write must change only the intended name/URL and timestamp, with a revision precondition or captured-baseline transaction guard. Re-read and validate the revision immediately before execution; if it differs, stop/reload rather than silently accepting an altered baseline.

The URL remains token-private. The validated media fingerprint is `f9dedee1c818af39f4ee4e8970316805399f24f96d387dfee72b59cc51e86b9e`; no full Download URL is embedded in this diff or the tests.

## Admin save supports values, but is not concurrency-safe

The form copies the existing ID, edited title and URL into a new `TutorialVideo`; its mapper drops creation/update revision metadata. `save()` builds `schemaVersion`, `exerciseName`, `muscleCategory`, `videoUrl`, `isActive`, `updatedAt`, then calls `collection.doc(id).update(data)`. This preserves omitted fields such as `createdAt`, but also sends category/status/schema values captured by the older form. It has **no transaction read, expected revision, original-field comparison or last-update precondition**.

For example, another author can change category to `Core` and Active to false after this form opens; the older rename/video form will send `Compound Lower-Body` and true again. Rules authorize valid Admin/Staff changes and require a server update timestamp, but do not detect that stale baseline. An isolated production-encoder/field-merge demonstration reproduced the stale protected-field payload; it was not a live or emulator contention test.

**Recommended prerequisite, requiring source-change approval:** retain an edit baseline/revision, transactionally read and compare it on save (including retry), write only intended changed fields, and show a reload/conflict state without raw URL details. Simply wrapping a blind patch in a transaction without comparing the form's original baseline is insufficient for edits that changed before the transaction began. Preserve mock behavior, account boundaries and pure-Dart package separation; no new Firestore/workout schema is needed.

Firestore retries transactions when read documents change during the transaction, and supports explicit last-update preconditions. [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [Precondition reference](https://firebase.google.com/docs/firestore/reference/rest/v1/Precondition). An alternative specifically approved one-off conditional write could use the exact document revision and three-field change under verified author authorization; that is **not the existing Admin UI operation**, and has not been prepared/executed as a bypass here. Until one safe route is separately approved and verified, catalog activation is blocked.

## Publisher and Member display verification

Three isolated Node tests exercised the actual local compiled publisher: fresh publication uses **Bodyweight Squat** plus validated fixture MP4 URL and preserves ID/day/3×8/title/45-minute duration; old request receipt does not refresh the rename; other content/history fixture records remain untouched. The publisher writes only the selected published document and its command receipt. The deployed publisher source inspected earlier also copies `source.exerciseName.trim()` for the name, but lacks video projection; selective deployment is still required for media.

Three isolated Flutter tests exercised actual parsing/binding, catalog encoding and the Member routine/tutorial widgets. The renamed exercise is shown as **Bodyweight Squat**, both exercise displays retain the exact real ID/day/3×8 targets, and the routine header remains **Codex Verification Routine**. The player was an isolated failure fixture; no real camera, Firebase write or physical playback occurred. These tests establish software propagation, not live activation.

The publisher transaction uses a consistent current source read, but the publish command carries no expected catalog/blueprint revision. Re-read approved source state before publishing and verify the resulting name/media/targets/title afterward; concurrent authorized changes can otherwise become the legitimately current source. Stop on drift. Old request IDs return existing receipts instead of re-reading source. MemberShell also caches its routine future: re-enter/restart the authenticated shell after successful fresh publication; an existing open view can retain its old snapshot.

## Evidence, actions and stopping point

All **6 isolated checks passed**; architecture checker still reports **zero findings**. Local evidence is ignored: [live-identity-sanitized.json](../../build/p8-1br-review/live-identity-sanitized.json), [publication-tests.log](../../build/p8-1br-review/publication-tests.log), [member-admin-tests.log](../../build/p8-1br-review/member-admin-tests.log). A token-hygiene scan of 649 relevant tracked/diagnostic/report text files found **zero occurrences** of the actual Storage download token; [token-hygiene.json](../../build/p8-1br-review/token-hygiene.json) records counts only. Fixture media addresses are synthetic and never submitted as real activity. No broad test rerun or physical accuracy claim is made for this document-only review.

Approval is needed for the safe catalog-edit prerequisite (or a specifically reviewed conditional write alternative), selective publisher deployment, atomic name/URL update, fresh trusted publication, and named Firebase APK build/update-install/playback trial. Keep the blueprint/routine title unchanged. The requested rename intent is understood, but this task explicitly authorizes **review/preparation only**, not these operations.

No production source, live record, historical workout, model/rule/version, schema, consent/outbox, acceptance tuple, media object or phone APK changed. Step 7C was not started. Stop for explicit approval.
