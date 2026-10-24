# Step 2F — displayed camera to refined joints and reason-coded blanks

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

**Status: bounded physical diagnostics collected and analyzed for two still captures, slow, fast, top hold and bottom hold. Fresh C→R timing remains unresolved: the user confirmed no Step 2F screen video was recorded. No production tuning or Step 3 work.** Beta 0.3 and the optimized Step 2C preprocessing remain in use. The diagnostic profile APK remained installed on Xiaomi 23013RK75C / serial xiaomi-device-serial-redacted, with its SHA verified again after all phases. Captures used fresh preview sessions, not hot reload. End preview released the camera.

## Current conclusions, with limits

| Question | Evidence so far |
| --- | --- |
| Is camera-preview to refined-joint mismatch materially visible? | Yes, repeated retrospective same-frame raises/lowers show yellow refined elbows behind the displayed camera arm. A positive minimum crossing delay is **not** established: every usable conservative C→R range includes zero. |
| Is refined→filtered the dominant verified added delay? | It remains a verified post-inference contribution from Step 2D. Its dominance over the whole visible mismatch is **unproven**. C→R cannot yet be ranked numerically against it. |
| What causes whole-overlay blanks? | All16 logical episodes in the bounded captures were freshness expiry of otherwise valid33-joint poses; seven reached blank CPU paint. Older video blanks cannot be assigned causes from unrelated telemetry. |
| Are blanks primarily freshness, prediction or renderer rejection? | Freshness within these captures. Confidence rejection affects partial limb links separately; no whole-pose prediction or all-joint rendering failure caused a recorded episode. |
| Next single-variable experiment? | Proposed, not implemented: interpreter threads2→4, targeting computation/input age while preserving freshness, models and filter. Benefit must be measured, not assumed. Fresh C→R timing remains a separate unresolved boundary. |

## Retrospective C→R supporting evidence

This is a retrospective review of the preserved beta 0.3 **screen-only** Step 2E control recording, not a fresh Step 2F run. It contains no physical latency estimate. It does not assign causes to the recording's blanks from unrelated or unsynchronized phone telemetry. Yellow rings are the refined, inverse-ROI-projected joints drawn using the same existing preview transform as magenta; they are not the raw ROI tensor output. A displayed yellow marker is also not a marker on the current camera-preview exposure: the camera preview and delivered pose update independently.

The original source hash is `40b6e8a8045b15212fc968eedfa91be25e1a0ac1a338c4adae13ab75c0830f93`; decoded 3,805 frames have first/last PTS 0/5717676 ticks at time base 1/90000 (0/63.529733 s). Every timestamp below is exact decoded ticks/90000, never frame/60. Control binary attribution retains the prior report's limitation: user label and installation chronology, rather than a retrospective hash of the then-installed binary.

## Event definition and conservative bounds

The moving **image-right elbow/upper arm** passing approximately shoulder level relative to the local shoulder/torso is followed. No anatomical left/right or physical event is inferred. The previous C anchors are retained unchanged; R anchors are separately reviewed from yellow rings. Shirt/sleeve overlap, shoulder shrug, tilted phone perspective, line placement, exposure blending and stepped pose updates limit the crossing precision. Bounds are crossing-zone enclosures, not adjacent-frame ground truth. C to R is `[Rlo - Chi, Rhi - Clo]`; printed bounds round outward to 0.05 s. Negative lower bounds mean uncertain crossing brackets overlap, not prediction ahead of the camera.

All three slower cycles and faster cycles 1, 2, 3 and 5 were independently reviewed, using every fourth decoded frame around each event plus the finer previous first-slow-rise sheet. This is a representative subset, not an exhaustive all-event survey. Missing, doubled or indistinct yellow rings inside the unresolved crossing are censored and receive no ordinary delay sample. No means, fitted delays or sums with other pipeline timing are calculated.

