# Step 2C: equivalent preprocessing optimization

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Status update: the [physical Step 2C comparison](2026-10-03-pose-step2c-physical-comparison.md) verifies the installed optimized profile APK and measures faster Xiaomi computation/throughput with fewer nonempty expiries. External gesture-response ranges overlap the baseline and moving-arm lag remains visible. Step 2 quality acceptance is not passed; Step 3 remains deferred.

The implementation, packaging and pending-device notes below preserve the state before the user's optimized installation and recording. The bounded preprocessing change passed local tensor-equivalence, mobile-test, analysis and host AOT performance checks; use the linked comparison for subsequent physical evidence.

The user authorized this optimization independently of the new external recording. The Xiaomi keeps the pre-optimization profile build until that recording is captured. No optimized APK is installed as part of these local checks.

## Evidence and scope

The [Step 2B quality baseline](2026-10-02-pose-quality-validation.md) measured about 54 ms preprocessing per processed frame, compared with 69 ms native inference, in the 60-second front-camera profile run. Preprocessing therefore accounts for approximately 44% of worker computation. The 99 nonempty overlay expiries in that run remain unresolved; a host speedup does not establish that phone tracking is now continuous.

Only `apps/mobile/lib/infrastructure/pose/blazepose_geometry.dart` changes production behavior in this pass:

- Compute ROI sine/cosine once per tensor; cache column products and compute row products once per row.
- Cache immutable dimensions, rotation, format and plane references for one preprocessing call, instead of repeatedly resolving those properties for every sampled pixel.
- Reuse bilinear floors/complements and chroma coordinates without changing arithmetic order.

The two column scratch arrays use 4 KiB at the 256-pixel landmark input size. They and the sampler are local to the call; no cache survives into another frame or session. The public preprocessing signature and all downstream interfaces stay the same.

The original pixel-center convention, projection arithmetic order, camera orientation mapping, independent plane strides, YUV coefficients/clamping, RGB/BGRA channel mapping, four-pixel bilinear interpolation, border rules and Float32 normalization are preserved. In particular, this does not interpolate YUV before RGB conversion or use incremental affine coordinates that could change rounding.

Frozen: model assets/version `mediapipe-full-e9a5c5cb-det-9ba9dd3d`, tensor layouts, detector/landmark thresholds, two interpreter threads, detector/ROI cadence, One Euro parameters, 250 ms age budget, watchdog and one-active/one-replaceable-pending policy. Camera resolution, decoded landmarks, inverse projection and preview mirroring/cover-crop are unchanged. No RepFSM, scoring, audio, upload, fallback or Step 3 work is included.

## Numerical and local verification

`test/support/preprocessing_baseline.dart` freezes the pre-optimization kernel, including its own original projection math. It is an oracle, not an alternate production implementation; do not update it alongside the optimized kernel.

`test/blazepose_preprocessing_equivalence_test.dart` compares complete Float32 tensor byte hashes in 96 cases: RGB, BGRA and YUV; four rotations; 224/256 model inputs with their respective normalization; zero/replicate borders; full-frame and fractional expanded/rotated ROI. Fixtures have odd dimensions, nonuniform/saturated samples, padded rows and independent chroma strides. Existing geometry tests separately anchor expected pixel values, rotation and border behavior. These are refactoring guards: they passed with the original kernel and must continue passing with the optimized one.

Verification results:

- 17 focused geometry/equivalence tests passed.
- All 127 mobile tests passed with preview and quality defines.
- `flutter analyze --no-pub`: no issues found.
- Read-only implementation review found no actionable issues.
- The manual AOT benchmark failed its speedup gate with the original implementation, then passed with this change. Timing is a manual gate, not a flaky unit/CI assertion.

