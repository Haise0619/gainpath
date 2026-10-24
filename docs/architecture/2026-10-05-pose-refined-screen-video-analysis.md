# Step 2H — close-screen camera/refined/skeleton analysis

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

**The new video confirms repeated moving-arm discrepancy before One Euro filtering, with additional refined-to-filtered discrepancy. It does not establish a precise positive minimum C→R delay or prove which contribution dominates. Step 2 quality acceptance remains open.** No production code, parameters, model assets, camera configuration or APK installation were changed for this analysis. Step 3 remains deferred.

The current control retains Step 2C preprocessing, One Euro beta 0.3/minCutoff 1/derivative cutoff 1 and two interpreter threads. Detector/ROI cadence, confidence thresholds, image resolution, projection/mirroring/cover crop, freshness 250 ms, watchdog 100 ms and latest-frame backpressure remain frozen. The rejected beta 0.6 and four-thread experiments are not being combined with this run.

## Source and provenance

Original supplied by the user: [VID_20261005_214051.mp4](C:/Users/Ngzhe/Downloads/VID_20261005_214051.mp4). The original remains unchanged; its byte-for-byte analysis copy is under the ignored local `apps/mobile/build/pose-quality/step2h/` directory.

| Property | Verified value |
| --- | --- |
| SHA-256 | `321d594b5ce49868e1a4b9492e2d206240fb78293a0bd5df4ba42e9304376b67` |
| File size |247,641,465 bytes |
| Codec / encoded dimensions |HEVC Main, 3840×2160; rotation −90°, upright 2160×3840 |
| Nominal recording mode |60 FPS in Xiaomi recording metadata |
| Decoded frames |1,870, indexed from0 |
| Presentation time base |1/90,000s |
| First / last PTS |0 / 2,806,666 ticks, or 0 / 31.185177778 s |
| Container duration |31.20s |
| PTS-derived rate |59.9323 FPS: 1,869 intervals divided by first-to-last presentation duration |
| Adjacent PTS spacing |16.5667–33.3889 ms; three intervals exceed 25 ms |
| Recording device metadata |Xiaomi 17 / 25113PN0EG, Android 16; this is the second camera |
| GainPath test device |Xiaomi 23013RK75C, serial xiaomi-device-serial-redacted, Android 13 |

FFmpeg 7.1 decoded presentation order; `showinfo` ran before frame selection. Derivatives used passthrough without FPS conversion. Timing uses exact decoded PTS ticks, not frame/60. Decimal PTS labels identify reproducible frames and do not imply equally precise crossing measurements.

The badge at f600 reads `F295847 idle t=51.2 B0 visible none`. This matches retained phone session 1791207610295847, PID 9294, created at 21:40:10.296 local. f1200 reads 61.2 and f1800 reads 71.2, consistent with the same session. Using f600 gives an approximate route-clock minus video-PTS offset 41.2048 s, and approximate clip route interval 41.20–72.39 s. Badge rounding, notification cadence, screen scan and second-camera exposure prevent exact clock synchronization.

ADB at 22:11 local verified the currently installed APK SHA:

`9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07`

This matches the preserved two-thread profile control from [Step 2G](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-05-pose-interpreter-thread-experiment.md). Installation chronology, the matching badge/log session and current APK check support attribution to that control. A later APK hash is not a retrospective binary timestamp attestation, and the badge itself does not encode beta, thread count or APK hash. The matched log reports modelVersion `mediapipe-full-e9a5c5cb-det-9ba9dd3d` and verified runtime tensor contracts.

The capture button remained idle throughout this recording. There are **no bounded manual joint/blank phase reports** for it. The video is fresh external evidence; it must not be relabeled as the earlier Step 2F controlled phases. `B0 visible none` comes from an inactive bounded collector and does not prove absence of freshness clears.

## Observable boundaries and method

- **C:** elbow/upper-arm movement visible in the phone's live camera preview.
- **R:** yellow refined elbow ring relative to the yellow shoulder, after heatmap refinement and inverse-ROI projection, before One Euro.
- **S:** accepted green elbow/upper-arm segment, after filtering and the existing preview transform.

The raw model tensor is not visible in this video. The actual physical person outside the phone is not observable. No physical→preview, physical→skeleton or total physical camera-to-display latency is estimated.

