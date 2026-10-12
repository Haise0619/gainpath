# Development deployment and physical test handoff

Continued the authorized real squat handoff on 2026-10-12. The intended project
is the existing `.firebaserc` development target `gainpath-0619`. No production
model/rule tuple was enabled and no workout or consent record was fabricated.

## Deployed and verified

Selective deployment completed successfully for these Node.js 22, second-generation
callables in `us-central1`:

- `acknowledgeWorkoutConsentCommand`
- `revokeWorkoutConsentCommand`
- `submitWorkoutSessionCommand`

The Firestore rules update adds only verified active member owner-get access to
the current consent document. Remote rules were compared before deployment: this
was the only difference from the tested local source. The resulting deployed
rules match that source exactly after newline normalization; SHA256:
`c301e87391a0ad774b220fc56b742815d243ca44027decd956dbb7e46c6dbfd1`.

The existing `provisionMemberRegistration` and `publishRoutineCommand` remain
listed alongside the three new callables. No other functions, hosting, storage
rules or indexes were selected for deployment. Each new live endpoint was called
without authentication using a bounded empty callable request; all returned HTTP
401 / `UNAUTHENTICATED`. These smoke checks prove the live authentication boundary,
not an authenticated workout or physical motion result.

Read-only catalog verification confirmed the development exercise
`F3b8xIr8ynBDd3gEICKX` is active and published routine
`routine_PTe4DxLS3WZ2DsfpGTOy` remains a published routine containing it, 3 sets ×
8 reps. Member data was not used for these checks.

The deploy CLI reported a legacy GCR build-image cleanup warning. Read-only
Artifact Registry checks afterward confirmed all three selected function build
packages are absent. No broad image deletion or unrelated cloud change was made;
legacy GCR state was not established by that check. The CLI also suggested a
firebase-functions SDK upgrade; this tested deployment kept the current versions.

## Fresh verification

- Backend production and test TypeScript checks pass; all 114 unit tests pass.
- Full Firestore/Storage emulator suite: 28 tests pass.
- Mobile source/test analysis: no issues; full suite: 249 tests pass, with 15
  optional diagnostic tests skipped.
- Firebase development profile APK builds with explicit `BACKEND=firebase` and
  `APP_ENV=development`. The earlier default mock profile artifact alone did not
  establish a reachable Firebase flow.

Preserved APK:
`apps/mobile/build/step6-development/gainpath-firebase-profile.apk`

SHA256:
`25d5214d12b993e4f5ef188b2972083258a925caee110b0529154434ebfce6e2`

Local ignored evidence in that directory includes `development-preflight.json`,
`endpoint-smoke.json`, `build-artifact-check.json` and the pre-deployment rule
snapshot. The APK and generated logs/evidence are not committed to Git.

## Physical work still pending

`adb devices -l` reported no attached Android device. No APK was installed, no
camera was opened, and no human squat or spoken cue was tested in this continuation.
The server's `ENABLED_WORKOUT_TUPLES` remains empty. A new acknowledged opt-in may
queue a measured request, but submission is intentionally rejected pending
physical validation; local save remains usable. No rewards are awarded.

When a phone is available, install the preserved Firebase APK without uninstalling
or clearing existing app data:

```powershell
$poseAdb = 'C:/Users/Ngzhe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
& $poseAdb devices -l
# Substitute a serial actually reported as "device" above.
& $poseAdb -s <device-serial> install -r `
  'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/build/step6-development/gainpath-firebase-profile.apk'
& $poseAdb -s <device-serial> shell am start -n com.zyang.gainpath/.MainActivity
```

Use a verified active Firebase member account in organization `gainpath`. Open
Workout → Start guided session, explicitly accept camera tracking and confirm a
full-body side view with an upright stationary camera. Upload opt-in is optional;
leave it off for the first physical local-flow check. This APK uses the default
CPU detector and existing provisional thresholds; experimental GPU/filter changes
are not enabled by these build arguments.

Record independently annotated full and partial squat attempts, unfinished cycles,
trunk lean and periods of missing joints. Compare observed counts and supported
deviations with annotations; do not label intended movements as ground truth
without inspecting the actual movement. Verify pause/background/resume recalibration,
rotation, permission denial/retry, voice off/on, save failure recovery, history
after restart and logout privacy. Lack of an assessable attempt must leave the
estimated form score absent, rather than displaying a fabricated percentage.

Camera-callback/CPU-paint timing is not physical camera-to-display latency. Assess
physical timing with a synchronized external view of source motion and the phone
display; separately record analysis and spoken cue onset. Existing internal
diagnostics can attribute computation and queue costs, but do not supply sensor
exposure or display-present timestamps. Agree numeric accuracy/latency targets
and collect representative phone evidence before enabling a server tuple.

Only after physical quality acceptance should a reviewed policy change enable
the exact detector/rule/view tuple and test one genuinely captured, consented
session's accepted server document and retry behavior. Synthetic fixtures must
continue to stay outside real activity acceptance. Unattended implementation
cannot replace that physical evidence.