The benchmark validates full tensor hashes before timing, warms each kernel in five batches, measures nine alternating-order batches of five calls and retains every batch duration. Its manual gate requires at least a 1.10 old/new time ratio in both landmark cases, with no case more than 5% slower. It uses synthetic YUV420 720×480, rotation 270° and chroma pixel stride 2; it does not invoke TFLite or a camera.

Final Windows x64 / Dart 3.10.8 AOT run, rounded for readability:

| Preprocessing case | Frozen original median | Optimized median | Less time |
| --- | ---: | ---: | ---: |
| Detector, full frame, 224×224 | 3.44 ms | 3.31 ms | about 4% |
| Landmark, rotated ROI, 256×256 | 6.47 ms | 5.38 ms | about 17% |
| Landmark, expanded edge ROI, 256×256 | 6.05 ms | 4.79 ms | about 21% |

An earlier run of the same final kernel measured approximately 8%, 14% and 19% less time, respectively. Normal host timing variation is retained rather than selecting a single number as a device claim. Both runs passed the manual gate. These results establish equivalent faster host preprocessing; they do **not** measure Xiaomi preprocessing, camera-to-display delay, inference latency, delivered FPS or filter signal delay.

Reproduce from `apps/mobile` in PowerShell:

```powershell
./tool/run_pose_preprocessing_benchmark.ps1 `
  -DartExecutable 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' `
  -VerifySpeedup -ResultName 'preprocessing-host-aot'