Source inspection confirms yellow and magenta markers are joined to the same input timestamp, and both use the same existing `PreviewProjection` and outer cover/crop transform. Yellow rings and magenta dots bypass confidence acceptance when coordinates are finite; a marker alone does not prove its green limb link was accepted. Green links require both endpoint visibility and presence at least0.5. The magenta dots cover the green elbow/wrist centers, so S is read from the green segment rather than assuming a magenta dot is accepted skeleton evidence.

The repeated event is the **image-right elbow/upper arm passing approximately its own shoulder level**, relative to the local torso and tilted phone-screen perspective. Wrist crossings are not substituted. A horizontal row in the recording is not the shoulder plane. Sleeve coverage, shoulder shrug, uncertainty in anatomical joint centers, motion blur, stepped model updates, exposure blending and doubled markers are included in the event enclosures.

All 1,870 upper-body crops were screened for candidate whole-overlay absence; the candidate and neighboring full-preview frames were visually inspected. Crossing review used coarse sheets, fine sheets every 3–4 source frames, native crops and independent review. The timing table is a representative subset of repeated one-arm events, not an exhaustive census. Earlier cycles are visually slower than later cycles; these are not timer-labeled slow/fast phases. Initial and final bilateral movements are excluded from the primary one-arm comparison. Brief pauses do not substitute for the earlier 20 s static/hold phases.

For independent crossing enclosures C=[c0,c1], R=[r0,r1], S=[s0,s1]: C→R=[r0−c1,r1−c0], R→S=[s0−r1,s1−r0], C→S=[s0−c1,s1−c0]. Each boundary is calculated directly from video anchors. Displayed intervals round outward to 0.05 s. Negative lower bounds indicate overlapping uncertain crossing zones, not anticipation. No pooled mean, fitted delay, interpolation through missing markers, or sums with internal telemetry are used.

## Representative crossing brackets

| Event | C PTS s (frame) | R PTS s (frame) | S PTS s (frame) | C→R s | R→S s | C→S s |
| --- | --- | --- | --- | --- | --- | --- |
| earlier rise at9s |8.962356–9.162222 (f538–550) |9.162222–9.462133 (f550–568) |9.362200–9.612033 (f562–577) |0.00–0.50 |-0.10–0.45 |0.15–0.65 |
| earlier rise at11s |11.411167–11.711078 (f685–703) |11.561067–12.010878 (f694–721) |11.711078–12.160778 (f703–730) |-0.20–0.60 |-0.30–0.60 |0.00–0.75 |
| earlier lower at12s |12.060844–12.310789 (f724–739) |12.110811–12.510656 (f727–751) |12.210856–12.560622 (f733–754) |-0.20–0.45 |-0.30–0.45 |-0.10–0.50 |
| earlier rise at14s |14.493000–14.626356 (f870–878) |14.559733–14.826222 (f874–890) |14.692978–14.959467 (f882–898) |-0.10–0.35 |-0.15–0.40 |0.05–0.50 |
| earlier lower at15s |14.959467–15.159444 (f898–910) |15.026089–15.292689 (f902–918) |15.159444–15.425933 (f910–926) |-0.15–0.35 |-0.15–0.40 |0.00–0.50 |
| later rise at18s |18.007989–18.108033 (f1081–1087) |18.108033–18.357867 (f1087–1102) |18.257933–18.507767 (f1096–1111) |0.00–0.35 |-0.10–0.40 |0.10–0.50 |
| later lower at18s |18.457800–18.657778 (f1108–1120) |18.607811–18.807678 (f1117–1129) |18.707744–18.957578 (f1123–1138) |-0.05–0.35 |-0.10–0.35 |0.00–0.50 |
| later rise at20s |19.757156–19.907167 (f1186–1195) |19.807233–20.057067 (f1189–1204) |19.957133–20.223756 (f1198–1213) |-0.10–0.30 |-0.10–0.45 |0.00–0.50 |
| later lower at20s |20.273756–20.456944 (f1216–1227) |20.373644–20.606844 (f1222–1236) |20.473600–20.706778 (f1228–1242) |-0.10–0.35 |-0.15–0.35 |0.00–0.45 |

