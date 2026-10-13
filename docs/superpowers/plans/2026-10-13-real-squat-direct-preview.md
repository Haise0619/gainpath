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
- [ ] Collect physical comparison of responsiveness and still shaking/count totals.
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
