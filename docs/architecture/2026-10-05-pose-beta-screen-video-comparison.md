# Step 2E paired screen-video comparison — 2026-10-05

**Decision: beta 0.6 is not accepted. Beta 0.3 has been restored.** The external C→S response is inconclusive: conservative ranges overlap substantially and visibly delayed moving arms remain in both runs. The videos do not establish a consistent meaningful motion benefit. No obvious large increase in held shaking is established either, but that does not rescue a failed benefit gate. Whole-overlay blinking persists. This is not proof that beta 0.6 has zero signal-response benefit; the previous same-input/internal evidence remains valid within its own boundary. Step 2 quality acceptance remains **not passed**; Step 3 stays deferred.

## Observable boundary and evidence preservation

These are screen-only originals provided by the user, in the same sitting. **C** is the moving elbow/upper arm in the displayed camera image; **S** is the corresponding green skeleton elbow/upper arm, corroborated by the magenta filtered marker when the green link is actually visible. The yellow ring is a refined/unfiltered diagnostic joint, not S. No physical person is independently visible. Consequently this report contains no physical→preview, physical→skeleton, total physical latency or reconstructed sensor timing.

Both originals were copied byte-for-byte into the ignored local `apps/mobile/build/pose-quality/step2e-external/{control,candidate}/original.mp4` directories and the copy hashes verified. Original Downloads files were not edited. Full PTS manifests, decode logs, all presentation-order arm crops, full-preview checks around every screened blank, annotated crossing/hold sheets, reviewed event/blank JSON and `comparison.json` are preserved beside the copies. None was uploaded. These are analysis derivatives of user-supplied recordings, not a new app camera/landmark recording facility.

| Recording | Original bytes | Decoded frames | First / last presentation timestamp | PTS-derived rate | Adjacent PTS spacing |
| --- | ---: | ---: | --- | ---: | --- |
| beta .3 control | 501800667 | 3805 | 0 / 63.529733s | 59.87747 FPS | 8.389–33.344ms |
| beta .6 candidate | 575825354 | 4369 | 0 / 72.995456s | 59.83934 FPS | 8.344–33.522ms |

SHA-256, beta 0.3 original and preserved copy:
`40b6e8a8045b15212fc968eedfa91be25e1a0ac1a338c4adae13ab75c0830f93`

SHA-256, beta 0.6 original and preserved copy:
`4a15ce4dfb1ab76a5037f97e4780090816053a2b23e55f94a902288142793745`

Both sources are HEVC Main, 3840×2160 encoded, display rotation −90° (2160×3840 upright), nominal capture metadata 60 FPS, time base **1/90000**. The candidate's demuxer `tbr=120` is not its decoded delivered frame rate. The container durations are approximately 63.55/73.01s, including stream tails. PTS endpoints are ticks **5717676 / 6569591**. Each timestamp is decoded PTS ticks/90000; **never frame/60**. FFmpeg 7.1 `showinfo` before selection recorded all frames; `-fps_mode passthrough` retained presentation order without frame-rate conversion. Every arm crop corresponds to the same zero-based PTS index (JPEG index is index+1). Small min/max spacing figures describe the recording, not measurement precision. MP4 creation metadata is not an exposure or recording-start clock and was not joined to phone telemetry.

## Build attribution and frozen controls

Control artifact: `step2d-joint-lag-logging-profile.apk`, SHA-256
`774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`.

Candidate artifact: `step2e-beta06-diagnostic-profile.apk`, SHA-256
`dd75e4f406d48d7ada1714e059d0bfb1de3438f1145961e0dc2bf04b62e0b9b2`.

Read-only ADB verified that the APK installed before this analysis matched the candidate hash. Retained package/process logs show replacement at 16:41:15 with process 6530, then replacement at 16:59:25 with process 6534; the latter matches the candidate and its recorded app time. **The control clip's beta attribution currently rests on the user's label and installation chronology, not a retrospectively recoverable hash of the then-installed APK.** A concise provenance confirmation was requested; this limitation is preserved rather than claiming filename proves a binary. The hashes above identify preserved artifacts. After rollback, ADB verified the installed binary matches the control hash; that later check does not retroactively prove the recording identity.

