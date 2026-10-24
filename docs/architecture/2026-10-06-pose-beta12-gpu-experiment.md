# Step 2P: isolated beta 1.2 filtered GPU candidate

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Current status

The isolated beta 1.2 experiment is **not adopted**. All five candidate phases, the paired original close-screen videos and normal candidate cleanup are analyzed. C→S response ranges substantially overlap, while held stability remains limited by actual motion/prediction variation and mask censoring. The user's fast-motion observation is corrected to uncertain, possibly about the same. Beta 0.3 is restored on the Xiaomi with its installed hash independently verified and camera clients empty. The candidate APK/evidence remains preserved. See the [completed external comparison](2026-10-06-pose-beta12-external-comparison.md). Step 2 quality acceptance still does not pass; Step 3 remains deferred.

This experiment follows the completed [offline Step 2O screening](2026-10-06-pose-filter-responsiveness-screening.md): beta 1.2 reduced synthetic motion displacement more than beta 0.6 while transmitting much less held noise than raising minCutoff. Synthetic results justify a trial, not production adoption, and larger confident prediction excursions remain a risk.

## Sole numerical change and guard

Candidate preview beta: **0.3 â†’ 1.2**. Keep minCutoff 1, derivative cutoff 1, minimum visibility/presence .5 and filter reset gap 500 ms. The shared `PoseFrameFilter` default remains .3. Models/assets/tensor contracts, detector/landmark thresholds, detector/ROI cadence, GPU backend, residual CPU threads, resolution, projection/mirroring/cover crop, 250 ms freshness, 100 ms watchdog, latest-frame backpressure, preprocessing, renderer acceptance and normal filtered green source remain unchanged.

Only `PosePreviewController` changes among the 215 original source/test/config/asset files. It selects beta 1.2 when `GAINPATH_POSE_BETA12_EXPERIMENT=true`, quality diagnostics are enabled, and `!kReleaseMode`. Other builds retain beta .3. The release exclusion is a compile-time guard; no release artifact is built or physically tested in this step.

The controller also exposes bounded `filterConfiguration` telemetry with the actual beta, minCutoff, derivative cutoff, minimumVisibility, resetAfterMicros and experiment tag. Existing foundation aggregate logging includes it every five seconds in diagnostic mode. No frame/landmark stream is added. Nineteen collected candidate foundation records verify beta 1.2 and `step2p_beta12`, together with the frozen filter settings and filtered green source. Installed hash attribution is kept separate from this runtime check.

The existing implementation applies beta to image and world streams through the same filter. This experiment targets image-overlay response; world kinematics, exercise acceptance and anatomical scoring are not validated.

## Preserved artifacts and hashes

Candidate: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2p-beta12-filtered-opencl-profile.apk`, **147,313,022 bytes**.

SHA-256: **`9b18190cc3789d05a2568fe34276d6cc1e0f7c33656c3884aa2ed43710058c99`**.

Control: `step2n-filtered-opencl-profile.apk`, SHA-256 **`6792b7c8776aa222e93985a32454d9f770b0823939824f90d93c9e8ccc014da9`**. Device-side `base.apk` independently matched the control during collection and before replacement. After candidate installation its hash independently matches **`9b18190cc3789d05a2568fe34276d6cc1e0f7c33656c3884aa2ed43710058c99`**. CPU rollback `step2k-refined-skeleton-profile.apk` remains hash-preserved; it is not the filtered GPU motion-comparison control.

The candidate uses the same eight Step 2N profile defines, plus `GAINPATH_POSE_BETA12_EXPERIMENT=true`: mock backend, local pose preview, quality/joint-lag/blank diagnostics, `GAINPATH_POSE_REFINED_SKELETON=false`, GPU and bounded startup GPU/CPU agreement enabled. The compiled primary skeleton remains F; yellow rings remain R and magenta dots remain F. Do not compare this candidate's green F against Step 2M's refined green as a paired filter experiment.

## Host verification

- The new actual-controller arm-step test first fails against unchanged control at filtered Y **0.445013378**, requiring candidate Y between .1 and .33. After the isolated selector it passes, retaining smoothing, confidence, dimensions and capture timestamp. The synthetic target is not a physical-latency criterion.
- Exact candidate flags across pose/model/GPU/lag/blank/controller/painter/UI boundaries: **52 passed**, **10 intentionally skipped refined-display-only tests**.
- New tests without the experiment flag and without any diagnostic flags: **2 passed**. With quality diagnostics and no experiment flag: **2 passed**. With the experiment flag but quality diagnostics disabled: **2 passed**. These cases retain the control arm-step response and verify the default remains beta .3.
- Analysis of the changed controller and new test: **no issues**.
- The controller's two added blocks can be removed in memory to recover the original control text exactly. All 214 other original files remain hash-identical. The saved original controller bytes match its pre-build hash. New test/tool/report files are separate from runtime numerical changes.
- APK entry sets are identical. Only three architecture-specific `libapp.so` AOT entries differ. Packaged models/native-runtime hashes, Android manifest and all DEX entries match the control exactly.
- APK signature verifies with v2 and the existing Android Debug signer, certificate SHA-256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`.
- Profile build completes successfully. No runtime GPU agreement, performance, jitter or lifecycle result is newly claimed for the candidate.

