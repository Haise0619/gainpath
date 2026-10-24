# Step 2C: Xiaomi physical comparison

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Analyzed on 2026-10-03. Step 2C shows measured improvement in phone computation, throughput and expiry frequency relative to the preserved Step 2B profile run. The external video does **not** establish a reduction in physical gesture-to-skeleton response: conservative event intervals overlap substantially, moving-arm lag remains visible and arm links become missing/indistinct during several descents. Step 2 quality acceptance remains **not passed**. Step 3 stays deferred.

This task changes documentation and local analysis artifacts only. It performs no APK installation, app restart, log clearing, pipeline tuning or product change.

## Original video and build provenance

- Source: `C:/Users/Ngzhe/Downloads/step2c_physical_latency_optimized_60fps.mp4`, 105355728 bytes.
- SHA-256: `752face4fb6df0b524ab187d356a21ceae14ec846e77aa54a184098ceb5402c5`.
- Byte-identical copy: `apps/mobile/build/pose-quality/physical-optimized/original.mp4`; original and copy were rehashed after analysis. The [baseline](2026-10-03-pose-physical-latency-baseline.md) source and preserved copy also retain SHA-256 `e2570403f10a14959334ef5fccec60db44087555a00a10652dd83183ec895b25`.
- HEVC, stored 3840×2160 with −90° display rotation; upright 2160×3840. Container duration about 13.42 seconds. Nominal 60 FPS, stream rate approximately **60.05 FPS**.
- **806 decoded presentation frames**, zero-based 0–805, actual PTS **0–13.4054 seconds**. Adjacent spacing 0.014933–0.033245 seconds; one spacing above 25 ms after frame 151. Decoding used passthrough presentation order, without constant-FPS resampling. Every frame has an original PTS and native-resolution phone crop.
- Recording metadata: Xiaomi 17 / 25113PN0EG / Android 16; creation 2026-10-03T09:30:13Z. This is the external recording phone, distinct from the GainPath Xiaomi 23013RK75C. Metadata time is not a synchronized video-to-log anchor.

The user confirmed installing with the documented ADB command. Read-only ADB retrieval from Xiaomi 23013RK75C / serial xiaomi-device-serial-redacted returned the installed `com.zyang.gainpath` APK. Its 146887038-byte SHA-256 is **`bce7c611c493747dc3a8731c76508310c324aa1aae90c2393937c2afd5d318b4`**, exactly matching the preserved **Step 2C optimized profile APK**. Package lastUpdateTime is 2026-10-03 16:49:25 local, before the recording's metadata time. Together, user capture designation, installation confirmation, installed byte identity and package chronology corroborate the tested build; video pixels alone cannot identify an APK.

The fresh logged PID 6560 / session `1791019747934164` starts at 17:29:07.934 with `uninitialized → session_created` and zero-origin diagnostics. Its metrics report `runtimeTensorContractVerified: true`, model `mediapipe-full-e9a5c5cb-det-9ba9dd3d`, front YUV420 720×480, rotation 270°, preview 480×720, and repeated 33-landmark results. Earlier PID 6556 lacks a retained creation record and is excluded from the primary comparison; PID 6559 is a separate background/reopen session.

Model bytes were independently compared **inside the baseline, optimized and installed APKs**: detector `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c`, landmark full `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f`. All match. The packaged preprocessing source still hashes to `1bf8e9011900202436f3dd2a0c562a33dff0e6834a0c303ce262d6c4a0ba040c`.

The [bounded implementation](2026-10-03-pose-preprocessing-optimization.md) changes preprocessing only. Model/tensor contracts, 0.5 acceptance checks, two interpreter threads, detector cadence of 15 ROI frames or loss, One Euro minCutoff 1 / beta 0.3, resolution, mirroring/projection, 250 ms freshness budget / 100 ms watchdog and one-active/one-replaceable-pending policy remain unchanged between the preserved builds. No settings were changed during this comparison. The installed hash identifies that frozen profile artifact, not an IDE replacement.

## Event definition and actual presentation brackets

Use the baseline's **moving elbow/upper arm crossing approximately shoulder level**, relative to local torso orientation: P in the physical mirror image, C in the displayed camera image, S in the skeleton. Do not use wrist height, screen-horizontal coordinates or anatomical side inferred from mirror left/right. Original frame indices are authoritative; displayed seconds below are rounded to hundredths for navigation. Local JSON retains full PTS anchors.

Mirror geometry, a loose shirt, differing projected shoulder/elbow positions, screen perspective, handheld movement, motion blur, screen scan/rolling shutter, stepped overlay updates, exposure and autofocus all widen the bounds. The optimized recording has five cycles rather than two, generally faster motion and softer/occasionally washed-out screen detail. It is approximately matched, not a controlled statistical trial.

