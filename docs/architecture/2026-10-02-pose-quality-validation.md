# Step 2B: Xiaomi physical quality validation

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Scope: latency/FPS, anatomical alignment, explicit loss/reacquisition and lifecycle/resource checks. The functional Step 2 camera/inference/rendering path is proven. Step 2B acceptance is pending controlled measurements. No Step 3, RepFSM, scoring, audio or upload is connected.

2026-10-03 follow-up: the [Step 2C physical comparison](2026-10-03-pose-step2c-physical-comparison.md) measures faster preprocessing/computation and higher delivered FPS on the Xiaomi. Visible gesture-response improvement remains inconclusive, dynamic arm alignment and pose loss remain unresolved, and Step 2 quality acceptance is not passed. Baseline measurements below remain historical evidence.

## Frozen configuration and provenance

- Xiaomi 23013RK75C, Android 13 / API 33, ADB xiaomi-device-serial-redacted; front camera YUV420 720×480, rotation 270°, upright image/preview 480×720.
- Model `mediapipe-full-e9a5c5cb-det-9ba9dd3d`; exact hashes and float32 tensors remain in `apps/mobile/assets/models/tensor_manifest.json`. Runtime tensor validation must be true on every tested process.
- Two CPU interpreter threads; detector every 15 ROI frames or after ROI loss; existing 0.5 acceptance checks; One Euro parameters unchanged. One active + one replaceable pending input, 250 ms result/freshness policy and 100 ms watchdog remain unchanged.
- `GAINPATH_POSE_QUALITY_DEBUG=true` enables observation only. Models, tensor layouts, preprocessing math, thresholds, ROI policy and filtering parameters are not tuned in this task.
- Install the preserved `apps/mobile/build/pose-quality/step2b-instrumented-debug.apk`, force-stop before launching, then manually open the local preview. No hot reload. A new `POSE_QUALITY_EVENT` from `uninitialized` to `session_created`, a new process and zero-origin counters establish a fresh session.

An initial quality process (PID 5174, session 1790946074149418) was replaced by a concurrent IDE run without the quality define (PID 5176). Package lastUpdateTime and the running Flutter command confirmed replacement. The later full-body image is useful visual evidence, but its metrics are excluded from the controlled quality baseline. The IDE run was stopped at the user's confirmation; the diagnostic APK is kept under a separate filename so ordinary builds cannot overwrite it.

## What each metric measures

| Metric | Boundary / denominator |
| --- | --- |
| Camera received FPS | Application image callbacks forwarded to the controller per active-preview second; not sensor exposure FPS |
| Processed FPS | Completed scheduler processing per active-preview second |
| Delivered overlay FPS | Fresh pose results delivered to UI, including empty results; `drawableOverlay` separately counts results with accepted landmarks |
| Detector / landmark inference | Native `Interpreter.invoke()` only, each averaged over its own invocation count |
| Total native inference | Combined native calls per processed frame, including frames that skip one model |
| Preprocessing | Detector and landmark resize/rotate/YUV/RGB/normalization separately, plus their per-frame sum |
| Camera copy | Callback entry to existing post-copy PoseInput timestamp; the scheduling timestamp is unchanged |
| Detector decode / ROI | Detector score-output read, SSD decode, weighted NMS and detector ROI construction |
| Landmark post-processing | Output reads, heatmap refinement, image/world inverse projection and auxiliary ROI update; excludes separately measured diagnostic trace construction |
| Filtering | Existing One Euro frame filter call, without parameter changes |
| Queue age / host processing | Existing input timestamp to dispatch; await of worker request/response including transfer overhead |
| UI delivery age | Existing post-copy input timestamp to filtered UI delivery; `callbackToUi` includes camera copy |
| Pose age when painted | Existing input timestamp to first CPU painter invocation for that pose; `callbackToPaint` includes camera copy |
| Flutter build / raster | FrameTiming build/raster durations for this preview screen; not display-present timestamps |

The camera plugin does not expose sensor exposure timestamps. CPU paint and Flutter raster timing do not expose the Android display-present fence. Consequently callback-to-paint is an operational latency measurement, **not a measured physical camera-to-display latency**. True physical latency requires an external recording of the moving person/reference and the phone screen together. Screen recording of the phone alone supports overlay-versus-preview alignment inspection but does not supply the missing physical source time.

