# Step 2E: isolated One Euro beta experiment

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Final status 2026-10-05: all five internal phases and the paired external screen recordings have been analyzed. The [screen-video comparison](2026-10-05-pose-beta-screen-video-comparison.md) measures C→S only. Conservative response ranges overlap substantially, visible moving-arm lag and overlay blinking remain, and the beta 0.6 pass gate is not met. Beta 0.3 source and the preserved control profile APK are restored on the Xiaomi, with its installed hash verified. The Step 2C preprocessing optimization remains intact. Both candidate/control artifacts and evidence are preserved; Step 2 quality is not accepted and Step 3 stays deferred. The internal candidate results below remain historical evidence, not the current installed configuration.

## Authorized change and control

The sole production change is the existing preview controller's `PoseFrameFilter()` → `PoseFrameFilter(beta: 0.6)`. The shared filter default stays beta 0.3, preserving deterministic control fixtures and other callers. Preview image/world filtering uses the selected beta through the same existing implementation. All other behavior/settings are frozen.

The retained beta 0.3 diagnostic profile APK is `apps/mobile/build/pose-quality/step2d-joint-lag-logging-profile.apk`, SHA-256 `774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`. Its five designated phase reports and findings remain in [Step 2D report](2026-10-03-pose-dynamic-joint-lag.md). The optimized Step 2C baseline APK is also retained untouched. Rollback means reinstating the controller's default filter and reinstalling the preserved beta 0.3 diagnostic APK, without stacking another variable.

A pre-change manifest preserves 180 hashes covering mobile production source/assets/Android config, shared pose source and dependency declarations/lock. Post-change validation must identify exactly the controller, and restoring only its beta argument in memory must reproduce its control SHA. Control source is stored as `.dart.txt` to avoid analysis treating an archived copy as runnable source. Test source and report additions are not runtime variables.

Frozen: minCutoff 1, derivative cutoff 1, resetAfter 500 ms, per-joint confidence .5, both model assets/tensor contracts, detector/landmark thresholds, 15-frame detector/ROI cadence and existing loss handling, two interpreter threads, front YUV 720×480 / upright 480×720, mirror and cover/crop mathematics, 250 ms freshness, 100 ms watchdog, one active + one replaceable pending input, rendering acceptance and bounded diagnostics. Exact model bytes must match the control APK.

## Comparison method and limits

Use fresh preview route sessions with the same phone/framing/light and diagnostic controls. Capture still, slow, fast, bottomHold and topHold separately for 20 seconds. Manually tapping requires an initial three-second preparation hold; preparation representatives/maxima stay labeled and are not interpreted as controlled motion. New route clocks are never joined across phases. Pause/expiry/filter generations and acceptance gaps censor crossing matches rather than being interpolated.

For elbow/wrist, compare accepted same-direction shoulder-level input-time crossing brackets, refined-to-filtered displacement mean/median/p95/max, censored excursions, confidence and actual link rejection, image/canvas/viewport bounds, nonempty expiry, processed/delivered/drawable FPS, callback-to-UI/CPU-paint and diagnostic CPU overhead. Compare the raw/refined trajectories as well as outputs: different movement speeds or prediction excursions weaken an unpaired physical before/after conclusion.

Static/held *filter displacement* is not stationary skeleton jitter. The unchanged Step 2D logger retains only four fixed coordinate snapshots, not a continuous stream or temporal RMS jitter statistic. Compare held representative coordinate spans and user-observed shaking conservatively; preparation samples and body drift are confounds. Synthetic coordinate-only replay may quantify deterministic noise response separately, but cannot substitute for physical jitter measurement. If stability cannot be judged reliably, leave experiment acceptance inconclusive rather than declaring pass from median displacement alone. No diagnostic schema or continuous coordinate logging is added in this beta-only pass.

The experiment requires meaningful motion response benefit without materially worse stationary/held stability or tracking reliability. Crossing ranges overlapping substantially do not prove a benefit; unmatched crossings remain censored. No synthetic or internal callback-to-paint figure establishes total physical latency. Raw/refined prediction relative to displayed camera remains unresolved.

## Physical phase ledger

- [x] Still
- [x] Slow raise/lower
- [x] Faster raise/lower
- [x] Bottom hold
- [x] Top hold
- [x] Internal before/after decision and resource cleanup
- [x] Matched external P/C/S recording prepared; original-video analysis pending user recording

## External protocol after internal comparison

Use the previous mirror setup and original 60 FPS-or-higher second-camera recording: actual moving person in mirror plus GainPath phone display (camera preview and skeleton) simultaneously visible, approximately the same distance/light/framing. Repeat whole-arm raises/lowers with brief top/bottom holds; keep shoulder/elbow/wrist clearly visible and the hand within the preview. Preserve the original unedited recording. Analyze P (physical mirror movement), C (displayed preview movement) and S (displayed skeleton movement) on actual presentation timestamps with conservative event brackets, censored events, partial links and whole-skeleton blanks. Compare P→C, C→S and P→S independently; never add callback-to-paint telemetry to external timing.

Step 3, RepFSM, scoring, form/audio/upload/Firebase acceptance remain deferred. Beta 0.6 remains experimental until evidence satisfies the stated gate; no other tuning is authorized in this pass.