| Event | P frames / seconds | C frames / seconds | S frames / seconds |
| --- | --- | --- | --- |
| Raise 1 | 36–48 / 0.60–0.80 | 44–60 / 0.73–1.00 | 60–80 / 1.00–1.33 |
| Lower 1 † | 114–130 / 1.90–2.16 | 122–140 / 2.03–2.33 | 132–168 / 2.20–2.81 |
| Raise 2 | 202–218 / 3.38–3.64 | 212–228 / 3.54–3.81 | 228–250 / 3.81–4.17 |
| Lower 2 † | 278–294 / 4.64–4.91 | 286–304 / 4.78–5.07 | 298–334 / 4.97–5.57 |
| Raise 3 | 378–398 / 6.30–6.64 | 388–406 / 6.47–6.77 | 404–428 / 6.74–7.14 |
| Lower 3 † | 470–486 / 7.83–8.10 | 478–498 / 7.97–8.30 | 486–520 / 8.10–8.67 |
| Raise 4 ‡ | 552–568 / 9.20–9.46 | 556–576 / 9.26–9.60 | 570–590 / 9.50–9.83 |
| Lower 4 | 604–620 / 10.06–10.33 | 610–626 / 10.16–10.43 | 616–638 / 10.26–10.63 |
| Raise 5 | 680–696 / 11.33–11.59 | 688–706 / 11.46–11.76 | 708–734 / 11.79–12.22 |
| Lower 5 † | 768–788 / 12.79–13.12 | 778–800 / 12.96–13.32 | 790–805 / 13.16–13.41 |

† **Censored by missing/indistinct arm traces**, not precise crossing samples. Lower 1: trace unclear around 138–156, below shoulder by 168. Lower 2: unclear around 306–316, below by 334. Lower 3: faint/overexposed around 494–510, below by 520. Lower 5: blurred near crossing; below-level trace at final frame 805, with no post-event hold recorded. These bounded crossings are retained with uncertainty; no interpolation through invisible links and no normal-sample average. The video cannot distinguish visibility rejection from faint rendered links or recording exposure in those frames.

‡ Raise 4 starts with a bent arm in front of the torso. Its approximate elbow crossing is retained as **variant/ambiguous**, excluded from the matched straight-arm comparison. Lower 4 is a recognizable straightened descent, but has no corresponding extra baseline repetition. The fifth descent is not assumed to have an observable later settling time after the recording ends.

For P=`[p0,p1]`, C=`[c0,c1]`, S=`[s0,s1]`, calculate P→C=`[c0-p1,c1-p0]`, C→S=`[s0-c1,s1-c0]`, and P→S=`[s0-p1,s1-p0]` directly. Do not add two independent ranges and double-count C. The following ranges are rounded **outwards to 0.1 seconds** from actual PTS, not nominal `frame/60`.

| Event | P → C | C → S | P → S |
| --- | --- | --- | --- |
| Raise 1 | −0.1–0.4 s | 0.0–0.6 s | 0.1–0.8 s |
| Lower 1 † | −0.2–0.5 s | −0.2–0.8 s | 0.0–1.0 s |
| Raise 2 | −0.1–0.5 s | 0.0–0.7 s | 0.1–0.8 s |
| Lower 2 † | −0.2–0.5 s | −0.1–0.8 s | 0.0–1.0 s |
| Raise 3 | −0.2–0.5 s | −0.1–0.7 s | 0.0–0.9 s |
| Lower 3 † | −0.2–0.5 s | −0.2–0.7 s | 0.0–0.9 s |
| Raise 4 ‡ | −0.2–0.4 s | −0.1–0.6 s | 0.0–0.7 s |
| Lower 4 | −0.2–0.4 s | −0.2–0.5 s | −0.1–0.6 s |
| Raise 5 | −0.2–0.5 s | 0.0–0.8 s | 0.1–0.9 s |
| Lower 5 † | −0.2–0.6 s | −0.2–0.5 s | 0.0–0.7 s |

Negative bounds reflect overlapping ambiguous crossings, not negative causal latency or anticipation. This footage cannot resolve a strictly positive minimum for those boundaries. They are manual conservative gesture-response ranges, not confidence intervals, precise milliseconds or p50/p95 statistics.

## Comparison and visual quality

The baseline Raise 1/2 P→S bounds are 0.2–0.7 / 0.2–0.8 s; optimized Raise 1/2 are both 0.1–0.8 s. Baseline C→S is 0.0–0.6 / 0.1–0.7 s; optimized is 0.0–0.6 / 0.0–0.7 s. **Substantial overlap prevents a demonstrated reduction.** The other uncensored optimized raises remain consistent with a several-tenths-of-a-second response. Do not convert a midpoint difference into a percentage speedup.

