# Real squat delay diagnosis — 13 October 2026

The phone tester reports visibly delayed tracking and saved results remaining
after restart. Voice coaching works after unmuting the workout speaker control.
No audio defect was established. Rep-count accuracy remains unmeasured because
performed versus counted totals have not yet been supplied.

## Audit and implemented observation

Read-only review found one active inference plus the latest pending frame, a
direct viewport repaint listener, and no duplicate filtering of the analyzer's
refined input. Historical filter-response recordings suggest smoothing merits a
matched experiment; they do not establish the current phone's delay.

A separate bounded scalar observer now measures accepted input-to-delivery,
input-to-first-drawable-CPU-paint, and squat analyzer runtime. It reports existing
native/worker means and scheduler counters every five seconds while tracking.
It is enabled only by non-release `GAINPATH_SQUAT_PERFORMANCE=true`. Normal
builds retain their existing behavior and settings. CPU uses two interpreter
threads; default filtering, scoring and server acceptance policy are unchanged.

The observer stores no images, joints, ROI coordinates, identities or session
identifiers. Reports use an explicit scalar allowlist, and do not enable the old
coordinate-bearing quality diagnostics. State is bounded to 300 recent timing
samples per stage and 300 delivery/paint markers. Pause, background, error and
close stop active-time accumulation; route disposal cancels the report timer.

## How to interpret the report

- The input stamp is taken **after camera plane copying**. Sensor exposure,
  camera preview age and display presentation are not measured.
- Delivery ends after the refined callback and synchronous squat analysis.
- First paint means a CPU painter issued at least one drawable base primitive
  intersecting the visible crop. It does not mean the display presented that
  frame. Repainting the same frame contributes only one sample.
- Per-stage means cover all accepted samples in the observer's lifetime;
  percentiles cover only the bounded retained samples. Their populations differ
  after 300 observations. Each report includes both counts.
- Observations older than 250 ms are excluded from accepted delivery/paint
  percentiles and counted as stale. Always read these counts alongside timings.
- Delivered FPS divides accepted deliveries by active tracking time, excluding
  pause/background time. It can include no-person frames. Generic frame-expiry
  counts are not a claim that a previously visible skeleton disappeared.
- Detector means/counters describe the detector's processed-frame population;
  they are not necessarily the same population as accepted painted frames.
- These timestamps cannot measure smoothing's signal delay. That needs matched
  refined-versus-filtered movement or physical recording evidence.

## Verification and phone build

All 253 mobile tests passed, with 15 optional checks skipped. Source analysis is
clean. Focused tests cover finite scalar allowlisting, bounded retention,
pause/stale handling, injected analyzer timing, visible-crop exclusion and
single sampling across repeated paints. Independent review found an initial
paint-counter dependency on an old quality flag; it was fixed and reviewed again
before the final APK was built. Final review found no remaining blocker.

Build command (from apps/mobile):

```text
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true
```

Preserved artifact:
`apps/mobile/build/step7-performance/gainpath-firebase-cpu-performance.apk`

SHA256: `3051B590B5CA59E47C59548B4DC67ED24A16A6A3C1DF17DE5365A8C45CC8242B`.

Installed successfully with `adb install -r` on the connected Xiaomi 23013RK75C
(Android API 33), after the user confirmed the previous session ended. GainPath
launched and a running process was verified. No app data was cleared.

## CPU phone observation

The user subsequently reported "only 3" and that the skeleton cannot follow
their true body speed. Actual versus app totals are still ambiguous. Collected
26 valid scalar reports from the running app, preserved locally in the ignored
`apps/mobile/build/step7-performance/cpu-metrics.jsonl`. The last report covers
129.263525 seconds of active tracking, including unlabelled setup/movement time.

| Metric | Last cumulative report |
| --- | --- |
| Accepted deliveries | 1,618; 12.517 FPS |
| Native inference mean | 56.207 ms |
| Worker pipeline mean | 77.904 ms |
| Input to delivery | 95.620 ms mean; 95.523 ms recent p50; 149.701 ms recent p95 |
| Input to first drawable CPU paint | 124.065 ms mean; 119.070 ms recent p50; 174.721 ms recent p95 |
| Squat analysis | 0.043985 ms mean; 0.111 ms recent p95 |
| Camera input / processed / replaced frames | 3,863 / 1,618 / 2,243 |
| Accepted drawable first paints | 821 |
| Stale observations / detector stale frames | 0 / 0 |
| Generic frame expiries | 37 |