Every usable C→R interval includes zero. Their overlapping uncertainty prevents a positive minimum upstream delay claim or a numerical ranking against R→S. Some C→S intervals exclude zero, supporting the visibly delayed final skeleton, without partitioning that delay into upstream and filter contributions.

| Censored event | C enclosure | R/S handling |
| --- | --- | --- |
| earlier rise near6.6s |f391–400,6.513544–6.663444s |Doubled yellow elbow/wrist and green arm at f409 fall inside the unresolved crossing; no ordinary C→R/R→S/C→S sample. |
| earlier lower near7.2s |f424–436,7.063289–7.263156s |Mixed R at f439 and doubled green positions at f439/f445; no ordinary delay sample. |
| earlier lower near9.8s |f577–589,9.612033–9.811900s |Ghost positions at f580/f595 overlap the unresolved R/S crossing; no ordinary delay sample. |

## What is visibly happening

[Same-frame evidence sheet](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2h/same-frame-evidence.jpg):

- f1087,18.108033s: the camera arm is raised, yellow elbow remains near/below its shoulder, and green elbow is farther below.
- f1093,18.207967s: the camera arm has risen farther while R/S retain the lower arm position.
- f1117,18.607811s: the camera arm is descending while R/S retain a higher position.
- f1233,20.556878s: the camera arm is lowered; yellow elbow has begun catching down while the green arm remains higher.

The mismatch reverses with movement direction and catches up during pauses. A fixed mirror or cover-crop displacement is therefore not a sufficient explanation. Yellow and green shoulders/torso broadly follow the person during pauses, while moving elbows/wrists depart from the current camera arm. This is qualitative alignment evidence, not ground-truth joint accuracy. Input age, model prediction, heatmap/ROI behavior and asynchronous camera/overlay presentation are still unresolved contributors to C→R; this video cannot isolate their separate causes.

There is no demonstrated isolated upper-arm/forearm link disappearance around the reviewed legible 11–23 s crossings. Faint/doubled links are not sufficient proof of renderer rejection. Hands/finger shapes are less anatomically convincing, and limbs can leave the visible area during bilateral movement or the final approach to the phone. Those cannot be counted as ordinary confidence-loss events. This capture supplies neither a complete per-link rejection ledger nor a robust held-jitter/settling statistic; no stationary-stability pass is claimed.

## Whole-overlay absence and reason correlation

At **f137, PTS 205,403/90,000 = 2.282256 s**, the full phone preview shows the person and camera image but no green skeleton or diagnostic markers. f136 at 2.265489 s and f138 at 2.298911 s show the overlay. This is **one externally sampled blank frame**, surrounded by visible-overlay observations 33.422 ms apart. Those PTS delimit recorded observations, not actual screen onset/recovery. The second-camera exposure/readout and display scan are not synchronized; actual display blank duration remains unmeasured. No 16.7 ms minimum or 33.422 ms maximum is asserted.

No other candidate whole-overlay blank was found in the all-frame upper-body screening. This is a candidate screen plus visual verification, not a display-present fence or an exhaustive per-link inventory. In particular, the later logical freshness clear did not produce an externally observed whole blank in the reviewed neighboring frames.

| Matching-session logical clear | Expired nonempty pose age | Return to logical `pose` | Approximate video time |
| --- | --- | --- | --- |
| route43.417925s |257.161ms |13.408ms later |2.21s |
| route43.519751s |264.543ms |20.010ms later |2.31s |
| route71.817815s |277.094ms |0.509ms later |30.61s |

All three clears are explicit **freshness expiry** of an otherwise nonempty pose. The early external blank is consistent with the paired early freshness clears. Approximate badge synchronization cannot identify exactly which clear produced f137; logical state spans are not displayed blank durations. Because the bounded collector was idle, no CPU-confirmed blank episode ledger exists for this clip.

The retained transitions do not show detector no-person, low landmark pose presence or all-joint renderer rejection within the approximate clip interval. The first no-person transition is at route 74.423885 s, after the clip. Thus freshness is the supported whole-overlay clear family for this session, rather than evidence of prediction disappearance during its repeated arm motion. Per-joint visibility/presence rejection can still affect individual links and must not be inferred absent merely because whole-pose health stayed valid.

## Internal telemetry, kept separate

