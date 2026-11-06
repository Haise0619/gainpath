# Standard Floor Push-Up — Module 2 implementation

Current checkpoint:6 November 2026. The main-application promotion below supersedes the earlier local-only checkpoints. Original5 November implementation and test evidence remain historical. Existing unrelated working-tree changes are preserved; physical acceptance limits remain explicit.

## Main-application promotion — 6 November 2026

**PROMOTED: normal main-app source, shared live catalog/routine, schema7 compatibility and the matching private main Admin are active.** The owner clarified that “no debug mode” means the normal Android Studio Run action should launch the latest app without floor diagnostic flags or special configuration; a production keystore/release APK is not requested.

The ordinary `apps/mobile/lib/main.dart` route already dispatches the distinct stable floor ID. Its route now contains no diagnostic overlay, render collector or audio trace wiring. `FloorPushUpWorkoutSession.debugEnabled` is permanently false, including if an old launch configuration still supplies the previous diagnostic define. Internal test observation APIs and voice-event safety stay available; counting155/105/120ms, scoring/source versions and Wall Push-Up are unchanged. The existing `.idea/runConfigurations/main_dart.xml` points to this main entrypoint and already enables workout backup/check-in; it needs no floor-specific configuration. No launch setting was changed.

The normal Android Studio-equivalent build passes without floor debug/trace flags. Preserved artifact: `build/floor-push-up-main-20261106/gainpath-main-default.apk`, SHA-256 `9fc243f9592feeb607e92b764672c4e5fee5e0f059f5058d4cca66855276a877`, same debug certificate as the installed-development lineage. It is an ordinary Android Studio development build, not a signed production release. No phone installation is claimed. The matching ordinary Admin `main.dart` web bundle is active at `http://localhost:7359/`; its served hash matches the reviewed build and the previous bundle is preserved. No Dashboard code was changed.

### Shared catalog and schema compatibility scope

The main Admin reads its Firebase exercise catalog; the main Member discovers published routines. Local-only selection does not create that shared content. The exact prepared metadata in `tools/workouts/floor-main-content.json` defines active `standard-floor-push-up-side-v1`, blueprint `gp-standard-floor-push-up-v1`, and published routine `routine_gp-standard-floor-push-up-v1`, reusing3×8/60s. An empty media URL honestly means no authored video. Normal repository decoding, tracking labels, editor display and published routine parsing pass against those exact fields.

Read-only live preflight on6 November confirms72 Functions and the two unchanged schema<=6 archives. The two prepared schema7 overlays match their exact baseline hashes, with26 passing local package scenarios and148 backend tests. Source-only updates preserve runtime/environment/IAM and all unrelated packaged bytes. Publication is an atomic **create-only** transaction for the exercise, blueprint, published routine and audit, guarded by fresh verified active canonical Admin authority and absent targets.43 existing content/authority records are retained for preservation checks; no Member progress/backup writes or existing content updates are part of it. Module13 remains excluded.

Independent review found one important release-check gap: old target receipts could hide later service drift. Before publication and final verification the tool now rechecks both live ACTIVE services, sealed archive hashes, exact metadata, stable runtime/config and original IAM. Nine offline release-tool tests cover drift rejection, scope and unordered Eventarc-filter serialization. The review seals the source/helper/baseline/artifact inputs and requires a complete minimum input set. The Admin activation uses the same seal and requires live verification first.

**Approved live completion:** automatic approval initially rejected the production command because the earlier no-deploy gate remained. The owner then explicitly answered **“Approve this live promotion”** for the two compatibility updates and four create-only records. Both existing Functions are ACTIVE with exact prepared source hashes, unchanged runtime/configuration/IAM and original reporting implementation. The exercise, blueprint, published3×8/60s routine and audit were created once; exact readback and43 pre-existing content/authority records are verified. Other70 Functions, Rules and indexes are unchanged. The shared IDs are `standard-floor-push-up-side-v1` and `routine_gp-standard-floor-push-up-v1`.

A real approved synthetic Member read through client Rules and registered App Check returns the published routine; read-only backup negotiation succeeds for maxima2/3/4/5/6/7. Both compatibility callables reject anonymous requests with401. No Member workout/backup, enrollment/progress, reward or recommendation data was written. This read does not certify native phone attestation or a live schema7 save/restore write round trip; package/contract tests cover those payloads locally.

The initial preservation comparison rejected the server's reordered `eventTrigger.eventFilters` entries for one unrelated Eventarc Function. Independent raw inspection found69 exact Functions, one filter-order-only difference and no other differences. Firebase CLI itself models those filters as an attribute map. Verification now normalizes **only that filter-entry order**, retaining all values, operators, timestamps and other metadata. A dedicated failing-then-passing guard case proves actual value/metadata changes still fail. This was a verification representation correction, not an unrelated service update.

The normal main Admin bundle was activated after live verification; HTTP served SHA-256 matches the reviewed artifact. Existing private App Check configuration is preserved. Browser interaction was not independently replayed in this turn; actual catalog/editor widgets pass59 tests against the real adapter and prepared fields. Reload the main Admin and use Exercise Catalog; Members can discover the published routine and use existing AI workout selection. Run Android Studio's existing `main.dart` normally; no floor-specific args, new keystore or alternate entrypoint is required.

### Fresh checks and remaining physical limits

|Check|Result|
|---|---|
|Member default launch, voice/session and backup regressions, with legacy diagnostic defines deliberately supplied|**55 passed**|
|Normal Admin Firebase catalog/editor/routine/reporting regressions|**59 passed**|
|Complete pose suite|**745 passed**|
|Backend compatibility/evidence/reporting contracts|**148 passed**|
|Exact prepared compatibility package scenarios / release-tool guard tests|**26 /9 passed**|
|Scoped Member/Admin analysis|**No issues**|
|Normal Android Studio-equivalent APK / ordinary Admin web bundle|**Built**|
|Complete Mobile suite|**1,492 passed,21 skipped,16 failed**|

The broader16 failures are the previously documented12 incomplete Firebase fake cases and four Member-shell timeouts. The time-dependent17th booking fixture passes at today's midday run, supporting the previous diagnosis; no unrelated booking/profile/shell implementation was changed. No new floor case fails. Tests caught and corrected an intermediate UTF-8 readiness-text encoding mistake; only final passing runs are listed here.

The supplied `Screenrecorder-2026-11-06-12-06-12-70.mp4` is37.618s,1,080×2,400,911frames. It begins at4/8 and visibly reaches the first set's target/rest; it is not a complete-session or saved-history recording and does not establish an expected full-rep total. It shows right-side tracking. Physical Left Side View, audible cue timing/content, Finish/save/reopen and human form-score agreement remain unverified. Main source promotion is not a claim of universal exercise accuracy or commercial production acceptance.

Exact changed source/test/tools: floor workout route and session; new `apps/mobile/test/floor_push_up_main_app_test.dart`; new `apps/admin_web/test/floor_push_up_main_catalog_test.dart`; new `tools/workouts/floor-main-content.json`, `floor-main-release.cjs`, `floor-main-release.test.cjs`; new `tools/admin_web/floor-main-client.cjs`; plan `docs/superpowers/plans/2026-11-06-floor-push-up-main.md`; this report and the seven operational references. Private baselines, packages, review, builds and verification live under ignored `build/floor-push-up-main-20261106/`.

Earlier checkpoints below are historical.

## Voice Feedback fix — controlled debug candidate, production still NO-GO

The owner subsequently authorized the confirmed voice fix and physical-test debug APK. **The incomplete-extension correction now reaches the audio port**, including when the same accepted observation resets the rep phase to READY. The regular Mobile regression first failed with zero delivered extension cues, then passed with `floor_extension`; its tracking-warning positive control still passes. This fixes delivery before the port; audible phone timing/content remains unaccepted.

### Behavior and timing policy

- Floor observations expose geometry acceptance independently of phase/health. Newly completed/partial attempt counters create timestamped `floor_extension`, `floor_depth` or `floor_good` events once, from accepted observations only. Timer snapshots, duplicate/out-of-order inputs and interrupted/unobserved outcomes cannot manufacture events.
- Completed-observation events survive READY and brief recoverable tracking loss while engine preparation is pending. Their start lifetime is bounded to **500ms from the accepted capture**, including detector/delivery age. Expired/future/malformed/replayed events are dropped, not accumulated. Actual source/geometry replacement, sustained loss/warnings, pause, mute, background, model/account/session loss and Finish cancel pending speech. Started speech can finish through ordinary empty batches; higher-priority guidance/lifecycle events still cancel it.
- Existing warning > correction > encouragement arbitration and floor's **6-second per-cue cooldown** remain. Current-frame guidance keeps its existing semantics; only floor opts into native bounded starts. A final-target event can finish during rest/completion instead of being immediately discarded by the analysis pause. Explicit user pause/Finish still cancels.
- Trace stages correlate exercise generation, queue, arbitration/drop, dispatch, TTS request, native request, actual engine start/completion/cancel. Preparation stages identify cold-engine waiting. Debug-only bounded256-entry local traces omit text/landmarks/account IDs and are never persisted/uploaded. Release disables them. Native callback timestamps are sampled on the callback thread; Dart and Android clock origins remain explicit.
- Independent review found a relative-deadline bridge gap. The fix samples native monotonic time and subtracts the entire request/response wait, passing a conservative **absolute native expiry**. Delayed delivery cannot renew an old cue. Its deterministic delayed-channel test fails before this fix and passes after it; native expiry/late-epoch checks pass. Engine-start callbacks are not proof of audible speaker latency, so physical listening/trace correlation is still required.

**Counting and scoring unchanged:** TOP>=155°, BOTTOM<=105°,120ms dwell, geometry rules, recovered/unscored policies and source/scoring versions remain. The analyzer change is the acceptance-status field/getter; no state-machine/counting branch was changed. Other exercise implementations, Admin Dashboard, Firebase data and Module13 eligibility were not modified.

### Fresh verification and failure accounting

|Check|Result|
|---|---|
|Focused audio/event/native-port/floor-session tests|**51 passed**|
|Complete pure-Dart pose suite|**745 passed**|
|Focused backend contracts|**148 passed**|
|Exact prepared backend package scenarios|**26 passed**, local memory stores only|
|Native deadline/epoch assertions|**18 passed**, plain Java; not a physical TTS test|
|Scoped Dart analysis / source and test TypeScript checks|**Clean / passed**|
|Complete frozen-source Mobile suite|**1,488 passed,21 skipped,17 failed**|
|Android debug APK|**Built and signature verified**; same debug certificate as retained preceding APK|
|Production signing guards|Direct release and aggregate dry-run both reject missing production signing; no release built|

The17 failing case names exactly match the preceding review. **The extra17th is NOT an intentional voice regression:** it is `coach_booking_cancellation_ui_test.dart`'s midnight-crossing fixture (`now+2h` time with today's date), which hides Cancel as past. The original12 incomplete Firebase fakes and four Member-shell timeouts remain, with the classifications below. The earlier ignored voice release probe was separate; its equivalent now lives in the regular suite and passes. An intermediate run reported18 because source was edited during Flutter compilation; that invalid run is retained, superseded by the frozen-source result above. One verification launch was retried after automatic approval review timed out; the retry ran successfully. No failing run is represented as a pass.

### Artifacts, release preparation and remaining gates

New physical-test APK: `build/floor-push-up-voice-20261105/gainpath-floor-voice-debug.apk`. Its exact SHA-256, byte count, preserved prior APK, signature evidence, source hashes and test logs are in that directory's `verification.json`. The APK enables floor diagnostics and audio tracing for this controlled retest. No phone is connected; no install, real-device latency measurement or physical acceptance is claimed.