The 180-file frozen production-source manifest showed **only** the preview controller's beta argument differed before rollback. Replacing `PoseFrameFilter(beta: 0.6)` with the original `PoseFrameFilter()` reproduced its control byte hash; after restoration **all 180 manifest files match**. The shared default is .3. Existing APK comparison establishes identical model assets and 26 frozen native/resource/manifest entries, with differences only in the three architecture-specific compiled Dart `libapp.so` entries. Thus the supplied artifacts change beta alone; their recorded installation identities carry the limitation above.

Model `mediapipe-full-e9a5c5cb-det-9ba9dd3d`: detector SHA-256 `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c`, landmark-full SHA-256 `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f`. No model/tensor, confidence/acceptance threshold, minCutoff = 1, derivative cutoff = 1, detector/ROI cadence, two-thread interpreter, camera resolution/orientation, projection/mirroring/cover crop, 250 ms freshness, 100 ms watchdog or one-active/one-replaceable-pending backpressure change was made. Same profile diagnostic defines: mock backend, pose preview, quality debug and joint-lag debug enabled. No Step 3/Firebase/upload work.

## Event definition and uncertainty

An event is the same moving **image-right upper arm/elbow** passing approximately shoulder level relative to the local shoulder/torso orientation; no anatomical left/right is inferred from front-camera mirroring. The same arm is followed for raises and lowers. Wrist height is not substituted. The phone screen is tilted and perspective differs between clips: an absolute horizontal recording row is not the event plane. Shirt/sleeve outlines obscure exact anatomical centers, the shoulder shifts/shrugs during a raise, and the model shoulder can move differently. Conservative visual brackets include that uncertainty.

Presentation-order coarse sheets locate all 26 raise/lower/hold transitions per clip; native arm crops and selected ~50ms-spaced fine sheets verify the event enclosures. Brackets are **conservative crossing-zone enclosures**, not an assertion that each crossing has two sharp adjacent ground-truth frames. Many are deliberately several recording frames wide. Motion blur, display scan/rolling shutter, exposure-blended/double arm and skeleton images, stepped overlays, and missing links prevent finer trustworthy claims. No interpolation through missing output or invented subframe timing is used.

The UI phase selector remains `still` during these external clips; motion groups below are identified by visible cadence, not by pretending a 20 s diagnostic capture labels the video. Control has 3 slower cycles, 9 faster cycles, then a top hold/descent; candidate has 4 slower cycles, 8 faster cycles, then a top hold/descent. Speeds and exact top angles are approximately matched, not identical trajectories. This limits a causal performance estimate from pair numbering.

For C=[c0,c1],S=[s0,s1], C→S=[s0−c1,s1−c0]. Printed seconds are rounded **outward to 0.05 s**, so the raw decoded anchors in JSON remain authoritative. A negative lower bound means the uncertain visual brackets overlap; it is not a claim of a skeleton anticipating the camera. Rows with missing/indistinct output within the unresolved S bracket are censored at this resolution; their last/first visible enclosure is retained, but no ordinary delay value or average is assigned. Censoring is conservative and may include a crossing that finer footage could resolve. No pooled average/median or percentage speedup is calculated from these interval/censored samples.

### beta .3 control — every repeated transition