The complete interior polls from 21:40:55.296 to 21:41:20.296 local cover 25.000 s, approximately route 45–70 s. These are differences of cumulative counters and sum/count-derived means between completion windows, not exact video-event/input cohorts. Rounding of logged cumulative means is retained in the audit. A drawable delivery means at least one accepted joint, not all 33 points or all limb links. First CPU paint is not physical display presentation.

| Metric | Interior result |
| --- | --- |
| Received / processed / delivered drawable / first CPU paint FPS |30.00 /11.16 /11.16 /11.12 |
| Processed / nonempty / drawable deliveries |279 /279 /279 |
| Unique frames first CPU-painted |278 |
| Preprocessing / total native / worker computation mean |35.78 /51.89 /88.36ms |
| Landmark ROI preprocessing / landmark inference |34.35 /49.60ms,279 samples |
| Detector preprocessing / detector inference |22.11 /35.55ms,18 detector samples |
| Detector decode/ROI / landmark post-processing |0.177 /0.496ms, respective stage samples |
| Queue age / UI delivery pose age |16.29 /106.08ms |
| Callback→UI / callback→first CPU paint |106.82 /118.96ms |
| Pose input age at first CPU paint |118.22ms |
| Filter CPU execution |0.099ms; **not filter signal delay** |
| Pending-frame replacements / stale results |472 /0 |
| Empty-pose / detector no-person / low-presence / expiry count in interior |0 /0 /0 /0 |

The three logical clears above occur outside this interior window. Zero interior expiries must not be reported as zero full-clip expiries. Pending replacements are the frozen latest-frame policy, not queued stale inference or an overlay-loss cause. Stage means have different sample populations; they are not added to external C→R/R→S/C→S brackets or used to manufacture a physical latency figure.

## Decision and next action

1. **First visibly mismatching boundary:** C→R already shows repeated discrepancy before temporal filtering. The video does not identify a particular upstream computation bug or prove a positive minimum crossing delay.
2. **Filtering:** refined→filtered remains a verified added contribution from Step 2D and is visible here. Dominance over C→R remains unproved; another beta experiment is not justified by this recording.
3. **Whole-overlay blanks:** explicit logged clears in this clip's approximate session interval are freshness effects. One external blank frame is consistent with the two early clears; no precise per-clear display-duration assignment is available.
4. **Projection/rendering:** the shared transform and direction-dependent catch-up argue against a fixed projection error explaining the lag. This is not a proof of perfect geometric alignment, and partial confidence rejection remains separate.
5. **Next:** profile the remaining landmark ROI preprocessing/sampling on the Xiaomi, then consider one numerically equivalent preprocessing implementation experiment if that profile confirms the hot path. Its measured 34.35 ms per landmark input makes it a concrete optimization target. Keep the sampler's interpolation, YUV conversion/clamping, borders, rotation, normalization and resulting tensors equivalent, with current model/filter/cadence/freshness/backpressure settings untouched. Benchmark the implementation and tensor agreement before asking for another physical recording. This is a computation/input-age experiment, not a claim that preprocessing is the dominant cause of the observed C→R mismatch. No candidate is implemented in Step 2H.

Step 2 quality acceptance **has not passed**: moving-arm anatomical response remains visibly late, held stability is not established by this brief-pause clip, and upstream causes cannot yet be ranked. Step 3/RepFSM/scoring/audio/upload/Firebase acceptance remain deferred.

## Preserved local evidence and verification

- [Exact PTS and reviewed events](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2h/reviewed-events.json), including all nine scored and three censored rows.
- [Same-session scalar audit](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2h/session-telemetry-audit.json); retained log SHA `1143272201326be8777675bebc655dff886b4b09790ff7ed730ff80629cd2af0`.
- [Source/copy and analysis integrity manifest](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2h/analysis-manifest.json), frame sheets, original analysis copy, independent review notes and installed-APK observation in the same ignored evidence directory.

Analysis verification checked original/copy hashes, 1,870 strictly increasing source PTS entries, 1,870 sequential arm crops, all selected frame-to-PTS joins, direct interval arithmetic and outward rounding. Independent review challenged narrower early brackets and those crossings were censored. No product code changed; mobile tests/Flutter analysis are not rerun for an evidence-only report. Earlier verified Step 2G test results are retained in its report, not relabeled as new verification.
