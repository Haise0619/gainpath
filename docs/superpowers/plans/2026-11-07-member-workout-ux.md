# Member workout UX implementation

Owner instruction: directly implement all requirements in the supplied Member Workout Experience UX Optimization document. Source audit: `docs/ux/member-routine-experience.md`. No further routine design approval is required.

## Design and invariants

Reuse the existing routes, RoutineJourneyController, Program controller and theme. Centralize execution-mode/target/result presentation; anchor exercise actions; make hub actions derive from compatible persisted attempts; add tutorial-to-execution only within an active attempt; distinguish all target-complete outcomes without inventing measurements. Timer interruption remains explicit-resume. Keep scheduling, attempt creation, codecs, camera consent, tracker algorithms and reward eligibility unchanged.

Ruling: continue the established `codex/hybrid-workouts` checkout; preserve unrelated dirty Admin, operational-reference and pose timing changes. Do not edit the pose preview controller/runtime or analyzer sources. Only explicitly owned files are staged. Build verification is required; physical acceptance is reported separately. No backend changes are needed.

Ruling: preserve eager attempt creation because making it lazy changes persistence semantics. Preview remains read-only. Between-exercise countdown is optional and deferred: the existing rest prescription is per set and adding another rest contract would risk inventing a target. The handoff remains explicit and never opens a camera automatically.

## Shared presentation contract (parent owns)

Create `apps/mobile/lib/features/workout/presentation/workout_presentation.dart` with:

- `WorkoutExerciseMode {aiTracked, videoTimed, manual, unavailable}`.
- `ExercisePresentation.forExercise(PublishedRoutineExercise exercise, {required String organizationId, ExerciseTrackerDispatcher trackers = const ExerciseTrackerDispatcher()})`.
- Fields/getters: `mode`, `label` (AI Tracked / Video Timed / Manual / Unavailable), `icon` (IconData), `targetLabel`, `restLabel`, `targetsWithRest`, `description`, `startLabel`, `provenance`.
- Presentation never grants execution authority. Explicit timed target/mode displays Video Timed; existing registry and resolver still authorize actual launches.
- Top-level `isExerciseTargetComplete(RoutineExerciseStatus)`, `exerciseStatusLabel(RoutineExerciseStatus)`, `exerciseResultSummary(RoutineExerciseResult)`, `workoutAttemptLabel(RoutineAttempt)` and `workoutDurationLabel(int microseconds)`.
- Results omit unsupported measured metrics. Timed = completed sets and active duration; manual = self-reported sets; measured = actual saved measured-session evidence.

## Task ownership and sequence

1. Parent: implement/test shared presentation contract, then timer/AI presentation controls, compact reward messaging and backup clarity. Preserve timer/controller logic. New tests pin mode identity, targets, provenance and no null/false zero metrics.
2. Hub implementer: own `workout_prep_route.dart`, `workout_prep_screen.dart`, `workout_hub_program.dart` if necessary, and new read-only hub-attempt presentation state. Derive free/scheduled action and progress from compatible actual checkpoints; represent rest/upcoming/missed days; preserve enrollment and catalog pagination. Own associated hub tests. Do not create checkpoints on preview or edit persistence models.
3. Journey implementer: own `routine_journey_route.dart`, `routine_journey_screen.dart`, `exercise_tutorial_route.dart`, `published_exercise_tutorial_screen.dart`, `routine_next_exercise_sheet.dart`, `routine_screen.dart` and their tests. Compact header/list, anchored primary action, truthful summary/icons, contextual tutorial launch preserving current attempt. Preview tutorials have no launch context. Do not edit shared helper, hub, Program/history or controllers without coordination.
4. Program/history implementer: own `workout_program_route.dart`, `workout_program_screen.dart`, `routine_history_screen.dart`, and tests. Typed mode/targets/results everywhere, date-aware headings, concise enrollment/recovery copy, truthful outcomes. No schedule algorithm or persistence changes.
5. Parent integration: review all changes against each requirement; improve execution controls using existing themes, safe areas and accessible semantics. Run focused Mobile tests/analysis and Android build, then broad independent review and regression fixes. Record exact files, checks, limitations and remaining optional work in the delivery document.

## Verification

- Red/green tests for typed AI/timer/manual presentation, completion icons, summary omission of unsupported metrics, tutorial launch identity and preview safety, free/scheduled resume and local recovery, timed back dialog, date headings and rest day.
- Small360px portrait and large text widgets: no overflow, anchored primary actions above SafeArea, visible loading/error/saved states.
- Preserve current checkpoint/signature, account switch, timer buffering/background/save retry and Program linkage tests. No new schema version or rewards activation.
- Use direct bundled Flutter SDK commands with the existing sandbox escalation for SDK cache writes. Logs under ignored `build/member-workout-ux-20261107/`.
- Run source analysis, affected tests, Android debug build; inspect release evidence before completion claims. Do not claim physical/device/UI acceptance from unit tests or builds.

## Completion record

Implemented and locally verified on 7 November 2026: 147 affected tests passed, strict analysis found no issues in 32 changed Dart files, and the Android debug build passed. See `docs/ux/member-workout-ux-implementation.md` for exact files, UX behavior, preserved invariants and physical-device limitations. Private execution and build evidence remains under ignored `build/member-workout-ux-20261107/`. No APK installation was performed while the connected app's idle state was uncertain.
