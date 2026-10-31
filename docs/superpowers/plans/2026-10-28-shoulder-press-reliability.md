# Shoulder Press reliability correction

Owner requests analysis of the 11:53 recording, comparison with squat, and a more reliable local fix. Prior installation authority is completed; no new cloud/content/device mutation is assumed.

## Evidence and pipeline comparison

Both trackers use AndroidPoseCamera → bounded latest-frame processing → BlazePose ROI decode → fresh onRefined callback → exercise analyzer → authored GuidedWorkoutProgress → shared measured view/history. Preview filtering is separate and must not feed analysis a second time. Squat stays frozen.

The recording now shows successful calibration/Ready/Press prompts followed by repeated resets and zero reps. The previous size correction is not sufficient. Shoulder press additionally compares projected upper/forearm lengths, shoulder span and shoulder center against a bottom-pose baseline on every frame; those image projections vary naturally as the arms rise. Every rejected frame discards the entire calibration. Squat has bounded tracking-recovery/discontinuity handling, angle filtering and reason diagnostics. Screen overlays are observations, not raw confidence/time evidence: do not claim a particular gate caused every recorded reset.

## Local design

- Keep fresh capture timestamps, 250ms stale/gap guard, .65 required-joint confidence, bilateral raw/filtered overhead/return dwell, null score and exact identity unchanged.
- Distinguish stable camera/torso evidence (hip position, lateral body position, torso scale) from moving arm projection. Bottom calibration remains strict; movement does not require constant projected arm length or shoulder span. Current-frame plausibility/front/upright geometry remains required.
- For brief unavailable frames, immediately discard an unfinished cycle and reset angle filters; retain only calibration for <=500ms and require a fresh sustained bottom position before arming another cycle. Never bridge a hidden peak/return. Prolonged loss, stale/gap, geometry/model identity change, large body displacement and pause fully recalibrate.
- Add bounded scalar rejection/phase diagnostics (no coordinates or camera images), usable in tests and optional local debugging. Expose useful recovery cues instead of unexplained resets.
- Test dynamic arm foreshortening, shoulder elevation, body jitter, short confidence dips, repeat failures, long loss, unilateral/alternating/curl/lateral-raise negatives, identity/time guards and real session watchdog delivery. Reproduce failures before production edits.

## Tasks

1. Add representative trajectory tests and replay measured-looking projected variation; establish old failure. Add optional diagnostics only as necessary to identify gates.
2. Correct press-only geometry stability and bounded recovery. Keep no-reconstruction/no-fabrication guards and old tracker sources unchanged.
3. Compare session lifecycle/watchdog paths to squat; add focused session regression for raw-frame delivery with timer interleaving, recovery and authored set completion.
4. Run pose/Mobile regressions, changed-code analysis, architecture, benchmark and APK build; independent review. Preserve initial logs/private frames under build/shoulder-press-reliability-20261028/.
5. Update operational references/progress/manual with exact limitations and prepared release scope. No cloud/Admin/content change; device install requires new owner authorization.

## Local completion

353 passing regressions/five existing skips, clean analysis/architecture, independent review and APK build. Reviewer P2 (watchdog tracked-time inflation during retained calibration) was reproduced and fixed, including the first recovered interval. Approximate overlay geometry demonstrates old span rejection but does not recover raw model evidence. Scalar diagnostics are bounded and coordinate-free. No new installation/cloud/content mutation. Evidence: build/shoulder-press-reliability-20261028/verification.json.

## Approved device release

Owner explicitly approved the exact prepared APK installation. Installed/launched in place on Xiaomi7c4cbff; installed hash/signer and UID/data directory/first-install identity preserved, previous APK retained. No cloud/Admin/content change. Physical retest remains pending. Evidence: build/shoulder-press-reliability-20261028/release-verification.json. Completed approval grants no further authority.