```

The helper creates a standalone pure-Dart AOT harness under ignored `build/pose-quality/preprocessing-aot`; this avoids unrelated Flutter/TFLite native build hooks. It uses already-resolved workspace packages and does not modify dependency versions or product analysis settings. Raw benchmark JSON, tests and analysis logs remain under ignored `apps/mobile/build/pose-quality/`.

## Matched physical before/after protocol

The new mirror recording has now been [analyzed and preserved as the pre-optimization physical baseline](2026-10-03-pose-physical-latency-baseline.md). It supplies independent P/C/S brackets on one presentation timeline, with overlapping P→C uncertainty and a censored arm crossing. The optimized APK remains uninstalled; repeat measurements are pending.

The [existing external video](2026-10-03-pose-external-video-analysis.md) is baseline evidence for **displayed preview → displayed skeleton response only**. Its approximately 300 ms manual crossing midpoint summary is not physical source-to-display latency. Do not combine that video with unrelated callback-to-paint logs to infer missing physical stages.

Before optimization is installed:

1. Use the installed Step 2B **profile** build directly on Xiaomi 23013RK75C. Keep Flutter/Android Studio Run stopped. Start a fresh preview session and allow warm-up.
2. Record an original 60 FPS-or-higher external video with the actual moving person and the GainPath display visible together in the same shot. Fix the external camera position, make the screen sufficiently legible and keep the full body in the preview.
3. Perform several distinct slow arm raises/lowers, pauses and knee bends. Use events that can be identified on the actual person, preview image and relevant skeleton joint. Record a short still period as well.
4. Preserve the original file. Record approximate framing, light, camera settings, app build, device temperature/warm-up and motion sequence. Do not enable phone screen recording for just one side of the comparison.

After the original baseline file is saved, install the preserved Step 2C profile APK, then repeat the same session, movement and recording protocol under approximately matched conditions. Use the same phone, lens, resolution, profile build mode and frozen pipeline settings. A different process/session is expected; confirm runtime tensor validation and new session-created health counters before collecting data.

Capture a matched 60-second static run and movement phases with the existing diagnostics. Compare camera received, processed and delivered FPS; detector/landmark preprocessing and invocation; decode/ROI and landmark post-processing; filtering; callback/input-to-UI and first-paint ages; replaced inputs, stale results, explicit empty reasons and expired overlays. Preserve model confidence/pose presence. Separate native/worker computation from physical response latency. Recheck Pause/background/return, End/reopen and resource release with fresh frame timestamps. A shorter computation time alone is not full quality acceptance.

## One-video latency analysis and uncertainty

For each recognizable event, bracket actual physical motion at frames/times `P=[p0,p1]`, its displayed camera-image event at `C=[c0,c1]` and its displayed skeleton event at `S=[s0,s1]`, all on the **same external recording's presentation timeline**. Report original frame indices and conservative elapsed-time ranges:

| Boundary | Conservative interval |
| --- | --- |
| Physical movement → displayed camera preview | `[c0-p1, c1-p0]` |
| Displayed camera preview → displayed skeleton | `[s0-c1, s1-c0]` |
| Physical movement → displayed skeleton | `[s0-p1, s1-p0]` |

Compute the total directly from P and S. Do not add the two interval ranges and count the shared camera-event uncertainty twice. Overlapping brackets mean that event does not resolve a positive delay; retain that uncertainty rather than forcing a precise value.

Use actual video timestamps, not the nominal FPS alone. At 60 FPS adjacent samples are roughly 17 ms apart, but movement interpretation, motion blur, rolling shutter, screen scanning, viewing perspective and landmark prediction/smoothing add uncertainty. Define the same event consistently for the real person, camera image and joint. A skeleton hidden during a crossing produces censored evidence; report the gap and wider bounds, or exclude that crossing with its reason. Describe observed gesture-response delay, which includes filter/prediction effects, separately from CPU computation or timestamp age.

Report repeated-event ranges and uncertainty, not artificial millisecond precision. The external camera observes displayed pixels; callback-to-first-CPU-paint instrumentation does not establish display presentation or sensor exposure time. Keep results from these different boundaries separate.

## Pending device gate

Local implementation verification and Android profile packaging are complete. The new pre-optimization recording is now analyzed and preserved; optimized installation and the matched physical repeat remain the next device phase. Phone improvement claims wait for that comparison. Step 2B acceptance remains pending stable full-body tracking, reasonable anatomical alignment, explainable reacquisition, measured physical latency/FPS and lifecycle/resource evidence. Do not tune smoothing, thresholds, model variant, freshness or backpressure while evaluating this pass.

Packaging used `flutter build apk --profile --no-pub` with `BACKEND=mock`, `GAINPATH_POSE_PREVIEW=true` and `GAINPATH_POSE_QUALITY_DEBUG=true`; exit 0. The output was copied to an isolated filename and **not installed**:

| Artifact | SHA-256 |
| --- | --- |
| Preserved baseline `build/pose-quality/step2b-instrumented-profile.apk` | `502e6ed53b9a0c2cb0eae0b9c7c0798b436bbf393434267fc7651a4ba6c08cc5` |
| New `build/pose-quality/step2c-preprocessing-profile.apk` (146887038 bytes) | `bce7c611c493747dc3a8731c76508310c324aa1aae90c2393937c2afd5d318b4` |
| Packaged preprocessing source `lib/infrastructure/pose/blazepose_geometry.dart` | `1bf8e9011900202436f3dd2a0c562a33dff0e6834a0c303ce262d6c4a0ba040c` |

Paths above are relative to `apps/mobile`. Both the asset files and their copies inside the new APK retain the exact detector/landmark hashes from the frozen contract. The model version alone therefore cannot distinguish this optimization; use the APK hash for build provenance. Detailed local build output is `build/pose-quality/step2c-profile-build.log`, and final benchmark output is `build/pose-quality/preprocessing-aot/preprocessing-host-aot-final.json`.

Only after the original pre-optimization recording has been saved, use the matched optimized build:

```powershell
& 'C:/Users/Ngzhe/AppData/Local/Android/sdk/platform-tools/adb.exe' `
  -s xiaomi-device-serial-redacted install -r `
  'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2c-preprocessing-profile.apk'
```

Keep IDE Run stopped, launch the installed app directly and create a fresh preview session. Repeat the same physical and instrumented protocol before deciding whether this optimization helps phone latency or expiry. No change to the remaining frozen settings is authorized by a host benchmark result.
