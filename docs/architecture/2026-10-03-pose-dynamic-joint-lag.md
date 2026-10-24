# Step 2D: dynamic joint-lag isolation

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Status updated 2026-10-05: **still, slow, fast, bottom hold and top hold** captures collected and analyzed on Xiaomi 23013RK75C. The first directly verified added post-inference lag is **refined image landmarks → One Euro filtered landmarks**. Fast motion confirms delay without freshness resets. Numerical mirror/cover/painter binding closes correctly; confidence rejection and freshness expiry separately remove links/whole poses. Raw prediction relative to the displayed camera remains unmeasured. No tuning or Step 3 implementation; Step 2 quality acceptance remains **not passed**.

## Preserved baseline and installed diagnostic build

The optimized Step 2C profile APK remains at `apps/mobile/build/pose-quality/step2c-preprocessing-profile.apk`, SHA-256 `bce7c611c493747dc3a8731c76508310c324aa1aae90c2393937c2afd5d318b4`. Its computation baseline and external video comparison remain in [Step 2C physical comparison](2026-10-03-pose-step2c-physical-comparison.md). Do not reinterpret callback-to-paint as exposure-to-display or add it to external gesture timing.

Step 2D diagnostic APK: `apps/mobile/build/pose-quality/step2d-joint-lag-profile.apk`, 147132798 bytes, SHA-256 `6a3cb0371a29279f5af837a88154cce850a269e1ea7bcb376d89e73d99e9aa2f`. Installed by ADB on Xiaomi 23013RK75C, serial xiaomi-device-serial-redacted, 2026-10-03 18:43:46 local. Freshly force-stopped/launched PID 30503. Installed `base.apk` was pulled and independently rehashed to the same value. Profile defines: `BACKEND=mock`, `GAINPATH_POSE_PREVIEW=true`, `GAINPATH_POSE_QUALITY_DEBUG=true`, `GAINPATH_POSE_JOINT_LAG_DEBUG=true`.

Detector and landmark assets were independently read from both APK ZIPs and remain byte-identical:

- Detector: `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c`.
- Landmark full: `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f`.

Model version remains `mediapipe-full-e9a5c5cb-det-9ba9dd3d`. Optimized geometry source SHA-256 remains `1bf8e9011900202436f3dd2a0c562a33dff0e6834a0c303ce262d6c4a0ba040c`.

No changes to model/tensor contracts, detector/landmark thresholds, cadence, two interpreter threads, One Euro minCutoff 1 / beta 0.3, 250 ms freshness, 100 ms watchdog interval, one-active/one-pending scheduling, camera resolution or projection/mirroring mathematics. The existing watchdog tick additionally checks the diagnostic capture deadline; its pose-expiry decision is unchanged. Debug controls reduce the viewport's available height; the actual resulting cover transform is recorded rather than assuming the Step 2C viewport size.

## Observation boundaries and coordinate spaces

Both shoulders, elbows and wrists are joined by exact `capturedAtMicros` across worker trace, refined frame, filtered frame and painter. A mismatch is rejected and counted. A single pending frame and at most 300 unique painted frames are retained in RAM during each 20-second phase. Completion emits aggregate statistics, at most twelve crossings per joint/space/direction, and **at most four representative frames** (first, midpoint, largest aggregate arm displacement, last). The trajectory is then cleared. Pause, failure, geometry invalidation and close clear the collector. The existing preview timer ends the capture if camera deliveries stall.

No camera frames, video or continuous landmark stream are saved/uploaded. Periodic joint-coordinate output from both quality and rendering loggers is suppressed in this diagnostic build. Fixed representative samples are bounded development evidence, not workout activity. Synthetic replay fixtures contain invented coordinate trajectories only and reside in mobile test scope.

| Field | Coordinate space / meaning |
| --- | --- |
| `rawModel.modelPixels` | Unrefined landmark tensor XYZ, landmark ROI pixel scale 256; Z is model depth, not metres |
| `rawModel.roiNormalized` | The same unrefined tensor XYZ divided by 256 |
| `rawModel.confidenceLogits` | Raw visibility and presence logits |
| `rawModel.unrefinedImagePixels` | Raw XY inverse-projected through the exact inference ROI into upright, unmirrored image pixels |
| `refinedImageNormalized` / `refinedImagePixels` | Heatmap-refined, inverse-ROI-projected coordinate actually supplied to the filter; normalized upright unmirrored XYZ / XY image pixels |
| `filteredImageNormalized` / `filteredImagePixels` | Current production One Euro output for the same input timestamp |
| `previewPixels` | Actual coordinate returned by the painter's existing mirror/cover projection; rejected joints have projected candidates with `accepted=false` |
| `viewportPixels` | Painter coordinate passed through the outer camera-and-painter FittedBox cover scale/offset |
| `visibility`, `presence` | Confidence probabilities retained unchanged through filtering |
| `links` | Actual limb CPU draw issued, endpoint rejected, or connections disabled; a draw call alone does not prove display-visible pixels |

`deltaPixels` is filtered minus refined XY in image pixels. `refinementDisplacementPixels` is refined minus unrefined inverse-projected XY, also in image pixels; never subtract ROI coordinates from image coordinates. `projectionResidualPixels` compares the actual painter return with the exact existing transform applied to the filtered point. Raw model logits and refined confidence are not interchangeable units.

Frame fields record input ownership timestamp, worker-result receipt, UI delivery and CPU painter invocation using the same route clock. Input ownership is **not camera exposure time**; CPU paint is **not display presentation**. Shoulder-level crossings are bracketed by two consecutive input timestamps, separated by at most 250 ms and within one observed freshness filter generation. Rejection, missing joints or invalid coordinates break the crossing sequence. No interpolation or averaging of ambiguous/censored events.

Yellow outline rings show refined coordinates and magenta dots show filtered coordinates using the same pose timestamp and existing transform. Markers bypass confidence gating for inspection; skeleton acceptance remains unchanged. Nonfinite observations are counted separately and excluded from quantitative statistics while actual draw/reject observations are preserved. Collector overhead is reported separately as `jointLagDeliveryMicros`, `jointLagPaintMicros` and existing `diagnosticTraceMicros`.

## Deterministic coordinate replay: host evidence only

`test/support/pose_joint_trajectory.dart` supplies 95 synthetic frames with irregular 90/87/94 ms spacing, slow and fast arm trajectories, bottom/top holds. `test/pose_joint_replay_test.dart` uses the **unchanged production PoseFrameFilter**. It tests stationary equality, directionally trailing motion and hold settling. This removes camera/inference latency for the replay only; it does not reproduce a particular person's model predictions or prove the phone's dominant source.

| Synthetic joint | Slow raise mean displacement | Fast raise mean displacement | Maximum displacement |
| --- | ---: | ---: | ---: |
| Elbow | 27.05 image px | 75.67 image px | 88.07 image px |
| Wrist | 35.16 image px | 96.47 image px | 110.12 image px |

Representative same-space shoulder-level crossing brackets use the actual fixture timestamps:

| Synthetic event | Refined input bracket | Filtered input bracket | Filter response bracket |
| --- | --- | --- | --- |
| Slow elbow raise | 2.987–3.074 s | 3.168–3.258 s | 0.094–0.271 s |
| Slow wrist raise | 3.074–3.168 s | 3.168–3.258 s | 0–0.184 s |
| Slow wrist lower | 5.155–5.242 s | 5.336–5.426 s | 0.094–0.271 s |
| Fast elbow/wrist raise | 7.594–7.681 s | 7.681–7.775 s | 0–0.181 s |

Thus small filter CPU execution time does **not** imply negligible signal delay. The first verified signal-lag stage in this synthetic experiment is refined input → One Euro output. Attribution of the physical phone's dominant dynamic lag remains pending; computation baseline and external P/C/S response are distinct measurements.

## Xiaomi still captures collected on 2026-10-05

The user completed `Capture 20s` before requesting analysis. ADB retrieved two complete still aggregate reports from **PID 18531**, same freshly created route session **1791163512955802**, with an explicit `session_created` record at 09:25:12.955 local. The currently installed APK was independently pulled/rehashed to the original Step 2D hash `6a3cb0371a29279f5af837a88154cce850a269e1ea7bcb376d89e73d99e9aa2f`. Runtime metrics verify the model tensor contract, unchanged model version, front YUV420 720×480 rotated 270° into upright 480×720. No restart, log clearing or capture was performed while retrieving these reports.

The preserved bounded log is `apps/mobile/build/pose-quality/step2d-still-20261005.log`, SHA-256 **`ad7e245dd1f8993a22a5ecedb29f6a37b26fd8d13b7dbe1a0f4df0b1a2445248`**. Parser output and separately calculated telemetry are alongside it. The repeated `still` labels represent **separate captures**, never merged or averaged:

| Capture | Local capture interval | Route-clock start | Reported unique painted frames | Delivered pose outcomes | Timestamp mismatches | Freshness resets |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Still 1 | 09:27:31.199–09:27:51.227, 20.028 s | 138243562 µs | 227 | 226 | 0 | 2 |
| Still 2, latest | 09:28:42.010–09:29:02.064, 20.054 s | 209055142 µs | 222 | 221 | 0 | 1 |

Neither capture reached the 300-frame capacity. All six selected joints are present in every retained observation; no nonfinite coordinates were counted. Both shoulders are accepted throughout. All aggregate painter projection residual maxima are **0 image/canvas pixels**. This confirms the painter binding reproduces the existing filtered-point mirror/cover transform, **not** independent physical calibration of model prediction or inverse ROI.

The original collector counted one capture-start repaint of the previous delivered frame in each capture. The first retained Still 1 input timestamp **138050055 µs precedes its capture start by 193.507 ms**; it is timestamp-matched across stages, but lies outside the labeled phase. The reported frame count is therefore one larger than the phase's delivered outcomes. Aggregate statistics below are preserved exactly as originally calculated; without the full retained trajectory, do not invent corrected percentiles by subtracting a guessed sample. The collector is repaired to clear the pending join at capture start and separately count ignored paints without a new delivery. Pipeline scheduling is unchanged.

### Static refined-to-filtered displacement

Values are **XY image pixels on 480×720**, calculated within matching input frames, for painter-accepted observations. They measure smoothing displacement, not physical latency or anatomical error.

| Joint | Still 1 median / p95 / maximum | Still 2 median / p95 / maximum | Still 2 mean |
| --- | --- | --- | ---: |
| Left elbow | 0.80 / 7.82 / 53.42 px | 1.13 / 10.98 / 42.65 px | 2.84 px |
| Right elbow | 0.85 / 7.33 / 46.48 px | 0.97 / 7.02 / 21.24 px | 1.91 px |
| Left wrist | 0.83 / 11.97 / 30.95 px | 1.17 / 11.49 / 42.35 px | 2.68 px |
| Right wrist | 0.94 / 7.96 / 65.78 px | 1.30 / 19.50 / 40.52 px | 3.78 px |

Typical still displacement is small, while occasional much larger excursions remain. A still instruction is not externally measured zero motion; without the detailed samples or ground truth, these outliers cannot be classified as body motion, model noise, heatmap refinement or filter response. The latest left-elbow raw-inverse-ROI → refined displacement averages **9.05 px**, p95 **9.95 px**; right elbow **3.82 / 12.25 px**, left wrist **5.41 / 7.30 px**, right wrist **2.78 / 7.23 px**. These are spatial refinement measurements and do not imply temporal lag.

### Confidence, actual limb rejection and clipping

| Actual limb | Still 1 draw issued / rejected | Still 2 draw issued / rejected |
| --- | --- | --- |
| Left shoulder → elbow | 227 / 0 | 222 / 0 |
| Left elbow → wrist | 220 / 7, left wrist rejected | 216 / 6, left wrist rejected |
| Right shoulder → elbow | 222 / 5, right elbow rejected | 216 / 6, right elbow rejected |
| Right elbow → wrist | 219 / 8, elbow 5 or wrist 3 | 216 / 6, right elbow rejected |

Latest capture: right elbow visibility falls below 0.5 in **6/222** observations, with no presence rejection. Left wrist presence falls below 0.5 in **6/222**, and visibility in **5/222**; those counts overlap and must not be added. Right wrist is rejected once by visibility; the forearm rejection label names the first rejected endpoint, so it can be masked by simultaneous elbow rejection. These are **per-joint acceptance failures**, distinct from whole-pose health. Thresholds remain unchanged.

Still 2 also contains left elbow **3 off-canvas / 8 off-viewport** observations despite acceptance throughout, and left wrist **5 / 6**; right elbow/wrist remain within bounds. Still 1 has left wrist **6 / 6** and right wrist **11 / 12**. Aggregate counts do not reveal the overlap with confidence rejection. The outer viewport is 411.4286×728, painter 480×720, cover scale 1.011111, offset X −36.952381 and Y 0. Some accepted limb endpoints can therefore be clipped independently of confidence gating. Do not conclude that every issued limb draw was fully visible or that clipping caused all missing links. There is no calibrated video/image alignment evidence in these captures.

### Whole-overlay health and separate computation telemetry

Within each actual 20-second capture, delivered outcomes contain only `pose`; retained health transitions show **no detector-no-person, invalid-ROI, low-pose-presence, stale-result or lifecycle-loss event**. Freshness alone clears nonempty overlays twice in Still 1 and once in Still 2. Those expired input ages are **266.139, 268.929 and 261.877 ms**, exceeding the unchanged 250 ms budget. The subsequent pose events arrive after **12.159, 4.366 and 7.646 ms** of application-clock state change, respectively. These are observed UI-state interruptions, **not measured display-visible blank durations**. Many absence/low-presence transitions elsewhere in the session occur outside these captures and are not attributed to the still task.

Internal telemetry below uses **15-second windows wholly inside** each capture: 09:27:32.956–09:27:47.956 and approximately 09:28:42.956–09:28:57.956. Means are differences of cumulative sums (`count × mean`) and counts, not differences of means. Rates are cumulative-frame differences divided by approximately 15 seconds. Diagnostic completion/logging cost is outside these windows. Rounded log means introduce small numerical uncertainty; this is not a new controlled Step 2C performance comparison.

