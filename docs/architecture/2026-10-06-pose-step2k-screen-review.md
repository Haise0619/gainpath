# Step 2K — close-screen evidence review

## Decision

The displayed refined green/yellow arm drawing already trails the camera image on some transitions. Magenta filtered joints trail the refined drawing further. **Filtering is an added source of signal delay, but it is not the only visible source.** The first visibly lagging boundary is displayed camera → refined drawing; this recording cannot separate input age, inference/delivery delay and landmark prediction error within that boundary.

Step 2 quality is **not accepted**. No production parameter, model, application source or APK is changed by this review. Step 3 remains deferred. The refined skeleton remains a diagnostic, not a production smoothing replacement.

## Original, timestamps and build attribution

Original: [VID_20261006_121700.mp4](C:/Users/Ngzhe/Downloads/VID_20261006_121700.mp4), 345,235,210 bytes. SHA-256:

```text
aee51bc821b261e5d452dcaf26fe30b8c05158740744fbc7dccf4c7d46fc85b1
```

The file is decoded directly and left unchanged. HEVC Main, stored 3840×2160, rotation −90°, displayed upright 2160×3840. Container duration 43.63 s; **2,581 decoded frames**, zero-based indices 0–2580. Timebase 1/90000; first PTS 0, last PTS 3,925,251 (**43.613900 s**). Average presentation rate is **59.15545 FPS**, despite nominal 60 FPS metadata. Interframe intervals range from 8.40 to 100.48 ms; twenty exceed 25 ms. All event timing below uses decoded presentation timestamps, not frame/60.

Recorder metadata identifies a Xiaomi 17, model 25113PN0EG, Android 16. This is the second camera. The GainPath test phone remains **Xiaomi 23013RK75C, Android 13**.

The screen caption identifies `Refined skeleton / filtered dots`. The native-resolution badge at frame 360 reads `F 008479 idle t=50.1 B0 visible none`, matching session **1791260177008479**, created at 12:16:17.008 local, PID **24061**. This is a newer session than the five bounded phase captures in the [parent report](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-refined-skeleton-ablation.md). Their joint samples are not timestamp-matched to this video.

Read-only ADB verification finds the installed APK matches the preserved Step 2K profile artifact:

```text
8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff
```

The Step 2I filtered-drawing rollback APK remains preserved with SHA-256 `747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4`. Model version remains `mediapipe-full-e9a5c5cb-det-9ba9dd3d`; beta 0.3, minCutoff 1, derivative cutoff 1, CPU threads 2, freshness 250 ms and watchdog 100 ms remain unchanged. Models/contracts, thresholds, ROI cadence, camera resolution, projection/mirroring and latest-frame policy are unchanged.

## Observable boundaries and crossing uncertainty

- **C:** anatomical movement in the displayed camera image.
- **R:** corresponding refined inverse-ROI joint/segment, drawn green/yellow.
- **S:** corresponding filtered magenta joint.

Only screen boundaries are observable. Physical→preview, physical→skeleton and total physical camera-to-display latency are not measured. No screen interval is added to callback/UI/paint telemetry.

The anatomical elbow is partly obscured by the loose sleeve. Several raises only graze shoulder level, while the photographed phone screen has uncalibrated perspective. **Elbow crossing times are censored**; the sleeve edge is not treated as an elbow centre. There is no reliable anatomical-elbow C→R delay distribution or average from this clip.

The following four image-right **wrist** cases are supplemental illustrations, not substitutes for elbow measurements or an exhaustive event dataset. Camera wrist and refined wrist crossings use their ipsilateral shoulder bands. Earlier movements are generally slower; later movements are more abrupt. These are visual descriptions, not the earlier controlled `Capture 20s` phases: the video remains in idle capture state.

Each manually selected endpoint is expanded by two actual decoded frames for motion blur, screen scan and transition ambiguity. This is an analyst allowance, not a statistical confidence interval; shoulder-band and perspective uncertainty remains conditional. For brackets C=[C0,C1], R=[R0,R1], delay is [R0−C1,R1−C0], rounded outward to 50 ms. Negative lower bounds indicate overlapping uncertain observations, not evidence that inference anticipates movement.

