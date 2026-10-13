# Matched real squat GPU comparison

User reports the skeleton cannot follow body speed in the CPU timing build.
Collected 26 scalar reports: final active time 129.264 s, 12.517 accepted
deliveries/s, native mean 56.207 ms, worker mean 77.904 ms, first drawable CPU
paint mean 124.065 ms. Analyzer mean 0.043985 ms is negligible by comparison.
This cohort is not a labelled movement window or a physical display-latency
measurement. The user's "only 3" does not yet distinguish actual and app counts.

Hypothesis: GPU execution will reduce the measured computation/delivery component.
It may leave visible smoothing lag; do not change both variables at once.
Use the already implemented non-release `GAINPATH_POSE_GPU=true` backend in a
separate Firebase development/profile APK with scalar performance observation.
Do not change source algorithms, beta, model, camera, confidence, scoring,
freshness, upload or acceptance. Keep quality/render/joint/blank/refined debug
and GPU_COMPARE flags off. Preserve the CPU APK as rollback.

- [x] Collect CPU scalar baseline and audit existing GPU integration read-only.
- [x] Verify existing mobile tests under GPU/performance defines and build.
- [x] Preserve/hash candidate and install with -r after session-end confirmation.
- [x] Verify running app.
- [ ] Collect a comparable GPU person run when available.
- [x] Record actual evidence/remaining limits, commit and push.

User confirmed the current session ended and authorized GPU comparison install.
No production backend adoption or pose/rep accuracy acceptance follows this spike.

Exact candidate-flag mobile suite: 253 passed, 15 optional skips. Independent
read-only review found no integration blocker. Native lifecycle/adapter, real
session and scalar painter tests are included. No new source change is required.

Profile APK build succeeded. Candidate SHA256:
ABFB93D5343037C3DAD7402E947FEAB5C87B097AC0D236D741403F43D188C857.
Preserved at apps/mobile/build/step7-performance/gainpath-firebase-gpu-performance.apk.
adb install -r and launch succeeded; process existence verified. User was asked
to repeat matched framing/movement. Native GPU startup, current runtime timing,
physical response and count totals still require an active session.
