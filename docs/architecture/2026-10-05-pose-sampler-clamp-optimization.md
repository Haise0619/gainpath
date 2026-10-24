# Step 2I — finite YUV clamp optimization

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Date: 2026-10-05. Device: Xiaomi `23013RK75C`, Android 13, ADB serial `xiaomi-device-serial-redacted`.

## Decision

Retain the sampler change as the new **computation baseline**. Preprocessing improved in both physical phases, with bitwise-equivalent tensors in the deterministic comparisons. The benefit during fast arm movement was substantially smaller than during still tracking. This is not evidence that visible arm lag, anatomical accuracy, or physical camera-to-display latency is solved.

**Step 2 quality acceptance remains pending. Step 3 remains deferred.** No additional parameter experiment was implemented. The pre-change two-thread beta 0.3 APK remains available for rollback and matched external comparison.

## Hypothesis and isolated change

A 20.009-second CPU sample profile of the unchanged control found 16,426 worker samples. `preprocessImage` occurred in 5,955 inclusive stacks (36.25% of sampled worker CPU); 1,911 of those contained `clamp`, and 616 contained `compareTo`. These overlapping inclusive counts are diagnostic attribution, not additive wall-time fractions or physical latency measurements. Profiling was disabled again before the paired captures.

The only main-app source difference is in `apps/mobile/lib/infrastructure/pose/blazepose_geometry.dart`: three per-pixel YUV channel calls to generic `num.clamp(0, 255)` now use a private typed comparison helper. Byte-derived YUV channels and fixed coefficients are finite. The helper preserves saturation endpoints, coefficients, arithmetic order, and clamping of each source corner **before bilinear interpolation**. It does not change the sampled positions or tensor normalization.

Frozen settings: beta 0.3; minCutoff 1; derivative cutoff 1; two interpreter threads; model/assets/tensor contracts; confidence and renderer acceptance thresholds; detector/ROI cadence; camera resolution; projection, rotation, mirroring and cover/crop; 250 ms freshness; 100 ms watchdog; latest-frame backpressure. Mock mode and the existing Workout UI remain intact.

Test/tool additions preserve a frozen Step 2C sampler reference, compare complete tensor hashes before timing, and include a literal saturated-corner midpoint test. No new raw-frame capture, video capture, landmark stream persistence, upload, or workout activity was added. Existing bounded diagnostic reports were collected locally.

## Artifact provenance

Both APKs are profile builds, 147,165,566 bytes each.

| Artifact | SHA-256 |
|---|---|
| `apps/mobile/build/pose-quality/step2g-threads2-control-profile.apk` | `9d5c0183d9567deea2bde9a01185678cfdfdc999b10c6b5b269054d820a0fc07` |
| `apps/mobile/build/pose-quality/step2i-sampler-candidate-profile.apk` | `747c9972a5253037f44f796d388f30f017cccdf42fd8f235595c9ae06b78c7e4` |

The installed candidate hash was read back through ADB after installation and after capture. Model version remains `mediapipe-full-e9a5c5cb-det-9ba9dd3d`; runtime tensor verification is true, with repeated 33-landmark output.

Source audit: 181 control-manifest files checked; only `blazepose_geometry.dart` differs. APK audit: all 309 entries outside signatures and compiled Dart `libapp.so` files are byte-identical, including model assets, native libraries and resources. The only changed unsigned entries are the three architecture-specific `libapp.so` files.

Build defines: `GAINPATH_BACKEND=mock`, `GAINPATH_POSE_PREVIEW=true`, `GAINPATH_POSE_QUALITY_DEBUG=true`, `GAINPATH_POSE_JOINT_LAG_DEBUG=true`, `GAINPATH_POSE_BLANK_DEBUG=true`.

## Deterministic verification

The manual AOT performance gate failed before the change, as intended: control/candidate ratios were approximately 1.019, 0.964 and 0.970. After the change it passed the required ≥1.10 speedup for both landmark cases with no >5% regression in any case.

