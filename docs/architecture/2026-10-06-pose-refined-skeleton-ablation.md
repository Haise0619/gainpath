# Step 2K — refined skeleton / filtered joint diagnostic

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Purpose and status

Implement the isolated display experiment specified in [Step 2J](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-held-bias-and-temporal-response.md), approved by the user's next-step instruction. This is a diagnostic artifact, not a new production smoothing policy or a quality acceptance.

The primary green skeleton draws the refined, inverse-ROI-projected coordinates. Yellow rings mark refined shoulders/elbows/wrists. Magenta dots mark the corresponding **filtered** shoulders/elbows/wrists. The existing beta 0.3 filter continues running and supplies the original controller state and timestamp ownership. The screen is labeled `Refined skeleton / filtered dots`.

This lets one recording compare the displayed camera arm against the legible refined upper-arm segment, while still observing the added filter displacement. A visible improvement in this display does not prove total physical latency is solved or justify releasing an unsmoothed skeleton.

Host implementation and checks are complete. The separate profile artifact is built and installed on the Xiaomi; its on-device APK hash matches the preserved local candidate. All five bounded phase reports are collected and analyzed below. Camera cleanup and final installed-artifact hash are verified. The subsequently supplied original recording is now reviewed in the [Step 2K screen report](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-step2k-screen-review.md): refined drawing itself visibly trails some camera-arm transitions, with additional filtered trailing. Anatomical-elbow crossings remain censored and sustained top-hold jitter is unmeasured. Step 2 quality has not passed; Step 3 remains deferred.

## Isolation and ownership

Only four existing production source files change: the diagnostic painter, joint-lag observer, development-preview caption and route's aggregate source label. A manifest check compares 181 existing Step 2I source/assets; the other 177 entries, including detector/decode/preprocessing, models/contracts, One Euro, scheduler, camera and controller, remain byte-identical. Test fixtures are updated to supply the same adapter ownership trace used by real inference, and a new diagnostic pixel-test file is added.

The mode requires `GAINPATH_POSE_REFINED_SKELETON=true` and the existing joint-lag diagnostic flag. The gate is disabled in release builds. Default builds keep the filtered primary skeleton. There is no runtime tuning control.

The selected refined frame must match the filtered owner on input timestamp, detector ID, model version, dimensions, mirroring, pose presence, joint keys and unchanged per-joint confidence/presence. All refined coordinates/confidences must be finite. Missing or mismatched ownership produces the explicit diagnostic reason `diagnostic_refined_unavailable`; it never silently substitutes a filtered skeleton under the refined label.

The diagnostic keeps at most one immutable refined coordinate frame for display, in addition to the existing bounded report join. Starting Capture 20s clears its report join but does not erase the current display owner or count the previous delivery as a new sample. Filter reset/generation clear, pause, background, logout, geometry invalidation and close still invalidate the existing controller frame and diagnostic owner. The source cannot resurrect a cleared controller frame. The existing 250 ms watchdog policy and 100 ms checking interval are unchanged; no extra freshness timer or queued camera frame is introduced.

The painter snapshots the refined owner when created and includes owner changes in `shouldRepaint`. Both skeleton links and markers use the exact existing mirror/cover transform. Green links retain visibility/presence acceptance 0.5. Rejected-joint diagnostic rings/dots follow the existing diagnostic policy, so a visible marker alone does not imply link acceptance.

## Diagnostic data semantics

- `primarySkeletonSource=refined_diagnostic` identifies the artifact in the screen label, scalar foundation/paint metrics and bounded representative records.
- Refined/filtered coordinates and R→S displacements retain their original meaning and same-input timestamps.
- In this mode, bounded `previewPixels`, `viewportPixels`, projection residual and inside-canvas/viewport statistics describe the **filtered diagnostic marker coordinates**, tagged `previewCoordinateSource=filtered_markers`. They must not be mistaken for the green refined-link position. Default records are tagged `filtered_skeleton`.
- Link draw/rejection counts describe the primary skeleton's actual issued links; matching confidence and joint keys preserve acceptance. Viewport-intersecting primitive counts and whole-overlay reason reports observe the primary refined drawing. Filtered marker off-viewport statistics are a separate observation.
- `refinedSkeletonSelectionMicros` measures the bounded source-validation CPU cost. Existing joint-lag paint timing remains available. A small CPU cost does not imply a small filter signal delay.

Existing retention limits, 20-second phases, fixed representative logging and transport chunk limits stay intact. No raw camera frames, newly captured video or continuous landmark streams are saved/uploaded by the app. The user may separately supply an original external recording for screen-timeline analysis.

## Physical protocol

Use a completely fresh preview session on Xiaomi `23013RK75C`; keep Flutter/Android Studio Run stopped. Verify the new caption and `primarySkeletonSource` scalar before interpreting a capture. Keep the same front-camera full-body framing and lighting, with the chosen arm's elbow exposed enough to see its anatomical location.

Capture phases separately, retaining the same one arm: still, slow raise/lower, faster raise/lower, top hold, bottom hold. Allow about 3 seconds after tapping to return to position. Motion should clearly pass above and below shoulder level, with brief holds; avoid merely grazing the plane. Capture 20s must visibly count down. End preview after the final phase to verify camera cleanup.

Prefer an original 60 FPS-or-higher close-screen recording that includes the camera image, full green refined skeleton, yellow rings, magenta filtered dots, phase/countdown and F badge. **Only C→R and R→S screen boundaries are observable in this setup**. Do not infer physical→preview, physical→skeleton or total camera-to-display latency. Use decoded PTS and conservative shoulder-crossing brackets, censor missing/ambiguous events and keep CPU telemetry separate.