## Candidate artifact and verified installation

Candidate: `apps/mobile/build/pose-quality/step2e-beta06-diagnostic-profile.apk`, **147132798 bytes**, SHA-256 **`dd75e4f406d48d7ada1714e059d0bfb1de3438f1145961e0dc2bf04b62e0b9b2`**. Profile defines are identical to Step 2D: `BACKEND=mock`, `GAINPATH_POSE_PREVIEW=true`, `GAINPATH_POSE_QUALITY_DEBUG=true`, `GAINPATH_POSE_JOINT_LAG_DEBUG=true`. Installed on Xiaomi 23013RK75C, serial xiaomi-device-serial-redacted, Android 13/API33, package `com.zyang.gainpath`, at **2026-10-05 11:02:24** local; fresh PID **26849**. Device-side `sha256sum base.apk` matches the candidate exactly. Installer used ADB `install -r`; no IDE run/hot reload is used for captures.

The 180-file source/config manifest check identifies only the controller, and undoing its beta argument in memory recovers the control source hash. APK ZIP-content comparison finds only the three architecture-specific `libapp.so` entries changed. The two model assets and all **26 frozen native/manifest/resource entries** are byte-identical. Detector SHA remains `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c`; landmark full SHA remains `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f`. Provenance and ZIP-difference evidence: `step2e-beta06-provenance.json` in the ignored evidence directory.

## Host evidence, separate from physical acceptance

The controller-level synthetic 100 ms arm-step test failed on the beta 0.3 control at filtered y **0.445013** (required below .4), then passed with beta .6 while still smoothing and preserving confidence. Complete mobile suite: **138 passed / one preview-flag test skipped**; that UI file was subsequently run with preview enabled. Shared pose **14 passed**, bounded-parser **three passed**. Production analysis is clean after renaming the archived control Dart source to `.dart.txt`; the initial analysis failure came from resolving its copied relative imports inside the build folder, not the candidate pipeline. No application behavior/config was changed to repair that artifact naming issue.

The production PoseFrameFilter was run at both betas on the same existing synthetic coordinate-only trajectory. Slow-raise mean elbow/wrist displacement **27.05/35.16 → 23.94/30.33 image px**; fast-raise **75.67/96.47 → 63.79/78.57 px**. Some crossing brackets move one input sample earlier, others stay the same at this sampling rate. Synthetic held-top error **0.39/0.46 → 0.28/0.31 px**. A separately invented stationary sinusoidal-noise input has raw SD **1.837 px**, filtered SD **0.864 → 0.867 px**, approximately **0.3%** higher. These are fixture responses, not physical jitter or total latency measurements, and do not accept beta .6 on the phone. Reproducible script `step2e_synthetic_replay.dart.txt` and aggregate JSON `step2e-synthetic-comparison.json` retain no device landmark trajectory and cannot create workout activity.

## Beta 0.6 still phase — comparison remains observational

Fresh preview session **1791169485167243**, created **11:04:45.167**, PID26849. Capture **11:04:52.835–11:05:12.843**, start **7668379 µs**, duration **20.007462 s**. Preserved bounded source `step2e-still-20261005.log`, SHA-256 **`895fc5c479585b07ebe37b479312040909f793fa7b04a680b87fe756c11d44d0`**. **228 poses / unique painted observations**, zero timestamp mismatches/capacity limit, two unmatched paints ignored. 24 fixed samples reconstruct, confidence logits match decoded probabilities, timestamp metadata joins match; maximum numerical projection/viewport residual below 1.2×10⁻¹³ px, maximum transport record 894 bytes. Runtime tensor contract verified, model version unchanged, front YUV720×480→upright480×720, landmarkCount33.

| Joint | Mean / median / p95 / max image-px displacement | Control still median |
| --- | --- | --- |
| Left elbow | 3.18 / 1.00 / 12.66 / 47.23 | 0.90 |
| Right elbow | 3.73 / 1.04 / 17.67 / 31.89 | 0.85 |
| Left wrist | 2.91 / 0.78 / 12.28 / 36.30 | 0.93 |
| Right wrist | 5.20 / 1.09 / 28.43 / 52.94 | 0.98 |

No shoulder-level crossing. Peak representative input **8201293 µs**, **0.533 s after capture start**, is preparation (right elbow/wrist displacement 26.50/41.02 px), not steady-state noise. Midpoint **17606723 µs**: right elbow refined **205.464,452.078** → filtered **204.406,452.173**, displacement **1.06 px**; wrist **204.019,507.931** → **203.304,508.333**, displacement **0.82 px**, accepted/in view/arm links drawn. Final **27428295 µs** gives **0.15 / 0.07 px**. Midpoint/final filtered coordinates differ approximately **1.85 / 2.36 px**, but raw coordinates also change and filter generation changes after expiry. Two sparse endpoints cannot measure temporal jitter or exclude body drift.

