# Complete Workout experience optimization — implementation

Date: 7 November 2026. Branch: `codex/hybrid-workouts`; baseline `7affa0a`. Implements Phases 1–4 of [the optimization plan](workout-page-optimization-plan.md), with the owner's explicit emphasis on UI/UX. This report records implemented Flutter behavior, not a proposed redesign.

## A. Executive summary

All four phases are integrated into the existing application. The Workout hub is more compact, separates free/scheduled context, shows actual saved exercise statuses and offers visible Settings access. Program selection previews actual routine assignments and recovery frequency; End current plan clears only active selection. Exercise setup, tutorials and execution messages are easier to scan, with explicit required view and reachable primary actions. Results, history, analytics, backup and equipment information distinguish supported measurements from estimates and unavailable data.

Existing purple branding, components, controllers and routes remain. No tracker, counting threshold, timer-credit algorithm, schedule algorithm, backend schema, cloud catalog or reward policy was changed. Unrelated pending Admin and pose instrumentation work is excluded from the feature files and isolated APK.

## B. Phase-by-phase changes

### Phase 1 — Trustworthy information

- Shared targets handle `1 set`/`1 rep`, typed timed duration per set and rest between sets. Side/arm/bilateral qualifiers continue to come from exact registered tracker capabilities.
- Completed hub cards no longer tell the Member to choose another exercise; supporting copy and summary/calendar/play icons reflect the actual completed or recovery context. Scheduled completed attempts open Summary rather than advertising unfinished work.
- The four supplied camera images remain unchanged and in order. General guidance labels the side-view illustration as an example and defers the required view to each exercise's setup.
- Rest messaging distinguishes AI setup/readiness, video preparation and explicit Manual logging. Paused AI and timed messages explain that work is not credited while paused; buffering and video readiness remain visible prerequisites.

### Phase 2 — Workout hub and Programs

- Replaced the oversized decorative photo hero with a compact neutral purple overview. Reduced wasted vertical spacing while retaining a dominant action, exercise list, browsing, pagination, refresh and secondary tools.
- Exercise rows now project saved status from the matching existing attempt entry; previews do not create attempts. Free-workout choices explain that they do not change the training plan.
- Workout Settings is reachable from the hub and journey, using the existing account-scoped Privacy & AI Tracking / Workout Preferences page and store.
- Program onboarding shows actual published routine sequence, frequency/recovery information and inline required-weekday validation. It does not hardcode the Beginner Program's three routines.
- Before a **new enrollment**, discovery is refreshed and the chosen ID/version/published data must still match. Withdrawal or discovery failure blocks new enrollment; existing saved schedules remain independent.
- End current plan asks for confirmation, explains history retention, increments the journal revision and clears only activeId through `WorkoutProgramController` and the existing store. Cancel, write conflict and revoked-account cases preserve the active plan and saved enrollment. The UI does not invent an Ended or Completed domain state.

### Phase 3 — Preparation and execution

- Six exercise setup screens reuse an explicit Front/Side view banner and SafeArea action bar with at least 56px action height. Arm/leg selections, required checkboxes and exercise-owned start guards remain in place.
- At 200% text the banner removes redundant explanatory copy, allowing the exercise name and targets to appear before the sticky camera action. Required positioning instructions remain in the scrollable content.
- Tutorials put targets and essential information before secondary media/details. Written instructions remain when video is absent; loading, unavailable media and playback retry retain distinct behavior. Contextual Start Exercise/Open Set Logger still returns through the same attempt.
- AI/timed/rest presentation was refined without modifying their session engines. Existing large counts, camera priority, sticky controls, manual logging, saved-before-rest ordering, readiness and interruption behavior are preserved.

### Phase 4 — Results, history, analytics and tools