| Event | C seconds (frames) | S enclosing seconds (frames) | C→S seconds | Status |
| --- | --- | --- | --- | --- |
| slow1 up | 11.80–12.15 (f708–725) | 12.15–12.55 (f729–749) | 0.05–0.70 | usable |
| slow1 down | 12.80–13.15 (f768–785) | 12.95–13.35 (f777–798) | not scored | censored: blank/indistinct |
| slow2 up | 14.85–15.25 (f890–911) | 15.25–15.65 (f913–935) | 0.00–0.80 | usable |
| slow2 down | 15.75–16.15 (f943–965) | 16.00–16.45 (f958–980) | -0.15–0.65 | usable |
| slow3 up | 17.80–18.25 (f1065–1090) | 18.25–18.70 (f1092–1117) | 0.00–0.90 | usable |
| slow3 down | 18.80–19.25 (f1125–1150) | 19.05–19.65 (f1140–1174) | -0.20–0.85 | usable |
| fast1 up | 20.60–21.05 (f1233–1258) | 21.00–21.45 (f1257–1281) | -0.05–0.85 | usable |
| fast1 down | 21.50–21.95 (f1285–1311) | 21.75–22.35 (f1301–1334) | not scored | censored: blank/indistinct |
| fast2 up | 23.20–23.65 (f1387–1413) | 23.60–24.05 (f1412–1437) | not scored | censored: blank/indistinct |
| fast2 down | 23.80–24.25 (f1424–1449) | 24.05–24.65 (f1439–1473) | -0.20–0.85 | usable |
| fast3 up | 25.20–25.65 (f1507–1533) | 25.45–26.05 (f1523–1557) | not scored | censored: blank/indistinct |
| fast3 down | 26.00–26.45 (f1556–1581) | 26.25–26.85 (f1571–1605) | -0.20–0.85 | usable |
| fast4 up | 27.35–27.85 (f1638–1664) | 27.80–28.45 (f1663–1700) | not scored | censored: blank/indistinct |
| fast4 down | 28.20–28.65 (f1687–1712) | 28.45–29.05 (f1702–1736) | not scored | censored: blank/indistinct |
| fast5 up | 29.60–30.05 (f1771–1796) | 30.00–30.45 (f1795–1820) | -0.05–0.85 | usable |
| fast5 down | 30.20–30.65 (f1807–1832) | 30.45–31.05 (f1822–1856) | -0.20–0.85 | usable |
| fast6 up | 31.80–32.25 (f1902–1928) | 32.20–32.65 (f1927–1952) | -0.05–0.85 | usable |
| fast6 down | 32.40–32.85 (f1939–1964) | 32.65–33.25 (f1954–1988) | not scored | ambiguous double image |
| fast7 up | 33.95–34.45 (f2033–2059) | 34.40–34.85 (f2058–2083) | not scored | censored: blank/indistinct |
| fast7 down | 34.80–35.25 (f2082–2107) | 35.05–35.65 (f2097–2131) | -0.20–0.85 | usable |
| fast8 up | 36.15–36.65 (f2165–2191) | 36.60–37.05 (f2190–2215) | -0.05–0.85 | usable |
| fast8 down | 37.00–37.45 (f2214–2239) | 37.25–37.85 (f2229–2263) | -0.20–0.85 | usable |
| fast9 up | 38.55–39.05 (f2309–2335) | 39.00–39.45 (f2334–2359) | -0.05–0.85 | usable |
| fast9 down | 39.40–39.85 (f2358–2383) | 39.50–40.25 (f2364–2407) | -0.35–0.85 | usable |
| top entry up | 40.75–41.25 (f2441–2467) | 41.20–41.85 (f2466–2503) | not scored | censored: blank/indistinct |
| top exit down | 52.00–52.45 (f3114–3139) | 52.25–52.85 (f3129–3163) | -0.20–0.85 | usable |

### beta .6 candidate — every repeated transition

