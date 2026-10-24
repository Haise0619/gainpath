# Step 2N: normal filtered overlay on the preserved GPU backend

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Current outcome

All five bounded physical captures are complete. The user confirms that the filtered green skeleton shakes less than the refined yellow rings, but also confirms clearly visible lag during fast movement. **The normal filtered display is proven; overall Step 2 quality has not passed.** Keep this GPU build experimental, CPU rollback/default preserved, and Step 3 deferred. No numerical parameter is tuned in this step.

Warmed capture interiors deliver approximately 19–21 drawable FPS with 75–83 ms callback→first CPU paint and no recorded whole-overlay loss/expiry increments. The full fast phase retains two brief freshness clears during a reopened preview's startup comparison. Per-joint confidence rejection remains. Normal disposal releases the camera and all three native owner threads. These internal results do not establish external C→R/C→F latency; the requested original screen-video path is pending. Bounded physical aggregate results and hashes are preserved in `physical-summary.json` and `physical-evidence-manifest.json` under the Step 2N evidence root.

## Purpose and boundary

The Step 2M paired screen review verified faster GPU computation and fewer whole-overlay interruptions, but did not establish a numerical external response speedup or accept anatomical quality. Both recordings displayed an unsmoothed refined green diagnostic skeleton. This next check restores the existing normal filtered primary skeleton to assess the intended Workout overlay before another numerical tuning experiment.

The user approved proceeding after this proposal. This is a separate diagnostic/profile artifact, not GPU production adoption. CPU remains the default and rollback. Step 3, repetition counting, scoring, form diagnostics, audio, upload and Firebase workout acceptance remain deferred.

Only build define `GAINPATH_POSE_REFINED_SKELETON` changes from `true` to `false`. No application source change is required. The existing painter uses the controller's One Euro filtered frame for green links and joints; yellow refined rings and magenta filtered diagnostic points continue to use the same inference timestamp and preview transform. The source badge becomes `Local camera preview`; periodic foundation telemetry must confirm `primarySkeletonSource: filtered` and `inferenceBackend: opencl_required` before physical interpretation.

Green-to-camera movement now concerns C→F. Yellow-to-camera concerns C→R. Do not relabel the previous refined green measurements as filtered response, sum these intervals with callback telemetry, or infer physical-person latency from a screen-only video.

## Artifact and immutable control

Candidate: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2n-filtered-opencl-profile.apk`, 147,313,022 bytes.

SHA-256: `6792b7c8776aa222e93985a32454d9f770b0823939824f90d93c9e8ccc014da9`.

Refined GPU display control: `step2m-opencl-candidate-profile.apk`, SHA-256 `89d9a15d3d6094be143c75ebeb179d797546a1bac6cbbb90a5b15403a098c977`.

CPU refined rollback: `step2k-refined-skeleton-profile.apk`, SHA-256 `8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff`.

All other Step 2M defines remain identical: mock backend, local preview, quality/joint-lag/blank diagnostics, GPU backend and bounded startup same-input agreement. Default/release behavior is unchanged. CPU shadows are excluded from performance assessment and must have closed before measurement.

Frozen: beta 0.3, minCutoff 1, derivative cutoff 1; model assets/version and tensor contracts; thresholds; detector/ROI period 15 processed frames; residual CPU threads 2; camera resolution; projection/mirroring/cover crop; 250 ms freshness; 100 ms watchdog; latest-frame replacement; Step 2C/2I preprocessing. Rendering colours, topology, joint acceptance and diagnostic caps remain unchanged.

## Build and host verification

- Snapshot/recheck of 215 existing source/test/assets/config files: all hashes unchanged.
- Preserved Step 2M GPU and Step 2K CPU APK hashes: unchanged.
- APK entry sets: identical. Only `lib/arm64-v8a/libapp.so`, `lib/armeabi-v7a/libapp.so` and `lib/x86_64/libapp.so` differ, reflecting the Dart compile define.
- Model assets and packaged TFLite native libraries: independently hash-matched to the control.
- Android DEX and compiled manifest: byte-identical.
- Focused GPU/pose/painter/UI/lifecycle suite with candidate defines: **49 tests passed, 10 refined-display-only tests skipped**. Existing pixel tests verify that normal green geometry follows filtered coordinates under both mirror settings, rather than the refined sibling.
- Focused pose/controller/view/painter analysis: **no issues**.
- Android profile build: successful. APK signature verifies with v2 and the existing Android Debug signer.
- Installed on connected Xiaomi `xiaomi-device-serial-redacted` / `23013RK75C` using `adb install -r`; app data preserved. Device-side installed APK SHA-256 matches the candidate above. GainPath was force-stopped and reopened for a fresh session; no hot reload is used.

Evidence root: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2n/`. `pre-build.json` preserves the original snapshot/defines; `build-profile.ps1` records the exact build invocation; `tests.log`, `analysis.log`, `build.log`, `signature.log`, `provenance.json`, and `installed-verification.json` preserve verification. Bounded scalar/report collection reuses the existing Step 2M collector; no camera/video/continuous landmark stream is newly persisted by the app.