Questions for the evidence review:

1. Does the camera upper-arm/elbow move ahead of the refined skeleton on raises and lowers?
2. Do magenta filtered joints trail the refined skeleton materially on the same displayed update?
3. Is refined held-pose jitter noticeably greater than the filtered dots, and do camera/R placement discrepancies remain after settling?
4. Are partial link losses explained by joint confidence? Are whole blanks freshness, prediction, lifecycle or diagnostic ownership failures?
5. Does the added diagnostic rendering/selection cost materially change computation/delivery behavior?

No next tuning variable is selected until these results are reviewed. A promptly following but shaking refined skeleton favors a later isolated smoothing tradeoff experiment. Material camera→R lag favors investigation of input age/prediction/ROI. Neither result alone establishes Step 2 acceptance.

## Build and rollback

Preserved Step 2I control: `apps/mobile/build/pose-quality/step2i-sampler-candidate-profile.apk`, SHA-256 `747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4`. The currently installed control matched that hash through ADB before replacement. This control retains beta 0.3 and the Step 2C/2I preprocessing improvements.

Step 2K candidate: `apps/mobile/build/pose-quality/step2k-refined-skeleton-profile.apk`, **147,181,950 bytes**, SHA-256 **`8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff`**. Profile build succeeded in 100.3 s. All **309 APK entries outside META-INF/signatures and compiled libapp.so** match the control; APK entry inventory is identical, including model hashes, Android manifest, native interpreters and other bundled assets.

ADB `install -r` succeeded on serial `xiaomi-device-serial-redacted`, and `sha256sum` of the installed package's `base.apk` matches the candidate. GainPath was launched and confirmed running as PID **9457**. The immediate launch-time `pidof` returned before the app started; the later check confirmed the process. Old PID 24057 logs were identified as prior control evidence and are not counted as new diagnostic results. PID 9457 and the installed candidate hash were verified again when collecting the fresh still report.

Candidate profile command, from `apps/mobile`:

```powershell
& C:/flutter/bin/flutter.bat build apk --profile --no-pub `
  --dart-define=GAINPATH_BACKEND=mock `
  --dart-define=GAINPATH_POSE_PREVIEW=true `
  --dart-define=GAINPATH_POSE_QUALITY_DEBUG=true `
  --dart-define=GAINPATH_POSE_JOINT_LAG_DEBUG=true `
  --dart-define=GAINPATH_POSE_BLANK_DEBUG=true `
  --dart-define=GAINPATH_POSE_REFINED_SKELETON=true
```

Model version remains `mediapipe-full-e9a5c5cb-det-9ba9dd3d`. Beta 0.3, minCutoff/derivative cutoff 1, interpreter threads 2, detector/ROI cadence, resolution, thresholds, projection/mirroring, freshness, watchdog and latest-frame scheduling are unchanged. Mock mode and workout acceptance/upload boundaries remain intact.

Install and rollback use `adb -s xiaomi-device-serial-redacted install -r` with the respective preserved APK; no uninstall/data-clear command is needed. Preserve the control artifact regardless of the diagnostic result.

## Verification ledger

New pixel/source tests were observed failing before implementation: the green skeleton stayed at filtered coordinates; invalid sources fell back to filtered pixels; source labels were absent. A repaint-clear test then failed before its fix. A capture-start test exposed the artificial-blank interaction before the separate display owner fixed it. An initial test used incorrect report key names; those keys were corrected before confirming the intended source-label failure.

Fresh checks: **46 affected mobile tests passed** with the complete candidate flags, including the real Workout camera-preview composition, mirror pixels, filtered-marker ledger, invalid ownership, nonfinite data, confidence rejection, repaint, capture/countdown and lifecycle behavior. **151 full default mobile tests passed**, with **15 define-gated checks explicitly skipped**. Full mobile analysis is clean. Source isolation and preserved control hash verified. Build/phone attestation and physical results are separate from these host checks.

Local build/test/provenance artifacts belong under ignored `apps/mobile/build/pose-quality/step2k/` and the `step2k-*.log` files in its parent. No Firebase, RepFSM, scoring, audio, gamification, ML Kit or Step 3 wiring is added.

## Fresh still capture — 6 October 2026

Session `1791255808931760`, PID 9457, local capture approximately **11:04:06.467–11:04:26.505**. The lag report starts at route time 37,536,230 µs and lasts 20.037149 s. There are **269 matched input/delivery/paint observations**, all worker outcomes `pose`, zero timestamp mismatches, no filter reset and no capacity truncation. Three repaint observations without a new delivery are excluded from unique pose counts. The report cohort is delivery/paint based: its first representative input precedes capture start by 47.376 ms; it is not a strictly input-after-start cohort.

The bounded blank report is complete: **zero whole-overlay blank episodes**, zero dropped report events and no open episode at capture end. Left upper arm, left forearm and right upper arm links were issued in all 269 observations. The right forearm was issued in 263; six observations rejected the right wrist on presence, including one also rejecting visibility. These confidence counts overlap. Whole-pose presence therefore must not be substituted for per-joint acceptance.

Filtered marker statistics include three right-elbow and six right-wrist off-canvas observations; viewport counts are seven and six respectively. These are **magenta filtered-marker observations**, not green refined-skeleton viewport counts. An early representative shows a rejected/off-canvas right wrist, while both middle and final representatives accept all tracked joints. Sparse samples cannot locate every rejection or prove all occurred during preparation.

