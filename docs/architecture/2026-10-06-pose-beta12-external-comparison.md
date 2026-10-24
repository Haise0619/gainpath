# Step 2P external comparison: beta 0.3 versus beta 1.2

## Decision

**Beta 1.2 does not pass adoption. The external response comparison is inconclusive; beta 0.3 is restored on the Xiaomi with its installed APK hash verified.** Visible moving-arm lag persists in both builds. The candidate does not demonstrate a meaningful benefit without unresolved held-stability caveats. This is an unmet acceptance criterion, not proof that beta 1.2 is intrinsically worse. Step 3 remains deferred.

The user's fast-motion opinion is corrected to **uncertain, possibly about the same**. The earlier “less visible lag” answer is superseded and supplies no positive evidence. The stationary-shaking answer “about the same” remains valid as a qualitative observation.

## Originals and actual presentation timelines

These screen-only recordings observe displayed camera C, yellow refined joint R and green filtered skeleton S. They cannot establish physical→preview, physical→skeleton or total physical latency. No timing below is added to callback/UI/paint telemetry. Original files are read in place; hashes and decoded presentation timestamps are preserved.

| Recording | Bytes | Decoded frames | Actual mean PTS FPS | First–last presentation timestamp | Inter-frame interval range | Gaps over 25 ms |
|---|---:|---:|---:|---|---|---:|
| beta 0.3 control | 444,543,858 | 3,375 | 59.903 | 0.00000–56.32409 s | 10.62–33.38 ms | 7 |
| beta 1.2 candidate | 452,163,522 | 3,422 | 59.720 | 0.00000–57.28442 s | 8.33–66.93 ms | 9 |

Both streams use time base 1/90000, coded HEVC 3840×2160 with a −90° display matrix; FFmpeg applies the existing rotation for inspection. Frame counts include every decoded presentation frame. No duplicate-frame interpolation or nominal frame/60 time is used. Frame numbers below are zero-based decoded indices, not independent app pose results.

- `C:\Users\Ngzhe\Downloads\beta 0.3.mp4` SHA-256: **`ea53108603fef693d83f6455b2b8b8e146d3f316ebf9256004b1474cacf4a473`**.
- `C:\Users\Ngzhe\Downloads\beta 1.2.mp4` SHA-256: **`22bbbcfc55696a603ae2f435bfca8f0a668793b92076ab22019bd5bfdf393131`**.

Build attribution combines the user's control/candidate identification with the independently verified installations and candidate runtime configuration in the [experiment report](2026-10-06-pose-beta12-gpu-experiment.md). The videos do not themselves embed a beta value or APK hash. Their displayed clocks are around 22:55 and 23:07 on 2026-10-06; they are separate evidence from the earlier diagnostic still/fast captures. No exact video-frame ↔ diagnostic-input-clock synchronization is claimed. The same two APKs differ only in the guarded beta selector and configuration reporting; packaged models, native runtime, manifest and DEX are identical. No other frozen production parameter is changed.

## Event definition and uncertainty

Use the same conditional shoulder-band definition as the earlier external reviews: the image-right upper-arm/elbow region passes the local shoulder-level band in the displayed camera; score the corresponding yellow elbow and green elbow/upper-arm junction. The loose sleeve hides the anatomical elbow centre. These are conservative visual proxy enclosures, not exact anatomical landmark crossings. Wrist motion is never substituted for elbow motion.

Before/near/after enclosures are selected from PTS-labeled motion sheets, with finer first-cycle checks. Each endpoint expands by two actual decoded frames for blur, display scan and mixed states. Delay interval is `[S_first − C_last, S_last − C_first]`, rounded outward to 50 ms. Exact PTS are shown only for reproducibility; they do not imply equivalent measurement precision. Negative lower bounds mean uncertainty overlaps zero, not anticipation. Doubled/indistinct candidate crossings are censored; no normal-sample averaging or forced pairwise cycle matching is applied.

