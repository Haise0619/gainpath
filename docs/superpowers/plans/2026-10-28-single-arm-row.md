# Single-arm dumbbell row implementation

Owner request: implement directly, prioritizing responsiveness, stability and smoothness. Local implementation/build/tests only; cloud content publication, deployment and APK installation require their own scope. Preserve existing uncommitted Program work and all existing detector/counting behavior.

## Design and alternatives

Use existing BlazePose, GPU/CPU fallback, latest-frame scheduling, fresh unfiltered analysis callback and responsive overlay. Add isolated side-view row geometry/analyser. A curl-only elbow-angle counter would confuse curls with rows; a new neural model/dependency adds unvalidated latency and training requirements. Chosen implementation combines selected-arm elbow angle with upper-arm travel relative to a calibrated near-horizontal torso, timestamp-based hysteresis/dwell and a small adaptive scalar filter. No smoothing of stale or missing motion and no inferred 3D spine/rotation/load/bench-contact assessment. The model's projected observations are provisional, with no fabricated form score.

Selected arm is explicit (left/right), one side per session; targets apply to that selected arm and remain supplied by the Routine. Save the side in typed local metrics schema 3, version `single-arm-row-side-v1`; preserve schemas 1/2. New row records are provisional backup data only. Approved workout acceptance/rewards remain held. Do not overwrite published Program v1s or enroll Members.

## Interfaces and ownership

- Pose: `RowSide {left,right}`, `RowPhase {ready,pulling,lowering}`; `RowAnalyzer({required RowSide side})`, `snapshot`, `update(PoseFrame,{required int nowMicros})`, `tick({required int nowMicros})`, `pause()`, static `version`, `maximumFrameAgeMicros`; `RowGeometry.confidence/fromFrame`, `neutral`. Update exposes existing measured-analysis fields plus calibration cue/progress, phase and side. No sets/reps in analyser.
- Identity: exact registry `gainpath/single-arm-dumbbell-row-side-v1`, capability tracker `single_arm_row_side_v1`, side view.
- Metrics: optional `rowSide` string left/right, required only for row scoring version, schema 3; old versions remain unchanged and cannot carry row-only metadata.
- App: isolated `RowWorkoutSession` implementing existing measured contract; explicit setup before opening camera, normal consent/session/account/foreground guards, local result/save/return to pinned Routine. App-owned dispatcher and prep labels use exact registry identity. No backend workout submission.

## Execution

1. Pose component: write trajectory/negative tests first; prove failure, implement calibrated row detection and adaptive smoothing; cover both sides, aspect ratios, weak/missing joints, stale/out-of-order frames, gaps, pause, jitter, curls, torso motion, partials and different sampling rates.
2. Independent contracts component: registry/metric serialization/backup-validation tests first; add additive version/side support and explicit unknown-identity fallback. No cloud mutation or accepted tuple changes.
3. App component: tests first for setup/route/session lifecycle, authored targets/rest, side metadata, persistence, idempotent save and zero fabricated metrics. Reuse camera/overlay/audio/result/session infrastructure; add only row-specific integration.
4. Integrate and review negative paths; run affected pose/domain/Mobile/Admin/backend tests, changed-file analysis, architecture and Mobile/Admin builds. Benchmark analyser CPU and replay latency/jitter as local synthetic evidence, not phone inference/FPS acceptance.
5. Update operational references/progress/manual with local availability, pending catalog/publication/installation and physical UAT; retain all logs/artifacts under ignored build/single-arm-row-20261028/.

## Review focus

- A curl or torso rocking must not count as a row.
- One peak or lost tracking must not bridge into a repetition on return.
- Side and target counts must remain attached to the exact scheduled attempt.
- No row score, cloud acceptance or reward evidence is invented.
- Existing squat/curl/wall/calves behavior must be unchanged; verify old metric round trips.

Research: [ACE row technique](https://www.acefitness.org/resources/everyone/exercise-library/126/single-arm-row/), [MediaPipe pose guide](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker), [1 Euro filter authors/tuning](https://gery.casiez.net/1euro/). Existing capture pipeline already bounds queued frames and separates fresh analysis from overlay smoothing; preserve those optimizations.