| Event | C PTS seconds (zero-based frame) | R PTS seconds (zero-based frame) | Conservative C to R seconds | Status |
| --- | --- | --- | --- | --- |
| slow1 up | 11.846011–12.129156 (f708–725) | 11.979256–12.312367 (f716–736) | -0.15–0.50 | usable |
| slow1 down | 12.845189–13.128756 (f768–785) | 12.912056–13.178722 (f772–788) | -0.25–0.35 | usable |
| slow2 up | 14.877800–15.246111 (f890–911) | 15.096211–15.429322 (f902–922) | -0.15–0.60 | usable |
| slow2 down | 15.778233–16.144767 (f943–965) | 15.844856–16.194767 (f947–967) | not scored | censored/indistinct |
| slow3 up | 17.827400–18.243311 (f1065–1090) | 18.094000–18.427700 (f1081–1101) | not scored | censored/indistinct |
| slow3 down | 18.827733–19.243489 (f1125–1150) | 18.827733–19.159744 (f1125–1145) | -0.45–0.35 | usable |
| fast1 up | 20.626144–21.044289 (f1233–1258) | 20.892633–21.309189 (f1249–1273) | -0.20–0.70 | usable |
| fast1 down | 21.509189–21.942356 (f1285–1311) | 21.642067–22.042233 (f1293–1317) | not scored | censored/indistinct |
| fast2 up | 23.208244–23.642578 (f1387–1413) | 23.535144–23.943622 (f1407–1431) | not scored | censored/indistinct |
| fast2 down | 23.823533–24.243467 (f1424–1449) | 24.026956–24.360133 (f1436–1456) | -0.25–0.55 | usable |
| fast3 up | 25.208011–25.641167 (f1507–1533) | 25.541122–25.807722 (f1527–1543) | not scored | censored/indistinct |
| fast3 down | 26.024344–26.440789 (f1556–1581) | 26.224344–26.557378 (f1568–1588) | -0.25–0.55 | usable |
| fast5 up | 29.617478–30.042633 (f1771–1796) | 29.891011–30.217944 (f1787–1807) | not scored | censored/indistinct |
| fast5 down | 30.217944–30.642933 (f1807–1832) | 30.491300–30.759600 (f1823–1839) | not scored | censored/indistinct |

Detailed censoring reasons and exact PTS ticks are preserved in `control-cr-observations.json`. Contact sheets are in `control-cr/`.

## Same-frame observations

- f720 = 12.045878 s (1084129 ticks), slow raise: Displayed camera upper arm is higher than the yellow refined elbow/upper-arm position; magenta is lower still.
- f1261 = 21.092222 s (1898300 ticks), fast raise: Displayed camera arm is raised above level while yellow refined elbow remains near/below level; magenta trails farther.
- f1407 = 23.535144 s (2118163 ticks), fast raise: Displayed camera upper arm is clearly elevated; yellow refined elbow remains approximately at/below shoulder level.
- f1576 = 26.357511 s (2372176 ticks), fast lower: Displayed camera elbow has descended; yellow refined elbow remains approximately near shoulder level, with magenta higher.

## Judgment and limits

Yellow R is legible enough to support several conservative observations. Repeated raises show R behind the displayed camera arm, and repeated lowers show R remaining raised after the camera arm descends. This establishes a practical, visible **upstream discrepancy relative to the preview** that is already present before temporal filtering. It is not correct to attribute all visible moving-arm mismatch to the One Euro filter.

However, **every usable C to R conservative interval here includes zero**. The inherited broad C brackets, moving shoulder reference and blended display images do not establish a positive minimum upstream crossing delay or a reliable numerical magnitude. These observations cannot distinguish input age, model prediction error, ROI behavior or display exposure alignment, and cannot rank the upstream delay against refined to filtered delay. The filter remains a verified added post-inference delay from timestamp-matched Step 2D evidence; dominance over the whole visible discrepancy remains unproven. No production tuning is justified solely by these old C to R ranges.

A fresh beta 0.3 Step 2F session with bounded reason-coded events is still required to correlate overlay blanks to pipeline states. For new screen recording, keep the camera image and yellow rings legible, keep the phone approximately square to the second camera, use the same one arm, and pause briefly on either side of shoulder level. Keep the current production parameters frozen. Capture an explicit session/phase identifier on screen so events can be matched to that same session's report without guessing wall-clock metadata. The prior source is useful supporting evidence and must not be relabeled as the new diagnostic capture.

## New bounded instrumentation

`GAINPATH_POSE_BLANK_DEBUG=true` enables the observation-only metadata collector in a non-release quality build. Each manual phase lasts at most 20 seconds and retains at most 128 events. It emits one bounded report at phase completion, with explicit overflow and open-episode censoring. Disabled mode retains no blank evidence. There is no image capture, image upload, video capture or continuous landmark log added to the application. Existing Step 2D joint diagnostics retain bounded RAM samples and emit aggregates plus four representatives.

A blank episode separates its logical `blank_begin`, later `cause_change` entries, first `blank_paint` CPU observation, and matching visible `recovery`. Valid delivery alone does not prove recovery. Obsolete paints cannot recover a newer blank. Scheduler discards are noncausal observations; a stale result usually leaves the previous pose until the watchdog expires it. Replacing pending frames is ordinary frozen backpressure and does not create blank events.