All scored crossings remain conditional because of sleeve/shoulder-band ambiguity. A strict anatomical-centre analysis would censor them rather than claim finer timing. “Slow” and “fast” identify observed relative movement pace; the UI remains selected fast throughout both videos. Control has four slower cycles and candidate five, followed by four faster complete cycles and a final raise into the top hold. They are similar protocols, not identical input trajectories.

The conservative C→S brackets substantially overlap for slow raises, slow lowers, fast raises and fast lowers. Green continues moving after the camera arm reverses in both. R also trails during movement, and green can trail R further. Neither the exact upstream cause nor a dominant numerical delay can be isolated by adding these intervals or treating spatial misalignment as a time shift.


### control

| Event | C frames / PTS s | R frames / PTS s | S frames / PTS s | C→R s | C→S s | Status |
|---|---|---|---|---|---|---|
| slow1 raise | 839–867 / 14.01017–14.47667 | 851–879 / 14.20587–14.67229 | 863–891 / 14.41004–14.87216 | -0.30 to 0.70 | -0.10 to 0.90 | conditional |
| slow1 lower | 887–915 / 14.80553–15.27636 | 899–927 / 15.00540–15.47194 | 911–939 / 15.20969–15.67181 | -0.30 to 0.70 | -0.10 to 0.90 | conditional |
| slow2 raise | 1031–1059 / 17.20446–17.67081 | 1043–1071 / 17.40432–17.87079 | 1055–1083 / 17.60419–18.07066 | -0.30 to 0.70 | -0.10 to 0.90 | conditional |
| slow2 lower | 1079–1107 / 18.00403–18.47481 | 1091–1119 / 18.20390–18.69137 | 1091–1131 / 18.20390–18.89123 | -0.30 to 0.70 | -0.30 to 0.90 | conditional |
| slow3 raise | 1211–1251 / 20.23636–20.90874 | 1223–1263 / 20.44058–21.10860 | 1235–1275 / 20.64038–21.30253 | -0.50 to 0.90 | -0.30 to 1.10 | conditional |
| slow3 lower | 1271–1299 / 21.23591–21.70227 | 1283–1311 / 21.43578–21.90224 | 1283–1319 / 21.43578–22.03549 | -0.30 to 0.70 | -0.30 to 0.80 | conditional |
| slow4 raise | 1387–1415 / 23.17423–23.63477 | 1399–1439 / 23.37251–24.03462 | 1411–1439 / 23.56814–24.03462 | -0.30 to 0.90 | -0.10 to 0.90 | conditional |
| slow4 lower | 1447–1475 / 24.16796–24.63442 | 1459–1487 / 24.36784–24.83433 | 1459–1499 / 24.36784–25.03424 | -0.30 to 0.70 | -0.30 to 0.90 | conditional |
| fast1 raise | 1567–1595 / 26.17299–26.63343 | 1575–1603 / 26.30623–26.76668 | 1583–1611 / 26.43357–26.89992 | -0.35 to 0.60 | -0.20 to 0.75 | conditional |
| fast1 lower | 1607–1627 / 26.83330–27.16652 | 1615–1643 / 26.96654–27.43907 | 1615–1643 / 26.96654–27.43907 | -0.20 to 0.65 | -0.20 to 0.65 | conditional |
| fast2 raise | 1703–1731 / 28.44938–28.92176 | 1711–1739 / 28.58861–29.05500 | 1719–1747 / 28.72194–29.18663 | -0.35 to 0.65 | -0.20 to 0.75 | conditional |
| fast2 lower | 1735–1763 / 28.98838–29.45312 | 1743–1771 / 29.12162–29.58637 | 1751–1779 / 29.25326–29.71972 | -0.35 to 0.60 | -0.20 to 0.75 | conditional |
| fast3 raise | 1839–1867 / 30.71924–31.18140 | 1847–1875 / 30.84823–31.31897 | 1855–1883 / 30.98746–31.45221 | -0.35 to 0.60 | -0.20 to 0.75 | conditional |
| fast3 lower | 1871–1899 / 31.24807–31.72056 | 1879–1907 / 31.38559–31.84779 | 1887–1915 / 31.52056–31.98112 | -0.35 to 0.60 | -0.20 to 0.75 | conditional |
| fast4 raise | 1975–2003 / 32.98057–33.44711 | 1983–2011 / 33.11381–33.58634 | 1991–2019 / 33.24717–33.71362 | -0.35 to 0.65 | -0.20 to 0.75 | conditional |
| fast4 lower | 2015–2035 / 33.64700–33.98018 | 2015–2043 / 33.64700–34.11342 | 2023–2051 / 33.78622–34.24667 | -0.35 to 0.50 | -0.20 to 0.60 | conditional |
| top transition raise | 2119–2147 / 35.37948–35.85196 | 2127–2155 / 35.51272–35.98529 | 2135–2163 / 35.64608–36.11254 | -0.35 to 0.65 | -0.25 to 0.75 | conditional |

