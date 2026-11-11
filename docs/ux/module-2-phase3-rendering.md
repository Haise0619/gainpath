# Module 2 Phase 3 — skeleton rendering

The profiling scope is Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press.

## Baseline before code changes

The fixture drives the ordinary camera viewport with 120 synthetic delivered poses at a virtual 50 ms interval. A stub counts calls to the camera controller's preview builder. The pre-change run produced 120 additional camera preview builds and failed the regression assertion. The seven existing Phase 0 diagnostics tests passed. These are Flutter test work counts. Physical camera FPS, native inference and displayed-frame jank remain unmeasured for this change.

ADB started successfully and listed zero devices on 11 November 2026. Current physical startup, inference, rendering, resource and voice measurements remain unavailable. The historical [October GPU validation](../architecture/2026-10-06-pose-filtered-gpu-validation.md) observed 19–21 drawable FPS and 75–83 ms from callback to first CPU paint under an experimental configuration. It supplies context for the observed lag and does not characterize the current release or ML Kit.

| Investigation | Existing evidence or instrument |
| --- | --- |
| Camera startup | Phase 0 camera/model and route-to-camera spans. The camera span includes enumeration and initialization. It ends before stream startup. |
| Pose FPS, inference and processing | Accepted FPS and delivery gaps, native inference, worker and host durations. The accepted FPS denominator excludes rest. |
| Drops, stale inputs and results | Separate replaced, stale-before-processing, stale-result and invalidation counts. The camera callback timestamps input after snapshot work. |
| Flutter rendering | Local fixture isolates avoidable rebuilds. Add bounded build/raster/total-span and skeleton-paint observations to the opt-in recorder for the physical run. |
| CPU, GPU and memory | Existing process RSS and resource counts cover memory trend and ownership only. Per-thread CPU, GPU load, allocations and thermal state require device profiling. |
| TTS | Initialization and native start callback spans already exist. Acoustic latency requires an external measurement. |
| Rest | Source inspection shows the analyzer stops counting while the preview and detector keep working. Capture rest duration and inference completions during rest for comparison before choosing a power policy. |
| Exercise switches | Route-to-camera and route-to-ready include setup and calibration. Current routes create their own camera, model and TTS. Profile those separately before considering reuse. |

## ML Kit Pose Detection evaluation

