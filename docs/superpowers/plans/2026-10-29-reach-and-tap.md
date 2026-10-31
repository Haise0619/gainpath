# Reach & Tap implementation plan

Owner explicitly requests direct implementation, focused tests, analysis and Android build. This task is local preparation; no deployment, APK installation, live content or reward activation is authorized. Reuse the current owner checkout and preserve unrelated dirty work and protected build evidence.

## Design

Separate supported game `reach-tap-v1`, local 40-second round, +10 Game Score per confirmed bilateral-hand target hit (either hand, once per target). Use the existing Android camera, BlazePose and PosePreviewController without altering Move & Catch or workout pose logic. Show a silhouette, stable body and both hands for approximately 2 seconds, Ready briefly, automatic 3-2-1 countdown, then one reachable circular target. Scores, effects, remaining active time, manual pause/resume, results, Replay and local history are account scoped. No screen tapping earns hits.

All observations are already upright BlazePose landmarks. Apply mirror once and a common centered BoxFit.cover transform to the camera and cursors; invalidate calibration when model/image/viewport geometry changes or preview/analysis fields of view disagree. Targets use conservative calibrated shoulder/limb reach intersected with the visible board and safe margins. Collision uses physical board aspect, both raw and time-smoothed hand agreement, fresh capture-time dwell and post-hit cooldown/new-target separation. No old frame or timer-only event awards a hit. Missing body or either hand, camera interruption, background, clock gaps and account change pause immediately; explicit Resume reacquires stable alignment before a fresh countdown. No hidden landmarks, pose history, cloud frames or score-to-reward conversion.

History stores only bounded completed-round aggregates, stable round IDs, date, hits/score and monotonic personal best under organization/member ownership. Retry is idempotent and account guarded. A separate disabled participation proposal records 20 points once per game per Malaysia day, shared cap 60, without allowing a new game to reach the existing active Move & Catch issuer.

## Tasks

- [x] Test-first pure game engine and projection mapping: fresh 2s alignment, Ready/3-2-1/40s active time, conservative reachable target generation, smooth hand cursors, raw+smoothed dwell, cooldown, scoring, immediate tracking pause, resume/replay/geometry boundaries.
- [x] Test-first account-scoped aggregate history and disabled reward preparation. Retain existing reward behavior and server supported-game allowlists. No calls or issuance for Reach & Tap.
- [x] Camera adapter, Member controller, responsive silhouette/live board and results, exit/pause/resume/retry/account/lifecycle guards, separate named route and supported challenge card. Reuse app design tokens and native CameraPreview. Keep Move & Catch implementation files unchanged.
- [x] Focused new and existing game regression tests; Flutter analysis, architecture and signed Android build. Independent review and fix material findings. Preserve exact APK and hashes, update six operational references, PROGRESS_REPORT and existing mini-game manual. Physical mapping/reach/latency/thermal acceptance remains pending.

## Integration contracts

Engine owns `features/gamification/domain/reach_tap.dart` and `reach_tap_projection.dart`, using dart:math Point<double>. `ReachTapSample` contains left/rightShoulder, left/rightElbow, left/rightHand, left/rightHip (normalized board positions), capturedAtMicros, boardWidth/boardHeight logical pixels, geometryKey. `ReachTapEngine` exposes update(ReachTapSample, {required int nowMicros}), tick(int now), unavailable(int now), pause(int now), resume(int now), restart(int now), phase (calibrating/ready/countdown/playing/paused/trackingLost/finished), hits, score, remainingSeconds, calibrationProgress, countdownSeconds, leftHand/rightHand (nullable smoothed Point), target(nullable Point), targetRadius/cursorRadius (fraction of board shortest side), hitSerial, trackingReady, activeMicros. Engine API may add read-only feedback.

Projection `ReachTapProjection` constructor imageWidth/imageHeight/viewportWidth/viewportHeight/mirrored, maps upright Point through `map(Point<double>)`; `compatible` reports valid dimensions. Sensor rotation helper/tests may be separate; real adapter must not rotate already upright landmarks again.

History contract `ReachTapRound` immutable id, completedAt(DateTime UTC), hits, score (hits*10), activeMicros=40000000; `ReachTapHistory` rounds immutable and bestScore; `ReachTapHistoryStore.load(SessionScope)` and record(SessionScope, ReachTapRound, {required bool Function() isCurrent}) → Future<ReachTapHistory>. Implementation infrastructure/local/reach_tap_history.dart. Ports and immutable DTOs features/gamification/domain/reach_tap_ports.dart. Root owns `ReachTapCamera` in these ports if required; persistence implementer must coordinate before editing same file. Root camera callback consumes a valid ReachTapSample or null on unavailable/invalid geometry. Controller owns fresh clock, scope/consent/lifecycle and save retry.

Original c3 FR-3.2 and c4 section4.9.6 were inspected. The owner requests a hand-target game with +10 per hit; whole-body cosine/combo scoring is not claimed or substituted into existing games. Local implementation, review and verification complete:180 tests pass, five existing skips, analysis/architecture/signed Android build pass. No deploy/install/content/reward mutation performed. See build/reach-tap-20261029/verification.json.

29 October: owner approved exact APK installation after the concrete local verification/build report. Installed/launched in place on Xiaomi7c4cbff with hash/signer/app identity/data preservation and prior APK retention verified. No cloud/Admin/content/Rules/reward/account change. Evidence: build/reach-tap-20261029/release-verification.json. Physical UAT pending; completed approval grants no further authority.