Full-capture same-input R→S image-space displacement, in upright unmirrored **480×720 pixel units**:

| Joint | Median px | Mean px | p95 px | Max px |
|---|---:|---:|---:|---:|
| Left elbow | 0.96 | 2.44 | 9.78 | 31.14 |
| Right elbow | 0.88 | 2.69 | 13.28 | 39.09 |
| Left wrist | 0.84 | 2.80 | 12.12 | 40.98 |
| Right wrist | 1.05 | 3.05 | 16.20 | 57.90 |

The largest retained right-elbow displacement occurs at input +0.788 s, within the allowed return-to-position interval. At +10.028 s, elbow displacements are 1.61/0.32 px and wrist displacements 1.41/0.29 px; at +19.877 s they are 1.41/0.71 px and 0.66/1.62 px (left/right). Do not interpret full-capture maxima as controlled stationary jitter. **R→S displacement measures filter separation, not jitter or motion delay in milliseconds.**

All 24 retained representative records identify `refined_diagnostic` primary drawing and `filtered_markers` coordinate fields. Independent reconstruction verifies normalized→image pixels, current mirror/cover→preview and viewport transforms, raw confidence sigmoid/acceptance, refinement displacement and R→S displacement. Maximum numerical reconstruction residual is below 6×10⁻¹⁴ pixels; this validates recorded transform consistency, not anatomical model accuracy. No external screen video is yet confirmed, so C→R timing and visible held-pose jitter remain unresolved.

Interior telemetry is a separate **10.001 s completion window**, approximately 11:04:13.935–11:04:23.936, using three complete polls and cumulative sum/count differences. It is not the exact 20 s input cohort. Camera received **29.90 FPS** (299), processed/delivered/drawable/first CPU paint each **13.50 FPS** (135). Latest pending frames replaced: 164; stale results, empty poses and nonempty overlay expiries: zero.

| Interior timing | Mean ms |
|---|---:|
| Camera copy | 0.80 |
| Queue age | 17.81 |
| Detector preprocessing / inference (9 runs) | 15.72 / 37.39 |
| Detector decode / ROI | 0.15 |
| Landmark preprocessing / inference | 20.56 / 47.77 |
| Landmark postprocessing | 0.55 |
| Total preprocessing / native inference | 21.61 / 50.26 |
| Worker computation | 72.65 |
| Filter CPU execution | 0.12 |
| Callback→UI | 92.45 |
| Callback→first CPU paint | 104.96 |
| Pose input age at first CPU paint | 104.28 |
| Refined source selection CPU | 0.021 |
| Joint diagnostic delivery / paint CPU | 0.004 / 0.122 |
| Blank diagnostic delivery / paint CPU | 0.022 / 0.037 |
| Worker diagnostic trace CPU | 0.039 |

Endpoint whole-pose presence is 0.9999–1.0 with tracked ROI; last detector confidence is 0.9780–0.9793. Callback/pose-age figures stop at the CPU painter and exclude physical sensor/display boundaries. They must not be combined with an assumed C→R interval. No matched control inference of diagnostic overhead or physical speedup is warranted from this still capture alone.

Evidence: ignored `step2k/still-phone.log`, `still-joints.json`, `still-blanks.json`, `still-interior.json` and independent `still-checks.json`; hashes are in the updated evidence manifest. No production source or tuning change was made during collection. Next collect slow one-arm motion, then fast motion and holds, with original close-screen recording if available. Step 2 acceptance remains pending.

## Slow capture — 6 October 2026

Collected from the same installed candidate process, PID **9457**, in a new preview session **1791256327124049**. Do not merge route timestamps across the still and slow sessions. The lag phase starts at **7,479,511 µs**, lasts **20.011372 s** and contains **269** matched observations, all worker outcomes `pose`. Timestamp mismatches, filter resets, capacity truncation and malformed transport records are zero; two paints without a new delivery are excluded. The separate blank capture lasts 20.003282 s and reports **zero whole-overlay blanks**, no dropped events and no open episode. The first retained input is 53.062 ms before the lag capture start; the cohort is delivery/paint based.

Accepted-joint R→S displacement in upright unmirrored 480×720 image pixels:

| Joint | Accepted / observed | Median px | Mean px | p95 px | Max px |
|---|---:|---:|---:|---:|---:|
| Left elbow | 268 / 269 | 1.20 | 2.99 | 15.21 | 32.86 |
| Right elbow | 269 / 269 | 5.30 | 6.51 | 15.77 | 60.20 |
| Left wrist | 262 / 269 | 1.07 | 3.09 | 15.48 | 34.83 |
| Right wrist | 262 / 269 | 10.98 | 11.71 | 21.64 | 91.13 |

Right-sided crossings dominate the motion report. Displacement distributions include preparation and holds, and reject confidence-failing joints. The retained peak at **+0.715 s** is within preparation: right elbow R=(172.97,421.47), S=(127.22,460.60), distance 60.20 px; right wrist R=(164.53,508.23), S=(97.75,570.24), distance 91.13 px. Do not present those peaks as controlled slow-motion maxima. At **+9.802 s**, right elbow R=(196.11,410.78), S=(201.13,417.07), distance 8.05 px; right wrist R=(148.76,426.50), S=(157.39,440.75), distance 16.66 px. Both pass confidence and their links are issued. At +19.838 s their distances are 3.23 and 5.51 px.

The wrist crossing lists have four separated refined/filtered raises and three lowers. The following order-matched pairs are **conditional internal filter-response candidates**, not camera-screen events. Times are route **input seconds**, not video PTS. Each crossing locally requires accepted finite joint/shoulder coordinates, unchanged filter generation and adjacent inputs at most 250 ms apart. Bounded event lists do not preserve the full trajectory between crossings; no external video is yet confirmed. Keep the remaining final wrist lower outside the observed window censored rather than inventing a delay.

