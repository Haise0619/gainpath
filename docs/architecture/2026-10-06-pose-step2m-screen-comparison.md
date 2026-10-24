# Step 2M paired CPU / OpenCL screen comparison

Date: 2026-10-06. GainPath test phone: Xiaomi 23013RK75C, Android 13, Adreno 730. Step 3 remains deferred.

## Decision

**Retain the OpenCL artifact as an experimental candidate; keep CPU as the default and rollback.** The recording-session telemetry confirms better computation and delivery, and the GPU video has fewer whole-overlay interruptions. The external crossing observations do **not** establish a numerical camera-preview-to-joint speedup: their conservative ranges overlap substantially. Dynamic arm misalignment and filtered-point trailing remain visible.

The paired holds do not establish a consistent material GPU-specific increase in shaking. This narrows the earlier concern; it does not certify stationary stability or dismiss the user's observation. Overall Step 2 quality acceptance has **not passed**. No application code, inference setting, filter parameter, freshness policy or backpressure policy changes accompany this analysis.

## Observable boundaries and method

These are close-screen recordings. `C` is the arm visible in the displayed camera preview. `R` is the refined, inverse-projected joint: yellow rings and the **green refined diagnostic skeleton**. `F` is the magenta One Euro filtered point. The green skeleton in both artifacts bypasses temporal smoothing for diagnosis; it is not the normal filtered primary skeleton. A green-skeleton response measurement therefore concerns C→R, not C→F.

No physical-person→preview, physical-person→skeleton or total camera-to-display latency is observable. External video timing is not added to callback-to-UI/CPU-paint telemetry. CPU paint also excludes subsequent raster, compositor and physical panel presentation.

FFmpeg 7.1 decodes all frames in presentation order. `showinfo` supplies each decoded frame's integer presentation timestamp before selection; the time base is 1/90000 seconds. Output uses passthrough without frame-rate resampling. Timestamp arrays are sequential and monotonic. Every event time below is derived from its actual PTS, never frame/60.

Both originals encode 3840×2160 HEVC Main, YUV420 BT.709, with −90° display rotation (upright 2160×3840). The Xiaomi 17 / 25113PN0EG metadata describes the recording camera, not the GainPath phone. Container creation times are not exposure timestamps or a synchronization clock.

| Recording | Bytes | Decoded frames | First / last PTS ticks | Last frame PTS, s | PTS-derived mean FPS | Adjacent PTS range, ms | Intervals >25 ms |
|---|---:|---:|---|---:|---:|---:|---:|
| CPU control | 440,889,900 | 3,348 | 0 / 5,030,349 | 55.892767 | 59.8825 | 8.311–33.433 | 10 |
| GPU candidate | 454,009,026 | 3,441 | 0 / 5,174,619 | 57.495767 | 59.8305 | 8.389–50.000 | 14 |

The last PTS is not the end of the final frame's presentation interval. Nominal recording metadata says 60 FPS; the measured intervals vary.

Original SHA-256:

- CPU `C:/Users/Ngzhe/Downloads/step2m_cpu_control_screen.mp4`: `9451d654c9a0533c9f208654ef3d7b643dda247b766ae0485377e794b4416fa2`.
- GPU `C:/Users/Ngzhe/Downloads/step2m_gpu_candidate_screen.mp4`: `9d1b70ce66cee9f300421bb3bba0ceaff6c7368f7572565c71fd2348664dae40`.

The originals remain unchanged. Analysis derivatives are local, ignored build artifacts under `apps/mobile/build/pose-quality/step2m/video/`. These are user-supplied recordings; no application camera stream was newly recorded or uploaded. Held-coordinate calculations retain only aggregate measurements, not a landmark-coordinate stream.

## Attribution and frozen controls

Preserved CPU Step 2K refined profile APK SHA-256: `8d618a92d6d0ad18f24f455e2c5b6ba2fcbd148cef9e02c083854edb3eba95ff`. GPU Step 2M profile APK: `89d9a15d3d6094be143c75ebeb179d797546a1bac6cbbb90a5b15403a098c977` (147,313,022 bytes).

