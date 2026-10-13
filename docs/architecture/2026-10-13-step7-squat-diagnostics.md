# Step 7A/7B squat explanations and estimated 3D comparison

Step 7A adds bounded explanations for full, partial and aborted attempts. Step 7B
calculates estimated world knee angles beside the existing 2D analyzer. Both are
local diagnostics. The baseline rule, counting, scores, cues and accepted-result
contract remain unchanged. These changes enable investigation; they do not establish
physical accuracy or promote the GPU/direct-preview candidate to production.

Implemented on `codex/real-squat-flow`; Step 7A commit `a862007`. Step 7B includes
the first-descent dwell explanation refinement described below. Work followed
the approved software-only scope: no APK installation, camera trial, backend
tuple enablement or upload change. The other workout audit chat's latest completed
review reported no outbox/DTO blockers and 18 passing focused checks; its files
were not edited here. Unrelated local files remain outside these commits.

## What is measured

The optional recorder holds at most 64 terminal attempt summaries by default,
with an enforced maximum capacity of 128. Each active attempt and the session
keep fixed-size scalar totals. It retains no frame, image, landmark coordinates,
angle trajectory, member ID or session ID. A record explains selected side,
minimum filtered 2D angle, observed depth streak, actual decision dwell,
confidence, rejected observations, interruptions, outcome reason, actual score
penalties and rule version. Aborted attempts receive no attempt score or penalty;
the previous completed-attempt session mean may still be present.

`longestContinuousDepthMicros` is the longest observed qualifying capture streak,
including the first descent frame. The existing FSM starts its eligible dwell
on a later frame after entering descent. `maximumDecisionDepthDwellMicros` observes
that timer, and `decisionDepthDwellAtConfirmationMicros` freezes at first
confirmation. They explain the baseline rather than changing it. A sparse stream
can therefore show an observed 200 ms streak yet an eligible timer of 0 ms and a
`depth_dwell_not_confirmed` partial. Neither measure proves continuous physical
depth between captures. The current 150 ms threshold is still checked at captures.

World geometry uses the selected hip, knee and ankle's complete XYZ values:

```text
u = hip - knee; v = ankle - knee
angle = acos(clamp(dot(u/length(u), v/length(v)), -1, 1)) * 180 / pi
```

World XYZ are model-estimated metres; they can be negative or outside image
bounds. Normalized image XY are separately restored to pixel units for 2D.
Image-relative z is never mixed into either calculation. Missing joints,
insufficient/invalid confidence, nonfinite coordinates, degenerate segments and
mirrored inputs explicitly abstain. No 2D value is fabricated as a 3D fallback.
Confidence gates are validity checks, not calibrated angle-error probabilities.

Raw and filtered comparisons require equal capture timestamp, detector/model,
dimensions, mirroring and pose presence, plus the analyzer's selected side.
No second model inference is introduced. Coordinate filtering precedes angle
calculation, as in the baseline. Settings are recorded: min cutoff 1, beta 0.3,
derivative cutoff 1, visibility threshold 0.5 and reset gap 500 ms. The same beta
number on normalized image coordinates and metre coordinates does not imply
the same temporal response. No world axis is used as gravity for trunk scoring.

Per-attempt and session summaries contain count/minimum/maximum/mean for raw2D,
filtered2D, raw3D and filtered3D, plus matched/mismatched counts and world
unavailability reason totals. Comparison population is **usable 2D frames,
including calibration**. These summaries cannot demonstrate that 3D rescues
2D-rejected frames. Each stream can have a different available population;
report coverage beside its statistics. Independently aggregated minima or means
are not paired-frame errors, lag measurements or anatomical validation.
Calibration/body approach also makes a mixed session range unsuitable as a
stationary-jitter measurement.