| Right wrist event | R input bracket s | S input bracket s | Candidate R→S interval ms |
|---|---|---|---|
| Raise 1 | 13.116737–13.187199 | 13.255235–13.328363 | 68–212 |
| Lower 1 | 14.415342–14.484279 | 14.484279–14.581601 | 0–167 |
| Raise 2 | 17.763343–17.818014 | 17.886997–17.963845 | 69–201 |
| Lower 2 | 18.912713–18.987185 | 19.049031–19.128880 | 61–217 |
| Raise 3 | 21.986197–22.120002 | 22.196597–22.245906 | 76–260 |
| Lower 3 | 23.311451–23.383206 | 23.383206–23.480177 | 0–169 |
| Raise 4 | 26.018663–26.084138 | 26.221695–26.315735 | 137–298 |

Right elbow has seven refined raises/lowers versus three filtered raises/lowers. Early and final refined recrossings make unique event pairing unreliable. For example, the first filtered raise has two nearby refined candidates, giving 232–335 ms or 65–205 ms. Do not average these or treat a damped recrossing as a missing renderer link. The bounded report supports added filter separation during motion but does not establish displayed-camera→refined delay or total physical latency.

Link counts: left upper arm 268 issued / 1 elbow rejection; left forearm 262 issued / 1 elbow-first rejection / 6 wrist-first rejections; right upper arm 269 issued; right forearm 262 issued / 7 wrist rejections. Left elbow visibility fails once. Left wrist visibility fails six times and presence five times, overlapping in seven rejected observations. Right wrist has seven presence failures and no visibility failures. Counts distinguish individual joint rejection from whole-pose loss. The first retained snapshot shows rejected wrists while returning from the phone; middle/final snapshots accept all six tracked joints, but sparse samples cannot timestamp every rejection.

Filtered-marker off-canvas/viewport observations: left elbow 0/15, right elbow 0/0, left wrist 1/17, right wrist 7/9. These remain separate from green refined-link viewport observations. No nonfinite or missing tracked joints. Independent reconstruction of all **24** representative samples verifies current image, mirror/cover, viewport and confidence transforms, with residual below 5×10⁻¹⁴ pixels and correct diagnostic source tags. This verifies transform consistency, not anatomical accuracy or absence of jitter.

Separate interior telemetry window: **11:12:22.126–11:12:32.126**, 10.000 s, estimated route 15.002076–25.002076 s. Received 300 frames (**30.0 FPS**); processed/delivered/drawable/first CPU paint 133 each (**13.3 FPS**); replaced pending 167. Stale, empty, detector no-person, low whole-pose presence and nonempty overlay expiry counts are zero in that window. Whole-pose presence endpoints are 0.9999–1.0; last detector confidence 0.9720–0.9747, tracked ROI.

Mean milliseconds: preprocessing **21.27**, native inference **51.87**, worker computation **73.97**, queue age **16.96**, filter CPU **0.109**, callback→UI **92.89**, callback→first CPU paint **103.95**, pose age at paint **103.27**. Detector preprocessing/inference (9 runs) 16.86/35.91; landmark preprocessing/inference 20.13/49.44; detector decode/ROI 0.20; landmark postprocessing 0.62. Refined selection CPU 0.030; joint diagnostic delivery/paint 0.004/0.078; blank diagnostic delivery/paint 0.021/0.038; worker trace 0.046. These CPU timing means are separate from the crossing response brackets and external display timing; do not add them into a synthetic total delay.

Evidence: ignored `step2k/slow-phone.log`, `slow-joints.json`, `slow-blanks.json`, `slow-interior.json`, `slow-checks.json` and updated manifest. No production code or frozen parameter changed. Next collect fast motion, then held stability and close verification. External C→R response remains unresolved until a legible original screen video is supplied. Step 3 remains deferred.

## Fast capture — 6 October 2026

Collected from PID **9457**, session **1791256562951962**. Input timestamps are local to this preview session and must not be compared directly with earlier sessions. Lag capture starts at **11,040,521 µs**, lasts **20.024466 s**, and retains **258** matched observations, all worker outcomes `pose`. Timestamp mismatches, filter resets, malformed records and capacity truncation are zero; three paints without new delivery are excluded. Separate blank capture duration 20.002288 s: **zero whole-overlay blank episodes**, zero dropped events and no open episode. First representative input precedes lag capture start by 41.441 ms; cohort remains delivery/paint based.

Accepted-joint R→S displacement in upright unmirrored 480×720 image pixels:

| Joint | Accepted / observed | Median px | Mean px | p95 px | Max px |
|---|---:|---:|---:|---:|---:|
| Left elbow | 257 / 258 | 1.09 | 2.76 | 14.51 | 25.40 |
| Right elbow | 257 / 258 | 8.17 | 8.56 | 14.58 | 51.55 |
| Left wrist | 253 / 258 | 1.16 | 3.64 | 20.86 | 81.10 |
| Right wrist | 252 / 258 | 16.04 | 16.22 | 28.30 | 89.10 |

Right-wrist median separation increases from slow **10.98 px** to fast **16.04 px**, and right-elbow median from **5.30** to **8.17 px**. These whole-capture accepted-joint distributions include preparation and holds; motion amplitude/pace are not identical controlled trajectories. They support filter separation during movement, not a numerical physical-latency estimate or a tuning comparison.

