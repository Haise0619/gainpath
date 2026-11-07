# Member workout UX implementation

Implemented 7 November 2026 on `codex/hybrid-workouts`. This is the implementation follow-up to [the source-based journey audit](member-routine-experience.md). It improves the existing Flutter journey rather than replacing its execution or persistence architecture.

## A. Implementation summary

Members now see the next action derived from compatible saved progress, consistent exercise modes and targets, and reachable primary controls through preparation, execution and completion. Tutorials opened from an active attempt can enter the existing execution flow. Summaries distinguish measured, timed and self-reported work without inventing AI evidence.

The existing purple theme, controllers, capability registry, measured session engines, guided timer, local stores and navigation remain the foundation. No new package, backend deployment, schema migration or content mutation is required.

## B. Exact application and test files

Paths below are relative to the repository root.

| File | Purpose |
|---|---|
| `apps/mobile/lib/app/routing/exercise_tutorial_route.dart` | Typed contextual tutorial outcome; previews cannot start an attempt. |
| `apps/mobile/lib/app/routing/guided_timed_workout_route.dart` | Explicit return-to-paused-workout wording; injectable clocks for deterministic tests with unchanged production defaults. |
| `apps/mobile/lib/app/routing/routine_journey_route.dart` | Tutorial handoff rechecks account, attempt, day and exercise before using existing execution; injectable store factories retain production defaults. |
| `apps/mobile/lib/app/routing/workout_prep_route.dart` | Read-only checkpoint projection and refresh after returning; account-scoped free and scheduled actions. |
| `apps/mobile/lib/app/routing/workout_program_route.dart` | Date-neutral error heading. |
| `apps/mobile/lib/features/workout/application/workout_hub_attempt.dart` | New compatible saved-attempt projection for hub actions and completion counts. |
| `apps/mobile/lib/features/workout/application/workout_hub_program.dart` | Actual scheduled attempt and date-aware recovery projection. |
| `apps/mobile/lib/features/workout/presentation/workout_presentation.dart` | Shared typed modes, targets, statuses, result summaries and provenance. |
| `apps/mobile/lib/features/workout/presentation/member/guided_timed_workout_screen.dart` | Prominent phase, time and set progress; anchored controls and paused-rest clarity. |
| `apps/mobile/lib/features/workout/presentation/member/published_exercise_tutorial_screen.dart` | Contextual anchored start/logger action and shared target presentation. |
| `apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart` | More readable coaching cue text. |
| `apps/mobile/lib/features/workout/presentation/member/routine_history_screen.dart` | Typed results, truthful metrics and anchored recovery/next-day actions. |
| `apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart` | Compact progress and exercise list; anchored selected-exercise and summary actions; accurate completion icons. |
| `apps/mobile/lib/features/workout/presentation/member/routine_next_exercise_sheet.dart` | Consistent next-exercise mode, target and instructions using actual organization context. |
| `apps/mobile/lib/features/workout/presentation/member/routine_screen.dart` | Consistent routine-preview targets and capability context. |
| `apps/mobile/lib/features/workout/presentation/member/widgets/routine_workout_reward_panel.dart` | Concise unavailable-points explanation; restrictions unchanged. |
| `apps/mobile/lib/features/workout/presentation/member/widgets/workout_session_sheet.dart` | Larger essential controls and complete action semantics. |
| `apps/mobile/lib/features/workout/presentation/member/workout_backup_screen.dart` | Explicit local-only training schedule limitation. |
| `apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart` | State-derived primary action, scheduled/free distinction, progress, date/rest-day display and secondary-tool hierarchy. |
| `apps/mobile/lib/features/workout/presentation/member/workout_program_screen.dart` | Date-aware schedule headings and typed targets/results. |
| `apps/mobile/test/guided_timed_workout_flow_test.dart` | Paused-back behavior, stable clock seam and small-screen large-text controls. |
| `apps/mobile/test/member_journey_ux_test.dart` | Tutorial-to-execution identity, manual no-credit navigation, truthful completion and anchored large-text UI. |
| `apps/mobile/test/published_tutorial_test.dart` | Updated consistent target presentation. |
| `apps/mobile/test/routine_camera_continuity_test.dart` | Existing transition/consent regression expectations. |
| `apps/mobile/test/routine_completion_actions_test.dart` | Summary action semantics. |
| `apps/mobile/test/routine_history_ui_test.dart` | Truthful history presentation. |
| `apps/mobile/test/routine_journey_flow_test.dart` | Updated journey and summary assertions. |
| `apps/mobile/test/workout_hub_attempt_test.dart` | Compatible signatures, resumable partial attempts and completed summaries. |
| `apps/mobile/test/workout_hub_program_test.dart` | Date-aware scheduled hub expectations. |
| `apps/mobile/test/workout_presentation_test.dart` | Mode identity, targets, provenance and absence of fabricated metrics. |
| `apps/mobile/test/workout_program_ui_test.dart` | Hybrid timed targets, upcoming date and small-screen presentation. |
| `apps/mobile/test/workout_rewards_status_test.dart` | Disabled rewards remain disabled with concise wording. |

