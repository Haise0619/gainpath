> **Documentation consolidated — 24 October 2026.** Historical guidance retained below. Its original instructions and next steps describe an earlier state; they are not current execution authority. Use [AGENTS](AGENTS.md), [current status](docs/STATUS.md), [architecture](docs/ARCHITECTURE.md) and [operations](docs/OPERATIONS.md). Exact-scope current approvals take precedence; old deploy/setup commands are not permission to run them.

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

# GainPath supervisor demonstration checklist

Execution evidence: [2026-10-15 integration report](docs/architecture/2026-10-15-firebase-demo-execution.md). Final backend source: `6dd91d90980dcd351b9f3aec297f0e885aa60b30`, branch `codex/real-squat-flow`; installed Firebase client artifact:588c7ab (app source unchanged by the later backend patch). The real three-role pending-hold/cancellation/automatic-expiry demonstration passed. This does not establish complete product readiness or every CRUD operation.

The owner's later [save/retrieval performance patch](docs/planning/2026-10-15-coaching-read-performance.md) passed independent review and [exact-head CI](https://github.com/Haise0619/gainpath/actions/runs/38666339474), then four affected Functions were selectively updated. Other ten Functions are unchanged. Owner's two post-update saves persisted/restored the window and owner reports faster response; initial server timings are in the report. No APK replacement or pose change was needed.

## Current usable artifacts

- **PASS:** Firebase-mode Admin Web at <http://localhost:7357/>; same existing account signed in, live catalog reads, Coach draft review/publication, availability and persisted booking reads work.
- **PASS:** Firebase-mode Android debug APK installed as a compatible Xiaomi update: `build/firebase-demo-preparation/gainpath-firebase-debug-588c7ab.apk`. Installed certificate checked, original APK/private data retained; private data byte-identical immediately after install. No uninstall/data clear.
- **PASS:** Final exact-head CI for `6dd91d90980dcd351b9f3aec297f0e885aa60b30`, including307 backend unit tests,61 emulator tests, Flutter/package/tooling suites, architecture/analysis and both mock-mode builds. Initial588c7ab CI also passed.
- **PASS:** Direct live authorization received. Existing Admin role corrected, genuine Coach provisioned/owner verified, approved policy created, all nine Functions selectively deployed, exact Firestore Rules and three READY indexes in place. Five existing Functions and Storage Rules preserved.
- **PASS:** Controlled native Android App Check debug credential registered privately; real Xiaomi options/hold requests log Auth/App Check VALID. Missing/invalid attestation and missing Auth rejected. This is not Play Integrity production validation.
- **PASS:** Private Scheduler worker executes empty batches and naturally expires the genuine replacement hold; no public invoker or new broad IAM grant.
- **PASS:** Real Member hold, same-ID cross-role pending visibility, trusted cancellation and released accounting/lock verified.
- **PASS:** Replacement hold owns the same reusable slot, preserving first cancelled booking/job; Admin deactivation excludes the Coach from Member directory and republication restores status on the same UID.
- **PASS:** Real deadline 09:12:38.731 Malaysia time; Scheduler persisted expiry at 09:13:06.161 (27.430 seconds later). Member/Coach owner checks and actual Admin browser agree on cancelled/expired records. No timestamp manipulation.
- **PASS:** Availability create/edit/remove/restore persisted as revisions1/2/3/4; two post-optimization saves produced5/6, restoring the same window. Matching receipts retained; owner confirmed reloads/faster response. Current window is16October09:00–11:00,main. Form actions and Save day are distinct.

## Launch the existing applications

Run from the repository root. If the current loopback server has stopped:

```powershell
node build/firebase-demo-preparation/serve-admin.cjs
```

Open <http://localhost:7357/>. It serves the already built Firebase Admin application on loopback only; no Hosting deployment is involved. Sign in using the same existing Admin credentials; its canonical membership is now Admin. Use a desktop-width browser window (980 px or wider) to access both children of grouped sidebar entries. The existing narrow rail jumps to a group's first child.

Rebuild commands, if needed:

```powershell
Set-Location C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web
C:/flutter/bin/flutter.bat build web --debug --no-pub --no-web-resources-cdn --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=false --output=C:/Users/Ngzhe/StudioProjects/gainpath/build/firebase-demo-preparation/admin-web

Set-Location C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile
C:/flutter/bin/flutter.bat build apk --debug --no-pub --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=false --dart-define=APP_CHECK_MODE=debug
```

The prepared APK's SHA-256 is `48169a0e11eac1c8ebe097f9a168622b089e1c29009d84b38d27b055d2e34af4`. Package `com.zyang.gainpath`, version `0.1.0`/code `1`, min SDK 26. It is debuggable; never use it as a production release. Configuring debug mode does **not** register an App Check debug credential or prove attestation.

Before any phone update, connect/unlock the Xiaomi and authorize USB debugging. Inspect its serial, installed version, base/split APKs and actual certificate. Privately preserve the installed APKs and supported account-scoped local data; the previous local APK alone is not a workout-data backup. Abort on package/certificate mismatch, downgrade requirement or uncertain data preservation. Only after those gates and installation authorization:

```powershell
& C:/Users/Ngzhe/AppData/Local/Android/Sdk/platform-tools/adb.exe -s <verified-Xiaomi-serial> install -r C:/Users/Ngzhe/StudioProjects/gainpath/build/firebase-demo-preparation/gainpath-firebase-debug-588c7ab.apk
```

Do not uninstall, clear application data or add downgrade flags. Preserve private App Check material outside source/logs/reports. Verify real token/callable behavior after private registration.

## Activation gates — completed; retain for future rebuilds

1. **DONE:** Direct authorization and exact-head CI. Confirm no newer source/remote drift before any future deployment.
2. **DONE:** Private before/after Admin snapshots and revision checks; only membership role changed. Existing Members preserved.
3. **DONE:** Dedicated supplied Coach identity, owner-controlled password setup and genuine verification. Never manually set `emailVerified` or use Member registration for privileged roles.
4. **DONE:** Exact `booking-v1` policy: `Asia/Kuala_Lumpur`, cap 1, hold 15 minutes. Do not blindly overwrite/change timezone with booking accounting present.
5. **DONE:** Nine reviewed exports, exact Firestore Rules and three READY indexes, in the existing [activation order](docs/planning/2026-10-15-coordinated-firebase-activation-preflight.md). Existing five Functions/Storage preserved.
6. **DONE:** Compatible client/readers, private Scheduler/OIDC, successful empty batches and real Android debug App Check before the first persisted hold.

## Three-role smoke sequence — actual results

| Step | Existing UI action | Required persisted evidence | Current result |
|---|---|---|---|
| 1 | Existing Admin signs in | Same Auth identity and intended current membership | PASS: actual Admin browser session |
| 2 | Admin catalog/routine CRUD | Successful server persistence; Member sees same content ID/targets | Catalog read/form entry PASS; write/publication smoke NOT EXECUTED in this task. Preserve squat/tutorial anchors |
| 3 | Member opens routines/detail/tutorial | Real organization content; honest unavailable media where applicable | Owner confirms routine details load and original History/Progress remain. Tutorial playback NOT VERIFIED: current publication has no videoUrl; separate activation remains required |
| 4 | Verified Coach saves professional profile | Own private draft/revision; no automatic publication | PASS: physical owner UI + Firestore draft revision1 |
| 5 | Admin publishes/deactivates/republishes Coach; Member refreshes | Same stable Coach UID, allowlisted fields, published-only Member visibility | PASS: actual Admin UI/callable; owner observed initial directory and exclusion after deactivation. Current public revision3, same professional fields |
| 6 | Coach creates/edits/removes/reloads future dated availability | Correct UTC interval, timezone and `main` branch | PASS: revision1 09:00–11:00; revision2 09:00–12:00; revision3 empty/removed; revision4 restored09:00–11:00. Owner confirmed reloads |
| 7 | Attested Member requests pending hold | Same persisted ID/status in all roles | PASS: initial-hold-booking-id-redacted, 09:00–09:30; Admin observed, owner confirms Coach roster match; Auth/App Check VALID |
| 8 | Member cancels; lists refresh | Cancelled record and safe release | PASS: member_cancelled at 00:55:39.913Z; daily reservation0, lock expiry advanced to closure, job completed; Admin displays cancelled |
| 9 | Member creates replacement in same permitted interval | New persisted pending record; previous evidence retained | PASS: replacement-hold-booking-id-redacted, created00:57:38.731Z; owns reused lock/reservation |
| 10 | Wait real 15-minute deadline and Scheduler tick | Persisted expired record/job result; all roles agree | PASS: expired/hold_expired at01:13:06.161Z; daily reservation0, job completed/expired/attempt1. Real worker processed1, blocked0/retry0; owner confirms both mobile roles agree; Admin observed |
| 11 | Switch/logout accounts; inspect existing local history | No stale account responses or original data loss | PASS: owner confirms history remains; archive checks all4 original workout and4 sync entries unchanged. Owner added2 local realCamera entries during Squat use; neither server-accepted |

Keep all real booking/receipt/job evidence. A hold is never a payment, confirmed appointment or completed consultation. Unsupported payments, earnings, certifications, rewards and advanced reports remain unavailable. Mock screens remain preserved only in mock mode.

## Rollback boundaries

- Before real holds: roll back only newly activated resources as specifically approved. Preserve additive indexes, five existing Functions, Storage and all user/content/workout data.
- After holds: stop new hold creation first; pause Scheduler before worker rollback; retain compatible terminal-state readers. Never restore old lock/accounting snapshots over newer activity or reopen closed bookings.
- Phone: preserve installed package/signature/data and compatible readers. A prior APK is not automatic permission for a downgrade or local-data deletion.
- AI squat/Step 7C and Bodyweight Squat tutorial activation remain separate; no simulated workout submission or acceptance-policy changes.