| Internal metric | Still 1 interior | Still 2 interior |
| --- | ---: | ---: |
| Camera received FPS | 30.00 | 30.00 |
| Processed / delivered / drawable FPS | 11.33 | 11.07 |
| Preprocessing mean | 35.30 ms | 37.05 ms |
| Native inference mean | 50.54 ms | 51.00 ms |
| Worker computation mean | 86.63 ms | 88.76 ms |
| Queue/input age at processing | 16.29 ms | 17.61 ms |
| Callback → UI | 105.15 ms | 108.58 ms |
| Callback → first CPU paint | 115.82 ms | 119.19 ms |
| Filter CPU execution | 0.114 ms | 0.113 ms |
| Diagnostic delivery observation | 0.005 ms | 0.006 ms |
| Diagnostic paint/marker observation | 0.072 ms | 0.089 ms |
| Worker diagnostic trace | 0.049 ms | 0.042 ms |
| Pending replacements | 280 | 284 |
| Empty poses / stale results | 0 / 0 | 0 / 0 |

These ages do not include sensor exposure → callback or CPU paint → display presentation, and do not replace external P/C/S timing. Interior windows omit the two early Still 1 expiries; the phase report remains the authoritative full-capture expiry count.

### Detailed logging failure and bounded repair

All **48** original representative sample lines (four frames × six joints × two captures) are truncated at **1023 message bytes** by Flutter's Android profile log path. Summaries and six per-joint statistics for each capture remain intact. No complete paired raw/refined/filtered/painter sample or dynamic crossing can be recovered from these lines. The profile VM reports an empty retained trajectory and omits the unread `lastReport` field from the compiled collector, so read-only recovery was unsuccessful; the temporary VM forward was removed. Do not present partial JSON as a complete coordinate sample.

Diagnostic output is repaired to split an oversized **existing bounded record** into valid numbered chunks of at most **900 UTF-8 bytes**, with capture-start identity, stage and record index. The number of observed frames/representatives is unchanged. The host parser reconstructs the exact original record, rejects incomplete chunks and separates repeated phase names by capture start. Synthetic regression tests verify the byte limit, exact coordinate reconstruction, missing-chunk rejection and two distinct `still` captures. This fixes evidence transport only; no pose/model/filter/rendering parameter is tuned.

The original still evidence confirms small typical stationary filter displacement, confidence-based partial-link loss, some clipping candidates, and explainable freshness interruptions. It **does not justify filter tuning or identify the dominant dynamic lag**. The required repeat from the repaired build is analyzed below before the slow/fast/hold phases.

The separately preserved repair artifact is `apps/mobile/build/pose-quality/step2d-joint-lag-logging-profile.apk`, 147132798 bytes, SHA-256 **`774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`**, installed on the same Xiaomi at **2026-10-05 09:41:08** local and freshly launched as PID **18535**. Installed APK readback matches that hash. Both packaged TFLite assets match the original Step 2D and Step 2C bytes; geometry source hash remains unchanged. Validation after repair: **138 mobile tests**, **14 shared pose tests**, **3 Python parser regression tests**, both Flutter analyses clean and profile build successful. On-phone verification of complete chunks succeeds in the subsequent PID 18536 capture below.

## Repeated still capture: logging verified on Xiaomi

The user confirmed completion in a new fresh session **1791165407381680**, PID **18536**, created at 09:56:47.381 local. Device-side installed APK SHA-256 is still `774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`. Runtime tensor verification/model version/orientation/resolution remain unchanged. Capture interval **09:57:38.807–09:57:58.851**, route start **51425583 µs**, duration **20.044371 s**.

The preserved bounded source is `apps/mobile/build/pose-quality/step2d-still-repeat-20261005.log`, SHA-256 **`f50a2fdcd75d78b26259fa5c57b7ca30577b9c38695b6448f102dc65e23805b8`**. Reconstructed summary/checks JSON and the local reproducible analysis script are alongside it. No camera images/video or full landmark trajectory were collected.

Transport verification **passes on the phone**: **24 complete joint records**, exactly six selected joints at each of four representative input timestamps; **zero malformed/incomplete chunks**; largest lag-log message **894 UTF-8 bytes**. All frame metadata matches within each representative frame. There are **224 new delivered poses and 224 unique painted observations**, no capacity limit or timestamp mismatches. Five paints without a matching new diagnostic delivery were ignored rather than counted as poses. No implementation changes were needed after this capture.

The first new result uses input **51404295 µs**, 21.288 ms before the button-start timestamp, but is delivered **51507295 µs**, after the capture started. This is an input already in flight at capture start, **not a reused pre-capture delivery**. It is retained and explicitly labeled initial transient. Capturing motion remotely after the person is already in position avoids interpreting preparation/walking as the requested arm trajectory.

### Repeat displacement and rejection

| Joint | Mean / median / p95 / maximum filter displacement | Accepted / observed |
| --- | --- | --- |
| Left elbow | 3.16 / 0.90 / 14.89 / 47.27 image px | 224 / 224 |
| Right elbow | 2.03 / 0.85 / 8.00 / 20.94 image px | 220 / 224 |
| Left wrist | 2.95 / 0.93 / 11.58 / 60.50 image px | 220 / 224 |
| Right wrist | 1.76 / 0.98 / 6.36 / 9.68 image px | 221 / 224 |

Both shoulders accepted throughout. Right elbow is rejected four times by **visibility**; left wrist four times by **presence**; right wrist three times by **visibility**. The actual left upper arm is drawn 224 times, left forearm 220 times (four wrist rejections), right upper arm and forearm 220 times (four elbow rejections). Simultaneously rejected right wrists can be masked by the first rejected endpoint label. Raw visibility/presence logits reproduce the decoded confidence via sigmoid **exactly in all 24 representative samples**, ruling out a confidence-logit/probability unit mismatch in those samples.

Left elbow is outside painter bounds in five observations, outside outer viewport in seven; left wrist four and seven, respectively. Right elbow/wrist have no bound violations. Numerical reconstruction from filtered points agrees with actual mirrored painter and outer cover coordinates to **less than 6×10⁻¹⁴ pixels**. This verifies coordinate units and binding, not model-to-person calibration. Current camera and painter share the cover crop.

### Complete timestamp-matched examples

Midpoint representative input **61395824 µs**: worker receipt **61504602**, UI delivery **61505051**, CPU paint **61513133 µs**. Those are input ages **108.778 / 109.227 / 117.309 ms**, not physical exposure/display timing. All selected joints are accepted, inside both bounds, and all four selected limb links issue draws. The table rounds coordinates only for reading; JSON preserves original precision. ROI coordinates below are **unrefined model pixels**, image columns are upright/unmirrored XY pixels, painter and viewport are mirrored XY pixels.