Metadata is joined by input timestamp, not the latest worker record. An episode retains input, worker-result-receipt and delivery timestamps; last accepted valid pose input/delivery and matching paint times/age; detector/landmark confidence; detector-vs-tracked ROI source; worker outcome and next-ROI state; refined/filtered/accepted counts; confidence/nonfinite rejection counts; renderer rejection and issued/intersecting primitive counts; and whether the watchdog cleared a previously accepted pose. Pipeline errors may have no completed result/delivery timestamp, which stays null. Debug yellow/magenta markers bypass green skeleton confidence gates; their presence does not prove accepted limb drawing.

The renderer's diagnostic intersection counts use the existing canvas plus outer cover/crop clipping. They distinguish accepted-but-off-viewport drawing from all-joint confidence rejection; they do not alter drawing or projection. CPU draw issuance/intersection is not a GPU display-present fence or a guarantee that the external camera recorded visible pixels. Screen-only recording remains the evidence for displayed C/R/S. Exposure blending and scanout can make an external blank ambiguous even when CPU primitives were issued.

| Reason family | Explicit observation |
| --- | --- |
| Freshness | `freshness_expiry`, with age and watchdog flag. Expiry of an already empty/rejected pose preserves the original loss cause. |
| Detector | `detector_no_person`, `detector_nonfinite_scores`, `detector_invalid_boxes`, `invalid_detector_roi`, or existing `roi_unavailable` outcome. |
| Landmark model | `low_landmark_pose_presence`, `nonfinite_landmarks`. |
| Confidence | `landmark_visibility_rejection` versus `landmark_joint_presence_rejection`, with separate rejection counts. |
| Renderer | `preview_aspect_mismatch` and `renderer_off_viewport`, accepted counts and intersecting primitive counts. |
| Invalidations/lifecycle | `camera_geometry_invalidation`, manual pause, background, logout, close, or pipeline error. These may be logical/unpainted when the viewport is removed. |
| Discard | `stale_before_processing`, `stale_result`, generation-invalidated pending/result; recorded separately from direct clear causes. |

`invalid_auxiliary_roi` is the state of the **next** ROI. It does not label a currently valid pose as missing. Generic pipeline error remains an explicit error branch; an exception without a completed model result is not invented as a detector/presence failure.

The diagnostic `F` badge displays the session suffix, phase, route-clock seconds and latest episode ID/reason, plus logical blank/visible state. It updates only through existing preview notifications; no faster UI or watchdog cadence is introduced. The badge retains the latest episode after recovery, so B# alone is not an active-blank assertion. Phase + session + route time permits matching a screen event to its capture token. During an unpainted logical transition, the badge state is still a logical observation.

The parser separates **initial blank causes** from subsequent cause changes. `reasonCounts` includes both and must not be presented as a count of disappearances. Missing/conflicting/truncated transport, capacity overflow and open episodes remain censored. Complete CPU blank durations are recovery CPU time minus first blank CPU paint, not physical display durations. No internal duration is added to C→R.

## Physical protocol and collection

1. Keep IDE Run stopped. Open the installed GainPath app directly and create a fresh Workout → Try live camera preview session.
2. Use the same full-body framing, front camera, light and one moving arm; other arm stays down. For each phase select its name, tap Capture 20s and allow about 3 seconds to return to position if tapping yourself.
3. Capture separately: still; slow raises/lowers; fast raises/lowers; topHold; bottomHold. During motion pause briefly on either side of shoulder level, with hands in view. Keep each phase separate so its bounded report can be retrieved before the next phase.
4. Prefer an original ≥60 FPS close screen video, with the camera arm, yellow shoulder/elbow rings, skeleton and F badge simultaneously legible. Keep the phone square to the recording camera where practical. There is no physical-person timing measurement requested in this screen-only protocol.
5. Preserve the original file. Decode its actual presentation timestamps; keep C and yellow-R crossing brackets independent, and censor missing/doubled/indistinct rings. Do not sum C→R with refined→filtered or callback/paint telemetry.
6. End preview after captures and verify camera/model cleanup. Fresh blank reports will be grouped by exact capture token, then matched to screen observations using the badge. If a video blank has no corresponding confirmed CPU event, retain that mismatch and investigate display/recording evidence rather than forcing a cause.

The local ADB collector writes only existing Flutter diagnostic output to ignored `apps/mobile/build/pose-quality/step2f/device.log`. The bounded report parser is:

```powershell
python apps/mobile/tool/analyze_pose_blanks.py apps/mobile/build/pose-quality/step2f/device.log --output apps/mobile/build/pose-quality/step2f/blanks.json
```

## Provenance and checks

Installed artifact: `apps/mobile/build/pose-quality/step2f-blank-diagnostic-profile.apk`, 147165566 bytes; SHA-256 **`9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07`**. ADB installation succeeded and device-side SHA matches. Beta 0.3 rollback APK is preserved unchanged at `step2d-joint-lag-logging-profile.apk`, SHA **`774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`**. Beta 0.6 candidate and evidence remain preserved separately.

