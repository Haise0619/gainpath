# Real squat direct preview diagnostic

CPU baseline was 12.517 deliveries/s and 124.065 ms input-to-CPU-paint mean.
Experimental GPU run reached 22.001/s and 76.126 ms. User says better than CPU,
but still lagging. Historical beta 1.2 trial found no clear benefit and rolled
back. Test smoothing as one drawing-source variable before changing parameters.

Use existing fresh refined PoseFrame directly as the preview's selected frame
only when both non-release GAINPATH_SQUAT_PERFORMANCE and
GAINPATH_SQUAT_REFINED_PREVIEW are enabled and a scalar observer is injected.
Keep the filter running in shadow, onRefined analysis callback unchanged,
freshness/confidence/projection/camera/model/GPU settings unchanged. Existing
frame clearing and latest-frame scheduling continue to own lifecycle. No extra
coordinate retention or old quality flags. Add an explicit visible test label
and scalar previewSource report enum; production/default remains filtered.

- [x] Red test moving-frame selection, unchanged refined callback and pause clearing;
  default and no-observer controllers retain smoothing even with the define.
- [x] Implement minimal gated source selection and honest label/report metadata.
- [x] Verify default and candidate mobile suites, source analysis, independent review.
- [x] Build/preserve/hash separate GPU direct-preview profile artifact.
- [x] Install after user confirmed session ended/saved/discarded.
- [x] Collect qualitative responsiveness/shaking feedback and scalar source/timings.
- [ ] Collect actual-versus-app count totals and physical no-count standing check.
- [x] Record evidence and commit/push. No production/accuracy acceptance claimed.

Red/green evidence: candidate expected direct wrist y=.1, existing filtered
value=.445013 failed. Minimal source selection passed. Review found mixed legacy
diagnostic flags could falsely label direct output as filtered and zero its
displacement ledger. Added a failing injected-quality regression, then disabled
direct mode for all legacy quality/joint/render/blank flags and enabled quality
objects. Re-review found no remaining blocker. Mixed-mode focused tests pass.
Both complete default and exact candidate suites: 256 passed, 15 optional skips.
Changed-source analysis: no issues. Physical direct-display benefit is pending.

Profile build succeeded. Artifact:
apps/mobile/build/step7-performance/gainpath-firebase-gpu-direct-preview.apk.
SHA256 E336B36F77291C9A12B2E6DDE38CA3BFEC702864396B386E9EFEB3C54C970A13.
adb install -r, launch and running process verified; app data not cleared.
User asked to repeat slow squats and a brief still hold, then report response,
shaking and actual-versus-app counts. Current-session source/timing evidence pending.

Latest observation supersedes pending runtime evidence: 55 scalar reports,
all opencl_required/refined, no counter reset; final 272.203297 active seconds,
21.142 deliveries/s, 78.894 ms input-to-first CPU paint mean, 117.650 ms recent p95.
User says very responsive with some shaking, and asks whether results are affected.
Read-only analyzer audit confirms independent smoothing and unchanged refined
analysis input. 29 analyzer tests passed freshly, including bounded standing
jitter, partial/full cycles, reversal/loss safeguards and scoring dwell.
This does not establish physical count/score accuracy or boundary-noise robustness.
Requested 15 s still (zero counts), five intended full squats, then still again
(no extra counts). No parameter, source or acceptance policy change adopted.

Provided recording VID_20261013_112006.mp4 shows six visible attempts, app 3 full
and 3 partial, ending estimated form 93%. Attempt total matches; depth labels and
score accuracy remain unvalidated. Brief standing samples show no extra attempt,
but no 15-second stationary check is present. Detailed video/algorithm/design
review: docs/architecture/2026-10-13-squat-video-and-algorithm-review.md.