The recordings are supplied as separate control/candidate installations following the documented commands. Their visible session badges and retained logs identify CPU PID 31408/session 1791273834424543 and GPU PID 31409/session 1791273962082954. The installed GPU APK was independently pulled and hash-matched. The CPU recording's installed APK bytes cannot be retrospectively attested by checking the currently installed GPU; its attribution rests on the supplied label, preserved control artifact and consistent session chronology. This is a limitation, not a claimed historical hash attestation.

GPU session creation/invocation/disposal uses owner OS thread 14851. Native logs identify forced OpenCL, with 291/291 detector and 332/332 landmark nodes delegated. Its bounded startup agreement compares 12 identical landmark inputs and one detector input, completes, and closes CPU shadows before the video measurement interior. Maximum refined-coordinate difference is 0.0017755 image px, world-coordinate difference 0.0000095754 m, and confidence difference 0.0000158548. No nonfinite values, acceptance flips or whole-pose/ROI-availability flips occur. These inputs support numerical agreement, not full-body anatomical ground truth; simultaneous acceptance of all eight full-body check joints is zero on both backends.

Preserved provenance verifies the same model assets/native runtime bytes and unchanged baseline source files. Frozen settings: beta 0.3, minCutoff 1, derivative cutoff 1; model version `mediapipe-full-e9a5c5cb-det-9ba9dd3d` and tensor contracts; existing 0.5 confidence thresholds; detector interval 15 processed frames; CPU residual interpreter threads 2; camera 720×480, oriented 480×720; projection/mirroring/cover crop; 250 ms freshness, 100 ms watchdog, latest-frame replacement; Step 2C/2I preprocessing. Faster processing naturally changes wall-clock detector frequency with the same processed-frame interval; no cadence setting was tuned.

## Motion observations and conservative event scoring

The screen-image-right arm moves; this report does not infer anatomical handedness. Approximate visible phases are CPU initial bottom hold 3–13.5 s, three slow cycles 14–22.3 s, six fast cycles 22.5–35.3 s, top hold 36–43.7 s, and bottom hold 46–53.7 s. GPU shows bottom hold 3–10.8 s, three slow cycles 11–20.5 s, seven fast cycles 20.9–37.6 s, top hold 38.5–46.5 s, and bottom hold 48–54.8 s. Approach/exit movement is excluded from held comparisons. Movements are not identical in speed, count or extent, and the top holds are approximately eight seconds rather than a full ten seconds.

Loose sleeves hide the anatomical elbow centre, and several raises only reach a shoulder-level zone. Consequently the appendix contains **conditional upper-arm crossing-zone enclosures**, not calibrated elbow-centre latency samples. C uses the visible arm/elbow region relative to the local shoulder band; R uses the corresponding refined elbow/upper-arm. Each manually selected enclosure is expanded by two actual decoded frames at each endpoint for blur/scan uncertainty. Interval subtraction is `[R earliest − C latest, R latest − C earliest]`, rounded outward to 50 ms. Negative lower bounds mean overlapping observations, not prediction before the camera image. Mirror/photographed-screen geometry, sleeve occlusion and different motion extent remain additional uncertainty; these brackets are not statistical confidence intervals.

Examples: CPU slow first raise is −0.10…+0.60 s, versus GPU −0.15…+0.70 s. CPU fast second raise is −0.15…+0.55 s, versus GPU −0.20…+0.65 s. All usable candidate ranges include zero and overlap substantially. **There is no defensible pooled mean or visual speedup percentage.** GPU updates look more continuous; that qualitative observation is compatible with higher delivered FPS without proving a smaller external crossing delay.

CPU slow second raise and fast fifth raise are censored by whole-overlay interruptions. CPU slow third lower and GPU fast third lower are censored by indistinct/doubled refined images. They are not ordinary delay samples. Other doubled or faint links, including around GPU 27.25–27.36 s and 36.43–36.51 s, may include screen scan/exposure blending.

Magenta wrist/elbow points visibly trail yellow rings during motion and converge during holds. Filtered elbow extrema often do not make a clearly observable shoulder-band crossing. Exact C→F crossing timing is therefore **not independently scored**; no wrist crossing substitutes for an elbow crossing and no missing crossing is assigned a finite delay. The small CPU execution time of the filter is not a measure of its signal delay.

Representative external crops (decoded index is zero-based, filename is index+1) are CPU index 1512 and GPU index 1459. They show a camera arm near the shoulder band, refined elbow below it and filtered point farther below. They are witnesses of residual displacement, not a synchronized before/after pair or an exact latency estimate.