All delivered outcomes `pose`. One nonempty expiry at age **254.593 ms**, restored after **3.457 ms** on the application clock; control still also had one expiry. Zero empty/stale/model-no-person/lifecycle loss during capture. Right upper/forearm draws **228/227**, left **226/223**; right elbow accepted all, right wrist one rejection, left elbow two, left wrist five. Full per-joint gate/clipping statistics remain in the bounded summary JSON; joint rejection and first-rejected link-endpoint counts are not added as independent events. No physical shake observation accompanied the user's `still done` response; stationary-noise acceptance remains unproven.

Separate interior **11:04:55.167–11:05:10.168** (~15s): camera **30.00 FPS**, processed/delivered/drawable **11.47 FPS**, preprocessing **34.46 ms**, native **50.93 ms**, worker **86.07 ms**, callback-to-UI **104.30 ms**, callback-to-first-CPU-paint **115.20 ms**, **278** replacements, no stale/empty, one nonempty expiry. Control still interior: **11.27 FPS**, worker **87.45 ms**, callback-to-paint **115.57 ms**; no meaningful computation-speed claim from these small observational differences. Trace/delivery/paint diagnostic CPU **0.040 / 0.006 / 0.105 ms**, filter execution **0.103 ms**. Physical latency is not derived by adding these to crossing response.

## Beta 0.6 slow phase — mixed response evidence

Fresh route **1791169666447195**, created **11:07:46.447**, capture **11:07:51.047–11:08:11.137**, start **4601041 µs**, duration **20.089580 s**. Source `step2e-slow-20261005.log`, SHA-256 **`2c2f90f5179f2aaabd4ffe900d5e2053aa96b9daedd5db3c4ef35d229c69b44f`**. **224 poses/unique paints**, zero mismatch/ignored/capacity limit; 24 complete representatives, matching timestamps/confidence, mirror/cover residual below 1.2×10⁻¹³ px, maximum record894bytes.

| Joint | Mean / median / p95 / max image-px displacement | Control slow median |
| --- | --- | --- |
| Left elbow | 2.83 / 1.11 / 14.28 / 43.28 | 1.02 |
| Right elbow | 6.74 / 6.85 / 12.04 / 19.53 | 5.77 |
| Left wrist | 2.46 / 1.21 / 10.54 / 28.10 | 0.92 |
| Right wrist | 12.18 / 12.99 / 21.52 / 27.12 | 11.48 |

Mean/median moving-arm displacement is **not lower** than control. Wrist p95 is modestly lower (21.52 vs22.53), elbow p95 lower (12.04 vs15.24), but preparation maxima and differing physical trajectories prevent attributing aggregate changes to beta alone. Candidate refined elbow crosses shoulder four times versus two in control; candidate raises are spaced roughly3.36–3.46s, versus approximately3.55–3.75s for control wrist raises. These are cycle intervals, not calibrated joint velocities; larger/faster movements are a substantial confound.

The unchanged shoulder-level event definition yields the following manually paired raises on the **candidate route input clock**:

| Joint/event | Refined bracket (s) | Filtered bracket (s) | Added response, outward-rounded |
| --- | --- | --- | --- |
| Elbow raise1 | 11.096506–11.167738 | 11.262279–11.399892 | .09–.31s |
| Elbow raise2 | 14.539801–14.636550 | 14.734105–14.762829 | .09–.23s |
| Elbow raise3 | 17.901957–17.997610 | 18.139888–18.193287 | .14–.30s |
| Elbow raise4 | 21.361169–21.431385 | 21.526353–21.596997 | .09–.24s |
| Wrist raise1 | 11.000056–11.096506 | 11.096506–11.167738 | 0–.17s |
| Wrist raise2 | 14.470287–14.539801 | 14.636550–14.734105 | .09–.27s |
| Wrist raise3 | 17.901957–17.997610 | 17.997610–18.139888 | 0–.24s |
| Wrist raise4 | 21.264893–21.361169 | 21.361169–21.431385 | 0–.17s |

Exact elbow response bounds **94.541–303.386 / 97.555–223.028 / 142.278–291.330 / 94.968–235.828ms**. Wrist **0–167.682 / 96.749–263.818 / 0–237.931 / 0–166.492ms**. No observed freshness reset lies inside these raise pairs. All four filtered elbow raises are recorded versus none in control slow, but the control had fewer refined elbow excursions and19 expiry resets, so improved crossing completeness is not an isolated beta effect. Wrist raise brackets substantially overlap the control's uncensored .3 bounds; three candidate zero lower bounds do not prove instantaneous response. Do not average these into a precise latency improvement.

Three accepted elbow descents have zero lower bounds and upper bounds **157.089 / 167.791 / 209.067ms**. First two candidate wrist descents **0–201.497 / 0–195.204ms**; the third refined descent has no filtered counterpart and remains **censored**, with freshness recovery shortly afterward. Raise2's descent is absent in both candidate crossing lists across a freshness-generation break and supplies no delay observation. Missing/refined/filtered events are not treated as zero-lag samples.

Midpoint **14470287 µs**, receipt/delivery/paint **14568591 / 14568743 / 14575561µs**: accepted/in-view elbow refined **162.661,397.962** → filtered **167.952,409.095**, displacement12.33px; wrist **108.156,395.663** → **114.342,414.655**, displacement19.97px. Their confidence is visibility **.9903/.9808**, presence **.9993/.9940**, and both right arm links issue draws. This still demonstrates signal trailing; it is not a same-trajectory comparison with the control midpoint. Peak representative **5300022µs**, only .699s after tap, is preparation. Final snapshot remains moving/near shoulder level and cannot be treated as a stationary hold.

