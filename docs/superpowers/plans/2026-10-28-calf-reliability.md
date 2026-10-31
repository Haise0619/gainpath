# Standing calf raise reliability correction

Owner request: fix the held standing calf raise exercise. Implement and verify locally, then prepare exact client candidates for review. No new cloud/content mutation or phone installation is authorized by this request.

## Existing evidence and decisions

The 25 October private recording/evidence shows side-on feet and skeleton but repeated neutral-hold resets. Earlier median-window repairs passed synthetic checks but did not establish physical reliability; Mobile subsequently held this tracker. Reuse existing camera/latest-frame/fresh-pose pipeline and exact gainpath/standing-calf-raise-side-v1 registry. Preserve old records/scoring format, Routine targets/rest, measured/manual separation and all acceptance/reward holds. Do not alter squat/curl/row/press/wall analyzers.

Current issues to reproduce: fixed10%-height shin cutoff, foot noise exceeding narrow calibration/6%-shin toe-anchor gates, unsmoothed heel/ankle motion, immediate full reset on one weak measured frame, no sustained bottom return, timestamp/model discontinuities and tracked-time watchdog accounting. A visible overlay does not establish raw landmark confidence. New tests must distinguish meaningful heel/ankle movement from independent foot jitter, jumping/toe translation and knee bending.

## Implementation

1. Tests first: different body sizes/aspects/rates and visible sides; independent foot jitter vs correlated heel/ankle motion; one weak sample vs sustained loss; full, partial, spike, bent knee, stepping/jumping/camera translation; stale/reordered/model/geometry/pause interruptions; correct tracked/rejected time.
2. Geometry: pixel-resolution guard rather than10% framing assumption; retain .7 required-joint confidence and meaningful heel/toe side profile. Median calibration remains bounded; permit independent foot jitter without calibrating through sustained correlated heel/ankle movement.
3. Analyzer: adaptive scalar filtering with fresh raw+filtered agreement for start/peak/return, sustained start/return, bounded toe-anchor jitter tolerance, immediate discard of interrupted cycle and short retained setup with observed heels-down rearm; hard loss/gaps/movement/identity changes fully recalibrate. No targets in analyzer. Existing provisional form scoring and legacy history shape remain unchanged.
4. Session/setup: coalesced notifications; visible foot-focused setup before camera, authored targets/rest and strict fresh neutral recalibration. Correct session diagnostics/feedback and lifecycle/account guards. Test save retry and target completion through real session pipeline.
5. Independent review, pose/Mobile/domain/Admin focused regressions, analysis/architecture, synthetic benchmark and both local builds. Only after review enable the corrected local Member candidate and align Admin availability labels. This is preparation for physical validation, not accepted physical accuracy.
6. Update operational references, PROGRESS_REPORT and existing manual with evidence/limits. Retain prior source/APK/evidence. A separately approved exact APK/private Admin activation is the next release action; no seeding/Program overwrite/rewards or cloud backend change.

References: ACE exercise-library heel raise technique and MediaPipe landmark visibility documentation; engineering thresholds remain provisional until phone trials.

## Separately approved client release

Owner approved exact APK installation and private Admin activation after the completed local report. Both are active; installed/served hashes, signer, app UID/data directory/first-install identity and prior artifacts are verified. Physical/browser acceptance remains pending; no backend/content/Rules/reward change occurred. Evidence: build/calf-reliability-20261028/release-verification.json. Completed approval grants no further mutation authority.