Synthetic YUV420 720×480, rotation 270°, chroma pixel stride 2; five warm-up batches per kernel, nine alternating measured batches per kernel, five invocations per batch. Windows Dart 3.10.8 AOT; these are host preprocessing measurements without camera or TFLite inference.

| Case | Control median ms | Candidate median ms | Control/candidate ratio |
|---|---:|---:|---:|
| Full-frame detector | 3.8304 | 3.0798 | 1.244 |
| Rotated landmark ROI | 5.8432 | 4.7050 | 1.242 |
| Expanded landmark ROI | 5.5674 | 4.2340 | 1.315 |

All three complete tensor hashes match bitwise. Geometry/equivalence verification passed before and after the change, including 96 complete tensor differential cases. Full mobile tests: 148 passed, five define-gated skips; mobile analysis: no issues. Shared pose tests: 14 passed; analysis: no issues. Profile APK build succeeded. Timing assertions remain outside normal unit/CI tests.

## Paired physical measurement method

Control session `1791212061835633`; candidate session `1791212396737201`. Each build used a fresh preview, with separate still and fast one-arm captures of approximately 20 seconds. The user confirmed each capture completed and ended both previews. Lighting, framing and movement were requested to match, but input trajectories were not identical, and no new external comparison video was supplied during these captures.

For interior telemetry, choose the first complete five-second poll at least three seconds after capture start, then the next two polls, all before capture +18 seconds. Difference cumulative timing sums/counts across the approximately ten-second completion window. Rolling percentiles are not differenced. Poll/window boundaries are approximate and not identical input-frame cohorts for every stage. No profiler was running during these captures.

Control still window: 22:54:36.837–22:54:46.838; fast: 22:56:11.838–22:56:21.838. Candidate still: 23:00:16.740–23:00:26.740; fast: 23:02:46.744–23:02:56.744. Times are local device log timestamps; exact selected polls are preserved in `paired-interior.json`.

| Interior metric | Control still | Candidate still | Control fast | Candidate fast |
|---|---:|---:|---:|---:|
| Camera received FPS | 30.00 | 30.00 | 30.00 | 30.00 |
| Processed / delivered / drawable FPS | 11.20 | 13.70 | 11.30 | 11.50 |
| Unique first CPU paint FPS | 11.20 | 13.70 | 11.20 | 11.50 |
| Total preprocessing mean ms | 36.84 | 21.03 | 36.26 | 27.78 |
| Landmark preprocessing mean ms | 35.03 | 19.99 | 34.66 | 26.83 |
| Detector preprocessing mean ms | 25.36 | 15.78 | 25.88 | 15.61 |
| Total native inference mean ms | 50.54 | 50.30 | 50.63 | 55.98 |
| Worker computation mean ms | 88.14 | 72.01 | 87.60 | 84.66 |
| Pending-frame age mean ms | 16.57 | 16.92 | 17.92 | 16.88 |
| Callback → UI mean ms | 106.63 | 90.84 | 107.64 | 103.56 |
| Callback → first CPU paint mean ms | 118.22 | 102.81 | 119.19 | 115.54 |
| Replaced pending frames | 188 | 163 | 188 | 185 |
| Stale results / empty pose results | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Nonempty overlay freshness expiries | 0 | 0 | 0 | 1 |

Still preprocessing fell about 43%, worker computation about 18%, with drawable FPS about 22% higher. Fast preprocessing fell about 23%, but native inference increased about 5.36 ms, leaving only about 2.94 ms worker improvement and 3.65 ms callback-to-paint improvement. No model or threading change explains that native-time increase; input differences, run order and device variability were not isolated. A repeated or randomized run would be needed to estimate variability. Do not claim a uniform motion speedup from one pair.

Diagnostic trace means were about 0.042 ms in both still runs, and 0.059/0.046 ms in control/candidate fast. Joint diagnostic CPU-paint means were 0.084/0.106 ms still and 0.103/0.120 ms fast. These execution costs are separate from temporal filter signal delay.

These are callback/worker/CPU-paint observations. They exclude sensor exposure and physical display presentation and must not be combined with external C/R/S brackets into an invented total physical latency.