| Event | C seconds (frames) | S enclosing seconds (frames) | C→S seconds | Status |
| --- | --- | --- | --- | --- |
| slow1 up | 12.50–12.95 (f753–775) | 13.00–13.50 (f783–808) | 0.10–0.95 | usable |
| slow1 down | 13.55–14.05 (f816–841) | 13.80–14.45 (f831–865) | -0.20–0.85 | usable |
| slow2 up | 16.15–16.65 (f971–996) | 16.55–17.05 (f995–1021) | not scored | censored: blank/indistinct |
| slow2 down | 17.20–17.65 (f1032–1056) | 17.45–18.05 (f1047–1081) | -0.20–0.85 | usable |
| slow3 up | 19.55–20.10 (f1175–1203) | 19.85–20.45 (f1193–1224) | not scored | censored: blank/indistinct |
| slow3 down | 20.55–21.05 (f1235–1260) | 20.80–21.65 (f1250–1296) | not scored | censored: blank/indistinct |
| slow4 up | 23.35–23.85 (f1402–1428) | 23.80–24.45 (f1427–1463) | not scored | censored: blank/indistinct |
| slow4 down | 24.35–24.85 (f1462–1488) | 24.60–25.45 (f1477–1523) | -0.20–1.05 | usable |
| fast1 up | 26.60–27.05 (f1595–1620) | 27.00–27.65 (f1619–1656) | not scored | ambiguous double image |
| fast1 down | 27.40–27.85 (f1643–1668) | 27.65–28.25 (f1658–1692) | -0.20–0.85 | usable |
| fast2 up | 29.20–29.65 (f1751–1776) | 29.60–30.05 (f1775–1800) | -0.05–0.85 | usable |
| fast2 down | 30.00–30.45 (f1799–1824) | 30.25–31.05 (f1814–1860) | not scored | censored: blank/indistinct |
| fast3 up | 31.80–32.25 (f1907–1932) | 32.20–32.85 (f1931–1968) | -0.05–1.05 | usable |
| fast3 down | 32.60–33.05 (f1955–1980) | 32.85–33.65 (f1970–2016) | -0.20–1.05 | usable |
| fast4 up | 34.20–34.65 (f2051–2076) | 34.60–35.25 (f2075–2111) | -0.05–1.05 | usable |
| fast4 down | 35.00–35.45 (f2098–2123) | 35.25–36.05 (f2113–2159) | -0.20–1.05 | usable |
| fast5 up | 36.80–37.25 (f2206–2231) | 37.20–37.65 (f2230–2255) | -0.05–0.85 | usable |
| fast5 down | 37.40–37.85 (f2242–2267) | 37.65–38.45 (f2257–2303) | -0.20–1.05 | usable |
| fast6 up | 39.00–39.50 (f2339–2364) | 39.40–40.10 (f2363–2400) | not scored | censored: blank/indistinct |
| fast6 down | 39.60–40.10 (f2375–2400) | 39.85–40.70 (f2390–2436) | -0.20–1.05 | usable |
| fast7 up | 41.35–41.85 (f2480–2505) | 41.75–42.45 (f2504–2541) | -0.05–1.05 | usable |
| fast7 down | 42.15–42.65 (f2528–2553) | 42.40–43.25 (f2543–2589) | not scored | censored: blank/indistinct |
| fast8 up | 43.80–44.25 (f2625–2650) | 44.20–44.85 (f2649–2686) | -0.05–1.05 | usable |
| fast8 down | 44.60–45.10 (f2673–2698) | 44.85–45.65 (f2688–2733) | not scored | censored: blank/indistinct |
| top entry up | 46.55–47.05 (f2790–2816) | 47.00–47.65 (f2815–2852) | -0.05–1.05 | usable |
| top exit down | 61.70–62.20 (f3694–3720) | 61.95–62.80 (f3709–3756) | not scored | censored: blank/indistinct |

## Comparative findings

**Slow response:** both clips visibly trail on raising and lowering. For example, control slow1 raise C f708–725=11.846011–12.129156s and S f729–749=12.195778–12.529000s yield0.066622–0.682989s; candidate slow1 raise C f753–775=12.545533–12.904089s and S f783–808=13.044511–13.461433s yield0.140422–0.915900s. These illustrative envelopes overlap substantially and are not point estimates or a basis for declaring the candidate slower. Other cycles are mixed or censored. A consistent meaningful slow-response improvement is not established.

**Fast response:** both clips show the camera arm already high while S remains near shoulder level, and the camera lowering while S remains raised. At control f1664=27.823556s versus candidate f1620=27.024244s (different cycles, not cross-video clock matching), the camera arm is high and the skeleton is still below/near level. The next several overlay updates catch up. Candidate excursions can look closer/completer in individual cycles, consistent with the prior internal signal evidence, but the repeated C→S enclosures broadly overlap. Blur and blanking censor some of the best potential comparisons. No reproducible visible speedup is demonstrated; moving-arm lag remains a practical issue.