- Measured summaries lead with saved status and supported values, have a sticky return action, and group detailed measurement limits below an expansion control. Unsupported scores remain unassessed rather than zero.
- Routine history distinguishes an attempt from its component camera sessions. Optional cross-links are exposed only for session IDs available under the current account and matching exercise identity; opening one does not add completion credit.
- Progress, activity, performance, form and reports explain the population behind camera charts and separate Timed/Manual routine progress. Form explanations distinguish unassessed data from 0%; aggregation/scoring calculations are unchanged.
- Backup leads with enablement, known/unknown last success, pending/backed-up counts and conflicts, then explains inclusion/exclusion and recovery. No success timestamp is fabricated. Local save, optional backup and local-only training schedules remain distinct.
- Equipment scanning retains suggestion/confirmation semantics and manual browsing; recovery controls can wrap on narrow screens. Detail pages prioritize written setup/safety and truthful media availability. Missing equipment-to-exercise relationships remain explicitly unconnected.
- Standalone preview states that no workout is recorded. Existing permission, retry and exit ownership remain with the preview controller.

## C. Files and responsibilities

The exact application/test manifest is listed below. In general: routing wires existing scoped destinations and history links; shared presentation owns labels; setup widgets own layout only; the Program controller owns the sole new journal command; analytics changes are explanatory presentation only. Focused regression tests cover those boundaries. Plan/report documents and isolated completion notes in the seven operational references accompany the implementation.

## D. Before and after

| Before | Implemented behavior |
|---|---|
| Large photo pushes useful controls down | Compact purple overview with immediate action and visible Settings |
| Completed card can still instruct exercise selection | Completion-specific supporting copy and summary icon/action |
| Program contents unclear before enrollment | Real routine sequence/frequency/recovery preview |
| Old active plan needs operational intervention to clear | Confirmed End current plan using revision-safe app controller/store |
| General guide appears to demand side view universally | Explicit example plus exercise-owned required view |
| Setup instructions and action compete for scroll space | Required-view banner, grouped content and sticky Start camera |
| Detailed score/limit text competes with saved results | Key supported result first; measurement details below |
| Routine versus exercise history ambiguous | Clarified record types and exact-ID saved-session links |
| Backup status spread through explanatory text | Summary of state, timestamp availability and queued records first |

## E. Data integrity and boundaries

Attempt IDs, Program associations, frozen snapshots, local checkpoints, measured sessions and account/organization guards remain authoritative. End current plan preserves every enrollment and result; it does not delete or complete anything. No selection/preview creates an enrollment. Current discovery is checked only for new enrollment, not used to erase historical schedules.

Consent, camera permission, calibration, live withdrawal, camera lifecycle, timed active-credit rules, per-set and between-exercise rest, Auto-Continue single-flight logic, save retry and manual set confirmation remain intact. This task introduces no alternate execution architecture. Optional backup contracts and held rewards are unchanged; no automatic voice subsystem or fabricated result was added.

Existing working-tree changes were recorded before implementation. Pre-existing Admin identity files, pose preview timing code, its untracked runtime/test files and the unrelated Module 2 report are not part of this feature. Operational documents receive only isolated new notes in the commit.

## F. Verification

- **366 tests passed; zero failures** in the final **73-file affected regression suite**. This is not the whole monorepo suite.
- Strict analysis: **50 changed Dart files, no issues**. A further targeted setup/layout/render run passed after the final large-text-only refinement; the remaining source was unchanged.
- Opt-in hub rendering passed with bundled fonts. Normal/200%-text setup and measured-result rendering also passed and was inspected. Visual inspection prompted the banner refinement rather than relying only on overflow tests.
- Coverage includes hub state/CTA/footer, 320/360px and 200% text, Program preview/end/cancel/conflict/future enrollment/withdrawal, consent and capture boundaries, mixed-mode continuity, inactive-time exclusion, history/results, analytics, backup and equipment failures.
- Early failures were investigated: actual offscreen/lazy test interactions were corrected; tutorial assertions now use scoped rest labels. Two app startup timeouts reproduced against the pre-change export. Completing those tests' explicit injected graph with in-memory Program/checkpoint stores resolved them without production changes or weakened assertions.
- Android debug APK builds from an isolated committed-source export plus the owned changes; dependency lock is retained. The final refinement is included in the final build evidence.
- **No APK installation or physical exercise/accessibility acceptance in this task.** The approved phone was connected, but its black screen did not establish a safe idle state. The existing APK/data were preserved. Synthetic fixtures and renders do not prove pose accuracy, TalkBack usability or native camera/video performance.
- Root integration/diff review was completed. Subtasks supplied focused checks, but final independent reviewer availability was limited by agent account usage limits; no independent whole-feature approval is claimed.

