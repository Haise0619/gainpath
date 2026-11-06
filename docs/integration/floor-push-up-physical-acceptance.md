# Floor Push-Up controlled physical acceptance

Status: **PENDING — debug testing only**. Physical Left Side View, native speech timing, complete workout, saved summary/history and human form-score acceptance have not passed. Keep Cloud Backup off until the schema-7 backend gate below passes. Module 13 eligibility remains disabled.

Use the new `build/floor-push-up-voice-20261105/gainpath-floor-voice-debug.apk`; confirm its SHA-256 in that directory's verification manifest. Preserve the installed app identity, signer, data and previous APK; do not uninstall or clear data. Finish or save any active session before updating. Do not substitute an arbitrary earlier `app-debug.apk` from the shared output path.

## Capture and observation sheet

Record phone model, Android/TTS engine and offline English voice, volume/output route, camera orientation, selected side, APK hash, voice mode and recording ID. Keep each camera level at floor height with the instructed joints visible. Annotate actual independent pose timestamps; duplicated screen frames are not new observations.

For **each** side, record a manually labeled sequence and fill expected full/partial counts, actual full/partial counts, false counts, missed counts and findings. Do not infer real-device acceptance from analytic fixtures. Preserve TOP >=155°, BOTTOM <=105° and 120 ms dwell. The camera threshold measures are provisional and do not establish biomechanical accuracy.

| Check | Right Side | Left Side | Acceptance evidence |
|---|---|---|---|
| Fresh extended plank, then three complete observed cycles | Pending | Pending | Exactly three completed counts, no duplicate at sustained TOP; every count has accepted BOTTOM and TOP evidence. |
| Shallow descent followed by extension | Pending | Pending | No full count; one meaningful partial; `floor_depth`: “Lower your chest a little more.” |
| Valid descent, return below155°, then renewed descent | Pending | Pending | No full count; one partial; `floor_extension`: “Extend your arms fully.” Delivery survives READY reset; fresh TOP rearms. |
| Subsequent clean complete cycle | Pending | Pending | One new full count; no reuse of prior bottom credit or replay of old correction. `floor_good`: “Good repetition.” when no measured findings. |
| Observable hip sag / hip pike with accepted tracking | Pending | Pending | Correct corresponding guidance only when the feature is measurable; do not score elbow flare. No fabricated fault score during occlusion/unscored recovery. |
| Brief occlusion; then sustained tracking loss | Pending | Pending | Brief recoverable loss does not erase a fresh completed-attempt event. Sustained loss cancels old correction and prioritizes “Adjust your camera position.” No invented rep. |
| Repeated same fault / competing warning | Pending | Pending | Same cue not repeatedly spoken within floor's6-second per-cue cooldown. Warning > correction > encouragement. No backlog/overlap. A higher-priority cue cancels lower-priority speech. |
| Full Coaching, Alerts Only, Muted | Pending | Pending | Coaching corrections/encouragement audible as applicable; Alerts Only suppresses encouragement; Muted silent. Existing preference semantics preserved. |
| Pause, background, mute and session exit while speaking/preparing | Pending | Pending | Cancellation is audible and logged; no stale speech after resuming. New accepted observations can generate new feedback. |
| Last repetition of a target set | Pending | Pending | Correct count and bounded final encouragement can finish during rest/completion. Manual pause/Finish still cancels. |

## Audio timing and latency investigation

The debug APK enables `GAINPATH_WORKOUT_AUDIO_TRACE` and floor diagnostics. They default off and are disabled in release. Bounded256-entry per-session trace records contain cue/request IDs and monotonic timestamps, without text, images, joints, account IDs or upload. Debug `GP_AUDIO_TRACE` lines are local logcat diagnostics; capture only this prefix in private test evidence, then remove/retain according to the project's evidence policy. They are not saved workout history.

With the phone connected, start a private trace capture before the set:

```powershell
adb logcat -v monotonic -s flutter:I | Select-String 'GP_AUDIO_TRACE' |
  Set-Content -LiteralPath 'build/floor-push-up-voice-20261105/device-audio-trace.private.log'
```

For each cue correlate `exercise_event_generated` → `feedback_queued` → `arbitration_selected` → `tts_dispatch` → `tts_request` → `native_tts_request` → `playback_start` → `playback_completed`/cancelled/unavailable. `dropped`, `cancelled` and `expired_before_start` explain suppressed speech. Preparation request/completion records expose cold-engine delay. Guidance is current-frame; attempt feedback is independently identified. Skipped events are not accumulated for later playback.

Compute pose-age and Dart queue/dispatch durations only within the Dart session clock. Compute native request→start and start→completion only within Android elapsedRealtime. The port samples Android's clock and subtracts the entire round trip to conservatively map the remaining deadline; never subtract the two clocks' raw origins. The original completed observation has at most500ms to start; Android also caps the start budget at500ms and rejects a request received after its absolute deadline. Already-started speech may finish naturally unless a cancellation condition applies. These are development policy bounds, not measured speaker latency claims.

