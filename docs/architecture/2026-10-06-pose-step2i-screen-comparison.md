# Step 2I — paired screen-video comparison

## Result

The user's impression that the recordings look similar is supported: **there is no demonstrated meaningful reduction in visible moving-arm lag**. Conservative C→R and C→S enclosures overlap substantially. Several elbow peaks only approach/graze the shoulder plane; they cannot be treated as precise, guaranteed crossings. This is an inconclusive visible-speed comparison, not proof of identical latency.

The computation improvement remains real in the separately measured phone telemetry. This pair also contains two externally sampled whole-overlay blanks in the control and none found in the candidate screening. That is favorable evidence for this pair, not a general tracking-reliability acceptance.

Retain Step 2I as the computation baseline, with the control preserved. **Step 2 quality acceptance remains pending; Step 3 remains deferred.** No app code, model, pose parameter, camera setting or APK installation was changed during this analysis.

## Originals, timestamps and attribution

Analysis date: 2026-10-06, Asia/Kuala_Lumpur. Supplied originals:

- `C:/Users/Ngzhe/Downloads/step2i_control_screen.mp4`
- `C:/Users/Ngzhe/Downloads/step2i_candidate_screen.mp4`

Originals remain unchanged. Byte-identical analysis copies and derivatives are under the ignored local directory `apps/mobile/build/pose-quality/step2i-screen/`.

| Property | Control | Candidate |
|---|---|---|
| SHA-256 | `72a76ca6de8eb25fc4f2716e136477e119879f3d1db35ed4a32bd2b09bba9941` | `be90e56b3d67293b2f830dc9ad344b9513c45598c714d65cbf7e507636a2a4d8` |
| Bytes | 368,130,457 | 319,652,777 |
| Decoded frames, zero-based indexing | 2,784 | 2,416 |
| Presentation time base | 1/90,000 s | 1/90,000 s |
| First / last PTS ticks | 0 / 4,186,787 | 0 / 3,636,717 |
| Last presentation timestamp | 46.519856 s | 40.407967 s |
| Container duration | 46.54 s | 40.42 s |
| PTS-derived rate | 59.8239 FPS | 59.7654 FPS |
| Adjacent PTS spacing | 8.311–49.989 ms | 8.356–33.422 ms |
| Intervals longer than 25 ms | 8 | 11 |
| Video-matched preview session | `1791249521163686` | `1791249633414209` |
| Session creation, local phone log time | 09:18:41.164 approximately | 09:20:33.414 approximately |

Both originals are HEVC Main 3840×2160, with −90° display rotation (upright 2160×3840), recorded by a Xiaomi 17 / `25113PN0EG`, Android 16. Metadata says 60 FPS. The candidate's FFmpeg nominal `tbr` is 120, but its actual decoded PTS-derived rate is approximately 59.77 FPS. Neither nominal `tbr` nor `frame / 60` was used for measurement.

FFmpeg 7.1 decoded presentation order. `showinfo` ran before selection, with passthrough output and no frame-rate conversion. All PTS were verified strictly increasing. Source frame number maps exactly to each saved crop. Decimal PTS labels identify frames; they do not imply equally precise motion-event timing.

The user confirmed installing the two preserved APKs separately. The screen badges match the scalar-log sessions: control `F163686`, candidate `F414209`. The currently installed candidate was independently checked through ADB and matches SHA-256 `747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4`. The preserved control SHA-256 is `9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07`.

These observations support build attribution, but a current APK hash and a screen badge are not retrospective binary timestamp attestations. The badge itself does not encode an APK hash or filter parameters. Source/APK isolation evidence remains in the [sampler optimization report](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-05-pose-sampler-clamp-optimization.md): only the finite channel-clamp implementation changed; 309 APK entries outside signatures/compiled Dart were identical.

Both matched sessions report model version `mediapipe-full-e9a5c5cb-det-9ba9dd3d`, verified runtime tensor contracts, front-camera YUV420 720×480, 270° rotation and compatible preview aspect. Beta remains 0.3, minCutoff/derivative cutoff 1, interpreter threads 2. Model/contracts/thresholds, detector/ROI cadence, resolution, mirror/projection/cover crop, 250 ms freshness, watchdog and backpressure remain as in the preserved builds.

## Observable boundary and uncertainty

