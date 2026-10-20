# Squat recording and algorithm review — 13 October 2026

## Finding

The recording shows six clear down-and-up attempts. The app records all six as
three full and three partial, ending with Estimated form 93% and 16s tracked.
This supports working attempt detection in this clip. It does not validate the
full/partial depth labels or establish 93% measurement/posture accuracy.

The participant begins frontal, moves back and turns side-on before exercising.
The UI reaches Ready by the sample at 2.000 s. All six reviewed cycles occur in
the side view. The initial frontal close-up is not the exercising view. Feet
are close to the displayed lower crop during exercise. Cropping in the displayed
viewport does not prove the detector's source image lacks those landmarks.

## Evidence and limits

Original read in place: C:/Users/Ngzhe/Downloads/VID_20261013_112006.mp4.
Bytes: 158,824,988. SHA256:
71950DF6FF38EEDE3F294A64D7178DCD6E14B26FFC3E467F45F384FE5CB4A991.
OpenCV decoded 1,195 frames with strictly increasing decoded presentation
timestamps, first 0 s and last 19.891388889 s. Display rotation is applied by
the decoder. No nominal-FPS interpolation is used for sample timestamps.

Visually reviewed 40 approximately half-second samples in four contact sheets,
plus enlarged counter/pose samples. Event windows below are approximate visual
brackets; counter observations are specific sampled PTS, not exact transitions.
The loose shorts, oblique recording of a phone screen, overlaid skeleton and
absence of original camera landmarks prevent reliable anatomical angle labels.
Displayed green coordinates are direct refined output; the counter uses its
independently filtered coordinates. Screenshot geometry is not a substitute for
those analysis values. There is no synchronized per-attempt angle/dwell trace.

| Attempt | Approximate movement window | Sample showing completed result | App classification | Cumulative full / partial |
| --- | --- | --- | --- | --- |
| 1 | 4.0–6.0 s | 6.016 s | Full | 1 / 0 |
| 2 | 6.3–8.0 s | 8.017 s | Full | 2 / 0 |
| 3 | 9.0–10.5 s | 10.512 s | Partial | 2 / 1 |
| 4 | 11.3–13.0 s | 13.013 s | Partial | 2 / 2 |
| 5 | 13.5–15.5 s | 15.510 s | Full | 3 / 2 |
| 6 | 15.8–17.5 s | 17.510 s | Partial | 3 / 3 |

The last reviewed 19.510 s sample still shows 3/3, 93% and 16s tracked. Tracking
interruption appears while approaching the camera near 19.010 s, followed by a
calibration prompt. No extra attempt appears in the short sampled standing
intervals. This clip does not contain the requested uninterrupted 15-second
stationary test. Counting success here is not a statistical accuracy estimate.

Local ignored evidence: apps/mobile/build/step7-performance/video-audit/ contains
the decoder script, decoded sample manifest, phone crops and contact sheets.
Raw video/frames have not been uploaded or added to Git.

## Current implemented squat measurement algorithm

Implementation reviewed at codex/real-squat-flow e730d1b plus documentation-only
4f35598. The active rule is bodyweight-squat-side-v1, an engineering default.

1. Receive fresh refined BlazePose landmarks. Preview filtering and analyzer
   filtering are separate; direct drawing does not bypass analyzer smoothing.
2. Choose a usable left/right side, then keep it for the current calibration.
   Require shoulder, hip, knee and ankle with finite usable geometry and minimum
   pose/visibility/presence confidence 0.7. A drawn skeleton can exist below the
   analyzer's confidence gate. View/yaw and upright-camera setup are confirmed
   assumptions, not automatically classified or gravity measured.
3. Apply the analyzer's own One Euro filter. Convert normalized x/y displacement
   to common pixel units before computing geometry. It is a 2D side-view measure:
   u = hip - knee; v = ankle - knee;
   theta = acos(clamp(dot(u,v)/(length(u)*length(v)),-1,1)) in degrees.
   Trunk lean is the shoulder-to-hip line's angle against image vertical.