## Held variation, settling and anatomical alignment

Both builds show refined-marker movement during stationary holds. To check whether GPU shaking is consistently worse, colour-mask centres are measured in a common 600×820 external-video crop (upright scale 1080×1920, crop x=340,y=470). Same-side shoulder translation is subtracted separately for refined and filtered points. The statistic below is the 95th percentile radial distance from the within-window median, in **external crop pixels**.

| Hold / PTS window | CPU refined elbow / filtered elbow | GPU refined elbow / filtered elbow | CPU refined wrist / filtered wrist | GPU refined wrist / filtered wrist |
|---|---:|---:|---:|---:|
| Initial, both 4–9 s | 4.92 / 3.63 | 6.02 / 4.89 | 9.93 / 10.47 | 5.68 / 4.86 |
| Top, CPU 39–43 s; GPU 40–44 s | 6.04 / 2.69 | 5.39 / 3.39 | 7.00 / 4.03 | 5.00 / 3.78 |
| Bottom, both 48.5–52.5 s | 4.03 / 2.76 | 3.54 / 2.10 | 6.98 / 5.11 | 6.34 / 4.96 |

These are screen-space variation estimates, **not pure model jitter**, calibrated painter pixels, physical distances or significance tests. Person holding/breathing, shoulder prediction, photographed-screen perspective and colour-centre uncertainty contribute. The centring allowance is approximately ±3 crop px per point (up to 6 px for a joint-minus-shoulder difference); most CPU/GPU differences are below that floor. Repeated photographed copies of a displayed pose are not independent inference observations.

Initial windows contain 299 CPU and 300 GPU decoded images; GPU filtered wrist has 12 mask-censored observations. Top windows contain 240 each. Bottom CPU matched counts are 233–235 because of blank/ambiguous images; GPU has 240. Masks with inadequate colour or wide/doubled extents are censored, not accepted as joint motion. Aggregate provenance is in `held-points.json`; continuous centre coordinates are not persisted.

There is **no consistent material GPU held-stability regression established by this pair**. This does not prove that either build is sufficiently stable. Settling and filtered convergence are visible, but release/endpoint ambiguity prevents a precise settling-duration comparison. Gross shoulder/hip/knee/ankle alignment is reasonable in static front-camera views, with no obvious common mirror reversal or uniform cover-crop displacement. Moving arm prediction and coarse hand landmarks remain imperfect. This video does not validate side-on squat anatomy or articulated finger tracking.

Partial arm links sometimes become faint, doubled or difficult to follow. A screen recording cannot uniquely distinguish confidence rejection from display blending or overlapping marker/limb positions. These recordings have an idle diagnostic phase and no synchronized per-joint acceptance ledger. Do not assign a visibility/presence cause to each apparent partial disappearance using the earlier capture's statistics. Earlier controlled GPU rejection evidence remains separately documented in the live-candidate report.

## Whole-overlay blanking

All 3,348 CPU and 3,441 GPU cropped frames are screened for green overlay pixels, followed by visual review of low-colour candidates and motion/hold contact sheets. CPU has fourteen short blank/near-blank groups: one during initial approach, thirteen with a full-body person and camera image remaining visible. The GPU has **no confirmed whole-overlay blank** in this recording; its lowest green count is 1,695, and reviewed low-count images retain overlay links. Colour screening alone is not a renderer/confidence attestation.

The blank appendix lists observed PTS spans, not exact physical panel durations. One-frame observations are not zero-duration events. Faint residue on blended boundary frames, asynchronous camera exposure and screen scan mean onset/recovery lie outside these minimal spans. No subframe duration is invented.

CPU retained health events around the photographed interruptions explicitly clear a previously nonempty valid pose as `freshness_expiry`, then reacquire a pose. Selected events show last-pose age approximately 251–337 ms. Interior detector-no-person, low whole-pose presence and empty-pose increments are zero. The main whole-overlay interruption mechanism here is **freshness expiry during slower delivery**, not demonstrated no-person prediction loss or all-joint renderer rejection.

Rounded on-screen route time only aligns video to telemetry to approximately ±0.2 s. Multiple clears/recoveries can be photographed as one brief/blended group; some logical clears are not captured as visibly blank frames. Hence thirteen interior visual groups are not equated one-for-one to the fifteen logical expiries in the approximately forty-second telemetry cohort. The on-screen idle `B0` is not a zero-blank ledger for these videos.