| Supplemental event | C frames / actual PTS s | R frames / actual PTS s | Conservative C→R interval |
|---|---|---|---|
| Earlier wrist raise | 424–446 / 7.277744–7.645711 | 430–452 / 7.378011–7.754267 | −0.30 to +0.50 s |
| Earlier wrist lower | 466–482 / 7.996567–8.264300 | 478–488 / 8.197367–8.364700 | −0.10 to +0.40 s |
| Later wrist raise | 1405–1415 / 23.772122–23.956144 | 1411–1427 / 23.872522–24.156944 | −0.10 to +0.40 s |
| Later wrist lower | 1435–1445 / 24.290811–24.458144 | 1447–1457 / 24.491611–24.658789 | 0.00 to +0.40 s |

All conservative intervals include zero. They do not establish a precise minimum delay, a slow/fast difference or a speedup. Visible transition sequences nevertheless show residual lag in R, with S further behind. The qualitative witness and the uncertain crossing statistics answer different questions; neither supplies total physical latency.

## Same-screenshot refined/filtered witnesses

![Selected motion and bottom-pause screenshots](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2k/video/wrist-motion-and-pause.jpg)

Coordinates below are **640×640 external-video crop pixels**, not pose image pixels or painter coordinates. Crop: upright source x=480, y=1000, width=1280, height=1280, scaled to 640×640. Yellow-ring bounding-box midpoint and magenta-mask centroid are selected within bounded manual windows. An analyst ±6 crop-pixel allowance per centre gives ±12 pixels for separation; it is not a statistical confidence interval.

| Decoded frame / PTS s | Image-right wrist R centre | S centre | Conservative R/S separation |
|---|---|---|---|
| 432 / 7.411456, earlier raise | (544.0, 311.0) | (535.99, 344.67) | 22–47 crop px |
| 1455 / 24.625344, later lower | (557.5, 338.0) | (557.82, 298.85) | 27–52 crop px |
| 2292 / 38.728856, short bottom pause | (451.0, 497.5) | (449.19, 499.22) | 0–15 crop px |

At frame 1455 the camera arm has lowered further than the refined drawing; the filtered dot remains above the refined wrist. During the later bottom pause R and S converge. This supports positional trailing during movement and convergence during a pause. It does **not** convert displacement into milliseconds, quantify static jitter or compare these external crop units with earlier 480×720 image-space displacement statistics.

## Alignment, holds, links and blanks

Gross shoulder/hip/knee/ankle alignment is qualitatively reasonable in the overview. No consistent left/right reversal or uniform global cover-crop offset is apparent. Dynamic arm agreement is poorer than the static body agreement. Anatomical elbow occlusion and photographed-screen perspective prevent a calibrated anatomical accuracy score; prior mathematical projection checks remain separate evidence.

The clip has brief bottom pauses around 3–6 s and 38.3–40.5 s. No severe stationary shaking is obvious there, but breathing, camera movement and frame-step updates prevent a registered jitter estimate. There is **no sustained stationary top hold**: raised peaks/brief pauses cannot establish ten-second top-hold stability or a settling-time distribution. Initial approach and final approach are excluded from stability interpretation.

Some links/rings are doubled or faint during transitions, including frame 444 at 7.61224 s and frame 1395 at 23.60472 s. Exposure/display-scan blending makes these ambiguous. They are not counted as confidence rejections or separate missing-link events. No unambiguous sustained elbow–wrist link disappearance is established in the reviewed sequences. No active bounded joint ledger accompanies this session, so per-joint confidence causes cannot be assigned from the earlier five captures.

**No confirmed whole-skeleton blank is observed.** Overview and motion sequences, low-colour-count candidates and a supporting scan of all 2,581 upper-body crops retain skeleton-coloured pixels. The scan finds no zero-green frame, but background colours can contaminate it; it is supporting evidence rather than an independent renderer-acceptance test. It does not prove uninterrupted visibility of every joint or the lower-body skeleton.

The badge's `B0` is **not** a zero-blank attestation: the bounded blank observer is inactive when no capture phase is selected. No blank duration or reason-coded event list is manufactured from that badge. Matching scalar telemetry independently shows no whole-pose health transition in the observed recording interval, as described below. Earlier startup prediction-loss blanks remain documented in the parent report and are not erased by this clip.

## Separate telemetry from the recording session

Nine complete scalar polls span **12:17:02.013–12:17:42.013**, route 45.005063–85.005063 s, a **40.000 s** interior window of session 1791260177008479. The rounded frame-360 badge provides approximate session/window attribution, with an analyst ±0.2 s allowance; it is not sensor/display clock synchronization. Scalar logs contain no saved camera frames or continuous landmark trajectory.

