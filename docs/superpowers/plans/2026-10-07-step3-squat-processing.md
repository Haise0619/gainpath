# Step 3 squat processing implementation plan

**Authorization:** On 2026-10-07 the user requested that Step 3 begin in parallel with “Audit and implement real squat flow”. This explicitly supersedes earlier Step 2 reports deferring Step 3. It does not accept pose accuracy or authorize enabling workout uploads.

**Goal:** Implement the pure side-view squat processing and corrective audio boundary from Step 3 of `2026-10-02-real-pose-workout-handoff.md`, preserving the camera experiment and mock workout flow.

**Architecture:** The new `SquatAnalyzer` owns a separate filter, calibration, geometry, tracking arbitration, four phases and bounded session aggregates. It accepts refined `PoseFrame` values and monotonic delivery time. Mobile orchestration feeds updates/cues to a playback adapter. Existing prototype classes retain compatibility. A side view and an upright, stationary camera are explicit operating assumptions; inferred world depth and phone IMU are not treated as validated biomechanical measurements.

**Execution:** Main chat implements `packages/gainpath_pose/lib/src/squat/*`, exports, tests, this plan and the integration bridge. Referenced chat owns mobile audio files/tests, native audio registration and the existing cue arbiter. Both use the current shared checkout because required prior work is uncommitted; separate file ownership preserves it. No commit, deployment, APK replacement or production enablement in this step.

## Decisions and public contract

- `SquatAnalyzer.update(PoseFrame frame, {required int nowMicros}) -> SquatUpdate`; `tick`, `pause`, `resume`, and `reset` provide explicit lifecycle/no-frame handling. Update contains capture time, `TrackingStatus health`, `needsCalibration`, phase, selected side, geometry, completed/partial rep aggregates, valid/rejected microseconds, nullable score, and `List<CueRequest> cues`.
- Input is refined upright unmirrored image coordinates, not an already filtered preview frame. Geometry converts normalized XY to pixels before angles. A required declaration of side-view setup is documented at the integration boundary; this algorithm does not infer camera yaw or accept frontal valgus.
- Pick one side using the minimum confidence of shoulder/hip/knee/ankle during initial calibration; lock it until recalibration. Require finite in-frame points and per-joint visibility/presence >= .70. Missing essential joints freeze transitions immediately; sustained 500 ms loss, >250 ms input gaps, geometry/model changes and pause/resume discard the incomplete cycle and require calibration. Stale/future input never creates a rep. No predictions across loss.
- Provisional thresholds: standing 160 degrees, depth 90 degrees, angular velocity 15 degrees/second, 500 ms standing calibration within a 6 degree range, 150 ms bottom/reversal dwell, 600 ms minimum cycle, 10 s maximum cycle, trunk deviation over 45 degrees sustained 300 ms. These are testable versioned engineering starting values, not validated coaching criteria.
- Four phases: ready -> eccentric -> inflection -> concentric -> ready. Early reversal can enter concentric with depth unmet; return to standing records a partial attempt rather than a valid rep. A complete descending/ascending cycle is required. Pausing/loss cannot manufacture a completion. Calibration starts only while standing; a user starting at the bottom must first stand.
- Confidence remains separate from form quality. Score only completed assessable attempts, once per attempt; aggregate duration-independent trunk/depth penalties, never per-frame penalties. No assessed attempt means null score. No frontal knee-valgus or IMU confirmation. Session statistics retain bounded aggregate values, not landmark trajectories.
- Audio cues are coaching information, not emergency or injury diagnoses. `CueRequest` remains id/text/priority; time is supplied separately by orchestration. Audio must stop on pause, lost/degraded tracking, disabled voice and close; recovery starts without stale corrections.

## Tasks and verification

- [x] Write failing pure tests for aspect-correct geometry, calibration, complete/partial cycles, critical-joint rejection, duration accounting, stale/gapped inputs, pause/recovery, finite inputs and bounded scoring.
- [x] Implement geometry/rules/models/analyzer and pass the full pure pose suite; analyze the package.
- [x] Referenced chat implements audio adapter and lifecycle/priority tests; read its `docs/architecture/2026-10-07-step3-audio-handoff.md` and verify evidence.
- [x] Add a small mobile Step 3 integration controller feeding refined frames into the analyzer and routing cues to audio. No existing preview/routing/persistence behavior changes.
- [x] Run affected mobile tests and analysis, full mobile suite, and pure pose tests. Review cross-boundary lifecycle and stale-frame behavior independently.
- [x] Document implemented behavior, provisional thresholds, source ownership, test results and remaining recorded-fixture/device validation.

## Review focus

1. Partial descent and reversal must not be counted as a full rep.
2. Occlusion, clock gaps, pause and stale frames cannot bridge unrelated half-reps.
3. Wide/tall image aspects, mirrored presentation and degenerate segments cannot distort angle arithmetic or create finite-looking defaults.
4. Tracking confidence cannot become a posture score; lost/calibration/paused intervals cannot inflate valid time.
5. Disabling voice or closing during asynchronous playback must suppress stale queued work.

## Progress

- Inspected latest referenced chat and current source. Other chat dispatched for audio with separate ownership.
- Ruling: use side-view 2D geometry in common pixel units for this provisional rule; 3D world-kinematics acceptance is separate. This avoids assuming unvalidated depth accuracy. Upright/stationary camera remains a documented setup requirement.
- Ruling: start implementation under the user's explicit Step 3 execution instruction and existing handoff rather than asking for another approval of the same stage.
- Resumed 2026-10-08 after a usage-limit interruption. The referenced chat is actively finishing audio in parallel under renewed user authorization.
- Independent review defects fixed with red/green regressions: tracking timeout on recovery, usable-side selection, watchdog timer resurrection during a close listener, and missing foreground-return notification.
- Synthetic fixtures include irregular-cadence standing jitter. Recorded-person fixture/physical acceptance remains outstanding; see `docs/architecture/2026-10-08-step3-squat-processing.md`.
- Final coordinated Dart verification: 46 pure pose tests; 190 mobile tests with 15 feature-flag skips; clean pure package and mobile `lib test` static analysis. Saved experiment copies under mobile `build/` prevent a clean unrestricted directory scan.