## Physical protocol and acceptance

Use a completely fresh front-camera preview on the Xiaomi, IDE Run stopped, full-body framing and comparable lighting. Warm for approximately 15 seconds and verify backend/model/tensor/display-source telemetry. Then use the existing separate 20-second captures: still, slow one-arm raises/lowers, faster raises/lowers, top hold, bottom hold. Keep the same arm and stay within the preview. Retain the existing capture caps and count censored observations; a missing visible button countdown does not prove the capture failed, so confirm phase start/end in logs.

Where practical, record an original 60 FPS close-screen video with the camera arm, green skeleton, yellow rings and magenta points legible. It observes C→R and C→F only. Use actual decoded PTS, censor unobservable shoulder-level crossings, and report uncertainty rather than precise physical latency. Such a user-provided video is separate from bounded app diagnostics.

Evaluate normal green skeleton stability during held periods away from button interaction; settling; dynamic arm alignment and trailing; actual link/joint acceptance and off-viewport predictions; reason-coded whole-overlay blanks; interior FPS, worker/native/preprocessing and callback-to-first-CPU-paint age. Compare whole-session and capture-interior counters separately. Faster compute alone does not accept filtered motion response. Yellow refined movement may remain noisier than the filtered skeleton by design.

Pause/background/resume/end checks verify no resource regression in the displayed-source configuration. GPU sustained thermal behavior, setup-cancellation stress and side-on anatomical quality remain separate outstanding acceptance items. No second variable is tuned if filtered lag remains unacceptable.

## Physical collection chronology

Installation and fresh preview configuration are verified. GainPath PID 31410, native owner OS thread 24015. Native logs verify OpenCL with 291/291 detector and 332/332 landmark nodes delegated. At 19:17:33.550 foundation telemetry reports the unchanged model/version, runtime tensor contract verified, 33 landmarks, `inferenceBackend: opencl_required` and `primarySkeletonSource: filtered`. Painter telemetry independently reports `filtered_skeleton`, an available primary source, 480×720 canvas and front-camera mirroring. Latest interval camera/processed/delivered/drawable FPS is approximately 30.22/21.21/21.21/21.21; the latest observed pose age at CPU paint is 83.48 ms. These are configuration/warm-up observations, not a controlled motion or held-stability cohort.

The bounded startup agreement completes twelve matched landmark inputs and one detector input over input timestamps 8,235,602–9,365,715 µs, then closes CPU shadows. Maximum refined-coordinate distance is 0.0047189 image px, world distance 0.000007879 m, and confidence difference 0.000021866. No nonfinite values, joint/whole-pose or ROI-availability flips occur. All eight full-body check joints are simultaneously accepted in zero startup pairs on both backends; the numerical gate does not certify full-body anatomy. Evidence: `preview-check-scalars.json` and `preview-check-native.log`.

Controlled captures and physical quality acceptance are pending. The warm-up cumulative counters include two overlay expiries and one low-pose-presence result; do not treat those startup-inclusive counters as a stable-phase loss rate or claim a zero-expiry session.

The user defers controlled captures until later. GainPath is force-stopped to release the diagnostic camera; camera service subsequently reports no active camera clients. This is process-stop cleanup, not a new graceful GPU-disposal/lifecycle acceptance. The candidate remains installed. Resume validation from a fresh warmed preview; no still/motion capture is claimed complete.

### Resumed physical session

At the user's later readiness confirmation, installed SHA-256 is rechecked and remains `6792b7c8…`. New PID 10106 and native owner 26557 verify a fresh OpenCL session; at 21:01:17 local phone log time, foundation and painter telemetry confirm the same model/tensor contract and filtered primary skeleton. Bounded startup agreement completes twelve landmark pairs over inputs 8,025,715–9,149,027 µs and closes CPU shadows, with no nonfinite/acceptance/whole-pose/ROI-availability flips. Maximum refined-coordinate difference is 0.0033025 image px and confidence difference 0.000031009.