### candidate

| Event | C frames / PTS s | R frames / PTS s | S frames / PTS s | C→R s | C→S s | Status |
|---|---|---|---|---|---|---|
| slow1 raise | 734–762 / 12.38186–12.85030 | 746–774 / 12.58263–13.05902 | 758–786 / 12.78341–13.25726 | -0.30 to 0.70 | -0.10 to 0.90 | conditional |
| slow1 lower | 782–810 / 13.19063–13.65974 | 794–822 / 13.38448–13.85961 | 794–834 / 13.38448–14.05948 | -0.30 to 0.70 | -0.30 to 0.90 | conditional |
| slow2 raise | 902–942 / 15.19071–15.85873 | 914–954 / 15.39236–16.05860 | 926–966 / 15.59217–16.25847 | -0.50 to 0.90 | -0.30 to 1.10 | conditional |
| slow2 lower | 950–978 / 15.99198–16.45833 | 962–990 / 16.19184–16.65831 | 962–1002 / 16.19184–16.85818 | -0.30 to 0.70 | -0.30 to 0.90 | conditional |
| slow3 raise | 1070–1098 / 17.98930–18.45738 | 1082–1122 / 18.19089–18.85644 | 1094–1134 / 18.39076–19.05071 | censored | -0.10 to 1.10 | censored R: double yellow crossing images; F retains broad conditional enclosure |
| slow3 lower | 1118–1146 / 18.78982–19.25151 | 1130–1158 / 18.98378–19.45221 | 1130–1158 / 18.98378–19.45221 | censored | censored | censored R and F: blended crossing images |
| slow4 raise | 1238–1266 / 20.79071–21.26494 | 1250–1278 / 20.99919–21.45809 | 1250–1290 / 20.99919–21.65887 | -0.30 to 0.70 | -0.30 to 0.90 | conditional |
| slow4 lower | 1274–1302 / 21.39120–21.85953 | 1286–1325 / 21.59187–22.24437 | 1286–1325 / 21.59187–22.24437 | -0.30 to 0.90 | -0.30 to 0.90 | conditional |
| slow5 raise | 1381–1421 / 23.18551–23.85361 | 1393–1433 / 23.38556–24.04579 | 1405–1433 / 23.58717–24.04579 | -0.50 to 0.90 | -0.30 to 0.90 | conditional |
| slow5 lower | 1429–1457 / 23.97886–24.45379 | 1441–1469 / 24.17966–24.64729 | 1441–1473 / 24.17966–24.72239 | -0.30 to 0.70 | -0.30 to 0.75 | conditional |
| fast1 raise | 1533–1561 / 25.71530–26.18374 | 1541–1569 / 25.84919–26.31763 | 1549–1577 / 25.98297–26.45141 | -0.35 to 0.65 | -0.25 to 0.75 | conditional |
| fast1 lower | 1557–1585 / 26.11686–26.58530 | 1565–1593 / 26.25063–26.71908 | 1573–1601 / 26.38452–26.85297 | -0.35 to 0.65 | -0.25 to 0.75 | conditional |
| fast2 raise | 1661–1689 / 27.85674–28.32979 | 1669–1697 / 27.99661–28.46536 | 1677–1705 / 28.12994–28.59636 | censored | censored | censored R and F: doubled/indistinct elbow at crossing |
| fast2 lower | 1693–1721 / 28.39641–28.85729 | 1701–1729 / 28.53202–28.99107 | 1709–1737 / 28.66298–29.12496 | -0.35 to 0.60 | -0.20 to 0.75 | conditional |
| fast3 raise | 1813–1841 / 30.39640–30.86484 | 1813–1849 / 30.39640–30.99862 | 1821–1857 / 30.53029–31.13251 | censored | -0.35 to 0.75 | censored R: double yellow crossing images; F retains broad conditional enclosure |
| fast3 lower | 1837–1865 / 30.79796–31.26611 | 1845–1873 / 30.93173–31.39998 | 1853–1881 / 31.06562–31.53384 | -0.35 to 0.65 | -0.25 to 0.75 | conditional |
| fast4 raise | 1941–1969 / 32.53768–33.00594 | 1949–1977 / 32.67154–33.14633 | 1949–1985 / 32.67154–33.27958 | -0.35 to 0.65 | -0.35 to 0.75 | conditional |
| fast4 lower | 1973–2001 / 33.07298–33.54019 | 1981–2009 / 33.21296–33.67408 | 1989–2017 / 33.34646–33.80786 | -0.35 to 0.65 | -0.20 to 0.75 | conditional |
| top transition raise | 2077–2105 / 34.81163–35.28008 | 2085–2113 / 34.94552–35.41397 | 2093–2121 / 35.07930–35.55427 | -0.35 to 0.65 | -0.25 to 0.75 | conditional |

