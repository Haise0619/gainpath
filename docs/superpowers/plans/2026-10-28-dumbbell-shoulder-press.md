# Dumbbell Shoulder Press implementation plan

**Goal:** implement a responsive bilateral front-view Dumbbell Shoulder Press tracker through the existing Routine → consent/setup → camera → measured summary → next exercise flow. Owner requested direct implementation; local code, tests and builds are authorized. New cloud deployment, catalog publication and device installation require their exact separate scope.

**Architecture:** use the installed BlazePose detector, bounded latest-frame scheduling and fresh unsmoothed analysis callback. Isolate shoulder geometry/counting from frozen existing trackers. Aspect-correct shoulder/elbow/wrist/hip evidence on both sides, stable front/upright calibration, timestamp dwell/hysteresis and bounded scalar smoothing identify bottom → bilateral overhead → bottom cycles. Never bridge tracking loss, stale frames, camera geometry changes, pause or unilateral attempts. No weights, pain, spinal alignment or three-dimensional shoulder mechanics are inferred. No form score is fabricated.

**Identity:** exact gainpath/dumbbell-shoulder-press-front-v1; tracker dumbbell_shoulder_press_front_v1; scoring version dumbbell-shoulder-press-front-v1. Both arms together constitute one repetition. Sets/reps/rest remain authored Routine targets, outside the analyzer. Provisional metric schema 4 distinguishes this new front-view variant from older schemas; backup list negotiation filters unsupported sessions and dependent checkpoints for older clients. No accepted-workout tuple or reward gate changes.

**Workspace:** preserve the current checkout's uncommitted Program/Row/catalog work and protected build artifacts; those dependencies are required by this extension. No reset/clean, broad staging or unrelated refactor.

## Tasks (execute inline)

- [x] Pose tests first: complete bilateral cycles across rates/aspect ratios; unilateral/alternating arms, partials, curls/lateral raises, jitter, clipped/weak/nonfinite joints, changing torso/camera geometry, stale/reordered frames, gaps and pause. Implement isolated ShoulderPressGeometry/ShoulderPressAnalyzer with snapshot/update/tick/pause and no targets.
- [x] Registry/metrics tests first: exact identity/front-view labels, unknown identity guided fallback, schema-4 strict round trip, null score and no row/curl fields, summary identity consistency, older-schema preservation. Add backend validation/negotiation without acceptance or deployment.
- [x] App tests first: dispatcher/route, setup responsiveness, Routine-authored targets/rest, measured sessions, pause/background/recalibration/account/model changes, idempotent local save, no upload/rewards. Reuse measured camera view/audio/result/history infrastructure in an isolated session/route.
- [x] Review integration and focused regressions; run pose/domain/Mobile/Admin/backend checks and analysis/typechecks/architecture. Build Mobile and Admin locally. Measure synthetic analyzer processing cost separately from pending physical inference/thermal/accuracy UAT.
- [x] Update six operational references, PROGRESS_REPORT and existing Module 2 manual with availability, instructions, evidence and exact pending release scope. Prepare catalog payload locally without overwriting published Programs or creating live data.

## Review focus

- One-arm or alternating motion must not become a bilateral rep.
- No completed rep until returning from a sustained overhead position to a sustained starting position.
- Raw and filtered joint evidence must agree; jitter, latency, invalid confidence and loss must not create reps.
- New measured records must remain identifiable, provisional and backward-compatible through negotiated backup reads.
- Existing detectors, acceptance/reward holds, publications and Member progress remain unchanged.

Research: [MediaPipe pose output/visibility](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker), [ACE shoulder training](https://www.acefitness.org/resources/pros/expert-articles/9074/smart-shoulder-solutions-an-evidence-based-approach-to-training-the-deltoids/). Algorithm thresholds are conservative engineering choices requiring phone validation, not validated physiological limits.

## Local closeout

All local tasks passed, with 765 tests and five existing skips. One review finding (compact large-text recalibration overflow) was reproduced and fixed; reviewer confirmed resolution. New-code lints and cross-package test fixture boundary were corrected. Both apps build. Evidence and release limitations: build/shoulder-press-20261028/verification.json. No live mutation or installation occurred.

## Owner-approved release closeout

Owner explicitly approved the reviewed source-only two-Function/private Admin/exact Xiaomi/catalog plus validation Routine release. All components are active and verified; 49 extracted-package checks and Member Rules/App Check discovery/schema-2/3/4 reads pass. Previous artifacts and existing content/Programs are preserved. Physical UAT and browser smoke remain pending. See build/shoulder-press-20261028/release-verification.json. This completed approval grants no further mutation authority.