| Joint | Raw ROI model XYZ | Raw inverse-ROI image XY | Refined image XY | Filtered image XY | Painter XY | Outer viewport XY | Visibility / presence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Left shoulder | 145.91, 70.77, −1.46 | 286.00, 386.58 | 284.32, 387.31 | 284.20, 387.41 | 195.80, 387.41 | 161.02, 391.71 | 0.99995 / 0.99985 |
| Right shoulder | 110.50, 71.37, 4.05 | 212.91, 390.02 | 214.20, 388.80 | 213.92, 388.45 | 266.08, 388.45 | 232.08, 392.76 | 0.99991 / 0.99980 |
| Left elbow | 148.27, 99.88, 1.70 | 292.67, 446.54 | 294.28, 443.52 | 294.13, 443.81 | 185.87, 443.81 | 150.99, 448.75 | 0.96489 / 0.99957 |
| Right elbow | 105.63, 99.48, 6.14 | 204.59, 448.35 | 205.94, 446.54 | 206.07, 446.04 | 273.93, 446.04 | 240.02, 451.00 | 0.95156 / 0.99945 |
| Left wrist | 146.96, 123.65, −34.58 | 291.44, 495.72 | 292.46, 493.16 | 292.51, 493.12 | 187.49, 493.12 | 152.62, 498.60 | 0.97330 / 0.99984 |
| Right wrist | 105.47, 124.21, −30.29 | 205.79, 499.44 | 207.11, 500.80 | 206.85, 500.74 | 273.15, 500.74 | 239.23, 506.31 | 0.94259 / 0.99954 |

Midpoint elbow/wrist filter displacement is **0.33 / 0.51 / 0.07 / 0.27 px** (left elbow/right elbow/left wrist/right wrist); final representative values are **1.21 / 0.80 / 1.10 / 1.81 px**. All those selected joints remain accepted and inside both bounds. The filter is closely settled relative to the refined signal at those two sample times; this does not prove zero body motion or measure anatomical accuracy.

The peak aggregate arm-displacement representative input is **51863254 µs**, only **0.438 s** after capture start; receipt/delivery/paint are **51966192 / 51966374 / 51977096 µs**. Left wrist raw ROI XYZ **153.381, 121.318, −52.878**, raw inverse-ROI XY **467.116, 547.211**, refined XY **448.723, 540.907**, filtered XY **460.897, 600.166**: **60.496 image px** displacement. Visibility/presence **0.857 / 0.910** pass the existing check and the forearm draw issues, but painter XY **19.103, 600.166** becomes viewport XY **−17.637, 606.835**, so the endpoint is cropped. Its refined endpoint is already slightly outside the outer crop; filtering moves it further outside. In the same frame, accepted left elbow refined XY **439.486, 466.887** becomes filtered **462.931, 480.902** (27.314 px), painter **17.069, 480.902**, viewport **−19.693, 486.245**. Its refined viewport X would be approximately **4.01**, so filtering moves that endpoint across the crop boundary.

The first representative left wrist is already out of image bounds **before filtering**, refined XY **517.938, 772.695**, with presence **0.177**, so its rejection begins at model/confidence output rather than painter displacement. Right elbow/wrist visibility **0.343 / 0.366** independently rejects the opposite links in that frame. The large coordinates/confidence changes in early versus midpoint samples are an **initial transient**, not a measured repeated arm-motion event. They can reflect preparation/framing, prediction or tracked ROI behavior; no visual ground truth was captured to distinguish those possibilities. Do not use them as a dynamic filter-delay estimate or remove them silently from statistics.

### Repeat health and separate timings

No dynamic shoulder-level crossings were recorded, as expected for this labeled still phase. Delivered outcomes are all `pose`; there are no detector-no-person, low-presence, stale or lifecycle-invalidated transitions **within the capture**. One nonempty overlay expires at input age **269.889 ms**, returning to pose after **20.293 ms** of app-clock state change. That remains distinct from joint rejection and is not a display-present blank-duration measurement.

The interior **09:57:42.383–09:57:57.383**, approximately 15 seconds, has camera **30.00 FPS**, processed/delivered/drawable **11.27 FPS**, preprocessing **35.77 ms**, native inference **51.00 ms**, worker **87.45 ms**, callback-to-UI **104.76 ms**, callback-to-first-CPU-paint **115.57 ms**. Pending replacements **281**, zero empty poses/stale results. The expiry happens after this interior window. Diagnostic trace/delivery/paint observations average **0.038 / 0.005 / 0.137 ms**; filter CPU cost **0.125 ms**. Means use cumulative sums/count differences as above; neither those CPU costs nor callback ages quantify filter signal delay or physical camera-to-display latency.

The diagnostic transport is now proven and the repeated still phase supports proceeding to **controlled slow arm motion**. It does not establish a dominant dynamic lag source or justify tuning. Parameters remain frozen and Step 2 quality remains unaccepted.

## Controlled motion physical captures

Remote start was attempted only after the user confirmed readiness and GainPath's visible `slow`/`Capture 20s` controls were verified. Xiaomi rejects ADB input injection with `INJECT_EVENTS` permission failure, and no slow-phase start event appeared. No device security setting was changed. Fallback is manual/helper activation; if the person must walk back, an initial approximately three-second still period is requested and those preparation samples must remain labeled separately from controlled motion. No pose parameter or capture duration is changed.

### Slow capture completed

User confirmation `slow done`; PID **18536**, new route session **1791165938849955** explicitly created at 10:05:38.850 local. Do not mix this route clock with the preceding still session. Capture **10:07:42.806–10:08:02.814**, start **123956359 µs**, duration **20.008684 s**. Source `apps/mobile/build/pose-quality/step2d-slow-20261005.log`, SHA-256 **`8cd1896b47526df559bab8a5a1ccfe757643cda6720164caf404f6c931f31a83`**. Summary/checks JSON and reproducible local analysis remain beside it. All models and policies remain frozen.

**187 delivered poses / 187 unique painted observations**, zero timestamp mismatches, no capacity limit, two unmatched diagnostic paints ignored. All **24 bounded representative joint records** reconstruct correctly, no malformed chunks, message maximum 894 bytes. Painter/outer-transform reconstruction residual is below **1.2×10⁻¹³ px**; representative logits reproduce confidence exactly. These checks support correct units/binding. They do not independently verify ROI against a photographed person.

| Joint | Mean / median / p95 / max refined-to-filtered displacement |
| --- | --- |
| Left elbow | 2.25 / 1.02 / 8.13 / 37.68 image px |
| Right elbow | 6.46 / 5.77 / 15.24 / 56.21 image px |
| Left wrist | 2.72 / 0.92 / 6.48 / 70.27 image px |
| Right wrist | 11.43 / 11.48 / 22.53 / 54.22 image px |

The model-right elbow/wrist show the repeated shoulder-level movement. These are anatomical model labels, not an inferred physical side from screen reflection. Right-wrist median displacement increases from **0.98 px in the repeated still phase to 11.48 px** in this slow phase; comparison is descriptive, not a motion-speed-normalized experiment. Initial preparation and 19 freshness resets are retained in the aggregate, so these summaries do not represent uninterrupted steady-state filtering.

#### Timestamp-bracketed wrist response