All phase outcomes `pose`; **two** nonempty expiries at ages **251.208/255.472ms**, restoration gaps **9.670/22.472ms** on application clock, versus19control expiries. No empty/stale/no-person/low whole-pose-presence/lifecycle loss. Separate periodic interior **11:07:51.447–11:08:06.448**, approximately15s, includes early preparation: camera30.07FPS, processed/delivered/drawable11.20FPS, preprocessing36.52ms, native50.61ms, worker87.84ms, callback-to-UI105.59ms, callback-to-first-CPU-paint115.56ms,283replacements, zero empty/stale, one interior expiry (two full-phase). Diagnostic trace/delivery/paint **.041/.005/.067ms**, filterCPU .103ms. Control slow was computationally slower (worker104.63ms); beta does not optimize inference/preprocessing, so this observational performance difference is not claimed as a beta effect.

Right upper/forearm draws **219/218 of224**, left **223/217**. Full joint rejection/viewport statistics are preserved in the phase summary for final comparison. Confidence rejection remains separate from freshness expiry and from accepted-joint signal delay. Slow evidence alone does not meet the pass gate; faster motion and held stability are still required.

## First beta 0.6 fast capture — bilateral ancillary trial

Fresh route **1791169755199197**, created **11:09:15.199**, capture **11:09:27.227–11:09:47.257**, start **12028618µs**, duration20.029924s. Source `step2e-fast-20261005.log`, SHA-256 **`583bba79d41a80682afba627c4acbd7e2bdb60e915b410fbaddb48f2c54ea342`**. **224 poses/unique paints**, no mismatch/capacity, four ignored unmatched paints, **zero freshness resets**. All24 representatives reconstruct, exact metadata/confidence, mirror/cover residual1.2×10⁻¹³px, max894byte records.

The raw coordinates show both arms repeatedly crossing their shoulders. The user explicitly confirmed **“I moved both arms.”** Step2D's designated fast control used one moving arm; this run is therefore **ancillary bilateral evidence**, not the matched fast comparison. Preserve it; repeat one-arm fast with no parameter/diagnostic changes rather than discard or silently merge it. More complete excursions can reflect different movement amplitude/occlusion and must not automatically be credited to beta.

| Joint | Mean / median / p95 / max displacement (image px) |
| --- | --- |
| Left elbow | 11.98 / 12.74 / 21.11 / 42.27 |
| Right elbow | 12.59 / 13.44 / 21.47 / 41.98 |
| Left wrist | 21.26 / 22.73 / 36.35 / 40.94 |
| Right wrist | 22.14 / 22.93 / 37.51 / 63.09 |

Right elbow has8 refined/8 filtered raises; first response0–161.178ms, subsequent **58.489–273.249 / 66.596–297.830 / 74.400–268.681 / 81.908–301.457 / 98.411–241.502 / 68.830–304.140 / 78.712–264.100ms**. Right wrist8/8 raises: **54.258–233.732 / 107.135–253.210 / 0–167.113 / 0–175.836 / 0–148.801 / 0–167.583 / 0–205.587 / 0–164.626ms**. Same-direction matching is temporal, no resets, no interpolation. These bounds still overlap the control substantially and are not comparable calibrated-velocity trials. Left elbow8refined/7filtered raises (last short excursion censored), left wrist8/8; full descent brackets remain in JSON, with overlaps/zero lower bounds retained.

Midpoint input **22099612µs**, receipt/delivery/paint **22196803/22196988/22204669µs**: accepted/in-view right elbow refined174.643,440.669→filtered181.643,444.536 (8.00px); wrist142.438,489.685→159.425,497.024 (18.50px), high confidence and both right links drawn. Peak representative only .671s after tap is preparation, not requested faster movement. First representative already has off-image raw arm coordinates; later mirror/crop binding is numerically correct. Right upper/forearm draws224/221, left223/218. No empty/stale/no-person/whole-presence/lifecycle loss or freshness expiry in the capture.

Separate interior **11:09:30.199–11:09:45.199**, approx15s: camera30FPS, processed/delivered/drawable11.20FPS, preprocessing35.79ms, native51.47ms, worker87.95ms, callback-to-UI107.03ms, callback-to-first-CPU-paint118.52ms,282replacements, zero stale/empty/expiry. Trace/delivery/paint diagnostic CPU .040/.005/.116ms, filterCPU .108ms. These remain internal timings; no physical latency figure is invented.

## Earlier handoff checkpoint (before afternoon captures)

The user's bilateral-fast confirmation is recorded. Bottom-hold capture instruction is pending; the latest phone report still ends at `fast@12028618`. Do not infer a completed hold or stationary-shake answer from silence. Next: bottomHold, topHold, then repeat fast using only the same moving arm as Step2D (other arm down). Reuse the installed candidate, identical diagnostics/settings, and new bounded phase keys. No tuning or fresh build is needed. Host verification: preview-enabled UI **two passed**, both mobile/pose analyses clean; current source manifest still identifies exactly the beta argument. A post-fast battery snapshot reads **91%, 34.7°C**; it is context, not synchronized thermal telemetry or proof of a cause.