| Observation | Recording-session interior value |
|---|---:|
| Camera received | 1,201; 30.025 FPS |
| Processed / delivered / nonempty / drawable | 538 each; 13.45 FPS |
| Unique first CPU paints | 539; 13.475 FPS |
| Latest pending frames replaced | 662 |
| Stale / empty / detector no-person / low whole-pose presence | 0 each |
| Camera copy / queue age mean | 0.83 / 17.18 ms |
| Detector preprocess / inference / decode-ROI mean, 35 runs | 14.60 / 36.08 / 0.17 ms |
| Landmark preprocess / inference / postprocess mean, 538 runs | 20.17 / 48.58 / 0.55 ms |
| Total preprocessing / native inference / worker mean | 21.12 / 50.93 / 72.81 ms |
| Host processing / filter execution mean | 74.09 / 0.123 ms |
| Callback→UI / callback→first CPU paint mean | 92.14 / 104.25 ms |
| Pose age at UI / first CPU paint mean | 91.43 / 103.54 ms |
| Refined source selection / worker trace mean | 0.024 / 0.052 ms |
| Joint diagnostic delivery / paint mean, idle | 0.003 / 0.021 ms |
| Blank diagnostic delivery / paint mean, idle | 0.021 / 0.022 ms |
| Flutter build / raster mean | 1.29 / 3.07 ms |

These are cumulative completion-cohort sum/count differences. One more first paint than new delivery is consistent with an in-flight boundary crossing; this is not a same-input paired trajectory. Detector-only timings have their own 35-run cohort and must not be summed as though every frame ran the detector. The low idle diagnostic cost does not estimate active capture overhead. CPU filter cost does not measure filter signal delay; first CPU paint is not actual display presentation.

No scalar health transition occurs in the inspected route interval 43–89 s. Interior endpoint whole-pose presence is 0.998–1.0 and last detector confidence 0.9771–0.9808, with tracked ROI. No expiry event is observed in this interval; `expiredEmptyFrame` remains unchanged. This supports continuous nonempty detection during visible arm lag. It does not establish zero per-joint rejection, and inactive bounded diagnostics cannot attest every potential blank mechanism.

The computation values are consistent with the earlier five sessions' 13.3–13.8 drawable FPS and 102.7–106.0 ms callback→first CPU paint. This is a consistency check, not a matched build comparison or an extra latency stage. No external C/R/S interval is fused with these CPU times.

## Next isolated investigation

Native inference accounts for about **70% of worker computation** in this session (50.93/72.81 ms); landmark inference dominates the native stage. My recommendation is a **GPU delegate feasibility and same-input numerical agreement audit**, followed only if viable by an isolated CPU-versus-GPU backend experiment. This targets a measured computation bottleneck without another smoothing/threshold change. It does not assert that computation is the sole cause of the visible lag.

First inspect the bundled `tflite_flutter` 0.12.1 runtime's delegate availability, exact model operator coverage, creation/invocation thread requirements and disposal behaviour on this Xiaomi. Keep runtime/library version and model bytes fixed. Compare detector and landmark outputs on identical deterministic test inputs, then compare pose/ROI/visibility outcomes and lifecycle behaviour. Any partial delegation or unsupported operators must be reported. GPU execution may help, but partial CPU/GPU graphs can be slower due to synchronization, according to the [official LiteRT GPU guidance](https://developers.google.com/edge/litert/performance/gpu). Device support and benefit remain unproven.

Do not silently upgrade the runtime or change preprocessing, model variant, CPU thread count, thresholds, smoothing, cadence, geometry or freshness to make the experiment work. If the current runtime cannot support an isolated backend experiment, stop at the feasibility finding. Any subsequent physical comparison must preserve the CPU control and separately measure computation, refined response, stability and resource handling. **No delegate or tuning change is implemented in Step 2K.**

## Evidence and verification scope

Local analysis evidence is under [step2k/video](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2k/video): original SHA/metadata, full decoded PTS, crop contract, manual observations and scripts, selected frame hashes, contact sheets, witness figure, scalar recording-session logs/parser, telemetry summary and installed-APK attestation. Full-resolution original remains only at its supplied path. Derived images are analysis of the user-provided recording; the application did not record/upload camera frames or landmark streams.

The analysis is reproducible from the original and retained PTS/selection scripts. Conservative intervals, censored anatomical elbows and brief-hold coverage are retained explicitly; no synthetic pose or workout activity is created. This turn changes reports/provenance only. Existing host checks remain 46 affected candidate tests passed, 151 default tests passed with 15 define-gated skips, and clean mobile analysis. No mobile test rerun is necessary for report-only changes. Original/APK hashes, analysis manifests and the existing 181-file candidate source manifest are rechecked before finalizing this review.
