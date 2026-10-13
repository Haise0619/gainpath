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

## Pending physical evidence

The user has been asked to run approximately 30 seconds of side-on slow squats
and report performed versus counted totals. No scalar timing reports were
available in the initial read or the subsequent bounded 40-second collection;
there is no confirmed active tracking cohort yet. The delay is **not yet fixed
or physically quantified**. The next tuning decision must follow this CPU
baseline; any GPU comparison should use a separate matched candidate build.
Server workout tuples remain disabled pending physical acceptance.
