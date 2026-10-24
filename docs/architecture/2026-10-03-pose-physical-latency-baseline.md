# Step 2B: pre-optimization physical latency video baseline

Analyzed locally on 2026-10-03. This is the user's designated pre-optimization physical baseline. The optimized Step 2C APK has not been installed or evaluated. No application code or pipeline setting changes in this analysis.

## Original and preservation

- Source: `C:/Users/Ngzhe/Downloads/step2b_physical_latency_baseline_60fps.mp4`, 98624651 bytes.
- SHA-256: `e2570403f10a14959334ef5fccec60db44087555a00a10652dd83183ec895b25`.
- A byte-identical original copy is preserved at `apps/mobile/build/pose-quality/physical-baseline/original.mp4`. Both source and copy hashes were checked after analysis. These artifacts are local and ignored by Git; no video was uploaded.
- HEVC, stored 3840×2160, −90° display rotation; upright image 2160×3840. Container duration approximately 12.64 seconds. Recording metadata identifies Xiaomi 17 / 25113PN0EG / Android 16, distinct from the GainPath Xiaomi 23013RK75C.
- Nominal 60 FPS, measured stream rate approximately 59.89 FPS. All 757 frames were decoded in presentation order without forcing constant-rate resampling. Zero-based frames 0–756 have PTS 0–12.623678 seconds.
- Adjacent PTS spacing is approximately 13.8–33.3 ms. Three spacings exceed 25 ms, after frames 578, 654 and 730. Event calculations use the actual PTS, not `frame/60`; the four measured arm events occur before these longer spacings.

The mirror shows the actual person independently of the phone's displayed camera image. The same recording also shows the displayed skeleton. This supplies all three observable boundaries on one video timeline. Phone/build identity is carried from the user's pre-optimization capture designation and the preserved Step 2B profile workflow; video pixels alone do not verify an APK hash or runtime tensor contract.

The preserved Step 2B profile APK remains SHA-256 `502e6ed53b9a0c2cb0eae0b9c7c0798b436bbf393434267fc7651a4ba6c08cc5`. No ADB install, app launch or telemetry alignment was used for this analysis.

## Event definition and conservative brackets

There are two arm raise/lower cycles. The mirror frame partly hides the moving wrist, so the repeated reference is the **visible moving elbow/upper arm passing approximately shoulder level**, relative to the person's local shoulder/torso orientation. P is that physical crossing in the mirror; C is the corresponding crossing in the displayed camera image; S is the corresponding skeleton elbow/upper-arm crossing. Follow the same moving arm through both views, rather than assigning its anatomical side from the recording's left/right alone.

This is a manual gesture-response estimate, not calibrated 3D joint ground truth. Shoulder position under the loose shirt, elbow blur, different mirror/camera perspectives, handheld camera tilt, screen perspective, scan/rolling shutter and stepped skeleton updates all widen the brackets. A projected shoulder-level crossing can differ slightly between viewpoints even at the same physical instant. The bounds intentionally cover ambiguous shoulder/elbow positions; they must not be narrowed to manufacture a positive camera delay.

The later crouch/stand motion is retained in the original but excluded from numerical event aggregation: the recording camera moves with the person's hand, the physical lower body is partly occluded by the foreground, and the screen traverses the recording. An absolute head-height crossing in those frames would mix body motion with camera motion. It is not a second calibrated latency trial.

Frame ranges are authoritative. The accompanying time ranges below are rounded to hundredths for navigation; calculations retain the actual timestamp anchors in the local JSON.

| Repeated event | P: physical frame bracket / seconds | C: displayed camera bracket / seconds | S: skeleton bracket / seconds |
| --- | --- | --- | --- |
| Raise 1 | 80–92 / 1.33–1.53 | 86–101 / 1.43–1.68 | 107–122 / 1.78–2.03 |
| Lower 1 | 180–204 / 3.00–3.39 | 198–214 / 3.29–3.56 | 214–244 / 3.56–4.06 |
| Raise 2 | 312–324 / 5.19–5.39 | 320–332 / 5.32–5.52 | 340–358 / 5.65–5.95 |
| Lower 2 | 442–456 / 7.35–7.58 | 454–470 / 7.55–7.82 | 472–490 / 7.85–8.15 |

Lower 1 is **censored**: the moving-arm links become missing/indistinct while torso and leg links remain visible. For example, frames 218–230 show the physical and camera-image arm moving with no clearly traceable matching skeleton elbow; frame 244 clearly shows the skeleton arm below shoulder level. The wider S bracket retains that uncertainty instead of interpolating a crossing through invisible links. Raise 2 includes the brief whole-overlay blank described below.

For P=`[p0,p1]`, C=`[c0,c1]`, S=`[s0,s1]`, compute P→C=`[c0-p1,c1-p0]`, C→S=`[s0-c1,s1-c0]`, P→S=`[s0-p1,s1-p0]`. The total is calculated directly, not by adding two independent ranges and double-counting C uncertainty.