The latest-frame replacement count is expected backpressure, not a growing
queue. Fewer drawable paints than deliveries can include no-person/confidence or
crop rejection; this unlabelled run cannot isolate those causes or count visible
tracking losses. Percentiles above use the latest 300 samples per stage.

Inference and worker time dominate analyzer time. The next isolated experiment
uses the existing experimental GPU backend with all other settings unchanged.
Smoothing's signal delay remains a separate hypothesis, supported by historical
observations but not measured by these timestamps. This baseline does **not**
prove 124 ms physical camera-to-screen latency or quantify accuracy. The visible
delay is not yet fixed. Server workout tuples remain disabled pending physical
acceptance.

## GPU comparison prepared and installed

The existing GPU path is gated by non-release `GAINPATH_POSE_GPU=true` and is
already honored by the real route. Independent read-only review found no
integration blocker; with GPU_COMPARE and quality/render/joint/blank diagnostics
disabled it creates no CPU shadow interpreter or coordinate diagnostic summary.
Native execution requires OpenCL and an unchanged owner thread; failure surfaces
rather than silently claiming a GPU result from a CPU fallback.

Built the same Firebase development/profile configuration with only the GPU
backend define added. No application algorithm/source settings changed. All
253 mobile tests passed with the candidate flags, with 15 optional skips.
Android profile build succeeded.

```text
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true
```

Candidate: `apps/mobile/build/step7-performance/gainpath-firebase-gpu-performance.apk`.
SHA256: `ABFB93D5343037C3DAD7402E947FEAB5C87B097AC0D236D741403F43D188C857`.

After the user explicitly confirmed the CPU session ended and authorized this
install, `adb install -r`, app launch and process existence succeeded. No data
was cleared. The CPU APK above remains available for rollback. A matched repeat
was requested. Installation is not proof that native GPU startup or faster
tracking succeeded in a current session; runtime reports, movement feedback and
actual-versus-app counts were pending at installation. Do not enable production
GPU or server acceptance from this diagnostic build.

## GPU run observed

The user reports "still some lagging but i think better than CPU". Sixteen scalar
reports confirm `opencl_required`. The final report spans 76.906669 active seconds:

| Metric | GPU final report | CPU final report |
| --- | --- | --- |
| Accepted delivery FPS | 22.001 | 12.517 |
| Native inference mean (ms) | 11.815 | 56.207 |
| Worker mean (ms) | 42.892 | 77.904 |
| Input to delivery mean (ms) | 59.610 | 95.620 |
| Input to first drawable CPU paint mean (ms) | 76.126 | 124.065 |
| Recent first-paint p95 (ms) | 116.288 | 174.721 |
| Analyzer mean (ms) | 0.093060 | 0.043985 |
| Deliveries / first drawable paints | 1,692 / 1,281 | 1,618 / 821 |
| Received / replaced inputs | 2,299 / 605 | 3,863 / 2,243 |
| Stale observations / generic expiries | 0 / 0 | 0 / 37 |

Evidence: local ignored `apps/mobile/build/step7-performance/gpu-metrics.jsonl`.
These are different-duration, unlabelled movement cohorts. The lower computation
and accepted-paint times, together with the user's impression, support GPU as
an improved diagnostic candidate. They do not establish a matched physical
speedup, full-body accuracy, heat/battery acceptance or graceful lifecycle checks
in this run. Rep-count totals remain unanswered.

Historical beta 1.2 trial's final disposition found no demonstrated meaningful
motion benefit; it was rolled back. Do not repeat that parameter change as a
presumed fix. The next isolated diagnostic should draw the same fresh refined
inference directly, with smoothing still running in shadow, to expose how much
of the residual visible lag depends on preview smoothing. It must keep scalar
telemetry only and default/release drawing unchanged. Physical comparison remains
required before adopting a responsive display policy.

## Direct preview diagnostic implemented

Added `GAINPATH_SQUAT_REFINED_PREVIEW` as a separate non-release diagnostic that
also requires scalar performance mode and an injected observer. It selects the
fresh refined result as the preview frame while continuing to update the filter
in shadow. The original refined callback into analysis is unchanged. Existing
ownership, timestamp freshness, projection, confidence and frame-clearing paths
apply to this selected frame. It retains no additional coordinate history.
The UI labels it "Direct skeleton test (may shake)". Reports include a scalar
`previewSource` enum from the controller, restricted to refined/filtered/unknown.