**Bottom hold:** compare initial3–10s and final settled arms-down windows (control54–61s, candidate64–71s). When visible, elbow/forearm links stay reasonably close to the displayed relaxed arms; small marker drift/jitter and actual body/head movement exist in both. Candidate initial still pose contains clear blanks around5.70–5.82s; control initial3–10s has none under this screen. Final bottom holds blink in both. There is no obvious large sustained increase in candidate shaking, but no calibrated body-relative jitter RMS, equal-noise claim or statistical equivalence follows from these differently framed screen recordings.

**Top hold and settling:** control roughly42–51.8s, candidate48–61.5s. The arm skeleton catches up after entry and is near the preview elbow/wrist through held segments; both show short blinks and small position drift. Neither demonstrates a large sustained post-settling oscillation. Control top entry S enclosure41.19–41.82s overlaps its final-rise preparation and is censored by a brief blank; candidate47.00–47.62s includes visible catch-up. Around42–43s /48–49s respectively the arm is visually near its held location, with candidate intermittent blanking. These are qualitative settling windows, not fitted time constants. Final descents again leave S above the displayed arm for several updates. No consistent settling-speed advantage is established.

**Partial links:** the moving upper-arm connection is usually present while the main torso/face skeleton is present. Forearm/hand tips and local elbow markers sometimes become faint, doubled or indistinct in transition frames (e.g. control f1090=18.243311s and f1963=32.825267s; candidate f783=13.044511s). A marker alone is not proof the green limb was accepted: debug magenta/yellow markers are drawn separately from the renderer's confidence gate. This review does not establish a defensible exhaustive count of isolated renderer-rejected elbow/wrist links or a material reduction with .6; the prominent clear failures in these clips are whole-overlay absence. Indistinct local links are not converted into ordinary timing samples, and exposure blending is not mislabeled as a confidence rejection. Earlier bounded captures separately contain actual confidence/edge-rejection counts.

**Alignment:** during stationary/held segments, shoulder/torso lines and elbows broadly follow the displayed person in both builds. During fast transitions the skeleton upper arm/forearm can lie outside the visible arm and the wrist can remain above/away from the camera hand on descent. Yellow refined rings can also differ from the camera arm before magenta/green filtering displacement is considered. This is consistent with remaining input/prediction age plus signal delay, not evidence that the frozen mirror/cover transform changed. Neither build shows a new systematic opposite-side mirror, uniform crop offset or obvious scaling failure. Loose clothing, body drift, camera perspective and joint prediction prevent claiming calibrated anatomical accuracy from these clips.

## Whole-overlay blank/indistinct intervals

Green-color screening of every presentation-order arm/body crop found37control and46candidate discontiguous low-green groups. All were checked using adjacent and representative **full-preview** crops including legs and status text; the camera person remains visible. Clear groups often also show the UI changing from `Pose detected` to `Move into view with your whole body visible`. Some single-frame/short groups contain faint blended ghost overlays instead of a certified hard blank. Those remain **I** (indistinct) below; **B** means a clear whole-overlay absence in the reviewed full-preview frames. The strict screen is an interval inventory, not guaranteed exhaustive ground truth for every faint pixel or partial-link rejection. Neither hue counts nor external timestamps identify app loss cause on their own. No physical timestamp is added.

The same-duration8s top windows43–51s /49–57s contain8 /9screened discontiguous groups respectively, including indistinct groups. Initial3–10s has0 /2groups; final settled7s bottom windows54–61s /64–71s have6 /5groups. These small, fragmentable counts do not establish a beta-caused reliability difference. Exposure blending can split/merge apparent gaps. Application freshness/model reasons require exact session diagnostics; no unsynchronized wall-clock join was used to assign a cause to each video blink.

Each row lists the observed low-green frames and their actual PTS span, plus an **outer temporal enclosure** between the adjacent visible frames. The real absence begins/ends somewhere in the scan/exposure uncertainty around those frames. A single blank recording frame cannot prove an exactly16.7ms app blank: its duration bound is0 to the adjacent-PTS span. B/I classification concerns the visible record, not sensor exposure or Flutter presentation time.