The latest pre-capture interval reports detector-no-person with zero drawable overlay FPS. Startup-inclusive means and no-person processed FPS are not full-body quality/performance measurements. The user is instructed to return to full-body framing for the separate still capture; controlled results remain pending. Evidence is `resumed-preview-scalars.json` and `resumed-preview-native.log`.

### Completed still capture

Phone-local capture start is 21:05:23.723; the lag report completes at 21:05:43.787 (20.064 s). It records 388 nonempty pose outcomes, zero timestamp mismatches and no filter resets. The first 300 painted frames are retained; the cap is reached and later joint observations are censored. This does not shorten the twenty-second whole-overlay capture. The blank report has complete transport, zero logical/CPU-painted blank episodes, no event-cap overflow and no open episode at the end.

The same capture's interior uses periodic endpoints within start +4 s through start +19 s, spanning 10.004 s between count endpoints. Camera is approximately 30 FPS; processed/nonempty/drawable delivery is 19.09 FPS and unique CPU-painted rate 19.19 FPS. A one-frame count-endpoint difference is possible between delivery and paint. There are 191 nonempty deliveries, 192 unique CPU-painted frames, 109 latest-frame replacements and zero interior increments for empty/no-person/low whole-pose-presence results or freshness expiry. Approximate means: preprocessing 29.13 ms, landmark native 11.53 ms, total native 12.17 ms, worker computation 49.99 ms, callback→UI 70.00 ms and callback→first CPU paint 82.33 ms. These are internal timing boundaries only.

All retained shoulder observations and left elbow observations pass joint acceptance; right elbow is rejected once for visibility. Left wrist is rejected in 10/300 observations (presence 10, visibility 6, overlapping), and right wrist in 13/300 (presence 9, visibility 5, overlapping). Corresponding forearm draw commands are issued 290/300 and 287/300 times. Whole-overlay stability therefore does not establish uninterrupted limb links. Off-viewport observations are left/right elbow 6/6 and left/right wrist 17/7; off-canvas wrist observations are 4/6. These phase aggregates include button interaction/stepping into position and cannot attribute every boundary observation to stationary full-body prediction.

Retained coordinates are finite, projection residual is zero, and all representative painter samples identify `primarySkeletonSource: filtered`. Refined→filtered displacement median is approximately 0.70–0.88 image px for elbows/wrists; phase-wide means are approximately 3.23–3.74 px and p95 17.10–22.98 px. These include initial repositioning/settling and measure R→F separation, **not stationary jitter**. No coordinate trajectory is retained to manufacture a pure held-jitter estimate.

The user reports that **the green skeleton shakes less than the yellow refined rings**. This supports the intended smoothing effect in the normal overlay and narrows the diagnostic-green stability concern. It does not yet accept moving-arm response, anatomical accuracy or overall Step 2 quality. Slow/fast/top/bottom captures remain pending. Evidence: `still-lag-analysis.json`, `still-blank-analysis.json`, `still-interior.json` and the bounded still scalar/log files under the Step 2N evidence root.

### Completed slow capture

Capture `slow@490610110` lasts 20.036 s, with 378 nonempty pose outcomes, no timestamp mismatches and no filter resets. First 300 painted frames are retained; later joint observations are censored. The separate full-duration blank report is transport-complete, uncensored and records zero whole-overlay blank episodes.

The 10.001 s interior delivers/processes/draws 18.70 FPS (187 frames) with 113 pending replacements, and zero increments for empty/no-person/low-pose-presence results or freshness expiry. Approximate means: preprocessing 29.18 ms, landmark native 12.21 ms, total native 12.77 ms, worker 50.96 ms, callback→UI 70.36 ms and callback→first CPU paint 82.46 ms. These are internal measurements, not camera-preview-to-joint or physical-person latency.

Right elbow/wrist R→F displacement mean/p95 is 5.35/10.86 and 9.30/16.25 image px, respectively. This demonstrates retained spatial separation during motion with the unchanged filter, not a calibrated external lag estimate. Right elbow is rejected in 2/300 observations (one visibility, one presence); right wrist in 6/300 (presence six and visibility three, overlapping). Right upper-arm/forearm draw commands are issued 298/293 times. Right wrist is outside the canvas/viewport in six observations; right elbow has no such observation. Projection residual is zero and coordinates remain finite.