## Stability, settling and alignment

No confirmed whole-overlay blank interval is found in either recording. Full-rate upper-body colour screening finds no frame below 100 green pixels; the 32 lowest-green frames per recording are visually checked and still contain skeleton segments. The lowest counts occur while walking close to the phone, outside the controlled full-body movement. This colour screen supports the visual review; it is not a per-joint confidence attestation or a guarantee about gaps shorter than a recorded frame.

No sustained moving upper-arm/forearm collapse is confirmed in the inspected crossing sequences. Brief blended/doubled yellow elbow/wrist states make some candidate crossings indistinct and are censored above. Colour-mask failures during a hold are **mask censoring**, not renderer rejection. Separate bounded device captures do contain confidence/link rejections, but their clocks are not synchronized to these video frames; a particular video flicker is not assigned a telemetry reason.

Torso/legs broadly follow the person; the camera-to-overlay arm displacement remains visible during reversals in both builds. During top holds, both refined and filtered joints converge closely, while elbow/shoulder placement is still approximate. No systematic new mirror/crop inversion is observed. This is qualitative alignment, not anatomical or squat acceptance.

Both top-to-bottom transitions retain a trailing arm before returning to the held down position. By approximately 48 s the skeleton is near the down camera arm in both recordings. The camera person, sleeve and predicted joints keep moving slightly, so no precise settled-within-N-pixels time is asserted.

The following optional screen-marker audit measures right-moving-side elbow/wrist **relative to its same-colour shoulder**, radial p95 excursion around the within-window median in the documented 600×820 external crop. The crop is extracted from a rotated 1080×1920 inspection scale. These are external screen-crop pixels, not pipeline image/preview pixels or pure sensor/model jitter. Approximately 3 px per-point centering uncertainty, actual person/camera movement, different framing and repeated displayed poses limit interpretation. No continuous coordinate series is saved.

| Hold window | Control F elbow / wrist p95 | Candidate F elbow / wrist p95 | Valid external images (elbow / wrist), control → candidate |
|---|---|---|---|
| initial: 4–9 s | 2.59 / 4.81 px | 5.09 / 2.98 px | 300 / 300 → 133 / 68 |
| top: 40–44 s | 1.50 / 2.71 px | 17.62 / 22.21 px | 240 / 240 → 200 / 200 |
| bottom: 49–53 s | 1.90 / 3.06 px | 1.36 / 2.77 px | 151 / 151 → 214 / 105 |

