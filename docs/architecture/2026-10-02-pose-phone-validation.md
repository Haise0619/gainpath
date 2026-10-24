# Step 2 physical Android validation handoff

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Physical inference and rendering were exercised on 2026-10-02 on Xiaomi `23013RK75C` (`mondrian`), serial `xiaomi-device-serial-redacted`, Android 13 / API 33. Runtime tensor validation succeeded and real 33-landmark output was observed. A viewport subscription bug prevented painting initially; it is now fixed, with green skeleton and diagnostic circles visible and confirmed by the user. Full Step 2 acceptance remains **pending** because perceived latency, body alignment and intermittent tracking still need investigation, along with the remaining orientation/lifecycle checks. See [rendering diagnosis and measured evidence](2026-10-02-pose-rendering-diagnosis.md).

Local verification: 111 mobile tests including rendering regressions, 14 pure Dart pose tests, clean analysis for both, and successful Android debug build. APK contents include hash-matching models, license and ARM64 TFLite native libraries. Rendering review found no material findings. These checks do not substitute for complete physical acceptance.

## Verified implementation

Two bundled assets were inspected before coding; full shapes, dtypes, tensor graph indices and hashes are in `apps/mobile/assets/models/tensor_manifest.json`. All tensors are float32:

| Model | Input | Outputs, in interpreter ordinal order |
| --- | --- | --- |
| Detector | `[1,224,224,3]`, RGB −1…1 | 0: `[1,2254,12]`; 1: `[1,2254,1]` |
| Full landmark | `[1,256,256,3]`, RGB 0…1, rotated body ROI | 0: `[1,195]`; 1: `[1,1]`; 2: `[1,256,256,1]`; 3: `[1,64,64,39]`; 4: `[1,117]` |

Model ID: `mediapipe-full-e9a5c5cb-det-9ba9dd3d`. CPU, two interpreter threads, persistent background isolate. Native startup checks exact names/shapes/types and asset hashes. Detector zero letterbox, landmark replicated-border crop, SSD/weighted NMS, expanded rotated ROI, anatomical/confidence/world mapping, heatmap refinement and inverse image/world projection are implemented. One Euro filtering resets on loss/reacquisition, gaps and camera geometry changes. Analysis timestamps are monotonic callback delivery times, not sensor exposure timestamps.

Only local camera foundation is connected to the member Workout UI. There is no workout persistence/upload or scoring. Default builds preserve mock and Firebase routes; a development define exposes **Try live camera preview**, with local consent before camera access. Do not use **Start guided session** to test the real pipeline; that remains the existing simulated or unavailable action.

## Connect and run (PowerShell)

1. Connect the phone with a data-capable USB cable. Enable Developer options and USB debugging, then accept the computer's RSA debugging prompt. The phone must appear as `device`, not `unauthorized` or `offline`. API 26 or newer is required.

```powershell
$adb = 'C:/Users/Ngzhe/AppData/Local/Android/sdk/platform-tools/adb.exe'
& $adb devices -l
Set-Location 'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile'
flutter run -d xiaomi-device-serial-redacted --dart-define=BACKEND=mock --dart-define=GAINPATH_POSE_PREVIEW=true
```

Replace the serial if another phone is used. For this local validation build, sign in with `member@example.com` / `password123`, complete any displayed member setup, open the **Workout** tab, scroll to **Try live camera preview**, accept local tracking consent, and grant Android camera permission. The front camera is selected when available. Stand far enough away to include head, hands and feet with good lighting.

To verify rear-camera geometry, end the preview and rerun with the additional define `--dart-define=GAINPATH_POSE_LENS=back`. This is a development selection; there is no camera switch during active inference.

Alternatively install the built mock debug APK:

```powershell
& $adb -s xiaomi-device-serial-redacted install -r 'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk'
& $adb -s xiaomi-device-serial-redacted shell am start -n com.zyang.gainpath/.MainActivity
```

