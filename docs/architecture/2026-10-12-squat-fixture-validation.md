# Local labelled squat fixture evaluator

Added a pure Dart evaluation command to support the remaining pose accuracy and
latency work while no Android phone is connected. It replays refined image-space
landmarks through the unchanged default SquatAnalyzer, compares independently
supplied expected counts and emits aggregate JSON. It imports no mobile/Firebase
repository and has no activity persistence or upload path.

From `packages/gainpath_pose`, run:

```powershell
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' run `
  tool/evaluate_squat_fixture.dart <local-fixture.json>
```

Exit codes: 0 means all supplied counts match, 2 means valid input with a count
mismatch, 64 means wrong command arguments, 65 means invalid/oversized fixture,
and 66 means unreadable input. Count match is an evaluation result, not permission
to enable real server acceptance. The command writes no files itself; stdout is
JSON and validation diagnostics do not echo paths or raw input.

## Version 1 input

Every object uses exact keys. Top-level fields:

| Field | Meaning / bound |
| --- | --- |
| schemaVersion | 1 |
| caseId, detectorId, detectorVersion | ASCII letters/digits/underscore/hyphen, 1..128 characters |
| provenance | `synthetic_fixture` or `recorded_fixture`; `real_camera` is rejected |
| expected | fullRepetitions, partialRepetitions and deviations |
| expected.deviations | trunkLean and incompleteDepth counts |
| frames | 1..20000 refined frames; local file at most 16MB |

All expected counts are required integers in 0..10000. Do not derive them from
the analyzer under evaluation: use independent movement annotation. For synthetic
tests, counts follow the analytic movement construction. A provenance string
describes input; the evaluator cannot authenticate a human annotation or prove
that a claimed recording came from a camera.

Each frame requires capturedAtMicros, deliveredAtMicros, imageWidth, imageHeight,
isMirrored, nullable posePresence and landmarks. Capture timestamps strictly
increase; deliveries are nondecreasing and cannot precede their own capture.
Clocks are nonnegative safe integers, and the case spans at most 24 hours from
first capture to last delivery. Image dimensions are integers in 1..16384.

Landmark map keys use the existing 33 canonical PoseLandmark names, such as
leftShoulder/leftHip/leftKnee/leftAnkle. An empty or incomplete map is allowed to
exercise actual tracking loss. Each point has exactly x, y, z, visibility and
nullable presence. Coordinates are finite in -10..10; confidence values are finite
in 0..1. x/y/z retain the PoseFrame normalized-image conventions. Use upright,
unmirrored refined detector output; do not prefilter the data a second time or
silently mirror/rotate it to make a test pass. Mirrored input is preserved so the
existing analyzer can reject unsupported anatomy. World coordinates are not part
of this evaluator protocol because the current sagittal rules use image geometry.

Keep real-person fixture data in a private local location or ignored build output,
not in committed examples. The tests construct anonymous analytic poses in code;
no human recording or landmark fixture was created during this implementation.

## What the report means

The output contains expected and observed full/partial/supported deviation counts,
signed/absolute count errors, tracked/rejected microseconds, tracking-health sample
counts and nullable estimated form score. Estimated form is a provisional rule
score, not an accuracy percentage against ground truth. Count totals cannot expose
event-level false positives/negatives or per-attempt timing, so no precision,
recall, percentage accuracy or event matching is fabricated from them.

Timing distributions contain mean, nearest-rank p50/p95, maximum and sample count:

- captureToDeliveryMicros comes from supplied fixture clocks. Its integrity is
  only as strong as the upstream capture/delivery instrumentation.
- analyzerProcessingMicros measures the host Stopwatch boundary around each
  SquatAnalyzer.update call. It includes cold/JIT calls and excludes fixture JSON
  decoding, detector inference, camera copy, drawing and speech.

Neither metric establishes physical camera-to-display latency. Reports explicitly
set physicalCameraLatencyMeasured=false and serverEligible=false. No frame arrays,
landmark coordinates, world joints, input paths or raw media enter the report.

## Verification evidence

Failing tests were run before evaluator and CLI implementation. Synthetic fixtures
exercise full/partial attempts, supported deviations, standing-only absent score,
stale deliveries, deliberately incorrect labels, malformed fields, input bounds
and CLI privacy/error behavior. Independent review found no concrete defect and
requested additional immutable-input and independent delivery-order regressions;
those are included before final verification.

Final verification on 2026-10-12: all 57 pure pose tests passed, including 11 new
evaluator/CLI tests; analysis of lib/tool/test reported no issues. Product analyzer,
filtering rules, mobile behavior and server acceptance policy were unchanged.

The local synthetic CLI smoke case uses 72 analytic frames, one expected full
repetition, no partial/deviation labels and a supplied 20ms delivery age. The
command observed matching counts. Its recorded processing times are host-only
observations and are not a phone performance improvement claim. Local generated
input/report remain under ignored `packages/gainpath_pose/build/squat-validation`.

Physical validation, representative phone comparisons and reviewed server tuple
enablement remain pending as described in the Step 6 deployment/device handoff.