Bottom holds look comparably stable within these limitations. Candidate initial filtered-marker coverage is poor (133/298 elbow and 68/298 wrist images), so its apparent initial variation cannot be cleanly compared. Candidate top-hold F variation is substantially larger, but R variation also increases (elbow 18.53 px and wrist 22.15 px, versus control 3.52/4.73 px). The camera person turns the head and changes the held pose; actual motion and prediction changes remain mixed. This does not prove beta-caused stationary jitter, and it does not establish non-degraded held stability. The motion-benefit requirement is already unmet.

## Internal telemetry, a separate boundary

Use each phase's original warmed interior rather than later collections whose older timing endpoints have aged out. Means below are approximately recovered from periodic cumulative counters, not synchronized video timings. FPS counts processed/nonempty/drawable results. Callback→first CPU paint is not display presentation, sensor-exposure timing or physical latency.

| Phase / build | Interior seconds | Processed/delivered/drawable FPS | Preprocess ms | Native ms | Worker ms | Filter CPU ms | Callback→UI ms | Callback→first CPU paint ms | Pending replacements |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| control-still | 9.998 | 21.30 | 24.42 | 12.20 | 44.52 | 0.14 | 64.38 | 76.56 | 86 |
| control-fast | 10.005 | 19.29 | 29.22 | 12.47 | 49.74 | 0.15 | 69.70 | 82.09 | 108 |
| candidate-still | 9.999 | 18.80 | 29.37 | 12.80 | 50.69 | 0.15 | 70.28 | 82.77 | 111 |
| candidate-fast | 10.004 | 19.29 | 28.54 | 12.58 | 49.23 | 0.14 | 70.70 | 83.82 | 106 |
| candidate-slow | 10.001 | 17.60 | 32.29 | 12.45 | 54.53 | 0.17 | 75.56 | 88.33 | 124 |
| candidate-top | 10.001 | 17.00 | 33.15 | 12.77 | 56.33 | 0.19 | 79.17 | 92.99 | 130 |
| candidate-bottom | 10.007 | 16.59 | 33.65 | 13.76 | 57.89 | 0.16 | 77.74 | 92.05 | 135 |

The fast control/candidate computation cohorts are essentially similar: 19.29 FPS each, ~49.74 versus 49.23 ms worker, ~82.09 versus 83.82 ms callback→CPU-paint. Later candidate cohorts slow down; preprocessing/host timing varies more than filter execution. No matched thermal/ROI attribution establishes the cause, and no additional parameter is changed. A separate post-top snapshot reports thermal status 0 and battery temperature 40.7°C; absent synchronized control and HAL temperatures, this cannot establish or exclude vendor throttling.

All seven whole-overlay capture reports are complete and uncensored, with zero blank episodes; all pose reports have zero timestamp mismatch and no global filter reset. Joint observations cap at 300 per phase and later observations are censored. Candidate fast right elbow/wrist rejection is 9/9 of 300 versus control 0/8; right upper/forearm draw commands are 291/291 versus 300/292. Unchanged confidence gates and different predictions prevent attributing those counts to beta. Projection samples are finite with zero measured residual where a residual exists; rejected samples have null measurements. None of this proves anatomical or physical response acceptance.

## Disposition and next boundary

The original beta 1.2 APK/evidence remains preserved. The filtered GPU beta 0.3 Step 2N control is restored with app data retained, force-stopped/relaunched and independently device-hash verified: `6792b7c8776aa222e93985a32454d9f770b0823939824f90d93c9e8ccc014da9`. Camera clients are empty. Candidate normal End cleanup passed before replacement. No new pause/background/logout or heap-leak result is claimed for this run. The guarded experiment source remains reproducible; shared/default/release beta is .3.

**Step 2 quality acceptance still does not pass.** Do not increase beta again from this result. The next useful investigation is upstream camera-preview versus refined-joint alignment/input age, separating prediction/spatial error from temporal lag, before another isolated optimization is selected. This report implements no next experiment and no Step 3 work.

Evidence root: `C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/pose-quality/step2p/`; video metadata/PTS, manual crossing JSON/tables, mask aggregates and review sheets are in `video/`. Bounded device reports remain separate. No app camera frames, new video capture or continuous device landmark stream is saved or uploaded.