### beta .3 blank inventory

| Group | Frames | Observed PTS span (s) | Outer enclosure (s) | B/I |
| --- | --- | --- | --- | --- |
| 0 | f799–799 | 13.361933–13.361933 | 13.345278–13.378589 | I |
| 1 | f983–987 | 16.461467–16.527822 | 16.444800–16.544478 | B |
| 2 | f989–993 | 16.561133–16.627322 | 16.544478–16.643978 | B |
| 3 | f1205–1205 | 20.159678–20.159678 | 20.143022–20.176333 | I |
| 4 | f1212–1212 | 20.276267–20.276267 | 20.259611–20.292922 | I |
| 5 | f1313–1313 | 21.975589–21.975589 | 21.959022–21.992156 | B |
| 6 | f1318–1321 | 22.058800–22.108867 | 22.042233–22.125522 | B |
| 7 | f1421–1423 | 23.773556–23.808644 | 23.756889–23.823533 | B |
| 8 | f1426–1430 | 23.860289–23.926956 | 23.840189–23.943622 | B |
| 9 | f1522–1522 | 25.457844–25.457844 | 25.441189–25.474500 | B |
| 10 | f1529–1529 | 25.574433–25.574433 | 25.557778–25.591089 | B |
| 11 | f1691–1692 | 28.274956–28.291611 | 28.258300–28.308267 | B |
| 12 | f1708–1708 | 28.557478–28.557478 | 28.540811–28.574144 | B |
| 13 | f1733–1734 | 28.990644–29.008511 | 28.957356–29.025167 | B |
| 14 | f1954–1955 | 32.675367–32.692022 | 32.657033–32.708678 | B |
| 15 | f2061–2061 | 34.457900–34.457900 | 34.441233–34.474567 | B |
| 16 | f2157–2157 | 36.057156–36.057156 | 36.040389–36.073811 | B |
| 17 | f2487–2487 | 41.554656–41.554656 | 41.538000–41.571311 | B |
| 18 | f2517–2517 | 42.052800–42.052800 | 42.036233–42.069367 | B |
| 19 | f2595–2595 | 43.368411–43.368411 | 43.351756–43.385967 | I |
| 20 | f2601–2601 | 43.469300–43.469300 | 43.452633–43.485222 | I |
| 21 | f2624–2625 | 43.852533–43.869200 | 43.835867–43.885867 | B |
| 22 | f2768–2769 | 46.251078–46.267733 | 46.234422–46.284722 | B |
| 23 | f2792–2792 | 46.650644–46.650644 | 46.633989–46.667300 | B |
| 24 | f2816–2820 | 47.050700–47.117322 | 47.034044–47.133978 | B |
| 25 | f2931–2931 | 48.968322–48.968322 | 48.951656–48.984989 | B |
| 26 | f2936–2938 | 49.051456–49.076611 | 49.034889–49.093344 | B |
| 27 | f3063–3063 | 51.166622–51.166622 | 51.149967–51.183278 | I |
| 28 | f3351–3353 | 55.964667–55.997978 | 55.948011–56.014633 | B |
| 29 | f3357–3359 | 56.064600–56.097911 | 56.047944–56.114567 | B |
| 30 | f3458–3459 | 57.765667–57.782333 | 57.749000–57.799000 | B |
| 31 | f3461–3462 | 57.815667–57.832333 | 57.799000–57.849000 | B |
| 32 | f3578–3578 | 59.763056–59.763056 | 59.746400–59.779711 | B |
| 33 | f3644–3645 | 60.862511–60.879167 | 60.845856–60.895822 | B |
| 34 | f3698–3698 | 61.764589–61.764589 | 61.747933–61.781244 | B |
| 35 | f3782–3782 | 63.164944–63.164944 | 63.148289–63.181600 | B |
| 36 | f3800–3803 | 63.463111–63.513078 | 63.446456–63.529733 | B |

### beta .6 blank inventory

