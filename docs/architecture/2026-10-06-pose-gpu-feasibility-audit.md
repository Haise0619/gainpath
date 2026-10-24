# Step 2L — GPU delegate feasibility audit

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Decision and current boundary

The Xiaomi's **Adreno 730** executes both existing BlazePose models through the already-bundled GPU delegate. Native logs report full delegation: **291/291 detector nodes** and **332/332 landmark nodes**, each as one partition. A separate app-context test initially falls back to OpenGL. Adding **only the optional `libOpenCL.so` declaration to the throwaway probe manifest** resolves the loader failure and enables OpenCL, with approximately **11.47 ms detector / 12.54 ms landmark** mean native invocation time on synthetic inputs. No production code, model, runtime dependency or parameter is changed.

**Hardware/library, full-graph and app-context feasibility pass.** This supports preparing an isolated GPU backend candidate, not adopting GPU for workouts or declaring Step 2 quality accepted. Real-person output agreement, simultaneous detector/landmark ownership, Flutter worker OS-thread handling, live-camera performance and application lifecycle are still unproven. Step 3 remains deferred.

A separate, camera-free diagnostic APK is built, signed, installed and tested after the user accepts Xiaomi's installation prompt. The initial `INSTALL_FAILED_USER_RESTRICTED` is resolved. The installed GainPath APK and its data remain unchanged. The standalone OpenGL and manifest-enabled OpenCL artifacts and scalar reports are both preserved.

## Isolation and provenance

The current Step 2K profile APK remains the source of the extracted native libraries and models, SHA-256 `8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff`. The Step 2I production-drawing control remains preserved, SHA-256 `747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4`.

The resolved package is **tflite_flutter 0.12.1**. Its local Android Gradle file specifies **LiteRT and LiteRT GPU Maven 1.4.0**. The extracted native runtime independently reports **`2.20.0-dev0+selfbuilt`** through `TfLiteVersion`; the Maven artifact version and native build string are different identifiers, not an inferred upgrade.

| Existing arm64 APK entry | SHA-256 |
|---|---|
| `libtensorflowlite_jni.so` | `246a3e0f91308ff27dfd74eea8fe03622303c6bd1d54b5d722f0abe099d2bd57` |
| `libtensorflowlite_gpu_jni.so` | `b4f04c3bea1eef65e4e5173dc5d9b1f37d872abcb81e1773283560ab55951eef` |
| `pose_detection.tflite` | `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c` |
| `pose_landmark_full.tflite` | `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f` |

ELF inspection verifies exported interpreter/tensor C API functions and `TfLiteGpuDelegateV2Create`, `TfLiteGpuDelegateV2Delete`, `TfLiteGpuDelegateOptionsV2Default`. Local package bindings load these same two library names on Android. The probe uses the package's bundled C headers, exact extracted libraries and exact model bytes. Device payload hashes match the host payload.

The isolated native probe SHA-256 is `7431329102db3a995854f26e562f310869c2339e0a837b3d50e60419ed252321`. It is a throwaway audit executable, not product code. All probe/build scripts, synthetic fixtures and binaries stay in ignored `apps/mobile/build/pose-quality/step2l`.

Frozen production values remain beta 0.3, minCutoff 1, derivative cutoff 1, CPU threads 2, freshness 250 ms, watchdog 100 ms. Models/contracts, detector and landmark thresholds, cadence, resolution, coordinate transforms and latest-frame policy are unchanged. No production source file is edited. No SDK/runtime upgrade is made.

## Model and runtime verification

FlatBuffer inspection finds detector PAD, DEQUANTIZE v3, CONV_2D, DEPTHWISE_CONV_2D, DENSIFY, ADD, DEPTH_TO_SPACE, RESIZE_BILINEAR v3, RESHAPE and CONCATENATION. Landmark operators include PAD, CONV_2D, DEPTHWISE_CONV_2D, ADD, RESIZE_BILINEAR v3, MAX_POOL_2D, RESHAPE, LOGISTIC and DEQUANTIZE v2. Static opcode names alone do not establish GPU execution: sparse/constant operations may be optimized during preparation. Actual native full-delegation logs are the stronger evidence for these exact assets and driver.

On both CPU and GPU, runtime validation checks every input/output count, dtype, rank, shape and name/index:

| Model | Input float32 | Outputs float32, in index order |
|---|---|---|
| Detector | `input_1 [1,224,224,3]` | `Identity [1,2254,12]`; `Identity_1 [1,2254,1]` |
| Landmark | `input_1 [1,256,256,3]` | `Identity [1,195]`; `Identity_1 [1,1]`; `Identity_2 [1,256,256,1]`; `Identity_3 [1,64,64,39]`; `Identity_4 [1,117]` |

GPU options use precision-first settings: precision loss disallowed, maximum-precision first priority, fast-single-answer preference, the existing default quantization-support flag, one maximum partition and no requested serialization. These are the defaults exposed by the package's `GpuDelegateOptionsV2`, not a tuned FP16 experiment. Each GPU interpreter owns its delegate; interpreter deletion precedes delegate deletion.

The [official GPU guidance](https://developers.google.com/edge/litert/performance/gpu) warns that partial CPU/GPU execution can be slower due to synchronization. No split partition was observed here. This does not replace app-context measurement or guarantee speed on other devices.

## Bounded synthetic same-input test

Device: **Xiaomi 23013RK75C, Android 13, serial xiaomi-device-serial-redacted**. SurfaceFlinger identifies **Qualcomm Adreno 730, OpenGL ES 3.2**; the delegate selects OpenCL. The camera service reports no active camera client before testing.

The standalone native executable runs as Android shell UID 2000, not GainPath. It uses public C ABI interpreter create/allocate/copy/invoke/read/delete calls on one OS thread, with CPU threads fixed at two. There is no camera, Firebase, audio, workout state or network connection. It generates three deterministic tensors in memory: neutral gray, channel/position ramp and checkerboard. Detector inputs are within −1…1; landmark inputs within 0…1. These are inference smoke fixtures, not anthropometric or camera evidence.

For each model/context: three create/invoke/dispose cycles; three fixtures per cycle; eight warm-ups per backend/fixture; twenty-four alternating-order measured invocations per backend/fixture. This gives **216 measured plus 72 warm-up invocations per backend/model/context**, 1,152 invocations per context. Three contexts are tested: shell OpenCL, app OpenGL, and app OpenCL, **3,456 total invocations**. All cycles finish, all tensor contracts validate, all compared outputs are finite, and owner-thread checks pass. Process cleanup is separate from a native leak measurement or Flutter lifecycle regression test.

Output arrays are held only in memory. Retained logs contain aggregate differences, confidence/count summaries and timings, not frames, videos or landmark streams. Synthetic results cannot create workout activity.

### Numerical agreement

The following values are the maximum across the nine shell fixture/cycle comparisons for each output; the app OpenCL test reproduces these maximum differences. They are exploratory measurements, not a retrospectively chosen production acceptance tolerance.

| Model / output | Maximum absolute difference | Maximum relative L2 |
|---|---:|---:|
| Detector 0, boxes/alignment fields | 0.0019684 | 2.96×10⁻⁶ |
| Detector 1, score logits | 0.0008240 | 7.57×10⁻⁷ |
| Landmark 0, 39×5 mixed coordinates/logits | 0.0084458 | 1.87×10⁻⁵ |
| Landmark 1, whole-pose presence | 5.48×10⁻⁷ | 8.19×10⁻⁴ |
| Landmark 2, segmentation output | 2.6392 | 2.47×10⁻⁴ |
| Landmark 3, heatmaps | 0.0008889 | 4.34×10⁻⁶ |
| Landmark 4, world coordinates | 0.00003434 | 3.98×10⁻⁵ |

Do not describe all tensors as identical. Segmentation has a larger maximum absolute difference, although the current pose adapter does not consume output 2. Its relative L2 does not establish pixelwise segmentation acceptance. Output 0 mixes units and logits; its maximum is not a measured projected anatomical error. Tiny near-zero whole-pose outputs explain why their relative error can exceed their small absolute error.

Detector maximum probability differs by at most **7.41×10⁻⁸**; both backends have zero candidates at the unchanged 0.5 threshold. Whole-pose presence differs by at most **5.48×10⁻⁷**; all landmark fixtures stay below 0.5. Per-joint visibility/presence threshold counts agree on these synthetic tensors. **No accepted person is tested**, so accepted-person ROI, auxiliary tracking, heatmap refinement, projection, painter acceptance and near-threshold confidence agreement remain untested. This cannot justify production GPU acceptance or claim stable real-person landmarks.

### Native invocation timing — separate shell scope

| Model | Shell CPU mean / fixture-group mean range | Shell GPU mean / fixture-group mean range | GPU initialization range |
|---|---|---|---|
| Detector | 153.82 / 144.26–157.50 ms | 16.85 / 15.64–17.69 ms | 1.32–1.77 s |
| Landmark | 218.14 / 206.83–229.94 ms | 28.02 / 26.05–31.01 ms | 1.24–1.26 s |

Invocation timers exclude input/output copy, preprocessing, queueing, filtering, UI and display presentation. Group ranges are not pooled confidence intervals or percentiles. Timings show useful GPU execution in this diagnostic context, **not an app speedup ratio**. Shell CPU times differ substantially from the preserved app's approximately 36 ms detector and 49 ms landmark inference. The reason is not established; foreground scheduling/power/runtime context cannot be assumed equivalent. Probe CPU affinity includes CPUs 0–7, which does not prove identical scheduling or frequencies. No thermal/power-controlled production comparison is claimed.

The existing app's 13.45 drawable FPS and approximately 104 ms callback→first CPU paint remain its latest baseline. GPU shell timing is not substituted into that pipeline to invent delivered FPS, a new total latency or solved physical responsiveness.

## App-context artifact and unresolved integration checks

The shell-directory executable is denied when invoked as GainPath's UID (`Permission denied`). A separate package is built: **`com.zyang.gainpath.gpuprobe`**, label **GainPath GPU feasibility**. It requests no camera/network permissions and has no workout/authentication APIs. A single background Java thread invokes the same native probe, leaving the Activity event loop available. Models and libraries in its APK match the extracted source hashes. It tests detector then landmark, so it still does not test two GPU interpreters active together.

Preserved initial OpenGL control: [step2l-gpu-feasibility-opengl-control.apk](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2l/step2l-gpu-feasibility-opengl-control.apk), **12,354,347 bytes**, SHA-256:

```text
e77bcb468bec15ed7b9b8366acb125fb42f8fd193497bcef9c1f9c6254d65b00
```

Manifest-enabled OpenCL artifact: [step2l-gpu-feasibility-only.apk](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2l/step2l-gpu-feasibility-only.apk), **12,354,347 bytes**, SHA-256:

```text
bd04c769f170e9504437a7d9694161d1e186488fb898ffc7466514bc69315a64
```

Both APKs are signed and signature-verified with the local Android debug key. Entry-by-entry comparison proves that only `AndroidManifest.xml` and signature metadata differ. All code, models and native libraries are byte-identical. Equal total APK sizes do not imply identical manifests; APK alignment padding differs.

The APKs compiled successfully with the installed NDK/Android SDK; no Gradle/network dependency download or production project change was needed. An initial Java stub compilation failure was corrected by compiling against Java 8 APIs and using D8 desugaring. Native probe compilation uses warnings as errors. These are throwaway artifact build checks, not mobile pipeline tests.

After installation, PID **9459**, native owner thread **31171**, completes both models on **OpenGL**. OpenCL direct loading fails with missing `libvndksupport.so`, then the ICD path reports undefined `clEnqueueReleaseEGLObjectsKHR`; the delegate explicitly falls back to OpenGL. Both graphs still delegate fully, with finite outputs and matching synthetic confidence counts. Its mixed raw landmark maximum difference is 0.0100441, heatmap maximum 0.00148201, world maximum 0.00003624, and whole-pose probability maximum difference 3.40×10⁻⁷. Segmentation maximum difference is 3.16593; it remains unused by the current pipeline and unaccepted for segmentation use.

The vendor's public library list contains `libOpenCL.so`. Android [documents that target API 31+ apps must explicitly request non-NDK vendor libraries](https://developer.android.com/guide/topics/manifest/uses-native-library-element). The original probe and GainPath/plugin manifests lack this declaration. The single-variable probe adds `<uses-native-library android:name="libOpenCL.so" android:required="false" />` only to its temporary application manifest, without adding vendor binaries, lowering target SDK or changing delegate options.

After that update, PID **9458**, native owner thread **32263**, completes both models on **OpenCL** with full delegation and no OpenCL-loader/fallback error. This validates the library-access diagnosis on this Xiaomi. Both models are created, invoked and deleted on the same Java-owned OS thread within each app process. This does not establish Dart receive-port worker ownership.

| Separate app context | Model | CPU native mean / group mean range | GPU native mean / group mean range |
|---|---|---|---|
| Original manifest, OpenGL | Detector | 49.97 / 32.42–79.74 ms | 30.45 / 19.00–34.38 ms |
| Original manifest, OpenGL | Landmark | 46.10 / 36.08–52.88 ms | 39.30 / 34.73–41.53 ms |
| Optional library declared, OpenCL | Detector | 44.55 / 33.94–60.81 ms | 11.47 / 9.22–12.66 ms |
| Optional library declared, OpenCL | Landmark | 38.14 / 34.99–42.80 ms | 12.54 / 10.75–14.22 ms |

These are sequential app sessions with interleaved CPU/GPU invocation order inside each fixture, not randomized thermal-controlled production trials. CPU ranges vary. The OpenCL results show a promising native-computation benefit in app context; they do not prove delivered FPS, live anatomical stability or visible lag improvement. Camera/Flutter GPU rendering contention is absent. OpenCL initialization takes **0.99–1.08 s detector** and **1.01–1.03 s landmark**, so startup/cancellation also needs explicit testing. No physical latency is inferred.

Before any live candidate, verify GPU construction, invocation and deletion ownership. The [official native GPU contract](https://developers.google.com/edge/litert/android/gpu_native) requires the same EGL context, or the creating OS thread when the delegate creates its context. The existing Dart worker serializes requests, but this audit has not demonstrated its OS-thread identity across initialization, later receive-port messages and close. Serialization alone is not an ownership test. Do not blindly add a delegate to its options.

Installed Dart is **3.10.8**. The public [Isolate.pinToCurrentThread API](https://api.dart.dev/dart-isolate/Isolate/pinToCurrentThread.html) is marked since 3.13 and is absent from this SDK. The local embedder header does expose `Dart_SetCurrentThreadOwnsIsolate`; that is not evidence that calling it through FFI inside Flutter provides a supported, correctly serviced worker. No SDK upgrade or pinning workaround is implemented. If stable ownership cannot be demonstrated in the current worker, evaluate an explicitly owned native inference thread before a live GPU candidate.

**Recommended next step:** a development-only GPU candidate using an explicitly owned inference thread and the verified optional library declaration, preserving the CPU default/control. First check two model/delegate instances coexisting and alternating on that thread, startup/cancellation/disposal, and bounded **same-input live-person** agreement in memory. Report the actual OpenCL/OpenGL backend and fail explicitly on GPU/ownership failure rather than silently claiming GPU when falling back to CPU. Keep every other production setting frozen. Only then measure delivered FPS, refined response, held stability, confidence/link outcomes and lifecycle on the Xiaomi. No live GPU pipeline or Step 3 implementation is made in this feasibility spike.

## Evidence and verification

Evidence is under [step2l](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2l): host APK/ELF/operator audit, hashed payload, throwaway probe sources, native stdout/stderr and Android logs for all three contexts, scalar analysis/summary, both separate APK provenances, manifest isolation, scheduling context, camera status and final attestation.

Final device attestation matches the preserved GainPath APK `8d618a92…` and the tested manifest-enabled probe `bd04c769…`. The copied app model hashes match the originals. The temporary package is force-stopped and uninstalled successfully after scalar collection; the five shell payload files and their temporary directory are removed. Local control/candidate artifacts remain preserved. GainPath's existing task is brought back to the foreground, and the camera service reports **Active Camera Clients: []**. No user footage, frame or landmark stream is collected by the probe, and no production APK/data is replaced.

No mobile/pose source changes are made in this audit, so application tests are not rerun for the spike/report. The existing 181-file candidate source manifest and both preserved APK hashes are checked again before finalization. Device process termination, installed GainPath hash and camera-idle status are checked separately. This preserves the existing Step 2K test evidence without claiming new Flutter GPU lifecycle tests passed.