The same joint crossing its corresponding shoulder in **unmirrored normalized image Y** defines the event independently in refined and filtered spaces. The diagnostic records each crossing only between accepted joints, consecutive samples no more than 250 ms apart, and one filter generation. Same-direction refined/filtered candidates are manually paired in temporal order. Observed freshness-recovery input times have been checked for resets between each paired bracket; none lies between the seven reported pairs. No mean delay or interpolation is introduced. Exact brackets below are **route input timestamps in seconds**, not external-video P/C/S or sensor exposure timestamps.

| Wrist event | Refined input bracket | Filtered input bracket | Added filter-response range |
| --- | --- | --- | --- |
| Raise 1 | 129.867195–129.963352 | 130.088074–130.173134 | 0.125–0.306 s |
| Raise 2 | 133.601096–133.727385 | No recorded filtered crossing | **Censored** |
| Raise 3 | 137.346973–137.463052 | 137.562021–137.669317 | 0.099–0.322 s |
| Raise 4 | 140.897640–140.995546 | 141.134599–141.227093 | 0.139–0.329 s |
| Lower 1 | 130.699299–130.769088 | 130.769088–130.937181 | 0–0.238 s |
| Lower 2 | 134.297061–134.404440 | 134.404440–134.509860 | 0–0.213 s |
| Lower 3 | 137.795361–137.896293 | 137.896293–137.966156 | 0–0.171 s |
| Lower 4 | 141.628779–141.727970 | 141.727970–141.834826 | 0–0.206 s |

Printed delay endpoints are rounded for reading; authoritative microsecond bounds remain in JSON. Raise 1 exact delay is **124.722–305.939 ms**, Raise 3 **98.969–322.344 ms**, Raise 4 **139.053–329.453 ms**. Conservative outward ranges at hundredth-second precision are **0.12–0.31 / 0.09–0.33 / 0.13–0.33 s**. Three raises have strictly positive separation between refined and filtered crossing brackets, directly establishing **A: One Euro adds dynamic signal delay**. Lower brackets share a boundary, so they cannot establish a strictly positive minimum.

Raise 2 has no observable filtered crossing; freshness recovery restarts filtering at input **133911555 µs**, shortly after the refined crossing and midpoint sample. It remains censored rather than assigned a delay or interpolated through the reset. The right elbow has two brief refined above-shoulder crossings but no filtered above-shoulder crossing. That response is also **censored**: short excursion attenuation, reset/sampling and shoulder-relative threshold behavior cannot be separated from the bounded records. No elbow latency number is invented.

#### Moving-frame and preparation examples

Midpoint input **133799478 µs**, receipt **133930078**, delivery **133930264**, paint **133938055 µs**. The paired moving model-right joints are accepted, inside canvas/viewport, and both arm links issue draws:

| Joint | Raw ROI XYZ | Raw inverse-ROI image XY | Refined image XY | Filtered image XY | Painter XY | Outer viewport XY | Visibility / presence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Right elbow | 86.285, 68.619, 7.335 | 177.996, 363.479 | 177.601, 365.950 | 181.282, 373.681 | 298.718, 373.681 | 265.085, 377.833 | 0.99490 / 0.99961 |
| Right wrist | 60.568, 65.729, −9.449 | 120.130, 359.450 | 117.448, 354.557 | 120.664, 368.812 | 359.336, 368.812 | 326.376, 372.909 | 0.98314 / 0.99622 |

The wrist is **14.61 image px** behind the refined coordinate and elbow **8.56 px**, independently of correct projection/binding and high confidence. Their refinement displacements are **5.58 / 2.50 px**, respectively. Depth remains separately recorded in the unrounded JSON and is not converted to a physical length. Input-to-receipt/UI/CPU-paint ages are **130.600 / 130.786 / 138.577 ms**, distinct from filter signal response.

The largest aggregate arm-displacement representative is input **125015420 µs**, only **1.059 s after capture start**. It falls inside the requested initial preparation/hold period, so its wrist **52.09 px** displacement is labeled preparation and is not treated as a controlled slow raise sample. The first new result input **123882876 µs** is in flight before the button start, delivered after it; raw/refined right wrist is already outside the image at **−171.403, 613.473**, visibility/presence **0.228 / 0.050**, so those early missing pixels begin at prediction/confidence and crop, not filter lag. These preparation records remain in original aggregates and are not silently removed.

#### Partial links and whole-overlay interruptions

All shoulders accepted. Right elbow **4/187 rejected by presence**, right wrist **7/187 rejected** (visibility 6, presence 7, overlapping); left wrist **5/187 rejected** (visibility 3, presence 4, overlapping). Actual left upper-arm draws **187**, left forearm **182**; right upper arm **183**, right forearm **180** (four elbow and three wrist rejection labels). Confidence gates explain those link omissions independently of whole-pose health. Right elbow has **6 off-canvas / 6 off-viewport**, right wrist **6 / 8**; early representatives show raw prediction already outside bounds. Body/framing versus prediction/ROI cannot be resolved without visual evidence; no gross mirror/cover mismatch is present in the numerical binding checks.

Every delivered outcome in this capture is `pose`: **no detector-no-person, low-landmark-presence, stale-result or lifecycle loss** during the phase. **19 nonempty-overlay freshness expiries** reset filter history at ages **250.722–322.283 ms**. Subsequent pose-state restoration takes **1.205–70.828 ms** on the application clock. These are actual freshness-policy interruptions, not a generic model-tracking-loss label or display-visible blank duration. Frequent resets prevent treating the whole 20 seconds as a continuous filter trajectory and remain a Step 2 quality failure.

Separate interior telemetry **10:07:43.852–10:07:58.852**, approximately 15 seconds: camera **30.07 FPS**, processed/delivered/drawable **9.47 FPS**, preprocessing **47.26 ms**, native inference **56.52 ms**, worker computation **104.63 ms**, queue age **18.61 ms**, callback-to-UI **125.49 ms**, callback-to-first-CPU-paint **136.99 ms**. Pending replacements **310**, zero empty/stale results, **13** expiries within this interior (19 full-phase). Detector preprocess/inference **29.85 / 45.38 ms**, landmark preprocess/inference **45.37 / 53.64 ms**. Diagnostic trace/delivery/paint **0.049 / 0.006 / 0.093 ms**, filter execution **0.111 ms**. Boundary counts can differ by one worker/paint as periodic lines straddle delivery. A post-run battery snapshot reads **35.9°C, 85%**; it is not a synchronized thermal sample or proof of throttling. Do not claim preprocessing equivalence regressed or change settings from this observational slowdown alone.

**Decision after slow:** the first directly verified added joint-lag stage is **refined pose → One Euro output**, with positive wrist response brackets and accepted moving samples. **B** (raw/refined already trailing current camera image) remains unmeasured; no new video/frame was captured. Numerical checks do not implicate **C** (mirror/cover/painter binding), while confidence rejection, early edge crop and freshness expiry separately explain **D/whole-overlay missing pixels**. Evidence supports considering a single-variable beta experiment after faster/hold evidence, but cannot establish that filtering dominates total physical delay. No tuning has been applied.

### Faster capture completed