Timing means are cumulative, with bounded last-300-sample p50/p95 summaries. Five-second FPS uses count deltas and active-time deltas. Do not mix paused/background/draining intervals with steady tracking. The local summarizer subtracts phase-start counters and weighted timing totals; it rejects windows with no new processed quality frames. Each decoder-to-paint joint record uses an exact timestamp match from a bounded 64-frame trace cache. Missing matches produce no paired coordinates.

## Explicit loss attribution

- `detector_no_person`: finite detector outputs below the existing threshold.
- `detector_nonfinite_scores` / `detector_invalid_boxes`: malformed numeric predictions, distinct from no person.
- `invalid_detector_roi`: accepted detector candidate with unusable alignment ROI.
- `low_landmark_pose_presence`: landmark pose probability below the existing threshold; ROI resets.
- `invalid_auxiliary_roi`: current anatomical landmarks may remain valid, but auxiliary tracking failed; the next frame re-detects. This is not automatically a zero-pose result.
- `nonfinite_landmarks`: landmark pose accepted, but no finite anatomical/world tuples survived decoding.
- `landmark_visibility_rejection` / `landmark_joint_presence_rejection`: landmarks exist but no joints pass the painter's visibility/presence requirements.
- `stale_before_processing`, `stale_result`, `replaced_pending`, `generation_invalidated_pending/result`: separate scheduler counters; these do not automatically erase a still-fresh displayed pose.
- `freshness_expiry`: watchdog cleared an older frame. `expiredOverlay` counts nonempty frames; `expiredEmptyFrame` is distinct. Event records retain age and latest scheduler discard context.
- Manual pause, background, geometry invalidation, logout/close, permission/init failure, pipeline error and preview aspect mismatch have distinct state records.

`adapter_empty_unspecified` is only a fallback for non-BlazePose test/adapters that supply no worker reason. It must not be used to classify real BlazePose losses without investigating missing instrumentation. Every health record preserves whether the detector ran, fresh detector confidence or carried confidence with its original timestamp, landmark pose probability, ROI source and next-ROI state.

## Preliminary evidence, not the controlled full-body baseline

Initial PID 5174 mixed setup/person-absent run, approximately 50 seconds: 500 completed worker frames, 497 delivered results, 174 worker poses, 317 detector no-person outputs, 9 low landmark-presence outputs, 955 pending replacements, 3 stale results, 43 visible-overlay expiries and 7 empty-frame expiries. Final sampled rates: 29.99 camera callbacks/s, 9.20 processed/delivered results/s and 6.40 drawable results/s. No malformed/truncated JSON records or paired-joint timestamp mismatches were found in the saved capture.

| Stage | Mean ms | Samples |
| --- | ---: | ---: |
| Detector preprocessing / invoke / decode-ROI | 40.85 / 36.63 / 0.34 | 336 each |
| Landmark preprocessing / invoke / post-processing | 63.00 / 51.17 / 0.90 | 183 each |
| Per-frame preprocessing / native / worker pipeline | 50.51 / 43.34 / 94.89 | 500 each |
| Camera copy / filtering | 0.95 / 0.09 | 1457 / 497 |
| Queue age / host worker await | 18.96 / 97.00 | 501 / 500 |
| UI input age / callback-to-UI | 115.00 / 115.94 | 497 each |
| Painted input age / callback-to-paint | 135.04 / 135.99 | 496 each |
| Flutter build / raster | 4.19 / 3.02 | 1660 each |

These mixed-path means do not describe a full-body steady run: no-person frames skip landmark inference, while periodic detector + landmark frames cost more. They identify CPU preprocessing and native inference as substantial computation costs; filtering, ROI/post-processing and drawing are much smaller in this capture. Expiry events cleared valid poses with landmark probability around 0.99 at ages 255–275 ms, independently of low-presence/no-person results. This is evidence for investigating freshness versus delivery cadence, not permission to silently change the policy.

Battery was 31.0°C and Android thermal status 0 at the sampled check. This does not prove no earlier/later throttling. Static full-body front screenshot broadly aligns shoulders, hips, knees and ankles; no global mirrored/rotated skeleton was apparent. Exact moving alignment and side-on assessment still require controlled evidence.