At input **+9.753 s**, right elbow R=(187.33,401.77), S=(194.68,412.44), separation 12.95 px; right wrist R=(140.66,411.82), S=(153.09,433.83), separation 25.28 px. Both pass confidence with actual arm links issued. At +19.912 s separations remain 9.17/23.08 px; movement/settling state is unverified without video. The selected aggregate peak at **+0.623 s** falls inside preparation and cannot represent controlled fast-motion maxima. All 24 representative records independently reconstruct image/preview/viewport coordinates, confidence sigmoid, acceptance and displacement, residual below 5×10⁻¹⁴ pixels. Tags remain refined primary drawing and filtered marker coordinate fields.

Six separated refined/filtered wrist raises and six lowers are present. Order-matched **conditional internal filter-response candidates** below use route input timestamps, not screen/video timestamps. As in slow, event acceptance/continuity checks apply locally to each crossing; the complete trajectory between crossings is not persisted. No automatic candidate average is justified.

| Right wrist event | R input bracket s | S input bracket s | Candidate R→S interval ms |
|---|---|---|---|
| Raise 1 | 15.261161–15.358952 | 15.494972–15.562500 | 136–302 |
| Lower 1 | 16.130065–16.226729 | 16.226729–16.301265 | 0–172 |
| Raise 2 | 18.244553–18.360198 | 18.360198–18.427423 | 0–183 |
| Lower 2 | 18.790082–18.858830 | 18.898242–18.975524 | 39–186 |
| Raise 3 | 20.932152–20.989572 | 21.071465–21.140460 | 81–209 |
| Lower 3 | 21.888461–21.964613 | 21.964613–22.059542 | 0–172 |
| Raise 4 | 23.857290–23.972345 | 24.090808–24.157254 | 118–300 |
| Lower 4 | 24.766411–24.797015 | 24.797015–24.889866 | 0–124 |
| Raise 5 | 26.856171–26.937183 | 26.996257–27.063411 | 59–208 |
| Lower 5 | 27.559886–27.628626 | 27.628626–27.692727 | 0–133 |
| Raise 6 | 29.604328–29.656170 | 29.732797–29.821497 | 76–218 |
| Lower 6 | 30.327684–30.424662 | 30.424662–30.498721 | 0–172 |

Millisecond endpoints above are rounded **outward**. Conservative slow brackets overlap substantially; increased displacement must not be treated as proof that fast response is slower in milliseconds. Right elbow has four refined raises/lowers versus two filtered. Matched raise candidates 1 and 3 give **99–236 ms** and **142–292 ms**; their lower brackets share the same input pairs, allowing negative-to-positive intervals (**−100–100 ms**, **−57–57 ms**) rather than an invented exact zero. Refined excursions 2 and 4 recross briefly with no corresponding filtered crossing. Keep those as unmatched/damped or ambiguous events; do not confuse suppression of a short excursion with a renderer link disappearing, or average them as normal successful samples.

Actual primary-link ledger: left upper arm **257 issued / 1 elbow rejection**; left forearm **253 issued / 1 elbow-first / 4 wrist-first rejections**; right upper arm **257 issued / 1 elbow rejection**; right forearm **252 issued / 1 elbow-first / 5 wrist-first rejections**. Left and right elbow each have one presence failure. Left wrist rejects five times (presence five, visibility two); right wrist six (presence six, visibility two). Confidence counts overlap and edge reason priority means they are not additive link counts. First snapshot shows out-of-image/rejected wrist during preparation; sparse representatives cannot locate every rejection.

Filtered-marker off-canvas/viewport counts: left elbow **0/6**, right elbow **6/7**, left wrist **5/8**, right wrist **7/7**. These concern magenta markers, not the green skeleton. All tracked coordinates are finite; none missing. Transform reconstruction does not establish anatomical prediction accuracy.

Separate interior completion window **11:16:17.955–11:16:27.954**, **9.999 s**, route estimate 15.003038–25.002038 s: camera received **300 (30.00 FPS)**; processed/delivered/drawable/first CPU paint **135 each (13.50 FPS)**; pending replaced **165**; stale, empty, detector no-person and low whole-pose presence zero. No blank episode occurred anywhere in the captured phase. Endpoint pose presence **0.9998–1.0**, last detector confidence **0.9719–0.9813**, tracked ROI. Full lag-cohort observations average about 12.88/s, distinct from the narrower interior FPS.

Mean milliseconds: preprocessing **21.17**, native inference **51.46**, worker **73.31**, queue age **18.09**, filter CPU **0.119**, callback→UI **93.55**, callback→first CPU paint **105.95**, pose age at paint **105.21**. Detector preprocessing/inference (9 runs) **16.20/36.10**, decode/ROI **0.11**; landmark preprocessing/inference **20.09/49.06**, postprocessing **0.48**. Refined selection CPU **0.027**, joint diagnostic delivery/paint **0.006/0.105**, blank diagnostic delivery/paint **0.022/0.027**, worker trace **0.040**. As before, CPU timing and internal filter-response brackets remain separate from external screen timing.

Evidence: ignored `step2k/fast-phone.log`, `fast-joints.json`, `fast-blanks.json`, `fast-interior.json`, `fast-checks.json` and manifest. No production code or parameter changed. Next top hold, then bottom hold and End preview cleanup verification. Need legible external screen evidence or an explicitly unresolved C→R conclusion before selecting another experiment. Step 3 remains deferred.

## Top hold — 6 October 2026