User confirmation `fast done`; PID **18536**, another fresh route session **1791166303981884**, created 10:11:43.982 local. Capture **10:11:57.289–10:12:17.368**, route start **13307373 µs**, duration **20.078654 s**. Source `apps/mobile/build/pose-quality/step2d-fast-20261005.log`, SHA-256 **`c40654d76243b180b60e0558bd08482ba14090ddf0d757de4c5b1ae5c89c3520`**. Route clocks from the preceding slow/still sessions must not be compared as one continuous timeline.

**225 new delivered poses / 225 unique painted observations**, no timestamp mismatch/capacity limit, three unmatched diagnostic paints ignored, **zero freshness resets**. All 24 representative records reconstruct correctly without malformed chunks; numeric painter/outer transform residual below 6×10⁻¹⁴ px, logits-to-confidence exact, maximum message 894 bytes. No code/model/threshold/filter/policy changes between the still, slow and fast runs.

| Model joint | Mean / median / p95 / maximum filter displacement |
| --- | --- |
| Left elbow | 2.38 / 1.10 / 9.07 / 25.96 image px |
| Right elbow | 11.01 / 11.17 / 18.76 / 46.72 image px |
| Left wrist | 2.48 / 1.28 / 10.50 / 25.10 image px |
| Right wrist | 20.39 / 21.32 / 34.65 / 67.72 image px |

The moving model-right elbow/wrist medians are greater than slow-run medians **5.77 / 11.48 px**, while the opposite arm remains near 1 px median. This supports movement-dependent filter displacement, but label `fast` does not supply calibrated velocity. Initial preparation samples remain included. Unlike slow motion, the fast run provides uninterrupted freshness history for the accepted crossing pairs, so its filter-delay evidence does not depend on watchdog-reset artifacts.

#### Faster response brackets

Manual same-direction event pairing follows the recorded temporal order, with no interpolation or averaging. The lists are below the twelve-crossing logging cap. The table uses exact input timestamps in seconds and **outward-rounded hundredth-second response ranges**:

| Joint/event | Refined input bracket | Filtered input bracket | Added filter-response range |
| --- | --- | --- | --- |
| Elbow raise 1 | 17.461826–17.557728 | 17.726537–17.823450 | 0.16–0.37 s |
| Elbow raise 2 | 19.759104–19.854967 | 19.993920–20.061497 | 0.13–0.31 s |
| Elbow raises 3–6 | Four additional recorded refined raises | No matching filtered raise | **Censored** |
| Wrist raise 1 | 17.461826–17.557728 | 17.557728–17.662050 | 0–0.21 s |
| Wrist raise 2 | 19.687239–19.759104 | 19.854967–19.993920 | 0.09–0.31 s |
| Wrist raise 3 | 21.927830–22.026129 | 22.125171–22.193271 | 0.09–0.27 s |
| Wrist raise 4 | 23.955449–24.020308 | 24.118674–24.185987 | 0.09–0.24 s |
| Wrist raise 5 | 25.985748–26.084229 | 26.152070–26.220736 | 0.06–0.24 s |
| Wrist raise 6 | 27.953653–28.034032 | 28.186927–28.282148 | 0.15–0.33 s |
| Wrist raise 7 | 30.083407–30.189758 | No matching filtered raise/lower | **Censored** |
| Wrist raise 8 | 31.823528–31.949198 | 32.035420–32.117148 | 0.08–0.30 s |

Exact elbow response bounds **168.809–361.624 / 138.953–302.393 ms** and six wrist raises with positive lower bounds confirm added temporal signal delay at **refined → One Euro output**, after the initial three-second preparation period. Wrist raise 1 shares a bracket boundary, so it does not prove a positive minimum. This is filter response on the input timeline, not physical-person-to-overlay latency.

Only the first two elbow excursions cross shoulder level in the filtered signal; the remaining four refined above-shoulder excursions have no filtered crossing. Wrist excursion 7 is also unobserved in the filtered crossing list. With no freshness resets, brief-peak attenuation by smoothing is a plausible contributor; acceptance gaps and sampled shoulder-relative geometry cannot be ruled out from four snapshots. These remain censored rather than infinite or averaged latency. Lower crossings mostly share/overlap input brackets; elbow lower 2 bounds **−0.092–0.092 s**, wrist lower 3 **−0.080–0.080 s**, wrist lower 5 **−0.168–0.168 s** are ambiguous, not negative causal delay. Other observed descents have zero lower bounds and upper bounds about 0.165–0.172 s. Missing descents are not interpolated.

#### Faster representative coordinates and rejection

Midpoint input **23219327 µs**, receipt/UI/paint **23335078 / 23335263 / 23343179 µs** (input ages **115.751 / 115.936 / 123.852 ms**). Both moving joints are high-confidence, accepted, inside canvas/viewport and connected by issued arm draws:

| Joint | Raw ROI XYZ | Raw inverse-ROI image XY | Refined image XY | Filtered image XY | Painter XY | Outer viewport XY | Visibility / presence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Right elbow | 106.476, 105.838, −12.328 | 230.640, 433.327 | 234.547, 428.831 | 230.054, 426.173 | 249.946, 426.173 | 215.770, 430.909 | 0.98327 / 0.99969 |
| Right wrist | 104.503, 131.326, −32.130 | 227.413, 485.186 | 227.201, 483.938 | 217.882, 478.740 | 262.118, 478.740 | 228.078, 484.060 | 0.97809 / 0.99972 |

The filter displacements are **5.22 / 10.67 px**, refinement displacements **5.96 / 1.26 px**. Final representative input **33124603 µs** uses a **detector-derived ROI**, with accepted in-bounds elbow/wrist filter displacement **5.12 / 11.53 px**; its input-to-CPU-paint age **188.941 ms** is separately observed, not appended to response brackets.

The peak representative input **14321699 µs** is only **1.014 s after capture start**, within preparation. Its elbow/wrist displacements **46.72 / 67.72 px** are documented but not treated as the requested controlled fast event. The first representative already has negative raw inverse-ROI image X and low wrist/elbow visibility, before filtering. Initial repositioning remains a confound for maxima and confidence/clipping aggregates.

Actual link draws: left upper arm **221/225**, left forearm **217/225** (four elbow/four wrist rejection labels); right upper arm **219/225**, right forearm **215/225** (six elbow/four wrist labels). Right elbow rejects six times (visibility 5, presence 2, overlapping), right wrist ten times (visibility 7, presence 8, overlapping). Left elbow presence rejection four; left wrist rejection eight (visibility 6, presence 8). Right elbow **7 off-canvas / 9 off-viewport**, right wrist **12 / 12**; aggregate overlap with rejected joints is not inferable. Both recorded controlled-event examples above pass confidence and transform checks, so their displacement is not renderer rejection.

No detector-no-person, low-pose-presence, stale-result, lifecycle loss or freshness expiry during this 20-second capture. The interior **10:11:58.982–10:12:13.982**, approximately 15 seconds, gives camera **30.00 FPS**, processed/delivered/drawable **11.33 FPS**, preprocessing **36.17 ms**, native **50.14 ms**, worker **87.02 ms**, callback-to-UI **105.48 ms**, callback-to-first-CPU-paint **115.66 ms**, pending replacements **280**, zero empty/stale/expiry results. Diagnostic trace/delivery/paint **0.043 / 0.006 / 0.081 ms**, filter CPU execution **0.120 ms**. The slowdown/expiry increase in the separate slow session is therefore not consistently present; its cause remains unproven. No tuning of freshness, threads, cadence or resolution is justified by simply merging these runs.