The 180-file control manifest has only five changed existing production files: diagnostic quality plumbing, preview controller observation hooks, painter observations, viewport aspect reason plumbing and diagnostic badge. The new bounded recorder is an additional file. **All other 175 existing files match**: detector, decoder, geometry/preprocessing, shared filter/scheduler and model contracts are unchanged. APK comparison finds only the three architecture-specific compiled Dart `libapp.so` entries differ; **29 model/native/runtime/Android manifest/resource/Dex entries match**. The source/build manifests are retained in the ignored Step 2F evidence folder.

Frozen settings remain beta .3, minCutoff 1, derivative cutoff 1, the original model/assets/tensors, thresholds, ROI/detector cadence, two interpreter threads, medium camera resolution, mirroring/cover/crop, 250 ms freshness, 100 ms watchdog and one-active/one-replaceable latest-frame policy. No Firebase acceptance, workout activity, scoring, audio or Step 3 path was added.

Profile flags enable preview, quality, joint-lag and blank diagnostics. Effective backend is mock, matching control. The initial build command used the unused `GAINPATH_BACKEND=mock` switch; the application's actual `BACKEND` default is mock. The exact command and this distinction are preserved in build provenance; no Firebase flow was entered. Subsequent source-only lint cleanup added four braces, with no semantic change; the installed build's exact source snapshots/hashes are retained as text in `build-source`. No installation during an active capture is performed.

Verification: complete mobile suite **147 passed / 4 define-gated skipped**; diagnostic-enabled UI/controller/rendering run **28 passed**, including gated cases; shared pose **14 passed**; new blank-parser **14 passed**. Initial analysis found four missing-brace style infos, corrected without changing conditions; final mobile analysis is clean. Temporary source snapshots were renamed to `.dart.txt` to keep archival copies out of the analyzer; no production issues remained. The verified empty-expiry regression failed before the guard and passed after it. Snapshot artifacts, test/analysis/build logs and transport tests remain preserved.

**Pending:** five fresh physical phase reports, legible new C→R screen recording, same-session blank/video correlation, final cleanup check and the evidence-led next-experiment decision. Step 2F is not physically complete and Step 2 quality/Step 3 acceptance is not claimed.


## Initial stale-collector inspection — preview telemetry only, 18:49 local (superseded)

The first host inspection mistakenly treated an old, stopped live collector as current. This section preserves that older preview-only evidence; it does **not** describe the later completed still captures. Its process6533 / session1791197349654850 spans session creation **18:49:09.655** through close **18:49:42.572** on 2026-10-05 Asia/Kuala_Lumpur. Installed APK SHA remains `9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07`; camera service reports no active clients after close. The raw local snapshot is `still-device.log`, SHA-256 `0d9a5446ef76a04fd5a3bd8fdef4ec90cba58ff7f5da8e209c9fe72a4108e9ce`.

**No POSE_LAG_PHASE, POSE_LAG_SUMMARY, POSE_BLANK_SUMMARY or blank events occurred.** Both parsers report no malformed/transport errors but zero phase captures. Therefore the bounded capture was not observed to start; this is not accepted as the still-phase joint/blank report. The phase selector or a still person alone does not initialize a bounded capture. Recapture was requested with confirmation that the Capture20s button visibly changes to a countdown. No production change/rebuild is requested.

Preview telemetry nevertheless records three controller freshness clears followed by valid pose deliveries:

| Logical expiry route time | Expired pose age | Next valid delivery route time | Clear → delivery gap | Accepted joints on return |
| --- | --- | --- | --- | ---: |
| 1.223757s | 294.083ms | 1.232243s | 8.486ms | 9 |
| 8.623803s | 272.383ms | 8.635809s | 12.006ms | 13 |
| 22.122209s | 274.213ms | 22.127624s | 5.415ms | 18 |

These are exact route-clock **logical decisions/delivery**, not CPU-confirmed or physically displayed blank durations. There is no bounded renderer record to determine whether each clear was painted or exposed by the recording camera. Return pose-presence values are about .8032, .99998 and .99986 respectively. Latest discard on each clear was normal `replaced_pending`, which does not itself clear an overlay. All327 processed/delivered results in the final snapshot are nonempty/drawable; stale results0, no empty-pose worker outcome recorded. Thus freshness effects are a concrete preliminary contributor in this preview session, not evidence of no-person or all-joint rejection at these three logical clears. It does not establish the dominant cause across the requested protocol or explain older video blanks.