Google describes estimated world coordinates, not a precomputed validated knee
angle: [Pose Landmarker result guide](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/python).
The inference of 3D from RGB is described in the
[BlazePose GHUM paper](https://arxiv.org/abs/2206.11678). Availability of those
coordinates is not evidence of degree-level or classification accuracy.

## Composition and lifecycle

`GAINPATH_SQUAT_DECISIONS=true` attaches the recorder only outside release mode.
`GAINPATH_SQUAT_3D_COMPARE=true` additionally enables world comparison and requires
the decisions flag. Default and release compositions attach neither diagnostic.
Terminal JSON uses `REAL_SQUAT_DECISION`; close emits one
`REAL_SQUAT_COMPARISON_SUMMARY`, including sessions with no attempts. Idle frames
do not copy the retained queue. Account changes suppress old-scope output, close
clears buffers, and logging failures cannot prevent analysis or cleanup.
These messages stay local; the result/outbox/upload DTOs are unchanged.

The existing analyzer timing includes diagnostic geometry/aggregation when
enabled, but stops before terminal JSON/log emission. Compare performance with
equivalent flags and report that boundary; it is not end-to-end physical latency.

Changed implementation files:

- `packages/gainpath_pose/lib/src/squat/squat_diagnostics.dart`: bounded scalar recorder.
- `packages/gainpath_pose/lib/src/squat/squat_world_geometry.dart`: estimated 3D geometry and strict scalar pairing.
- `packages/gainpath_pose/lib/src/squat/squat_analyzer.dart`: optional observations at existing decision boundaries.
- `packages/gainpath_pose/lib/gainpath_pose.dart`: exports.
- `apps/mobile/lib/infrastructure/pose/squat_decision_diagnostics.dart`: guarded local logging/composition.
- `apps/mobile/lib/features/workout/application/squat_processing_controller.dart`: scoped emission and cleanup.
- Pure diagnostics/world geometry tests and mobile diagnostic lifecycle/guard tests.

## Verification

Initial missing recorder and geometry APIs failed focused tests before their
implementation. The first-descent regression failed with a missing actual-dwell
field, then passed after the observational hook. Every synthetic replay frame
compares diagnostic and baseline health, calibration, phase, side, geometry,
velocity, full/partial counts, durations, score, confidence, cues and attempt facts.
Fixtures also cover penalties, brief depth, loss/pause/watchdog/gap aborts, retention
and reset. World tests check known 45/90/135/175-degree angles, right-side selection,
projection differences, translation/rotation/uniform scaling, missing/invalid
confidence and data, exact abstention statuses and identity mismatch.

Final software verification on 2026-10-13:

| Check | Result |
| --- | --- |
| Entire pure pose package | 70 passed |
| Entire mobile suite, default composition | 259 passed; 15 optional skips |
| Entire mobile suite, GPU/direct preview/performance/decisions/3D enabled | 259 passed; 15 optional skips |
| Product-mode compiler guard, both diagnostic defines enabled | 3 passed; composition and emission disabled |
| 3D define alone | 3 passed; composition and emission disabled |
| Changed-source Dart analysis | No issues |
| Independent whole-change review and incremental dwell recheck | No blockers |

Compiler guards are software checks, not release-device acceptance. The reviewer
identified the observed/eligible dwell difference; the implementation now exposes
both. The reviewer also cautioned against inferring paired accuracy from aggregates,
which is explicit above and in the [next trial protocol](2026-10-13-step7-physical-protocol.md).

The ignored `apps/mobile/build/step7-diagnostics/example.dart` runs an analytic
replay through the real analyzer. Its output is preserved in `example-output.log`.
It uses constructed planar metre coordinates, not recorded person data or
uploadable activity. Actual terminal excerpts:

| Sequence | Outcome / reason | Min filtered 2D | Observed depth | Maximum decision dwell | Confirmed at | Attempt / session score |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | full / confirmed_depth | 75.1231° | 1,300,000 µs | 200,000 µs | 200,000 µs | 100 / 100 |
| 2 | partial / depth_dwell_not_confirmed | 53.0593° | 200,000 µs | 0 µs | null | 90 / 95 |
| 3 | aborted / paused | 128.7869° | 0 µs | 0 µs | null | null / 95 |

The session has 108 matched observations, no mismatches or world abstentions.
Raw 2D/3D agreement is by construction. The partial's depth penalty is 10; this
is the current rubric, not a recognition accuracy result. A partial can reach
a small observed angle without satisfying the baseline eligible dwell.

## Artifact and next decision

The profile APK uses Firebase development, performance logging, GPU, direct
refined preview, decisions and 3D comparison defines. The separate preserved
artifact and SHA-256 were recorded after the successful 43.4 s Gradle build. Earlier
CPU/GPU/direct-preview rollback artifacts are preserved. No phone was restarted
or APK installed for this block.

Artifact: `apps/mobile/build/step7-diagnostics/gainpath-firebase-gpu-squat-decisions-3d.apk`
(147,427,710 bytes, ignored local build output).
SHA-256: `E07B55B5DD7DD719FC9FBA24304E74055203C42C80E572C891DC7F775CE8DD5B`.
Example output SHA-256: `2CAEE3D958F018A48B0637ED8EC53E7004E45F8A6E85E85B409986081D45F016`.
Build log: `apps/mobile/build/step7b-apk-build.log`.

Reproduce from `apps/mobile` with the configured Flutter SDK:

```powershell
flutter build apk --profile --no-pub `
  --dart-define=BACKEND=firebase --dart-define=APP_ENV=development `
  --dart-define=GAINPATH_SQUAT_PERFORMANCE=true `
  --dart-define=GAINPATH_POSE_GPU=true `
  --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true `
  --dart-define=GAINPATH_SQUAT_DECISIONS=true `
  --dart-define=GAINPATH_SQUAT_3D_COMPARE=true
```

Next work requires a controlled labelled physical trial using the protocol.
Production remains filtered 2D, and trusted workout tuples remain disabled.
Do not relax thresholds to make the previous clip's six attempts all full.
Select or reject a later 3D counting candidate based on measured failures and
independent labels, with a new evaluated rule version if behavior changes.
