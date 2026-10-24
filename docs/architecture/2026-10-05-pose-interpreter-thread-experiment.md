# Step 2G — isolated interpreter thread experiment

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

**Decision: reject the four-thread candidate and restore the two-thread control.** The Xiaomi showed a small still-phase computation gain without lower callback age, and the motion window was slower. No additional tuning was stacked. Step 2 quality acceptance remains unmet; Step 3 remains deferred.

## Scope and provenance

User approved the proposed interpreter threads **2 → 4** experiment after Step 2F. One literal in `apps/mobile/lib/infrastructure/pose/blazepose_detector.dart` configured both detector and landmark interpreters with four threads. Inference remained sequential inside the existing background worker. This is a configured thread count, not proof that every kernel uses four threads or that four threads are the entire application's thread population.

All other production settings stayed frozen: beta .3, minCutoff1, derivative cutoff1, BlazePose assets/tensor contracts, thresholds, detector/ROI cadence, interpreter/runtime versions, camera resolution, orientation/mirroring/cover transform, renderer acceptance,250ms freshness,100ms watchdog and latest-frame backpressure. Step 2C preprocessing remained retained. Mock backend and existing Workout UI remained in use; no workout upload, acceptance, scoring or RepFSM was added.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Two-thread control profile APK | 147165566 | `9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07` |
| Four-thread candidate profile APK | 147165566 | `e3028bcc332f939148a9e51371449c37a24a559d78050724393eb12211fb8c78` |

Both are preserved under `apps/mobile/build/pose-quality/` as `step2g-threads2-control-profile.apk` and `step2g-threads4-candidate-profile.apk`. Build logs, source manifests, the candidate detector source snapshot and comparison evidence are preserved under the ignored `step2g/` folder. Candidate build command:

```text
flutter build apk --profile --no-pub --dart-define=GAINPATH_BACKEND=mock --dart-define=GAINPATH_POSE_PREVIEW=true --dart-define=GAINPATH_POSE_QUALITY_DEBUG=true --dart-define=GAINPATH_POSE_JOINT_LAG_DEBUG=true --dart-define=GAINPATH_POSE_BLANK_DEBUG=true
```

Defines match the control. As documented previously, `GAINPATH_BACKEND` is unused; actual `BACKEND` defaults to mock. No backend changed.

Strict source isolation was verified against the installed Step 2F control's180-file manifest. The candidate used the exact preserved diagnostic source rather than its later four lint-only brace additions. **Only the detector file differs**; replacing its `threads = 4` literal with2 reproduces the control detector hash. The additional blank recorder matches its preserved control source. Both temporary source substitutions were restored after building, and all pre-experiment source hashes match again. Candidate APK inventory is identical; only the three architecture-specific compiled Dart `libapp.so` entries differ. All29 frozen model/native/runtime/manifest/resource/Dex entry hashes match.

Device: physical Xiaomi **23013RK75C**, Android13, serial `xiaomi-device-serial-redacted`, portrait front camera,720×480 YUV input rotated to480×720, sensor orientation/rotation270°. Model version `mediapipe-full-e9a5c5cb-det-9ba9dd3d`; runtime tensor verification remained true. Candidate device-side SHA was verified before captures. Control was reinstalled after analysis and its device-side SHA matches again. User ended preview; camera service recorded disconnect at21:22:21 local and **Active Camera Clients: []**. Current source still configures two threads.

## Paired captures and analysis method

Each build had a fresh preview and bounded20s still and fast one-arm phases. User used the same arm, approximate pace, framing and brief top/bottom holds. These are observed physical runs, not identical input-image replays or randomized repetitions. Control session `1791205786312005`; candidate `1791206187430375`.

Periodic telemetry was grouped into complete polls from `POSE_FOUNDATION_METRICS` through the corresponding quality viewport record, with explicit session/capture identity. The previous generic summary tool's latest-session/prefix assumptions were not used on mixed ring-buffer snapshots. End-of-phase debug-report output can delay log emission, so no poll emitted amid that output was used as an interior timing endpoint.

