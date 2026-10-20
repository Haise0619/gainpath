# Step 3 squat processing: implementation and validation

The user authorized Step 3 in parallel with the existing squat-flow chat. The
coordinating chat implemented geometry, calibration, phase tracking, scoring and
mobile orchestration. The other chat implemented corrective audio; its interface
and native verification are recorded in `2026-10-07-step3-audio-handoff.md`.

## Implemented boundary

`packages/gainpath_pose/lib/src/squat/` exposes `SquatAnalyzer`, `SquatRuleSet`,
`SquatGeometry` and immutable `SquatUpdate`/attempt values. The analyzer consumes
refined, unmirrored upright image landmarks, applies its own One Euro filter,
restores common pixel units for XY geometry, and locks a usable shoulder/hip/
knee/ankle side during standing calibration. It does not classify camera view.

Four phases distinguish full and partial attempts. Required-joint confidence,
capture/delivery timestamps and a no-frame watchdog freeze or invalidate unsafe
transitions. Valid and rejected intervals are accumulated separately; paused wall
time is excluded. Scoring applies bounded depth and sustained trunk-lean penalties
once per assessed attempt; it is null before an attempt. Confidence is separate.
No frontal knee-valgus, athlete IMU movement or inferred clinical measurement is
reported. Rule defaults remain provisional and are documented in `SquatRuleSet`.

`SquatProcessingController` connects these values to `WorkoutAudioController`.
It requires explicit side-view/upright setup confirmation, accepts refined poses
through `consumeRefined`, watches freshness every 100 ms, and handles preferences,
pause/background, close and account replacement. Capture times and `clockMicros`
must share a monotonic clock origin. The owner must forward foreground and auth
changes promptly and close/dispose the controller when the session ends. Feed
refined poses before preview smoothing to avoid filtering twice. The controller
owns the supplied audio controller; do not share one between sessions.

The existing workout route is not yet mounted to this boundary. Camera capture,
consent, saving, upload and real reward acceptance belong to subsequent steps.
No phone installation or backend deployment was performed for this slice.

## Review and automated evidence

Independent review found four defects, each reproduced by a failing regression
test and corrected: recovery crossing the tracking-loss timeout retained a cycle;
automatic side selection could prefer collapsed geometry; a close listener could
leave a watchdog timer alive; and foreground return did not notify observers.

- Pure pose suite: 46 tests passed, including 29 squat geometry/engine tests.
- Squat mobile integration: 8 tests passed, including a complete synthetic squat
  routed through the actual audio policy controller, watchdog loss, account
  isolation, duplicate/future input and lifecycle regression cases.
- Pure package and affected integration static analysis: no issues.
- Full mobile suite: 190 passed, 15 feature-flag-dependent tests skipped. Log:
  `apps/mobile/build/step3-mobile-tests.log` (local build output).
- Mobile `dart analyze lib test`: no issues. Unrestricted directory analysis also
  scans an older saved detector copy in `build/pose-quality/step2m/` whose relative
  imports are unresolved; that experiment artifact was preserved. The source-only
  pass above ran after parallel edits stabilized.
- Parallel audio handoff confirms 22 focused mobile tests, 11 native epoch
  assertions, clean focused analysis, and successful final Android profile Java/
  Kotlin compilation (161 tasks). See the audio handoff for commands and limits.

## Acceptance still requiring real evidence

Fixtures here are analytic synthetic trajectories, including irregular timing,
bounded standing jitter, missing joints, incomplete depth and sustained lean.
The repository does not contain labeled recorded-person squat landmark fixtures.
Synthetic fixtures verify logic but cannot establish real rep/correction accuracy,
angle error, user generalization, inference latency or audible feedback timing.

Before treating Step 3 as physically validated, replay consented labeled side-view
recordings and compare complete/partial counts, false corrections, missed
corrections and detection delay. Include slow/fast reps, occlusions, startup at the
bottom, clothing/lighting variations and different body proportions. Measure on
the target phone with one monotonic clock: capture-to-inference, analysis cost,
capture-to-feedback and speech onset, reporting median/p95 and dropped frames.
Agree acceptance targets before tuning the provisional thresholds. The 150 ms
phase dwell and smoothing intentionally affect response time; no latency or
accuracy improvement is claimed from these synthetic tests.

The initial audio adapter uses installed offline Android TTS, not a prerecorded
soundbank. Soundbank assets and its proposed fast-path target remain outstanding.
Step 2 pose-quality acceptance also remains outstanding. These limits do not
prevent reviewing and testing the isolated Step 3 software boundary.