All P→C, C→S and P→S intervals overlap their same-order baseline counterparts in the first two cycles; optimized-minus-baseline intervals include zero. Lower 1 is censored on both recordings; optimized Lower 2 is censored although baseline Lower 2 was observable. They cannot establish faster response through an invisible crossing. Extra cycles corroborate persistent lag but do not become extra independent baseline pairs or a normal-sample average.

The moving physical/preview arm clearly advances ahead of the bright skeleton arm on repeated raises. Several descents show a displaced arm trace extending outward after the preview arm has lowered, followed by faint or indistinct links. Visible moving-arm lag is **not clearly reduced**. Faster movement can exaggerate spatial separation for the same delay; neither clip supplies calibrated angular-speed control.

No whole-skeleton blank interval was visually confirmed in this optimized recording. Candidate low-color frames 496, 500 and 504–507 retain visible face/torso/leg links under severe screen overexposure; they are **rejected as whole blanks**. The physical person and preview remain visible. In contrast, baseline frame 355 is a confirmed whole blank bounded to 0–approximately 0.04 s. This does not establish that optimized interruptions were eliminated: the short recording, faint screen detail and subframe sampling do not prove uninterrupted rendering. Color counts nominate inspection candidates only; they are not a tracking-loss classifier.

Shoulders and torso generally attach to the displayed body when motion is limited; the hip rectangle and leg chains remain broadly placed over the body. No obvious persistent reflection or gross cover-crop offset is demonstrated. The moving shoulder/elbow/wrist chain is visibly displaced during motion, so dynamic anatomical alignment is not accepted. Knees/ankles are too small/soft and partly covered by the preview status panel for precise evaluation. The physical mirror lower body is foreground-occluded. This is a front-camera arm-response recording, not a replacement for controlled full-body or side-on squat alignment. It cannot isolate prediction, temporal filtering and projection error by itself.

## Separate phone telemetry comparison

Existing device logcat was preserved without clearing or restarting. Primary optimized window: **17:29:12.936–17:30:12.938**, approximately 60 active seconds, PID 6560, same freshly created session. It starts after the first periodic snapshot. Compare with the preserved 60-second front-camera Step 2B profile window (PID 5179 / session `1790947204385817`). Optimized posture/lighting/thermal state during this logged minute are not independently annotated; this is an observational before/after comparison, not a randomized or A/B causal estimate.

Means use differences of cumulative sums (`count × mean`) and sample counts between window snapshots, rather than subtracting means or mixing sessions. Periodic lines can straddle a result by milliseconds; the secondary window exposes that boundary uncertainty. Rate means cover approximately five-second active intervals. No malformed diagnostic JSON was encountered. Rolling p95 is not a whole-window p95 and is not differenced.

| Metric | Step 2B | Step 2C | Boundary |
| --- | ---: | ---: | --- |
| Camera received FPS | 30.02 | 30.02 | Application callbacks |
| Processed FPS | 7.95 | 11.40 | Includes empty results |
| Delivered result FPS | 7.90 | 11.40 | Includes empty results |
| Drawable/nonempty FPS | 7.90 | 11.17 | Accepted landmark results |
| Detector preprocessing | 29.50 ms | 21.27 ms | Per detector call: 32 / 59 calls |
| Detector native inference | 48.15 ms | 35.52 ms | Per detector invoke |
| Detector decode / ROI | 0.23 ms | 0.16 ms | Per detector decode |
| Landmark preprocessing | 52.30 ms | 34.28 ms | Per landmark call: 477 / 672 calls |
| Landmark native inference | 65.32 ms | 48.08 ms | Per landmark invoke |
| Landmark postprocess/refinement | 0.60 ms | 0.49 ms | Per landmark decode |
| Total preprocessing | 54.28 ms | 35.51 ms | Per processed frame: 477 / 684 |
| Total native inference | 68.55 ms | 50.30 ms | Per processed frame |
| Worker computation | 123.68 ms | 86.49 ms | Prep + inference + worker decode/overhead |
| Queue age | 17.29 ms | 16.09 ms | Pending input age at worker start |
| Camera copying | 0.85 ms | 0.71 ms | Per received callback |
| Filtering CPU time | 0.14 ms | 0.11 ms | Execution cost, not filter signal delay |
| Input-to-UI age | 141.95 ms | 103.83 ms | From owned frame timestamp |
| Callback-to-UI | 142.68 ms | 104.47 ms | Application callback to UI delivery |
| Pose age at first paint | 153.06 ms | 114.43 ms | Owned frame to first CPU paint |
| Callback-to-first-paint | 153.80 ms | 115.08 ms | CPU painter invocation, not display-present |
| Replaced pending inputs | 1324 | 1117 | Expected latest-frame replacement |
| Stale-result discards | 3 | 0 | Neither equals overlay expiry |
| Delivered empty poses | 0 | 14 | 12 detector-no-person + 2 low pose-presence |
| Nonempty overlay expiries | 99 | 5 | Expired prior drawn pose |
| Empty-frame expiries | 0 | 0 | Separate from nonempty expiry |