Provisional internal evidence is mixed: synthetic same-input motion displacement decreases, but physical slow median displacement is not lower, wrist crossing ranges overlap the control, and the first fast trial is unmatched bilateral movement. No experiment pass, failure, total-latency conclusion or decision to keep beta .6 has been made yet. If the completed matched evidence cannot demonstrate meaningful benefit, follow the user's rollback instruction rather than stack further tuning.

## Completed afternoon holds and one-arm fast repeat

User confirmed all three captures completed. They ran in fresh app process **26851**, route session **1791187592990624**, created **16:06:32.990** local on 2026-10-05. The same beta .6 APK remains installed: package path/update time unchanged, device SHA-256 still **dd75e4f406d48d7ada1714e059d0bfb1de3438f1145961e0dc2bf04b62e0b9b2**. The morning PID26849 is not incorrectly reused to retrieve afternoon evidence. Afternoon wall time differs by about five hours; unchanged light/framing/body speed are requested but cannot be certified from coordinate-only evidence.

All three captures share one fresh route, but have distinct phase keys. Source `step2e-holds-fast-repeat-20261005.log`, SHA-256 **`4eb147cc4f20fc93fba36b576ba0d7e2d4277a3af32b6affb8867082a639a132`**. The original logs/aggregates are preserved; no continuous landmark trajectory or camera frames are stored. Parser reports no malformed records. Each phase reconstructs24 fixed joint records/four input frames, matching metadata and decoded confidence, projection/cover residual ≤1.2×10⁻¹³px, transport ≤894bytes. Host telemetry extraction groups the whole periodic poll around its foundation-metrics line; bottom-poll lines crossed from16:06:52.999 to53.000. The earlier exact-second selector failed rather than silently dropping late stages; only the ignored host analysis helper was corrected, with no APK/diagnostic change.

| Phase | Capture wall interval | Input-clock start µs | Duration | Poses/unique paints | Ignored unmatched paints | Nonempty expiry resets |
| --- | --- | --- | --- | --- | --- | --- |
| bottomHold |16:06:49.677–16:07:09.734|16686800|20.056622s|224|1|3|
| topHold |16:07:19.714–16:07:39.740|46723572|20.026328s|224|0|0|
| fast repeat |16:08:01.250–16:08:21.262|88259602|20.012048s|221|2|3|

No timestamp mismatch/capacity limit, invalid/missing coordinate or delivered empty-pose outcome in these phases. The one-arm repeat has only model-right shoulder-level crossings; opposite-arm medians remain near1px, supporting the intended movement match. The bilateral morning run is excluded from the designated fast comparison.

### Displacement distributions, control → candidate

Cells are **mean / median / p95 / max image XY pixels**, not physical error or latency. Full-period aggregates retain preparation samples.

| Phase / joint | beta .3 | beta .6 |
| --- | --- | --- |
| fast / leftElbow | 2.38 / 1.10 / 9.07 / 25.96 | 2.59 / 0.84 / 12.72 / 46.96 |
| fast / rightElbow | 11.01 / 11.17 / 18.76 / 46.72 | 9.79 / 9.81 / 17.40 / 36.17 |
| fast / leftWrist | 2.48 / 1.28 / 10.50 / 25.10 | 2.85 / 1.09 / 11.30 / 51.49 |
| fast / rightWrist | 20.39 / 21.32 / 34.65 / 67.72 | 16.77 / 17.14 / 31.28 / 57.21 |
| bottom / leftElbow | 1.64 / 0.53 / 4.65 / 47.11 | 2.36 / 0.57 / 11.68 / 41.99 |
| bottom / rightElbow | 1.79 / 0.63 / 4.99 / 40.50 | 2.02 / 0.68 / 8.89 / 33.32 |
| bottom / leftWrist | 2.70 / 0.69 / 6.67 / 81.90 | 2.10 / 0.69 / 8.94 / 41.08 |
| bottom / rightWrist | 1.97 / 0.71 / 5.07 / 74.23 | 2.38 / 0.79 / 13.09 / 28.66 |
| top / leftElbow | 2.36 / 0.68 / 12.02 / 66.29 | 2.22 / 0.61 / 12.41 / 37.45 |
| top / rightElbow | 3.17 / 0.84 / 15.31 / 53.85 | 2.83 / 0.77 / 14.49 / 36.23 |
| top / leftWrist | 2.17 / 0.88 / 12.11 / 33.40 | 2.11 / 0.79 / 8.72 / 43.53 |
| top / rightWrist | 4.51 / 0.87 / 27.44 / 107.71 | 3.68 / 0.89 / 19.17 / 87.18 |

Fast moving elbow/wrist medians **11.17/21.32 → 9.81/17.14px**, approximately **12%/20% lower** observationally; means about11%/18% lower, p95 about7%/10% lower. Opposite-arm medians remain near1px. This is useful motion-response evidence and agrees directionally with same-input synthetic replay, but physical trajectories are not identical and it is not a calibrated causal speedup. Slow moving medians did not improve. The larger bottom-hold p95 is not evidence of temporal jitter by itself: retained repositioning occupies more than5% of a 20s run and can dominate upper percentiles.

