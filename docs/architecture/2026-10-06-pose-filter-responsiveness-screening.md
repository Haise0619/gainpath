# Step 2O: offline filter responsiveness screening

## Outcome and next experiment

The offline comparison is complete. **Recommend a separate GPU diagnostic trial changing only preview-filter beta from 0.3 to 1.2, with minCutoff and derivative cutoff both retained at 1.** Beta 1.2 has not been applied, built or installed in this step. The installed Step 2N filtered GPU build remains the control; CPU remains the default/rollback. Overall Step 2 quality is unaccepted and Step 3 remains deferred.

On the identical synthetic motion at 19–21 FPS, beta 1.2 reduces elbow/wrist motion p95 refined→filtered displacement by 22–35% across slow/fast raises/lowers. The held-noise proxies show at most 4.4% greater filtered radial RMS and 7.7% greater peak error. This warrants a physical experiment, not production adoption. Raising minCutoff alone to 1.5 shows up to 40% greater held-noise RMS, so it is not selected for the next phone trial.

Accepted prediction excursions are a separate risk: at 20 FPS an invented one-frame 50 px spike produces a 15.26 px filtered excursion with beta 1.2 versus 12.84 px with beta 0.3. No filter setting repairs an incorrectly predicted joint, confidence rejection or constant anatomical bias. Physical held stability, partial links and external camera→filtered response must decide acceptance.

## Why this follows Step 2N

The user observes that normal filtered green is steadier than yellow refined rings but noticeably slower than Step 2M's refined green skeleton. Those greens represent F and R respectively; the observation is not a GPU computation regression. Step 2N already delivers approximately 19–21 FPS in warmed capture interiors, with healthy computation and no interior expiry increments. Another computation-only change would not directly remove the verified filter signal response.

This step uses the existing production filter offline, before selecting another phone experiment. It does not infer physical-person latency, join internal telemetry to external crossing intervals, or treat the earlier beta 0.6 trial as proof of a bad filter. Step 2E's physical external result was inconclusive and failed its full acceptance gate. Beta 0.6 is included here only as historical context, not proposed again as a candidate.

## Source and coordinate audit

- `blazepose_decode.dart` inverse-projects ROI points to upright image space, then divides X by image width and Y by image height. Image Z uses width units. The real image frame is unmirrored.
- `PosePreviewController` passes that refined frame to `PoseFrameFilter`, and retains R alongside F for timestamp-matched diagnostics. The normal skeleton uses F. Preview mirror/cover/crop remains a later presentation transform.
- `PoseFrameFilter` filters independent X/Y/Z streams. Its time is `capturedAtMicros / 1e6`, not UI delivery or paint time. Frame identity, capture timestamp and confidence are preserved. Low confidence bypasses smoothing and clears that joint's filter state; missing/nonfinite joints and stream-generation resets retain their existing handling.
- The existing One Euro implementation computes the derivative from the current input minus the **previous filtered value**, divided by capture-time delta. It smooths that derivative at 1 Hz and sets `cutoff = minCutoff + beta * abs(derivative)`. This derivative feedback is retained exactly; no alternative filter algorithm is substituted.
- Beta therefore acts on normalized-coordinate change per second for image points. A beta tuned for pixels would not be interchangeable. The code and input units are consistent; this audit establishes no pixel/normalized-unit projection bug. At zero derivative, minCutoff 1 gives a time constant `1/(2π)` ≈159 ms and alpha ≈0.239 at a 50 ms input interval. That is a filter coefficient/time constant, **not** measured camera/display delay.
- The same parameter currently also applies to world-coordinate streams in metres. The offline responsiveness/noise study concerns image points; it does not accept world kinematics or exercise rules.

## Reproducible bounded method

Tool: `apps/mobile/tool/pose_filter_tradeoff_probe.dart`. It imports the real `PoseFrameFilter`, plus the retained Step 2D synthetic fixture. It imports no camera, controller, workout, storage or submission API. Synthetic coordinates exist in RAM; output contains only aggregate distributions, crossing brackets and configuration metadata.