Several refined elbow threshold recrossings cluster within one near-shoulder interval, so automated crossing candidates cannot be averaged or treated as unique physical movements. The parser preserves wrist candidates and ambiguous elbow pairings for later interpretation. The user confirms capture completion without a qualitative slow-response judgment. Fast motion and top/bottom holds remain pending. Evidence: `slow-lag-analysis.json`, `slow-blank-analysis.json`, `slow-interior.json` and bounded slow collection files. Older captures appearing in the slow parser output are not assigned new interior statistics when their telemetry has aged out of the collector window; the original still evidence is preserved separately.

### Completed fast capture in a reopened session

Native logs show the prior owner 26557 closes at 21:08:32.623. A new preview starts at 21:10:31.924 and creates OpenCL owner 27322. Fast capture `fast@7523064` begins only 7.523 s into new quality session 1791292231505860 and lasts 20.022 s. This is not a continuous warmed extension of the slow capture. Bounded startup CPU comparison completes twelve person inputs and closes its shadows; its input interval is 7,894,594–8,924,490 µs. No numerical acceptance flips/nonfinite consumed values occur.

The capture records 411 nonempty pose outcomes, no timestamp mismatches and two `freshness_expiry` filter resets. The complete blank report has two short CPU-painted blanks near startup: at session 9.093/9.192 s, approximately 1.57/1.67 s into capture. CPU-painted durations are 47.15/15.87 ms. Both watchdog clears involve otherwise valid refined poses, not all-joint renderer rejection or no-person/low whole-pose-presence outcomes. They overlap the startup comparison's delivery/settling interval and are kept in the whole-phase evidence rather than hidden. Later hold captures are instructed to warm for at least fifteen seconds after any reopening.

The 10.001 s interior, after start +4 s, is beyond shadow comparison and has 213 processed/nonempty/drawable/unique-painted frames (21.30 FPS), 87 pending replacements and zero empty/no-person/low-pose-presence/freshness-expiry increments. Approximate means: preprocessing 25.49 ms, landmark native 11.47 ms, total native 12.02 ms, worker 44.96 ms, callback→UI 63.08 ms, callback→first CPU paint 75.41 ms. No physical or camera-preview latency is inferred.

First 300 joint observations are retained and later ones censored. Right elbow/wrist R→F displacement mean/p95 is 8.02/15.66 and 13.46/27.53 image px. Right upper-arm draw commands are issued in all 300 retained observations; right forearm 292/300, with eight right-wrist presence rejections. Right elbow/wrist off-viewport counts are eight each; wrist off-canvas count is eight. Coordinates are finite and projection residual is zero. These aggregates include the initial startup/repositioning interval and are not a pure steady-motion trajectory or stationary-jitter measure.

The new owner 27322 closes normally at 21:11:11.413. The user confirms fast capture completion without supplying a qualitative judgment of remaining green-to-camera lag. Such acceptance remains unresolved; smoother still behavior and internal timing do not substitute for it. Evidence: `fast-lag-analysis.json`, `fast-blank-analysis.json`, `fast-interior.json`, `fast-native.log` and bounded fast collection files.

### Completed top hold

Capture `topHold@40049757` starts approximately forty seconds into a new quality session 1791292427051395, beyond startup warm-up. It has 300 retained joint observations, no timestamp mismatches and a complete, uncensored blank report with zero whole-overlay blank episodes. The user confirms completion without an additional judgment of shaking or missing links.

The 10.001 s interior records 207 processed/nonempty/drawable/unique-painted frames (20.70 FPS), 93 pending replacements and no increments for empty/no-person/low-pose-presence outcomes. Approximate means: preprocessing 25.92 ms, landmark native 11.58 ms, total native 12.14 ms, worker 45.59 ms, callback→UI 67.48 ms and callback→first CPU paint 79.94 ms.

Retained right elbow/wrist rejection counts are 8/15 of 300 observations; left elbow/wrist 10/20. Phase-wide right elbow/wrist R→F mean/p95 is 4.71/19.99 and 5.93/32.23 image px. These include raising/lowering and repositioning, so neither those values nor the no-blank result establishes pure stationary jitter or uninterrupted individual links. Bottom hold and final cleanup remain pending. Evidence: `top-hold-lag-analysis.json`, `top-hold-blank-analysis.json`, `top-hold-interior.json` and bounded top-hold collection files.

