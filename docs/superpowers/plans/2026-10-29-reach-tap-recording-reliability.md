# Reach & Tap recording reliability correction

Owner reports frequent missed detection/interruptions in private 23.69s screen recording Screenrecorder-2026-10-29-11-30-20-494.mp4. Private sampled screen geometry shows scoring50→100, remaining33→25, then play→alignment near17.25s while body stays visible and arms reach across/return. Screen video lacks native landmark confidence/capture timing; do not claim raw replay or an exact rejected joint.

Confirmed architectural failure modes: camera adapter returns null for any missing required shoulder/elbow/wrist/hip, although active collisions consume only the observed hand and torso; engine also requires both elbows/wrists and rejects individual shoulder movement >.09 board-shortside, conflating reaching/shoulder projection with body displacement. Test these contracts before fixing. Keep full real eight-joint setup calibration and existing strict .65 confidence; do not fabricate obscured hands or lower thresholds globally.

## Design and scope

- Camera adapter retains four real confident torso anchors and independently observed left/right wrist/elbow points. A null hand stays null; a missing elbow must not remove a visible wrist. Full setup calibration still requires all eight observed joints. Active/recovering admission requires both shoulders/hips and at least one observed hand; missing-hand cursor is hidden, its smoothing/dwell cleared and it cannot score. An opposite visible hand can continue with fresh evidence. Losing both hands or body still freezes score/time and uses existing hands-free recovery.
- Use calibrated hip center translation, torso orientation/scale and bounded shoulder-span/center evidence for active torso stability, separate from individual shoulder excursion. Permit ordinary shoulder elevation/projection/asymmetry during reaching. Reject significant camera/body translation, collapsed side view, excessive scale/lean; calibration retains its stable all-joint hold. Do not adapt the baseline continuously to drift or invent missing anchors. Preserve calibrated target/reach regions and all raw/smoothed hit confirmation/cooldowns.
- Add bounded scalar rejection/availability feedback (no frames/pose history or uploads) if needed to make remaining interruptions explainable. Display single-hand availability and specific alignment/recovery cues rather than generic missing-everything messages. Keep compact2xtext overlay and manual/background/hardware/account guards.
- Keep latest installed larger targets, automatic 3s/400ms recovery, score/history, Move & Catch and reward holds unchanged except admission/stability needed above. No model replacement or workload increase. Pure geometry O(1), no extra inference.
- Run focused TDD cases including recorded-style cross-body/shoulder motion, independent missing elbow/wrist, no hidden-hand hits, both-hands loss, per-hand dwell/smoothing isolation, hardware/manual/account bounds, continuous varied-aspect play and raw→adapter→controller integration. Run affected suite, strict analysis, architecture, independent review, signed build. Install in place under standing owner authorization on Xiaomi7c4cbff, preserving data/signer/previous APK and avoiding active unsaved play. No cloud/Admin/content/reward mutation.

## Ownership/interfaces

Engine implementer owns reach_tap.dart plus new reach_tap_recording_test.dart and necessary existing engine/recovery test expectation updates. No new sample fields required; left/rightHand/Elbow are already nullable. Preserve full calibration all8. Root owns adapter reachTapSample admission (return partial sample if all torso anchors valid), controller/view/painter and integration tests. Engine should expose hasLeftHand/hasRightHand getters only if useful; nullable hand getters are sufficient. Specific feedback must remain bounded and unscored.

- [x] Reproduce camera all-or-nothing sample and engine active elbow/both-hand/shoulder failures.
- [x] Implement independent actual-hand admission and reach-compatible torso gates, focused regressions.
- [x] Integrate adapter/UI and verify raw observations through controller; no extrapolated hand or stale score.
- [x] Full affected tests, strict analysis, architecture, scoped review, signed APK/hash/signature, standing-authorized in-place installation and documentation/evidence. Physical mapping/count/occlusion/latency/thermal retest remains pending.


Completed 29 October: 257 affected tests (44 new; five existing skips), strict analysis, architecture, independent review and signed Android build passed. Sealed APK installed/launched in place under standing authorization; installed hash/signer, app identity/data and previous APK verified. See `build/reach-tap-recording-20261029/release-verification.json`. No cloud/Admin/content/account/reward mutation. Exact recorded native rejection and physical acceptance remain unproven; phone retest pending.