### Fast-repeat crossing response

Same-direction event pairing follows temporal order with complete7/7 refined and filtered raises/lowers for both right elbow and wrist. No observed reset occurs **inside** any paired raise bracket. Two expiry recoveries precede the first controlled raise; the third occurs after its filtered rise and before its descent. Do not imply uninterrupted filtering across the whole phase. All events occur after the initial3s preparation allowance; the first controlled raise starts about6.3s after tap.

The following are exact **route input timestamps in seconds**, with delay bounds conservatively rounded outwards to hundredths. These are refined→filtered response, not physical P/C/S.

| Joint/event | Refined bracket | Filtered bracket | Added response range |
| --- | --- | --- | --- |
| rightElbow raise1 |94.680989–94.739114|94.844902–94.904005|0.10–0.23s|
| rightElbow raise2 |96.748902–96.842155|96.922545–97.011479|0.08–0.27s|
| rightElbow raise3 |98.709996–98.812070|98.905480–98.978461|0.09–0.27s|
| rightElbow raise4 |100.604822–100.703767|100.784582–100.842008|0.08–0.24s|
| rightElbow raise5 |102.706754–102.807254|102.905602–103.015369|0.09–0.31s|
| rightElbow raise6 |104.909119–104.975827|104.975827–105.085155|0.00–0.18s|
| rightElbow raise7 |106.904816–107.001448|107.068289–107.165891|0.06–0.27s|
| rightWrist raise1 |94.575424–94.680989|94.739114–94.844902|0.05–0.27s|
| rightWrist raise2 |96.676904–96.748902|96.842155–96.922545|0.09–0.25s|
| rightWrist raise3 |98.646597–98.709996|98.812070–98.905480|0.10–0.26s|
| rightWrist raise4 |100.537437–100.604822|100.703767–100.784582|0.09–0.25s|
| rightWrist raise5 |102.706754–102.807254|102.807254–102.905602|0.00–0.20s|
| rightWrist raise6 |104.809940–104.909119|104.909119–104.975827|0.00–0.17s|
| rightWrist raise7 |106.803380–106.904816|107.001448–107.068289|0.09–0.27s|

Elbow raises have exact bounds **105.788–223.016 /80.390–262.577 /93.410–268.465 /80.815–237.186 /98.348–308.615 /0–176.036 /66.841–261.075ms**. Wrist raises **58.125–269.478 /93.253–245.641 /102.074–258.883 /98.945–247.145 /0–198.848 /0–165.887 /96.632–264.909ms**. Their ranges overlap control substantially; no precise reduction in temporal delay is demonstrated by midpoint subtraction.

Control fast had **6 refined elbow raises, only2 filtered** (four censored), and **8 refined wrist raises,7 filtered** (one censored). Candidate has7/7 for each with no missing raise/descents. This improved observed excursion completeness supports the candidate, but different refined amplitudes and acceptance history remain confounds; missing control excursions are not assigned infinite delay or averaged. Candidate elbow descents2/3/4 share identical raw/filtered brackets, giving ambiguous signed ranges approximately ±.10/±.14/±.11s, not negative causal delay. Other elbow descents have zero lower bounds and upper .16–.18s. Wrist descents are mostly zero-minimum, with two strictly positive ranges **67.363–258.825 /28.151–232.848ms**. Full exact candidate and control crossings remain in `step2e-final-phase-comparison.json`.

### Holds and same-input representatives

Bottom midpoint input **26643429µs**, receipt/delivery/CPU-paint **26739566/26739683/26748842µs**: accepted in-view right elbow refined203.785,457.213→filtered204.027,456.678 (**.59px**), wrist183.634,507.089→184.109,506.005 (**1.18px**), with both right links drawn and high confidence. Final input36543289µs gives **.65/.46px**. Filter generations5→6 change due to expiry, so two points do not fit a settling curve. Peak representative17802951µs is1.116s after tap, still preparation; maxima are not interpreted as steady-state shake.

Top midpoint **56655030µs**, receipt/delivery/paint **56767365/56767532/56777411µs**: right elbow refined195.110,382.909→filtered194.900,382.412 (**.54px**), wrist152.873,351.993→153.077,351.187 (**.83px**), accepted/in-view, high confidence and arm draws issued. Final66519269µs gives **.20/.72px**, same filter generation7 with no expiry. Refined coordinates themselves drift by several pixels between held snapshots; filtered endpoint separation is not temporal noise RMS. Peak47466923µs is.743s after tap, preparation. One top raise yields elbow refined **51.756035–51.856095s**, filtered **51.963737–52.093880s**: response **.10–.34s** outward; wrist refined **51.688760–51.756035s**, filtered **51.756035–51.856095s**: **0–.17s**. Control top bounds were elbow .07–.24s/wrist .09–.24s; these overlap, and candidate elbow is not demonstrably faster. No lower crossing was recorded in either top-hold phase; final arm remains above shoulder and supplies no descent observation.