## Physical protocol and remaining acceptance

### Controlled debug front-camera result

PID 5177 / fresh session 1790946599567496 retained its instrumented build throughout this phase. Approximately 95 seconds of confirmed full-body front-camera sampling yielded 557 worker poses, 507 fresh delivered poses, 50 stale results, 2285 pending replacements and 411 visible-overlay expiries. There were **zero** detector no-person, low landmark-presence or delivered empty-pose frames in this window. Mean sampled rates were 29.92 received, 5.86 processed and 5.34 delivered/drawable FPS. The last detector confidence was 0.9849 and landmark pose presence rounded to 1.0. No malformed records or matched-joint timestamp errors occurred.

| Stage | Window mean ms |
| --- | ---: |
| Detector preprocessing / native invoke / decode-ROI (38 invocations) | 45.70 / 59.40 / 0.45 |
| Landmark preprocessing / native invoke / post-processing (557 invocations) | 81.04 / 76.90 / 1.37 |
| Per-frame preprocessing / combined native / worker pipeline | 84.16 / 80.96 / 166.92 |
| Queue age / host processing | 19.77 / 170.04 |
| Camera copy / One Euro filtering | 1.14 / 0.16 |
| UI input age / callback-to-UI | 180.95 / 182.30 |
| Painted input age / callback-to-paint | 199.60 / 200.96 |
| Flutter build / raster | 3.28 / 3.47 |

The latest rolling p95 callback-to-paint was 253.75 ms. CPU preprocessing and native inference dominate this debug run. Delivered valid poses already approximately 181 ms old commonly reach the fixed 250 ms budget before the next result; the watchdog then clears them. Loss events during this phase are freshness expiry, not model no-person or low pose confidence. The UI's existing generic move-into-view text can therefore appear while a fully visible person is being predicted correctly.

The front movement recording is retained locally for analysis, separately from the benchmark. Its sampled frames frequently show no overlay despite a person in view; the accompanying interval still has no no-person/low-presence outputs but many stale results and freshness expiries. It cannot establish good moving alignment. Battery reached 39.0°C with thermal status 0 at a later check; the long-running debug workload and changing native timings limit causal attribution to debug overhead alone.

A fresh **profile build comparison** is prepared with exactly the same models, resolution, thread count, thresholds, filtering and scheduling configuration. This changes compilation/execution mode for measurement only. No preprocessing algorithm, model variant or acceptance/freshness policy is optimized on the basis of the debug run alone.

### Controlled profile front-camera result

PID 5179 / fresh session 1790947204385817, exactly 60 seconds of wall-clock capture after the user confirmed the full-body pose: 477 worker poses, 474 delivered/drawable/painted results, 1324 pending replacements, 3 stale results and 99 visible-overlay expiries. No empty-pose/model-loss category occurred. Mean sampled rates: 30.02 received, 7.95 processed and 7.90 delivered/drawable FPS. Latest carried detector confidence 0.9685 with its source timestamp; landmark pose presence rounded to 1.0. All paired-joint timestamps matched; no malformed records.

| Stage | Profile window mean ms |
| --- | ---: |
| Detector preprocessing / invoke / decode-ROI (32 invocations) | 29.50 / 48.15 / 0.23 |
| Landmark preprocessing / invoke / post-processing (477 invocations) | 52.30 / 65.32 / 0.60 |
| Per-frame preprocessing / combined native / worker pipeline | 54.28 / 68.55 / 123.68 |
| Queue age / host processing | 17.29 / 125.41 |
| Camera copy / filtering | 0.85 / 0.14 |
| UI input age / callback-to-UI | 141.95 / 142.68 |
| Painted input age / callback-to-paint | 153.06 / 153.80 |
| Flutter build / raster | 0.84 / 3.61 |

Rolling p95 callback-to-paint at the final snapshot was 203.13 ms. Profile compilation improves this workload but does not remove the mismatch between delivery cadence/age and the fixed expiry budget. Native inference and CPU preprocessing remain the dominant compute stages. A small filtering **computation** time does not imply zero smoothing **signal delay**; compare raw and filtered coordinates during gestures before considering any parameter changes. These sequential debug/profile runs are not thermally matched laboratory benchmarks.