Do not uninstall or clear app data to troubleshoot without checking what it contains. `flutter run` displays debug metrics; in another PowerShell terminal aggregate-only logs can be captured with:

```powershell
& $adb -s xiaomi-device-serial-redacted logcat -v time 'flutter:I' '*:S' |
  Select-String 'POSE_FOUNDATION_METRICS' |
  Tee-Object -FilePath 'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/step2-device-metrics.log'
```

## Required phone checks

- Both native models initialize and invoke with the validated runtime signatures; no missing native library, operator or tensor errors.
- A real person produces 33 anatomical landmarks with supported confidence/depth/world outputs. Skeleton follows actual motion after smoothing; empty view clears it, occlusion hides uncertain joints and reacquisition does not reuse an earlier person's pose. Auxiliary ROI remains stable, including near image edges.
- Front and rear cameras: portrait, both landscapes and 180° turns. Verify anatomical left/right, front mirroring exactly once, no flipped/rotated overlay, and alignment at preview edges after cover cropping. `previewAspectCompatible` must be true; unequal negotiated fields of view require a hardware-specific transform before acceptance. Aspect agreement alone does not prove identical sensor crop.
- Pause/resume, Home/background/lock screen/return, Android permission denial/retry, End/back/disposal, repeated reopen and account logout. Camera indicator releases; old landmarks never return; user pause remains paused after backgrounding. No result, score, reward or activity upload is created.
- Continuous run for at least 60 seconds after warm-up, then repeated preview reopen. Record device/OS/lens/frame sizes, model hashes/version/runtime signatures, native inference average, total pipeline average, approximate delivered overlay FPS and received/processed/replaced/stale counts. Confirm responsive UI and bounded memory; the file-backed models avoid the plugin's buffer ownership leak.

Debug metrics every five seconds include `averageInferenceMillis` (combined native invocations per processed frame), `averagePipelineMillis` (preprocessing/decode/inference), `overlayFps` (delivered pose frames per active preview second, including empty detections), `landmarkCount`, `receivedFrames`, `processedFrames`, `droppedFrames`, `staleFrames`, model version, tensor-validation flag and camera geometry. One inference runs at a time; one pending frame is replaceable by the latest. Queued/completed results older than 250 ms are discarded; pause/orientation changes invalidate active generations. There is no unbounded queue. If a phone cannot deliver within this age, record the measurements and adjust the policy based on evidence before acceptance.

## Device results

| Field | Current evidence |
| --- | --- |
| Connected device | Xiaomi 23013RK75C / Android 13 / API 33 / serial xiaomi-device-serial-redacted |
| Camera/inference/33 landmarks | Real front-camera YUV420 720×480; upright image and preview 480×720; repeated 33-point output, with empty results and reacquisition also observed |
| Runtime tensor validation on phone | true; model mediapipe-full-e9a5c5cb-det-9ba9dd3d; tensor shapes as listed above |
| Preview orientation/mirroring/alignment | Portrait front camera, sensor/input rotation 270°; compatible aspects; visible overlay after binding fix. Full-body static screenshot broadly aligned; motion, rear camera and rotation checks pending |
| Native average / total pipeline average | Diagnostic snapshot 57.79 / 123.81 ms; later run without coordinate markers approximately 60 / 129 ms. Mixed development measurements, not production benchmarks |
| Approximate FPS / dropped / stale frames | Diagnostic snapshot 7.64 FPS, 3982 processed, 3926 displayed, 11052 replaced/dropped, 57 stale. Latest-frame policy unchanged. Later aggregate-only run approximately 7.4 FPS |
| Lifecycle and repeated reopen | Unit tests passed; physical run pending |

ML Kit, squat RepFSM/form diagnostics, anthropometric/spatial analysis beyond model projection, IMU, audio, accuracy aggregation, Firebase acceptance/upload and gamification remain deferred.
