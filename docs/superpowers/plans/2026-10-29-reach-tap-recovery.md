# Reach & Tap hands-free tracking recovery

Owner reports a brief hand loss forces a phone walk/touch Resume, interrupting play. Confirmed source cause: a missing required hand or 200ms freshness gap calls `_lose`, and `update` then refuses all trackingLost frames until explicit Resume. Keep existing confidence/freshness admission; do not solve this by scoring stale hands.

Implement locally and prepare a signed APK; the completed prior installation approval does not authorize this new APK installation. Preserve unrelated work, Move & Catch, target size/distribution, history and reward holds.

## Behavior

- Brief ordinary tracking dropout enters new `ReachTapPhase.recovering`. Immediately freeze active time/score and clear cursors/dwell. Retain the same calibrated target and body baseline. Camera stays active.
- Allow a 3-second recovery window measured from the original loss boundary, never extended by repeated missing samples. Fresh valid observations from both hands/body, matching geometry and stable calibrated torso, must be continuous for 400ms before automatic return to playing. Do not require hands to return to the original calibration pose; do not score recovery samples or carry old hit dwell. Retain accumulated hits/time/target. Missing/stale frames reset the return hold.
- A loss longer than 3 seconds or changed body/geometry requires full fresh alignment, Ready and countdown automatically, preserving accumulated score/active time. No compulsory screen tap for ordinary tracking reacquisition. trackingLost is a waiting-for-body state that accepts fresh valid data and transitions to calibration automatically.
- Manual Pause, background, session/account loss, camera errors and unavailable/reopening hardware must not auto-resume. Keep explicit Resume/retry and existing lifecycle guards. No timer-only reacquisition, unobserved time, hidden-hand cursor or inferred hit.
- UI shows `Tracking interrupted · score and timer paused` plus `Show both hands to continue automatically`. During recovery, render retained target dimly and only fresh returning cursors. For prolonged loss show hands-free alignment guidance. Resume remains available for intentional/manual pause or camera error. Preserve +10 effect keys and compact/large-text layout.

## Work

- [x] Test-first engine state/timing changes with 1-second dropout, same-target recovery, hold interruption, recovery timeout, hard geometry/body reacquisition, duplicate/future/stale input, no score/time/carryover dwell, manual/background/finished isolation and target generation preservation.
- [x] Test-first controller and UI integration: no touch needed after brief hand loss; keep explicit manual/background/camera-error restart; clear feedback; responsive status/painter behavior; update old tests whose explicit tracking-loss Resume assumption is intentionally replaced.
- [x] Focused/full affected game regressions, strict analysis, architecture, scoped independent review and signed Android candidate. Update six operational references, PROGRESS_REPORT and manual. Physical dropout/reacquisition/latency/thermal retest remains pending; no install/cloud/content/reward mutation.

Engine API additions: enum `recovering`; read-only `recoveryProgress` 0..1 for the observed 400ms return hold. Existing getters/methods retained. The pure engine `unavailable` is ordinary pose absence; hardware error/manual/background isolation stays in the controller. Implementation must preserve actual target/reach/cursor constants and scoring code.

Local verification complete:213 affected tests pass/five existing skips, strict analysis/architecture, review and signed APK. Root/source tests reproduce the Resume latch; delivery-latency watermark starvation and recovery-overlay hit-effect identity regressions are corrected. No install/cloud/reward mutation performed. Physical acceptance pending.

29 October: owner approved the exact recovery APK and explicitly requested no repeated APK installation approval. Installed/launched in place on Xiaomi7c4cbff with hash/signer/app identity/data preservation and previous APK retention verified. AGENTS.md now records standing authority for routine verified in-place GainPath updates on this same device; destructive actions and cloud/account/reward boundaries remain unchanged. Evidence: build/reach-tap-recovery-20261029/release-verification.json. Physical retest pending.