| Area | GainPath BlazePose | Google ML Kit Pose Detection |
| --- | --- | --- |
| Architecture | Explicit person detector, tracked ROI with periodic redetection, landmark worker, CPU and optional OpenCL path. GainPath controls scheduling, decoding and resets. | Managed streaming tracking. Base and accurate variants choose CPU/GPU with fallback and warm-up differences. [Android guide](https://developers.google.com/ml-kit/vision/pose-detection/android) |
| Landmark compatibility | 33 normalized upright image landmarks, independent confidence fields, optional hip-relative metric world landmarks, and ROI/pose presence. Squat and Floor Push-up consume world geometry when available. | The 33-point topology can map to preview links. Pixel coordinates need rotation, mirror and scale normalization. In-frame likelihood and experimental pixel-relative Z cannot supply equivalent presence, visibility or metric world geometry. [Landmark API](https://developers.google.com/android/reference/com/google/mlkit/vision/pose/PoseLandmark) · [Pose overview](https://developers.google.com/ml-kit/vision/pose-detection) |
| Frame overhead | Flutter camera copies planes to a snapshot before scheduler admission, then sends them to a worker for sampling, tensor input, inference and decode. | Native image input could remove Dart copies. Flutter-plane input may retain copies, channel transport and repacking. A native adapter would need image-lifetime and ownership tests. These are integration inferences. [Input formats](https://developers.google.com/ml-kit/vision/pose-detection/android#2._prepare_the_input_image) |
| Latency | The current Phase 0 spans can distinguish host work, inference and delivery. Current physical values are pending. | Google publishes roughly 30 FPS for base and 23 FPS CPU / 30 FPS GPU for accurate on Pixel 3 XL. Those figures do not measure this app's camera-to-paint path or establish an advantage on GainPath hardware. [Android SDK comparison](https://developers.google.com/ml-kit/vision/pose-detection/android) |
| Accuracy and integration | Existing geometry, calibration, confidence and persistence rules depend on the current output contract. | Different tracking, confidence and occlusion behavior could shift full/partial counts, especially side/floor poses and foot landmarks. The Android API is beta and bundles additional code/assets. GainPath's current Android API 26 minimum already meets the SDK's API 23 requirement. [Android guide](https://developers.google.com/ml-kit/vision/pose-detection/android) |

The shared BlazePose lineage and topology do not establish output equivalence or an end-to-end speedup. A separate A/B prototype is deferred because current measurements show avoidable Flutter viewport work and do not isolate a detector or transport bottleneck.

## Implementation and verification plan

1. Keep the camera viewport stable while fresh pose delivery invalidates only the overlay paint layer. Preserve camera metadata updates, aspect/mirror projection, clearing, and diagnostic rendering.
2. Project each visible anatomical point once per paint and reuse it for the original connections and dots. Keep the existing Responsive and Smooth choices without adding frame interpolation latency.
3. Reuse the bounded Phase 0 recorder for paint and engine timings and rest inference counts. Compare the local fixture before and after, test lifecycle and output behavior, and run affected Flutter and pose tests, analysis and Android build.
4. Profile the six retained exercises with the [Phase 0 device procedure](module-2-phase0-implementation.md#exact-remaining-physical-baseline-procedure). Decide rest inference, resource reuse and any detector experiments from matched evidence.

## Implemented result

The ordinary viewport holds the camera texture tree stable while a frame notifier drives the overlay's repaint boundary. A new delivered pose can paint on the next scheduled Flutter frame without rebuilding the camera widget. Camera metadata changes still rebuild projection geometry. Pause, failure and close clear the paint source. The existing diagnostic layout continues to support refined/filtered comparisons and primitive visibility observations.

The painter projects each anatomical point once and reuses the coordinates for the existing links and joints. It allocates lag-observation collections only when those diagnostics are enabled. Responsive and Smooth retain their current source selection and filters. Analysis continues to receive its existing fresh detector output.

| Deterministic check | Before | After |
| --- | --- | --- |
| Camera preview builder calls caused by 120 delivered synthetic poses | 120 | 0 |
| Observed skeleton paints for the 120 deliveries | Baseline counted camera builds | 120 |
| Landmark map lookups per painter call on the complete 33-point fixture | 103 | 33 |
| Pixel comparison against frozen pre-change painter | Reference | Equal in 16 mirror, size, confidence and offscreen variants |

The viewport regression additionally reads rendered pixels to verify that clearing the pose and switching to an incompatible aspect remove the green overlay. The existing fixture also verifies rest frames complete inference without adding accepted tracking frames. The rest policy continues to need device CPU/power and restart-latency comparison before a change is selected.

Phase 0 diagnostics now include camera snapshot and stream-start durations, skeleton CPU paint duration and capture-to-paint age, and app-wide engine build, raster and total-span samples. Capture-to-paint starts at the post-snapshot timestamp and ends at CPU paint. Build/raster over-budget counters use the display's reported refresh rate and retain the sampled budget. They screen for possible jank. DevTools is still needed to identify dropped presentation frames and attribute time. Frame timings arrive in batches while the workout binding is active, so route-boundary samples may include adjacent work.

Rest duration and processed-during-rest counts complement the existing accepted-FPS, drop/stale, TTS and resource metrics. An inference completion is attributed to the rest state at host completion. It may have started before the boundary. Fixed metric/signal vocabularies and existing bounded recent samples/report caps apply. Recorders retain scalar observations and ephemeral audio correlation only.

Fresh verification on 11 November 2026 passed 363 affected Mobile tests across 57 files with 13 optional skips, 759 pose tests, and 28 quality/refined/lag diagnostic tests with one feature-flag skip. Scoped analysis of seven Dart files is clean. The arm64 Debug APK built successfully. Its retained artifact is `build/module2-phase3-20261111/phase3-app-debug.apk`, SHA256 `1B3D08D415B381E89F1AADB41C63CD15D4889F58FA27236C75D81F5FC306424E`. Independent review found no Critical or Important issue. Tests and build used the inspected workspace containing the existing unrelated changes. The commit contains the scoped Phase 3 deltas.

## Remaining physical baseline

ADB listed zero connected devices during this phase. Current camera startup, end-to-end pose latency/FPS, stale/drop rates under real load, screen jank, CPU/GPU utilization, native/Dart memory, TTS/acoustic latency and exercise transition p95 require a matched physical run.

Use the reviewed profile build with `GAINPATH_WORKOUT_BASELINE=true` on the six retained exercises. Record 20 cold and 30 warm opens, at least 1,000 processed frames per exercise, rest and next-set cycles, and 30 same-view and different-view transitions. Use DevTools to inspect build/raster timelines and isolate CPU, and Perfetto or Android profilers for native/GPU scheduling and memory. Capture speaker and Bluetooth starts against an external acoustic reference, then complete the 45–60 minute resource and thermal soak. The Phase 0 procedure specifies configuration and preservation details. [Device procedure](module-2-phase0-implementation.md#exact-remaining-physical-baseline-procedure)

Compare the same saved build configurations and labeled movements. Revisit ML Kit only if those measurements identify a substantial inference or frame-transport cost that its native streaming architecture could address. A future experimental adapter would need matched camera-to-paint p50/p95, startup/reacquisition and drop rates, CPU/GPU/memory, and six-exercise full/partial/occlusion validation with explicit confidence/world-coordinate handling before production consideration.