**Decision after fast:** filtering is a reproducibly lagging post-inference stage even without freshness resets; pure CPU execution time is not a proxy for its temporal response. This is sufficient to justify a later isolated beta experiment, but it is not proof that raw prediction/input age contributes no delay or that Step 2 quality has passed. At that point, hold settling and the visual refined-vs-filtered marker observation remained pending; the subsequent results are below.

### Bottom hold completed

User confirmation `bottom done`; PID **18536**, fresh route session **1791166532085763**, created 10:15:32.085 local. Capture **10:16:21.931–10:16:41.954**, start **49846161 µs**, duration **20.022666 s**. Source `apps/mobile/build/pose-quality/step2d-bottom-20261005.log`, SHA-256 **`e61b1793210b1a3dcff3e3921fb1896f2d20216378a42d5bbf1f9c3f28d04c06`**. An additional `still@6183349` report is preserved in this file, but was not the user-confirmed bottom phase and is not merged with the designated repeated-still baseline.

**194 poses/unique painted observations**, no timestamp mismatch/capacity limit, four unmatched paints ignored. All 24 fixed representatives reconstruct; confidence and frame-metadata joins match exactly, painter/viewport residual below 6×10⁻¹⁴ px. No shoulder-level crossings. Mean/median/p95/max refined-to-filtered displacement in image px:

| Joint | Bottom hold displacement |
| --- | --- |
| Left elbow | 1.64 / 0.53 / 4.65 / 47.11 |
| Right elbow | 1.79 / 0.63 / 4.99 / 40.50 |
| Left wrist | 2.70 / 0.69 / 6.67 / 81.90 |
| Right wrist | 1.97 / 0.71 / 5.07 / 74.23 |

Midpoint input **59514105 µs**, receipt/delivery/paint **59664596 / 59664802 / 59683317 µs**. Both right arm joints accepted, in view, links issued: elbow refined **190.771,428.004** → filtered **190.847,428.404** → painter **289.153,428.404** → viewport **255.414,433.164**; wrist refined **174.790,483.072** → filtered **174.861,482.554** → painter **305.139,482.554** → viewport **271.577,487.916**. Elbow/wrist filter displacement **0.41 / 0.52 px**, visibility **0.98755 / 0.98297**, presence **0.99973 / 0.99956**. Final input **69642295 µs** gives **0.89 / 0.87 px**. These snapshots support closeness during the hold, not a fitted settling time: midpoint/final generations **11/14** differ because of expiry resets.

Peak representative input **50422189 µs**, only **0.576 s after start**, is preparation, with elbow/wrist **40.50 / 74.23 px** filter displacement. The first input is in flight before capture start and already has low presence/off-image wrist coordinates before filtering. Maxima remain in aggregates and are not interpreted as steady-state noise.

All delivered outcomes are `pose`, with **seven nonempty freshness expiries**, ages **265.407–282.818 ms**, application state-clear-to-restoration gaps **10.806–48.999 ms**. No detector-no-person, low whole-pose presence, stale result or lifecycle invalidation in phase. Right elbow rejects twice by presence; right wrist five times (visibility 3/presence 5, overlapping). Right upper/forearm draws **192/189 out of 194**. Left elbow five rejects, left wrist two; left upper/forearm draws **189/189**. Whole-pose expiry and partial confidence rejection are independent findings.

Separate interior telemetry **10:16:22.085–10:16:37.085**: camera **30.00 FPS**, processed/delivered **9.73 FPS**, preprocessing **44.96 ms**, native **55.26 ms**, worker **100.98 ms**, callback-to-UI **122.48 ms**, callback-to-first-CPU-paint **134.72 ms**, **304** pending replacements, zero empty/stale, **six** interior expiries (seven full-phase). Trace/delivery/paint diagnostic CPU **0.047 / 0.006 / 0.064 ms**. Do not equate state-clear intervals with physical display blanks.

### Top hold completed

User confirmation `top done`; PID **18536**, fresh route session **1791166721318987**, created 10:18:41.319. Capture **10:18:47.327–10:19:07.383**, start **6008022 µs**, duration **20.056578 s**. Source `apps/mobile/build/pose-quality/step2d-top-20261005.log`, SHA-256 **`acbeb99dd5881cb569b6c75df7d7a38f97bbbaf0bba7b175d817d1def1a38dd3`**.

**233 poses/unique painted observations**, no timestamp mismatch/capacity limit, one unmatched paint ignored; 24 complete representatives, maximum message 894 bytes, confidence exact, metadata matched, maximum painter/viewport residual **1.2×10⁻¹³ px**. Mean/median/p95/max displacement in image px:

| Joint | Top hold displacement |
| --- | --- |
| Left elbow | 2.36 / 0.68 / 12.02 / 66.29 |
| Right elbow | 3.17 / 0.84 / 15.31 / 53.85 |
| Left wrist | 2.17 / 0.88 / 12.11 / 33.40 |
| Right wrist | 4.51 / 0.87 / 27.44 / 107.71 |

One accepted above-shoulder raise is observed after the three-second preparation period. Elbow refined input bracket **9.417843–9.514748 s**, filtered **9.588365–9.654707 s**: added response **73.617–236.864 ms**, conservatively **0.07–0.24 s**. Wrist refined **9.350015–9.417843 s**, filtered **9.514748–9.588365 s**: **96.905–238.350 ms**, conservatively **0.09–0.24 s**. No expiry reset lies between either paired bracket. These are input-clock filter response bounds, not physical camera/display measurements. No lower crossing is recorded, and final representative coordinates remain above shoulder level: the requested final lowering is **not evidenced** and supplies no recovery/descent sample.

Midpoint input **15879883 µs**, receipt/delivery/paint **15990614 / 15990760 / 15996427 µs**; all three model-right joints accepted, inside canvas/viewport, both arm links issued. Raw ROI XYZ uses model pixel units; all other XY below are image/painter/viewport pixels, with each transform applied explicitly:

| Joint | Raw ROI XYZ | Unrefined inverse-ROI XY | Refined image XY | Filtered image XY | Painter XY | Viewport XY | Visibility / presence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Shoulder | 109.969,68.813,−34.074 | 234.692,364.495 | 233.820,360.446 | 233.961,360.064 | 246.039,360.064 | 211.820,364.065 | 0.99930 / 0.99910 |
| Elbow | 88.262,60.444,−34.452 | 190.535,349.216 | 190.600,350.688 | 189.509,349.629 | 290.491,349.629 | 256.766,353.513 | 0.99586 / 0.99932 |
| Wrist | 66.537,43.371,−64.452 | 145.734,316.465 | 145.667,316.167 | 144.697,315.241 | 335.303,315.241 | 302.076,318.743 | 0.98558 / 0.99642 |