PID **9457**, session **1791256750807035**. Lag capture start **26,614,617 µs**, duration **20.032265 s**, **273 matched pose observations**, no timestamp mismatches, no recorded filter reset and no phase-capacity truncation. Two paints without new delivery are excluded. The blank report separately covers 20.021058 s and contains one recovered, CPU-paint-confirmed episode with three retained events; transport complete, no dropped events or open episode. The first representative input precedes capture by 82.398 ms. Delivery/paint cohorts must not be treated as strictly post-start input cohorts.

### Startup blank: preserve the pre-capture cause sequence

Scalar health context, in this session's route microseconds:

| Observation time µs | Input µs | State transition / probability |
|---:|---:|---|
| 26,111,357 | 26,030,060 | pose → low landmark pose presence, 0.28995 |
| 26,338,015 | 26,226,567 | recovered pose, presence 0.55139, 13 accepted joints |
| 26,491,022 | 26,388,115 | pose → low landmark pose presence, 0.39398 |
| 26,541,159 | 26,487,282 | low presence → detector no-person |
| 26,649,484 | 26,532,219 | recovered pose, presence 0.82019, 18 accepted joints |

The bounded capture first observes the **already-existing empty detector result**: input 26,487,282, result received 26,541,049, diagnostic delivery 26,541,142 (all before capture). Detector confidence **0.481282**, detector ROI source, next ROI unavailable. Refined/filtered/accepted count zero, no valid refined frame, renderer did not reject all joints; it had no pose to draw. There is no freshness transition in this local scalar interval. Last valid input 26,321,305 and delivery 26,406,566; recorded age at blank observation **301.710 ms** does not establish freshness as the cause because prediction had already become empty.

Within the capture, first blank paint is at 26,623,038 µs; recovery CPU observation at 26,658,236. Parser observation-time duration is **35.189 ms**. This is the **observed CPU-painted blank slice**, with full episode onset **left-censored at capture start**. Do not call 35 ms the full blank duration or physical screen blank duration, even though the parser labels the retained begin/recovery pair `complete`. The pre-capture history establishes prediction-loss causes (low presence, then detector no-person); the bounded in-capture state names the latest detector reason. Both must be preserved rather than collapsed to one generic tracking-loss label.

Recovery input **26,532,219**, result received **26,649,334**, diagnostic delivery **26,649,464**, detector confidence **0.654750**, detector ROI, next tracked auxiliary ROI; 33 refined/filtered landmarks, pose presence **0.820187**, 18 accepted joints. The painter issues 33 primitives, 11 intersecting the viewport, without rejecting all joints. Latest pending replacement is a separate scheduler observation, not the cause of this empty model output. No further whole-overlay blank is retained during the phase.

### Joint separation and held interpretation

Accepted-joint R→S displacement, upright unmirrored 480×720 image pixels; statistics include preparation, raise and the intended hold:

| Joint | Accepted / observed | Median px | Mean px | p95 px | Max px |
|---|---:|---:|---:|---:|---:|
| Left elbow | 270 / 273 | 0.92 | 3.35 | 14.74 | 72.12 |
| Right elbow | 273 / 273 | 1.03 | 4.03 | 18.35 | 92.48 |
| Left wrist | 263 / 273 | 1.27 | 3.57 | 14.23 | 42.52 |
| Right wrist | 269 / 273 | 1.07 | 4.68 | 24.26 | 78.99 |

The selected aggregate peak is **+0.343 s**, inside return-to-position preparation, and cannot be presented as stationary jitter or a held maximum. At **+9.878 s**, right elbow R=(170.45,385.01), S=(170.82,384.26), separation **0.84 px**; wrist R=(120.93,370.15), S=(121.19,369.37), **0.82 px**. At **+19.867 s**, elbow R=(170.93,383.03), S=(169.76,383.03), **1.17 px**; wrist R=(119.20,367.53), S=(119.32,367.65), **0.17 px**. All arm links are issued in both snapshots. These samples support R/S convergence, but sparse points cannot measure jitter distributions, settling duration or anatomical accuracy.

One refined wrist raise bracket **29.924712–29.992108 s** and filtered raise **30.085393–30.155370 s** give a conditional internal R→S interval **93–231 ms** (outward-rounded). No wrist lower is retained, so the planned lowering is unconfirmed and the return crossing remains censored. Elbow refined raise/lower lists each reach the **12-event per-list cap**; their counts are censored independently of the phase frame-capacity flag. The filtered list has two raises and one lower. Near-plane recrossings during an intended hold do not constitute repeated arm movement or quantify visible jitter. No C→R or physical timing is inferred.

Actual links: left upper arm **270 issued / 3 elbow rejections**; left forearm **263 issued / 3 elbow-first / 7 wrist-first rejections**; right upper arm **273 issued**; right forearm **269 issued / 4 wrist rejections**. Left elbow rejects visibility three times; left wrist ten (visibility ten, presence seven); right wrist four (visibility four, presence three). Confidence categories overlap. The first/peak representatives show preparation rejections, while middle/final representatives accept all tracked joints; individual rejection timing cannot be fully reconstructed from sparse samples.

Filtered-marker off-canvas/viewport counts: left elbow **0/7**, right elbow **0/2**, left wrist **13/14**, right wrist **6/6**. They remain distinct from green refined-link viewport counts. No missing/nonfinite tracked coordinates. All **24** representative records reconstruct image, mirror/cover, viewport, confidence and displacement with residual below 5×10⁻¹⁴ pixels and correct refined-primary/filtered-marker tags.

### Separate computation telemetry

