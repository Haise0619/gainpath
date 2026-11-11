# Routine Journey Page UI/UX Redesign

**Date:** 11 November 2026  
**Scope:** `apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart`  
**Target:** Member Workout Journey Experience (launched when tapping "Start Workout" from Workout Prep / Catalog)

---

## 1. Executive Summary & Before / After UI/UX Improvements

The Member Routine Journey Page was redesigned from a cluttered workout dashboard into a clean, modern, action-focused Workout Journey following fitness app design patterns (inspired by Hevy, Fitbod, and Nike Training Club) while maintaining GainPath's signature purple (`#6D28D9`) branding.

| Area | Before | After |
| :--- | :--- | :--- |
| **Information Flow** | Mixed progress indicators, bulky 3-line tiles, duplicated middle progress bar, confusing buttons | Clear single-column hierarchy: **Header Progress → Compact Exercise List → Current Exercise Focus → State-Aware Sticky Action Bar** |
| **Header & Progress** | Heavy purple panel with large redundant text, unstyled dropdown, lengthy 2-line storage explanation | Modern rounded white card, compact `X of Y completed` counter, clean purple progress bar with neutral lavender track, concise "Saved on this device" micro-copy, and Day dropdown shown only when multiple days exist |
| **Duplicate Elements** | Mid-page second progress bar (`completed / total exercises complete`) duplicating top panel | Completely removed duplicate progress bar; freed ~60px vertical screen space |
| **Exercise List** | Chunky 3-line tiles, bulky text subtitles, ambiguous completion states | Sleek, compact cards (~52px height) with numeric index / green check avatar, exercise name, mode chip (`AI Tracked`, `Video Timed`, `Manual`), target sets/reps, active exercise purple accent border, and clear Done / Active / Next indicators |
| **Current Exercise Card** | Unfinished vs. finished states mixed with confusing Skip/Start buttons, missing camera positioning guidance | Clear state branching: completed exercises show verified reps summary and tutorial without misleading actions; unfinished exercises display form cues, essential camera view setup hints (Front view, Side view, Floor side view), and clean action buttons |
| **Primary CTA Bar** | Overlapping/conflicting buttons, non-responsive large-text overflow | Sticky, opaque bottom action bar with `SafeArea`, state-aware primary CTA (`Start AI Workout` / `Resume Timed Workout` / `Continue to Next Exercise` / `View Workout Summary` / `Mark set X done`) + secondary `Tutorial` button, with 140px bottom list padding to eliminate tap occlusion |
| **Screen Responsiveness** | RenderFlex overflow on 320px/360px screens at 200% text scaling | All text wrapped in constrained rows with `FittedBox` / `Expanded`, ensuring `< 616px` button bounds on 360×640 screens at 2.0x font scaling |

---

## 2. Updated Information Hierarchy

The screen follows a strict, intuitive sequence:
1. **Workout Progress Header Card:**
   - Routine title and current day indicator (dropdown selector only visible when `routine.days.length > 1`).
   - Compact progress text (`X of Y completed`) and status badge (`In progress` in purple or `Finished` in green).
   - Single linear progress indicator (GainPath purple `#6D28D9` fill on `#EDE9FE` track).
   - Local persistence indicator ("Saved on this device") with accessible information tooltip.
2. **Exercise Schedule List:**
   - Compact, tappable rows representing each exercise in the routine.
   - Circular leading avatar with exercise index number, or green checkmark for completed exercises.
   - Clean title, execution mode badge (`AI Tracked` / `Video Timed` / `Manual`), and target prescription.
   - State indicators: `Active` (active purple border for current selection), `Next` (subtle accent for next unfinished exercise), or `Done` (green text & check icon).
3. **Selected Exercise Focus Card:**
   - **For Unfinished Exercises:**
     - Exercise name and mode chip.
     - Prescribed sets, reps, and rest duration.
     - Form cue callout (`💡 Form Cue: ...`) if defined by coaches.
     - Camera setup guidance (`Front camera view · Stand facing camera with full body visible` / `Side camera view · Place device 2m away facing your profile` / `Floor side view · Place device on floor 2-3m away facing your side`).
     - Specific execution mode details (elapsed video time, AI retries, self-reported set logging with undo).
     - Secondary actions: `Watch exercise tutorial` and `Skip exercise`.
   - **For Completed Exercises:**
     - Green completion header (`✓ Exercise completed`).
     - Summary of recorded repetitions across saved sessions (AI verified reps, timed sets, or self-reported sets).
     - `Watch exercise tutorial` secondary action.
     - Misleading Start/Skip actions are cleanly omitted.
4. **Finish / Summary Access:**
   - Subtle `Finish early` / `Finish routine` action at bottom of list with confirmation dialog.