Documentation: this report, the historical audit notice, `docs/superpowers/plans/2026-11-07-member-workout-ux.md`, and scoped status notes in the seven operational references. Pre-existing Admin, pose instrumentation and Module 2 report edits are outside this implementation.

## C. Member interactions by stage

| Stage | Resulting experience |
|---|---|
| Discover and prepare | Browse when no selection exists; Start for new work; Continue for an open compatible attempt; View Workout Summary for completed work; Resume Unfinished Exercises for finished partial work. A rest day leads to View Training Schedule. Free selection preserves enrollment. |
| Routine journey | Compact routine/day/progress header, flexible exercise list, explicit selected exercise and bottom action above the system safe area. Existing skipping, early finish and manual set logging remain available. |
| Learn and start | Active-attempt tutorials offer Start Exercise for measured/timed modes. Manual offers Open Set Logger, returning to the same selected logger without logging anything. Catalog previews have no start action. Measured execution still requires existing setup and consent. |
| Execute AI | Existing camera, readiness and counting flow; larger essential controls, readable coaching text and complete semantic action labels. |
| Execute timed | Prominent work/rest/paused phase, countdown and set progress, persistent Start/Pause/Resume/Next-set/Skip controls. Leaving the back dialog returns to a paused session; explicit Resume is required. Tutorial looping remains owned by the existing player/controller. |
| Transition | Existing saved-result next-exercise handoff shows typed targets and mode, tutorial access, explicit start and return choices. It does not activate the camera automatically. |
| Complete | Timed/manual completion has success indicators. Unsupported AI aggregate sections are omitted when no measured evidence exists. Resume, next-day or return action is anchored. |
| Schedule and history | Upcoming/missed dates are distinguished from today; timed prescriptions use seconds. History identifies actual measured results, timed active duration and self-reported sets. |
| Recover and back up | Compatible checkpoints drive resume actions. Training schedules are explicitly described as local and excluded from backup. Disabled workout points remain disabled. |

## D. Logic and data integrity

- Capability presentation uses the registered identity and organization, never exercise names alone. Presentation does not grant permission to execute a tracker.
- Contextual tutorial results are accepted only for the same live attempt and day under the current account; execution uses the existing dispatcher. Manual navigation grants no set credit.
- Existing attempt creation timing is preserved. Hub preview reads checkpoints and does not create a new attempt. Delaying the journey's existing eager checkpoint would require a separate persistence/navigation change and was intentionally not included.
- Routine signatures, account/organization boundaries, selected exercise persistence, scheduled day linkage, enrollment, completion semantics, retry and local history contracts are unchanged.
- No timer controller, timer credit rule, pose analyzer, counting threshold, camera consent or supported tracker was changed by this feature. Injected route clocks are optional and production retains the original monotonic/UTC defaults.
- Timed completion reports sets and active duration; manual completion remains self-reported. Neither is converted into repetitions, pose scores or AI verification.
- No continuous cloud sync, schedule backup or reward issuance is implied or introduced. Firebase authorization, optional backup and Module 13 exclusions are preserved.
- Optional between-exercise rest countdown was not added: existing values prescribe per-set rest, and reusing them as a new between-exercise contract would invent behavior. The existing explicit handoff and timed per-set rest remain.

## E. Verification and limits

Final affected regression run: **147 passed, zero failed**, across 29 test files. It includes shared presentation and hub tests, actual tutorial route identity/manual-no-credit tests, journey/history/timer UI, controller and progress persistence, schedule controller/store/UI, backup integration, registry/resolver, plan signatures and camera continuity. This is an affected-module run, not a claim that the entire monorepo suite ran.

Strict Flutter analysis: **no issues in all 32 changed Dart files**. Journey and timed screens were exercised at 360×640 with 200% text and bottom safe-area padding; existing narrow Program cases were retained. A separate opt-in hub render test passed using bundled fonts and its fresh screenshot was inspected. A scoped independent code review found no remaining actionable issue after the manual tutorial action was corrected.

The final Android debug APK builds successfully. Private logs, exact test path list, render evidence, source hashes and APK are retained in ignored `build/member-workout-ux-20261107/`. The APK includes the current checkout, including pre-existing pose instrumentation outside this feature; this report does not claim those unrelated edits were implemented or independently accepted here.

No new APK was installed during this task: the connected phone had a running GainPath process and a safe idle state could not be established. Existing app data and any unsaved activity were preserved. Automated widgets, source review and a successful build do not establish physical-device acceptance.

## F. Remaining recommendations

1. Complete an in-place installation when the existing phone is idle, then walk through a mixed routine, background/resume, real video failure/recovery and partial-workout reopen without clearing app data.
2. Check TalkBack traversal, camera-overlay visibility, contrast in gym lighting, touch reach and audio/video behavior on the physical phone. Automated large-text checks cannot establish these qualities.
3. Consider optional between-exercise rest only with an explicit prescription/recommendation contract. Treat any change to eager attempt creation as a separately reviewed persistence change.

No new voice subsystem, reward activation or unrelated feature is required for this UX integration.
