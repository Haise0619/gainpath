# Beginner Foundations - 4 Weeks

Published 7 November 2026 in GainPath / `gainpath-0619`, organization `gainpath`, as Program `beginner-foundations-20261107`, version 1. The owner requested a replacement for Full Body Starter with three to four routines based on current active exercises. Three distinct routines were created.

| Suggested training day | Routine | Exercises and targets |
|---|---|---|
| Monday | Beginner Full Body Foundations | Squat 2×8; Dumbbell Shoulder Press 2×8; Standing single-arm dumbbell curl 2×8 per selected arm; Standing calf raise 2×10 |
| Wednesday | Beginner Upper Body Basics | Dumbbell Shoulder Press 2×8; Standing single-arm dumbbell curl 2×8 per selected arm; Standing Lateral Raise 2×8 |
| Friday | Beginner Lower Body Basics | Squat 2×8; Standing calf raise 2×10 |

Each routine uses a 60-second per-set rest prescription. The schedule repeats for four weeks: 12 workouts, active recovery between training days and Sunday rest. Members choose their start date and three training weekdays when enrolling. Estimated routine durations are planning estimates: 20 minutes full body and 15 minutes upper/lower body. The existing Member preference controls suggested between-exercise rest independently.

Only five currently active, exactly registered AI exercises are used. Existing setup, selected-arm handling, readiness, thresholds and result rules remain unchanged. Exercise tutorial metadata was copied through the existing validated projection. No exercise was activated, renamed or modified.

Active Burpee and Standard Floor Push-Up were omitted from this introductory template; unsupported modified push-up tracking was not invented. There is currently no active back-row exercise. Curl remains an arm exercise; this limited catalog template is not claimed to cover every major muscle group. The general schedule rationale follows [CDC guidance on muscle-strengthening activity](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html); that guidance does not validate this app's tracking or prescribe these exact exercises/targets.

## Full Body Starter removal

The live discovery index had already stopped offering the old Program. The remaining Member banner came from a locally saved active enrollment in the old Beginner 4-week Program, whose routine snapshot was Full Body Starter.

On the approved Xiaomi, the app was observed idle on the Workout hub. The exact journal and all relevant workout/game file hashes were retained before changing only `journal.activeId` to null and incrementing its revision from 16 to 17. The full old enrollment, schedule, progress and routine snapshots were preserved byte-for-byte as values. All 21 other protected files were unchanged. The app was relaunched without clearing data or installing an APK, and the changed journal was read back after startup. The new Program was not automatically enrolled or assigned a start date.

## Publication and verification

- Three new v2 blueprints and three published routine snapshots were created, plus one Program draft, immutable v1 and audit record. Only the previously empty Program discovery index was replaced. Atomic publication required current catalog sources, current verified Admin authority and create-only target preconditions.
- Existing exercises, the separate Testing routine, withdrawn legacy routines, previous Program versions and drafts were unchanged. No Member cloud records, account roles, rewards, Rules, Functions or indexes were modified.
- Current TypeScript source compiled successfully into an isolated verification directory. Existing server blueprint, exercise-execution, tutorial and Program validators accepted every authored record.
- Three focused Flutter tests passed against the actual Mobile models/store: routine capability/targets, 12-workout four-week schedule, and local enrollment deactivation preserving all saved enrollment values.
- Exact live readbacks matched every planned publication record. The current Member-authorized catalog business logic returned exactly the new Program and its three routines. This was a business-logic read against live records, not a new HTTP login or full phone walkthrough.
- Phone journal readback confirmed no active old enrollment, complete enrollment retention and no new enrollment. App relaunch was observed. Full exercise execution/pose accuracy was not re-tested in this content operation.

Private snapshots, source/record manifests, commit receipts, protected-file hashes, test logs and rollback instructions are retained under ignored `build/beginner-program-20261107/`. No private Member identifiers or journal content belongs in the repository.

## Stable publication identities

- `routine_v2_gp-beginner-foundations-full-body-20261107`
- `routine_v2_gp-beginner-foundations-upper-body-20261107`
- `routine_v2_gp-beginner-foundations-lower-body-20261107`
- Program: `beginner-foundations-20261107`, version 1.