4. Calibrate standing at knee angle >=160 degrees for 500 ms with a maximum
   6-degree observed angle range. Compute angular velocity from consecutive
   filtered knee angles and capture-time differences, in degrees/s.
5. Start descent below 160 degrees with velocity <-15 degrees/s. Confirm full
   depth only at <=90 degrees sustained for 150 ms. Confirm ascent with velocity
   >15 degrees/s for 150 ms; count only after returning to >=160 degrees, with
   total cycle duration >=600 ms and <=10 s. A completed return without confirmed
   depth records a partial attempt. Reversals stay within the same attempt.
6. Reject stale/gapped frames beyond 250 ms. Sustained loss, material geometry
   changes or pause can invalidate progress/calibration. Therefore unassessable
   movement is not automatically an incomplete-depth attempt.

Source: packages/gainpath_pose/lib/src/squat/{squat_geometry.dart,
squat_analyzer.dart,squat_rule_set.dart} and the mobile refined callback.
Independent read-only algorithm audit confirms this path and its stated limits.

## What 93% means

For each completed full OR partial attempt:

```text
leanExcess = maximum(trunkLean - 45 degrees) after 300 ms sustained deviation
trunkPenalty = min(30, 2 * leanExcess)
depthPenalty = 0 if confirmed full depth
               otherwise clamp(minimumFilteredKneeAngle - 90, 10, 50)
attemptScore = clamp(100 - trunkPenalty - depthPenalty, 0, 100)
sessionScore = arithmetic mean of all completed full and partial attempt scores
```

Aborted/unassessable movement is not included as a scored attempt. The UI rounds
the session mean. Thus three partials can coexist with a score of 93: a near-depth
partial may lose only 10 points, and other attempts may score nearly 100. The
rounded UI means cannot reconstruct individual penalties uniquely.

This score measures two configured deviation categories. It does not establish
angle accuracy, overall technique accuracy, knee valgus, heel lift, left/right
symmetry or comprehensive squat quality. The full/partial labels depend on
filtered angle and dwell, so a short excursion or near-boundary prediction may
be labelled partial even when a single displayed raw frame looks deep.
Whether that happened in attempts 3/4/6 cannot be established from this clip.

## Alignment with the supplied Chapter 4.9 design

The attached GainPath_Chapter_4_9_Aligned_Algorithm_Design.md is reference material,
not authorization to replace current rules. The implemented slice is narrower:

| Design reference | Current squat slice |
| --- | --- |
| 3D vector angles plus shoulder-scale normalization | Pixel-corrected 2D side-view angles; uniform scale is unnecessary for these angles |
| IMU reversal cross-check | Vision-only temporal confirmation |
| Trunk against gravity | Trunk against image vertical, requiring upright camera |
| Knee valgus + trunk + ROM | Trunk + incomplete depth only |
| End-only weighted sum: weights knee/trunk/ROM = 3/2/1, severity min(degrees/10,5) | Per-attempt capped penalties, averaged including partials; live estimated display |

These differences should be documented as the current MVP scope or resolved by
an evaluated implementation plan. A stationary camera phone's accelerometer is
not a direct body-motion reversal measurement; adding it blindly would not supply
the proposed ground truth. Switching to estimated 3D points alone also does not
establish accuracy. Thresholds/rubric must be evaluated against labelled inputs.

## Next evidence needed

Keep this responsive display candidate separate from production acceptance.
Expose local scalar attempt explanations: evaluated side, minimum filtered knee
angle, actual time <=90 degrees, confidence/loss interruptions and score penalties.
Then compare those explanations with independently labelled camera-view attempts,
including intentional shallow attempts, near-boundary depths and long stationary
holds. Do not lower the threshold just to make all six attempts count as full.
Report attempt detection, full/partial classification and angle/form evaluation
as separate metrics; this single recording cannot provide general accuracy.