**Prepared, not deployed:** two exact source-overlay schema7 archives and per-file inventories/patches are in `build/floor-push-up-voice-20261105/backend-release/manifest.json`. Backup changes only negotiation and validation; reporting changes only its bundled validator. Both add the floor validator. Original reporting implementation, entrypoints, dependencies, Auth/App Check and other packaged bytes are preserved. Unrelated current FYP/reporting source is deliberately excluded. Local package checks cover scored/unscored left/right payloads, identity/source/fault spoof rejection, consent/ownership denial, client maxima2–7, missing scores and separate Wall/Floor groups. The active backend remains schema<=6 until a later verified release.

**Production signing prepared:** Gradle takes an approved keystore via ignored properties/environment and has no debug-key fallback. Both requested release tasks and actual aggregate task graphs fail closed without it. The aggregate dry run reproduced the bypass before the task-graph fix and rejects after it. No production key was generated, no credentials were exposed and no production artifact was created. Certificate continuity and attestation remain gates.

Follow the [controlled physical checklist and exact compatibility/signing release gates](floor-push-up-physical-acceptance.md) for Right/Left, corrections/encouragement, timing, Finish, saved summary, reopened history and scored/unscored availability. **Overall production decision remains NO-GO:** physical acceptance, restored/accepted broader integration coverage, matching deployed schema7 and approved production signer/attestation are outstanding. No Firebase deploy, user-data write, Admin activation or production distribution occurred.

### Exact files changed in the voice task

- `packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart`
- `apps/mobile/lib/features/workout/application/floor_push_up_workout_session.dart`
- `apps/mobile/lib/features/workout/application/workout_audio_controller.dart`
- `apps/mobile/lib/features/workout/domain/workout_audio_port.dart`
- `apps/mobile/lib/features/workout/domain/workout_feedback_event.dart` (new)
- `apps/mobile/lib/features/workout/domain/workout_audio_trace.dart` (new)
- `apps/mobile/lib/infrastructure/audio/android_workout_audio.dart`
- `apps/mobile/lib/app/routing/floor_push_up_workout_route.dart`
- `apps/mobile/android/app/src/main/java/com/zyang/gainpath/WorkoutAudioPlugin.java`
- `apps/mobile/android/app/src/main/java/com/zyang/gainpath/AudioPlaybackEpoch.java`
- `apps/mobile/android/app/src/main/java/com/zyang/gainpath/AudioStartDeadline.java` (new)
- `apps/mobile/android/app/src/test/java/com/zyang/gainpath/AudioStartDeadlineCheck.java` (new)
- `apps/mobile/android/app/build.gradle.kts`
- `apps/mobile/android/key.properties.example` (new, blank template)
- `apps/mobile/test/floor_push_up_voice_feedback_test.dart` (new)
- `apps/mobile/test/workout_feedback_event_test.dart` (new)
- `apps/mobile/test/android_workout_audio_test.dart`
- `tools/workouts/prepare-floor-schema7.py` (new, offline only)
- `tools/workouts/verify-floor-schema7.cjs` (new, offline only)
- `docs/superpowers/plans/2026-11-05-floor-voice-feedback.md` (new)
- `docs/integration/floor-push-up-physical-acceptance.md` (new)
- This report and seven operational references: `AGENTS.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md`, `docs/STATUS.md`, `docs/PROGRESS_REPORT.md`, `docs/SUPERVISOR_DEMO_GUIDE.md`.

Earlier checkpoints below are historical and retain the original failure evidence.

## Final release-readiness review - 21:41 recording - NO-GO

**Decision: NO-GO for production build/distribution or Firebase deployment. GO to retain the current detector/thresholds for controlled acceptance testing.** This review makes **no production algorithm, threshold, app, Firebase or signing changes**. Four characterization tests freeze the correct treatment of the two partial returns. A release build was deliberately not prepared because the owner's required release gates have not passed.

### Real-device observations and partial classification

The independently inspected `Screenrecorder-2026-11-05-21-41-22-837.mp4` is1080x2400,1,103 frames,45.505s. The app visibly reaches **5/8** on the right-selected side. This is observed counter behavior, not a measured population accuracy rate or independently labeled expected-full-rep total. Original raw landmark replay is unavailable; repeated video renders are not separate detector observations.

|Requested sequence|Observed peak evidence|Reset / recovery|Classification under current rules|
|---|---|---|---|
|24-27s|Raw152.61 degrees at capture37149733; later152.34 and152.12; maximum displayed smooth152.08. All are<155.|`incomplete_extension_reversal`, ASCENDING, capture37629802; fresh TOP later around27s.|Correct **incomplete extension**, not evidence of a missed accepted TOP. Do not force a count.|
|37-40s|Raw150.82,151.30,151.41; maximum displayed smooth151.05, then falling angles. All are<155.|`incomplete_extension_reversal`, ASCENDING, capture50709538; fresh TOP around40s.|Correct **incomplete extension**, not the previous dwell-boundary defect.|

In both windows geometry remains accepted, the raw TOP tracker stays at zero, knees are about173-178 degrees with high visibility, and knee-candidate count stays zero. Thus the knee guard and a geometry veto do not explain these two outcomes. TOP>=155, BOTTOM<=105 and120ms dwell remain unchanged; current tracked evidence does not justify a calibration/version change. Classification is relative to these provisional camera rules, not a biomechanical judgment inferred from appearance alone.

A **separate tracking interruption** also exists near32.4s: the last-reset context records `limbChange`, ASCENDING, capture45041685, followed by fresh TOP acquisition. It is not one of the two incomplete-extension reversals. The selected before/after samples do not preserve the rejected frame's complete trajectory reason, so this review does not call it a confirmed full repetition or silently force it to count. That limits any claim of whole-recording count accuracy and remains part of robustness acceptance.

The owner explicitly confirmed **Left Side View has not been manually tested or recorded**. Right-side observations and synthetic left-side cases do not clear that gate. No connected Android device was available in the read-only final ADB inventory.

### Required release gates

|Area|Confirmed evidence|Release status|
|---|---|---|
|Left/right repetition behavior|Right-side5-count recording and two correctly rejected partials; four new analytic left/right partial characterizations pass.|**OPEN:** physical left-side expected/count/partial labels absent; whole-recording accuracy and the separate interruption are not accepted.|
|Form Score|Strict v1 formulas/weights/grouping unchanged. Projection/world/recovery/added raw-TOP evidence withholds score; null components remain null. Clean strict-path, unscored and serialization tests pass.|**SOURCE/TEST PASS; PHYSICAL OPEN:** no scored/unscored phone summary or human fault-label calibration is shown. Do not replace unavailable form with a reliable0%/100% claim.|
|Voice Feedback|Isolated arbiter/port tests cover priority/cooldown/lifecycle. A separate real-session audit reproduces loss of the partial-extension correction before it reaches the port.|**FAIL - CONFIRMED INTEGRATION DEFECT**, plus owner-reported confusing/late and missing coaching. Actual timing is not measured; see below.|
|Completion/partials/local history|Floor tests cover target sets, failed-save exact retry, schema7 round trip, result UI, local repository history and account/provenance guards.|**TEST PASS; PHONE/SHELL OPEN:** owner has not completed the whole set; recording ends during active tracking and does not show Finish, saved summary or reopened history. Two relevant Member-shell journeys time out before assertions.|
|Module12 / Cloud Backup|Current source supports schema7, separate wall/floor groups and descriptive null-score gaps;148 focused backend tests pass.|**FAIL DEPLOYED COMPATIBILITY:** active backup/reporting archives remain schema<=6; details below.|
|Existing exercises|745 complete pose tests and140 focused Mobile tests pass, including squat, curl, row, shoulder press, calf raise, lateral raise, reverse lunge and Wall Push-Up sessions.|**PASS at regression-test level.** No production exercise source changed during this review.|
|Broader Mobile suite|Fresh result1,467 passed,21 skipped,17 failed; the prior16 remain and an additional time-dependent fixture failure is reproducible.|**NOT GREEN:** classification below; no blanket waiver.|
|Production configuration|Floor diagnostics default off and are forced off by `!kReleaseMode`; callback/render diagnostic paths are guarded. Release App Check defaults to production/Play Integrity; emulator/debug modes must not be supplied.|**DIAGNOSTIC SOURCE PASS; ARTIFACT OPEN:** no release build/attestation acceptance. Gradle currently uses the **debug signer** for release.|

**Owner acceptance update:** Left Side View is explicitly untested; the whole set has not been completed. The owner reports that speech is confusing/late and sometimes gives no correction when form is wrong. This is **failed voice acceptance**, not an acceptance pass inferred from an audio track. Finish/save/reopen and physical form-score correctness remain unverified.

**Confirmed voice integration defect:** a valid incomplete attempt emits the corrective `floor_extension` cue, then `_reset()` sets health to degraded and phase toREADY. `FloorPushUpWorkoutSession._consume` passes `trackingAvailable:false` (`health==healthy && !needsCalibration`), and `WorkoutAudioController.consume` filters nonwarning cues in that state. Thus **"Extend your arms fully" is dropped before the audio port**, despite the current geometry having been accepted. This conflates a repetition-phase reset with loss of pose tracking. Source locations: analyzer partial/extension branch, `apps/mobile/lib/features/workout/application/floor_push_up_workout_session.dart:260`, and `workout_audio_controller.dart:124`.

The ignored real-session Flutter audit `voice-release-probe_test.dart` runs full-coaching mode and produces one correct partial, accepted geometry, and **zero extension cues delivered**. Its positive control then delivers `floor_tracking` through the same port, ruling out a muted session or disconnected test sink. The required-correction assertion fails. This is **one separate failing release probe**, not one of the17 regular-suite failures. Independent re-review confirms the source path. Production code was intentionally not changed in this release review; a focused correction-delivery fix with source-loss safety tests is required before release. This is not an algorithm-threshold calibration proposal.

**Latency scope:** owner-reported delayed/confusing speech is real failed acceptance, but this review does not assign it a measured duration or assume the same defect explains all utterances. Existing policy lets already-started speech finish through later empty cue batches; TTS start/completion and phase timing need a device trace/listening check. Do not change counting thresholds or cooldowns speculatively to mask it. The recording's audio track has mean-32.6dBFS and peak-10.7dBFS; those levels can include ambient sound and do not identify spoken cues or certify speaker routing, volume, priority or interruption behavior. Extracted clips stay private in ignored build evidence. Method-channel/audio-controller tests use test ports and are not native speaker acceptance.

### Verified deployed backend incompatibility - concrete blocker

Read-only inventory found72 Functions. The two actual active archives were downloaded through the Functions source-download API; no deployment, user-data query, workout write, Rules/config/IAM change or provider-content action occurred.

|Function, asia-southeast1|Active source updated (UTC)|Verified source behavior|Archive SHA-256|
|---|---|---|---|
|`workoutBackupCommand`|2026-10-28 14:33:41.497|Negotiated maximum rejects7 (`>6`); validator rejects floor schema7 fields.|`78a1ec02e6cc20e1ad3db349c33a28891219b200a5e92a927d360d965c67a464`|
|`adminWorkoutReportingCommand`|2026-10-28 14:33:52.597|Its bundled workout validator also rejects schema7 floor metrics.|`59e96fbe7bbb8f8a38a54f2161edd35330f27647192709f59d6149379f967528`|