Final snapshot (roughly30s route time): received873, processed/delivered327, replaced pending544, nonempty expiry3; latest five-second interval camera30.01FPS and processed/delivered/drawable11.01FPS. Session-cumulative means: worker87.24ms, native50.11ms, preprocessing36.37ms, callback→UI106.45ms, callback→first CPU paint117.67ms. New blank observation means delivery0.020ms / paint0.024ms, excluding renderer intersection calculation and end-of-phase logging. These aggregates include warm-up/positioning and are not isolated 20s still-phase measures or total physical latency.

**Historical next step, superseded by recovery below:** repeat the still capture with an observed countdown. Direct phone retrieval subsequently recovered both completed reports; no third still capture was required. All tuning remained frozen.


## Recovered still captures — 20:27 and 20:32 local

The live ADB collector had exited. Direct retrieval from the phone recovered two complete still phases in process6531, with **zero transport/malformed errors and no capacity censoring**. The prior missing-report inference was corrected and the user was told that no third still capture was needed. Subsequent captures will be retrieved from the phone buffer directly. Artifact path and SHA are unchanged.

| Phase / capture token | Wall-clock start / report | Matched painted pose frames | Whole green-skeleton blank episodes | Outcomes / resets |
| --- | --- | ---: | ---: | --- |
| still / `1791203251152914:8910075:1` | 20:27:40.062 / 20:28:00.101 | 223 (~11.12FPS) | 1, CPU-confirmed and recovered | pose223; freshness reset1 |
| still / `1791203555237893:15387724:1` | 20:32:50.625 / 20:33:10.672 | 226 (~11.27FPS) | 0 | pose226; no resets |

Both are bounded20s captures with zero timestamp mismatches. Three paints per phase were ignored without a matching delivery, explicitly counted; these are not missing-pose episodes. The first joint input can precede capture start because its matching delivered frame is first painted within the phase. Whole-pose prediction loss outside these bounds (for example the person leaving view after completion) is not pooled into the still results.

### Explicit freshness blank in the first phase

Old valid input16.572720s; delivered16.723480s; last valid paint16.733500s. At16.861924s the watchdog logically cleared it at **289.153ms** input age. It had33 refined/filtered/visible/accepted joints, no nonfinite or confidence rejection, pose-presence **.999975**, tracked-ROI source and last detector confidence **.98156**. Latest discard was normal replaced-pending, not a stale-result clear. Aspect was compatible. First null/zero-primitive CPU paint occurred approximately16.865864s.

Recovery input16.718773s came from a detector refresh, detector confidence **.98205**, pose-presence **.999991**,33 accepted joints. Delivered16.887522s; CPU recovery observation16.902618s issued68 intersecting primitives. The recovered ledger's CPU blank span is **about37ms**, not a physical display duration. The next delivered valid frame's input→delivery age is about169ms; that includes queue/host work and is not pure native inference. This event establishes a **freshness-policy blank of an otherwise valid pose**, rather than detector no-person, low pose presence or all-joint renderer rejection. One such event does not establish overall dominance across motion phases.

### Joint acceptance, displacement and projection

All elbows and both shoulder→elbow links were accepted/draw-issued in223/223 and226/226 matched paints. First phase: right elbow→wrist rejected4/223 because right wrist confidence failed; second: left elbow→wrist rejected2/226 and right elbow→wrist4/226. Visibility/presence count overlap is retained, not summed as separate rejected frames. Right wrist was off viewport6 first /7 second observations; right elbow off viewport5 first /0 second. Partial links/off-viewport observations are independent of whole-pose blank health.

Refined→filtered displacement **median image pixels**:

| Joint | First still | Second still |
| --- | ---: | ---: |
| left elbow | .86 | .79 |
| right elbow | .99 | .86 |
| left wrist | .81 | 1.17 |
| right wrist | .95 | .85 |

These are same-input refined/filter displacements, **not stationary jitter RMS**. Upper tails/maxima are much larger during initial positioning; the largest representative arm excursion is within about0.6–0.9s of phase start. Mid/last representative elbow/wrist displacements are about0.1–1.7px. The report cannot reconstruct an excluded-start full trajectory from its four snapshots or declare physical held stability from medians alone. Existing transform residuals are zero in every sampled joint: no numerical painter/projection binding mismatch was found, which does not prove anatomical model accuracy.

### Separate interior telemetry

From cumulative aggregate differences over fully interior snapshots (first20:27:46–56,111 results; second20:32:55–20:33:10,169 results), approximate means are preprocessing **36.3/36.7ms**, native **51.5/50.2ms**, worker **88.5/87.5ms**, callback→UI **107.7/107.2ms**, callback→first CPU paint **119.6/118.8ms**. These interior windows are10s/15s, not exact20s phase aggregates. New blank metadata observation costs about **.024–.026ms delivery** and **.028–.029ms paint**, excluding primitive intersection calculation and end-report output. No telemetry is added to C→R or represented as physical latency.