Held elbow/wrist displacement **1.52 / 1.34 px**; final input **25881469 µs** gives **0.42 / 0.26 px**. Midpoint/final generations **2/3** differ after expiry; these are settling observations, not uninterrupted response curves or a precise settling time. Peak representative **6656898 µs**, only **0.649 s after start**, belongs to preparation. The first representative uses detector ROI and contains a rejected/off-image wrist before filtering. Controlled midpoint/final use tracked ROI and high confidence; no numerical binding error appears.

Two nonempty freshness expiries occur at ages **253.843 / 252.932 ms**, with application state-clear gaps **3.759 / 9.199 ms**. All delivered outcomes are `pose`; no empty/no-person/low whole-pose-presence, stale or lifecycle loss in phase. Right elbow accepted **233/233**, right wrist **228/233** (visibility 1/presence 5, overlapping); right upper/forearm draw **233/228**. Left elbow seven rejects (visibility 6/presence 6), left wrist eight (visibility 8/presence 7); left upper/forearm draw **226/225**. Rejection labels on links count the first rejected endpoint, so joint counts need not sum to edge rejections.

Separate interior **10:18:51.319–10:19:06.319**: camera **30.00 FPS**, processed/delivered/drawable **11.67 FPS**, preprocessing **34.76 ms**, native **49.06 ms**, worker **84.44 ms**, callback-to-UI **103.42 ms**, callback-to-first-CPU-paint **113.95 ms**, **276** pending replacements, zero empty/stale, two expiries. Diagnostic trace/delivery/paint CPU **0.041 / 0.005 / 0.074 ms**; filter CPU **0.101 ms**. No timing is added to external P/C/S or input-clock response bounds.

## Evidence-led conclusion and next experiment

**A — verified.** The first directly verified lagging post-inference stage is refined image coordinates → production One Euro coordinates. Slow raises, fast raises with no freshness resets, and the top raise all have strictly separated refined/filtered crossing brackets. Moving right elbow/wrist median displacements rise from about **0.85 / 0.98 px** in repeated still to **5.77 / 11.48 px** in slow and **11.17 / 21.32 px** in fast. Held medians return below 1 px. CPU filter execution near 0.1 ms does not describe this temporal delay.

**Visual cross-check:** after the captures, the user reported **“Yellow rings moved sooner; magenta dots trailed.”** This corroborates the measured refined-to-filtered separation. It is a qualitative observation, not a timestamped measurement of raw-prediction accuracy or total physical lag.

**B — unresolved.** Bounded landmark records contain no synchronized camera-image ground truth. They cannot determine whether raw/refined prediction already trails the displayed camera arm, nor isolate input age from ROI/prediction error. Retained Step 2C external video remains separate evidence. Do not claim filtering dominates all physical-person-to-display latency.

**C — no material numerical contribution demonstrated.** Same-timestamp model confidence, image-to-painter mirror, outer cover/crop and binding close within floating-point roundoff across representatives. This rules out a gross coordinate-unit/binding mismatch in those observations, but is not proof of anatomical prediction accuracy. Initial predictions outside image bounds and legitimate cover cropping can remove pixels independently.

**D — verified separate failures.** Partial links are explicitly rejected by per-joint visibility/presence, even while whole-pose inference returns 33 landmarks. Nonempty freshness expiries independently clear overlays/reset filter history: repeated still **1**, slow **19**, fast **0**, bottom **7**, top **2**. These are application freshness transitions, not model no-person results or measured display blank lengths. No phase returned zero landmarks as its delivered outcome. Confidence rejection, expiry and initial repositioning cannot be folded into one generic tracking-lost cause.

The dominant **verified added post-inference** contribution is temporal filtering; total physical delay and prediction accuracy remain partly unisolated. Step 2 quality acceptance remains **not passed**: visible moving-arm lag, partial link instability and variable nonempty-overlay expiry persist. Step 3 stays deferred.

The evidence now justifies the smallest next **single-variable tuning experiment**: **One Euro beta 0.3 → 0.6 only**, keeping minCutoff 1, derivative cutoff, model/assets/contracts, confidence thresholds, camera resolution, cadence, interpreter threads, projection, 250 ms freshness, watchdog and latest-frame scheduling unchanged. Increasing beta is intended to increase responsiveness during motion; it is not assumed to fix prediction, confidence or expiry. **This experiment is proposed, not implemented.**

Before/after should use the same labeled phases/framing and conservative accepted-crossing brackets, report censored excursions separately, compare static/held jitter and wrist/elbow displacement, count per-joint/link rejection and whole-overlay expiry, and repeat the matched external recording for physical P/C/S. A result requires improved motion response without materially worse static stability or lost tracking. Do not pool across route clocks or treat preparation maxima as controlled movement. Stop or revert the experiment if the measured benefit is absent; other variables require their own evidence-led pass.

## Physical close / lifecycle check

The top-hold route emitted `lifecycle_closed` at **10:21:32.390**, matching the camera-service disconnect at **10:21:32**. A later separately reopened preview (session **1791167185759701**) was not one of the five controlled phases; its quality counters are not mixed into motion/hold evidence. Following the final End preview request it emitted `lifecycle_closed` at **10:27:16.201**, camera service disconnected at **10:27:16**, and the subsequent `dumpsys media.camera` summary showed **Active Camera Clients: []**. Preserved bounded event/summary artifacts are `step2d-lifecycle-cleanup-20261005.log` and `step2d-camera-cleanup-20261005.txt` in the ignored evidence directory.

This verifies physical camera release and route invalidation on close. Controller teardown clears the collector, cancels its existing timer, invalidates the camera, drains active work and closes the detector; host lifecycle tests cover that ordering. Interpreter native-memory reclamation is not directly measured on the phone. No new lifecycle failure is demonstrated by these captures; paused/background/logout behavior was not physically repeated in this phase and remains covered by prior Step 2B evidence and controller tests.

## Verification

Fresh host validation after the bounded logging repair: **138 mobile tests**, **14 pose-package tests**, both Flutter analyses clean, profile APK built, `git diff --check` clean. Tests exercise timestamp mismatch, exact mirror/cover mapping, actual painter link acceptance/rejection, bounded retention, duplicate repaint suppression, disabled/lifecycle clearing, stalled capture deadline and nonfinite statistics. New collector tests were observed failing before their corresponding implementation; review findings were corrected without changing rendering acceptance or pipeline policies.

Detailed build/test logs and bounded phone report artifacts belong in ignored `apps/mobile/build/pose-quality/`. `apps/mobile/tool/analyze_pose_joint_lag.py` parses the bounded report; crossing matches remain explicitly manual and censored events are not normal averaged samples. No workout activity, Firebase write or Step 3 wiring is introduced.

Final post-capture verification (2026-10-05): **22 affected mobile tests with quality/lag diagnostics enabled**, **14 shared pose tests**, **three bounded-report parser tests**, mobile and shared-pose analyses clean, `git diff --check` clean. The default-define focused run also passed 19 tests with three diagnostic tests explicitly skipped; the enabled run executed all 22 without skips. All five designated captures independently pass fixed-sample reconstruction, timestamp metadata, sigmoid confidence, displacement and mirror/cover checks. No production tuning change was made during collection or analysis.