### Profile front motion

The bounded 22-second screen recording retained the same PID/session and frozen configuration. Five-second metric snapshots covering that recording contained 198 worker/delivered/drawable/painted poses, 552 pending replacements, 48 visible-overlay expiries and zero stale results, empty poses or model-loss outputs. Snapshot deltas span approximately 25 seconds because the reporting timer is discrete; these counts are not divided by the video duration to invent FPS. Sampled delivered FPS was 7.40–8.60; mean worker computation 124.50 ms, callback-to-UI 144.26 ms and callback-to-CPU-paint 155.55 ms.

Sampled video frames show the arms following earlier arm positions: actual arms above the head while the overlay is nearer horizontal, then actual arms lowered while the overlay remains higher. Shoulders, hips, knees and ankles remain broadly anatomically aligned during the observed mostly upright movement. The requested one-arm/knee sequence was not reproduced: both arms moved and the video does not establish a distinct knee-bend sequence. Therefore neither an asymmetric mirror check nor moving-knee acceptance is claimed from this recording.

Five timestamp-matched samples per representative shoulder/hip/knee/ankle have raw-to-filtered displacement means 0.31–0.65 image pixels and maxima 0.73–2.08 pixels on the 480×720 image. These samples support correct coordinate units and modest smoothing displacement for those joints; wrists/elbows are not in this representative trace, so their smoothing/prediction contribution remains unresolved. The measured camera-callback delay is already substantial independently of filtering. ROI rotation, image inverse projection, a single front-camera mirror and the common cover crop have no apparent global rotation/translation defect in these frames; this is visual evidence, not a calibrated ground-truth accuracy measurement.

### Profile side-on alignment

The same profile PID 5179 opened a fresh preview session 1790947977193141 before this phase. Its explicit session-created event, new counters and camera reconnect establish provenance; the model/configuration did not change. A 30-second side-on recording and approximately 30 seconds of metric snapshots contained 270 worker/delivered/drawable/painted poses, 630 pending replacements, 19 visible-overlay expiries and no empty/model-loss results or stale results. Received FPS was approximately 30; mean sampled processed/delivered FPS 9.00. Detector confidence was 0.9740 and landmark pose presence rounded to 1.0 at the final snapshot.

| Stage | Side-on window mean ms |
| --- | ---: |
| Detector preprocessing / invoke / decode-ROI (18 calls) | 28.86 / 48.27 / 0.15 |
| Landmark preprocessing / invoke / post-processing (270 calls) | 48.99 / 54.65 / 0.55 |
| Per-frame preprocessing / combined native / worker pipeline | 50.91 / 57.87 / 109.58 |
| Queue age / camera copy / filtering | 17.37 / 0.84 / 0.12 |
| UI input age / callback-to-UI | 128.40 / 129.10 |
| Painted input age / callback-to-paint | 139.98 / 140.68 |

Standing and a visible knee bend broadly align the near-side shoulder, hip, knee and ankle. Six matched representative samples show both shoulders/hips and the near-side knee/ankle accepted and inside the painter canvas throughout. The far-side right knee passes visibility in only 1/6 samples; right ankle in 3/6. These missing connections are explicit occluded-joint visibility rejection, while the overall pose continues with 33 landmarks. No whole-pose visibility rejection occurs in this window.

The painter is 480×720 before the common camera/overlay cover transform; front mirroring maps filtered x to `(1-x)*480`, y to `y*720`. Logged rounded coordinates reproduce this transform within 0.042 pixels. The viewport uses scale 1.0833, horizontal offset −54.2857, vertical offset 0 for 411.4286×780; camera and child paint share that same crop. Representative joints remain within the canvas and the observed body region. Raw-to-filtered movement displacement reaches about 16 image pixels at a moving shoulder, so smoothing contributes position lag during the bend. Raw model coordinates precede heatmap refinement; directly projecting those raw coordinates differs from refined image landmarks by several pixels and is **not** evidence of an inverse-projection defect. This trace does not record refined ROI coordinates separately, so exact refined-ROI numerical closure relies on the geometry/decoder unit tests and the visual check rather than a fabricated phone residual.

