# Step 2E matched external recording protocol

Completed-recording scope update: the user supplied two close **screen-only** clips in the same sitting. Their observable boundary is **displayed camera preview → displayed skeleton (C→S)**. The [completed comparison](2026-10-05-pose-beta-screen-video-comparison.md) uses actual decoded PTS, preserves censoring and hashes, and concludes that beta 0.6 has not met its benefit gate. Beta 0.3 is restored; Step 3 remains deferred. The mirror protocol below is the historical preparation plan. No physical-person latency is inferred from the supplied clips, and no additional recording is required to complete this comparison.

The internal beta .6 comparison is promising but **not accepted**: one-arm motion displacement/excursion completeness improves, response-time bounds overlap, and physical stationary shaking remains unjudged. This recording checks physical response and held stability; no other variable is tuned.

## Prefer a fresh paired comparison

Record **two original clips in the same sitting**, beta .3 control followed by beta .6 candidate, using identical diagnostic UI/phone orientation/camera lens/framing/light/movement. This avoids attributing different dates or Step2C-vs-Step2E debug viewport changes to beta. Previous original Step2C beta .3 video remains contextual evidence, not silently replaced. Both preserved Step2D/Step2E APKs have the same diagnostic interface and differ only in the beta argument's compiled app code.

Control APK: `apps/mobile/build/pose-quality/step2d-joint-lag-logging-profile.apk`, SHA-256 `774345f7b0f7f778b7bef83043b31e1ad803c162306d4a4582b84abfba52bf5a`.

Candidate APK: `apps/mobile/build/pose-quality/step2e-beta06-diagnostic-profile.apk`, SHA-256 `dd75e4f406d48d7ada1714e059d0bfb1de3438f1145961e0dc2bf04b62e0b9b2`.

ADB will install each preserved profile APK, verify the device hash, force a fresh process/session, and collect its existing aggregate health telemetry. Keep Flutter/Android Studio Run stopped. Switching the preserved APKs changes beta only; no source/config/model/diagnostic edit or new build is needed. End each preview before the next installation. Do not overwrite the originals or splice the clips.

## Camera setup

Use the same mirror arrangement as before: actual moving upper body in the mirror and GainPath Xiaomi display visible **at the same time**, including camera-preview image and skeleton. Use the Xiaomi portrait front camera; keep head, hands and feet in view. Stabilize the recording camera independently (second person or fixed support), so the moving arm does not move the recording camera. Avoid changing distance/zoom/framing/exposure during or between clips. The phone display must be large/sharp enough to distinguish elbow/upper-arm links and magenta dots without hiding the mirror elbow.

Record original **60 FPS or higher** video. Nominal FPS is only capture setup; analysis uses decoded **presentation timestamps**, preserves variable spacing/rotation, hashes original files and records frame count/FPS/PTS range. No `frame/60` timing substitution, resampling or edited montage.

## Same movement sequence in each clip (~60–75 seconds)

1. Open Workout → Try live camera preview. Wait around10s until the full-body skeleton is present; finish any screen taps/repositioning before scored motion. Existing diagnostics stay unchanged; no capture-button interaction during the motion segment.
2. Start external recording with both mirror person and screen visible. Hold arms down and body mostly still for **10s**. This supplies visible stationary stability evidence, not just raw-to-filtered displacement.
3. Slowly raise/lower **one whole arm**, the same arm as the one-arm control, so elbow/upper arm clearly crosses approximately shoulder level; other arm stays down. Use **four cycles over about15s**, with brief top/bottom pauses. Keep hand inside preview.
4. Repeat that arm faster for **seven or eight cycles over about15s**, close to the internal ~2s cycle pace. Avoid extreme speed, torso twisting or moving closer to the phone.
5. Raise the arm and hold it above shoulder level for **10s**; then lower and hold still for **10s**. Keep both anatomical and display joints visible. These held segments expose shaking, drift, partial-link disappearance and settling.
6. Stop the original recording, save it unchanged, then tap End preview. Use separate descriptive filenames, e.g. `step2e_beta03_control_external_60fps.mp4` and `step2e_beta06_candidate_external_60fps.mp4`.

This reproduces the prior mirror P/C/S measurement method and adds stable held segments. The timing targets guide approximately matching movement, not ground-truth angular speed. Record obvious deviations, camera movement or visibility obstruction instead of hiding them.

## Analysis and decision

The repeated event definition remains **moving elbow/upper arm crossing approximately shoulder level relative to local shoulder/torso orientation**. P is actual movement in the mirror, C the corresponding displayed camera-preview movement, S the corresponding skeleton movement. Follow the same anatomical arm; do not infer anatomy from mirror left/right, substitute wrist height, or use absolute horizontal screen Y.

For each clearly observable raise/lower, bracket P/C/S separately on actual video PTS. Report P→C `[c0-p1,c1-p0]`, C→S `[s0-c1,s1-c0]`, P→S `[s0-p1,s1-p0]` directly. Preserve uncertainty from blur, mirror geometry, perspective, display scan/rolling shutter, stepped overlays and ambiguous crossings. Missing/indistinct arm links censor S; do not interpolate/average them as normal samples. Report whole-overlay blanks, partial-link disappearance, qualitative alignment, visible shaking during holds and moving-arm lag. No callback-to-paint or filter-response number is added to these video bounds.

Compare paired stationary/held stability and tracking as well as motion. If bounds still overlap substantially, retain that uncertainty rather than declare a physical speedup. Beta .6 passes only with meaningful motion benefit and no material degradation of held stability/tracking. Restore beta .3 if meaningful benefit is absent or instability worsens. No additional tuning pass is combined with this one, and Step3 remains deferred.
