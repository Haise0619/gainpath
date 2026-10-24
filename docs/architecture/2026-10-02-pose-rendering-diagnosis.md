# Step 2: successful inference, invisible skeleton

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Physical phone: Xiaomi 23013RK75C, Android 13 / API 33, ADB serial xiaomi-device-serial-redacted. Model `mediapipe-full-e9a5c5cb-det-9ba9dd3d`; runtime tensor verification true. Model assets, tensor contracts, detector/landmark acceptance thresholds, One Euro parameters and latest-frame/backpressure policy were not changed.

## First failing stage and fix

The first failure was **UI pose state → camera viewport painter binding**. `PosePreviewView` listened to the session but reused the same `viewport` widget object. The viewport listened only to `CameraController.value`, which does not notify for each inferred pose. Flutter reused that subtree; its painter retained the initial null frame even while session landmark counts advanced. Camera orientation changes could occasionally rebuild the viewport, obscuring the failure.

The fix adds a direct `ListenableBuilder` subscription to the pose session inside `PoseCameraViewport`. Pose updates and freshness clearing now rebuild its painter independently of camera notifications. The widget regression runs the real session/filter, viewport, camera preview composition, projection and painter with only external native texture/inference replaced. It failed with session33/painternull before the fix and now verifies actual green pixels over a stationary camera texture. A separate canvas test verifies magenta markers even when confidence suppresses skeleton links.

The actual rendering path is raw model tuples → heatmap refinement → ROI inverse projection to normalized upright image coordinates → detector-neutral `PoseFrame` → One Euro filtering → session notification → viewport binding → preview projection/mirroring → `PoseLandmarkPainter` → `CameraPreview.child` / `CustomPaint`. Inverse ROI projection happens before One Euro filtering in this implementation. The older `SkeletonPainter` remains the mock animation and is not used by real camera mode.

## Physical evidence

Baseline and fixed logs were captured locally in ignored `apps/mobile/build/pose-debug/`. Baseline phone data had anatomical/model count33, image/filter count33 and17 visible/accepted points; viewport and painter remained bound to null/zero. The canvas was already 480×720 and above the preview, with opacity1, compatible aspect ratio and normal clipping. This ruled out a zero-size canvas, covered paint layer or universal confidence rejection as the initial failure.

| Stage | Before fix | After fix, saved snapshot |
| --- | --- | --- |
| Raw model tuples / anatomical points | 39 / 33 | 39 / 33 |
| Projected image points | 33 | 33 |
| One Euro filtered points | 33 | 33 |
| Visible/accepted points | 17 | 28 |
| Viewport-bound points | 0 / timestamp null | 33 / timestamp514854116 |
| Painter points / projected points | 0 / 0 | 33 / 33 |
| Painter timestamp | null | 514854116, matching filtered/viewport |
| Canvas size | 480×720 | 480×720 |
| Repaint-true checks | 0 | 3300, advancing |
| Points within canvas | 0 | 22 (the person was partially framed) |
| Visible pixels | no skeleton | green skeleton + magenta markers seen in phone screenshot and confirmed by user |

Representative left shoulder at timestamp514854116: raw model pixels `[151.9309,77.1081,-97.0248]`, raw ROI normalized `[0.5935,0.3012,-0.3790]`; image normalized before filter `[0.5902,0.3885,-1.1918]`; filtered image pixels `[284.7526,280.8805,-591.3399]`; front-mirrored preview pixels `[195.2474,280.8805]`. It was accepted and inside the canvas. Image pixels, normalized units and preview pixels are explicitly distinguished.

The diagnostic run's cumulative metrics at the saved snapshot: average native inference57.79ms, total pipeline123.81ms, delivered overlay7.64FPS, processed3982, displayed3926, replaced/dropped11052, stale57. These include the pre-fix run, hot reloads and development instrumentation; they are not an isolated production-performance benchmark. The queue policy is unchanged.

## Temporary opt-in diagnostics

`GAINPATH_POSE_RENDER_DEBUG=true` plus debug mode enables representative coordinates and yellow canvas border/magenta circles. Normal builds omit coordinate logs and markers. The app does not persist camera images or these snapshots. A development screenshot was captured via ADB for compositor verification and retained only in the ignored build directory; the device screenshot file was removed.

Log stages, sampled every 5 seconds: `POSE_RENDER_MODEL`, `IMAGE`, `FILTERED`, `VIEWPORT`, `PAINTER`, `JOINT`, and `HEALTH`. Each joint line includes model pixels, ROI normalized coordinates, image normalized/pixel coordinates before/after filtering, preview pixels, confidence and clipping status, with capture timestamps. Coordinate logging rounds display values to 4 decimals only; actual inference/geometry values are unchanged. Lines are split into compact records because long Android Flutter log lines were truncated on this phone.

Painter diagnostics include invocation count, canvas size, repaint checks/results, projected count/bounds, accepted count, in-canvas count, confidence thresholds, mirror state and connection toggle. Set `GAINPATH_POSE_RENDER_LINKS=false` with render debug enabled to isolate marker rendering. Magenta markers deliberately ignore confidence, whereas normal green points/connections keep the existing0.5 visibility/presence thresholds.

`POSE_RENDER_HEALTH` separates delivered empty-pose results from expiry of old overlays and records displayed frame age. Debug-mode aggregate `POSE_FOUNDATION_METRICS.poseHealth` exposes the same counters without coordinate logging, plus capture timestamp and last delivered pose-presence probability. Its counters are temporary diagnostics, not a change to the 250 ms freshness policy. Reopen the preview after hot reload to initialize the new callbacks; counters from a session created before this instrumentation are not valid evidence.

## Remaining Step 2 findings

The user confirms both overlay types are visible but reports high perceived latency, inaccurate body alignment and detection coming/going. These quality concerns are **not marked fixed**. The first screenshot was a close/partial body view, with some projected joints outside the canvas. A subsequent full-body screenshot with diagnostic circles disabled showed the normal green overlay broadly following shoulders, hips, legs and feet in a static pose. This confirms rendering in full-body view, not motion accuracy or stable tracking. Low-confidence magenta guesses must not be used as evidence of accurate body tracking.

A follow-up process with detailed coordinate diagnostics and markers disabled still recorded approximately 60 ms native inference, 129 ms pipeline time and 7.4 delivered frames/s, with 0 → 33 reacquisition. The perceived delay is therefore not explained solely by the debug circles. These are cumulative debug-mode averages, not end-to-end camera-to-display latency measurements. A clean diagnostic run must distinguish empty inference results from expired display frames before tuning anything. Models, thresholds, smoothing and backpressure remain unchanged, and no RepFSM or Step 3 processing was added.

After the user's full-body positioning confirmation, the aggregate samples from 19:38:11–19:38:41 each reported 33 landmarks, followed by a zero-landmark sample at 19:38:46. Sampling every 5 seconds cannot prove uninterrupted tracking between samples. This long-running development session's averages later reached approximately 65 ms inference, 137 ms pipeline and 6.9 FPS. The health-counter fields were hot-reloaded into a pre-existing session, whose callbacks had not been recreated; their zero counts and null presence are excluded from conclusions. Xiaomi rejected ADB input injection with `INJECT_EVENTS`, so it was not possible to reopen that preview programmatically. A clean reopened session remains necessary to attribute the intermittent loss.

Validation:111 mobile tests, clean mobile analysis, Android debug build, fresh read-only review with no material rendering findings, physical hot reload and visible-pixel confirmation. The repaired APK is built with coordinate diagnostics/markers disabled by default; the attached phone run used explicit diagnostics for the investigation.