The fixed shortlist is control beta .3/minCutoff 1; historical beta .6/minCutoff 1; beta 1.2/minCutoff 1; and beta .3/minCutoff 1.5. Derivative cutoff remains 1 throughout. Each alternative changes only one variable relative to control. This is a limited screening comparison, not a searched optimum.

Each configuration receives exactly the same integer capture timestamps and input coordinates within a cadence. The time-based Step 2J trajectory is reused: slow ramps last 3 seconds, fast ramps .6 seconds, with clean top/bottom holds. Nominal cadences are 19, 20 and 21 FPS with deterministic ±3% interval variation. Image dimensions are 480×720, shoulder Y is .35, elbow moves .70→.15 and wrist .85→.10. All points are finite and above the unchanged confidence gate. No reset, missing result or acceptance censor is injected into the clean motion.

The existing 95-frame Step 2D fixture is replayed unchanged as an independent historical control. Its nominal pace is different from the GPU-rate fixtures, so its numbers are kept separate. It is synthetic, not a phone-recorded landmark stream. The retained physical reports have only sparse representatives and cannot supply a complete deterministic trajectory.

Stationary-noise proxies use fixed true positions, with nominal 1/3/8 image-px per-axis RMS inputs: seeded uniform white noise, a .4 Hz sinusoid, and a 6 Hz sinusoid. The two sinusoidal axes are in quadrature. Each run lasts 24 seconds; the first four seconds are excluded. Reported radial RMS/p95/max are displacement from the known stationary truth, **not R−F displacement and not measured human jitter**. Identical noise input is supplied to every configuration. Confidence stays unchanged, so these tests cannot assess reliability under model confidence loss.

An additional bounded check injects a single accepted 25 or 50 px Y excursion after eight seconds of exact still input. It reports filtered peak and return-to-below-one-pixel brackets separately from stationary-noise statistics. Real prediction errors may be correlated, persistent or much larger than these fixtures.

Crossing intervals use adjacent actual fixture timestamps: `[F_lower − R_upper, F_upper − R_lower]`. There is no interpolation. An independent Python check verifies each R bracket against the analytic ramp crossing and recalculates interval subtraction. All clean events are observable; no censored synthetic event is averaged. This does not eliminate censoring in physical videos.

## Representative synthetic results

At nominal 20 FPS, p95 displacement in upright image pixels:

| Joint/motion | beta .3 control | beta .6 historical | beta 1.2 | minCutoff 1.5 only |
|---|---:|---:|---:|---:|
| Elbow slow raise | 17.64 | 15.81 | 13.64 | 12.73 |
| Wrist slow raise | 23.00 | 20.25 | 17.11 | 16.88 |
| Elbow fast raise | 65.00 | 53.97 | 43.09 | 51.64 |
| Wrist fast raise | 81.86 | 66.89 | 52.83 | 66.15 |

Across all 19–21 FPS raises/lowers, beta 1.2 p95 displacement reductions range from 22.36% to 35.48%. Higher minimum cutoff reductions range from 19.02% to 28.03%, with greater stationary-noise transmission.

Representative 20 FPS R→F crossing intervals, rounded outward to whole milliseconds:

| Joint/event | beta .3 | beta 1.2 |
|---|---:|---:|
| Elbow slow raise | 50–150 ms | 50–150 ms |
| Wrist slow raise | 100–200 ms | 48–150 ms |
| Elbow fast raise | 48–150 ms | 0–99 ms |
| Wrist fast raise | 48–150 ms | 0–99 ms |
| Wrist fast lower | 0–99 ms | 0–99 ms |

These intervals overlap substantially; they do not establish an exact crossing-delay reduction. Zero lower bounds mean sampling uncertainty, not instantaneous response. The deterministic spatial-displacement comparison gives stronger screening evidence here.