Record actual audio against the screen/trace (including a cold engine and a warmed engine). Report p50/p95/max generation→audible-start, native request→start and phrase duration, plus expired/dropped counts and reasons. Treat a necessary correction that repeatedly expires as a failed acceptance requiring investigation; do not waive it because the expiry safety test passed. Verify content, routing, interruption and audible overlap by listening. No measured device latency is currently available.

## Finish, local summary/history and form

1. Finish a mixed full/partial workout before the target. Confirm full and partial counts are distinct, Finish saves once, and summary is available after save. An unfinished meaningful cycle may become one interrupted partial; it must not become a full rep.
2. Reopen Saved Workout Sessions; compare ID, exercise name, selected side, full/partial counts, duration and available findings. Navigate away/reopen and restart the app to verify durability; exercise/account boundaries remain intact.
3. Complete a target set and the full configured multi-set workout, including rest/next-set transitions. Check final encouragement, target completion and saved summary. A failed save must support retry without duplicate sessions.
4. Inspect a strict assessable cycle and a recovered/projected/unscored cycle. Missing form score/components must remain unavailable, not invented0%/100%. Compare available component/fault values with manually labeled observable faults. Wall/Floor groups remain separate. Native form acceptance remains pending even if serialization tests pass.
5. Record each result as PASS/FAIL/UNTESTED with video/trace reference. Both sides, audio, Finish/save/reopen and score availability must pass before changing the release decision.

## Prepared Firebase schema7 compatibility release — NOT DEPLOYED

Exact offline archives/patches/inventory are in `build/floor-push-up-voice-20261105/backend-release/manifest.json`. Project `gainpath-0619`, region `asia-southeast1`, existing functions **only** `workoutBackupCommand` and `adminWorkoutReportingCommand`. No Rules/indexes/IAM/environment/runtime/entrypoint/dependency/other function update is included. No user data migration/write, recommendation activation or Admin Dashboard change is included.

The prepared backup archive changes only `lib/modules/workouts/workout-backup.js` and `workout-backup-validation.js`, adding `floor-push-up-validation.js`. The reporting archive changes only its bundled validator and adds the same floor validator; its reporting/callable implementation remains byte-identical. This intentionally excludes unrelated local FYP/reporting changes. Original ZIPs are retained for rollback. Source-only patch diffs and hashes pin every preserved packaged file. The original deployed schema<=6 rejection was executed locally;26 prepared-package checks now pass, including scored/unscored left/right payloads, spoof denial, consent/ownership denial, client maxima2–7 and read-only Module12 Wall/Floor grouping.

Reproduce preparation locally (no deployment mode exists in these tools):

```text
cd functions
pnpm exec tsc --outDir ../build/floor-push-up-voice-20261105/compiled
cd ..
python tools/workouts/prepare-floor-schema7.py
node tools/workouts/verify-floor-schema7.cjs
```

Before any future deployment: re-download/compare the two active source hashes to the pinned baselines; snapshot all72 Functions and target service configuration/IAM; review exact ZIP/patch hashes and Auth/App Check/ownership/consent gates. Resolve drift rather than overwriting newer source. After release gates authorize execution, update only `buildConfig.source` for those two existing Functions, retaining region/runtime/entrypoint/configuration/IAM. Verify active source hashes and preservation of other functions/Rules/indexes/configuration; perform authenticated schema7 save/list/restore and Module12 descriptive reporting with approved test records plus old-client negotiation. Retain a reviewed source-only rollback to the two original ZIPs. **Do not execute deployment during this task.** Pure package checks do not certify live Firebase/App Check round trips.

## Production signing — CONFIGURED FAIL-CLOSED, IDENTITY PENDING

Gradle no longer substitutes the debug key for release. Supply approved credentials through ignored `apps/mobile/android/key.properties` using `key.properties.example`, or environment `GAINPATH_ANDROID_KEYSTORE_PATH`, `GAINPATH_ANDROID_KEY_ALIAS`, `GAINPATH_ANDROID_STORE_PASSWORD`, `GAINPATH_ANDROID_KEY_PASSWORD`. Keystore paths resolve from `apps/mobile/android`. No passwords or private keys are included/generated.

Missing inputs block direct release requests and actual aggregate task graphs (including `assemble`/`build`); both guard paths are tested without producing a release. Debug builds use the existing debug signer independently. Before production, verify the approved certificate SHA-256 against the intended distribution/update and App Check identities. A new signer cannot silently update a differently signed installation; do not uninstall/clear data to bypass that. Keystore ownership, signer continuity, Play/App Check attestation and physical gates remain unverified. No production APK/AAB or distribution is authorized by this preparation.
