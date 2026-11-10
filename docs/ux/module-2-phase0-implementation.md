# Module 2 Phase 0 — Privacy, authorization and baseline

Date: 10 November 2026 (Asia/Kuala_Lumpur).

## Scope

The primary AI optimization scope is **Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press**. The diagnostic exercise enum contains exactly these six; it is not a catalog eligibility list.

Reverse Lunge, Dumbbell Row and Wall Push-up are legacy retirement candidates. Phase 0 does not delete or hide their trackers, rewrite history, withdraw catalog items or change published routines/enrollments. Wall Push-up consent remains regression-tested. Timed/video and manual execution stay unchanged.

Before a separate retirement action: inventory all exact exercise IDs/aliases, active/inactive catalog visibility, all published/draft routine versions and Program references, enrolled plan snapshots, pending/resumable attempts and historical scoring contracts. Decide a future-selection policy and replacement/migration path without relabeling historical records. Test old versions/history/backup restore, complete a dry-run inventory and review concrete withdrawal changes before applying them. No live catalog/backend was queried or mutated in this phase.

## Implemented privacy boundary

Preview now reuses persistent versioned organization/account-scoped AI consent and the existing `WorkoutAiConsentGuard`. The launcher pins its original account, observes authorization loss and uses the same `_CaptureLaunchLease` as measured launch. Interrupted or A→B→A intents cannot revive after a privacy sheet/async preference lookup.

`PosePreviewRoute` verifies consent before creating camera/model resources; its active-scope callback checks the current Member role, account, lifecycle authorization and consent. Withdrawal, logout, account switch or same-scope role revocation latch the route closed and synchronously invalidate controller/camera generations. Initialization results arriving later are discarded/disposed. Backgrounding during initial preferences/model/camera startup invalidates that launch; a working authorized preview retains the existing background/pause/resume behavior. A revoked preview never restarts after regrant; authorized users can leave and reopen. OS permission checks and permission-denial/retry behavior remain in `AndroidPoseCamera`.

Hardware-free controller/viewport seams allow route regression tests without opening a real camera. Four consent fixtures now inject authenticated `AuthBloc` and account-scoped preferences, test both first-time and accepted consent, assert disabled acceptance until agreement/setup, and retain the no-upload control checks. No consent check was removed to pass a test.

## Reusable instrumentation

Enable explicitly with `--dart-define=GAINPATH_WORKOUT_BASELINE=true` in a local debug/profile build. Default/release route composition does not create the recorder, timer, trace or RSS sampler. Existing independent debug diagnostics are unchanged.

`WorkoutPerformanceDiagnostics` retains at most300 scalar samples per fixed metric (configurable1–1000),64 ephemeral audio correlations, a fixed counter/resource vocabulary and at most1000 summary emissions. Snapshots contain only an allowlisted exercise enum, durations/counts, histograms, RSS and resource counts. They contain no camera buffers, landmarks, pose histories, user/organization/document IDs, message text or request IDs. Nothing is uploaded or persisted automatically. Audio trace request keys are bounded in memory and never included in baseline output. An output-sink exception cannot change a workout decision.

`WorkoutBaselineBinding` observes the existing session/preview and attaches the existing audio trace; all six retained route factories share this composition. Camera/detector/audio adapters report lifecycle and timing. Instrumentation does not alter frame admission, latest-frame policy, inference models, calibration, rep thresholds, speech deadlines/priority/cooldowns or persistence. Ordinary traced speech adds correlation only; it retains the ordinary playback policy. Native scalar audio trace supports profile as well as debug when explicitly requested by the Dart adapter.

| Metric/output | Exact boundary and limits |
|---|---|
| `cameraStartupMicros` | Camera start through enumeration/initialize; excludes later texture presentation, sensor exposure and stream-to-first-preview delay |
| `modelStartupMicros` | Bundled asset verification, worker/native initialization through ready; includes configured GPU preference/fallback |
| `inferenceMicros`, `workerMicros`, `hostProcessingMicros` | Existing native stage sum, worker pipeline and host detect roundtrip; no invented latency values |
| Delivered/dropped/stale counters and `deliveryAgeMicros` | Existing scheduler callbacks; input timestamp is after camera plane copy, not sensor exposure |
| `acceptedFrames/Fps` and delivery gap | Unique delivered pose with current session analysis available, healthy and calibrated, during active working time; rest/pause excluded. This is an analysis-readiness snapshot proxy, not a clinical accuracy or camera-preview-FPS measure |
| TTS init | Existing prepare requested/completed on the same route Dart clock; missing/failed engines still use existing outcomes |
| Rep/event→voice callback | Existing observation/event to Dart receipt of native `onStart`; outcome cue IDs classified privately, only numeric aggregate emitted. Native request→start subtracts native timestamps only. Bluetooth/acoustic latency is not measured |
| Transitions | Route recorder creation to initialized camera/first assessable snapshot; includes user setup/IO/calibration wait. Profile detailed sub-stages separately before attributing delay |
| Memory/resources | Process RSS every5s when supported; initialized camera/detector/TTS ownership counts and closure reports. RSS is not Dart heap, native-allocation attribution or proof of a leak |