- **C:** image-right elbow/upper-arm motion in the displayed camera preview, approximately at its own shoulder level, relative to the local torso and tilted phone screen.
- **R:** yellow refined elbow ring, after heatmap refinement and inverse-ROI projection, before temporal filtering.
- **S:** accepted green elbow/upper-arm segment, after filtering and the existing preview transform. A magenta dot alone does not establish green-link acceptance.

There is no observable physical person outside the displayed camera image. **No physical→preview, physical→skeleton or total physical camera-to-display latency is inferred.** The raw model tensor is also not visible in this footage.

The same approximate shoulder-level event definition used in Step 2H is retained; wrist crossings are not substituted. Review included all-frame upper-body color screening for whole-overlay gaps, coarse full-preview sheets, fine motion sheets, native crops and full-preview gap neighbors. Crossing samples are representative, not an exhaustive census of every cycle or limb link.

Sleeve coverage, uncertain camera-image joint center, shoulder shrug, phone perspective, near-plane elbow maxima, stepped pose updates, motion blur, doubled markers and display/exposure blending widen the enclosures. Several peaks show the wrist above the shoulder while the elbow stays close to the plane. A clean wrist crossing must not be relabeled as a clean elbow crossing.

The eight rows below are **conditional shoulder-level-zone enclosures**, with strict side-to-side crossing uncertain. They preserve possible passage times; they are not eight ordinary uncensored delay measurements. No means, pooled samples, significance test or percentage visible speedup is calculated from them. Broad enclosures and fully censored events cannot establish a precise numerical ranking of upstream delay versus filter delay.

For C=[c0,c1], R=[r0,r1], S=[s0,s1], calculate directly C→R=[r0−c1,r1−c0], R→S=[s0−r1,s1−r0], C→S=[s0−c1,s1−c0]. Display ranges round outward to 0.05 s. Negative bounds represent overlapping uncertain crossing zones, not anticipation. R→S and C→R are never added to internal telemetry to manufacture a latency figure.

## Representative conditional enclosures

Earlier cycles are relatively slower; later cycles are relatively faster. The phase selector remained `still`, and Capture 20s remained idle. These are visually classified sections, not timer-labeled slow/fast diagnostic captures. `B0 visible none` from an inactive bounded collector does not prove absence of clears.

| Clip/event (conditional zone) | C PTS s (frame) | R PTS s (frame) | S PTS s (frame) | C→R s | R→S s | C→S s |
|---|---|---|---|---|---|---|
| Control earlier raise | 5.580867–5.913978 (f331–351) | 5.780733–6.313633 (f343–375) | 5.913978–6.380300 (f351–379) | −0.15–0.75 | −0.40–0.60 | 0.00–0.80 |
| Control earlier lower | 6.380300–6.782089 (f379–403) | 6.446967–6.915300 (f383–411) | 6.513800–6.981922 (f387–415) | −0.35–0.55 | −0.45–0.55 | −0.30–0.65 |
| Candidate earlier second raise | 7.999067–8.432233 (f479–504) | 8.165622–8.682111 (f489–519) | 8.332178–8.765389 (f499–524) | −0.30–0.70 | −0.35–0.60 | −0.15–0.80 |
| Candidate earlier second lower | 8.598900–8.930300 (f514–534) | 8.682111–9.013578 (f519–539) | 8.765389–9.181844 (f524–549) | −0.25–0.45 | −0.25–0.50 | −0.20–0.60 |
| Control later raise | 24.561644–24.894844 (f1468–1488) | 24.761644–25.327333 (f1480–1514) | 24.894844–25.393956 (f1488–1518) | −0.15–0.80 | −0.45–0.65 | 0.00–0.85 |
| Control later lower | 25.260544–25.527156 (f1510–1526) | 25.260544–25.660489 (f1510–1534) | 25.393956–25.795367 (f1518–1542) | −0.30–0.40 | −0.30–0.55 | −0.15–0.55 |
| Candidate later raise | 24.556400–24.823178 (f1466–1482) | 24.756556–25.173233 (f1478–1502) | 24.889800–25.241578 (f1486–1506) | −0.10–0.65 | −0.30–0.50 | 0.05–0.70 |
| Candidate later lower | 25.106611–25.391578 (f1498–1515) | 25.106611–25.516600 (f1498–1523) | 25.189889–25.583533 (f1503–1527) | −0.30–0.45 | −0.35–0.50 | −0.25–0.50 |

