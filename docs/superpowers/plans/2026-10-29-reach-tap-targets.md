# Reach & Tap target size and distribution refinement

Owner requests larger, more widely distributed target points. Implement directly in the existing game engine. Local source/tests/build only; the earlier installation approval was completed and does not authorize this new APK installation.

Use a target radius up to 9% of the board shortest side (was6.5%), adapt to27% of calibrated reach for smaller bodies (was22%). Keep cursors, +10 score,100ms raw/smoothed same-hand dwell,250ms cooldown, fresh tracking and interruption behavior. Expand conservative target reach to90% of observed setup limb lengths (was72%); require the entire target circle inside that reach and visible margins. Rotate spawning through six bounded reachable regions (two columns × three rows) with fallback when a region is unavailable. Keep current-hand/prior-target exclusion and bounded sampling. Never force a target outside measured reach to fill a region.

- [x] Add red tests for visibly larger/adaptive targets and sustained six-region distribution inside visible calibrated bounds across portrait/landscape/square boards.
- [x] Implement size/reach constants and bounded region rotation with safe fallback. Update the existing target-bound expectations for the intentionally expanded limit.
- [x] Run focused/regression tests, strict analysis, architecture, scoped independent review and signed Android build. Preserve installed APK and prior artifacts. Update operational references and manual. Physical comfort/mapping/latency remain pending; no cloud/reward or device mutation.

Local verification complete:184 affected passes/five existing skips, strict analysis/architecture, review and signed APK. Cursor-sizing review finding corrected with observed red/green. No install or cloud mutation; physical comfort/mapping acceptance pending.

29 October: owner approved the exact new APK installation. Installed/launched in place on Xiaomi7c4cbff with hash/signer/app identity/data preservation and previous APK retention verified. No cloud/Admin/content/reward mutation. Release evidence: build/reach-tap-targets-20261029/release-verification.json. Physical comfort/mapping/latency/thermal retest pending; completed approval grants no additional authority.