Percentile fields are explicitly **recent** retained-sample p50/p95; `mean`/`count` cover all observed samples. Do not mix those windows or compare differently configured diagnostic runs. `WORKOUT_BASELINE` lines are scalar local console output; retain private logs outside source control.

## Exact remaining physical baseline procedure

No phone was touched, app launched, APK installed, or physical latency/FPS/memory/battery result recorded for Phase 0.

1. Confirm target phone is safely idle with no unsaved workout/game. Record app/build hash, signer/data-preservation plan, model/Android/SoC, camera/lens/resolution/refresh, TTS engine/offline voice, brightness, battery and thermal state. Preserve existing APK/data before any later authorized installation. Do not clear or uninstall.
2. Build/run the reviewed profile variant with the baseline define only after safe-state confirmation. Example in `apps/mobile`: `flutter run --profile --dart-define=GAINPATH_WORKOUT_BASELINE=true`. This command launches/updates the device, so it is a future procedure, not a command executed by Phase 0. Keep optional CPU/GPU shadow and joint/image diagnostics off for ordinary baseline runs.
3. Record20 cold/30 warm camera opens, at least1000 processed frames per retained exercise, neutral-calibration duration separately, and loss/reacquisition/2–3m/front/side/floor conditions. Capture average/p95 native/worker/host age, accepted FPS/gaps and discarded/stale denominators. Use identical labeled motion and camera setup for before/after comparisons.
4. Capture at least100 supported outcome/correction events, cold/warm TTS, speaker/wired/Bluetooth/music/focus interruption and mute. Correlate the existing event→native callbacks; use an external acoustic/video reference for audible latency. Report expired/dropped/unavailable counts alongside p95, not only successful starts.
5. Use Flutter DevTools profile CPU/frame timelines and `FrameTiming` for UI/raster jank. Android System Trace/Perfetto and memory profiler or `adb shell dumpsys meminfo com.zyang.gainpath` distinguish native/GPU/Java/Dart use; RSS alone cannot. Use supported power/thermal gauges, not assumed Pixel-only power rails on Xiaomi.
6. Run a45–60min mixed six-exercise soak and30 same/different-view transitions, with normal rest, interruption, offline and safe process-recovery scenarios. Log resource closure/RSS and latency in5min buckets; confirm local-first results/checkpoint reconciliation and no duplicate activity. No unsafe exercise movement is required to test failure states.
7. Repeat key user-perceived/audio/power cases with the ordinary release configuration. Instrumentation overhead and debug behavior are not production performance claims. Use the audit's benchmark table as proposed targets, not achieved results.

## Verification and files

Fresh verification: **314 Mobile tests passed,13 optional diagnostic cases skipped** across48 compilable affected files, with preview UI enabled. **750 pose tests passed**. Scoped Flutter analysis of26 changed production/test files reports **no issues**. The arm64 Android Debug APK build passed; its private retained artifact is `build/module2-phase0-20261110/phase0-app-debug.apk` (SHA256 `D0306EC387374E4A2A8297620CE94564265574E403A9A666D43FB88498D111C9`). No APK was installed/launched.

The initial49-file extended run had309 passes,13 skips and one pre-existing compile failure in `workout_backup_integration_test.dart`: committed `in_memory_routine_template_repository.dart:36` calls nonexistent `EquipmentImage.extension`. Both source files are unchanged by Phase 0. This unrelated integration fixture is not claimed passing; it was recorded separately rather than weakening its contract or changing unrelated code. The final48-file manifest excludes that noncompilable fixture. All four requested consent fixture families pass for both first-time and previously accepted consent.

Independent review found a navigation-push→destination-build lease gap and incomplete suppressed/failed-audio diagnostic denominators. Both were reproduced RED→GREEN and fixed; the final suite covers the fixes. Route-level account/role revoke→restore is also covered. A minor suggestion for richer per-set/calibration transition counters is deferred: current transition metrics measure route→camera/readiness rather than a full state trace. Logs, original dirty-file snapshots and exact manifest are retained locally under ignored `build/module2-phase0-20261110/`.

Production changes: preview route and launch; shared preview/audio observation hooks; camera/detector/native audio adapters; six retained route factories; new scalar recorder and binding. Tests: preview authorization/launch, scalar diagnostics, Android audio, shared consent harness, Calf/Curl/Floor/legacy Wall consent fixtures. Documentation: scope note in audit, this report, implementation plan and scoped operational-reference entries.

Initial unrelated working-tree content is preserved. The commit stages Phase 0 deltas only, including partial staging for pre-existing dirty preview-controller, workout-preparation and operational-reference files. Tests/build ran against the inspected working tree including those preserved changes, rather than a clean checkout of the resulting commit. The user subsequently authorized direct continuation through Phase 1 and Phase 2; those changes/results require separate commits and reports.