Means are cumulative total/count differences, `(nB·meanB − nA·meanA)/(nB − nA)`, from three complete interior polls spanning approximately10s. They describe a completion/observation window, not exact input-time phase cohorts. Four-decimal logged cumulative means introduce recorded rounding error bounds; small overhead differences must not be overinterpreted. Existing rolling p50/p95 values include earlier samples and are retained separately, **not called interior-window percentiles or subtracted**. FPS uses counter differences over the endpoint interval and is cross-checked with interval-rate samples. Root independently verified source-log hashes, endpoint arithmetic for100 stage/window combinations and FPS arithmetic against raw logs.

| Window | Local endpoint times | Phase offsets | Worker / delivery / first-paint samples | Detector invocations |
| --- | --- | --- | ---: | ---: |
| Control still | 21:09:56.313–21:10:06.315 | +4.98–14.99s | 112 | 8 |
| Candidate still | 21:16:37.431–21:16:47.431 | +6.15–16.15s | 116 | 8 |
| Control fast | 21:11:46.318–21:11:56.315 | +6.57–16.56s | 105 | 7 |
| Candidate fast | 21:18:52.434–21:19:02.431 | +4.35–14.35s | 98 | 6 |

All four selected windows have nonempty pose results, zero stale results, zero timestamp mismatches and complete uncensored transport. The full-phase reliability ledger is kept separately; selecting a clean interior must not hide failures near its boundaries.

## Computation and delivery results

Approximate window means in milliseconds; FPS rounded to two decimals. Camera received rate remained approximately30FPS.

| Metric | Still: 2 threads | Still: 4 threads | Fast: 2 threads | Fast: 4 threads |
| --- | ---: | ---: | ---: | ---: |
| Detector inference, per invocation | 34.81 | 32.65 | 43.23 | 45.31 |
| Landmark inference, per invocation | 48.27 | 45.38 | 49.96 | 51.02 |
| Total native inference, per processed result | 50.76 | 47.63 | 52.84 | 53.79 |
| Preprocessing, per processed result | 35.96 | 36.06 | 39.90 | 45.84 |
| Worker computation | 87.47 | 84.36 | 93.52 | 100.35 |
| Callback queue age | 15.46 | 18.70 | 17.41 | 16.74 |
| Callback → UI | 104.95 | 105.02 | 113.23 | 119.59 |
| Callback → first CPU paint | 116.02 | 116.18 | 124.60 | 131.02 |
| Processed / delivered / drawable FPS | 11.20 | 11.60 | 10.50 | 9.80 |
| Replaced pending inputs | 188 | 184 | 194 | 201 |
| Stale / empty results | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

Native time is the sum of native calls made for a result; detector refresh is intermittent. Therefore detector and landmark invocation means must **not** be added and called per-frame native time. Pipeline, queue, UI and paint measurements are also distinct overlapping boundaries, not terms to sum into physical latency.

Still native time improved about6.2%, worker3.6% and drawable rate3.6%. The approximately3.2ms increase in observed queue age offset the worker gain; callback→UI/paint ages were essentially unchanged. Fast worker time was about7.3% higher, first CPU paint age5.2% higher and drawable rate6.7% lower. Preprocessing code was identical, yet its runtime increased in the candidate motion window; the experiment cannot establish whether scheduling, device load, thermal conditions or movement/ROI differences caused that variance. It does not prove four threads inherently cause every regression. It **does fail to demonstrate a reliable useful benefit**.

Diagnostic metadata costs remained small and unchanged in design. Still control/candidate mean trace .054/.040ms, joint delivery .004/.004ms, joint paint .098/.077ms, blank delivery .021/.031ms, blank paint .046/.020ms. Fast equivalents .042/.053ms, .003/.004ms, .087/.082ms, .026/.023ms, .067/.064ms. These are individual instrumentation boundaries with different sample counts, not a summed total diagnostic cost; blank-paint timing excludes primitive-intersection calculation, and phase-end logging is excluded from the selected windows. The filter's tiny execution cost does not measure its signal delay.

## Blanks, joint acceptance and stability limits