| Group | Frames | Observed PTS span (s) | Outer enclosure (s) | B/I |
| --- | --- | --- | --- | --- |
| 0 | f342–344 | 5.698689–5.732000 | 5.682033–5.748656 | B |
| 1 | f348–349 | 5.798622–5.815278 | 5.781967–5.831933 | B |
| 2 | f727–727 | 12.112500–12.112500 | 12.095833–12.129167 | B |
| 3 | f1001–1004 | 16.693500–16.743500 | 16.676833–16.762200 | B |
| 4 | f1211–1211 | 20.186956–20.186956 | 20.170222–20.203689 | I |
| 5 | f1295–1297 | 21.595122–21.628456 | 21.576767–21.645122 | B |
| 6 | f1385–1385 | 23.111067–23.111067 | 23.094411–23.127722 | I |
| 7 | f1439–1439 | 24.009078–24.009078 | 23.992411–24.025744 | B |
| 8 | f1739–1740 | 29.006667–29.023322 | 28.990011–29.039978 | B |
| 9 | f1745–1747 | 29.106600–29.139911 | 29.089944–29.156567 | B |
| 10 | f1804–1804 | 30.089500–30.089500 | 30.072844–30.105667 | I |
| 11 | f1834–1834 | 30.590033–30.590033 | 30.573378–30.606689 | B |
| 12 | f1853–1862 | 30.905856–31.057444 | 30.889189–31.074111 | B |
| 13 | f2361–2365 | 39.404222–39.470889 | 39.389211–39.487556 | B |
| 14 | f2475–2478 | 41.305033–41.355000 | 41.288378–41.371656 | B |
| 15 | f2584–2586 | 43.113111–43.146578 | 43.096378–43.169167 | B |
| 16 | f2689–2691 | 44.902422–44.935756 | 44.885233–44.952422 | B |
| 17 | f2695–2699 | 45.002422–45.069089 | 44.985756–45.085756 | B |
| 18 | f2713–2714 | 45.302233–45.318889 | 45.285578–45.335544 | B |
| 19 | f2803–2803 | 46.801456–46.801456 | 46.784800–46.818111 | B |
| 20 | f2809–2810 | 46.901389–46.918156 | 46.884733–46.934811 | B |
| 21 | f2898–2899 | 48.385433–48.402089 | 48.368778–48.418744 | I |
| 22 | f2918–2918 | 48.713144–48.713144 | 48.696411–48.736411 | I |
| 23 | f2941–2941 | 49.102933–49.102933 | 49.086278–49.119589 | I |
| 24 | f2977–2977 | 49.702656–49.702656 | 49.687567–49.719311 | I |
| 25 | f2994–2994 | 50.002511–50.002511 | 49.969144–50.019167 | I |
| 26 | f3036–3036 | 50.695944–50.695944 | 50.679211–50.712678 | I |
| 27 | f3138–3138 | 52.406000–52.406000 | 52.389344–52.422656 | I |
| 28 | f3252–3255 | 54.306989–54.348856 | 54.290333–54.365589 | B |
| 29 | f3270–3271 | 54.607367–54.624033 | 54.590700–54.640700 | I |
| 30 | f3364–3366 | 56.192511–56.225822 | 56.175856–56.242478 | B |
| 31 | f3370–3373 | 56.292444–56.342411 | 56.275789–56.359067 | B |
| 32 | f3473–3473 | 58.008489–58.008489 | 57.991833–58.025144 | I |
| 33 | f3574–3574 | 59.691167–59.691167 | 59.674511–59.707822 | I |
| 34 | f3586–3586 | 59.891089–59.891089 | 59.874422–59.907756 | I |
| 35 | f3593–3595 | 60.007756–60.041089 | 59.991089–60.057756 | I |
| 36 | f3753–3753 | 62.704711–62.704711 | 62.682422–62.721367 | B |
| 37 | f3806–3806 | 63.598944–63.598944 | 63.582211–63.615678 | B |
| 38 | f3812–3813 | 63.705700–63.722356 | 63.689044–63.739011 | B |
| 39 | f3919–3921 | 65.488322–65.523333 | 65.471667–65.539989 | B |
| 40 | f3926–3929 | 65.604978–65.654978 | 65.588311–65.671644 | B |
| 41 | f3968–3969 | 66.305356–66.314767 | 66.288689–66.331500 | B |
| 42 | f4040–4040 | 67.500511–67.500511 | 67.483778–67.517244 | B |
| 43 | f4046–4046 | 67.600911–67.600911 | 67.584178–67.624189 | B |
| 44 | f4267–4268 | 71.296678–71.313333 | 71.271744–71.329989 | B |
| 45 | f4285–4286 | 71.596478–71.613133 | 71.579822–71.629789 | B |