### Explicit absence and reacquisition

The person stepped out and returned in session 1790947977193141. Absence began just before the recording baseline, with an explicit `pose → detector_no_person` event; baseline health showed detector confidence 0.0830, pose presence 0 and ROI unavailable. The 25-second capture's five-second snapshots contain 44 detector-no-person empty results followed by 197 real poses, 509 pending replacements, 12 nonempty-overlay expiries and no stale results or low-landmark-presence outputs. This is distinct from the still-visible person's freshness losses in the static/moving phases.

The first returning pose uses input timestamp 173261726 µs and UI transition 173451844 µs (190.12 ms input-to-UI), pose probability 0.9738, 33 decoded landmarks and 20 accepted joints. Subsequent frames recover more joints and stable pose presence. Video starts with an empty/partially entering view and shows the skeleton by the next three-second sample; it does not precisely timestamp when the person's body became detectable. Therefore physical reentry-to-reacquisition delay is bounded visually, not claimed as 190 ms. Absence was approximately 15.5 seconds between logged loss/recovery transitions rather than the requested five seconds; coordination/tool-start delay limits this timing protocol. The loss cause and automatic reacquisition are nevertheless directly observed.

### Lifecycle/resource evidence

Manual Pause at 21:37:11 in PID 5179/session 1790947977193141 followed by Home at 21:37:15 and return retained the paused screen and empty overlay. Android `dumpsys media.camera` showed `Active Camera Clients: []`; the last disconnect belongs to this app at 21:37:11. Consecutive five-second counter snapshots remain identical while paused. One pending and one in-flight result were explicitly generation-invalidated during suspension, rather than redelivered after pause.

Paused PSS 334059 KB / RSS 456128 KB / native heap PSS 101448 KB, compared with the earlier active baseline PSS 385780 KB / RSS 512088 KB / native heap approximately 126012 KB. This is consistent with releasing camera resources; a single cycle is not a leak endurance test, and the interpreter intentionally remains reusable while paused. Incidental movement to reach the controls produced separate low-landmark-presence (0.0950) and detector-no-person events before lifecycle pause; these are outside the controlled full-body benchmark and demonstrate that the health log distinguishes model confidence loss from lifecycle invalidation.

After explicit Resume, ADB brought Home to the foreground for approximately 3.7 seconds and then reopened the existing activity. Background camera clients were empty; return reopened front camera 1 in the same PID. Events distinguish `lifecycle_background → lifecycle_opening → detector_no_person → pose`; the returned pose uses a new post-reopen input timestamp, not the pre-background frame. The person was seated/partially visible for this resource check, so confidence loss here is not classified as failed full-body tracking.

The earlier End/reopen cycle is also captured in this same profile process: session 1790947204385817 logs `lifecycle_closed` at 21:29:02, and Android records camera disconnect in that second. Reopening at 21:32:57 creates session 1790947977193141 from `uninitialized`, with fresh counters and input timestamps. Source closes the worker/interpreters after the scheduler drains; camera disconnect and subsequent clean reinitialization are directly observed. This does not prove a long-duration absence of native leaks. Active-camera logout/account-scope invalidation is covered by controller tests, but was not physically exercised through an accessible logout control in this preview.

Final End preview at 21:47:35 logs `lifecycle_closed`. A subsequent Android camera snapshot has no active client; native heap PSS is 80820 KB, total PSS 298519 KB and RSS 420708 KB. The logger was then stopped; the profile APK remains installed and the app is left outside the preview. An earlier “ended” acknowledgement arrived while the actual screen still showed the live preview; it was not counted as disposal evidence. The later explicit close and hardware snapshot establish the end check.

The later sampled battery temperature was 38.6°C, Android thermal status 0. Thermal snapshots and sequential runs are retained as context, not proof of constant CPU frequency. Screen recording may add load during motion/side-on/loss phases; the 60-second profile static timing baseline was captured without a concurrent video encode.

The original second-camera recording was supplied and analyzed on 2026-10-03; see [external video analysis](2026-10-03-pose-external-video-analysis.md). It provides approximately 60-FPS footage of the phone display, with repeated preview-to-skeleton arm-response delay around 300 ms using conservative manual brackets. The physical person is outside the recording's field of view, so physical camera-to-preview and movement-to-skeleton latency remain pending. Do not substitute callback-to-paint or preview-to-overlay figures for either.