Private test/file manifests, logs, isolated source, screenshots, source hashes, build and prior-APK/device preflight evidence are under ignored `build/workout-four-phases-20261107/`. The installed app has not been replaced by this update.

## G. Remaining limitations and external dependencies

1. No stable live equipment-to-exercise relationship contract exists. The honest unavailable state is retained; no name matching or backend expansion was introduced.
2. Historical backup timestamps can be unknown; the UI says so. Program schedules, AI consent and preferences are not silently added to backup.
3. Clearing active selection does not persist an explicit Ended status. Retained enrollment snapshots stay history; no unsupported lifecycle state is shown.
4. Complete physical checks on an idle device: TalkBack focus/order, gym lighting/contrast, reachability, long-name scrolling, real permission revocation, background/lock interruption, buffering and fresh enrollment through authenticated HTTP.
5. No new backend/Rules deployment, catalog mutation, account-role change or data migration is required.

## H. Git integration

The final integration is committed as one cohesive change because the shared copy/layout changes and their exact-label regression updates span all four phases. The implementation plan, review plan and this report are included. The exact commit hash is reported in the final delivery; baseline is `7affa0a`. Unrelated working changes remain unstaged.

## Exact application and test paths

- `apps/mobile/lib/app/routing/member_progress_route.dart`
- `apps/mobile/lib/app/routing/routine_journey_route.dart`
- `apps/mobile/lib/app/routing/workout_prep_route.dart`
- `apps/mobile/lib/features/analytics/presentation/member/activity_timeline_screen.dart`
- `apps/mobile/lib/features/analytics/presentation/member/goal_comparison_report.dart`
- `apps/mobile/lib/features/analytics/presentation/member/posture_accuracy_screen.dart`
- `apps/mobile/lib/features/analytics/presentation/member/widgets/workout_measurement_scope.dart`
- `apps/mobile/lib/features/analytics/presentation/member/workout_performance_screen.dart`
- `apps/mobile/lib/features/analytics/presentation/member/workout_report_screen.dart`
- `apps/mobile/lib/features/analytics/presentation/shared/progress_dashboard_screen.dart`
- `apps/mobile/lib/features/workout/application/workout_program_controller.dart`
- `apps/mobile/lib/features/workout/presentation/member/between_exercise_rest_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/calf_raise_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/camera_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/curl_arm_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/equipment_browse_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/equipment_scanner_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/guided_timed_workout_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/lateral_raise_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/pose_preview_view.dart`
- `apps/mobile/lib/features/workout/presentation/member/published_exercise_tutorial_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/published_routine_catalog_controls.dart`
- `apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart`
- `apps/mobile/lib/features/workout/presentation/member/reverse_lunge_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/routine_history_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/row_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/shoulder_press_setup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/widgets/exercise_setup_layout.dart`
- `apps/mobile/lib/features/workout/presentation/member/widgets/workout_session_sheet.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_backup_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_program_screen.dart`
- `apps/mobile/lib/features/workout/presentation/member/workout_result_screen.dart`
- `apps/mobile/lib/features/workout/presentation/shared/equipment_detail_screen.dart`
- `apps/mobile/lib/features/workout/presentation/workout_presentation.dart`
- `apps/mobile/test/calf_raise_setup_test.dart`
- `apps/mobile/test/curl_arm_setup_test.dart`
- `apps/mobile/test/exercise_setup_layout_test.dart`
- `apps/mobile/test/member_equipment_test.dart`
- `apps/mobile/test/member_local_progress_flow_test.dart`
- `apps/mobile/test/published_tutorial_test.dart`
- `apps/mobile/test/routine_journey_flow_test.dart`
- `apps/mobile/test/workout_backup_ui_test.dart`
- `apps/mobile/test/workout_hub_state_copy_test.dart`
- `apps/mobile/test/workout_phase4_ux_test.dart`
- `apps/mobile/test/workout_prep_action_hierarchy_test.dart`
- `apps/mobile/test/workout_presentation_test.dart`
- `apps/mobile/test/workout_program_controller_test.dart`
- `apps/mobile/test/workout_program_ui_test.dart`