The phone did start both captures despite the user's not seeing a countdown. A new widget test at the Xiaomi logical screen size taps the actual Workout Capture20s button, verifies both collectors start and the visible label changes, then verifies both reports finish. It passes with the existing two UI tests (**3 passed**). This establishes the host UI path and phone capture start; a physical countdown-visibility defect was not reproduced. No speculative UI/inference fix or APK change was made.

**Disposition after still:** the available CPU-confirmed blank is explicitly freshness-driven; no whole-overlay prediction/confidence/clipping loss occurred within these phases. Some wrist confidence rejection and off-viewport samples remain. Still cannot determine C→R temporal response; slow/fast footage and remaining phase reports are required. No tuning selected.


## Slow one-arm phase — recovered bounded evidence

Capture token `1791204002180061:4687972:1`, matching joint phase `slow@4687975`:221 same-timestamp pose paints in20.032s (~11.03FPS), zero timestamp mismatches, eight paints explicitly ignored without a matching delivery, no capacity or transport loss. All matched outcomes are pose. The blank collector observed227 delivery decisions and251 paint callbacks (including null and repeats), which are not221 distinct delivered pose timestamps.

There are **six logical freshness clears, only one CPU-painted blank**, all recovered. The five logical-only clears must not be reported as five displayed blank intervals. Expired poses have33 refined/filtered/accepted joints and pose presence .99964–.99996; age at clear251.6–287.7ms; watchdog flag true. No detector-no-person, invalid ROI, low pose presence, stale-result discard, all-joint confidence rejection or whole-viewport rejection caused these episodes. The last event was painted blank for **about51ms CPU time** (not a physical display duration). Recovery frames remain high-confidence valid poses; two recoveries used detector refresh, four tracked ROI. This does not attribute every clear to detector refresh: the four tracked-ROI returns are retained separately.

| Logical episode | Age at clear | CPU blank status |
| --- | ---: | --- |
| B1 | 287.7ms | clear/recovery; no blank CPU paint |
| B2 | 257.1ms | clear/recovery; no blank CPU paint |
| B3 | 285.1ms | clear/recovery; no blank CPU paint |
| B4 | 274.5ms | clear/recovery; no blank CPU paint |
| B5 | 251.6ms | clear/recovery; no blank CPU paint |
| B6 | 252.5ms | confirmed and recovered; ~51ms CPU span |

Both shoulders/elbows and shoulder→elbow links are accepted/draw-issued221/221. Left wrist confidence rejected7/221 (presence7, visibility1 overlapping); right wrist rejected1/221 (visibility1). Their forearm links have the corresponding7/1 rejections, independent of whole-pose health. Off-viewport observations: right shoulder3, right elbow5, left wrist7, right wrist0. Numerical transform residuals remain zero in the sampled joints; no uniform projection/mirror binding defect is found. This does not prove model anatomy or pixel-level visibility.

The moving model-right elbow refined→filtered image-pixel displacement median/p95 is **4.37/13.04px**; moving wrist **8.23/19.03px**. The other elbow/wrist medians are .82/.97px. These are same-input signal displacements, not CPU execution durations or video C→R delay. Crossings exist on the model-right side; several refined elbow recrossings near shoulder level are ambiguous and must not be averaged or forced into pairings. Freshness resets also segment trajectories. Screen-video C/R brackets are still required to rank upstream discrepancy against filter response.

The immutable `phone-after-slow.log`, parsed `slow-blanks.json`/`slow-joints.json`, and phase-specific `slow-1791204002180061-report.json` retain exact contexts and source hash in the ignored evidence folder. **No parameter change.** Fast, top hold and bottom hold remain to be captured and reviewed.


## Fast one-arm phase — recovered bounded evidence

Capture token `1791204262071223:3796726:1`, joint phase `fast@3796729`:223 matched pose paints over20.066s (~11.11FPS), zero timestamp mismatches, five unmatched-delivery paints explicitly ignored; no capacity or transport loss. All matched outcomes are pose.

There are **two logical freshness clears and zero CPU-painted blanks**, both recovered. The old poses had33 accepted joints, pose presence .999944/.999425, and ages258.3/254.1ms at clear. One recovery was tracked ROI, one detector refresh. These are logical policy effects/reset points, not two observed blank pixel intervals. No whole-pose detector/presence/invalid-ROI/nonfinite/stale/confidence/clipping failure occurred in the bounded capture.