| Whole20s phase | Matched paint observations | Pose / no-person outcomes | Logical freshness clears | CPU-confirmed freshness blanks | Other blank episode |
| --- | ---: | --- | ---: | ---: | --- |
| Control still | 225 | 225 / 0 | 0 | 0 | none |
| Candidate still | 231 | 231 / 0 | 2 | 1 | none |
| Control fast | 203 | 203 / 0 | 6 | 6 | none |
| Candidate fast | 197 | 189 / 8 | 6 | 3 | one setup-period detector-no-person blank |

The candidate's197 matched paints are **not197 valid pose outputs**. Its initial no-person blank began about+0.016s and lasted approximately782ms between blank/recovery CPU observations. It is kept separate from freshness and from normal motion-lag samples. It occurred during button/position setup; no video establishes the person's camera visibility at that instant, so it is not attributed to thread count or discarded as a proven physical absence.

Control motion's six freshness blank CPU spans were approximately14–63ms. Candidate still has one CPU span about21ms and one logical-only clear; candidate motion has three freshness spans about15–49ms and three logical-only clears. All freshness episodes recovered. Candidate still's two expiries lie just outside its chosen interior; its zero interior expiry count must not be reported as an expiry-free full still phase. Within fast interior, control has2 logical/2 CPU blanks; candidate3 logical/2 CPU blanks. Fewer full-phase CPU-painted blanks in one candidate run do not establish more reliable tracking when logical expiry remains and still reliability is worse.

Confidence and viewport findings remain independent of whole-overlay expiry. Still left/right elbow rejection control1/1 versus candidate3/1; wrist7/5 versus10/8. Fast elbow rejection control1/4 versus candidate0/0; wrist10/7 versus2/0. Fast upper-arm/forearm draw-issued counts for the moving model-right side control199/196 of203 and candidate189/189 of197; missing-coordinate observations on empty results are retained separately. The mixed still/motion acceptance changes and different trajectories do not prove accuracy improvement or degradation from threads. No sampled numerical projection residual or timestamp binding defect was found.

This experiment did not record a held-only complete coordinate fixture or an external screen video. Whole-phase displacement percentiles include transitions/setup and cannot establish stationary jitter RMS or physical settling time. The earlier verified filter signal discrepancy remains; beta .3 and cutoffs were untouched.

## Sustained check and acceptance

The candidate preview stayed open for approximately six minutes, but after the fast phase only a short person-valid tail remained before explicit low-pose-presence/no-person results (first low presence about2.9s after phase end). There is no clean complete all-pose post-phase poll interval. A clean subsequent125s interval contained1,732 detector-no-person results, zero landmark invocations and zero drawable FPS. Later cumulative processed/delivered FPS around13.45 includes empty frames and is **not drawable-person FPS or a sustained full-body success**. This run cannot verify sustained thermal performance on a continuously tracked person. Android reported thermal status0, no override and no temperature readings; there is no measured temperature curve or basis for a thermal-cause claim. The sustained evidence is retained and labeled rather than averaged into the valid-person comparison.

The four-thread candidate is rejected. The exact two-thread Step2F control APK was reinstalled and device-side SHA verified; source restored to its pre-experiment hashes. The candidate and evidence remain preserved for review. No model, cadence, resolution, confidence, filter, freshness, watchdog or backpressure tuning followed the failed experiment.

Fresh checks: full mobile suite **147 passed / 5 define-gated skipped**; diagnostic-enabled affected suite **38 passed**; mobile static analysis clean; Python parsers **17 passed**. Build succeeded and artifact isolation checks passed. No new implementation-mirroring thread-count unit test was added: this is a one-literal configuration experiment, with physical A/B performance as its acceptance evidence.

**Step2 quality acceptance remains unmet.** Current computation evidence favors keeping two threads. It does not resolve displayed-camera→refined-joint prediction/input-age lag, physical person→display timing, anatomical accuracy or persistent partial-link instability. The next evidence should be a legible original close-screen recording showing camera arm, yellow refined joint and skeleton together; review C→R and C→S before another responsiveness change. This is a recommendation for the next diagnostic boundary, not a new tuning implementation. Step3/RepFSM/scoring/audio/upload remain deferred.
