# 5.1.4.1 — Real-time human pose estimation pipeline

The camera-to-inference path runs on Android. Dart owns capture adapters, image geometry, scheduling, decoding and analyzers. Native Android provides a GPU OpenCL execution path for the TensorFlow Lite model; CPU is supported and selected if native preferred initialization fails. The bundled models are labelled MediaPipe Full BlazePose in the model version. The implementation consumes bundled model tensors directly, via tflite_flutter, without a graph/task SDK in this path. Evidence of GainPath's contribution is the camera/decoder/scheduler/calibration/analysis/feedback stack. This audit found no pose model training evidence in the inspected runtime.

| Configuration | Observed authority |
|---|---|
| Flutter dependency and Android target | apps/mobile/pubspec.yaml:39–40 pins camera 0.11.4 and tflite_flutter 0.12.1. Lines 111–112 bundle the pose models. Android minimum API 26 is configured in apps/mobile/android/app/build.gradle.kts:63. |
| Detector model | assets/models/pose_detection.tflite, SHA-256 9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c. Float32 input 1×224×224×3. Outputs 1×2254×12 (box/keypoints), 1×2254×1 (scores). |
| Landmark model | assets/models/pose_landmark_full.tflite, SHA-256 e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f. Float32 input 1×256×256×3. Outputs 195 landmark values, 1 scalar pose presence, 256×256×1 segmentation, 64×64×39 heatmap and 117 world coordinates. Segmentation exists in the tensor contract but is unused in the rendered skeleton. |
| Contract identifier | mediapipe-full-e9a5c5cb-det-9ba9dd3d. Asset and tensor shape/type/name checks are in blazepose_assets.dart and blazepose_contract.dart:13–48. |
| Capture format | ResolutionPreset.medium selected dynamically by device. YUV420 requested, BGRA8888 handled in adapter, audio disabled. Front preferred unless route selects rear; first available is fallback. Actual pixel dimensions are carried per frame; no fixed device-independent camera size is claimed. |
| Compute and cadence | Separate Dart worker, two CPU interpreter threads, Android OpenCL MethodChannel/owned executor, acceleration compile-time default on. Detector refreshes when ROI missing or after 15 tracked ROI frames. Result age bound 250 ms. |

~~~mermaid
flowchart TD
  A[Android permission and lens selection] --> B[Strided YUV camera planes and monotonic timestamp]
  B --> C[Latest-frame scheduler]
  C --> D{ROI missing or due}
  D -->|Yes| E[Letterboxed detector crop and person/anchor decode]
  D -->|No| F[Use tracked ROI]
  E --> F
  F --> G[Bilinear RGB 256 by 256 rotated crop]
  G --> H[Lite GPU or CPU tensor invocation]
  H --> I[Pose probability and refined image/world joints]
  I -->|Auxiliary anchors| F
  I --> J[Freshness and session ownership checks]
  J --> K[Exercise analyzer or game adapter]
  J --> L[One Euro display filter and mirror/crop projection]
  K --> M[Reps, provisional metrics and cue requests]
  L --> N[Skeleton overlay]
~~~

## Runtime and privacy

1. AndroidPoseCamera.start enumerates devices and initializes the plugin controller, preserves row/pixel strides, derives rotation from lens/sensor/device and exposes upright geometry. A revision guard rejects stale startup/callbacks. CameraAccess errors map to PoseCameraPermissionDenied and the camera is disposed. Malformed images are emitted as invalid input so downstream clears stale output. The API timestamp is collected after camera delivery/snapshot. It omits sensor exposure. See apps/mobile/lib/infrastructure/pose/android_pose_camera.dart:35–170.
2. LatestFrameScheduler manages one in-flight item and one replaceable latest pending frame. Generation increments invalidate delayed results on pause, scope change or disposal. This backpressure prevents a queue of old detections. See packages/gainpath_pose/lib/src/pose/pose_stream.dart:84–184.
3. The worker samples directly from strided planes, rotates the crop, letterboxes detector input, uses bilinear interpolation and normalizes RGB by the model range. The detector selects a weighted candidate cluster after sigmoid score filtering, decodes scale/center/rotation and returns a full-body ROI. Candidates use a sigmoid score floor .50. Candidates overlapping the top box with IoU >.30 contribute score-weighted alignment points. A live ROI derived from auxiliary landmarks is reused until refresh. See apps/mobile/lib/infrastructure/pose/blazepose_geometry.dart:7–165, blazepose_decode.dart:54–165 and blazepose_detector.dart:470–551.
4. Pose presence 0.5 gates decoding. The decoder refines candidate image points with a local heatmap average, applies inverse ROI transforms and exposes 33 anatomical joints. World joints are rotated to match the upright view. Visibility and presence probabilities accompany joints, and nonfinite outputs are rejected. See blazepose_decode.dart:170–242. Real exercise geometry selects an exact known exercise and required joints.
5. Android accelerator ownership is implemented in BlazePoseGpuPlugin.java and GpuSessionOwner.java. Boot uses a preferred native session or two-thread CPU tensor interpreters. Worker errors/timeout dispatch failure and lifecycle cleanup; an app-level retry may be required. See apps/mobile/lib/infrastructure/pose/blazepose_gpu.dart:10–12,62–88; blazepose_detector.dart:65–100,196–222,277–344.
6. Preview uses a separately smoothed, upright image-coordinate map and BoxFit/crop-style projection. Front camera mirror is applied for display. The default delivery-clock policy clears stale display on 250 ms accepted-result absence or 500 ms absolute capture age, checked every 100 ms. The analyzer still requires fresh results. Held preview is separate from measurement. The controller stops/drains the camera on pause, clears temporal state, uses scope ownership to avoid cross-account reuse, and closes worker resources on exit. The implementation's normal exercise payloads carry derived summaries and optional descriptive backup. Neither camera frames nor raw pose maps are fields of the workout backup contract. Opt-in local diagnostics and controlled historical video capture are separate evidence modes. See apps/mobile/lib/features/workout/application/pose_preview_controller.dart:133–182,359–451,488–587 and functions/src/modules/workouts/workout-backup-validation.ts.

## Landmark inventory used by analysis

| Workload | Required groups |
|---|---|
| Squat | Visible shoulder, hip, knee and ankle; corresponding world joints may supply diagnostics. |
| Curl | Selected shoulder, elbow, wrist and hip. |
| Calf Raise | Visible hip, knee, ankle, heel and foot index/toe. |
| Shoulder Press and Lateral Raise | Bilateral shoulders, elbows, wrists and hips. |
| Floor Push-Up | Visible-side shoulder, elbow, wrist, hip and ankle; opposite shoulder, knee and world geometry are conditionally used. |
| Reach & Tap | Shoulders and hips establish alignment/scale; elbow and wrist points support hand control/qualification. |
| Move & Catch | Both shoulders and hips determine torso center/scale. |

Model contract, camera/worker lifecycle and capture tests are source evidence. See apps/mobile/test/blazepose_contract_test.dart, blazepose_geometry_test.dart, blazepose_gpu_test.dart, pose_failure_recovery_test.dart and pose_preview_controller_test.dart. Current physical latency/accuracy conclusions require the evaluation sheets.