The moving model-right shoulder/elbow/upper-arm link is accepted and draw-issued223/223. Moving wrist/forearm confidence rejection6/223, mostly presence; wrist off viewport6 observations. Other elbow rejects5/223 and forearm11/223 (the elbow first-rejection precedence is retained in link counts). Other elbow/wrist off viewport13/14 observations. Confidence counts overlap and must not be summed. Partial/off-viewport phenomena remain independent of whole-overlay health.

Moving elbow refined→filtered median/p95 displacement **8.02/15.33 image pixels**; moving wrist **16.18/26.15px**. These exceed the slow phase's moving medians4.37/8.23px and support a speed-dependent added filter signal discrepancy; trajectories are approximately, not identically matched. Five refined/filtered raises are observed on the moving elbow and wrist. Several lower crossings have overlapping input brackets or no distinct elbow crossing, and remain unsuitable for averaging/forcing a physical response estimate. Freshness reset points segment the evidence. No C→R or total physical latency value is inferred from these coordinate observations.

Sampled transform residuals remain zero. The phase-specific `fast-1791204262071223-report.json` and immutable phone snapshot retain all bounded metadata, joint statistics/crossings and four representatives. **No tuning or APK change.** Top and bottom holds remain pending.

## Top hold — recovered bounded evidence

Capture token `1791204545775044:7457267:1`, joint phase `topHold@7457271`:223 matched pose paints over20.013s (~11.14FPS), zero timestamp mismatches, four unmatched-delivery paints explicitly ignored. Both parsers report complete transport and no capacity censoring. All matched outcomes are pose.

**Seven logical freshness clears, five CPU-confirmed blanks, all recovered.** Every expired pose had33 accepted joints, pose presence .99953–.99996, a valid refined frame, and watchdog-cleared-valid-pose true. Age at clear252.4–256.7ms. No other whole-overlay cause was recorded. Five first-blank-CPU-paint→recovery spans were approximately21,12,30,20 and18ms. Two logical clears did not reach a blank CPU paint. These are CPU composition observations, not physical screen exposure measurements.

Three old poses came from detector ROI and four tracked ROI; three recoveries used tracked ROI and four detector ROI. Thus both ROI sources occur around these policy events; this evidence does not justify assigning all expiry to detector cadence. All recovery frames remained valid and drawable.

Moving model-right shoulder/elbow/upper-arm link accepted/draw-issued223/223; moving wrist/forearm rejected6/223 (presence6, visibility3 overlapping), with6 wrist off-viewport observations. Other elbow rejected7/223 and forearm10/223, with13 off-viewport observations for both elbow and wrist. Numerical transform residuals remain zero in sampled joints. Partial confidence rejection and off-viewport geometry are separate from whole-overlay expiry.

Moving elbow/wrist refined→filtered displacement medians1.29/1.70 image pixels, p95s16.72/19.70px. The phase includes entry, raise and lower transitions and cannot be called a pure stationary jitter measurement. Midpoint representative input at phase+9.893s has elbow1.26px and wrist2.28px displacement; final at+19.888s has .58/.83px. The largest wrist representative is at+.724s during initial setup (68.17px), not evidence of sustained top-hold shaking. These sparse representatives support settled small displacement at sampled instants, but cannot establish full hold jitter RMS or exact settling time.

Exact contexts and the source-log SHA are preserved in `topHold-1791204545775044-report.json` under the ignored evidence folder. **Bottom hold and original motion video review remain pending; no parameter change.**

## Bottom hold and cleanup — final bounded evidence

Capture token `1791204925719767:7021303:1`, joint phase `bottomHold@7021307`:221 matched pose paints over20.058s (~11.02FPS), zero timestamp mismatches, five unmatched-delivery paints explicitly ignored. All matched outcomes are pose. **Zero blank episodes and zero filter resets**; no malformed/transport/capacity censoring. The phase-specific report preserves its source SHA.

Both shoulders are accepted throughout. Left/right elbows reject5/3 of221; left/right upper-arm links draw216/218. Left/right wrists reject7/5; forearm links draw214/216. Link counts retain first-joint-rejection precedence, so joint-rejection totals must not be added to infer link losses. Left elbow/wrist off-viewport9/8, right elbow/wrist0/5. All sampled numerical transform residuals are zero.

Right elbow/wrist refined→filtered median displacement .88/1.20px, p95s17.18/29.87px. The phase includes returning from the button to position; the peak representative is at+.957s, not a pure steady-hold sample. At+9.855s displacement is1.12/4.26px and at+19.888s .33/1.27px. Without a complete held-only fixture or video these are sampled settling observations, not jitter RMS or exact settling duration.

