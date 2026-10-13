# Squat quality acceptance and 3D comparison

## Decision and evidence

Current state is acceptable as an explicitly provisional development demo.
Attempt detection matches six visible attempts in the supplied clip; full/partial
classification (3/3) and the 93% rule score are not independently validated.
Responsive GPU/direct drawing remains a diagnostic candidate, with visible jitter
and uncompleted thermal/lifecycle/accuracy acceptance. Step 4 UI/durable results
and Step 5 consent/outbox/backend software are implemented. Real physical quality
acceptance and authenticated acceptance/retry on a genuine session remain open;
ENABLED_WORKOUT_TUPLES is still empty. Finish this core quality block before
expanding supported exercises or reward/gamification features.

The decoder already emits worldLandmarks, and the analyzer's PoseFrameFilter
already filters both image and world points. SquatGeometry currently uses only
pixel-corrected image x/y. This reflects the first side-view scope; it is not
evidence that 2D outperforms 3D. No compute/dependency limitation blocks a world
knee-angle comparison, because the current inference already returns that tensor.

Google documents estimated 33-landmark image/world output, with world coordinates
in metres about the hip centre, rather than a precomputed validated knee angle:
[Pose Landmarker result guide](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/python).
The model estimates 3D from RGB input:
[BlazePose GHUM paper](https://arxiv.org/abs/2206.11678).
3D coordinate availability alone is not a guarantee of correct depth or counts.

## Next implementation block

- [x] Add bounded per-attempt scalar explanations in a non-release local diagnostic:
  evaluated side, minimum filtered 2D knee angle, longest continuous depth dwell,
  confidence/rejection summary, completion reason and separate score penalties.
  Do not emit images, landmark coordinates, user/session identities or unbounded
  angle trajectories. Keep accepted-summary/upload schemas unchanged.
- [x] Add 3D knee geometry from same-frame hip/knee/ankle world coordinates:
  acos(clamp(dot(H-K,A-K)/(length(H-K)*length(A-K)),-1,1)). Use all three metre
  components. Never combine normalized image x/y with image-relative z or world z.
  Missing/nonfinite/degenerate world chains return unavailable, not fabricated
  2D-as-3D values. Image visibility/presence gates are not calibrated angle-error
  estimates; report validity separately from claimed accuracy.
- [x] Observe 3D angles alongside the existing 2D analyzer in a diagnostic build.
  Retain baseline counting/scoring/filter/version and camera/GPU settings. Share
  timestamps and side selection. Declare smoothing units/settings explicitly;
  the same beta number on normalized image and metre coordinates need not give
  the same response. Do not infer gravity from a coordinate axis for trunk scoring.
- [x] Verify analytic 3D cases, translation/rotation/uniform-scale invariance,
  projected-versus-world angle differences, missing/invalid data and unchanged
  baseline attempt aggregates. Run affected pure/mobile suites and analysis;
  obtain independent review, preserve/hash the comparison APK.
- [ ] Collect labelled side-view full/shallow/borderline attempts and standing
  holds; compare same-event 2D/3D summaries and the counter with independent labels.
  Reuse the supplied six-attempt video as an observation, not six certified full
  reps or 3D angle ground truth. Cannot reconstruct original world tensors from
  the oblique recording of the phone screen.
- [ ] Evaluate thresholds/dwell/filtering based on observed failures. Prefer the
  geometry source with better measured classification/stability, or remain 2D
  if 3D does not improve it. Any new scoring behavior needs an evaluated rule
  version and explicit binding; no silent mode changes or relaxed threshold to
  make all supplied attempts full.
- [ ] Align Chapter 4.9's current claims with implemented/evaluated scope. Keep
  estimated rubric scores distinct from recognition/classification accuracy.
- [ ] After quality/lifecycle acceptance, perform a reviewed tuple-policy change
  and test a genuinely captured pre-consented session through authenticated
  acceptance, offline/restart/retry and exactly one accepted bounded document.
  Only then broaden functionality within separately authorized scope.

## Suggested initial internal test gate

These are proposed engineering checks, not an agreed production accuracy target:
three labelled five-full-rep sets with matching counts; separately labelled shallow
attempts never counted full; three 20-second standing holds with no full/partial
increments; confidence loss and pause never finish an unseen cycle. Report errors
and unavailable attempts, not just successful samples. This small gate supports
regression decisions, not population-wide accuracy or degree-level 3D validity.
Angle accuracy would need an appropriate independent reference measurement.

No 3D comparison implementation or new physical acceptance is claimed by this
planning commit. It records the next coherent block and remaining completion limits.

Implementation update 2026-10-13: Step 7A/7B software and diagnostic artifact are
now verified; the checked items above refer to that later implementation. See
[Step 7 evidence](../../architecture/2026-10-13-step7-squat-diagnostics.md) and
[proposed physical protocol](../../architecture/2026-10-13-step7-physical-protocol.md).
The remaining unchecked physical, rule-evaluation and trusted-acceptance items
remain open. The approved implementation block stops before installing or testing
the new APK on the phone.