Fast midpoint **98278902µs**, receipt/delivery/paint **98384950/98385103/98405225µs**: accepted/in-view elbow218.352,449.293→222.674,453.273 (**5.88px**), wrist187.700,491.621→199.604,497.740 (**13.38px**), high confidence, both right links drawn. Peak88815107µs is.556s after tap, preparation. All full raw ROI/refined/filtered/painter/viewport/confidence/link samples remain bounded in the source summary; no coordinates from different spaces are subtracted.

### Joint confidence and canvas/crop observations

Each cell below is **control visibility/presence rejection → candidate visibility/presence rejection; control off-canvas/off-viewport → candidate off-canvas/off-viewport**. Rejection causes overlap; off-screen and rejection observations can overlap too. Counts cover the full20s period, have different frame denominators and include preparation; do not sum these as independent failures. Shoulder rows are included because confidence/crop can reject an upper-arm link even if elbow passes.

| Phase / joint | Gate counts and bounds observations |
| --- | --- |
| still / leftShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| still / rightShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| still / leftElbow | 0/0 → 0/2; 5/7 → 0/8 |
| still / rightElbow | 4/0 → 0/0; 0/0 → 0/0 |
| still / leftWrist | 0/4 → 4/5; 4/7 → 5/11 |
| still / rightWrist | 3/0 → 0/1; 0/0 → 0/5 |
| slow / leftShoulder | 0/0 → 0/0; 0/0 → 0/1 |
| slow / rightShoulder | 0/0 → 0/0; 0/4 → 0/0 |
| slow / leftElbow | 0/0 → 0/1; 0/2 → 1/5 |
| slow / rightElbow | 0/4 → 5/0; 6/6 → 0/0 |
| slow / leftWrist | 3/4 → 5/7; 6/6 → 6/7 |
| slow / rightWrist | 6/7 → 4/0; 6/8 → 0/0 |
| fast / leftShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| fast / rightShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| fast / leftElbow | 0/4 → 0/1; 0/5 → 0/11 |
| fast / rightElbow | 5/2 → 0/0; 7/9 → 0/4 |
| fast / leftWrist | 6/8 → 7/9; 7/8 → 13/15 |
| fast / rightWrist | 7/8 → 0/3; 12/12 → 6/6 |
| bottom / leftShoulder | 0/1 → 0/0; 5/6 → 0/0 |
| bottom / rightShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| bottom / leftElbow | 5/2 → 0/1; 4/6 → 4/11 |
| bottom / rightElbow | 0/2 → 1/1; 0/0 → 0/5 |
| bottom / leftWrist | 2/2 → 4/8; 6/7 → 9/11 |
| bottom / rightWrist | 3/5 → 3/6; 5/5 → 6/6 |
| top / leftShoulder | 0/0 → 0/0; 7/9 → 0/5 |
| top / rightShoulder | 0/0 → 0/0; 0/0 → 0/0 |
| top / leftElbow | 6/6 → 0/1; 9/11 → 3/8 |
| top / rightElbow | 0/0 → 1/0; 0/0 → 0/6 |
| top / leftWrist | 8/7 → 6/8; 8/12 → 6/8 |
| top / rightWrist | 1/5 → 2/4; 6/7 → 8/9 |

Confidence values/gates are unchanged by filtering. Fewer right-joint rejections in the candidate do not show beta improved model confidence. Left-wrist rejects increase in bottom/fast despite better right links, and candidate top/bottom right elbow has more viewport-edge observations during preparation. Off-viewport is distinct from off-image and from failed painter acceptance. Numerical mirror/cover binding closes; anatomical prediction relative to the displayed camera remains unmeasured.

### Actual limb draws and freshness

Cells show control **issued draws / phase poses → candidate issued draws / phase poses**. First rejected endpoint labels are preserved separately in JSON; joint rejection counts cannot simply be added to recover edge counts.

| Phase | Left upper arm | Left forearm | Right upper arm | Right forearm | Nonempty expiries .3→.6 |
| --- | --- | --- | --- | --- | --- |
| still | 224/224 → 226/228 | 220/224 → 223/228 | 220/224 → 228/228 | 220/224 → 227/228 | 1→1 |
| slow | 187/187 → 223/224 | 182/187 → 217/224 | 183/187 → 219/224 | 180/187 → 218/224 | 19→2 |
| fast | 221/225 → 220/221 | 217/225 → 211/221 | 219/225 → 221/221 | 215/225 → 218/221 | 0→3 |
| bottom | 189/194 → 223/224 | 189/194 → 216/224 | 192/194 → 223/224 | 189/194 → 218/224 | 7→3 |
| top | 226/233 → 223/224 | 225/233 → 216/224 | 233/233 → 223/224 | 228/233 → 220/224 | 2→0 |

Candidate bottom expiry ages **262.165–269.389ms**, restoration gaps **3.374–12.830ms**; top none; fast ages **253.504–260.157ms**, gaps **21.388–39.772ms**. These are application transitions, not physical display blank lengths. All designated phase outcomes are pose with no delivered empty/stale/no-person/low whole-pose-presence/lifecycle loss. Fast reliability is not uniformly better (3expiries vs0control), while other expiry counts are equal/lower. Do not pool unequal sessions into an asserted percentage reliability improvement.