The control/candidate ranges overlap substantially in both pace groups. The conditional candidate later-raise interval's positive lower bound is not treated as a guaranteed latency minimum: its strict crossing is uncertain. Differences narrower than these broad enclosures, such as the roughly 18 ms internal callback-to-paint reduction, cannot be resolved by this event review.

Fully censored examples, excluded from numerical comparison:

| Event | C enclosure | R/S handling |
|---|---|---|
| Candidate first earlier raise | f320–344, approximately 5.35–5.75 s | Near-plane maximum and mixed/doubled marker exposure near f348; no reliable strict R/S crossing. |
| Candidate first earlier lower | f354–382, approximately 5.92–6.38 s | No reliable preceding above-plane R/S anchor; no ordinary lower-crossing delay. |
| Control raise around the blank | f1222–1235, approximately 20.46–20.68 s | Overlay absent at f1229 and blended at f1228; no interpolation through missing output. |

## Visible lag, stability and anatomy

[Same-frame evidence sheet](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2i-screen/same-frame-comparison.jpg) shows each clip's camera image, refined rings and filtered skeleton together. These are illustrative similar-motion frames, not timestamp-matched input trajectories between builds.

- Control f347 at 5.847356 s and candidate f340 at 5.681789 s show the camera arm raised while refined and filtered elbow/wrist positions remain lower. Control f1496 at 25.027733 s and candidate f1486 at 24.889800 s show the same pattern during later movement.
- On lowering, the mismatch reverses: yellow/green joints retain a higher arm pose after the camera arm has descended. Filtered endpoints visibly trail the refined rings in both builds. This supports a temporal contribution, while spatial prediction error also remains possible.
- In the holds, refined rings and filtered points converge; shoulders/torso broadly follow the person. Elbow/wrist placement remains approximate in some raised-arm frames, so not every camera/overlay separation should be interpreted as delay. Static prediction/geometry bias must be separated from temporal response. These clips do not prove a projection or mirroring defect.
- No conspicuous new stationary shaking is apparent in the sampled candidate top/bottom holds. The control top hold is roughly 30–36 s, bottom hold roughly 38–44 s; candidate top roughly 27–31 s, bottom roughly 33–37 s. These are short, unmatched visual holds with real body/camera movement, not calibrated jitter distributions or a stability acceptance test.
- Both settle over subsequent pose updates after movement. There is no defensible numerical settling-time improvement from the uncertain camera stopping point, near-plane peaks and exposure blending.
- No isolated upper-arm/forearm link disappearance was positively identified in the reviewed legible crossing/hold frames apart from the verified whole-overlay gaps. Faint or doubled links were not counted as confidence rejection. This is not an exhaustive per-link acceptance ledger; hands/finger geometry remains approximate.

The visible result is consistent with the user's “looked same” assessment. Computation improved, but the remaining prediction/filter discrepancy is still large enough to be apparent. The footage cannot establish that either upstream input/prediction or filter signal delay numerically dominates. Filter execution time is not filter signal delay.

## Whole-overlay blank observations and reasons

All 2,784 control and 2,416 candidate upper-body crops were screened for low green-pixel counts, then low-count candidates reviewed visually. All-frame color screening is a candidate detector, not a display-present ledger or proof that a very brief display gap was impossible.

| Clip | Externally sampled absence | Visible neighbors | Interpretation |
|---|---|---|---|
| Control | f1229, PTS 1,852,016 / 90,000 = 20.577956 s | f1227 at 20.544644 s; f1230 at 20.594611 s | Whole skeleton/markers absent while camera/person remain; f1228 at 20.561300 s is exposure-blended, so it is not a clean visible/absent anchor. |
| Control | f2355, PTS 3,543,524 / 90,000 = 39.372489 s | f2354 at 39.355833 s; f2356 at 39.389144 s | Whole skeleton/markers absent while camera/person remain. |
| Candidate | No whole-overlay absence found in screening | — | Favorable within this clip; not a general reliability pass. |

Full-preview verification: [first gap neighbors](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2i-screen/control/blank-neighbors-1228.jpg), [second gap neighbors](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2i-screen/control/blank-neighbors-2355.jpg).