Evidence root: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2p/`. It contains the immutable pre-build snapshot, original controller `.dart.txt`, exact build script, red/green/candidate/control test logs, analysis/build/signature logs, APK/source comparison provenance and read-only installed-control verification. No raw camera frames, app-recorded video or continuous device landmark stream is saved or uploaded.

## Resume physical comparison

1. Keep IDE Run stopped. Before replacing the installed control, warm at least 15 seconds so startup CPU shadows close, then capture still and fast one-arm motion separately. Keep the same framing/light/arm; preserve full-phase counters separately from warmed interiors. Both control captures are collected below. The control route used an existing session clock, so do not describe it as a newly constructed route solely from the user's capture confirmation.
2. If practical, save an original close-screen 60 FPS recording of control still/slow/fast/top/bottom, with displayed camera, yellow R rings and green F visible. The earlier Step 2N recording-path question is unresolved; no video is assumed present or absent. User-provided recordings are separate from bounded app diagnostics.
3. After control collection and normal End preview, install the preserved candidate with `adb install -r`; verify device-side installed SHA and start a completely fresh app/preview. Installation/hash/fresh launch are now complete. Keep the same phone/framing/light and warm-up. Confirm runtime model contract, required OpenCL, `primarySkeletonSource: filtered`, beta 1.2 and closed startup shadows before interpreting performance.
4. Capture candidate still, slow, fast, topHold and bottomHold separately using the unchanged bounded 20-second controls. Preserve cap/censor information, joint confidence/link rejection, off-viewport predictions, reason-coded blanks/expiry, filter generations, FPS and callback/UI/CPU-paint telemetry.
5. Compare matched close-screen Câ†’R and Câ†’F events on actual decoded PTS, with uncertainty and censored crossings. Râ†’F displacement/crossing diagnostics and callback-to-paint remain distinct boundaries. Screen-only video cannot establish physical-person latency. Inspect held green jitter/settling and accepted prediction excursions, not just lower Râˆ’F displacement.
6. End/pause/background checks must confirm no candidate resource regression. Adopt only if motion response improves meaningfully without materially worse held stability or tracking reliability. Otherwise reinstall the beta .3 control and disable the experiment. Do not stack another tuning variable or proceed to Step 3.

For installation **after control capture**:

```powershell
$adb = 'C:/Users/Ngzhe/AppData/Local/Android/sdk/platform-tools/adb.exe'
$serial = 'xiaomi-device-serial-redacted'
$root = 'C:/Users/Ngzhe/StudioProjects/gainpath'
& $adb -s $serial install -r "$root/apps/mobile/build/pose-quality/step2p-beta12-filtered-opencl-profile.apk"
& $adb -s $serial shell am force-stop com.zyang.gainpath
& $adb -s $serial shell am start -n com.zyang.gainpath/.MainActivity
```

Rollback uses the preserved Step 2N filtered control APK in the same commands. The experiment has not passed; Step 2 quality acceptance, upstream displayed-cameraâ†’refined response and overall physical latency remain unresolved.

## Collected control still

Control remains independently hash-verified on the Xiaomi. PID 10108, quality session `1791296942790188`, capture `still@1201318487`; phone-local start 22:49:04.108 on 2026-10-06. The report lasts 20.015 s, with 426 nonempty pose outcomes, zero timestamp mismatches and no filter resets. The first 300 painted observations are retained; later joint observations are censored by the unchanged cap. The complete whole-overlay report covers the twenty-second capture, records zero blank episodes and has no transport/capacity censoring. These scopes remain separate.

The warmed count cohort within capture +4 through +19 s spans 9.998 s: 213 processed/nonempty/drawable results (21.30 FPS), 214 unique painted observations (21.40 FPS; one endpoint imbalance), and 86 pending replacements. No empty, detector-no-person, low-landmark-presence or generation-invalidated increments occur in that cohort. Sparse absent counters are not treated as new positive expiry/stale events. Approximate timing means: preprocessing 24.42 ms, total native 12.20 ms, worker 44.52 ms, filter execution .14 ms, callbackâ†’UI 64.38 ms and callbackâ†’first CPU paint 76.56 ms. These are computation/callback/CPU-paint boundaries, not external physical latency.

Retained right elbow/wrist acceptance rejects 3/4 of 300 observations; left elbow/wrist rejects 0/16. Right upper/forearm draw commands issue 297/296 times; left 300/284. Phase-wide Râ†’F mean/p95 displacement is 3.91/23.45 px at right elbow and 5.16/22.15 px at right wrist. Preparation/body motion and prediction excursions are included; these are not stationary jitter measurements. All 24 bounded representatives have finite coordinates; 22 accepted representatives have measured zero numerical projection residual, while two rejected left-wrist representatives have null residual observations. The first retained representative input precedes the capture button by approximately 57 ms and is not a controlled held sample. This is not anatomical acceptance.

Runtime foundation confirms the same model version, verified tensor contract, required OpenCL, front YUV720Ã—480 and normal filtered primary source. Latest foundation after the capture has zero landmarks, while the capture itself is nonempty; do not interpret a later out-of-view state as a still-phase failure. The session-clock start is earlier than the capture, and no new route construction is claimed. Candidate thermal/warm-up conditions and physical movements will need to be considered separately.

Evidence: `control-still-lag-analysis.json`, `control-still-blank-analysis.json`, `control-still-interior.json`, `control-still-attribution.json`, the bounded collection files and hashed `control-still-summary.json` under the Step 2P evidence root. The original still cohort remains authoritative; the later control-fast collection lacks its old timing endpoints and must not overwrite that cohort with missing data.

## Collected control motion, cleanup and candidate installation

Control `fast@1532042495` lasts 20.022 s with 384 nonempty outcomes, no timestamp mismatches and no filter resets. The first 300 painted observations are retained; later joint observations are censored. The complete twenty-second whole-overlay report has zero blank episodes, complete transport and no capacity censoring.

The 10.005 s warmed count cohort delivers/processes/draws 193 results (19.29 FPS) and observes 192 unique paints (19.19 FPS; one endpoint imbalance), with 108 pending replacements and no empty/no-person/low-pose-presence/generation-invalidated increments. Approximate means: preprocessing 29.22 ms, total native 12.47 ms, worker 49.74 ms, filter execution .15 ms, callbackâ†’UI 69.70 ms and callbackâ†’first CPU paint 82.09 ms. This differs observationally from the still cohort; beta has not optimized computation, and no controlled thermal comparison is inferred.

Right elbow/wrist Râ†’F mean/p95 displacement is 8.67/16.33 and 14.80/29.57 image px. Right upper-arm draws issue 300/300 times; right forearm 292/300, with eight right-wrist rejections. The other arm's links issue all 300 draws. All 24 representative coordinates are finite; 23 have measured zero projection residual and one rejected representative has no measured residual. These samples do not prove anatomical correctness or physical response timing. Crossing matching remains for the paired analysis.

After user-confirmed End preview, native session `pose-1791296943273361` closes on owner thread 11956. That thread is absent while GainPath PID 10108 remains alive; camera service has no active camera clients. This verifies normal control disposal, not candidate lifecycle acceptance or heap-leak freedom. Installed control and preserved candidate APK hashes are rechecked before replacement.

ADB `install -r` reports success. Independent device-side `base.apk` hashing matches the preserved beta 1.2 candidate. The app is force-stopped and launched through its existing MainActivity; no hot reload or IDE Run is used. The user is instructed to open a fresh preview, warm at least fifteen seconds, then capture candidate still before motion. No candidate performance/stability result is yet available.

Evidence: `control-fast-summary.json`, its bounded collection/analysis files, `control-fast-cleanup.json`, `install.log`, `installed-verification.json` and `launch.log` under the Step 2P evidence root. The preserved beta .3 control remains the rollback artifact.

## Collected candidate still and runtime verification

Fresh GainPath PID 10109, quality session `1791298796575095`, native owner 14179. Required OpenCL delegates 291/291 detector and 332/332 landmark nodes. Nineteen foundation observations verify beta 1.2, minCutoff 1, derivative cutoff 1, minimumVisibility .5, resetAfterMicros 500000, existing model version/runtime tensor contract and normal filtered primary source. Frame format and projection metadata remain unchanged.

The bounded startup comparison stops at the existing 24-attempt limit, with 24 detector tensor pairs but **zero landmark-frame pairs**. It reports no nonfinite/acceptance/whole-pose/ROI flips and CPU shadows closed. Its last compared input is 9.701 s, well before this capture begins at 49.669 s. The emitted snapshot's `comparisonActive: true` describes that last compared input, not an active shadow during the later still cohort. This run does not supply a completed twelve-landmark-pair agreement test or full-body acceptance; earlier backend validation and unchanged packaged models/runtime remain separate evidence. No comparison policy is changed.

Candidate `still@49668948` begins at phone-local 23:00:46.243 on 2026-10-06 and lasts 20.038 s, with 388 nonempty pose outcomes, zero timestamp mismatches and no filter resets. The first 300 painted observations are retained; later joint observations are censored. The complete whole-overlay report records zero blank episodes, complete transport and no capacity censoring.

The warmed count window spans 9.999 s and records 188 processed/nonempty/drawable/unique-painted results (18.80 FPS), 111 pending replacements and no empty/no-person/low-pose-presence increments. Approximate means: preprocessing 29.37 ms, total native 12.80 ms, worker 50.69 ms, filter execution .15 ms, callbackâ†’UI 70.28 ms and callbackâ†’first CPU paint 82.77 ms. Control still was 21.30 FPS, 44.52 ms worker and 76.56 ms callbackâ†’CPU-paint. These are observational cohorts with different prediction/ROI/warm-up/thermal conditions; the filter parameter is not an inference/preprocessing optimization, and this difference does not establish a beta-caused computation regression or physical latency effect.

Retained right elbow/wrist rejects 6/8 of 300 observations; left elbow/wrist 2/2. Right upper/forearm draw commands issue 294/292 times; left 298/297. Phase-wide right elbow/wrist Râ†’F mean/p95 is 2.99/11.68 and 2.64/11.15 image px. Smaller Râˆ’F displacement is not a measurement of stationary shaking, and different raw trajectories prevent treating these still aggregates as a matched responsiveness improvement. All 24 representative coordinates are finite; 21 have measured zero projection residual and three rejected representatives have no residual observation. Partial confidence rejection is distinct from whole-overlay stability.

The user reports stationary green shaking **about the same** as the beta .3 control. This is a qualitative still observation, not quantified jitter or acceptance of all held periods. No original candidate video is supplied yet. Latest post-capture foundation can show zero landmarks when the user leaves view; all capture outcomes above are nonempty. Evidence: bounded `candidate-still-*` files and hashed `candidate-still-summary.json`.

## Collected candidate fast: provisional response evidence

Same candidate quality session and native owner. `fast@222889885` begins at phone-local 23:03:39.464 and lasts 20.032 s, with 381 nonempty outcomes, zero timestamp mismatches and no filter resets. The first 300 painted observations are retained; later joint observations are censored. The complete blank report records zero whole-overlay episodes, complete transport and no capacity censoring.

The 10.004 s warmed count cohort records 193 processed/nonempty/drawable/unique-painted results (19.29 FPS), 106 pending replacements and no empty/no-person/low-pose-presence increments. Approximate means: preprocessing 28.54 ms, total native 12.58 ms, worker 49.23 ms, filter execution .14 ms, callbackâ†’UI 70.70 ms and callbackâ†’first CPU paint 83.82 ms. Control fast was 19.29 FPS, 49.74 ms worker and 82.09 ms callbackâ†’CPU-paint. No meaningful computation speedup is claimed; beta targets signal response.

Right elbow/wrist Râ†’F mean/p95 displacement is 9.05/16.15 and 14.97/25.61 image px, versus control 8.67/16.33 and 14.80/29.57 px. Means are not lower; the wrist tail is lower. Candidate right elbow/wrist rejects 9/9 of 300 observations versus control 0/8; candidate upper/forearm draw commands issue 291/291 versus control 300/292. Those confidence observations come from different model inputs and unchanged confidence gates; do not attribute changed rejection directly to beta. All 24 representative coordinates are finite; 21 have measured zero residual and three rejected points have no measured residual. Left-arm crossings before capture +3 seconds are preparation and excluded from controlled crossing interpretation.

Ordered within-phase right-arm Râ†’F pairs after preparation produce the following conservative input-clock intervals. Values below are rounded outward to whole milliseconds; zero/negative lower bounds preserve overlapping crossing uncertainty and do not prove instantaneous response or anticipation.

| Build / joint / direction | Provisional response intervals |
|---|---|
| Control wrist raise | 104â€“198, 108â€“208, 58â€“174, 99â€“193 ms |
| Candidate wrist raise | 0â€“96, 30â€“162, 36â€“165, 41â€“173, 0â€“134 ms |
| Control elbow raise | 37â€“197, 67â€“150, 131â€“281 ms; fourth raw raise unmatched/censored |
| Candidate elbow raise | 68â€“206, 70â€“165, 135â€“255, 98â€“232, 86â€“211 ms |
| Control wrist lower | 38â€“177, 95â€“174, 68â€“157 ms |
| Candidate wrist lower | 24â€“136, 0â€“142, 69â€“164, 0â€“107 ms |

The candidate wrist brackets are often shorter, but substantially overlap control intervals. Elbow raises remain mixed. The recorded crossings use accepted adjacent joint/shoulder samples and break crossing continuity on rejected points; sparse exported representatives cannot reconstruct all confidence gaps *between* an R bracket and its paired F bracket. Keep matches provisional, do not average them into a physical response estimate, and retain unmatched events as censored.

Candidate refined wrist raise-to-raise separations span approximately 2.39â€“3.06 s versus control 3.30â€“3.57 s. These are event-separation brackets, not calibrated joint velocities, but establish that the movement patterns are not matched. Candidate also has shorter above-shoulder excursions. Such differences confound the aggregate displacement and crossing comparisons; the internal evidence does not yet demonstrate a clear elbow response benefit or a physical Câ†’F improvement. The later fast-motion opinion is explicitly corrected to uncertain, possibly about the same; it does not establish improvement.

Earlier Step 2N slow/hold reports remain historical controls with different sessions; only the new still/fast control pair is collected in this sitting so far. Evidence: `candidate-fast-summary.json`, its bounded reports and `fast-provisional-crossing-comparison.json`. No numerical setting is changed or candidate adopted from this partial result.

## Collected candidate slow

Same candidate session. `slow@522709050` lasts twenty seconds, with 300 retained painted observations, zero timestamp mismatches and no reported filter resets. The joint cap censors later observations. Whole-overlay transport is complete and uncensored, with zero blank episodes. Current foundation continues to report beta 1.2 and filtered green.

The 10.001 s warmed cohort records 176 processed/nonempty/drawable/unique-painted results (17.60 FPS), 124 pending replacements and no empty/no-person/low-pose-presence increments. Approximate means: preprocessing 32.29 ms, total native 12.45 ms, worker 54.53 ms, filter execution .17 ms, callbackâ†’UI 75.56 ms and callbackâ†’first CPU paint 88.33 ms. Current variation is predominantly outside the filter CPU stage; no particular thermal/ROI/background cause is established or tuned.

Right elbow/wrist mean/p95 Râ†’F displacement is 6.04/12.17 and 9.73/17.92 image px. Right elbow rejects zero observations and right wrist five; whole-pose stability does not exclude these partial interruptions. No new beta .3 slow phase was captured in this sitting, so comparison with earlier Step 2N slow is historical, not an isolated same-input estimate. Top hold is requested next. Evidence is bounded `candidate-slow-*` reports and hashed summary; acceptance remains pending.

## Collected candidate top hold

Same session; `topHold@699005106` lasts 20.041 s with 333 nonempty outcomes, zero timestamp mismatches and no filter resets. The first 300 painted observations are retained; later joint observations are censored. Whole-overlay transport is complete/uncensored and records zero blank episodes.

The 10.001 s warmed cohort records 170 processed/nonempty/drawable/unique-painted results (17.00 FPS), 130 pending replacements and no empty/no-person/low-pose-presence increments. Approximate means: preprocessing 33.15 ms, total native 12.77 ms, worker 56.33 ms, filter execution .19 ms, callbackâ†’UI 79.17 ms and callbackâ†’first CPU paint 92.99 ms. Native inference stays close to prior phases while preprocessing/host timing varies; no causal throttling or beta effect is established.

Right elbow/wrist phase-wide Râ†’F mean/p95 is 3.15/12.21 and 3.76/16.75 image px, including preparation and raise/lower. Right elbow passes all 300 observations; right wrist rejects nine, so upper/forearm draw counts are 300/291. Left elbow/wrist rejects 8/8 and links draw 292/292. All 24 representatives are finite; 21 have measured zero projection residual. At capture +9.010 s, accepted right elbow/wrist Râ†’F displacement is .23/.84 px; at +17.787 s it is .66/1.24 px. These sparse observations show close R/F agreement at those inputs, not continuous settling duration, measured jitter or anatomical correctness. Peak representative is capture +.864 s (preparation), and first input precedes the capture by approximately 82 ms.

The user supplies completion without a top-shaking/link observation. A read-only post-top thermal/battery snapshot is retained separately; it has no synchronized control baseline and cannot establish the cause of FPS variation. Bottom hold and normal End preview are requested next; fast-lag opinion is requested separately. Evidence is bounded `candidate-top-*` files and summary. No tuning changes occur.


## Collected candidate bottom hold and cleanup

`bottomHold@829603431` lasts 20.042 s, with 328 nonempty outcomes, zero timestamp mismatches and no global filter resets. First 300 painted joint observations are retained and later observations censored. Whole-overlay transport is complete and uncensored, with zero blank episodes.

The 10.007 s warmed cohort records 166 processed/nonempty/drawable results (16.59 FPS), 135 pending replacements. Approximate means: preprocessing 33.65 ms, native 13.76 ms, worker 57.89 ms, filtering .16 ms, callback→UI 77.74 ms and callback→first CPU paint 92.05 ms. These are internal boundaries, not physical display latency.

Right elbow/wrist phase-wide R→F mean/p95 is 2.36/11.52 and 2.67/16.76 image px. Right elbow/wrist rejects 9/12 observations; left rejects 10/15. Upper/forearm draws are 291/288 on the right and 290/285 on the left. All 24 representative coordinates are finite; 20 accepted samples have zero measured projection residual and four rejected samples have no residual measurement. Preparation and prediction excursions prevent interpreting phase aggregates as stationary jitter.

After user-confirmed End preview, native owner 14179 is absent, the native session has closed, camera service has no active clients, and GainPath PID 10109 remains alive on Workout. Device-side candidate SHA-256 still matches. All 215 original files match the verified candidate source snapshot. This verifies normal route disposal; it does not newly establish pause/background/logout or heap-leak acceptance.

All five candidate blank captures report zero whole-overlay episodes, complete transport, no capacity censoring, zero pose timestamp mismatches and no global filter resets. Partial confidence/link rejection persists. No beta change is adopted: motion benefit and held stability remain unresolved pending the supplied external videos.


## Final comparison and disposition

The [external comparison](2026-10-06-pose-beta12-external-comparison.md) records actual PTS, file hashes, conditional/censored crossings, screen-marker stability limits and separate internal cohorts. There is no demonstrated meaningful candidate motion benefit. Beta 1.2 is not adopted; beta .3 control installation and camera closure are verified in `rollback-verification.json`. All evidence is retained. No new tuning variable is implemented. Earlier chronological “pending” paragraphs above describe collection-time state; this final disposition supersedes them.