Interior completion window **11:19:40.810–11:19:50.811**, **10.001 s**, route estimate 30.003053–40.004053 s: received **300 (30.00 FPS)**; processed/delivered/drawable **138 each (13.80 FPS)**; unique first CPU paints **137 (13.70 FPS)**; pending replacements **163**; stale, empty, detector no-person and low pose presence **zero inside this narrower window**. The startup prediction-loss event lies outside it. Endpoint pose presence **0.9998**, last detector confidence **0.9761–0.9784**. Do not erase the full-phase blank because the interior window has zero empty results.

Mean milliseconds: preprocessing **20.15**, native inference **50.50**, worker **71.50**, queue age **17.62**, filter CPU **0.105**, callback→UI **91.27**, callback→first CPU paint **102.70**, pose age at paint **101.86**. Detector preprocessing/inference (9 runs) **19.69/32.05**, decode/ROI **0.16**; landmark preprocessing/inference **18.87/48.41**, postprocessing **0.64**. Refined selection CPU **0.019**, joint diagnostic delivery/paint **0.004/0.081**, blank diagnostic delivery/paint **0.020/0.021**, worker trace **0.041**. These are CPU observations, separate from signal response and physical display timing.

Evidence: ignored `step2k/topHold-phone.log`, `topHold-joints.json`, `topHold-blanks.json`, `topHold-interior.json`, `topHold-checks.json` (including pre-capture scalar context), and manifest. No production source or frozen parameter changed. Next bottom hold, then End preview and cleanup verification; external screen evidence remains unconfirmed. Held stability and Step 2 quality acceptance are not yet established. Step 3 remains deferred.

## Bottom hold and cleanup — 6 October 2026

PID **9457**, session **1791257028138643**. Lag capture starts at **13,615,809 µs**, lasts **20.037157 s**, retaining **271 matched observations: 269 pose and two detector no-person results**. No timestamp mismatch, recorded filter reset, phase-capacity truncation or malformed report. Blank report duration 20.037184 s, one recovered CPU-confirmed episode, three events, complete transport and no dropped/open events. Two empty observations have no joint coordinates; their edge ledger rejection labels indicate absent joints, not per-joint confidence failures.

Pre-capture scalar health records pose→low landmark presence at **12,647,748 µs** (input 12,566,195; probability **0.354049**), then detector no-person at **13,046,792 µs** (input 12,966,423). Recovery occurs at **13,813,666 µs**. This prediction-loss interval begins before capture. The captured blank's current cause input **13,535,132**, result received **13,622,798**, diagnostic delivery **13,622,954**, detector confidence **0.490535**, detector ROI source, next ROI unavailable. Refined/filtered/accepted counts zero; no valid refined frame existed. First blank CPU paint **13,632,023**, renderer did not reject all joints because there was no pose. Recorded last-valid input **12,499,789**, delivery **12,570,406**, age approximately **1.13 s** at paint is not proof of freshness causing the blank; prediction was already empty.

Recovery input **13,667,239**, result received **13,813,533**, diagnostic delivery **13,813,646**, detector confidence **0.536664**, whole-pose presence **0.704291**; 33 refined/filtered landmarks, 17 accepted joints, 31 issued primitives, 12 intersecting the viewport, next tracked auxiliary ROI. CPU recovery observation **13,826,261**. The parser records **194.221 ms** between its observed blank paint and recovery. Full blank duration is **left-censored**, because the actual prediction-loss state began before capture; 194 ms must not be called the entire blank or physical screen duration. The scalar empty-state interval from first low-presence transition to recovery is about **1.166 s**, a separate logical-health boundary without complete pre-capture paint timing. No further blank episode occurs in the bounded phase.

Accepted-joint R→S displacement, upright unmirrored 480×720 image pixels. Each joint is observed on 269 pose frames and missing on the two empty frames:

| Joint | Accepted / pose observations | Median px | Mean px | p95 px | Max px |
|---|---:|---:|---:|---:|---:|
| Left elbow | 264 / 269 | 0.65 | 2.39 | 11.15 | 44.56 |
| Right elbow | 269 / 269 | 0.58 | 2.48 | 11.85 | 40.27 |
| Left wrist | 262 / 269 | 0.64 | 2.74 | 15.60 | 46.61 |
| Right wrist | 263 / 269 | 0.72 | 2.55 | 11.56 | 61.79 |

Peak representative input **+0.793 s** is during preparation and does not establish held jitter. At **+9.878 s**, right elbow R=(181.96,443.74), S=(182.22,443.31), distance **0.50 px**; wrist R=(164.43,497.08), S=(164.27,496.04), **1.06 px**. At **+19.885 s**, elbow R=(183.53,443.95), S=(183.42,444.37), **0.43 px**; wrist R=(165.70,496.59), S=(165.63,496.93), **0.35 px**. All arm links issued in both later snapshots; no shoulder-level crossing retained. Only **18 joint representatives** exist (three pose snapshots); the first selected observation is empty and supplies no joint representatives. Independent reconstruction again verifies current coordinate/confidence transforms, residual below 6×10⁻¹⁴ pixels. Sparse convergence cannot establish stationary jitter, settling duration or anatomical accuracy.

Actual link ledger, over all 271 observations: left upper arm **264 issued / 3 shoulder-first / 4 elbow-first rejections**; left forearm **262 issued / 7 elbow-first / 2 wrist-first**; right upper arm **269 issued / 2 missing-shoulder**; right forearm **263 issued / 2 missing-elbow / 6 wrist rejections**. Two empty-frame edge reasons are absence. On pose frames, left shoulder has one presence rejection; left elbow five (visibility five, presence one); left wrist seven (visibility seven, presence five); right wrist six (visibility four, presence six). Confidence categories overlap; edge-first reason precedence prevents summing these as link counts. Right elbow and shoulder accept all 269 pose observations.

