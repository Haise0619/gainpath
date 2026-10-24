# Step 2M — isolated live OpenCL candidate

Status: controlled physical captures and normal pause/background/close checks collected. GPU computation improves, but reported held shaking prevents quality acceptance or production adoption. CPU remains the default. Step 3 remains deferred.

## Frozen control and experiment

Control: `apps/mobile/build/pose-quality/step2k-refined-skeleton-profile.apk`, SHA-256 `8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff`. The installed APK was pulled and independently hash-matched before replacement. The filtered production rollback remains `step2i-sampler-candidate-profile.apk` (`747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4`).

The experiment changes inference backend and introduces its necessary thread/transport adapter. Dart preprocessing, consumed tensor indices, heatmap refinement, auxiliary ROI tracking, detector period 15, One Euro beta 0.3/min cutoff 1/derivative cutoff 1, two residual CPU threads, camera resolution, projection/mirroring, rendering acceptance, 250 ms freshness, 100 ms watchdog and latest-frame scheduling stay frozen. The existing Step 2K refined diagnostic skeleton and filtered markers remain the display configuration for the paired experiment. This is not production adoption of an unfiltered skeleton.

`GAINPATH_POSE_GPU` and `GAINPATH_POSE_GPU_COMPARE` are false by default and gated off in Dart release mode. No camera SDK/model upgrade, workout activity, upload or scoring is introduced.

## Ownership and lifecycle