## Separate recording-session telemetry

Both measurements exclude startup CPU-shadow work and initial positioning. Rounded badge time is used only to select broad interior cohorts, not to infer missing latency stages. Count endpoints are CPU 16:04:39.433–16:05:19.430 (39.997 s) and GPU 16:06:37.087–16:07:17.087 (40.000 s). These are approximately video 8–48 s, with badge alignment uncertainty. Stage means use differences of cumulative counts/sums; detector-only means have their own invocation counts and are not simply added to per-pose means.

| Metric | CPU control | GPU candidate |
|---|---:|---:|
| Camera received FPS, periodic range | 29.79–30.21 | 29.80–30.25 |
| Processed / delivered drawable / unique CPU-painted FPS | 9.55 | 17.00 |
| Nonempty delivered and unique-painted count | 382 | 680 |
| Replaced pending frames | 818 | 520 |
| Detector native mean, ms | 47.19 | 10.38 |
| Landmark native mean, ms | 70.02 | 12.59 |
| Total native mean per processed pose, ms | 73.11 | 13.29 |
| Preprocessing mean, ms | 28.72 | 32.43 |
| Worker computation mean, ms | 102.72 | 56.25 |
| Input queue age mean, ms | 17.78 | 17.93 |
| Callback→UI mean, ms | 122.97 | 77.42 |
| Callback→first CPU paint mean, ms | 135.84 | 90.61 |
| Pose age at first CPU paint mean, ms | 135.12 | 89.80 |
| Nonempty overlay freshness expiries | 15 | 0 |
| Empty / detector-no-person / low whole-pose-presence increments | 0 / 0 / 0 | 0 / 0 / 0 |

GPU stale-result increment is zero; its cumulative startup stale count of one remains unchanged. CPU endpoint foundation metrics report no stale frames, though the newer explicit stale-result delta field is absent in that older control. Latest-frame replacements are expected bounded dropping, not a stale queued stream.

Filter CPU cost is 0.13/0.19 ms and landmark postprocessing 0.67/0.25 ms (CPU/GPU). GPU adapter copy mean is 1.13 ms, round trip 23.42 ms and transport/queue remainder 9.00 ms. Diagnostic idle observation means are approximately 0.005/0.003 ms at joint delivery, 0.034/0.03 ms at joint paint, 0.029/0.04 ms at blank delivery and 0.041/0.05 ms at blank paint. These observations do not establish active-capture overhead or filter signal responsiveness.

This pair supports a computation and continuity benefit on this Xiaomi. CPU inference here is slower than earlier CPU sessions; order, temperature and power state were not controlled. The result is run-specific and should not be presented as a universal backend speedup ratio. Higher FPS and lower callback→CPU-paint age do not prove that external prediction/filter lag is solved.

## Next check and acceptance

The smallest next validation is to keep this GPU backend and every numerical parameter frozen, then show the **normal filtered primary skeleton** instead of the unsmoothed green diagnostic skeleton. Preserve refined markers for diagnosis if needed. This changes the displayed pose source only; it is not beta/minCutoff tuning and may reveal the existing responsiveness/stability tradeoff rather than solve it. Assess the actual intended Workout overlay before attributing diagnostic-green shaking to a production regression. This next check is a recommendation; no display-source change or new APK is made in this analysis.

CPU rollback remains preserved. GPU side-on anatomical validation, sustained thermal/performance and resource/setup-cancellation stress acceptance are still incomplete. Dynamic filtered response and acceptable held stability remain unresolved. **Step 2 quality is pending; no RepFSM, scoring, audio, upload, Firebase acceptance or Step 3 work follows this report.**

The prior implementation test/analysis results remain in the live-candidate report. This turn changes reports/analysis artifacts only; original-video and source/APK hashes are rechecked rather than claiming a fresh mobile test run.

## Evidence index