After the exact fast ramp endpoint, both elbow and wrist settle and stay within 1 px of the clean target in approximately 598–650 ms for control versus 298–350 ms for beta 1.2 at 20 FPS. This strict synthetic convergence criterion is not first response, physical settling or displayed-camera latency. Small floating-point endpoint rounding is retained in aggregate JSON; the brackets above are rounded outward.

The retained older fixture reproduces the prior control slow-raise mean elbow/wrist displacement 27.05/35.16 px and fast-raise 75.67/96.47 px. Beta 1.2 yields 19.94/24.50 and 49.65/58.89 px respectively. This consistency does not turn the fixture into physical evidence.

Across the 27 stationary-noise scenarios, beta 1.2 increases filtered radial RMS by at most 4.37% and peaks by at most 7.61%. The minCutoff 1.5 alternative increases RMS by at most 39.91% and peaks by at most 38.59%. Both still attenuate these invented inputs. Beta 1.2 also transmits an isolated 50 px spike more strongly; the 20 FPS recovery bracket remains 401–450 ms after the input returns to its true position for both betas. A more responsive filter may follow confident wrong predictions more visibly.

## Verification and preserved evidence

- Two full probe runs are byte-identical. Tool self-checks verify frozen defaults, same-frame timestamp/identity/confidence, finite output, constant preservation, crossing completeness and clean-hold convergence.
- Independent analysis verifies analytic crossing containment, interval arithmetic, attenuation and historical fixture control values.
- All **215 original Step 2N source/test/config/asset hashes remain unchanged**. No application/shared production source, model, setting or installed APK is modified. Only a standalone tool, this report and ignored aggregate evidence are added.
- Preserved Step 2N filtered GPU SHA-256 remains `6792b7c8776aa222e93985a32454d9f770b0823939824f90d93c9e8ccc014da9`; Step 2M refined GPU and Step 2K CPU controls are independently rehashed and unchanged. No ADB mutation occurs in this step.
- Focused mobile replay/controller tests with existing quality/lag/blank flags enabled: **11 passed, no skips**. Shared filter/foundation/scheduler tests: **5 passed**. New tool analysis: **no issues**. This is host verification, not renewed physical acceptance.

Evidence root: `apps/mobile/build/pose-quality/step2o/`. `comparison.json`, `repeat.json`, `verified-summary.json`, `verify.py`, `mobile-tests.log`, `shared-tests.log` and `analysis.log` preserve outputs, independent checks and hashes. The evidence root is ignored; no raw frames, user video or continuous device landmark stream is stored by this probe.

From the workspace root:

```powershell
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' --packages=.dart_tool/package_config.json apps/mobile/tool/pose_filter_tradeoff_probe.dart
& 'C:/Users/Ngzhe/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' apps/mobile/build/pose-quality/step2o/verify.py
```

## Physical decision gate

The next experiment should preserve the beta .3 filtered GPU APK as the control and create a separately hashed beta 1.2 diagnostic/profile candidate. Keep minCutoff, derivative cutoff, GPU backend, models/tensors, confidence thresholds, ROI cadence, residual CPU threads, resolution, preview projection, freshness/watchdog, backpressure, preprocessing and normal filtered rendering unchanged. Do not compare refined green against filtered green as if they were the same stage.

Repeat fresh warmed still, slow, fast, top and bottom phases with the same arm/framing/light. Use matched close-screen recordings containing C (displayed camera), R (yellow refined) and F (green filtered/magenta); retain actual PTS and uncertain/censored crossings. Track reason-coded blanks, accepted-joint/link interruptions, held shaking, settling and callback/paint ages separately. Watch especially for larger high-confidence prediction excursions. The current Step 2N video-path question remains unresolved; no absence or new recording is assumed.

Adopt only if motion response is visibly/measurably improved without materially worse held stability or tracking reliability. Otherwise restore beta .3. Do not stack another tuning change. Synthetic improvements cannot resolve upstream C→R, physical-person latency, side-on anatomical accuracy, sustained thermal behavior or full lifecycle acceptance. Step 3 remains deferred.