Observed total preprocessing is about **35% lower**, worker computation **30% lower**, callback-to-first-paint **25% lower**, and drawable delivery **41% higher**. Nonempty expiries are substantially less frequent, but not zero. Native inference is also approximately 27% lower even though models/threads are unchanged: thermal state, scheduling/load and different invocation/content mixes can affect results. Therefore these percentages describe these logged windows; the preprocessing refactor alone is not proven to cause the entire improvement.

The secondary approximately 55-second mostly-pose window (17:29:17.939–17:30:12.938) has preprocessing 35.51 ms, native 50.71 ms, worker 86.91 ms, callback-to-paint 115.64 ms, approximately 11.31 drawable FPS, one detector-no-person result and the same five nonempty expiries. This checks that the primary improvement is not simply produced by empty detector-only frames skipping landmark inference. Snapshot boundaries account for a one-frame paint/delivery discrepancy; it is not evidence of repeated nonempty repaints inflating drawable FPS.

Sampled healthy primary-window detector confidence is 0.9645–0.9824 and pose presence 0.9416–1.0. These are periodic health samples, not every-frame confidence minima; explicit low-presence events exist between snapshots. Freshness events distinguish `wasEmpty:false` from expiry of already-empty results.

By the final periodic snapshot at 17:32:42.940, the fresh optimized session has **1841 nonempty results, 256 low-landmark-pose-presence results, 340 detector-no-person results, 11 nonempty expiries and 44 already-empty expiries**. No stale-result count appears and foundation counters remain zero for stale frames. Invalid-ROI, whole-pose visibility/joint-presence rejection and lifecycle-generation discards are not observed in this session's outcome counters. Partial rejected joints cannot be inferred from a whole-pose counter. The later large empty count is retained, not omitted to claim stable tracking; whether a full-body person was in view throughout that unsynchronized period is unverified.

**No video PTS is aligned to logcat solely by creation metadata.** The two phones' clocks and start/exposure conventions are not calibrated. These logs cannot label a particular video arm disappearance as freshness expiry or model loss. No internal callback-to-paint age is added to, subtracted from, or substituted for P→C/C→S/P→S. Faster CPU work and ~11 drawable FPS can coexist with visible model/filter gesture lag; 0.11 ms filtering execution does not measure temporal smoothing response.

## Acceptance and next diagnostic boundary

Computation/FPS improvement is measured on the Xiaomi. Physical latency improvement is inconclusive, while lag and dynamic alignment concerns remain visibly present. Continuous full-body tracking and explainable loss under a verified person-in-view condition are not accepted. Logs identify detector-no-person, low landmark presence and freshness expiry separately, but do not synchronize them to the external clip.

Camera service readback confirms no active clients after `lifecycle_closed` at 17:32:46 and camera disconnect for PID 6560. That supports End-preview cleanup, not a complete optimized Pause/background/dispose/logout regression suite. Existing Step 2B lifecycle evidence remains separate; acceptance cannot be promoted from this short video.

The next focused investigation should compare **raw image-space joints versus filtered joints on the same captured frame**, alongside projection/preview transforms and explicit per-joint visibility/presence. That can isolate prediction/ROI error, smoothing signal lag and renderer rejection before tuning. Keep the current models, thresholds, One Euro, freshness and backpressure frozen until that evidence is available. No further optimization or Step 3 is implemented here.

Local ignored evidence: `apps/mobile/build/pose-quality/physical-optimized/` contains original video, `frame-pts.log`, `pts.json`, all 806 presentation frames/native phone crops, crossing/candidate contact sheets, `manual-event-brackets.json`, `optimized-summary.json`, parsed telemetry/inventory, 60-second and secondary summaries, installed provenance/camera readback and APK/model verification. Raw logcat and installed APK readback are in the parent quality directory. All are local; no recording was uploaded.

Final verification checked byte-identical source preservation for both recordings, 806 ordered frame/PTS/crop pairs, all ten independent P/C/S interval calculations and outward rounding, and overlap/zero-containing differences for the first two cycles. All 43 PID 6560 foundation snapshots verify the same runtime model contract and report zero stale frames. APK/model/source hashes were rechecked and `git diff --check` passed. Product tests were not rerun for documentation/local evidence processing; the implementation's previous test results remain in the linked optimization report.