The separately authorized [Step 2C preprocessing change and matched physical protocol](2026-10-03-pose-preprocessing-optimization.md) preserve the models, smoothing, thresholds, freshness and scheduler. Host checks do not replace this phone baseline or establish quality acceptance. The installed pre-optimization profile build is retained until the new same-shot physical-person/display recording is captured.

The subsequent [mirror video physical baseline](2026-10-03-pose-physical-latency-baseline.md) is now preserved and analyzed separately on its own PTS timeline. Four repeated arm events have independent physical, camera-image and skeleton brackets; mirror/shoulder ambiguity prevents a tight positive P→C lower bound, while physical-to-skeleton delay is clear. A whole-overlay blank at frame 355 is directly visible. These observations do not use or extend callback-to-paint telemetry and do not establish optimized-build improvement.

## Evidence-led decision, before optimization

The controlled evidence identifies two different sources of missing pixels: nonempty pose expiry while the fully visible person remains confidently predicted, and rejection of occluded individual joints in side-on views. Actual exit from view produces detector-no-person results and automatically reacquires. These must retain separate attribution.

In the full-body profile baseline, preprocessing consumes approximately 44% of worker computation and native inference approximately 55%; filter computation, detector decoding, landmark post-processing and Flutter drawing are small. The first optimization candidate is therefore a deterministic preprocessing benchmark and equivalent faster sampling/coordinate computation, followed by a repeat of this protocol. Per-pixel transform currently recalculates sine/cosine and repeatedly samples/converts four pixels; profiling those costs is a concrete investigation, not a proven speedup. Preserve normalization, border behavior, orientation, ROI geometry and decoded tensors with meaningful numerical tests. Do not change model variants, interpreter threads, thresholds, ROI cadence, smoothing or freshness concurrently.

The fixed 250 ms age budget independently explains visible flicker. Any subsequent freshness decision must consider measured input age plus the next-result interval and preserve explicit stale/lifecycle protection. Raising a threshold or hiding loss messages does not address compute latency. Arm smoothing/prediction lag still needs wrist/elbow evidence or an external synchronized recording before tuning One Euro parameters.

At this point stable continuous tracking **does not pass**: 99 nonempty expiries occurred in the controlled 60-second front profile baseline. Qualitative static/side-on anatomical alignment and automatic reacquisition have evidence; quantitative accuracy, physical source-to-display latency and endurance/resource acceptance remain limited as described above. Step 3 remains deferred.

1. Cold app/session, confirm quality define, runtime signatures, session-created event and stable process. Stop IDE Run during capture.
2. Front portrait, full body in good light: hold still for 60 seconds. Mark phase-start/end captures; inspect shoulders, hips, knees and ankles with confidence/clipping and matched decoder/filter/paint coordinates.
3. Move arms/legs and torso slowly, then faster; inspect alignment relative to the current camera preview. Do not attribute prediction/filter lag to projection without comparing the matched coordinates and cover/mirror transform.
4. Side-on intended squat setup: stand still, then bend/straighten slowly without implementing counting/scoring. Record occluded versus visible joints, ROI behavior and explicit loss events.
5. Step out and return, partially occlude, then Home/return, manual pause/background/return, end/reopen and logout. Confirm camera/worker release and no old pose resurrection or upload.
6. External recording for physical source-to-display latency; record frame rate and uncertainty. Preserve callback-to-paint separately.

Acceptance requires stable full-body tracking, reasonable anatomical overlay alignment, explainable loss/reacquisition, measured delivered FPS and physical latency, and no lifecycle/resource regression. A passing build or static screenshot alone does not meet this gate. Subsequent optimization decisions must follow controlled evidence; no frozen parameter is changed here.

Local validation: 115 mobile tests with preview/quality defines, 14 pure Dart pose tests, clean analyses, Android debug and profile builds, and read-only review with the frame-correlation/rejected-joint findings corrected. Focused `git diff --check` is clean. Phone images, detailed logs and summaries remain under the ignored build directory; the app does not persist camera images.