5. **Sticky State-Aware Action Bar:**
   - Sticky bottom container with white background, subtle elevation shadow, and top hairline border.
   - Real-time exercise title & target preview.
   - Dynamic primary action button based on authoritative workout state:
     - Unstarted exercise → `Start AI Workout` / `Start guided exercise`
     - Interrupted AI session → `Retry AI Workout`
     - Interrupted Timed session → `Resume Timed Workout`
     - Manual exercise set logging → `Mark set X done`
     - Completed exercise with remaining targets → `Continue to Next Exercise`
     - All targets complete → `View Workout Summary`
   - Secondary `Tutorial` button for quick instruction reference without leaving the journey.

---

## 3. State-Aware Primary Action Logic

```text
                           ┌────────────────────────┐
                           │ User views Routine Day │
                           └───────────┬────────────┘
                                       │
                      ┌────────────────┴────────────────┐
                      ▼                                 ▼
           [Exercise Complete?]               [Exercise Incomplete]
             /            \                             │
           YES             NO                           │
           /                \                           ▼
   [Remaining targets?]      │                 [Execution Mode?]
     /           \           │            ┌─────────────┼─────────────┐
   YES            NO         │            ▼             ▼             ▼
    │              │         │       [AI Tracked]    [Timed]       [Manual]
    ▼              ▼         │            │             │             │
"Continue to   "View Workout │            ▼             ▼             ▼
Next Exercise"    Summary"   │     "Start AI      "Start guided  "Mark set
                             │      Workout"       exercise"      X done"
                             │     (or "Retry")  (or "Resume")
```

---

## 4. Modified Files

- `apps/mobile/lib/features/workout/presentation/member/routine_journey_screen.dart`:
  - Replaced bulky `Panel` with `_buildHeaderCard` featuring single progress summary, dynamic day selector, and local save status.
  - Eliminated duplicate middle progress bar.
  - Added camera setup hints (`_cameraHint`) mapping `ExerciseTracker` to front/side/floor camera positioning guidelines.
  - Redesigned exercise rows into compact modern cards with clear active/next/done states.
  - Implemented state-aware completed vs. unfinished views in the Current Exercise Section.
  - Styled sticky bottom navigation bar with responsive layout, opaque white container (`#FFFFFF`), subtle top border (`#E9E5F0`), and state-aware primary action.
  - Fixed white-on-white text defect above the "Start workout" button by explicitly applying `AppColors.ink` (`#190F2E`) for exercise title and `AppColors.inkSoft` (`#6B6488`) for targets, eliminating reliance on undefined `titleSmall` / `bodySmall` theme tokens.
  - Eliminated large bottom blank space by replacing 140px bottom padding and redundant safe-area `SizedBox` with balanced `EdgeInsets.fromLTRB(16, 8, 16, 24)`.

---

## 5. Verification Results

### Scoped Static Analysis
```powershell
flutter analyze lib/features/workout/presentation/member/routine_journey_screen.dart
```
**Result:** `No issues found! (ran in 0.9s)` (0 errors, 0 warnings, 0 infos).

### Flutter Regression Test Suite
```powershell
flutter test test/member_journey_ux_test.dart test/routine_journey_flow_test.dart test/routine_completion_actions_test.dart test/routine_history_ui_test.dart test/routine_journey_controller_test.dart test/workout_continuity_flow_test.dart
```
**Result:** **37 / 37 PASS** (0 failures, 0 skips).
- `test/member_journey_ux_test.dart`: 5/5 passed (small phone 360×640 layout at 200% text scale verified, action rect bottom $\le 616$px).
- `test/routine_journey_flow_test.dart`: 6/6 passed (tracking unavailable, manual set logging, instructions reviewed, and automatic summary transition).
- `test/routine_completion_actions_test.dart`: 2/2 passed (summary actions, progress view, and next day progression).
- `test/routine_history_ui_test.dart`: 4/4 passed (history isolation, attempt rendering, small-screen detail).
- `test/routine_journey_controller_test.dart`: 11/11 passed (checkpoint reconciliation, manual sets, multi-day restore).
- `test/workout_continuity_flow_test.dart`: 9/9 passed (auto-continue, camera backgrounding, rest transitions, failure recovery).

---

## 6. Physical-Device Verification Requirements & Commit Details

- **Commit Hash:** `83219a3` (branch `codex/hybrid-workouts`)
- **Debug APK Artifact:** `build/app/outputs/flutter-apk/app-debug.apk`

Before performing physical user acceptance testing on mobile hardware (e.g., Xiaomi 7c4cbff):
1. **Device Connection:** Ensure the target device is connected via ADB and recognized with `adb devices`.
2. **Safe Install:** Install only debug APK (`gainpath-debug.apk`) using normal `--debug` flags; do not force overwrite protected app data.
3. **Screen Density Check:** Validate UI on physical display at standard font scale (1.0x) and accessibility font scale (1.5x–2.0x).
4. **Navigation Flow:**
   - Tap "Start Workout" on an active routine.
   - Verify Header shows single progress bar and accurate `X of Y completed`.
   - Tap through exercises in the list; ensure active purple highlight updates smoothly.
   - Test "Start AI Workout", complete 1 rep, return, and confirm sticky CTA changes to "Continue to Next Exercise".
   - Test manual exercise, log set, verify "Mark set 2 done" updates without list occlusion.