The following bounds are rounded **outwards** to tenths of a second. They are conservative event ranges, not precise milliseconds, confidence intervals or p50/p95 telemetry statistics.

| Event | Physical → camera preview (P→C) | Camera preview → skeleton (C→S) | Physical → skeleton (P→S) |
| --- | ---: | ---: | ---: |
| Raise 1 | −0.1 to +0.4 s | 0.0–0.6 s | 0.2–0.7 s |
| Lower 1, censored | −0.1 to +0.6 s | 0.0–0.8 s | 0.1–1.1 s |
| Raise 2 | −0.1 to +0.4 s | 0.1–0.7 s | 0.2–0.8 s |
| Lower 2 | −0.1 to +0.5 s | 0.0–0.7 s | 0.2–0.8 s |

A negative P→C lower bound does **not** mean the preview anticipates physical motion. It means the ambiguous event brackets overlap, so this recording cannot establish a strictly positive minimum for that boundary. Keep the signed uncertainty rather than clipping it and calling the result a measured zero latency.

The uncensored events' physical-to-skeleton interval midpoints are roughly half a second, with substantial uncertainty. That is a descriptive gesture-response observation, not a precise mean or p50. Physical-to-preview response is less tightly resolved. The camera-to-skeleton response remains visibly delayed; it includes prediction/filter signal response and presentation cadence, not only CPU computation. The censored lower event must not become a precise crossing sample in a later before/after average.

## Visible overlay interruption

At least one whole-skeleton blank is directly confirmed while the physical person remains visible and the camera preview continues showing the raised arm:

| Observation | Original frames / PTS |
| --- | --- |
| Last neighboring visible skeleton | 354 / 5.887711 s |
| Whole skeleton absent | 355 / 5.904344 s |
| First neighboring visible skeleton | 356 / 5.920978 s |

The disappearance starts between frames 354–355 and ends between 355–356. With no subframe exposure/display timing, duration is conservatively **0 to approximately 0.04 seconds**, spanning at most roughly two video-frame intervals. One recorded blank frame does not establish an exactly 16.7 ms app outage. Screen scan and exposure can affect the edges. The standalone video does not identify whether this is freshness expiry, confidence loss, visibility rejection or another pipeline state; no unsynchronized log is used to assign a cause.

Moving-arm link loss during Lower 1 is separate from this whole-overlay blank: torso/legs remain drawn and the camera still shows the arm. It widens the event bracket but is not counted as whole-pose loss. This small clip does not establish stable continuous tracking, a dropout rate or endurance acceptance.

A cyan-pixel screen scan was used only to nominate frames for visual inspection. Frame 355 has zero qualifying pixels and visual absence; frame 47 also has zero qualifying pixels but the skeleton is plainly present in the native crop, so that candidate was rejected. Overexposure/white balance makes a color count unsuitable as a definitive renderer-health classifier. The interruption above is a confirmed observation, not a claim that every possible subframe or faint-link interruption has been exhaustively classified.

## Boundaries and matched comparison

No callback-to-paint, native inference or other telemetry was added to or subtracted from these video measurements. This clip measures physical gesture and visible display response, not sensor exposure time or the internal worker stages. The [earlier display-only video](2026-10-03-pose-external-video-analysis.md) remains preview-to-skeleton evidence only; it cannot supply missing stages for this recording or sharpen its uncertainty.

This baseline is preserved before installation. The [Step 2C implementation and repeat protocol](2026-10-03-pose-preprocessing-optimization.md) retain model assets, tensor contracts, interpreter settings, thresholds, One Euro parameters, resolution, freshness and backpressure. The next comparison should use the optimized profile APK with the same mirror geometry, camera/display framing, moving arm, lighting, warm-up and motion pace as approximately as possible. Keep the recording phone steady and the moving elbow visible. Use a fresh app/preview session and keep IDE Run stopped.

Repeat the same crossings and retain ambiguous/censored samples with their reasons. Compare event brackets on each video's own actual presentation timeline; do not assume matching frame numbers or convert the nominal frame rate into exact timing. Compare clearly observable events first. A shorter midpoint with overlapping conservative ranges is inconclusive evidence of physical improvement. Instrumented compute/FPS/expiry checks remain a separate matched run.

Local evidence under ignored `apps/mobile/build/pose-quality/physical-baseline/`: preserved original; complete `frame-pts.log` and `pts.json`; 757 upright overview frames; native-resolution phone crops (wider crops follow the late handheld movement); overview and crossing/blank contact sheets; `manual-event-brackets.json`; `baseline-summary.json`; and candidate-only `overlay-color-counts.json`. No optimized APK has been installed during this task. Step 3 remains deferred.

The inspected `confirmed-blank-triptych.png` places original frames 354/355/356 side by side, with physical mirror movement above the corresponding displayed camera/overlay crop. Final checks verified all 757 ordered timestamp/crop pairs, independent P/C/S interval arithmetic, outward-rounded bounds and byte-identical source preservation. `git diff --check` passed; application tests are not rerun for this document-only analysis.