Filtered-marker off-canvas/viewport counts: left elbow **0/13**, right elbow **0/4**, left wrist **5/16**, right wrist **5/7**. They do not describe green refined-link visibility. No nonfinite pose joint coordinates; the two missing observations are explicit no-person outputs.

Separate interior completion window **11:24:08.143–11:24:18.142**, **9.999 s**, route estimate 20.005036–30.004036 s: camera **300 (30.00 FPS)**; processed/delivered/drawable/first CPU paints **135 each (13.50 FPS)**; pending replaced **165**. Stale, empty, no-person and low whole-pose presence counts zero in this narrower window. Endpoint pose presence **1.0**, last detector confidence **0.9752–0.9809**, tracked ROI. This does not remove the full-phase startup prediction loss.

Means in milliseconds: preprocessing **20.63**, native inference **51.49**, worker **72.90**, queue **18.21**, filter CPU **0.099**, callback→UI **93.14**, callback→first CPU paint **104.23**, pose age at paint **103.56**. Detector preprocessing/inference (9 runs) **15.63/37.04**, decode/ROI **0.13**; landmark preprocessing/inference **19.59/49.02**, postprocessing **0.54**. Refined selection CPU **0.030**, joint diagnostic delivery/paint **0.006/0.092**, blank diagnostic delivery/paint **0.021/0.039**, worker trace **0.053**. CPU timing remains separate from screen signal response and physical latency.

End preview emits `lifecycle_closed` at **11:24:58.067**, route **69,929,166 µs**. Android camera service records GainPath PID 9457 disconnect at **11:24:58** and reports **Active Camera Clients: []**. Final installed APK SHA-256 still matches **8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff**. This verifies route closure and camera release; it is not an independent native-memory/leak measurement. Existing lifecycle/disposal host tests remain the code-level evidence, with no application source changes during these captures.

Evidence: ignored `step2k/bottomHold-phone.log`, `bottomHold-joints.json`, `bottomHold-blanks.json`, `bottomHold-interior.json`, `bottomHold-checks.json`, `cleanup-camera.txt`, `final-installed-apk.sha256.txt` and manifest.

## Five-phase evidence decision

| Phase | Matched observations | Pose / no-person | Observed whole blanks | Interior drawable FPS | Callback→first CPU paint mean ms | Right elbow / wrist median R→S px |
|---|---:|---|---:|---:|---:|---|
| Still | 269 | 269 / 0 | 0 | 13.50 | 104.96 | 0.88 / 1.05 |
| Slow | 269 | 269 / 0 | 0 | 13.30 | 103.95 | 5.30 / 10.98 |
| Fast | 258 | 258 / 0 | 0 | 13.50 | 105.95 | 8.17 / 16.04 |
| Top hold | 273 | 273 / 0 | 1 inherited startup state | 13.80 | 102.70 | 1.03 / 1.07 |
| Bottom hold | 271 | 269 / 2 | 1 startup prediction-loss episode | 13.50 | 104.23 | 0.58 / 0.72 |

There are **1,340 matched observations**, including two empty results, across separate preview sessions. There are **114 bounded joint representatives**, with consistent source tags and independently reconstructed transforms. No timestamp mismatch is reported. Counts and statistics retain each phase's cohort; do not construct a continuous trajectory across sessions or use these observations as simulated workout activity.

The verified added signal separation remains **One Euro filtering during movement**, with convergence in later held samples. Production beta stays **0.3**; this diagnostic does not justify releasing unfiltered drawing. The later [screen review](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-step2k-screen-review.md) also establishes qualitative lag before filtering at camera-preview→refined drawing. Its conservative supplemental wrist intervals include zero; anatomical-elbow crossings remain censored. Input-age versus landmark-prediction contributions and the dominant share of complete visible delay cannot be ranked. Mathematical projection/binding consistency is verified in the retained samples; calibrated anatomy and sustained held jitter remain unverified.

The two bounded whole-blank episodes trace to **startup prediction loss**, with pre-capture low landmark pose presence followed by detector no-person. Their captured CPU durations are censored for full onset. There is no evidence in these bounded captures that otherwise-valid poses are predominantly blanked by freshness or renderer rejection. Individual arm-link losses are explained separately by joint confidence and two wholly absent poses; off-viewport marker counts are not equivalent to whole-overlay loss. No threshold/freshness tuning is justified from these events alone.

All five interior windows deliver about **13.3–13.8 drawable FPS**, with callback→first CPU paint **102.7–106.0 ms**, native inference **50.3–51.9 ms** and worker computation **71.5–74.0 ms**. Small diagnostic CPU costs do not measure filter signal delay. These ranges are neither an external latency measurement nor a matched production/control overhead experiment.

**External review completed:** [VID_20261006_121700.mp4 analysis](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-step2k-screen-review.md). Its newer session is distinct from these five captures. No confirmed whole-overlay blank is observed; matched scalar telemetry delivers 13.45 drawable FPS with 104.25 ms callback→first CPU paint. No physical latency is inferred or combined with CPU timing.

**Recommended next action:** audit GPU-delegate feasibility and same-input numerical agreement before an isolated CPU-versus-GPU experiment, targeting the measured native-inference share of worker computation. Preserve runtime/model bytes and every other frozen setting; report unsupported/partial delegation rather than stacking changes. No delegate, production tuning or Step 3 work is implemented in this review. Step 2 quality is **not accepted**.
