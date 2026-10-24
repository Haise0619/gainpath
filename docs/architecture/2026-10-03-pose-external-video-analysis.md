# Step 2B: original second-camera video analysis

Analyzed on 2026-10-03 (Asia/Kuala_Lumpur). This adds evidence to the Xiaomi Step 2B quality report; it changes no app code, model asset, tensor contract, threshold, smoothing parameter, interpreter configuration or scheduling policy. Step 3 remains deferred.

## Source and measurement boundary

- Original: `C:/Users/Ngzhe/Downloads/VID_20261002_214318.mp4`, 169720641 bytes.
- SHA-256: `e74722fa965fcd7ad2f5936dca61a121cc4ad1e37831dc71d5d3e0ade2108514`.
- HEVC 3840×2160 stored with −90° display rotation; upright decoded image 2160×3840. Nominal rate approximately 60 FPS; stream reports 60.03 FPS. Container duration approximately 21.42 seconds.
- All 1286 video frames decoded. First presentation timestamp 0, last 21.406822 seconds. Adjacent timestamp differences 14.722–18.400 ms; calculations use presentation timestamps, not a presumed constant `frameIndex / 60`.
- Recording-device metadata identifies Xiaomi 17 / `25113PN0EG` / Android 16. This is the second camera, distinct from the tested GainPath phone Xiaomi `23013RK75C` / Android 13.

The recording clearly shows the GainPath phone's camera preview and overlaid skeleton. The physical person is outside the second camera's field of view: the body visible in the video is already the displayed camera image. Therefore this source measures **displayed camera-preview movement → displayed skeleton response**, not physical movement → camera display and not physical movement → skeleton display.

The filename and creation-time metadata are insufficient to align video presentation timestamps precisely with ADB log wall time. Individual video blanks are not assigned a pipeline reason using that guessed alignment.

## Arm-response observation

Four full arm raise/lower cycles are visible after the initial positioning. For each cycle, manually bracket when the screen-left wrist crosses approximately shoulder height in the camera preview and when its corresponding skeleton wrist does so. The reference follows the display plane/shoulder-height direction rather than the tilted recording's horizontal pixel row. Inspect native-rate frames around the crossing; use deliberately conservative brackets for blur, anatomical landmark ambiguity, stepped overlay updates and brief absent overlays. This is an approximate event measurement, not automated calibrated joint ground truth.

| Event | Preview crossing, video seconds | Skeleton crossing, video seconds | Conservative delay range |
| --- | ---: | ---: | ---: |
| Raise 1 | 3.715–3.815 | 3.965–4.065 | 150–350 ms |
| Lower 1 | 5.731–5.881 | 6.080–6.230 | 200–500 ms |
| Raise 2 | 7.580–7.680 | 7.830–7.980 | 150–400 ms |
| Lower 2 | 9.729–9.879 | 10.129–10.278 | 250–550 ms |
| Raise 3 | 11.628–11.778 | 11.978–12.078 | 200–450 ms |
| Lower 3 | 14.177–14.327 | 14.477–14.577 | 150–400 ms |
| Raise 4 | 16.142–16.292 | 16.442–16.592 | 150–450 ms |
| Lower 4 | 18.825–18.974 | 19.124–19.274 | 150–450 ms |

Interval midpoints are approximately 250–400 ms, with a median of approximately **300 ms**. These manually bracketed midpoints are a compact description of this clip, not a p50 telemetry statistic or a precisely calibrated latency benchmark. The frame sampling interval is about 16.7 ms, but manual interpretation adds substantially greater uncertainty; do not report millisecond precision on the response estimate.

Both arms repeatedly appear higher/lower in the camera preview before the skeleton follows the same direction. The skeleton broadly catches up when movement stops. This supports temporal lag as a substantial part of perceived moving-arm misalignment; no persistent global mirror reversal, rotation or cover-crop offset is apparent. It does not exclude landmark prediction error or quantify static anatomical accuracy.

Brief whole-skeleton blank intervals are also visually present while the camera preview continues to show the person, including near 6.13 and 14.23 seconds. A missing overlay makes the exact crossing time partially unobservable; the conservative event ranges retain that uncertainty. The separate controlled log captures already establish freshness expiry as a cause of full-body flicker, but this unsynchronized video alone cannot classify each blank as freshness, model absence, visibility rejection or lifecycle invalidation.

Two inspected blank episodes span frames 367–370 and 854–857: four consecutive video samples lack the skeleton and neighboring samples show it. Presentation-time bounds put each visible interruption at approximately 50–83 ms, allowing uncertainty between the last visible/first blank and last blank/first visible samples. A local green-pixel check agrees with the inspected frames (zero matching pixels in those four samples versus hundreds/thousands in neighboring visible frames). This is a display observation, not a pipeline health classifier; recorded-display scan/rolling shutter can affect interval edges. Other low-color frames during setup/approach are not treated as full-body stability measurements.

## Relation to the earlier instrumentation

The separate 60-second front profile baseline measured approximately 124 ms worker computation and 154 ms camera-callback-to-first-CPU-paint age at 7.9 delivered FPS. Those metrics have different boundaries from this video's approximately 300 ms preview-to-skeleton gesture response. Do not add them, subtract them to invent a filtering latency, or relabel either as physical camera-to-display latency.

Processing input age, delivered frame cadence, One Euro signal delay and landmark prediction can all contribute to the visible response. A filtering computation time of approximately 0.14 ms measures CPU work, not the low-pass filter's signal lag. Earlier matched traces cover shoulders, hips, knees and ankles, not wrists/elbows; this clip cannot isolate wrist smoothing from raw prediction. Before tuning One Euro parameters, add timestamp-matched raw/refined/filtered wrist and elbow observation or a controlled filtering replay, with the same models and pipeline settings.

The evidence-led first optimization candidate remains deterministic preprocessing, which consumed approximately 54 ms per processed frame in the front profile baseline. Re-measure the same gestures and explicit expiry counters after any single equivalent optimization. Do not concurrently tune thresholds, model variant, freshness or smoothing to hide the symptom.

## Acceptance and remaining capture

The user designated this clip as the pre-optimization **preview-to-skeleton response baseline only**. A new original 60 FPS-or-higher video will include the physical person and display together. The [Step 2C comparison protocol](2026-10-03-pose-preprocessing-optimization.md) defines all three latency boundaries and conservative interval calculation; the existing clip cannot supply its missing physical stages.

Step 2B remains unaccepted: the prior controlled baseline has 99 nonempty expiries in 60 seconds, and moving-arm response remains visibly delayed. This recording supplies useful independent preview-to-overlay evidence, but physical camera-to-preview and physical movement-to-skeleton delay remain unmeasured.

For the missing physical measurement, place the second camera diagonally to the side so **the actual moving arm/body and the GainPath phone display appear simultaneously in the same frame**, with sufficient screen detail. Use 60 FPS or higher, a fixed camera, good light and several distinct arm movements. A short sample can confirm framing before recording all gestures. Match physical, displayed-camera and displayed-skeleton events using that one recording's timestamps; report interval uncertainty and display scan/rolling-shutter limitations. No new app behavior is required for this capture.

Local inspection artifacts under ignored `apps/mobile/build/pose-quality/`: native-rate `external-frames/frame-NNNN.jpg`, exact PTS log, timeline and crossing contact sheets, and `external-video-event-summary.json` with frame-index/time brackets. The original video is unchanged. These artifacts are local analysis; the app does not upload or persist camera recordings.