One of the longer control gaps is f2816–2820 (47.050700–47.117322s, outer 47.034044–47.133978s); the longest candidate group is f1853–1862 (30.905856–31.057444s, outer 30.889189–31.074111s). Other flickers are frequently 1–5 recording frames. This describes observed gaps, not an averaged application availability SLA; no interpolation joins brief reappearance between groups.

## Internal evidence remains separate

The [bounded beta experiment report](2026-10-05-pose-beta-responsiveness-experiment.md) contains the internal five-phase comparison. Its representative one-arm fast elbow median refined→filtered displacement 11.17→9.81px and wrist 21.32→17.14px, plus more complete excursions, support a modest **filter signal** benefit. Those captures are separate sessions/trajectories, not the external-video timing rows above. Internal conservative crossing bounds also overlap. Fast processed/delivered/drawable FPS 11.33→10.93, worker 87.02→90.09ms, callback→UI 105.48→108.92ms, first CPU paint 115.66→120.07ms and nonempty expiry 0→3 do not establish computation improvement from beta. Diagnostic trace/delivery/paint CPU remains about 0.04/0.005–0.007/0.08ms in that phase. Model confidence and renderer gates are unchanged. Filter execution cost ~0.1ms does not measure signal delay.

No internal duration is added to C→S. Previous Step 2C optimized preprocessing remains the computation baseline; reverting beta leaves that optimization intact. The external screen comparison cannot isolate exposure/input age from prediction/refinement/filtering or measure physical total latency. Inspecting displayed camera versus yellow refined joint and explaining periodic whole-pose blanking on exact session timestamps is the next useful investigation; **no new tuning experiment was implemented**.

## Rollback and verification

The original beta .3 controller is restored byte-for-byte against its preserved source hash. Both APKs, candidate controller and candidate-only test source, internal evidence, both originals/copies and this analysis remain preserved. The beta .6-only controller assertion was removed from the active suite with its archived candidate source; it asserted the experimental responsiveness contract that was intentionally rolled back, not a production requirement. Shared filter, preprocessing, geometry, timestamp, acceptance and lifecycle tests remain active. An initial overlapping suite run still read that candidate-only assertion and failed at the expected control output 0.4450133781525032; after restoration/removal the fresh suite passes. This failure was not hidden or addressed by a second tuning change.

Fresh verification: default mobile suite **134 passed / 4 define-gated tests skipped**; all four gated cases exercised separately by preview-enabled UI/render tests (**4 passed**) and quality/joint-debug controller tests (**10 passed**). Shared pose suite **14 passed**. Mobile and pose analysis both **no issues**. The bounded diagnostic parser tests also pass (**3 tests**); decoded PTS indices, all 52 reviewed event anchors and interval calculations were checked for consistency, and both original recording hashes were reverified. The 180-file control manifest matches completely after rollback. ADB installation of the preserved control succeeded, installed SHA-256 matches `774345…2bf5a`, and camera service reports **Active Camera Clients: []**. No replacement build, model change, permission/security-setting change or automatic preview run was needed.

**Disposition:** computation optimization retained; beta 0.3 restored as the working control; beta 0.6 retained only as a preserved candidate artifact/evidence. The motion-response comparison is inconclusive, so the strict acceptance gate fails. Stability is not proved worse, nor is total physical latency solved. Step 3 remains deferred. A next investigation should identify remaining C→refined lag and reason-coded whole-overlay blinks before another single-variable optimization is selected.