### Completed bottom hold and normal disposal

Capture `bottomHold@185506091` uses the same warmed quality session as the top hold and lasts 20.040 s. It records 386 nonempty pose outcomes, no timestamp mismatches and no filter resets. The first 300 painted frames are retained and later joint observations censored. The complete, uncensored blank report records zero whole-overlay blank episodes.

The ten-second interior delivers/processes/draws 19.30 FPS (193 frames), with 107 pending replacements and no empty/no-person/low-pose-presence increments. Approximate means: preprocessing 28.91 ms, landmark native 11.49 ms, total native 12.10 ms, worker 49.25 ms, callback→UI 70.04 ms and callback→first CPU paint 82.79 ms.

Right elbow/wrist R→F mean/p95 is 2.71/13.76 and 2.97/15.28 image px. These phase aggregates include initial positioning and are not pure stationary jitter. Right elbow passes all 300 observations; right wrist has nine presence rejections and eight off-canvas/off-viewport observations. Left elbow/wrist have 10/13 rejections, and six left-shoulder observations are rejected. Right upper-arm/forearm draw commands are issued 300/291 times; left 290/287. Coordinates are finite and measured projection residual remains zero. Full-body anatomical acceptance cannot be inferred from these upper-body diagnostic samples.

The user confirms End preview and return to Workout. Native owner 27551 closes at 21:17:24.433, matching its construction/invocation thread. Camera service reports no active clients. All three completed native owners (26557, 27322, 27551) are absent from `/proc/10106/task/` while GainPath PID 10106 remains alive. This verifies normal route cleanup, not heap-leak freedom or setup-cancellation stress. No new manual-pause/background test is claimed in this capture series.

After collection, all 215 source/test/config/asset hashes, both preserved control APK hashes and all model/runtime hashes are rechecked and unchanged. APK differences still consist only of the three Dart AOT libraries for the single display-source flag. Evidence: bottom-hold bounded collection/analysis files, `final-cleanup.json` and refreshed `provenance.json`.

## Step 2N physical result and decision

| Capture | Drawable FPS, interior | Worker ms | Callback→UI ms | Callback→first CPU paint ms | Whole-phase blank episodes |
|---|---:|---:|---:|---:|---:|
| Still | 19.09 | 49.99 | 70.00 | 82.33 | 0 |
| Slow | 18.70 | 50.96 | 70.36 | 82.46 | 0 |
| Fast, reopened preview | 21.30 | 44.96 | 63.08 | 75.41 | 2, startup freshness expiry |
| Top hold | 20.70 | 45.59 | 67.48 | 79.94 | 0 |
| Bottom hold | 19.30 | 49.25 | 70.04 | 82.79 | 0 |

Each timing/FPS cohort spans approximately ten seconds between periodic endpoints selected within capture start +4 s through +19 s. Whole-phase blank counts cover the full twenty seconds and retain startup events; do not compare those scopes as identical. None of the warmed interior cohorts increments freshness expiry or empty/no-person/low-pose-presence outcomes. Neither these means nor the earlier Step 2M video comparison is a synchronized physical latency measurement.

The user reports both **less green-skeleton shaking than yellow refined rings in still pose** and **clearly visible green-to-camera lag during fast motion**. The user additionally notes that the current green skeleton visibly lags more than the green skeleton in `step2m_gpu_candidate_screen.mp4`. Step 2M green represents refined R, whereas Step 2N green represents filtered F; that observation compares different signal stages. It supports the unresolved stability/responsiveness tradeoff and must not be labelled a measured GPU inference regression. Current interior computation is healthy, but these are not matched external/thermal sessions and do not quantify the extra visible delay.

Normal filtered rendering is functionally proven and smooths visible motion, while the responsiveness criterion remains unmet. Existing confidence rejection still causes partial-link interruptions. Internal R→F spatial/crossing evidence supports a retained filter contribution, but the current C→R and C→F external timing boundaries have not yet been measured for this build.

**Keep the filtered GPU artifact as an experimental candidate and retain CPU rollback/default; do not claim overall Step 2 quality acceptance or proceed to Step 3.** No new numerical tuning is made. The next evidence task is the original filtered GPU close-screen recording, if available, with C (camera), R (yellow refined) and F (green filtered/magenta) scored separately using actual decoded PTS. If there is no recording, quantitative external timing remains unresolved; the user's visible-lag observation is retained without an invented latency value. A recording-path question is pending at report completion.