### Internal telemetry comparison

Control→candidate periodic-window means below. Windows are separate roughly15s interior polls; the fast-repeat candidate window16:08:02.99–17.99 includes preparation, whereas the control starts roughly1.69s after tap. At each beta processed/delivered/drawable FPS are equal in these selected windows; raw camera stays about30FPS. None is sensor-exposure-to-display latency.

| Phase | Processed/delivered/drawable FPS | Preprocess ms | Native ms | Worker ms | Callback→UI ms | Callback→first CPU paint ms | Pending replacements | Stale/empty |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| still | 11.27→11.47 | 35.77→34.46 | 51.00→50.93 | 87.45→86.07 | 104.76→104.30 | 115.57→115.20 | 281→278 | 0/0→0/0 |
| slow | 9.47→11.20 | 47.26→36.52 | 56.52→50.61 | 104.63→87.84 | 125.49→105.59 | 136.99→115.56 | 310→283 | 0/0→0/0 |
| fast | 11.33→10.93 | 36.17→37.66 | 50.14→51.67 | 87.02→90.09 | 105.48→108.92 | 115.66→120.07 | 280→286 | 0/0→0/0 |
| bottom | 9.73→11.27 | 44.96→36.29 | 55.26→50.37 | 100.98→87.34 | 122.48→105.76 | 134.72→116.51 | 304→281 | 0/0→0/0 |
| top | 11.67→11.20 | 34.76→36.43 | 49.06→50.94 | 84.44→88.14 | 103.42→106.92 | 113.95→117.90 | 276→283 | 0/0→0/0 |

Fast-repeat native/worker/callback paint are slightly slower than control; beta is a signal-response change and does not optimize inference. Slow/bottom candidate computation is faster than their slower control sessions, but that is not causally attributed to beta. Complete individual detector, ROI decode, landmark/refinement, filtering and diagnostic stages remain in comparison JSON.

| Phase | Diagnostic trace / delivery / paint CPU ms, .3→.6 |
| --- | --- |
| still | 0.038 / 0.005 / 0.137 → 0.040 / 0.006 / 0.105 |
| slow | 0.049 / 0.006 / 0.093 → 0.041 / 0.005 / 0.067 |
| fast | 0.043 / 0.006 / 0.081 → 0.040 / 0.007 / 0.081 |
| bottom | 0.047 / 0.006 / 0.064 → 0.049 / 0.005 / 0.073 |
| top | 0.041 / 0.005 / 0.074 → 0.044 / 0.005 / 0.080 |

The user answered **“I couldn’t judge reliably”** when asked about increased stationary shaking. No continuous temporal jitter statistic exists in the unchanged bounded diagnostic. Thus unchanged/lower held median displacement does **not** certify stationary stability. No new landmark stream or diagnostic schema was introduced to fill that gap.

## Internal decision and physical recording handoff

**Internal result: promising but not accepted.** The usable one-arm trial shows lower spatial lag distributions and more complete filtered excursions, consistent with synthetic same-input response benefit. Conservative crossing-time bounds overlap substantially, the slow result is mixed, physical motion/framing differs, fast nonempty expiry count increases, and stationary jitter cannot yet be judged. This is neither proof that beta .6 has no benefit nor evidence that it materially worsens jitter. It does not satisfy the full pass gate.

Retain **beta .6 only as the installed diagnostic candidate for the requested matched video**, with the .3 control APK/source/evidence unchanged and immediately available for rollback. No additional variable is tuned; no production-quality acceptance or permanent adoption is claimed. If the external/stability check fails to demonstrate meaningful benefit, or shows materially worse shaking/tracking, restore beta .3 rather than stack further changes. If remaining uncertainty persists, do not call the experiment passed.

The afternoon route emitted `lifecycle_closed` at **16:08:28.903**, camera service disconnected at16:08:29, and a read-only summary confirmed **Active Camera Clients: []**. Camera/model teardown is covered by the unchanged controller ordering and previously passing lifecycle tests; native interpreter-memory reclamation was not separately measured. Cleanup evidence is retained in `step2e-camera-cleanup-20261005.txt`.

Matched external protocol is prepared in [Step2E recording instructions](2026-10-05-pose-beta-external-recording-protocol.md). It preserves the previous P/C/S definition (**moving elbow/upper arm crossing approximately shoulder level relative to torso**, not wrist or absolute screen-horizontal Y), actual presentation timestamps, separate P→C/C→S/P→S bounds and visibility censoring. Include stationary bottom/top segments so physical shaking can be judged. The new original video is still required; no physical total-latency conclusion has been made. Step2quality acceptance remains not passed; Step3 stays deferred.

Final collection verification: all five designated beta .6 phase records reconstruct without timestamp/transport error; corresponding image/painter/viewport/confidence checks pass. The180-file source manifest still proves only the beta argument differs, and both preserved APK hashes remain intact. Same-direction fast/top raise pairs have no observed freshness reset within their response brackets. Three bounded-parser tests rerun successfully and `git diff --check` is clean. No application code changed while collecting/analyzing the afternoon reports; prior full mobile/pose verification remains in the host-evidence section. No tuning beyond beta was introduced.
