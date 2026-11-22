# Workout Flow Feedback Implementation Plan

**Goal:** Make rest and AI tracking easier to follow using presentation-only visual feedback.
**Architecture:** Reuse `BetweenExerciseRestController` and `MeasuredWorkoutSession`. Keep motion in focused widgets and preserve all capture/counting/business contracts.
**Tech Stack:** Flutter, existing GainPath theme and image component; no dependencies.
**Spec:** ../specs/2026-11-15-workout-flow-feedback-design.md

## Constraints and review focus
- Preserve unrelated local changes and use the current checkout.
- No camera/pose/counting/audio or domain changes.
- Pause/background must freeze or dismiss motion; resets and stale counts must not animate.
- Keep controls accessible at 320px, landscape and 200% text.
- Missing cover media must use the existing honest fallback.
- Animation frames must not rebuild or resize the camera viewport.

## Tasks
- [x] Rest: add progress/pause/media tests, observe failures, implement responsive rest layout and finite countdown pulse, run rest regressions.
- [x] Tracking: add event lifecycle tests, observe failures, implement isolated Ready/rep overlay and integrate above the stable camera viewport, run camera/continuation regressions.
- [x] Verify: render actual Flutter frames at multiple sizes and motion phases, inspect images, analyze changed files, build Android debug, review scoped diff and record limitations.

Execution: inline. Follow the user's complete requirements and repository authorization without additional approval steps. Keep changes uncommitted for review alongside the user's existing work.

Verification: 96 affected Mobile tests passed, including 10 new visual-event tests; eight scoped Dart files analyzed without findings; arm64 Android debug APK built. Gated `GAINPATH_RENDER_FLOW=true` Flutter test produced 14 actual page PNGs at 390×844, 320×640/200% text, and 844×390. Images, logs and APK hash are under `apps/mobile/build/workout-flow-feedback/`. Camera backgrounds are test fixtures, and offline font fallbacks use Barlow; these are not physical camera performance results. No Android device was connected, so installation and hardware profiling remain pending.

Independent review: fixed final rep suppression caused by automatic analyzer invalidation and corrected both-arm Curl numbering. Both issues were reproduced as failing tests before fixes. Final review found no remaining actionable issues. Animation-frame tests verify that camera viewport build count stays unchanged. No pose, counting, camera, audio or business-logic files were changed.
