# Step 2J — held placement versus temporal response

## Decision

Retain Step 2I and beta 0.3. The strongest directly verified added delay remains **refined coordinates → One Euro filtered coordinates**. The new offline probe confirms that increasing sample cadence from approximately 11 to 14 FPS does not remove this filter's signal delay. Constant and settled coordinates are preserved, so a persistent anatomical offset after a genuinely stationary hold would need investigation upstream of filtering or in the geometric transform.

The existing footage does **not** establish such a persistent anatomical offset accurately enough to justify changing projection, models or ROI handling. It also cannot quantitatively rank input/prediction delay against filtering. There is no production parameter change, APK build/install or new physical measurement in this step. Step 2 quality acceptance remains pending; Step 3 remains deferred.

This was an offline diagnostic spike using the existing videos and production filter. The only new executable source is `apps/mobile/tool/pose_filter_response_probe.dart`; it cannot ingest camera data, submit workouts or modify production configuration.

## Sources and coordinate boundaries

Use the preserved [Step 2I screen comparison](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-step2i-screen-comparison.md) and [Step 2D timestamp-matched diagnostics](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-03-pose-dynamic-joint-lag.md). The two Step 2I originals and full decoded PTS tables remain the video authority. This review does not create additional C→R or C→S timing samples from uncertain shoulder-level peaks.

The eight representative frames below use the original decoded PTS. Frame numbering is zero-based; crop filenames are frame+1. R is the yellow refined ring; S is the magenta filtered dot bound to the accepted green skeleton. All screenshot separations are measured **in the same 600×700 decoded external-video crop**, whose origin is (300,380) after scaling the upright recording to 1080×1920. They are not source camera pixels, normalized pose coordinates or painter canvas pixels.

Color masks within manually selected joint windows estimate ring/dot centers. A conservative analyst allowance of ±6 crop pixels per center gives separation ranges rounded outward; these are not statistical confidence intervals. Exposure/phone scan, JPEG decoding, doubled markers and window selection limit the estimates. Screenshot R/S samples are simultaneous recorded pixels, not new timestamp-matched input-frame records. No screenshot is assigned a pose input timestamp from approximate badge time.

| Clip / visual phase | Frame / actual PTS seconds | R–S elbow separation, crop px | R–S wrist separation, crop px |
|---|---|---:|---:|
| Control slower raise | f347 / 5.847356 | 7–32 | 25–50 |
| Candidate slower raise | f340 / 5.681789 | 8–33 | 25–50 |
| Control faster raise | f1496 / 25.027733 | 8–33 | 26–51 |
| Candidate faster raise | f1486 / 24.889800 | 13–38 | 29–54 |
| Control top hold | f1980 / 33.108633 | 0–18 | 0–14 |
| Candidate top hold | f1800 / 30.138411 | 0–14 | 0–15 |
| Control bottom hold | f2460 / 41.123333 | 0–15 | 0–15 |
| Candidate bottom hold | f2100 / 35.152522 | 0–13 | 0–13 |

These selected frames show clearly separated R/S wrist positions during raises and convergence compatible with zero separation during holds. They are not matched motion trials between builds or displacement distributions. The [bounded evidence sheet](C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2j/held-vs-motion.jpg) puts motion and hold observations together.

During raising, the camera arm is higher than R and S; during lowering, the discrepancy reverses, as previously reviewed. That direction-dependent behavior plus hold convergence supports a temporal component. Shoulders/torso broadly align in both holds, and wrist rings are near the visible wrist/cuff region. The anatomical elbow center lies under a loose sleeve, and the person and recording phone move slightly. **No defensible anatomical elbow error in pixels, static camera→R bias or calibrated jitter statistic is claimed.** These observations do not prove perfect landmark accuracy or rule out smaller geometric/prediction errors.

Existing Step 2D samples remain the stronger same-input evidence: the top raise's accepted elbow R→S bracket is 73.617–236.864 ms, wrist 96.905–238.350 ms, with no freshness reset between the paired crossings. Held samples converge to subpixel differences. Their exact mirror/cover binding closes within floating-point roundoff. Neither those input-clock intervals nor screenshot positions supply total physical latency.

## Unchanged production filter replay

The new CLI probe calls the actual `PoseFrameFilter` and actual `PreviewProjection`. It changes no filter implementation or parameters. Synthetic left elbow/wrist trajectories are upright unmirrored normalized image coordinates, with confidence/presence 1, converted to image displacement using the fixture's 480×720 dimensions.

One continuous trajectory is sampled twice: nominal 11.08 FPS and 13.68 FPS, with a fixed ±3% cadence variation and rounded integer microsecond timestamps. These cadence labels approximate the previous telemetry means; they are **not replayed phone frame timestamps**. Slow raise/lower each takes 3 s; fast each takes 0.6 s, separated by holds of at least 2 s. Both runs sample the same time-based motion rather than changing movement duration with frame count. All trajectories are synthetic, bounded in memory and omitted from output; only aggregates/crossing brackets are saved.

Parameters remain beta 0.3, minCutoff 1, derivative cutoff 1; no reset or low-confidence rejection occurs in the probe. Results:

| Synthetic metric, 720-high image px | 11.08 FPS | 13.68 FPS |
|---|---:|---:|
| Slow raise elbow p95 R–S displacement | 18.47 | 18.20 |
| Slow raise wrist p95 R–S displacement | 24.27 | 23.86 |
| Fast raise elbow p95 R–S displacement | 69.99 | 68.36 |
| Fast raise wrist p95 R–S displacement | 88.24 | 85.88 |

At 13.68 FPS, synthetic slow-raise elbow and wrist R→S crossing enclosures are approximately **75–220 ms** and **73–220 ms**, respectively, rounded outward to whole ms. The source brackets and all raise/lower events are preserved in `step2j/crossing-brackets.json`. Several other enclosures include zero because crossing times are only bounded by adjacent samples; they are not exact delays. No interpolation or averaging of these brackets creates a more precise response time.

For this deliberately large synthetic fast raise, elbow/wrist residual drops below **one image pixel and stays below it** between approximately 654 and 728 ms after the known hold begins at 13.68 FPS. At 11.08 FPS the corresponding ranges are approximately 657–751 ms elbow and 750–841 ms wrist. This is a stringent settling criterion on an artificial trajectory, **not 0.7 s phone latency, first response time or measured human hold settling**. End-of-hold residuals are below 0.002 px in both runs.

Independent checks passed:

- A constant input with a deliberately artificial 0.04 normalized offset stays constant to ~2.8×10⁻¹⁷ normalized units. That artificial 28.8 px offset is not an observed human error. Filtering preserves static bias rather than correcting it.
- Adding the same constant coordinate offset to a moving input and comparing filtered outputs gives ~2.6×10⁻¹⁶ normalized residual. Thus this filter does not invent a permanent displacement from coordinate translation.
- The exact preview affine transform, with mirroring both off and on, maps R–S displacement within ~1.3×10⁻¹³ px of its analytic scale. It scales/reflects a displacement; it has no temporal history. This verifies the probe's geometric relation, not the phone's unknown anatomical ground truth.
- Four crossings per stage/joint, finite samples and final hold convergence are checked explicitly. Two complete executions produced equal aggregate JSON.

Increasing sampling cadence is beneficial for computation/delivery but leaves similar synthetic filter displacement. This explains why a real computation gain can coexist with an inconclusive visible-lag comparison. It does not attribute all remaining camera→skeleton delay to filtering or predict a particular human improvement from any new parameter.

## Next isolated experiment

The next useful experiment is a **diagnostic full-skeleton filter ablation**, rather than another sampler change or blind parameter increase:

1. Preserve the installed Step 2I control and its APK/hash.
2. In a separate development-only artifact, select the same-timestamp refined frame as the primary skeleton drawing source. Keep the existing filter running in shadow and show its filtered elbow/wrist markers. Clearly label the display `refined / unfiltered diagnostic`; default builds keep the current filtered display.
3. Retain the exact confidence acceptance, projection, timestamps, scheduling, models, thresholds, cadence, threads, resolution, freshness and lifecycle behavior. Do not feed diagnostic coordinates into workout activity. Invalid/mismatched/expired refined frames must never be displayed.
4. Compare the camera arm against the fully legible refined skeleton and its filtered markers during one-arm slow/fast motion and holds. Use an unobscured elbow and a clear above/below-shoulder excursion, with a torso-relative plane. Retain C→R and R→S as separate boundaries; censor ambiguous/missing events.

This changes only the **diagnostic drawing source**, not One Euro settings or the production pipeline. It tests the maximum visible benefit of removing added filter delay while revealing the unsmoothed prediction's jitter and remaining camera→R mismatch. Yellow rings already establish a filter contribution; the full refined skeleton makes camera/upper-arm angle and held stability easier to judge than faint isolated rings. It is not a production candidate or an acceptance shortcut.

If the refined skeleton follows the camera promptly but shakes, a subsequent single-variable filter experiment becomes justified with explicit motion/stability targets. If refined motion still trails materially, investigate source-frame age/prediction/ROI before another smoothing change. This ablation is **specified, not implemented or installed in Step 2J**. No beta 0.6 retry, minCutoff change, model switch or freshness extension is made here.

Whole-overlay blanking remains a separate reliability issue. Step 2I's two externally sampled control blanks and its associated freshness-clear family are preserved; no new blank events are measured in this analysis. Existing per-joint confidence rejection and whole-pose freshness expiry must remain separate from filter delay.

## Reproduction and verification

From the repository root:

```powershell
& C:/flutter/bin/cache/dart-sdk/bin/dart.exe --packages=.dart_tool/package_config.json apps/mobile/tool/pose_filter_response_probe.dart
```

Local ignored evidence lives in `apps/mobile/build/pose-quality/step2j/`: aggregate probe JSON and equal repeat, crossing bracket arithmetic, eight-frame visual review and contact sheet, review script and integrity manifest. The script verifies every one of the 181 existing Step 2I production source/asset manifest entries unchanged. The new probe is tool/debug scope only.

Fresh verification on 2026-10-06: probe analysis **no issues**, deterministic checks pass, **20 affected mobile tests pass** with quality/joint-lag/blank diagnostics enabled (filter replay, preview controller, real painter composition and geometry). Existing production files were not modified. No physical lifecycle retest or new device-performance result is claimed. The initial sandbox Dart failure and an incorrect app-local package-config path were resolved by using the installed SDK with the workspace root package configuration; neither was an application test failure.