Neighbor PTS delimit recorded observations only. Neither their separation nor one sampled absent frame establishes the physical screen gap's minimum/maximum duration. Second-camera exposure/readout and phone display scan are unsynchronized.

Badge-based approximate route-minus-video offsets are 40.135 s control and 23.954 s candidate. The badge is rounded to 0.1 s and updated asynchronously. In the approximate control clip interval, scalar logs contain **seven freshness expiries of nonempty poses**, with ages about 250–262 ms, followed by `pose` recovery. There is no detector no-person or low landmark presence transition in that interval. Candidate has no non-pose transition in its approximate clip interval; subsequent detector no-person after the person approaches/leaves is outside it.

The first observed control gap is consistent with the route 60.789366 s freshness clear, and the second with route 79.589247 s. They recover logically about 22.9 ms and 12.7 ms later, respectively. Approximate clock matching supports the reason family but cannot attest exact screen onset/recovery or assign display duration. There is no bounded manual blank/renderer-rejection report for these idle captures; the seven logical clears must not be reported as seven externally observed blanks.

## Phone telemetry — separate evidence

Retrieve existing scalar logs only, excluding landmark/frame streams. Compare complete 25-second interior completion windows: control 09:19:26.166–09:19:51.167 local (route ~45–70 s), candidate 09:21:03.416–09:21:28.420 (route ~30–55 s). Both cover early/later movement but are not matched trajectories or exact video-event/input cohorts. Means come from differences of cumulative sum/count; rolling percentiles are not differenced. Run order and device variability remain uncontrolled.

| Interior scalar metric | Control | Candidate |
|---|---:|---:|
| Camera received FPS | 30.00 | 29.92 |
| Processed / delivered drawable / first CPU paint FPS | 11.08 | 13.68 |
| Preprocessing mean ms | 36.47 | 20.58 |
| Landmark preprocessing mean ms | 35.01 | 19.69 |
| Detector preprocessing mean ms | 22.46 | 13.22 |
| Total native inference mean ms | 51.39 | 50.48 |
| Worker computation mean ms | 88.63 | 71.77 |
| Callback → UI mean ms | 108.56 | 90.62 |
| Callback → first CPU paint mean ms | 120.71 | 102.40 |
| Processed/drawable/first CPU-painted frames | 277 | 342 |
| Pending replacements | 473 | 407 |
| Stale results / empty poses | 0 / 0 | 0 / 0 |
| Nonempty freshness expiries in this interior window | 3 | 0 |

This corroborates reduced computation and fewer freshness clears in this pair. It does not override the inconclusive external response comparison. Callback-to-CPU-paint excludes camera sensor exposure and physical display presentation. No internal/external timing values are added, subtracted or fused into a physical latency estimate.

## Acceptance, next focus and evidence preservation

Keep the equivalent Step 2I sampler improvement. Do not change beta, thresholds, models, resolution, cadence, freshness or backpressure on the basis of this footage. Step 2 quality has not passed: visible moving-arm mismatch remains, anatomical joint accuracy is approximate and a reliable static/held stability acceptance is not established.

The next focus should be separating **held-pose joint-placement bias from temporal prediction/filter delay**, using the existing videos and bounded coordinate fixtures before another production tuning experiment. Further sampler-only tweaks are unlikely to resolve the whole visible discrepancy by themselves; this is an inference from the retained computation gain and persistent video mismatch, not a measured attribution of the remaining delay. No additional physical recording or implementation is required by this report.

Preserved evidence: original analysis copies, full PTS tables, all-frame upper-body crops/color audits, reviewed conditional/censored events, same-frame sheet, full-preview blank neighbors, matched scalar log, telemetry audit and SHA-256 integrity manifest under `apps/mobile/build/pose-quality/step2i-screen/`. Build evidence/rollback remain in `apps/mobile/build/pose-quality/step2i/` and its parent.

Verification checked source/copy SHA-256 equality, all 5,200 strictly increasing frame/PTS joins and crop counts, event-to-PTS joins, direct interval arithmetic/outward rounding, session matching, scalar-log parsing and current installed candidate hash. This evidence-only analysis changes no product code; mobile tests/analysis were not rerun or represented as new results. Earlier verified tests remain documented in the sampler report.