The downloaded **pure validators were executed locally**, with no live workout datastore access: both scored and unscored floor payloads were rejected in both archives (`Unexpected backup fields.`). Schema7 list negotiation was rejected (`Invalid supported pose metric version.`) **before the fake store was touched**. These are executions of the deployed-source validators, not claimed authenticated live round trips. Current local source contract tests accept these shapes and preserve old-client filtering, but that source has not replaced the deployed services.

Cloud Backup defaults off unless explicitly enabled (or emulator mode is used). Keeping it off protects local practice, but it does not establish the requested cloud-enabled release compatibility. The Mobile gateway explicitly requests maximum7, so an enabled release against the current backend can fail listing as well as floor saving. A reviewed matching backend release and authenticated schema7 save/list/restore/report acceptance are required before distribution; **none was deployed in this review**. Module13 floor evidence remains explicitly `unsupported_exercise` and is not enabled by descriptive Module12 support.

### The sixteen known failures and one newly exposed fixture failure

Exact names for the original16 remain listed in [Remaining broader-suite failures](#remaining-broader-suite-failures); the fresh17-name list and logs are retained in the verification manifest.

|Failure group|Confirmed cause / limit|Release-impact classification|
|---|---|---|
|8 `member_contact_details_repository_test.dart` cases|Test fake implements `doc` but not `collection`; current `FirebaseDataScope.scopeUser` uses SDK-supported `collection('users').doc(...)`. Stacks stop at Fake.noSuchMethod.|**Test-fixture defect, not demonstrated Firebase runtime defect.** Their profile/staleness/security assertions are not exercised, so coverage must be restored or explicitly replaced; cannot claim whole-app green.|
|4 `member_photo_gateway_test.dart` cases|Same incomplete fake API boundary.|Same classification; photo/account-isolation coverage remains unavailable.|
|`coach_availability_flow_test.dart` Member directory/logout|Initial `pumpAndSettle` timeout before feature assertions.|**Unresolved shell integration evidence gap.** Does not demonstrate a floor detector regression.|
|`member_equipment_test.dart` Firebase Home equipment entry|Initial settle timeout before browsing/no-activity assertions.|Same unresolved shell integration gap.|
|`member_local_progress_flow_test.dart` Home/Profile history/account switch|Initial settle timeout before history/isolation assertions.|**Direct release blocker for the claimed local-history journey** until bounded-state testing or equivalent device evidence clears it.|
|`workout_backup_integration_test.dart` background save/opt-out|Initial settle timeout before backup/opt-out assertions.|**Direct release blocker for the backup journey.**|
|Additional `coach_booking_cancellation_ui_test.dart`: Coach can cancel confirmed upcoming session with mandatory reason|Fresh full run and isolated retry fail to find Cancel. After22:00 the fixture's `now+2h` start is tomorrow, but `localDate` remains today. Presentation combines today's date with tomorrow's00:xx label, considers it past and hides Cancel.|**Confirmed time-dependent fixture inconsistency**, outside floor counting; cancellation assertions are not reached. Recorded rather than hidden by reporting the prior16 count.|

MemberShell instantiates multiple pages in an IndexedStack. Offstage loading animation is a plausible reason settle cannot finish, but source/logs alone do not prove the exact spinner or prove that live initialization succeeds. These four failures are not automatically harmless. No unrelated production profile, booking or shell code was changed to make this review green.

### Build/configuration decision and closure criteria

`FloorPushUpWorkoutSession.debugEnabled` is false by default and false in release even if the debug define is accidentally supplied. Production configuration must omit developer/GPU/performance/blank-pose flags, keep emulator injection off and use the production App Check provider. The existing `apps/mobile/android/app/build.gradle.kts` release block explicitly selects `signingConfigs.getByName("debug")`; an approved production signer and its update/attestation compatibility are not configured/verified here. No keys were created, exposed or replaced.

**No clean production artifact was created or distributed.** Before a release candidate: fix and regression-test valid partial correction delivery without treating phase reacquisition as source loss; measure and accept native cue timing/content; complete manually labeled left/right full/partial/interrupted and Finish/save/reopen checks; restore/replace the blocked integration coverage and stabilize the dated fixture; resolve approved signing; prepare and verify matching schema7 backend compatibility without weakening Auth/App Check/ownership/consent; then verify the scoped deployed round trip before distributing Mobile. Respect the owner's no-deployment/no-production-build gate until the required checks pass. Held workout rewards/verified upload and Module13 eligibility remain disabled.

Fresh verification: **745 pose tests,140 focused Mobile tests,148 focused backend tests pass; scoped Dart analysis and source/test TypeScript checks pass.** Full Mobile remains1,467/21skip/17fail, **and the dedicated voice-delivery release probe fails**. Synthetic cases are acceptance characterizations only, not real-camera accuracy. Production algorithm hashes match the preceding build. Extensive unrelated working-tree changes are preserved; this is not a sealed whole-application release snapshot.

This review changes only `packages/gainpath_pose/test/floor_push_up_release_acceptance_test.dart` and the eight current Markdown references (this report,AGENTS,README,ARCHITECTURE,OPERATIONS,STATUS,PROGRESS_REPORT,SUPERVISOR_DEMO_GUIDE). Private recording panels, audio extracts, deployed source archives/replays, logs and hashes are retained in ignored `build/floor-push-up-release-review-20261105/verification.json` and its directory.

## Observed TOP dwell and reset diagnostics - fifth recording

**Acceptance assessment:** tracking is substantially better, but the supplied27.677-second recording is not sufficient to accept repetition-count accuracy. The fifth candidate has observed depth and extension that the smoothing-only dwell misses; its reset then prevents the next low position from starting a valid cycle. The corrected source/build is ready for another controlled phone test, not a claim of completed physical acceptance.

`Screenrecorder-2026-11-05-20-37-28-756.mp4` was inspected independently. Container:1080x2400,671 frames,27.677s (about24.244fps); displayed upright camera coordinates480x720. Repeated screen frames were not treated as new detections. The visible counter reaches4/8. Original raw landmark coordinates and complete internal filter/timer trace are unavailable.

### Exact TOP evidence and the reset

|Capture timestamp (us)|Accepted raw elbow|Displayed smoothed elbow|State|
|---:|---:|---:|---|
|33907727|74.23|71.78|BOTTOM; credit acquired|
|34391677|137.21|133.39|ASCENDING|
|34481982|157.30|151.98|ASCENDING; raw TOP already observed|
|34562043|158.00|156.40|ASCENDING; first smoothed TOP|
|34680746|160.35|159.46|ASCENDING; second smoothed TOP|
|34780402|152.57|154.69|ASCENDING; smoothed hold clears|
|34990162|128.96|134.16|ASCENDING; clear downward reversal|
|35045461|114.58|cleared|READY / waitingTop; previous implementation labels geometry rejected|

The smoothed TOP pair spans **118,703us**,1,297us short of120,000us. The overlooked earlier raw TOP gives **three actually accepted raw TOP observations spanning198,764us**. The first eligible smoothed observation is80,061us after the first observed raw TOP; smoothing consumes an accepted capture interval before its hold begins; demanding another full120ms after that crossing loses this peak. This is not a reason to lower155degrees or pretend118.703ms equals120ms.

The old source's ASCENDING reversal branch calls `_complete(extended:false)` followed by `_reset()`, clears BOTTOM credit/filter/pose, and returnsREADY. That branch explains the35045461 snapshot, including `waitingTop` rather than a geometry fault. `Geometry rejected` was derived from the now-cleared `_geometry` and degraded phase-reset health, so it falsely described a state reset as an input rejection. `Last reset kneeSupport` was already displayed during healthy TOP/BOTTOM earlier in the recording and was not updated by this branch. A new actual knee veto would have current rejection `kneeSupport`, rather than this snapshot's `waitingTop`. The exact original `_turnSince` was not logged; painter timestamp34921516 is consistent with the120ms reversal completing by35045461 but is not substituted for a raw timer trace.

The later63.73-degree observation at21.5s is accepted image geometry, but READY correctly requires a fresh TOP before it can start another cycle. It cannot resurrect lost earlier credit. The source correction preserves the observed fifth TOP so the subsequent descent can form its own measured cycle.

### Implemented correction, with unchanged thresholds

The strict smoothed120ms path remains and takes precedence, retaining its existing score behavior. An additional **count-only** TOP path requires all of:

- previously observed valid BOTTOM and current ASCENDING phase;
- at least **three distinct accepted raw elbow observations>=155degrees**, all with primary confidence>=0.85;
- actual first-to-last capture span>=the unchanged configured120ms, with existing<=250ms source/capture/freshness bounds;
- a current smoothed endpoint>=155degrees.

There is no interpolation, extrapolated crossing, timestamp rounding or dwell-shortfall tolerance. Rejected input, source/phase reset or a broken raw hold clears this evidence. Duplicate/out-of-order captures cannot add samples. A raw/smoothed endpoint below threshold cannot authorize this path. **TOP155/BOTTOM105 and120ms dwell remain unchanged.** New internal evidence revision: `floor-observed-top-dwell-v1`; tracking revision `floor-geometry-recovery-v6`.

A repetition that uses the added path is **unscored**. The v1 scoring formulas/version/weights/source groups are unchanged; conservative aggregate behavior leaves form unavailable after unassessable evidence. Existing geometry/trajectory checks, source integrity, other exercises, voice policy, Firebase/history/Module12 contracts and Module13 exclusions remain.

Diagnostics now report input geometry acceptance/rejection independently of phase resets, explicit `incomplete_extension_reversal`, interrupted phase and associated capture context. Current projection diagnostics clear between frames instead of displaying old metrics as current. The panel adds current raw TOP count/span, last confirmation method/span and knee raw/qualified angle, visibility/presence, threshold and consecutive candidate count. Latest diagnostic data includes knee candidate duration and side.

**Knee investigation:** the image-side Hip-Knee-Ankle angle is supplementary. The existing guard remains: a valid visible/present knee (>=0.65) with angle<125degrees rejects knee-supported geometry; a missing/low-confidence knee is not invented. There is no evidence-supported knee-classification change in this task. The original historical knee angle/confidence/persistence cannot be recovered from the old panel. Added tests demonstrate90-degree/high-confidence rejection, unchanged125-degree threshold, both sides, candidate persistence and low-confidence exclusion. New diagnostics will make a genuine future knee rejection measurable rather than attributing a historical label to a current miss.

### Measured before/after, verification and remaining limits

Analytic fixtures retain the visible capture timestamps/raw angle samples, using constructed joint coordinates and a controlled filter history. Their computed smoothed values are not claimed to reproduce the phone's hidden history exactly. The preserved actual previous library matches its prior source manifest.

|Reproduction, each left/right side|Previous|Corrected|
|---|---|---|
|Three observed raw TOP samples over198,764us|0 completed /1 partial after reversal|1 completed /0 partial, unscored|
|Above sequence plus next measured full cycle|0 completed|2 completed, unscored|
|Only two eligible TOP observations over118,703us|0 completed /1 partial|0 completed /1 partial|
|Accepted incomplete reversal diagnostic|Geometry rejected; stale reason|Geometry accepted; explicit phase-reset reason|

The original RED run reproduced the miss and misleading diagnostics. **741 complete pose tests pass**, including20 new dwell/reset/knee cases; **105 affected Mobile tests pass**; scoped analysis is clean and Android debug build passes. Full Mobile: **1,468 passed,21 skipped,16 failed**; extracted names match the same twelve Firebase-fake and four Member-shell failures listed in the historical section below. Strict-path score tests remain green. New cases cover exact120ms, just-short118.703ms, insufficient extension, duplicate captures, rejected confidence, elapsed gaps, low confidence, smoothed endpoint below155, both sides, subsequent-cycle continuity and honest partial resets. Independent review found a gap/source-reset context being overwritten withREADY; its regression failed, was corrected and passes in the final full suite.

APK: `build/floor-push-up-dwell-20261105/gainpath-floor-dwell-debug.apk`, debug define `GAINPATH_FLOOR_PUSH_UP_DEBUG=true`, SHA-256 `F261768D25CF3F492789BBBBAD968A0DED92449B63853497F98D9D9CFCD923F7`. Previous source/APK, private video extracts, RED/GREEN logs and before/after JSON remain in that ignored evidence directory. No phone was connected; no install or cloud operation occurred. **Real-device counting and knee-classification acceptance remain pending.** No error percentage or biomechanical accuracy is inferred from the synthetic tests. Retest normal repeated cycles, short/insufficient extensions and knee-supported/occluded conditions on both sides with manually labeled outcomes.

Exact files for this correction:

```text
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_top_evidence.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_geometry.dart
packages/gainpath_pose/test/floor_push_up_top_dwell_test.dart
packages/gainpath_pose/test/support/floor_push_up_dwell_fixture.dart
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
docs/integration/standard-floor-push-up.md
AGENTS.md
README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/STATUS.md
docs/PROGRESS_REPORT.md
docs/SUPERVISOR_DEMO_GUIDE.md
```

## Phase-aware projected-limb validation - fourth recording

The `Screenrecorder-2026-11-05-18-22-24-893.mp4` was independently inspected rather than treating the attached AI analysis as instructions. Measured container: **1080x2400,1,306 frames,53.900s**; visible camera coordinates remain480x720. The counter reaches4/8. Visually apparent movements are not automatically labeled valid repetitions, and this task did not reprocess original raw landmarks.

### Confirmed evidence and root cause

|Video event|Visible measured evidence|Observed consequence|
|---|---|---|
|17.8s /18.0s|Forearm26.7%; then upper25.7% /forearm27.3%; confidence0.96|BOTTOM suspended; later READY with last reset `accepted_result_timeout`|
|38.8s|Upper32.9% /forearm24.7%; raw77.73; world-XY80.00; confidence0.95|`limb_recovery_rejected_limbChange`|
|42.40s|Forearm36.0%; raw69.33; capture62029137|Pending BOTTOM|
|42.46s|Forearm38.5%; raw70.41; capture62129315; confidence0.94|Second rejected result immediately clears BOTTOM|
|42.58s|Raw67.17; capture62158664|Geometry resumes, but READY has no bottom credit|
|46.8s|Forearm29.0% (not29.8 in the suggestion); raw104.56; world-XY102.17; confidence0.99|TOP/departure is reset before the later accepted84.18-degree observation|

For the42s case, the last visible accepted capture is61970190 (raw76.42); first recovery62158664 is only **188,474us** later. Two failures within the250ms budget still reset because the preceding policy allowed only one rejected frame. Conversely, the17.8/18.0 sampled panels both say pending and are not proof of consecutive detector rejections; intermediate acceptance cannot be ruled out. The visible watchdog reset is distinct from the rejection-count reset. A latched `Last reset` is now labeled explicitly so it is not mistaken for a current rejection.

The structural issue is using **one initial TOP projected limb length as an identity gate throughout a changing pose**. The implementation compares aspect-corrected shoulder-elbow and elbow-wrist2D lengths with that fixed TOP baseline. Projection changes are not measurements of changing bone length. The prior single-frame, BOTTOM-only exception still reset descending/departure and short multi-frame discontinuities. The recording now identifies the affected segment and deviation magnitude; original signed directions, segment pixels and full joint trajectories remain unavailable.

### Corrected counting acceptance and score separation

The **25% TOP-baseline gate is unchanged for form eligibility**. A frame beyond it can receive explicit2D **counting acceptance** only after fresh temporal validation against the last accepted observation:

- identical detector/model, selected anatomical side and upright dimensions; existing mirror/view/visibility/primitive/anchor gates remain active;
- capture and delivery intervals each<=250ms; both observations' primary confidence>=0.85;
- each adjacent projected limb change<=the same25% threshold; maximum image-joint displacement<=0.12 of the preceding shoulder-ankle length;
- elbow orientation stays consistent and angular change<=the existing500degrees/s development bound;
- available high-confidence world-XY elbow/body angles agree with image angles within25degrees, and shoulder-relative world-XY joint steps normalized by projected body length stay<=0.18. Independent3D contradiction validation remains active. Copied world visibility is not presented as independent depth confidence.

Rejected frames never seed this trajectory. World-XY disagreement, unavailable world support, low confidence, abrupt joint/segment motion or swaps cannot authorize a baseline departure. Once trajectory validation is required, it continues through a return inside baseline bounds: an abrupt56.25% adjacent expansion cannot bypass it merely by matching the old TOP length. It ends only after an observed complete extension with baseline-compatible lengths, or a reset.

A frame that fails counting validation still contributes **no angle, minimum, smoothing, dwell or BOTTOM/TOP credit**. An unresolved limb rejection can suspend TOP/departure, DESCENDING or a previously observed BOTTOM for the existing **250ms accepted-capture AND delivery budget**, with no arbitrary one-frame cutoff. Rejected samples do not refresh that budget. Recovery needs valid temporal geometry and phase-compatible endpoints; any interrupted dwell restarts. BOTTOM recovery retains the20-degree endpoint bound. A previously unobserved depth crossing earns no credit until fresh accepted<=105-degree samples satisfy the normal dwell. Subsequent ASCENDING and observed>=155-degree TOP/dwell remain required.

Continuously validated projections are fresh measurements, not an extended dropout: a held BOTTOM remains countable while independently passing every per-frame check. Persistent genuinely invalid geometry expires/interruption remains mandatory. The rule is not an unlimited allowance for rejected frames.

**All projection-revalidated or limb-recovered attempts are unscored, including a suspension before DESCENDING begins.** Existing conservative aggregate behavior keeps form components unavailable after an unassessable attempt. The155/105 thresholds, scoring rules/weights/version, metric schema/source, existing session/history/Module12 contracts, Module13 exclusions, Wall Push-Up and other exercise algorithms are unchanged. Internal revisions are `floor-projected-limb-trajectory-v1`, `floor-phase-limb-continuity-v2` and tracking `floor-geometry-recovery-v5`.

The opt-in debug panel now shows signed TOP deviations, adjacent deviations, trajectory rejection reason, normalized image/world-XY steps and explicit accepted2D/unscored status. Latest-only diagnostic data also exposes capture/delivery ages and numerical thresholds. No automatic trace/video persistence, production logging, Firebase/Admin/backend change or telemetry was added.

### Before/after evidence and verification

Analytic triangles reproduce the visible angles/deviation magnitudes; signed compression and world coordinates are explicitly chosen fixture values, not recovered phone values. The preserved **actual previous library** matches its preceding build manifest and is used through an isolated package configuration. No app source rollback or simulated disabling of the old policy is used here.

|Constructed sequence, each left/right side|Previous count /partial|Corrected count /partial|Score|
|---|---|---|---|
|A:forearm26.7%,27.3% near BOTTOM|0 /1|1 /0|Unavailable|
|B:upper32.9% and valid recovery|0 /1|1 /0|Unavailable|
|B2:forearm36.0%,38.5% then valid recovery|0 /1|1 /0|Unavailable|
|C:TOP/departure, forearm29.0%, newly observed depth|0 /0|1 /0|Unavailable|

All eight left/right reproductions improve0->1; these are synthetic case outcomes, **not a real-video error rate**. Initial RED tests reproduced the resets. Independent review found two further edge cases: pre-departure recovery could yield a score85, and an abrupt return into baseline bypassed temporal checks. Both were reproduced RED, fixed and re-reviewed. The final42 focused limb/projection cases pass. Tests cover missing observed depth/extension, rejected depth, persistent jumps, swaps, low confidence, unavailable world, inconsistent world motion, long capture/delivery gaps, held BOTTOM, repeated cycles and duplicate prevention. Two earlier floor tests now correctly express time-based persistence and avoid supplying accepted90-degree holds in the missing-depth negative.

Fresh final checks: **721 complete pose tests passed;105 affected Mobile tests passed; scoped Dart analysis clean; Android debug build passed.** Complete Mobile suite: **1,468 passed,21 skipped,16 failed**; exact failure names match the previous build (twelve incomplete Firebase fakes and four Member-shell timeouts, named below). Backend/architecture checks were not rerun because their source is unchanged; no historical passes are represented as fresh.

APK: `build/floor-push-up-trajectory-20261105/gainpath-floor-trajectory-debug.apk`, `GAINPATH_FLOOR_PUSH_UP_DEBUG=true`, SHA-256 `0D1ECB7A360BEC6334CE2C8B94AA9B37A89F1C7165F4C9BC7CCCFDA4E35C8762`. Previous source/APK, measured JSON and logs are preserved in that ignored directory. No phone was connected and no install occurred. **Physical retest is required**: the world/image step bounds and confidence policy are development parameters, not calibrated real-device accuracy. Original raw landmark replay and signed per-segment phone measurements are unavailable. Future validation must label valid/partial/interrupted cycles on both sides and compare counts/form disagreements on held-out real recordings; no universal accuracy is claimed.

Exact files for this correction:

```text
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_projection_evidence.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/test/floor_push_up_projection_test.dart
packages/gainpath_pose/test/support/floor_push_up_projection_fixture.dart
packages/gainpath_pose/test/floor_push_up_limb_continuity_test.dart
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
docs/integration/standard-floor-push-up.md
AGENTS.md
README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/STATUS.md
docs/PROGRESS_REPORT.md
docs/SUPERVISOR_DEMO_GUIDE.md
```

## Isolated BOTTOM limb-change correction - third debug recording

The supplied `Screenrecorder-2026-11-05-17-05-00-307.mp4` was inspected independently of the attached AI suggestion. Its measured container is **1080x2400,739 frames,30.495 seconds**. The debug panel reports actual upright camera coordinates of **480x720**. The counter reaches2/8; two missed movement candidates show a directly visible accepted-BOTTOM -> `ready / limbChange` reset. No raw landmark replay or human-labeled accuracy rate is claimed.

### Video evidence and the confirmed reset mechanism

| Event | Capture timestamp (microseconds) | Raw image elbow | World3D / projected elbow | Analyzer |
|---|---:|---:|---|---|
|A, about16.56s|73733040|68.24 degrees|73.94 /73.96|Accepted BOTTOM, smoothed70.07|
|A, about16.68s|73903375|54.79 degrees|68.68 /60.95|Rejected `limbChange`, READY; body217.44px|
|A, about16.80s|73944501|61.75 degrees|69.41 /68.75|Geometry accepted, but historical BOTTOM already lost|
|B, about20.55-20.67s|77758161|82.68 degrees|100.71 /91.00|Accepted BOTTOM, smoothed80.73|
|B, about20.72-20.80s|77875009|78.95 degrees|79.49 /80.36|Rejected `limbChange`, READY; body217.83px|
|B, about20.84s|77941160|63.94 degrees|83.83 /69.45|First accepted recovery; an earlier frame than the suggested69.88-degree sample|

Repeated displayed frames are not independent detector observations. The accepted-to-accepted capture intervals are **211,461us for A** and **182,999us for B**. Recovery angle differences from the last accepted image observation are6.49 and18.74 degrees. Both rejected frames show world `agreed`, size ratio about0.45 >=0.30, and pose/painter input. Those are separate from the rejected continuity gate and do not prove depth ground truth.

`FloorPushUpAnalyzer` compares the current **2D aspect-corrected shoulder-elbow and elbow-wrist projected lengths** against the lengths saved at the stable initial TOP, not the previous accepted frame. If either absolute relative change exceeds **25%**, `limbChange` is raised. Previously only confidence/missing-landmark rejections could enter bounded recovery; every limb-change rejection called `_reset(interrupted:true)` immediately. That cleared `_bottomValid`, bottom/ascent times, phase, filter and TOP baseline, so the later observed extension could not finish the earlier cycle. A meaningful interrupted attempt was retained as one unscored partial.

The original panel did not print either segment length, TOP baseline or change percentage. Therefore the **exact triggering segment and percentage in this phone recording are unknown**. The rejection proves at least one projected segment crossed25%, not which one. Projection foreshortening or elbow localization noise is a plausible mechanism; this composited video does not establish its exact cause. The new panel and current-only diagnostics expose both segment changes, triggering segment names, threshold, primary confidence, baseline/current lengths, continuity decision and reset reason. No trace persistence or cloud logging was added.

### Targeted continuity policy

The **25% limb consistency gate remains unchanged**. The bad frame is rejected: it supplies no smoothed angle, measured minimum, phase dwell, BOTTOM/TOP credit or form component.

Only a single limb-change frame may suspend an already acquired BOTTOM when all of the following hold:

- BOTTOM was previously observed and validated; both the last accepted raw elbow and the rejected raw elbow are <=105 degrees.
- Their angle difference is <=20 degrees; image geometry, visibility, side view and anchor checks otherwise pass, with no confirmed world contradiction.
- Capture freshness, accepted-result delivery freshness and source continuity satisfy the existing250ms bounds; side/model/dimensions cannot change.
- The **next delivered observation** must be valid against the unchanged TOP limb baseline and anchors, still in the <=105-degree band, within20 degrees of the last accepted raw angle, and within250ms of that accepted observation in **both capture and delivery time**.

The versioned development policy is `floor-bottom-limb-continuity-v1`, with tracking diagnostic revision `floor-geometry-recovery-v4`. The20-degree bound accommodates the visible18.74-degree recovery while still rejecting larger hidden changes; it is provisional and not biomechanically validated. At most **one** rejected frame is allowed. A repeated limb failure, intervening occlusion, invalid geometry or confirmed world contradiction, unsafe recovery motion, excessive capture/delivery interval, camera/model change, pause, finish or watchdog timeout interrupts the attempt. Existing confidence-only recovery remains unchanged.

Successful recovery preserves historical BOTTOM only. Its phase dwell and reversal hold restart from valid observations, and a fresh measured ASCENDING -> >=155-degree TOP with existing timing/dwell is still necessary. Rejected depth or extension cannot create credit. Both **155-degree TOP /105-degree BOTTOM** remain unchanged.

Any such recovered attempt has `unstableTracking` and remains **unscored**. Existing conservative aggregate behavior leaves the session's form components/score unavailable once an attempt is unassessable. Counts and descriptive activity still persist through the existing session/history contracts. Scoring version/source/schema, Firebase/Module12 compatibility, Module13 exclusion, Wall Push-Up, other exercises and voice policy are unchanged. No backend/Admin source or production data was touched.

### Deterministic before/after measurements and verification

Analytic triangles reproduce the visible angle order and timing. These are **not original per-segment phone measurements**. Initial upper-arm and forearm projections are45px each at640x480; the rejected upper-arm projection is58.5px (+30%). Case A's forearm is49.97845px (+11.06322%); case B's is26.62200px (-40.83999%). Primary confidence is0.99, anchors remain fixed and world projection stays compatible. The old immediate-reset path was reproduced in an isolated ignored library mirror with only the new recovery branch disabled; app source was not rolled back.

|Analytic case, each anatomical side|Old immediate-reset count / partial|Corrected count / partial|Form score|
|---|---|---|---|
|A:68.24 -> rejected54.79 ->61.75 -> observed extension|0 /1|1 /0|Unavailable|
|B:82.68 -> rejected78.95 ->63.94 -> observed extension|0 /1|1 /0|Unavailable|
|Three consecutive recovered cycles|0 at first cycle before fix|3 /0; no duplicate on held TOP|Unavailable|

Initial regression run reproduced four incorrect READY resets, missing segment diagnostics and zero-count cycle loss. Independent review found a capture-fresh but delivery-late recovery counterexample; a new test failed, then passed after checking delivery time at recovery without assuming an intervening watchdog tick.

Fresh final checks: **699 complete pose tests pass** (20 new limb continuity cases); **105 affected Mobile tests pass**; scoped Dart analysis is clean. New tests cover both sides, sustained/mixed bad frames, actual elbow/wrist landmark swaps, missing BOTTOM, missing extension, rejected extension, large bottom-band motion, source change, capture/delivery timeout, pause/finish/watchdog, multiple cycles, unscored recovery and duplicate prevention. The complete pose suite also reruns previous portrait/landscape/world and other exercise regressions.

Final complete Mobile suite: **1,468 passed,21 skipped,16 failed**. Automatically extracted failure names exactly match the previous geometry-build run: twelve incomplete Firebase fake failures and four Member-shell timeouts listed in the historical broader-suite section below. This final full run used the reviewed delivery-time guard; the earlier full run is retained separately. No unrelated tests or app behavior were changed to hide these failures.

Android debug build with `GAINPATH_FLOOR_PUSH_UP_DEBUG=true`: **passed**. Stable artifact: `build/floor-push-up-limb-20261105/gainpath-floor-limb-debug.apk`, SHA-256 `B25C47376207ED595056F427F4C91F77B796D11655E7E809B53C66B586D91D77`. Previous app APK is preserved in that directory. No phone was connected (`adb devices -l` empty); no installation or native acceptance occurred. The source fix needs a physical retest with the new segment diagnostics, multiple complete/partial cycles and both capture sides. Synthetic test success is not physical accuracy validation.

### Exact files for this correction

```text
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/test/floor_push_up_limb_continuity_test.dart
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
docs/integration/standard-floor-push-up.md
AGENTS.md
README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/STATUS.md
docs/PROGRESS_REPORT.md
docs/SUPERVISOR_DEMO_GUIDE.md
```

Private video extracts, before/after JSON, RED/GREEN logs, library mirror and build evidence remain in ignored `build/floor-push-up-limb-20261105/`; source/artifact hashes and exact broader-suite failures are recorded in `verification.json` there.

## Portrait size and world-geometry correction — new debug recording

The new `Screenrecorder-2026-11-05-16-05-16-251.mp4` was independently inspected, including full frames and enlarged diagnostic panels. Its measured container is **1080×2400,605 frames,24.965 seconds** (approximately24.23fps). This is the recording's size, not a claim about the raw camera dimensions.

Visible evidence agrees with the reported geometry failures:

| Time | Visible diagnostic | Interpretation |
|---|---|---|
|4s|`healthy · right`,167.689°,`ready · stabilizingTop`|Pose and selected image-side geometry are accepted, but TOP hold is still being acquired|
|6s|`lost · right`,`ready · bodyTooSmall`|The geometry size gate rejects; green drawing is independently visible|
|8s|`healthy · right`,125.621°,`top · none`|TOP was acquired earlier. This particular sample is **not** BOTTOM:125.621°>105°|
|10,15,17s|`degraded · right`,`ready · bodyTooSmall`|Repeated size rejection resets acquisition/cycle credit|
|19s|`degraded · right`,`ready · contradictoryWorld`|The old instantaneous world veto rejects near the visually low position; the displayed null elbow is the cleared smoothing state, not evidence that MediaPipe supplied no elbow|

The supplied panel did not display raw camera width/height, size ratios, raw 2D/world angles or body-angle disagreement. Their exact original values cannot be reconstructed from the recording. `bodyTooSmall` establishes the source-derived bound `pixelBodyLength/imageHeight <0.30` on those frames, but not its precise ratio. The new build exposes all of these values; no phone was connected for a direct trace in this task.

### Confirmed normalization defect and measured before/after

The old angle coordinate system `(x×W/H,y)` is correct for aspect-corrected geometry. The bug was reusing its length in the **size gate**: it equals pixel distance divided by image height. Consequently the same physical body passes in landscape and fails in portrait.

Only that size gate now uses:

```text
bodyPixels = sqrt(((ankle.x-shoulder.x)×W)^2 + ((ankle.y-shoulder.y)×H)^2)
bodySizeRatio = bodyPixels / min(W,H)
accept size when bodySizeRatio >=0.30
```

Other angle, displacement, limb-ratio and anchor calculations keep their existing units. Upright source dimensions are used, not screen dimensions, device density or the covered/cropped preview. The camera adapter's upright rotation and preview-only mirroring remain unchanged.

The following are **measured deterministic camera-coordinate reproductions**, not invented values from the person's raw camera feed:

|Same pixel-coordinate fixture|Body pixels|Old height ratio / result|Corrected short-side ratio / result|
|---|---:|---|---|
|480×640 portrait,170° TOP|180.97395|0.28277<0.30 →reject|0.37703≥0.30 →accept|
|640×480 landscape,170° TOP|180.97395|0.37703 →accept|0.37703 →accept|
|480×640 portrait,90° BOTTOM|171.12410|0.26738<0.30 →reject|0.35651≥0.30 →accept|
|640×480 landscape,90° BOTTOM|171.12410|0.35651 →accept|0.35651 →accept|

The same ratios hold at4×camera resolution. A genuinely undersized body remains rejected in both orientations. The confidence, supported-view and anatomical plausibility gates remain active. This is a denominator correction, not a blanket relaxation of validation.

### World checks: projection, confidence and temporal reliability

The adapter rotates world x/y back from the model ROI and retains z. Orthogonal rotation/translation does not alter3D joint angles. The floor validator previously compared these **3D angles directly with2D projected angles**, and treated copied image visibility/presence as though it established depth reliability. The decoder in fact copies the image confidence into the world points; it is not independent confidence in inferred z.

The corrected validator measures both3D world angles and world-XY projected angles. A difference in inferred depth alone is classified unreliable and uses the existing **unscored2D counting fallback**. Missing/low-confidence/implausible world evidence likewise cannot replace missing required image landmarks or produce a form score.

Measured depth fixture at BOTTOM: image elbow **90.00°**, world-XY elbow **90.00°**,3D world elbow **33.73647°**. The old direct comparison saw56.26353°>25° and rejected as contradictory. The corrected comparison recognizes matching projections, permits independently valid2D counting and withholds the score.

A world veto remains possible when elbow or body angles disagree with the image in **both** spaces by>25°. The world-evidence policy qualifies the candidate only with:

- image and world primary confidence≥0.85 (still not described as independent depth confidence);
- at least3 samples spanning300ms, with capture gaps≤the existing250ms limit;
- image-relative angle residual changes≤12° and world body-length changes≤15%, against **both adjacent samples and the candidate window's anchor**;
- otherwise valid image geometry and plausible world geometry; only fresh capture observations contribute. Stale, frame-gap and camera/model-change frames reset qualification.

Before qualification, the candidate is pending and counting is2D-only/unscored. A stable strong contradiction remains rejected until evidence changes; it is not cleared merely by resetting the repetition phase. One measured strong-conflict fixture has image **90.00°** versus world3D/XY **7.38437°/7.38437°**: it is pending initially and rejected at300ms. A world scale growing10%per frame (77%across the candidate window) cannot qualify as stable. Independent review identified that cumulative-drift edge case; its failing regression was fixed using anchored window bounds.

These temporal constants are versioned development parameters in `FloorPushUpWorldEvidence`, not validated biomechanical standards. The geometry/tracking diagnostic revisions are `floor-short-side-v2`, `floor-geometry-recovery-v3` and `floor-world-projection-stability-v2`.

### Counting, score compatibility and unchanged contracts

TOP≥155°,BOTTOM≤105°, initial TOP hold300ms and phase dwell120ms are unchanged. Existing dropout/freshness checks remain. Validated BOTTOM frames now reach the state machine rather than being rejected solely by portrait height or unstable inferred depth. No synthetic interpolation supplies a missing BOTTOM. Both left/right portrait fixtures complete one observed TOP→BOTTOM→TOP cycle exactly once; shallow cycles remain partial, and a sustained reliable world contradiction invalidates credit.

Score formulas/weights, exercise ID, scoring version, metric schema7 and source compatibility ID are unchanged. To preserve their assessed-evidence contract, newly admitted size observations that fail the historical height-based score gate are **counted but unscored**; all world-fallback attempts are also unscored. Historical compatible landscape fixtures retain their existing v1 score. This avoids silently adding newly eligible observations to older scored progress groups. Review/calibration can explicitly authorize a future expanded scoring contract.

No Firebase data, backend policy, Module12 grouping, Module13 exclusion, Wall Push-Up or other exercise algorithm changed. Hash comparisons confirm the rule configuration, local score parser and backend/recommendation compatibility sources match the preceding implementation.

### Separate diagnostics and new Android build

The local debug panel now reports four separate stages: **Pose detected/missing; Painter accepted input points and frame timestamp; Geometry accepted/rejected with reason; Rep phase**. It also shows upright dimensions, pixel body length, height ratio, short-side ratio,0.30 threshold, raw2D/smoothed elbow,3D/projected world elbow and temporal world decision/sample count. `FloorPushUpGeometryObservation` retains detailed latest-only values for developer inspection. Painter invocation/input observation uses the existing diagnostic collector in observation-only mode, without drawing debug borders or changing normal skeleton filtering. No automatic trace/video persistence, production logging, Firebase write or telemetry was added.

The Android debug APK is built with `GAINPATH_FLOOR_PUSH_UP_DEBUG=true`; the normal UI and purple branding remain unchanged outside the opted-in panel. Stable output: `build/floor-push-up-geometry-20261105/gainpath-floor-geometry-debug.apk`. SHA-256: `E80D3EAF1A439BB0890B519420B475DCE3E591C8FCA32AE55A620883EDBABCBC`. The prior APK is preserved in the same ignored evidence directory. No installation or cloud operation occurred.

Fresh checks: **679 complete pose tests pass;150 affected Mobile tests pass (3 existing skips); scoped Dart analysis is clean; Android debug build passes.** Portrait/landscape, resolution invariance, both anatomical sides, world projection/depth, low-confidence world, transient/persistent contradictions, cumulative world drift, complete/shallow cycles, legacy score preservation, actual painter observation and existing exercise/voice/history/camera tests are covered. Fixtures are analytic; the supplied recording is real visual evidence. No raw trace was available for an exact same-recording landmark replay, and no left-side human recording was fabricated.

Full Mobile regression: **1,468 passed,21 skipped,16 failed**. Automatically extracted failure names exactly match the preceding run (the same twelve Firebase fake failures and four Member-shell timeouts listed below). The full run preceded the final freshness guard; the complete pose suite and150 affected Mobile tests were rerun after that guard. No unrelated failures were hidden or repaired. Detailed source hashes, measured fixture output, final build hash and test results are in `build/floor-push-up-geometry-20261105/verification.json`.

### Exact files for this correction

```text
packages/gainpath_pose/lib/gainpath_pose.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_geometry.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_world_evidence.dart
packages/gainpath_pose/test/floor_push_up_camera_geometry_test.dart
packages/gainpath_pose/test/support/floor_push_up_camera_fixture.dart
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
apps/mobile/lib/infrastructure/pose/pose_render_diagnostics.dart
apps/mobile/lib/features/workout/presentation/member/widgets/pose_landmark_painter.dart
apps/mobile/test/floor_push_up_render_observation_test.dart
docs/integration/standard-floor-push-up.md
AGENTS.md
README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/STATUS.md
docs/PROGRESS_REPORT.md
docs/SUPERVISOR_DEMO_GUIDE.md
```

The seven active operational references receive a checkpoint update. Private video extracts, measured fixture reports, failing/passing test logs, prior APK and build evidence stay in ignored `build/floor-push-up-geometry-20261105/`. The corrected build still requires a repeat on the phone: verify the new ratios/angles in the panel and confirm a visibly and measurably≤105° BOTTOM followed by≥155° TOP. This source fix is not a claim that the original125.62°sample was a valid BOTTOM or that physical-device accuracy is established.

## Tracking/readiness correction — 5 November 2026

The supplied screen recording was inspected at multiple points across its measured 19.751 seconds (475 frames, approximately 24.05 fps). It visibly shows an extended plank, intermittent green landmarks, the unchanged camera warning and a counter remaining at 0/8 through a candidate push-up. It does **not** contain original pose confidences, capture timestamps, world estimates or analyzer rejection reasons. No Android device was connected (`adb devices -l` returned an empty list). The exact internal rejection and angle sequence for that recording cannot be reconstructed honestly from the composited preview.

### Confirmed source defects and before/after reproduction

These failures were reproduced with deterministic input and failing tests before the fixes. They are sufficient causes of failed readiness/counting; they are not claims that the recording uniquely proves each one occurred on the phone.

| Reproducible input/condition | Before | After |
|---|---|---|
| Fresh frames every 150 ms, each delivered with 200 ms inference latency; 100 ms watchdog tick | Watchdog treated capture age as delivery silence: capture age reached 300 ms between fresh results; TOP could never remain acquired | Freshness is still checked at delivery, capture gaps still checked between captures; watchdog times absence of accepted deliveries. Stable TOP is acquired |
| 170° TOP, then one 50 ms elbow confidence sample at 0.60 against the unchanged 0.65 gate, then matching visible TOP | One rejected frame cleared readiness and cycle state | Reject the sample for measurement, preserve only compatible fresh endpoints within 250 ms; maintain/acquire TOP, then a fully observed cycle counts once |
| Early left candidate becomes low-confidence or has unusable high-confidence geometry, while right is usable before TOP | Candidate remained selected indefinitely, blocking calibration | Reevaluate an unusable candidate before the first TOP; lock the side only after TOP acquisition. Do not switch sides during a repetition or later in the capture |
| Sound 2D geometry with incomplete/low-confidence optional world points | Nonempty-but-unusable world map categorically rejected the pose | Explicit 2D tracking fallback; any affected attempt/session has **null form score**. Confident contradictory world estimates still reject |
| Different rejection reasons: missing pose, hidden elbow, small body, wrong view, stale frame, moved anchors | Same generic camera-position warning; no reason data | Typed reasons, matching short actions, latest-only developer diagnostics, bounded feedback stability |

The watchdog also preserves a current specific rejection when rejected results are arriving; it does not replace it with a generic timeout merely because no pose has yet been accepted. Manual reset/return to calibration clears any previous Ready message.

### Measurements and limits

The following measured values are from the **analytic regression fixture**, not the person's recording:

- Primary elbow visibility/presence **0.60**, other primary joints **0.99**, pose presence **0.99** → `lowLandmarkConfidence`; the rejection threshold remains **0.65**.
- Consistent fixture: 2D/world elbow **90°/90°**, body angle **180°**, body length **0.6844964** image-height units, slope **0.3300899**, shoulder/body ratio **0.0372465** → accepted.
- Same image geometry with confident contradictory world elbow **7.38437°** versus image **90°** → `contradictoryWorld`; disagreement exceeds the unchanged **25°** limit and remains rejected.
- Sustained confidence loss beyond **250 ms**, or a meaningful movement/threshold crossing hidden by a short loss, clears cycle credit and requires fresh TOP. A short loss cannot invent BOTTOM or arm extension. Recovered BOTTOM must still be visibly compatible; missing samples do not supply bottom/return/reversal dwell. Uncertain in-attempt movement leaves the score null.

No numeric camera-position gate, ROM threshold or scoring weight was loosened: TOP 155°, BOTTOM 105°, leave-TOP 145°, initial hold 300 ms, phase dwell 120 ms, frame-age/capture-gap bound 250 ms, primary confidence 0.65, body length 0.30, shoulder/body ratio 0.35, slope 0.65 and reliable-world disagreement 25° remain as listed below. Optional-world fallback is confidence-aware and unscored. Existing assessed-score formulas and score/source/schema identifiers are unchanged; the internal diagnostic tracking revision is `floor-tracking-recovery-v2`. This change does not authorize comparing newly unscored observations as scored ones.

### Why skeleton appearance is separate

Source inspection confirms floor validation does **not** hide or remove the green overlay. The preview receives refined poses independently of the floor result. The overlay can be absent because the detector returns an empty pose, visible joints fail the painter's 0.5 gate, processing results exceed the scheduler's 250 ms freshness limit, the preview watchdog clears an old overlay, or preview/analysis aspect ratios differ by at least 0.02. The decoder distinguishes no-person/low-pose-presence/ROI outcomes through existing quality diagnostics. None can be assigned as the recording's unique cause without its original runtime diagnostics. No shared detector, camera orientation, preview freshness or painter safety behavior was disabled to conceal the symptom.

### Developer diagnostics and UI

`FloorPushUpRejection` and `FloorPushUpGeometryObservation` distinguish no pose, image/mirror invalidity, missing/out-of-frame/low-confidence joints, scale, projected arm/body geometry, side view, hands/knee setup, world reliability/contradiction, freshness/gaps, geometry/model changes, limb/anchor drift and top acquisition. Diagnostics include the latest confidence/presence values, selected side/lock, image dimensions/mirror flag, raw 2D and available world angles, body line features, anchor drift, smoothed angle, phase/dwell, reset reason, accepted capture/delivery times and counts. The session adds current camera rotation/preview mapping, detector timing and processed/dropped/stale/empty/expired-overlay counters from the existing pipeline.

The data is latest-only, in memory. There is no production print/log, trace retention, automatic file/video capture, Firebase write, Analytics or telemetry. A developer may explicitly inspect `session.localDiagnostics` or supply the debug-only `onLocalDiagnostics` callback. No callback is installed in the normal route.

For an opt-in compact local overlay, build/run with:

```text
flutter run --dart-define=GAINPATH_FLOOR_PUSH_UP_DEBUG=true
```

The overlay shows tracking state, side, smoothed elbow, rep phase and rejection reason; release builds exclude it. Normal UI uses exercise-owned actionable feedback and briefly retains the last supported label only within the bounded dropout policy. Other exercises keep their existing readiness path. Floor-only voice arbitration uses a **6-second** per-cue cooldown; shared audio policy is unchanged.

### Exact correction files and verification

```text
packages/gainpath_pose/lib/gainpath_pose.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_diagnostics.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_geometry.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/test/floor_push_up_recovery_test.dart
apps/mobile/lib/features/workout/application/floor_push_up_workout_session.dart
apps/mobile/lib/features/workout/application/measured_workout_session.dart
apps/mobile/lib/features/workout/presentation/member/real_workout_view.dart
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
apps/mobile/test/floor_push_up_workout_session_test.dart
```

This report and the seven current operational references also receive checkpoint updates. No backend, Admin, Wall Push-Up, catalog identity, history schema or Module 13 code changed for this correction.

Fresh **665 full pose tests pass**, **146 affected Mobile tests pass** (3 preexisting skips), scoped Dart analysis has no issues, and the Android debug APK builds successfully. The new Flutter test renders the actual workout view, verifies that accepted TOP clears the warning, preserves feedback through a short rejected sample, observes a fully measured repetition reaching **1 / 8**, and verifies no repeated tracking speech within 3.2 seconds. Fifteen new recovery tests include left/right top, short/long drops, missing/unreliable world, strict hidden-depth rejection, BOTTOM recovery, side candidates, latency, current no-pose feedback and manual-reset messaging. Existing contradictory-world, shallow/incomplete, orientation and other-exercise tests remain passing.

Independent read-only review identified a remaining high-confidence-but-unusable candidate lock; its regression failed, the condition was corrected and the final full pose suite includes it. Review did not establish physical counting accuracy or the original clip's exact rejection.

Private evidence and test/build logs are in ignored `build/floor-push-up-debug-20261105/`; screen-recording extracts are kept out of source and public reports. The previous APK is retained there. No cloud operation or device installation occurred. The corrected build still needs a repeat on the original phone/camera setup with developer diagnostics to identify any remaining geometry/confidence/model limitation. Do not claim that the original clip has been recounted from raw input or that native accuracy is validated.

**Fresh complete Mobile run:** 1,467 passed,21 skipped,16 failed. The16 failure names exactly match the preceding implementation run: contact/photo Firebase fakes throw `UnimplementedError: collection`, and the same four Member-shell flows time out in `pumpAndSettle`. Exact names remain listed in section9 below. No new failing case appeared. The passing146-test affected run is separate from this non-green full-suite result.

The original implementation record below remains historical where superseded by this correction.

## 1. Exact files changed

All paths below are relative to that repository. This is the task's manifest, not a list of every dirty file in the checkout.

Pose engine and replay support:

```text
packages/gainpath_pose/lib/gainpath_pose.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_rules.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_geometry.dart
packages/gainpath_pose/lib/src/floor_push_up/floor_push_up_analyzer.dart
packages/gainpath_pose/test/floor_push_up_analyzer_test.dart
packages/gainpath_pose/test/floor_push_up_fixture_evaluator_test.dart
packages/gainpath_pose/test/support/floor_push_up_trajectory.dart
packages/gainpath_pose/tool/floor_push_up_fixture_evaluator.dart
packages/gainpath_pose/tool/evaluate_floor_push_up_fixture.dart
packages/gainpath_domain/lib/src/workout/exercise_tracking.dart
```

Existing Mobile composition and new exercise:

```text
apps/mobile/lib/app/routing/floor_push_up_workout_route.dart
apps/mobile/lib/app/routing/exercise_tracker_route.dart
apps/mobile/lib/app/routing/routine_journey_route.dart
apps/mobile/lib/features/workout/application/floor_push_up_workout_session.dart
apps/mobile/lib/features/workout/domain/floor_push_up_catalog.dart
apps/mobile/lib/features/workout/domain/floor_push_up_metrics.dart
apps/mobile/lib/features/workout/domain/exercise_tracker_dispatcher.dart
apps/mobile/lib/features/workout/domain/workout_pose_metrics.dart
apps/mobile/lib/features/workout/domain/workout_contracts.dart
apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart
apps/mobile/lib/features/workout/presentation/member/workout_result_screen.dart
apps/mobile/lib/features/analytics/domain/member_workout_report.dart
apps/mobile/lib/infrastructure/firebase/firebase_workout_backup_gateway.dart
apps/mobile/test/floor_push_up_workout_session_test.dart
apps/mobile/test/support/floor_push_up_trajectory.dart
apps/mobile/test/firebase_workout_backup_negotiation_test.dart
```

Backend descriptive compatibility and recommendation exclusion:

```text
functions/src/modules/workouts/floor-push-up-validation.ts
functions/src/modules/workouts/workout-backup-validation.ts
functions/src/modules/workouts/workout-backup.ts
functions/src/modules/recommendation/workout-evidence.ts
functions/test/floor-push-up-contract.test.ts
functions/test/workout-backup-negotiation.test.ts
```

Documentation:

```text
docs/superpowers/plans/2026-11-05-standard-floor-push-up.md
docs/integration/standard-floor-push-up.md
AGENTS.md
README.md
docs/ARCHITECTURE.md
docs/OPERATIONS.md
docs/STATUS.md
docs/PROGRESS_REPORT.md
docs/SUPERVISOR_DEMO_GUIDE.md
```

No Wall Push-Up analyzer or session implementation was rewritten. The existing pose adapters, camera preview, voice controller/arbiter, guided sets/rest, measured workout view, account lifecycle, local repository and progress/report aggregation are reused.

## 2. Selection and camera directions

- Stable exercise ID: `standard-floor-push-up-side-v1`.
- Installed tracker: `standard_floor_push_up_side_v1`.
- Separate Wall Push-Up ID remains `wall-push-up-side-v1`.
- V1 supports **Left Side View** and **Right Side View**. The near usable side is selected from confidence and locked for the capture. Switching sides requires a new capture.
- Workout → Workout tools → **Standard Floor Push-Up** opens local practice through the existing consent/setup gate and tracker route. The authored practice target is 3 sets × 8 repetitions, with 60 seconds rest and the existing session rest controls.
- This is an explicitly local practice entry, available to the existing `gainpath` Member composition. It is not a fabricated published routine or a Firebase-error fallback. A future genuinely authored routine using the exact ID uses the same dispatcher, setup instructions and tracker. No remote Admin catalog record or published routine was created.
- Setup requests a stable, level camera near floor height, a full-body side view, a clear near elbow, and visible shoulder through ankle. Consent and recalibration instructions describe the floor setup. The original purple `Panel`, buttons and workout view remain.

## 3. Landmark and angle calculations

The existing canonical landmark enum follows the 33-landmark MediaPipe ordering:

| Feature | Left | Right |
|---|---:|---:|
| Shoulder | 11 | 12 |
| Elbow | 13 | 14 |
| Wrist | 15 | 16 |
| Hip | 23 | 24 |
| Knee, supplementary | 25 | 26 |
| Ankle | 27 | 28 |

Primary selected-side visibility/presence is the minimum across shoulder, elbow, wrist, hip and ankle, together with pose presence. Missing, nonfinite, out-of-frame, mirrored or low-confidence primary image points are rejected. The opposite shoulder supplies a conservative side-view projection check. A reliable knee adds a hip–knee–ankle straight-leg sanity check; an absent knee does not substitute for a missing ankle or prevent otherwise supported measurement.

Image geometry uses `(x × imageWidth/imageHeight, y)` so distances and angles have equal axis scale. Normalized image z is not treated as metric depth.

- Elbow angle: angle between shoulder−elbow and wrist−elbow.
- Body angle: shoulder–hip–ankle angle, exposed in the geometry snapshot.
- Signed hip displacement: perpendicular hip offset from the shoulder–ankle line divided by shoulder–ankle length. The normal points image-down for either facing direction: positive means sagging, negative means piking. Equivalent formula: `cross(ankle−shoulder, hip−shoulder) × sign(ankle.x−shoulder.x) / bodyLength²`.
- Body slope, shoulder separation/body length, limb lengths, wrist/ankle anchor drift, smoothed angular speed, phase and tracking status are also measured.
- Available world landmarks are separately checked in metres: finite points, usable confidence, plausible body length, 3D elbow/body angles and agreement with the image projection. World data cannot rescue an occluded image elbow. Reliable contradictory world data rejects the observation; incomplete/low-confidence optional world data permits 2D tracking with no form score. Absent world data allows the defined 2D source contract.

Coordinate semantics were checked against [MediaPipe's official output documentation](https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/pose.md). That documentation does not validate this exercise's thresholds or scores.

## 4. Final configurable development parameters

These are **provisional implementation defaults**, not calibrated population standards. `FloorPushUpRules` validates configuration; changing a default under the same scoring version is rejected. New parameter sets require a new version and explicit persistence/source support before use in production summaries.

| Parameter | Default |
|---|---:|
| TOP / BOTTOM elbow thresholds | ≥155° / ≤105° |
| Leave TOP threshold | ≤145° |
| Reversal hysteresis | 8° |
| Minimum observed excursion from actual starting top | 25° |
| Initial stable top hold | 300 ms |
| Phase/return/reversal dwell | 120 ms |
| Minimum attempt duration | 900 ms |
| Minimum observed lowering/return duration | 150 ms |
| Maximum attempt duration | 60 s |
| Maximum frame age / capture gap | 250 ms |
| Primary minimum visibility/presence | 0.65 |
| Maximum absolute body slope | 0.65 |
| Maximum shoulder separation/body length | 0.35 |
| Minimum projected body length, image-height units | 0.30 |
| Hip displacement tolerance / zero-alignment-score endpoint | 0.045 / 0.14 body lengths |
| Maximum 2D/world elbow and body angle disagreement | 25° |
| Angular-speed control penalty endpoint | 500°/s; penalty begins at 250°/s |
| Maximum projected limb-length change | 25% |
| Maximum wrist/ankle drift | 0.18 baseline body lengths |
| One Euro filter min cutoff / beta | 3 Hz / 0.015 |
| ROM / alignment / control / extension weights | 40% / 35% / 15% / 10% |

The source version additionally fixes basic projection sanity guards: opposite shoulder confidence ≥0.35; reliable supplementary knee angle ≥125°; wrist below shoulder by >0.05 body lengths; arm segments between 0.08 and 0.65 body lengths; hip projection within 15–85% of the body line; world body length 0.25–3 metres. These are source sanity limits, not clinical form standards.

## 5. Rep-counting state machine

`READY → TOP → DESCENDING → BOTTOM → ASCENDING → TOP`

READY requires a fresh stable extended floor plank. TOP departure uses a separate 145° threshold and dwell. BOTTOM requires a smoothed ≤105° observation held for the dwell period. A sustained extension starts ASCENDING. A full count is emitted once only on a stable ≥155° return with valid bottom credit and sufficient observed timing.

A shallow return produces a partial with insufficient-descent feedback. A renewed descent before full extension finalizes an incomplete attempt and clears bottom credit, even when the short ascent stayed below 130°. A small excursion is ignored consistently on normal return, pause, finish and tracking interruption. Repeated TOP frames cannot duplicate a count.

Visibility loss, stale frames, large gaps, changing image geometry/model, background/pause/rest and explicit recalibration cannot bridge an unfinished cycle. A meaningful interrupted attempt becomes one unscored partial and requires a fresh TOP. Duplicate/out-of-order/future timestamps cannot advance the state. Slow repetitions and held bottoms remain possible up to the configurable attempt timeout.

## 6. Form scoring

Counting validity and form quality are separate: measurable sagging/piking does not invalidate an otherwise complete depth/extension cycle.

- **ROM, 40%:** minimum smoothed elbow angle; 100 at/below 105°, linear loss over the next 50°.
- **Body alignment, 35%:** maximum absolute normalized hip displacement; no penalty through 0.045, linear loss to zero at 0.14. The geometry also exposes the body angle.
- **Movement control, 15%:** observed timing and peak smoothed angular speed; too-fast attempts receive zero control, and speed penalty rises from 250 to 500°/s.
- **Arm extension, 10%:** full credit for a valid top return; incomplete returns lose four points per degree below 155°.

Completed assessable attempts contribute component means. No attempt means no score. A meaningful tracking-interrupted attempt makes the session's aggregate form components/score null, including when earlier attempts were scored; this intentionally avoids treating unseen movement as assessed. Counts and tracking durations remain available. Legacy `accuracy` is only the bounded storage representation; UI calls the measure estimated form.

Independently retained findings: insufficient descent, hip sagging, hip piking, incomplete extension, unstable tracking, interruption and too-fast movement. There is no elbow-flare rule, load estimate, force estimate, symmetry score or floor-contact detector.

## 7. Voice feedback

| Observation | Cue | Priority |
|---|---|---|
| Shallow completed attempt | Lower your chest a little more. | Correction |
| Positive hip displacement | Keep your hips aligned. | Correction |
| Negative hip displacement | Lower your hips slightly. | Correction |
| Incomplete return/reversed ascent | Extend your arms fully. | Correction |
| Unusable tracking/view | Adjust your camera position. | Warning |
| Complete attempt without observed findings | Good repetition. | Encouragement |

The existing `WorkoutAudioController`/`AudioCueArbiter` enforces the two-second per-cue cooldown, warning > correction > encouragement priority, current-frame requests, voice preferences, alerts-only/muted behavior, playback cancellation and account/foreground lifecycle. Tracking warnings also run from the camera timeout tick. Voice is not enabled automatically.

## 8. Summary, history, progress, Module 12 and Module 13

- The measured session implements the existing `MeasuredWorkoutSession` view and guided sets/rest contract, validates active account/model/consent, and retries the identical summary after local save failure.
- Pose metrics schema **7** contains selected side, source compatibility `floor-push-up-2d-crosscheck-v1`, component means, finding counts and scoring version `standard-floor-push-up-side-v1`. No video or per-frame data is persisted.
- Local practice has no invented `publishedRoutineId`. Existing genuinely published captures keep their routine linkage.
- Completion details show the floor-specific heading, side, components, partials and findings. The existing saved-session entry is labeled **Saved workout sessions**. Existing account-scoped history/progress/report mapping accepts schema 7 and provides the readable floor exercise name.
- Compatibility grouping already includes exact exercise/rule/detector/model/view. Floor and Wall Push-Up scores cannot share a group. The source version is strictly validated for schema 7.
- Optional, separately enabled provisional backup and Module 12 descriptive reporting accept schema 7 in the updated source. Counts/activity are descriptive; missing scores remain missing. Old clients negotiate lower schemas and skip floor records/routines without losing cursor progress. New clients advertise schema 7.
- **Deployment ordering:** matching backup/reporting backend source must be released before distributing the new Mobile build for cloud backup. The currently running backend was not changed by this task. Local counting/history work independently; this report does not claim that the deployed service already accepts schema 7.
- Verified workout upload/acceptance and rewards stay unavailable. **Module 13 automatic recommendation eligibility stays disabled**: floor evidence explicitly has no compatibility, no learning-need exercise mapping or reviewed threshold policy, and never inherits Wall Push-Up thresholds. Module 12 descriptive support does not grant recommendation eligibility.

## 9. Test and build results

Fresh verification in this task:

| Check | Result |
|---|---|
| Complete pure-Dart pose suite | **650 passed** |
| Complete shared domain suite | **188 passed** |
| Affected Mobile sessions/routing/persistence/analytics/routine/UI regressions | **113 passed** |
| Affected backend backup/reporting/evidence/recommendation boundaries | **205 passed** |
| Scoped Dart analysis | **No issues** |
| TypeScript source + test no-emit compilation | **Passed** |
| Android debug APK | **Built**, exit 0; Kotlin daemon retried successfully |
| Complete Mobile suite | 1,466 passed, 21 skipped, **16 failed** outside floor test cases |
| Complete backend suite with localhost socket access | 2,002 passed, **2 failed** |
| Whole-repository architecture checker | **13 existing external test-support imports reported**; no floor path remains in findings |

The complete suites are not green; see the exact remaining failures below. The first attempted pose run used Flutter's runner, causing the existing Dart CLI tests to time out; rerunning with the package's actual Dart runner passes. The first backend run was sandbox-blocked on loopback sockets; the final socket-capable run above resolves those transport failures. A focused Mobile command initially named three nonexistent session test files; its corrected final run is the 113-pass result above. These earlier unsuccessful commands are not counted as passes.

New deterministic tests cover correct, shallow, incomplete-extension, sagging, piking, slow, fast transient, held-bottom, occluded elbow, lost tracking, wrong view, both sides and facing directions, partial/interrupted cycles, tiny departures, below-130° reversed ascents, duplicate/stale clocks, model/dimension changes, configurable depth, invalid weights, 2D/world agreement/disagreement, normalized aspect behavior, supplementary knee absence, voice priority/cooldown, consent, local selection and same-result history/save retry.

The timestamped JSON replay evaluator and actual CLI test compare counts and finding aggregates with explicitly supplied reference labels, return signed/absolute rep errors and form-rule disagreements, and reject malformed data. The synthetic correct replay has reference error 0 and no form-rule disagreements; a deliberately changed reference produces error −1 and nonzero exit. Those numbers describe that analytic fixture only.

Run from the repository root:

```text
dart run packages/gainpath_pose/tool/evaluate_floor_push_up_fixture.dart <fixture.json>
```

The version-1 fixture includes `caseId`, `evidenceKind` (`synthetic_landmarks` or `annotated_video`), nullable `videoId`/`annotator`, detector identifiers, `reference` (`repetitions`, `partialRepetitions`, `issueCounts`) and timestamped `frames`. Frames retain upright dimensions, mirrored flag, pose presence, named image landmarks and named world landmarks, each with x/y/z/visibility/presence. Annotated-video inputs require nonempty video/annotator metadata. Limits are 16 MiB/20,000 frames. This local evaluation tool never writes workout history or enables upload/recommendations.

Independent review found two important edge cases (below-130° ascent reversal and tiny interrupted departures); both were reproduced with failing tests, fixed and included in the final full pose pass. Real-camera accuracy, native performance, deployment behavior and unrelated dirty changes were outside that review's evidence.

Evidence logs are under `build/floor-push-up-*.log` and `build/floor-push-up/android-build.log`. The two previous APKs were retained under `build/floor-push-up/`. New APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `4FF04B4BB2229130C44DC6DDD39016692EFFABCF9D6191D257DFE34922192B99`.

### Remaining broader-suite failures

The following automatically extracted names and causes are completed below; they are not hidden by the focused pass. No unrelated Firebase fixture, release package or emulator routing implementation was changed to make this feature's report green.

Mobile failures (16):

- `coach_availability_flow_test.dart: Member directory opens schedule by stable Coach ID and logout hides the pushed schedule` — existing Member-shell `pumpAndSettle` timeout.
- `member_contact_details_repository_test.dart: display name saves both existing identity names and preserves contacts and private photo` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: display name rejects stale and forged baselines plus blank, control and oversize values` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: display name membership or session drift never commits either identity field` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: optional contact details save, reopen, replace and clear without touching photo or other fields` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: stale baseline rejects write and remains aborted if transaction retries against original` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: foreign repository baseline, oversized text and control characters never write` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: session loss during load stays invalid; email and membership drift prevent writes` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_contact_details_repository_test.dart: wrong role, inactive and mismatched organization deny reads` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_photo_gateway_test.dart: transaction updates only own photo and timestamp` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_photo_gateway_test.dart: stale first transaction abort remains sticky when retry sees original again` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_photo_gateway_test.dart: membership change aborts the transaction and invalidates future reads` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_photo_gateway_test.dart: session loss during read and Auth email drift reject stale results` — incomplete Firebase fake (`UnimplementedError: collection`).
- `member_equipment_test.dart: Firebase Member Home Equipment entry opens scoped browsing without recording activity` — existing Member-shell `pumpAndSettle` timeout.
- `member_local_progress_flow_test.dart: Firebase Home and Profile share measured local history; refresh and account switch remain truthful` — existing Member-shell `pumpAndSettle` timeout.
- `workout_backup_integration_test.dart: full member shell backs up saves without visiting Progress and respects opt-out` — existing Member-shell `pumpAndSettle` timeout.

Backend failures (2):

- `test/emulator-suites.test.ts — routes every fixed-port test to an emulator that actually exposes that port`: the existing FYP cohort test uses port 18231 absent from its selected runner configuration.
- `test/fyp-live-package.test.ts — Node22 exact release package exports only the two callable endpoints and retains enforced App Check source`: the expected prior FYP release-package artifact is absent. This task did not recreate or release that package.

Architecture checker findings (13):

- `apps/admin_web/test/business_dashboard_test.dart:26: relative directive escapes package (../../../test_support/fyp_render_support.dart)`
- `apps/admin_web/test/emulator/fyp_ordinary_admin_emulator_test.dart:16: relative directive escapes package (../../../../test_support/fyp_emulator_gateway.dart)`
- `apps/admin_web/test/emulator/fyp_ordinary_admin_emulator_test.dart:17: relative directive escapes package (../../../../test_support/fyp_render_support.dart)`
- `apps/admin_web/test/emulator/fyp_ordinary_admin_emulator_test.dart:18: relative directive escapes package (../../../../test_support/fyp_widget_waits.dart)`
- `apps/admin_web/test/emulator/fyp_ordinary_admin_emulator_test.dart:19: relative directive escapes package (../../../mobile/test/support/signed_out_firebase.dart)`
- `apps/admin_web/test/emulator/unified_ordinary_admin_test.dart:17: relative directive escapes package (../../../../test_support/fyp_emulator_gateway.dart)`
- `apps/admin_web/test/emulator/unified_ordinary_admin_test.dart:18: relative directive escapes package (../../../../test_support/fyp_render_support.dart)`
- `apps/admin_web/test/emulator/unified_ordinary_admin_test.dart:19: relative directive escapes package (../../../../test_support/fyp_widget_waits.dart)`
- `apps/admin_web/test/emulator/unified_ordinary_admin_test.dart:20: relative directive escapes package (../../../mobile/test/support/signed_out_firebase.dart)`
- `apps/admin_web/test/fyp_offline_fonts_test.dart:5: relative directive escapes package (../../../test_support/fyp_render_support.dart)`
- `apps/mobile/test/emulator/fyp_ordinary_member_emulator_test.dart:22: relative directive escapes package (../../../../test_support/fyp_emulator_gateway.dart)`
- `apps/mobile/test/emulator/fyp_ordinary_member_emulator_test.dart:23: relative directive escapes package (../../../../test_support/fyp_render_support.dart)`
- `apps/mobile/test/emulator/fyp_ordinary_member_emulator_test.dart:24: relative directive escapes package (../../../../test_support/fyp_widget_waits.dart)`

## 10. Accuracy and calibration limitations

No annotated Standard Floor Push-Up videos were found in the inspected repository fixtures. No real-video count-error rate, human form-rule agreement, sensitivity/specificity or biomechanical accuracy was measured. Synthetic landmark/replay success is not an accuracy claim.

Next calibration requires consented annotated recordings from both camera sides and multiple participants, camera distances/heights, lighting/occlusion conditions and movement speeds. Label full/partial/interrupted cycles and independently observable faults, compare evaluator count errors and rule disagreements, select parameters on a development subset and report held-out results separately. Version any changed rules and review source compatibility before comparing scores.

The side-view proxy cannot establish elbow flare, force/load, palm/toe floor contact, bilateral symmetry or full 3D alignment. Conservative opposite-shoulder/world/anchor checks may reject otherwise usable real recordings; their behavior must be measured rather than assumed. Image-down sag/pike interpretation requires the instructed level camera. Knee-supported variants are not supported exercises. Native camera performance, detector quality and voice playback still need physical-device acceptance. No new deployment, remote exercise catalog publication or recommendation policy review is implied by the local build.