Local ignored evidence root: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2m/video/`.

- `cpu/metadata.json`, `gpu/metadata.json`, each `pts.json` and `decode.log`: full decoded timestamp contract.
- `crossings.json`, `crossing-tables.md`, `events.py`: conditional manual enclosures and interval arithmetic.
- Each `color-audit.json`, `low-green-*.jpg`, motion/hold contact sheets and `blank-observations.json`: screening and visual witnesses.
- `held-points.json`, `held_points.py`: aggregate held variation and censor counts.
- `telemetry.json`, `telemetry.py`, `recording-session-scalars.json`: independent bounded scalar cohort analysis.
- `evidence-manifest.json`: rechecked source/APK hashes and analysis-file hashes.
- Parent `step2m/recording-scalars.json`, `recording-native.log`, `provenance.json`, `final-source-check.json`: backend agreement, owner thread and immutable control/candidate provenance.

## Appendix: conditional crossing-zone enclosures

Frame indices below are zero-based decoded presentation indices. Five-decimal PTS are lookup values, not claimed perceptual precision. R denotes refined green/yellow, not filtered magenta. Censored entries are excluded from delay comparison. No average is computed.

<!-- Generated tables follow. -->

CPU

| Event | C frames / PTS s | R frames / PTS s | C→R s | Status |
|---|---|---|---|---|
| slow1 raise | 864–884 / 14.45319–14.78699 | 880–900 / 14.72032–15.04690 | -0.10 to 0.60 | conditional |
| slow1 lower | 908–928 / 15.18862–15.52169 | 924–944 / 15.45504–15.78020 | -0.10 to 0.60 | conditional |
| slow2 raise | 1040–1068 / 17.38170–17.85014 | 1052–1080 / 17.58248–18.05892 | not scored | censored: whole-overlay blank inside refined enclosure |
| slow2 lower | 1076–1104 / 17.99230–18.45866 | 1088–1116 / 18.19217–18.65096 | -0.30 to 0.70 | conditional |
| slow3 raise | 1196–1224 / 19.99284–20.45931 | 1208–1236 / 20.19271–20.65296 | -0.30 to 0.70 | conditional |
| slow3 lower | 1244–1272 / 20.79324–21.26097 | 1256–1284 / 20.98714–21.46254 | not scored | censored: double/indistinct refined image |
| fast1 raise | 1351–1379 / 22.58139–23.04003 | 1363–1391 / 22.78126–23.24872 | -0.30 to 0.70 | conditional |
| fast1 lower | 1387–1415 / 23.18210–23.64923 | 1399–1427 / 23.37397–23.84959 | -0.30 to 0.70 | conditional |
| fast2 raise | 1502–1522 / 25.09506–25.42972 | 1514–1534 / 25.29583–25.63039 | -0.15 to 0.55 | conditional |
| fast2 lower | 1538–1554 / 25.69739–25.97140 | 1550–1570 / 25.89789–26.23137 | -0.10 to 0.55 | conditional |
| fast3 raise | 1615–1643 / 26.98280–27.45699 | 1627–1655 / 27.18347–27.65850 | -0.30 to 0.70 | conditional |
| fast3 lower | 1651–1679 / 27.59019–28.05162 | 1663–1691 / 27.78389–28.25222 | -0.30 to 0.70 | conditional |
| fast4 raise | 1735–1763 / 28.99352–29.46164 | 1747–1775 / 29.19507–29.65373 | -0.30 to 0.70 | conditional |
| fast4 lower | 1771–1799 / 29.58680–30.05513 | 1783–1811 / 29.78760–30.26236 | -0.30 to 0.70 | conditional |
| fast5 raise | 1879–1907 / 31.39778–31.85743 | 1879–1919 / 31.39778–32.05823 | not scored | censored: two whole-overlay blanks inside refined enclosure |
| fast5 lower | 1903–1931 / 31.79050–32.25886 | 1915–1943 / 31.99130–32.45963 | -0.30 to 0.70 | conditional |
| fast6 raise | 1999–2027 / 33.40198–33.86762 | 2011–2039 / 33.59371–34.06749 | -0.30 to 0.70 | conditional |
| fast6 lower | 2035–2063 / 34.00087–34.46132 | 2035–2063 / 34.00087–34.46132 | -0.50 to 0.50 | conditional |

GPU

| Event | C frames / PTS s | R frames / PTS s | C→R s | Status |
|---|---|---|---|---|
| slow1 raise | 700–724 / 11.71241–12.12908 | 716–740 / 11.99583–12.39559 | -0.15 to 0.70 | conditional |
| slow1 lower | 756–776 / 12.66267–12.98932 | 760–784 / 12.72902–13.12319 | -0.30 to 0.50 | conditional |
| slow2 raise | 898–926 / 15.06637–15.52649 | 910–950 / 15.26623–15.93334 | -0.30 to 0.90 | conditional |
| slow2 lower | 946–974 / 15.86672–16.35013 | 958–986 / 16.07696–16.55011 | -0.30 to 0.70 | conditional |
| slow3 raise | 1102–1130 / 18.47612–18.94330 | 1114–1142 / 18.68326–19.15188 | -0.30 to 0.70 | conditional |
| slow3 lower | 1138–1166 / 19.08521–19.55154 | 1150–1178 / 19.28501–19.74986 | -0.30 to 0.70 | conditional |
| fast1 raise | 1279–1307 / 21.46751–21.93392 | 1291–1319 / 21.66738–22.12571 | -0.30 to 0.70 | conditional |
| fast1 lower | 1327–1355 / 22.26587–22.73233 | 1339–1367 / 22.46573–22.93397 | -0.30 to 0.70 | conditional |
| fast2 raise | 1449–1473 / 24.29856–24.69826 | 1461–1485 / 24.49826–24.89979 | -0.20 to 0.65 | conditional |
| fast2 lower | 1485–1509 / 24.89979–25.29793 | 1497–1521 / 25.09807–25.49780 | -0.20 to 0.60 | conditional |
| fast3 raise | 1591–1619 / 26.66576–27.13033 | 1603–1631 / 26.86473–27.32974 | -0.30 to 0.70 | conditional |
| fast3 lower | 1615–1643 / 27.06371–27.53039 | 1627–1655 / 27.26312–27.73039 | not scored | censored: blended/indistinct refined crossing |
| fast4 raise | 1723–1751 / 28.86410–29.33057 | 1735–1763 / 29.06397–29.53220 | -0.30 to 0.70 | conditional |
| fast4 lower | 1759–1787 / 29.46462–29.93193 | 1771–1799 / 29.66544–30.13021 | -0.30 to 0.70 | conditional |
| fast5 raise | 1855–1883 / 31.06320–31.52968 | 1867–1895 / 31.26304–31.72959 | -0.30 to 0.70 | conditional |
| fast5 lower | 1903–1931 / 31.86283–32.33007 | 1915–1943 / 32.06248–32.52993 | -0.30 to 0.70 | conditional |
| fast6 raise | 1987–2015 / 33.26382–33.72986 | 1999–2027 / 33.46297–33.92986 | -0.30 to 0.70 | conditional |
| fast6 lower | 2023–2051 / 33.86319–34.32986 | 2035–2063 / 34.06270–34.52959 | -0.30 to 0.70 | conditional |
| fast7 raise | 2120–2154 / 35.47913–36.04570 | 2138–2172 / 35.77904–36.34510 | -0.30 to 0.90 | conditional |
| fast7 lower | 2150–2184 / 35.97932–36.54549 | 2168–2202 / 36.27860–36.84579 | -0.30 to 0.90 | conditional |
## Appendix: photographed CPU blank / near-blank observations

| Decoded indices | Observed PTS span, s | Scope |
|---|---|---|
| 21–22 | 0.351500–0.368167 | approach; excluded from stable full-body comparison |
| 960–961 | 16.053711–16.070378 | full-body camera person remains visible |
| 966–967 | 16.153511–16.170267 | full-body camera person remains visible |
| 1062–1063 | 17.749811–17.766533 | full-body camera person remains visible |
| 1703–1703 | 28.459611–28.459611 | full-body camera person remains visible |
| 1888–1889 | 31.539500–31.556233 | full-body camera person remains visible |
| 1894–1895 | 31.639900–31.656633 | full-body camera person remains visible |
| 2278–2280 | 38.058756–38.091989 | full-body camera person remains visible |
| 2655–2657 | 44.341756–44.375067 | full-body camera person remains visible |
| 2661–2664 | 44.443400–44.493400 | full-body camera person remains visible |
| 3028–3028 | 50.561122–50.561122 | full-body camera person remains visible |
| 3034–3035 | 50.654700–50.671433 | full-body camera person remains visible |
| 3130–3130 | 52.261578–52.261578 | full-body camera person remains visible |
| 3225–3226 | 53.844222–53.860878 | full-body camera person remains visible |