User confirmed End preview. The phone emitted `lifecycle_closed` at20:56:07.027; camera service recorded disconnect at20:56:07 and **Active Camera Clients: []**. Installed APK SHA remains `9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07`. No APK or production setting changed between the six bounded captures. This verifies close/camera release for this protocol; it does not replace the prior pause/background/logout lifecycle tests.

## Combined disposition and next experiment

| Bounded capture | Matched pose paints | Logical expiry episodes | CPU-confirmed blank episodes |
| --- | ---: | ---: | ---: |
| Still1 | 223 | 1 | 1 |
| Still2 | 226 | 0 | 0 |
| Slow | 221 | 6 | 1 |
| Fast | 223 | 2 | 0 |
| Top hold | 223 | 7 | 5 |
| Bottom hold | 221 | 0 | 0 |
| Total | 1,337 | 16 | 7 |

All16 episodes recovered; all began with explicit freshness expiry, a valid refined frame and33 accepted joints. CPU-confirmed blank spans were approximately12–51ms. The other nine clears were logical decisions without a blank CPU paint and cannot be called nine displayed blanks. Whole-pose detector-no-person, low-pose-presence, invalid ROI, nonfinite output, stale result, lifecycle invalidation, all-joint confidence rejection and clipping did not cause these bounded episodes. No capacity or transport censoring occurred. Prediction loss while leaving view **outside** the20s captures is excluded from this table. The table does not explain older videos' unpaired blanks.

The first verified whole-overlay failure stage is therefore the controller/watchdog clearing a still-valid pose at the frozen freshness limit, followed in seven cases by null/zero-primitive CPU composition. It is not a prediction disappearance in these samples. This identifies the immediate cause, but not why each result arrived late enough to cross the limit; native computation, preprocessing and host scheduling/input age remain contributors to investigate.

Same-input refined→filtered discrepancy is still verified: moving elbow/wrist median displacement grows from4.37/8.23px in slow to8.02/16.18px in fast. It is a signal effect, independent of the tiny filter execution duration. No sampled projection/painter binding residual was found. Partial elbow/wrist link failures correlate with per-joint presence/visibility rejection and off-viewport observations; they must not be pooled with the freshness episodes. These findings do not establish anatomical prediction accuracy.

**No new Step 2F video exists**, confirmed by the user after collection. Fresh displayed-camera C versus refined R crossing brackets cannot be measured from app timestamps. The retrospective screen-only control review remains the available external evidence: repeated visible mismatch, seven usable broad intervals all including zero and seven censored events. Thus upstream prediction/input-age mismatch is qualitatively present, but its positive minimum delay and dominance relative to filtering are unproven. No C→R number is manufactured, no telemetry stages are added together, and no total physical latency is claimed.

Proposed next **single-variable** experiment: interpreter thread count **2→4**, with beta .3, all cutoffs, assets/contracts, confidence/ROI cadence, resolution/transforms,250ms freshness, watchdog and backpressure unchanged. Hypothesis: native inference around50ms in the verified interior still windows is sufficiently material that a thread-count change may reduce computation/result age and the frequency of freshness clears. It does not address landmark prediction accuracy or filter dynamics directly. Official [LiteRT performance guidance](https://developers.google.com/edge/litert/conversion/tensorflow/build/best_practices#tweak_the_number_of_threads) supports measuring thread-count changes and warns that resource use and concurrent-work variability can increase. Four threads are a candidate, not an assumed improvement.

Preserve the current two-thread artifact as control; compare native/worker distributions, callback→UI/first CPU paint, drawable FPS, logical versus CPU-confirmed expiry, partial-link rejection and stationary reliability under the same conditions, including a sustained run for thermal variability. Revert if there is no meaningful improvement or stability worsens. A matched original screen video showing C, yellow R and green S would still be needed to assess visibly improved response. **This experiment has not been implemented.** Changing freshness instead would suppress clears without establishing a fresher prediction, so it is not the first proposed experiment.

Fresh verification after capture-button test addition: diagnostic-enabled affected mobile suite **38 passed**, shared pose suite **14 passed**, Python analysis parsers **17 passed**, mobile and shared-pose static analysis clean, `git diff --check` clean. The earlier complete mobile suite is recorded above separately. **Step2 quality acceptance remains unmet; Step3 is deferred.**

## Follow-up — Step 2G

After the user approved the next experiment, the isolated two→four-thread physical comparison was performed and **four threads were rejected**. Still computation improved slightly without reduced callback age; motion worker/paint ages increased and drawable FPS decreased. The exact two-thread control was restored on the phone and in source, with APK/hash verification. See [Step 2G report](2026-10-05-pose-interpreter-thread-experiment.md). No other tuning was stacked; the fresh C→R video boundary remains unresolved.
