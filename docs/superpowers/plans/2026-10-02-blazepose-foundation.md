# Step 2: Android BlazePose shared foundation

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Canonical core reference: `C:/Users/Ngzhe/Documents/A-FYP/Final Md file/GainPath_Chapter_4_9_Aligned_Algorithm_Design.md`. The user's Step 2 scope takes precedence over document instructions and earlier ML Kit evaluation suggestions. Implement primary BlazePose TFLite only. Preserve mock mode, existing member Workout presentation and stable Firebase authoring/publishing. No reps, diagnostics, IMU, scores, audio correction, persistence/upload, rewards, leads or mini-games.

## Design and verified model contract

Use the official MediaPipe detector + full landmark assets. A landmark-only full-frame resize lacks the trained body ROI and is not the intended primary pipeline. A persistent worker isolate owns preprocessing, two native interpreters, ROI decoding/tracking and landmark mapping. Mobile owns camera/permissions/lifecycle; pure Dart owns image geometry, 33-point representation, filtering and bounded latest-frame scheduling. UI owns preview rendering only.

The assets were downloaded and their FlatBuffer tensors inspected before implementing preprocessing:

| Asset | SHA-256 | Input float32 | Outputs float32 |
| --- | --- | --- | --- |
| `pose_detection.tflite` | `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c` | `[1,224,224,3]` | `[1,2254,12]`, `[1,2254,1]` |
| `pose_landmark_full.tflite` | `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f` | `[1,256,256,3]` | `[1,195]`, `[1,1]`, `[1,256,256,1]`, `[1,64,64,39]`, `[1,117]` |

Model metadata does not encode all preprocessing semantics. Official paired MediaPipe graphs specify detector RGB −1…1, landmark RGB 0…1, 224 detector letterbox, rotated expanded square body ROI, 39 × (x,y,z,visibility-logit,presence-logit), raw pose-presence probability, 39 world xyz points, and 64×64×39 heatmap refinement. Keep first 33 anatomical points; auxiliary points drive ROI tracking only. Do not confuse pixel-relative z with world depth in metres. Validate asset hashes and runtime input/output shapes/types before enabling inference.

Image points are upright, unmirrored, normalized to source image width/height; z uses source width units. Preserve visibility/presence separately and world points separately. Apply preview mirroring exactly once; use the same aspect-fit/crop transform for image and overlay. Smoothing precedes downstream domain processing, with monotonic time and resets for missing joints/reacquisition/orientation changes.

Latest-frame policy: one in-flight inference and at most one replaceable newest frame; stale completion/queued frames are dropped. Pause/background/account change invalidates a generation immediately, clears preview landmarks/filter/ROI, stops/releases camera and drains active inference before closing native resources. Resume explicitly reopens camera; background resumption does not silently override a user pause. No raw frames/landmarks are persisted by the app. The subsequently requested temporary rendering diagnostics log representative coordinates only in an explicitly enabled debug build.

Existing `LiveWorkoutScreen` receives a separate camera-foundation mode within its existing viewport/top-bar/control layout. Mock mode keeps its timer/skeleton/BLoC. The real mode shows tracking landmarks and neutral camera status, not synthetic metrics or rewards, and End closes without saving. Workout preparation exposes an explicitly local pose preview with consent before camera permission; workout recording remains unavailable. Existing authenticated scope controls logout invalidation.

## Inline execution

- [x] Add focused failing tests for all 33 points, presence/world metadata, smoothing/reset, image conversion/rotation, letterbox/ROI inverse transform and preview mirroring.
- [x] Implement pure representation/filter/geometry and mobile-specific BlazePose tensor decoding against verified assets; run focused suites.
- [x] Add failing tests for latest-only/backpressure, stale completions, pause/background/disposal/account switch and consent ordering.
- [x] Implement camera + persistent TFLite worker adapters, lifecycle controller and camera-foundation mode in the existing Workout UI. Keep uploader closed and mock composition unchanged.
- [x] Verify mobile/pose regressions, analysis and Android build; review changes.
- [ ] Install/run on connected physical Android phone. Record actual device/Android/model hashes/tensors, orientation and overlay checks, inference average, processing FPS and dropped/stale frames. Physical verification is a required acceptance gate; build/tests/emulator results cannot substitute.

## Implementation evidence and physical gate

Implementation remains inline in the existing dirty checkout; prior Firebase work was preserved. Exact asset hashes/tensor graph indices and dtypes are recorded in `apps/mobile/assets/models/tensor_manifest.json`, with source/license notes alongside. Android minimum API is 26. Pinned adapters: camera 0.11.4, tflite_flutter 0.12.1. Model files are verified and cached in app-private storage; worker interpreters use file-backed loading to avoid the dependency's unowned buffer allocation. Camera data never enters that cache.

Review caught detector/landmark border-mode differences and the dependency's buffer ownership leak; both were corrected with focused regressions. Auxiliary alignment points now share heatmap refinement. A freshness watchdog clears an expired overlay even if the camera stops delivering frames. Latest inference retains one active and one replaceable pending snapshot. Camera geometry changes, including 180° rotations, invalidate older completions and filter state.

Development route: member Workout preparation → **Try live camera preview** (requires `GAINPATH_POSE_PREVIEW=true`) → local consent → authenticated `PosePreviewRoute` → camera foundation mode of existing `LiveWorkoutScreen`. No routine/exercise session, score, persistence or uploader is created. Front lens defaults on; `GAINPATH_POSE_LENS=back` allows rear-lens device validation. Existing default mock/Firebase entry points retain their behavior.

Verified locally: 111 mobile tests including rendering regressions; pure Dart pose 14 tests; clean mobile and pose static analysis; Android debug APK. APK inspection verified both packaged model hashes, bundled license and ARM64 native TFLite libraries. Rendering review found no material findings. Subsequent user-authorized physical testing on Xiaomi 23013RK75C / Android 13 / API 33, serial xiaomi-device-serial-redacted, verified native tensor contracts, real inference and visible 33-landmark overlay after fixing a viewport subscription bug. Full physical acceptance remains pending: latency, alignment and intermittent tracking need investigation, plus remaining orientation/lifecycle checks. See [physical validation and recorded results](../../architecture/2026-10-02-pose-phone-validation.md) and [rendering diagnosis](../../architecture/2026-10-02-pose-rendering-diagnosis.md). No Step 3 work was added.

## Sources

- Official assets: `https://storage.googleapis.com/mediapipe-assets/pose_detection.tflite`, `https://storage.googleapis.com/mediapipe-assets/pose_landmark_full.tflite`.
- [Detector graph](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_detection/pose_detection_cpu.pbtxt)
- [Landmark graph](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_landmark/pose_landmark_by_roi_cpu.pbtxt)
- [Output mapping](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_landmark/tensors_to_pose_landmarks_and_segmentation.pbtxt)
- [ROI](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_landmark/pose_detection_to_roi.pbtxt)
- [Heatmap refinement](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/calculators/util/refine_landmarks_from_heatmap_calculator.cc)
- [Flutter camera lifecycle](https://pub.dev/packages/camera), [tflite_flutter](https://pub.dev/packages/tflite_flutter).