This is a drawing-source ablation, not a deployed production latency fix. It
tests whether removing the preview filter materially improves the user's
remaining visible lag, and may expose prediction jitter. No beta or scoring
change is adopted. Default and release builds remain filtered.

A red regression observed the expected direct y=.1 versus existing filtered
y=.445013. Tests verify source selection, observer isolation, unchanged analysis
callback confidence/timestamps and pause clearing. Review identified a mixed
legacy-diagnostic mode that would mislabel direct coordinates as filtered. A
second failing test reproduced this. Direct mode now declines when legacy
quality/joint-lag/render/blank build flags or an enabled quality object are
present; a re-review found no remaining blocker. Complete default and candidate
suites each passed 256 tests with 15 optional skips; source analysis is clean.
Physical direct-display response, stability and actual count accuracy remain
pending.

Direct candidate build succeeded with the previous GPU timing flags plus
`--dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true`. Artifact:
`apps/mobile/build/step7-performance/gainpath-firebase-gpu-direct-preview.apk`.
SHA256: `E336B36F77291C9A12B2E6DDE38CA3BFEC702864396B386E9EFEB3C54C970A13`.
After the user confirmed the GPU session ended and was saved/discarded,
`adb install -r`, launch and running process verification succeeded. No app data
was cleared; CPU and filtered GPU artifacts are preserved. User was asked to
repeat movement and a brief still hold. Direct-source runtime, physical response,
shaking and count totals remain pending at installation.

## Direct run and effect on results

User reports the skeleton is now "very responsive" with "some shakes", and asks
whether shaking affects results. This is qualitative feedback; no jitter
amplitude or exact physical response delay was measured. Collected 55 scalar
reports with no counter reset, all `opencl_required` and `previewSource: refined`.
The final report covers 272.203297 active seconds, including unlabelled time:

| Metric | Direct GPU report |
| --- | --- |
| Accepted deliveries / FPS | 5,755 / 21.142 |
| Native / worker means | 11.721 / 44.699 ms |
| Input to delivery mean | 61.457 ms |
| Input to first drawable CPU paint | 78.894 ms mean; 117.650 ms recent p95 |
| First drawable paints | 4,106 |
| Observer stale / upstream stale frames / generic expiries | 0 / 2 / 1 |

Evidence: ignored `apps/mobile/build/step7-performance/gpu-direct-metrics.jsonl`.
Computation times are similar to the prior filtered GPU cohort. Together with
the reported responsiveness improvement, this supports preview smoothing as a
substantial contributor to the earlier visible lag. It is not a controlled
physical latency estimate or a quantitative jitter comparison.

Code audit confirms `onRefined` still sends the same unsmoothed refined inference
into `SquatProcessingController.consumeRefined` in both preview modes.
`SquatAnalyzer` applies its own independent `PoseFrameFilter` before computing
knee angle and trunk lean. Removing preview filtering did not remove analysis
filtering or modify scoring. Only the evaluated side's shoulder, hip, knee and
ankle enter current squat geometry; wrist/face shaking is not directly scored.

Existing protections require valid geometry and confidence >=0.7, stable upright
calibration for 500 ms within a 6-degree range, depth/ascent confirmation over
150 ms, a cycle of at least 600 ms and return to standing, and trunk deviation
lasting 300 ms before recording it. Gaps/loss/pause can invalidate progress.
Fresh verification: all 29 analyzer tests passed, including standing jitter,
full/partial cycles, reversals, tracking gaps and per-attempt score aggregation.
Independent read-only review confirmed the separate analysis path and limits.

Visible shaking alone does not establish a result error. Sustained or confidently
wrong essential-joint predictions can still affect depth, standing recognition
or trunk penalties. The existing synthetic standing-jitter test uses
174 +/- 3 degrees, comfortably above the 160-degree ready threshold; it does
not establish noise robustness at the 160/90/45-degree rule boundaries or real
person accuracy. No rule/filter adjustment follows this observation.

Requested next check: start a fresh side-on guided session, calibrate and stand
still for 15 seconds (zero full and
partial counts), perform five intended full squats, then stand still again
(counts stop changing). Actual-versus-app totals and false counts remain pending.
This candidate is not yet approved for production/reward acceptance.

User asked whether to face the camera or use a side view. Clarified side-on,
approximately 90 degrees, keeping shoulder/hip/knee/ankle/feet visible and the
phone upright/fixed. No new count results have been supplied yet.
