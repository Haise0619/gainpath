# Workout Programs and Weekly Schedule Implementation Plan

**Goal:** Versioned four-week Beginner/Intermediate/Advanced Programs above existing published Routines, with safe daily scheduling and truthful Member progress.
**Architecture:** Shared pure Dart Program/schedule contracts; isolated trusted callable for Admin authoring/publication and Member discovery; account-scoped durable local enrollment referencing existing routine attempt IDs. Published Programs embed published routine snapshots, so later editing cannot change an enrollment. Existing opt-in routine/workout backup retains exercise evidence; Program enrollment is separate metadata, never accepted workout evidence.
**Spec:** User's ten requirements in the current chat. Direct implementation requested; routine choices below are engineering decisions.
**Tech stack:** Flutter/Dart shared domain, Firebase callable TypeScript, existing local stores and tracker routes.

## Shared wire contract

`WorkoutProgram.fromJson(Map<String,dynamic>)`, `toJson()` in gainpath_domain/workout.dart. Fields schemaVersion:1, id:String, version:int (0 draft; >=1 published), title:String, level:Beginner|Intermediate|Advanced, weeks:4, days:List<ProgramDay> exactly 28.
`ProgramDay`: week:1..4, weekday:1..7 Monday, kind:workout|activeRecovery|rest, category:Full Body|Upper Body|Lower Body|Push|Pull|Legs|Active Recovery|Rest, routineId:String? (content ID), routineDay:int (default1), muscleGroups:List<String> canonical upperPush|upperPull|lower, restSeconds:int (0..600, default60), routineSnapshot:Map<String,dynamic>? (server copies existing published content; draft must not supply authoritative snapshots).
`WorkoutProgram.templates()` returns three editable 28-day drafts (no fabricated routine assignments), `validate({bool published = false})` throws FormatException. Repeated weeks: Beginner Mon/Wed/Fri Full Body; Intermediate Mon/Tue/Thu/Fri Upper/Lower; Advanced Mon Push/Tue Pull/Wed Legs/Fri Upper/Sat Lower. Other days recovery/rest. Adjacent workout dates cannot overlap muscleGroups (including week boundaries); recovery/rest breaks adjacency. This is a conservative scheduling guard, not medical advice.
Callable `workoutProgramCommand` request: schemaVersion:1, organizationId, action:list|adminList|saveDraft|publish, requestId for mutations, program for saveDraft, programId + expectedRevision for publish; saveDraft has expectedRevision (0 new). Responses list/adminList `{programs:[wireProgram], drafts:[{program:wireProgram,revision:int}]}`; saveDraft `{revision:int}`; publish `{program:wireProgram,revision:int}`. Published listing returns latest per program; enrollment copies entire version. Server requires canonical active verified scope, Admin/Staff for writes, App Check and fresh Auth before/after trusted work; optimistic revisions and idempotency receipts.

## Tasks and ownership

- [x] 1. Root: shared validated immutable Program models, template drafts and pure date/recovery scheduler with tests RED→GREEN. API for mobile: `ProgramSchedule.create(program,startDate,trainingWeekdays)` returns 28 `ScheduledProgramDay` entries with `key` (wN-dN), `definition` ProgramDay and `date` UTC date-only. `ProgramSchedule.reschedule(entries,key,date)` preserves keys, refuses date collisions/recovery conflicts. Default mapping assigns ordered workout days to selected weekdays; require exact count per week, preserve other days. Malaysia civil dates supplied by UI.
- [x] 2. Backend worker: isolated callable/service + backend tests, immutable published routine snapshots, optimistic drafts/versions/idempotency, canonical authorization. No root export/deploy/Rules mutations. Reuse publication storage style. Include rest targets in snapshot without modifying pose algorithms.
- [x] 3. Admin worker: connected Program editor/nav and scoped repository using wire contract; 3 editable template starters; choose existing published routines/day, day kind/category, targets via Routine Builder, rest; draft save and publish with errors/readback. Tests. Own Admin only.
- [x] 4. Mobile worker: scoped Firebase Program discovery + account-private local enrollment/journal, onboarding/Today/week/day screens, routine-route integration with exact attempt ID, completion reconciliation from stored typed routine result, skip/resume/reschedule and next scheduled day. UI tests + local persistence tests. Own Mobile only; root supplies shared model.
- [x] 5. Root: integrate all, focused affected suites, architecture and analysis, Mobile profile APK/Admin release Web builds, review and update active operational references plus PROGRESS_REPORT. No installation, activation, cloud calls or deployment.

## Review focus

- Switching accounts or expired authority during asynchronous work must not reveal or save prior Member progress.
- Existing enrollment retains its version and attempt linkage after Admin republishes or Member switches Programs.
- Skipped/partial/in-progress sessions never count as completed; measured and manual sets retain existing evidence labels.
- Rescheduling rejects overlap, duplicate dates and excessive consecutive same-group workouts across week boundaries.
- Unsupported exercises continue the existing manual tutorial path; rewards/accepted tuple gates stay unchanged.

## Decisions and evidence

- Direct local implementation in existing workspace; preserve unrelated work, no commits/push/deploy or APK install requested.
- Program catalog release requires the separately reviewed callable to be exported/deployed. Until then the normal app shows unavailable/empty with retry, never seeded sample Member data.
- Program enrollment stays local; existing explicit opt-in routine/workout backups remain the cloud evidence path. No new automatic personal-data upload.

## Final verification

172 domain + 135 backend + 87 Mobile + 37 Admin = 431 passing tests. Changed-file Dart analysis, architecture and both TypeScript checks pass. Mobile profile APK and private Admin release Web builds pass; evidence/hashes retained under build/workout-programs-20261027/. Fresh review found four issues (attempt pinning, date rollover, recovery labels, App Check retry); all were reproduced and fixed with regressions. No deploy, live content publication, Admin activation or APK installation. Program enrollment metadata stays local; custom-rest backup/report compatibility needs scoped releases.

## Owner-approved release complete

Owner answered “Yes, release all three components.” workoutProgramCommand and the two source-only backup/report validator updates are active; source hashes/runtime/environment/existing IAM verified. Inventory 70 with 67 other Functions, Rules/indexes and earning configuration unchanged. Private Admin served hashes and exact signed Xiaomi APK installation/launch/app-identity preservation verified; previous artifacts retained. Thirty extracted-package checks and 135 affected backend tests passed. No live Program publication or Member transaction. Signed-in UAT pending; enrollment metadata local. Evidence: build/workout-programs-20261027/release-verification.json.

## Owner-approved starter publication and authority compatibility closeout

- Existing catalog discovery found only two published Squat-based test Routines, so the owner explicitly approved creating reusable starter Routines and all three Programs with 3 sets × 8 reps and 60s rest (Curl per selected arm).
- Actual Admin documents exposed a global-role compatibility defect. Six regressions were added (three RED before fix); the optional global role condition now matches existing content/reporting authority. The owner separately approved its exact source-only release. 141 affected backend tests, 10 extracted-package checks and independent focused review (68 tests) pass; deployed source/runtime/environment/IAM and all other 69 Functions are preserved.
- Five new Routine blueprints/publications and three Program drafts/immutable v1s plus index/audit were created in one create-only 18-document transaction. Existing catalog/Routine/Admin records were verified unchanged. Actual reviewed payloads passed 174 Member-model/scheduler/dispatcher checks; verified Member + App Check discovery returned all three Programs with HTTP200. No Member progress/reward/role/AI registry change. Native UI stopped on URL confidence; browser access is disabled, so browser/physical UAT remains pending. Evidence: build/workout-programs-20261027/starter-program-closeout.json.