The background Dart worker still preprocesses and decodes. A MethodChannel passes float32 input to an Android-owned single-thread executor containing both interpreters/delegates. Construction, invocation and destruction occur on that same OS thread; every invocation returns its owner ID, checked by Dart. The [official standalone Android GPU contract](https://developers.google.com/edge/litert/android/gpu) requires this ownership. This avoids treating serialized Dart isolate messages as proof of OS-thread affinity.

The exact cached LiteRT 1.4.0 Java API is used; it exposes forced `OPENCL` and precision-loss-disabled options. OpenCL is required rather than silently falling back to CPU/OpenGL. Native logs must corroborate live delegation; a requested backend label alone is not physical verification. The interpreter keeps two CPU threads and disables XNNPACK to match the control C API for residual operations. All native model/library APK entries must match the control before installation.

Only one operation is accepted at a time. Close is the sole queued operation, runs after accepted work and attempts disposal of each interpreter then delegate. Close is idempotent, engine detach closes every session, and parent-side worker failure/initialization timeout also requests native cleanup. The parent allocates the session ID before spawning so it can close initialization still in progress. The existing controller drains frames and handles pause/background/logout; it is not retuned.

Merged-APK inspection corrects an overbroad statement in Step 2L: **GainPath's actual merged control APK already contains optional application-level OpenCL library declarations**, inherited from the dependency. The separate initial probe lacked that declaration and needed it. No extra GainPath profile manifest declaration is needed; its existing manifest is restored byte-for-byte. This does not contradict the separate probe's manifest experiment.

## Bounded same-input gate

GPU owns the live ROI and refined output. After five seconds of preview input to allow positioning, up to 12 landmark tensor pairs (24 frame attempts maximum) are compared against the unchanged CPU adapter. The same preprocessed tensor and same GPU-derived ROI are used by both backends. Detector comparisons occur only at the unchanged detector cadence; their actual count is reported rather than assumed to be three. CPU detector ROI and auxiliary ROI are compared independently against GPU-derived equivalents, without changing which ROI drives the live session.

Only scalar aggregates are retained: consumed tensor absolute maxima, finite failures, refined image pixel distance, world metre distance, confidence differences, renderer joint-acceptance flips, near-threshold flips, whole-pose flips, ROI availability/geometry/rotation differences, pair counts and full-body accepted-pair counts. No tensor/coordinate samples, camera images or video are written by this diagnostic. All five landmark output signatures, including unused segmentation, are validated; only outputs 0/1/3/4 are transferred/compared for current behavior. This gate does not accept segmentation equivalence.

Provisional limits registered before live collection: no nonfinite consumed values, no whole-pose/ROI availability/joint acceptance flips, max refined XY distance 1 upright image pixel, world distance 0.001 m, probability difference 0.001, ROI centre/side difference 1 pixel, angle difference 0.5 degrees. Threshold flips within 0.01 of 0.5 are separately labeled boundary cases and do not silently pass. An incomplete/no-person comparison cannot establish accepted-person agreement. Numerical agreement does not establish anatomical accuracy or low physical latency.

CPU shadow interpreters are closed after the bounds. Frames marked `sameInputComparisonActive` are **excluded from performance acceptance**; their worker time includes extra CPU inference and comparison. Start controlled performance phases only after inspecting the completed agreement and warming the remaining GPU path. The initial five-second wait and these bounds are diagnostics, not changes to camera/inference cadence or backpressure.

## Timing boundaries

`nativeMicros` comes from LiteRT's last native invocation duration, excluding MethodChannel transport. `gpuNativeCopyMicros` measures the remaining Android adapter time (buffer copying and Java tensor I/O); `gpuRoundTripMicros` includes Android queue/codec/transport and Dart output decoding. Their difference is labeled `gpuTransportAndQueueMicros`, not physical camera delay. Preprocessing and landmark decoding remain separately measured. Shadow CPU time is separately labeled.

Record processed/delivered/drawable FPS, callback-to-UI/first CPU paint, freshness/stale events, confidence and actual renderer outcomes using the existing diagnostics. Do not substitute GPU kernel times into delivered FPS or combine these timings with external C/R/S recordings to invent physical latency.

## Host verification and physical protocol

New Dart tests cover tensor inventories, byte lengths, owner mismatch, busy rejection, late-result close, malformed output/initialization cleanup, matched timestamp/coordinate-space agreement, threshold-boundary flips, bounded retention and nonfinite tensor handling. A host Java test exercises the actual executor class: owner consistency, no queued frames, in-flight close, idempotence, rejection after close and failed-init cleanup. These tests do not prove device delegate behavior.

Physical protocol on Xiaomi 23013RK75C: first fresh full-body still session for bounded agreement and native logs. If agreement is acceptable, collect separate still/slow/fast/top/bottom phases after shadow completion, then background/manual pause/resume/close and fresh reopen. Verify no remaining camera client/owner thread after End preview. Later compare close-screen refined response/held stability against preserved CPU control, with APK attribution. GPU inference improvement alone is not Step 2 quality acceptance.

Artifact SHA, source isolation and exact native/model hashes are recorded in `apps/mobile/build/pose-quality/step2m/provenance.json`. Physical results will be appended after collection; none are inferred from Step 2L synthetic timings.

## Prepared artifact and verification

Current profile artifact: `step2m-opencl-candidate-profile.apk`, 147313022 bytes, SHA-256 `89d9a15d3d6094be143c75ebeb179d797546a1bac6cbbb90a5b15403a098c977`. APK model assets and all packaged TensorFlow Lite native libraries match the preserved control byte-for-byte. Three existing source files differ (worker, Android activity registration and pinned direct dependencies); 178 baseline files, including profile/main manifests and all frozen processing/rendering files, remain byte-identical. Six bounded adapter/test files are added. The earlier `1679a1fe…` live artifact is preserved separately.

Final GPU-flag affected suite: 53 passed. Default mobile suite: 159 passed, 15 diagnostic-flag-dependent skips. Pose/GPU static analysis: no issues. Host executor lifecycle test passes. APK compilation succeeds. These are host checks, not live GPU acceptance.

## Initial physical session — provisional and incomplete

The first live artifact (`1679a1fe3b61914b5d3ac58888cb876d4f1c19356290c037e4a0f5b62ae2757e`) runs in GainPath PID 24059. Native logs explicitly load OpenCL and delegate all detector nodes (291/291) and landmark nodes (332/332), each as one partition, on kernel thread 9272. Both models coexist and run; no GPU-to-CPU/GL fallback is observed. Creation completes at 15:02:35.486; native setup spans approximately 2.4 seconds. The first version's returned owner number 5185 is Java thread identity, not kernel TID; logcat establishes the kernel TID. The logging repair uses `Process.myTid()` directly for subsequent checks.

The truncated agreement prefix reports 12 landmark pairs, no nonfinite values, no joint/whole-pose/ROI-availability flips, image-coordinate maximum distance about 0.0021 px, world distance about 0.0000059 m and probability maximum difference about 0.0000074. All eight full-body check joints are simultaneously renderer-accepted in zero pairs; this is a confidence observation and does not independently establish framing. The final ROI angle, completion gate and input interval were cut from the Android log line. This is **not a completed full-body numerical acceptance**, despite promising partial values. A regression test reproduces the missing packet API; small one-time base64 packets now preserve the full scalar report. No production parameter is changed by that repair.

Scalar telemetry is preserved in `step2m/initial-still-aggregates.json`; native logs in `initial-still-native.log`. The session extends beyond the user's short positioning check, includes substantial no-person/low-presence periods and has no matched controlled-phase boundary, so its whole-session means are not a still/motion acceptance cohort. At 15:05:32.627 the latest interval delivers about 18.99 drawable FPS with 29.99 camera FPS. Landmark native mean is about 11.61 ms (recent median 10.96 ms), worker recent median 45.05 ms, callback-to-first CPU-paint recent median 76.89 ms. These are promising computation observations; they are not external latency, a matched speedup ratio or tracking-reliability acceptance. CPU-shadow startup frames contaminate cumulative means and must remain excluded from controlled comparisons.

ADB Back is denied by Xiaomi's input-injection permission. The user taps End preview. Native close is logged at 15:07:39.798 on kernel thread 9272, matching creation. Camera service then reports `Active Camera Clients: []`. This verifies normal route cleanup, not an independent native heap-leak or cancellation-during-setup stress test. Motion, sustained full-body tracking, controlled FPS, held stability, pause/background and setup cancellation remain pending.

## Logging repair artifact

Current candidate SHA-256 `89d9a15d3d6094be143c75ebeb179d797546a1bac6cbbb90a5b15403a098c977`, 147313022 bytes. Previous live artifact remains preserved separately. This revision adds one-time scalar packets, compact periodic backend metadata, comparison input interval bounds, direct OS TID checks and shadow cleanup on a GPU frame error. Model assets/native libraries and the 178 baseline files still match the control. The log-packet regression passes; affected GPU-flag suite now passes 53 tests. Static analysis remains clean. The original closed owner thread 9272 is absent from `/proc/24059/task/9272` while PID 24059 still runs.

## Complete bounded live numerical report

Installed packet-repair APK is independently pulled/hash-matched to `89d9a15d3d6094be143c75ebeb179d797546a1bac6cbbb90a5b15403a098c977`. GainPath PID 9455, native owner/kernel TID 10190. Native logs again verify OpenCL with 291/291 and 332/332 nodes delegated, one partition per model. The complete scalar report reconstructs without invalid records.

Twelve matched landmark inputs are compared over input timestamps **8,098,593–9,165,865 µs** (1.067272 s) in this preview session, with one detector input pair at the unchanged cadence. CPU shadows close at the bound; the completion frame itself is still marked comparison-active and is excluded from performance. Maximum refined XY distance **0.0008765 image px**, world distance **0.000005442 m**, joint/whole-pose probability difference **0.000007068**; ROI centre/side maximum **0.0003003 px**, angle **0.00001270°**. Nonfinite consumed values, joint acceptance flips (including boundary cases), whole-pose flips and ROI-availability flips are all zero. This passes the preregistered numerical limits for these inputs.

Mixed raw tensor maxima remain in the packet report with their own units; do not interpret detector score-logit differences (up to 0.001160) as probability or pixel error. Landmark raw mixed-coordinate/logit maximum is 0.0006218, whole-pose probability output maximum 0.000001907, heatmap maximum 0.0003595, world tensor maximum 0.000005007. Unused segmentation is signature-validated but not numerically accepted.

All eight full-body check joints are simultaneously renderer-accepted in zero pairs on **both** backends, with zero joint-acceptance disagreement. That cannot prove full-body anatomy/framing or leg-link reliability, and is not used to claim Step 2 quality acceptance. Numerical equivalence of the observed person inputs supports moving to controlled GPU-only quality/performance captures while retaining the CPU rollback. The ambient session includes the user approaching/leaving the camera; its cumulative empty results are not a controlled tracking-loss rate.

Final host checks after the repair: **159 default mobile tests passed, 15 diagnostic-flag skips; 53 affected GPU-flag tests passed; pose/GPU analysis clean; Android profile APK build and signature verification passed**. No production tuning follows this numerical result.

## Controlled GPU-only captures

Two still captures and separate slow, fast and top-hold captures have complete bounded reports. Every capture lasted approximately 20 seconds, with no input/delivery timestamp mismatches or filter resets. Joint statistics retain only the first 300 painted frames; reaching that cap does **not** end the capture timer. Later joint observations are censored. Whole-pose outcome and blank diagnostics continue for the full capture. The user did not see a button countdown, despite verified capture start/end reports; the visible countdown remains an unresolved diagnostic-UI observation, not a missing capture.

The second preview owns native thread 10680 (creation 15:21:51.687). Its five-second comparison window encountered no person: 24 detector pairs, zero landmark pairs, shadows closed at the bound. This is an **incomplete person-agreement cohort**, irrespective of an otherwise true empty numerical-limit flag. The earlier completed twelve-person-input cohort supplies the observed-person gate. Slow/fast/hold captures occur after shadow closure; no CPU shadow computation is included in their performance windows.

Interior telemetry uses periodic endpoints between phase start +4 s and end −1 s, typically about ten seconds between the first/last endpoint. Stage means below are approximate differences of cumulative counts and rounded sums; FPS shows interval ranges. These are camera-callback/computation/CPU-paint measurements, **not** sensor-exposure-to-display latency. Camera received FPS is approximately 30 throughout.

| Capture | Drawable FPS | Preprocessing ms | Landmark native ms | Total native ms | Worker ms | Callback→UI ms | Callback→first CPU paint ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| Still, first | 20.0–21.7 | 26.29 | 11.43 | 11.99 | 45.85 | 66.51 | 79.77 |
| Still, requested repeat | 16.2–16.4 | 33.88 | 13.68 | 14.29 | 58.87 | 80.90 | 94.09 |
| Slow | 19.0–19.8 | 30.12 | 11.45 | 12.13 | 50.08 | 70.33 | 83.22 |
| Fast | 16.2–17.0 | 33.59 | 12.75 | 13.39 | 57.35 | 78.02 | 90.96 |
| Top hold | 16.0–17.0 | 34.61 | 13.15 | 13.72 | 59.12 | 80.04 | 93.19 |
| Bottom hold | 16.6–17.0 | 32.40 | 13.17 | 13.90 | 56.89 | 76.75 | 89.75 |

Native-copy adapter means are 0.83–1.21 ms, complete GPU round trips 19.30–24.63 ms and transport/queue remainder 6.47–9.25 ms across these windows. Preprocessing and transport now form appreciable remaining computation costs. Latest-frame replacement counts are 92/137/109/133/139 over the respective approximately ten-second windows, with 208/163/191/167/161 nonempty delivered and uniquely painted frames. Replacement is expected bounded backpressure, not a queued stale-frame stream. Interior empty results, detector-no-person and low-pose-presence results are zero. Each complete 20-second blank report records **zero logical/CPU-painted whole-overlay blank episodes**, no retained/dropped blank events and no open episode.

Previous CPU Step 2K measurements were approximately 50–52 ms native inference, 72 ms worker, 104 ms callback→CPU paint and 13.5 drawable FPS. The GPU observations support a substantial native computation improvement, and the user reports that yellow refined rings/green arm look more responsive. These different-session measurements are not a matched thermal/physical latency speedup ratio. The green primary skeleton is still the **refined diagnostic** skeleton; its improvement cannot establish that the production filtered-skeleton signal delay is solved.

Partial links remain explainable per-joint confidence rejections. In the first 300 retained frames, moving right upper-arm/forearm links were drawn 292/287 times in slow, 289/289 in fast, and 300/294 in top hold. Fast right elbow was rejected in 11 observations; right wrist in 9 (visibility rejection in 9, presence rejection in 8; these overlap). Coordinates are finite and the measured transform residual is zero; fast right wrist was outside canvas in 11 and viewport in 12 observations. This is not proof that every physically framed hand prediction is accurate. User confirmation that legs/feet are visible in the camera image does not independently accept leg-link anatomy.

Refined→filtered displacement remains present with the unchanged beta 0.3 filter: slow right elbow mean/p95 8.15/15.44 image px and wrist 12.68/23.49 px; fast elbow 9.63/16.39 px and wrist 17.35/30.30 px. Top-hold whole-phase wrist mean/p95 is 4.88/20.69 px, but that phase includes stepping into position and raise/lower transitions, so it is **not a stationary-jitter estimate**. No extra filter/threshold tuning follows these observations.

Bottom hold lasted 20.071 s: 327 pose and seven detector-no-person outcomes, 300 retained painted frames, zero timestamp mismatches/filter resets. Its interior window has 168 nonempty deliveries/unique paints, 132 replacements, zero empty outcomes and no counter increment for expired empty frames. There is one approximately **0.48 s CPU-painted blank** immediately at capture start, explicitly `detector_no_person`: input 911,530,859 µs, delivery 911,603,329 µs, confidence 0.04097, no valid refined frame/ROI; recovery input 911,962,566 µs, detector confidence 0.51378 and landmark pose presence 0.73775. This episode is prediction/detection loss, not renderer-all-joint rejection or watchdog expiry. Positioning at the button is possible but cannot be proven without external video. The bottom-hold blank transport is complete, with no event-cap overflow.

The user reports **higher responsiveness but obvious shaking of the overall skeleton and yellow/pink points**. This blocks a held-stability/Step 2 quality pass. It does not alone prove that GPU arithmetic introduced the shaking: the bounded matched-input numerical error is tiny, and both inference cadence and live tracked inputs differ over an extended run. Refined rings/green skeleton bypass temporal smoothing by design, while magenta points use the unchanged filter. No smoothing or threshold change is made to mask this observation. Bottom-hold elbow/wrist displacement statistics contain the initial reacquisition/positioning interval and therefore cannot be substituted for stationary jitter.

Bounded evidence: `step2m/gpu-top-lag-analysis.json`, `gpu-bottom-lag-analysis.json`, `gpu-bottom-blank-analysis.json`, `gpu-phase-interiors-scalars.json`, `phase-windows.json` and native logs. The GPU adapter's eight focused tests were rerun after physical collection and all passed. `final-source-check.json` independently rechecks both preserved APK hashes and all nine changed/added source hashes against provenance; all match. No application source change follows the physical captures.

## Physical lifecycle results

The user manually pauses at 15:39:40.842, backgrounds at 15:39:44.043, then confirms the reopened screen remains paused. Camera service inspection during that paused interval shows no active camera clients. Native models remain allocated while the session is paused, as intended; pause stops/drains camera work and resets ROI/filter state rather than disposing the reusable session.

After user Resume, the same preview opens at 15:41:31.602 and emits camera results. A second Home transition logs background at 15:41:43.974; reopening logs opening at 15:41:52.875 and results at 15:41:53.236. End preview logs closed at 15:42:01.209 and native close at 15:42:01.265 on **owner 10680**, the same thread as construction/invocation. Camera clients are empty afterward; `/proc/9455/task/10680` and the previously closed owner 10190 both report no such file while the app process remains alive. This verifies normal ownership/disposal, manual-pause persistence and automatic background/resume behavior. It does not establish heap-leak freedom, logout-specific GPU behavior or setup-cancellation stress acceptance. Scalar lifecycle evidence is `step2m/gpu-final-lifecycle.json`.

## Decision and next comparison

Retain OpenCL as an experimental computation candidate, with CPU default/rollback preserved. Native inference benefit is verified; faster internal delivery and user-perceived refined response are encouraging. **Held stability, anatomical quality and physical latency are not accepted; Step 3 remains deferred.** No other parameter tuning is justified in this pass.

Next use the preserved Step 2K refined CPU control and this GPU artifact in a matched close-screen comparison, with the same refined green skeleton/yellow rings and filtered magenta markers, same arm, full-body framing and lighting. Include at least ten seconds each of bottom/top stationary hold away from button interaction, slow/fast raises/lowers through shoulder level and settling. Attribute each original recording to its installed APK hash. Analyze displayed-camera→refined and displayed-camera→filtered/skeleton boundaries separately using decoded presentation timestamps; screen-only video supplies no physical-person timing. Compare held marker excursions and partial/whole-link losses before adoption. No tuning accompanies that comparison. A sustained GPU thermal/performance check and setup-cancellation/device-resource stress check remain separate unverified acceptance items.

## Paired recording review, 2026-10-06

Completed screen-only CPU/GPU analysis is in [the paired comparison report](2026-10-06-pose-step2m-screen-comparison.md). Rechecked originals: CPU 3,348 frames / 59.8825 PTS-derived FPS; GPU 3,441 / 59.8305. All event timings use decoded presentation timestamps. Green is refined diagnostic, magenta filtered; no physical-person latency is inferred.

Recording-session interior telemetry shows 9.55 versus 17.00 drawable FPS and 135.84 versus 90.61 ms callback→first CPU paint, CPU versus GPU. CPU has fifteen nonempty freshness expiries in the approximately forty-second cohort, GPU zero. Video review confirms thirteen interior short CPU blank/near-blank groups and no confirmed GPU whole-overlay blank. Logical and photographed counts have different boundaries and are not mapped one-for-one.

Conditional upper-arm crossing intervals substantially overlap; an external response speedup is inconclusive. Moving filtered points still trail refined points. Held screen-space variation does not establish a consistent material GPU-specific stability regression, but is not pure jitter or anatomical ground truth. Thus the earlier user shaking concern remains relevant without proving a GPU arithmetic cause. Retain GPU experimentally and CPU rollback/default; Step 2 quality and Step 3 remain pending. Recommend checking the normal filtered primary skeleton on this unchanged GPU backend next, without tuning other parameters. That display-source change is not implemented in this review.