## Blanking, links and projection

Full bounded capture ledgers, distinct from the narrower interior windows:

| Phase | Control logical blanks / CPU-painted blanks | Candidate logical blanks / CPU-painted blanks | Initial causes |
|---|---:|---:|---|
| Still | 1 / 1 | 0 / 0 | Control: one freshness expiry |
| Fast | 10 / 8 | 1 / 0 | Control: nine freshness expiries, one low landmark pose presence; candidate: one freshness expiry |

The candidate fast expiry occurred with a valid refined/filtered 33-joint frame, all 33 joints accepted, pose presence about 0.99997 and last detector confidence about 0.96795. The watchdog cleared that pose at age about 281 ms. A detector refresh result recovered the overlay state roughly 3.2 ms later, before any blank CPU paint was observed. It is a **logical-only expiry**, not evidence of a visible screen blank. The interior fast expiry count nevertheless rose from zero to one; disclose this alongside the more favorable full-phase counts. Physical display blank duration was not measured.

All four reports completed without transport errors, capacity overflow or timestamp mismatches. Bounded joint-diagnostic painted-frame counts were 222/270 for control/candidate still and 214/231 for fast; these capture-scope counts differ from interior telemetry.

Moving-side right elbow/wrist projection residuals were zero in both builds. Fast joint rejection remained: elbow 2/213 versus 6/231; wrist 7/213 versus 8/231. Visibility and presence rejection can overlap. Actual right upper-arm link rejection was 3/214 versus 6/231; forearm rejection 8/214 versus 8/231. Off-viewport elbow observations were 4 versus 6, wrist 8 versus 7. Partial links have not been eliminated, and these unmatched short samples do not establish improved reliability.

Fast refined→filtered image-space displacement mean/p95 was 10.55/29.45 px versus 7.78/16.87 px for right elbow, and 18.69/33.28 px versus 13.35/31.61 px for right wrist. Beta is unchanged. These differences depend on the actual motion, prediction and sampling cadence; they are neither a matched crossing-delay measurement nor proof of reduced filtering signal delay.

Still right elbow displacement p95 was 10.19 versus 12.04 px, wrist 7.79 versus 12.75 px. Refined→filtered displacement is not stationary jitter. Settling, anatomical alignment and held stability cannot be declared improved from this aggregate. No new user assessment of visible lag/stability was supplied.

Both End-preview actions released the camera (`Active Camera Clients: []`). Candidate lifecycle-close was logged; the final installed APK hash remained correct. Temporary profiling/ADB forwarding was cleaned up. The full physical pause/background/logout matrix was not repeated in this experiment; existing lifecycle tests passed.

## Evidence and next boundary

Local evidence directory: `apps/mobile/build/pose-quality/step2i/`. Preserve the control/candidate logs, bounded joint/blank JSON, paired interior report, CPU profile attribution, source manifest, build provenance, test/analysis/build logs and cleanup checks. AOT outputs are in `apps/mobile/build/pose-quality/preprocessing-aot/step2i-sampler-{red,green}.json`. These build directories are ignored; this report is the durable result summary.

Next, use a matched close-screen recording of control and retained candidate in the same sitting, with the camera arm, yellow refined rings and filtered skeleton legible. Use the same one arm, framing, lighting, slow/fast shoulder-level crossings and top/bottom holds. Decode actual presentation timestamps and compare C→R and C→S independently, preserving censored crossings and interval uncertainty; screen-only recordings cannot measure P→C or P→S. Inspect held shaking, settling, partial links and whole-overlay blanks. No further parameter tuning is justified by this sampler experiment alone.

Follow-up, 2026-10-06: the paired screen recordings have now been [analyzed](C:/Users/Ngzhe/StudioProjects/gainpath/docs/architecture/2026-10-06-pose-step2i-screen-comparison.md). The new session telemetry corroborates the computation improvement. Visible arm-response speedup remains inconclusive, with two sampled control whole-overlay blanks and none found in candidate screening. Step 2 quality remains pending; no further parameter tuning was implemented.
