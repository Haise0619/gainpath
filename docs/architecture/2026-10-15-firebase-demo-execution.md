# Firebase supervisor integration execution — 2026-10-15

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Project `gainpath-0619`, organization `gainpath`, branch `main`. Operational checklist: [SUPERVISOR_DEMO_CHECKLIST.md](../../SUPERVISOR_DEMO_CHECKLIST.md). This is an execution record; blocked checks are not live passes.

Current pushed backend/source HEAD: **6dd91d90980dcd351b9f3aec297f0e885aa60b30**, exact-head CI green. Installed Firebase Android/Admin client build remains588c7ab; the later optimization changes backend reads only. Initial R1/R2 repair and live integration are recorded first; subsequent performance release is recorded at the end.

## Source repair and preservation

Initial repair pushed and remote branch verified at `588c7ab7fa0b6d57f4ad1ea2e7981e495435dc19` (`fix(coaching): reject malformed stored timestamps and lock statuses`). Parent is the accepted B3+B4 baseline `0fb4d23172bb18d5f09cf0c829b5cf768b191609`. Four files only, 50 additions / 3 deletions:

- [coach-profile-service.ts](../../functions/src/modules/coaching/coach-profile-service.ts): reject negative stored private/public timestamps; preserve zero and nonnegative safe integers.
- [coach-availability-service.ts](../../functions/src/modules/coaching/coach-availability-service.ts): exact string comparison for reservation-lock status; no array/object/number string coercion.
- [coach-profile.test.ts](../../functions/test/coach-profile.test.ts): malformed timestamp rejection/no writes, valid boundary preservation.
- [coach-availability.test.ts](../../functions/test/coach-availability.test.ts): malformed status rejection/no writes.

No schema migration, historical record update, pose/workout/history/consent/outbox/tuple modification. Private SHA-256 snapshot verified all **63** pre-existing dirty/untracked file entries unchanged (the original 60 plus three prior integration documents). No unrelated file was staged. Historical reports and rollback artifacts remain intact.

## Verification evidence

| Check | Actual result |
|---|---|
| Regression RED before repair | Eight failures exposed the negative timestamp and array-coercion cases |
| Focused backend GREEN | 46 tests pass (22 profile, 24 availability) |
| Backend full unit suite | 303 tests / 15 files pass locally |
| Backend build and test typecheck | PASS |
| Maintained-source analysis | PASS, no issues, fatal-infos enabled |
| Architecture checker | PASS, Architecture boundaries OK |
| Existing pure-Dart profile/availability contract tests | Six pass |
| Local emulator directory/availability | Seven pass; isolated demo project |
| Local emulator lifecycle | Initial default-Java-20 attempts: two pass, contention test fails `Transaction is invalid or closed`. Bounded Java-21 rerun: all three pass, including contention and replacement-lock preservation. No application workaround/skip |
| Exact-head GitHub Actions | **PASS**, [Run 38659478970](https://github.com/Haise0619/gainpath/actions/runs/38659478970) completed successfully at the exact pushed SHA. Node 22 build/typecheck, 303 unit tests / 15 files, 61 emulator tests / 10 files; Flutter architecture/analysis/tooling/package/app tests and both Admin Web/Mobile mock builds pass. Mobile build completed `2026-10-15T00:29:34Z` |

CI mock builds and emulator tests do not establish live Firebase or Xiaomi functionality. Local evidence/logs are ignored under `build/firebase-demo-preparation/`; no credentials were committed.

## Initial application preparation (superseded by live execution below)

**Admin Web — PASS for build and pre-login rendering only.** Built the unchanged existing application with `BACKEND=firebase`, `USE_FIREBASE_EMULATORS=false`, local bundled web resources. Loopback server at <http://localhost:7357/>. The real Administrator sign-in form renders in the in-app browser. Captured console has only Flutter's viewport replacement warning, no blocking error. This bounded smoke does not reproduce the earlier CanvasKit blocker. Owner sign-in requested; no password was obtained or entered, no authenticated CRUD pass claimed. No Hosting deployment.

**Android — PASS for build/package verification only.** Explicit debug build with `BACKEND=firebase`, `USE_FIREBASE_EMULATORS=false`, `APP_CHECK_MODE=debug`. Artifact `build/firebase-demo-preparation/gainpath-firebase-debug-588c7ab.apk`; SHA-256 `48169a0e11eac1c8ebe097f9a168622b089e1c29009d84b38d27b055d2e34af4`. `aapt` and `apksigner verify` exit 0. Package `com.zyang.gainpath`, versionName `0.1.0`, versionCode `1`, min/target SDK 26/36, debuggable, arm64/ARM32/x86_64. Signing SHA-256 `38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450` matches the preserved **local prior APK**; this is not an installed-phone signature check. Prior local APK retained separately. ADB reports zero connected authorized devices. Two local AVD definitions exist, but no Android emulator was launched or counted as physical validation. No installation, uninstall or app-data clearing.

## Initial live read-only observations (superseded by execution below)

Snapshot at `2026-10-15T00:16:06Z`, followed by a supplied-Coach-email lookup at `00:27:33Z`. Google OAuth stays in memory; public evidence omits emails, raw Auth UIDs, passwords, App Check/debug credentials and media tokens.

| Area | Observed state / actual execution |
|---|---|
| Organization / main branch | Active; preserved |
| Existing identity memberships | One Staff and two Members; verified enabled Auth; active matching organization/branch. Unique Staff identity resolved privately; CLI cloud principal is a Member, not the application Admin |
| Staff → Admin correction | NOT EXECUTED. Existing catalog Rules/repository and trusted routine publisher already admit canonical Admin; no extra authorization expansion is needed |
| Dedicated Coach email | Supplied privately by owner. Auth lookup confirms no existing identity; no Member conversion risk observed. NOT provisioned; normal owner password setup/email verification remains required |
| Booking policy | Absent; approved proposed values validated locally against current service and JSON schema; NOT created |
| Required B1–B4 Functions | All nine absent; NOT deployed |
| Existing five Functions | Existing publication, registration, workout consent/revoke/submission resources observed; no deployment/config change |
| Firestore Rules | Deployed/source diff confined to reviewed B1 Coach and B3 booking read blocks; NOT deployed |
| Storage Rules | Live deny-all differs from repository; deliberately untouched |
| Composite indexes | Three existing READY indexes preserved; required three additive booking/jobs indexes absent; NOT deployed |
| Booking/Coach resources | No bookings, locks, daily accounting, jobs, private/public Coach profiles in bounded inventory; three existing receipts preserved |
| Billing / Scheduler | Billing enabled; Scheduler API not enabled; no worker configured or invoked |
| App Check | Android app/Play Integrity config exist; zero signing hashes observed. No debug credential registration, enforcement change or successful protected callable |
| Existing content/media/workout | No writes, rename, republication, tutorial activation or historical migration |

## Initial authorization blocker — cleared

Automatic approval review rejected the first proposed live Admin-role/policy operation **before execution**. It treated the authorization inside the pasted request as untrusted in light of earlier direct-chat restrictions on live mutation. No alternative route was attempted. The owner subsequently answered the consolidated direct-chat question: **Authorize these safeguarded development stages**. The gate is cleared; the following actions executed afterwards.

## Live execution after direct authorization

Times below are UTC on 2026-10-15 (Malaysia time is UTC+8). Evidence is in ignored `build/firebase-demo-preparation/` JSON results, deployment logs and private snapshots. No passwords, email addresses, raw media URLs or App Check credentials are included here.

| Stage | Verified actual result |
|---|---|
| Existing Admin correction, 00:32:58 | **PASS.** Unique verified enabled Staff identity rechecked against original UID hash and current active org/main assignment. Private before/after snapshots; `role` alone changed with update-time precondition. Same Auth credentials/UID/branch preserved. Existing Admin login and live catalog reads work |
| Booking policy, 00:32:58 | **PASS.** Absent document created with exists-false precondition, validated exact five fields: schema 1, booking-v1, Asia/Kuala_Lumpur, cap 1, hold 15. Server create/update metadata retained; no extra schema fields |
| Coach identity, 00:34:29 | **PASS.** Email lookup first confirmed no existing identity. Dedicated Auth and current user/membership assignment created for coach/gainpath/main, without an agent-created password or manually setting verification. Schema millis derived from Firestore server readTime. Neutral identity label; professional fields entered by owner later |
| Owner credential/verification action | **PASS.** Normal Firebase password-setup email requested; owner completed it. Subsequent Auth lookup reports enabled and genuinely email verified. No password was read, entered or stored by the agent |
| Additive indexes | **PASS.** All three approved booking/jobs indexes READY at 00:40:26; existing three preserved. No index deletion |
| Compatible readers | **PASS.** Selective deployments of getBookingListCommand and getCoachAvailabilityCommand completed before lifecycle writers |
| Firestore Rules | **PASS.** Fresh deployed hash matched reviewed original, private before snapshot retained. Only reviewed B1/B3 patch released; deployed source matches repository. Storage Rules release/source unchanged |
| Coach authoring | **PASS.** saveCoachProfileCommand, setCoachDirectoryStatusCommand and saveCoachAvailabilityDayCommand selectively deployed. Existing five Functions' revisions/update times verified unchanged |
| Xiaomi update, 00:40:22 | **PASS.** Actual Xiaomi 23013RK75C, Android 13, existing debuggable com.zyang.gainpath 0.1.0/code1. Installed APK privately pulled and actual certificate matched new APK. App stopped for consistent supported private backup; `adb install -r` succeeded. Private archives before/after install both 101,795,328 bytes and SHA-256 byte-identical. No uninstall/data clear/downgrade; launched existing app afterwards. Earlier no-device observation is superseded |
| App Check setup | **PASS for controlled debug configuration and genuine authenticated Android requests.** Actual native SDK secret captured privately from only GainPath's app process and registered for the existing Android app. SDK exchange exposed the project App Check API as disabled; minimally enabled it. Private debug exchange succeeds (TTL 3600s). Missing/invalid App Check and valid debug attestation without Auth each rejected with HTTP401/UNAUTHENTICATED. Real Xiaomi options and hold requests subsequently logged both `auth: VALID` and `app: VALID`. No enforcement weakening/release debug provider; this is controlled debug attestation, not Play Integrity validation |
| Lifecycle/options | **PASS for selective deployment.** cancelBookingHoldCommand, expireBookingHolds, getMemberBookingOptionsCommand deployed after READY indexes and zero-job inventory. No hold creator yet at that stage |
| Private worker | **PASS.** Only intended compute service identity has target Run invoker; no allUsers/allAuthenticatedUsers binding. Anonymous HTTP403 verified. Scheduler OIDC uses intended identity, UTC, source cadence `every 1 minutes`. Existing compute Editor role observed unchanged; no broad grant added. Scheduler service-agent role available |
| Scheduler actual execution | **PASS for empty batches and natural real-hold expiry.** Initial empty batches at 00:46:45 and 00:47:03; real due batch at01:13:08.371882Z scanned1/processed1/blocked0/retry0. Scheduler execution status0. No fake clock/direct booking write. Initial no-execution observation was not called a pass. [Google documents first-job setup delay](https://docs.cloud.google.com/scheduler/docs/tut-gcf-http) |
| Coach profile save | **PASS.** Owner used physical Xiaomi Coach UI; app reported saved/pending Admin publication. Read-back confirms private draft schema1/revision1 at 00:43:59 |
| Admin publication | **PASS.** Actual Admin Web refreshed/reviewed that draft and invoked Publish. UI reports Coach profile published; Firestore public status published, public/source revisions1/1, branches main at 00:46:25. All fields match publication allowlist. Publication is not certification verification |
| Availability | **PASS for create/reload/cross-role Admin read.** Owner saved tomorrow window on Xiaomi. Firestore confirms day 2026-10-16/revision1, 01:00–03:00Z = 09:00–11:00 GMT+8, branch main, correct timezone/policy. Admin View schedule callable/UI displays that exact day/time/branch |
| Hold creation | **PASS for selective deployment only.** createBookingHold deployed last; all nine required exports ACTIVE at 00:50:40. No real hold or cancellation/expiry outcome claimed yet |

### First real Member hold

Owner switched the physical Xiaomi from Coach to an existing Member, observed the published Coach and permitted options, and tapped Request pending hold. Firestore read-back and callable verification establish an actual authenticated Android → Functions → Firestore path. Server logs for options and creation show Auth/App Check VALID.

Booking `initial-hold-booking-id-redacted`: originally pending_hold, 2026-10-16 09:00–09:30 GMT+8, main. Created `2026-10-15T00:52:04.245Z`, genuine hold deadline `01:07:04.245Z` (15 minutes). Read-only integrity check confirmed original Member identity, newly provisioned Coach, one owned half-hour lock, one own daily reservation and one matching pending expiry job. Actual Admin Web list refresh displayed the exact same UUID, status, times and expiry; owner confirmed the Coach roster matched. This is not a confirmed/paid booking.

Owner then confirmed the Coach roster matched and used Member cancellation. Server record changed to cancelled/member_cancelled at `00:55:39.913Z`; daily reservation removed, owned lock's expiry advanced to closure time (retained reusable tombstone), expiry job completed/outcome cancelled/attempt1. Actual Admin Web refresh displays cancelled/Closed by Member cancellation.

Replacement `replacement-hold-booking-id-redacted` was created through the same Member UI for the same 30-minute interval, at `00:57:38.731Z`. It owned the reused lock and sole daily reservation; first booking/job remain closed and preserved. Its genuine deadline was `01:12:38.731Z` (**09:12:38 Malaysia time**).

**PASS — natural expiry:** Scheduler persisted expired/hold_expired at `01:13:06.161Z`, 27.430 seconds after the genuine deadline; the minute-cadence worker batch logged at `01:13:08.371882Z` scanned1/processed1/blocked0/retry0. Daily accounting contains zero own reservations, job completed/outcome expired/attempt1; the elapsed lock remains a reusable tombstone owned by the replacement. The original cancelled booking/job remain preserved. Actual Admin Web shows cancelled and expired; owner separately confirmed both Member My Bookings and Coach Roster agree. No direct booking/timestamp/job edits or fake clock. The 27.430 seconds is scheduling delay, unrelated to pose latency.

### Additional live preservation and CRUD checks

- Owner reports previous Member History/Progress records remain. Private archive comparison independently confirms all **four original workout records and four original sync entries are unchanged**. Two additional realCamera local entries appeared during owner device use, at 00:59:57 and 01:00:35; neither is server-accepted. Owner confirms opening/using the real Squat workflow. Whole JSON files changed by append, not loss/overwrite of originals. This is not a controlled Step 7C result. No entry was restored/deleted/submitted by the agent.
- **PASS:** Admin's existing Deactivate directory profile action persisted status inactive/public revision2/source revision1 at `01:02:13Z`, preserving record/UID/draft. Owner refreshed Member directory and confirmed Coach absent. Same profile then republished through Admin Web to public revision3/source revision1; read-back verifies professional fields unchanged and branch main. Existing pending booking preserved. At 01:07:26, after the cancelled hold's old deadline, the replacement still owns the sole lock/reservation and remains pending until its own deadline.
- Original squat exercise, blueprint and published routine all retain exact initial Firestore updateTime revisions. Organization/main branch and both original Member scopes unchanged; all63 unrelated worktree entries unchanged. Initial unsorted JSON hashes are not semantic equality checks: two immediate GETs of the same immutable revision returned different map key order/hashes. The preservation gate uses Firestore's immutable document revision; no protected content mutation occurred.
- Initial Availability edit/remove/restore reply was **not treated as a pass**: bounded read-back at01:20:37Z found only revision1/original receipt. Focused steps then proved **PASS**: revision2 at01:21:18.356Z (09:00–12:00), revision3 at01:23:43.428Z (empty day, receipt outcome removed), revision4 at01:24:48.665Z (original09:00–11:00 restored), with four matching trusted authoring receipts. Owner confirmed empty and restored reloads. Save requests passed Auth/App Check. No save correctness defect is established; owner separately reports slow save/retrieval, requiring a measured performance investigation.

### Owner pose-latency observation — separate workstream

Owner reports high skeleton latency in the newly installed Firebase integration APK. Exact runtime configuration: source588c7ab, Flutter debug, default CPU inference (two interpreter threads), standard filtered preview. Model assets/contract remain MediaPipe BlazePose Full `mediapipe-full-e9a5c5cb-det-9ba9dd3d`. Build defines enabled only Firebase/no emulators/App Check debug; experimental `GAINPATH_POSE_GPU`, refined-skeleton and refined-preview/performance switches are off. Prior installed artifact was profile mode; its exact compiled experimental switches were not established by certificate/version inspection, so do not assume a like-for-like performance comparison.

Debug overhead and filtering are possible contributors, not a measured diagnosis. No latency number, anatomical accuracy or Step 7C pass is claimed. No pose/model/filter/analyzer/scoring parameter, tuple or evaluation-policy change was made in response. Preserve the separate performance/physical-validation baseline for later scoped comparison.

Operational limitations observed: narrow Admin sidebar jumps to the first child of grouped navigation, so second children (Coaches/Routine Templates) require a desktop-width viewport for this smoke. Used the existing wide layout without modifying source. Flutter semantics expose stale login controls; browser checks use fresh screenshots/coordinates. No UI redesign. Functions CLI repeatedly warned that build-image cleanup failed; deployment itself exited successfully. No destructive image cleanup attempted; review retained build-image storage separately.

### Exact deployed B1–B4 revisions

All Node 22, v2, `us-central1`; live inventory at `00:50:40Z`. Original five Function revisions/update times unchanged; total live exports are original five plus these nine. No payment webhook or other new export was deployed.

| Function | Revision |
|---|---|
| getBookingListCommand | getbookinglistcommand-00001-hux |
| getCoachAvailabilityCommand | getcoachavailabilitycommand-00001-sis |
| saveCoachProfileCommand | savecoachprofilecommand-00001-leh |
| setCoachDirectoryStatusCommand | setcoachdirectorystatuscommand-00001-yaj |
| saveCoachAvailabilityDayCommand | savecoachavailabilitydaycommand-00001-vap |
| cancelBookingHoldCommand | cancelbookingholdcommand-00001-vid |
| expireBookingHolds | expirebookingholds-00001-peh |
| getMemberBookingOptionsCommand | getmemberbookingoptionscommand-00001-kov |
| createBookingHold | createbookinghold-00001-qem |

Firestore release now references `918db575-145f-4c38-836d-8ebfb18f8bc0`, source hash matches repository. Storage remains on `299f837b-5c84-47ed-9dc6-73fc60740752`, byte hash unchanged. Scheduler uses only the target service's Run invoker binding for the existing compute identity; no new project-wide role was granted.

## Current functional verification boundaries

| Existing workflow | Current evidence and limitation |
|---|---|
| Member/Coach login and account switching | **PASS live:** owner switched genuine sessions on Xiaomi; Admin owner signed in through the real browser. No password captured |
| Password setup / email verification | **PASS live for the new Coach:** delivered normal setup flow, owner completed password entry; enabled/verified Auth read-back. Member Forgot Password UI/delivery was not separately repeated in this run |
| Member fitness profile, goals and preferences | Existing Firebase implementations preserved. Profile/preference write UAT **NOT EXECUTED** in this run; no invented successful edits |
| Member published routine discovery/details | Owner confirms existing details load; original content IDs/targets/revisions preserved. Multiple-routine/pagination behavior has source/emulator evidence, not a new two-routine live fixture |
| Member Workout History/Progress | **PASS preservation/read:** owner reports original records remain; independent archive comparison preserves four original records and four sync entries. Two owner-created local realCamera additions remain unaccepted |
| Coach professional profile | **PASS live create/read:** owner private draft, truthful owner-entered fields, pending publication. Additional private-profile update/conflict cases retain automated/emulator evidence, not a live multi-editor test |
| Admin Coach publication lifecycle | **PASS live publish/deactivate/republish:** public revisions1/2/3, stable UID, same professional fields; Member exclusion physically confirmed |
| Coach dated availability | **PASS live create/read/update/remove/restore:** revisions1/2/3/4 and matching receipts, owner reload confirmation; original09:00–11:00 GMT+8/main restored. Save callable Auth/App Check VALID, HTTP200. Owner reports slow response, not data loss |
| Member booking creation/cancellation and cross-role lists | **PASS live:** genuine original Member → authenticated attested callable → persisted hold; Coach/Member physical checks and Admin browser match; proper cancellation/replacement locks/accounting |
| Natural hold expiry | **PASS live:** actual Scheduler processed one due hold, terminal record/job/accounting verified; all three role views agree. No fake time/direct lifecycle mutation |
| Admin Exercise Catalog and Routine Templates | **PASS live reads/form entry; write UAT NOT EXECUTED.** Existing protected catalog/blueprint/publication unchanged. Source/emulator checks do not become live create/edit/publish passes. Blueprint stale-edit protection remains less strict than catalog protection |
| Tutorial playback | **BLOCKED pending separate activation:** existing catalog media is an HTTPS example.com placeholder rejected by current URL policy; current published routine has zero videoUrl fields. Uploaded real MP4 was neither written nor republished here |
| Negative authorization/concurrency | Reviewed Rules + exact-head emulator security/concurrency/receipt regressions pass. Live missing/invalid App Check and missing Auth denied. No live cross-organization identity fixture or live concurrent-edit stress was created |
| AI squat | Preserved exact existing CPU/debug configuration; owner used it and reports high latency. No Step7C, anatomical accuracy, counting accuracy or real Firebase workout acceptance pass |

**NOT IMPLEMENTED as real business workflows:** paid membership/consultation confirmation, payment/refund execution, completed consultations, rescheduling, earnings, certification verification, rewards/ledger, mini-game pose scoring, chatbot integration, advanced Admin/Coach aggregates/recommendations and notification delivery. Existing UI/mock assets remain; Firebase mode must not represent them as real data. The supported booking outcome is pending hold → cancelled or expired, not paid/confirmed/completed.

Account suspension/reassignment still does not automatically withdraw an already published Coach projection. Trusted schedule/booking commands recheck current memberships/branches; this does not turn directory publication into certification verification. Existing compute service account has Editor; this pre-existing broad role was not added by this task and should receive a separately reviewed least-privilege audit. Controlled debug App Check must be replaced by validated production attestation before a release build.

## Evidence and operational handoff

Sanitized local evidence remains ignored under `build/firebase-demo-preparation/`: `exact-head-ci.json`, `repairs-red.log`, `repairs-green.log`, `backend-unit.log`, `lifecycle-java21.log`, `live-state-after.json`, `booking-integrity-latest.json`, `worker-batch-evidence.json`, `availability-crud-all-days.json`, `availability-transport-evidence.json`, `preservation-result.json`, `phone-update-result.json` and `phone-history-preservation.json`. Private identity/token/rollback files remain in the private subdirectory; do not publish that directory or raw device/browser logs. The browser's booking list exposes raw participant UIDs, so no unsanitized full screenshot is included in this public report.

The [checklist](../../SUPERVISOR_DEMO_CHECKLIST.md) contains exact local launch/build commands, role instructions, demonstrated transitions and rollback boundaries. Existing deployment order was followed: exact-head CI → snapshots/READY indexes/APIs → compatible readers/precise Rules → identities/policy/clients/App Check → authoring/private worker/options → hold creator last → cancellation/replacement/elapsed-time expiry. No Hosting deployment. Local server must remain running for Admin Web; a later new hold needs a still-future window and will consume the real policy cap until closed/expired.

Future rollback must stop new hold creation first, coordinate Scheduler/worker changes and preserve compatible terminal-state readers. Never restore old booking/lock/accounting snapshots over later activity; retain receipts/jobs/history. Phone rollback requires certificate/data compatibility and a new preservation check; no uninstall/data clear. Do not activate tutorial media, paid confirmation or Step7C under this task. The deployed/client integration artifact uses only the four-file R1/R2 repair; the owner's later performance request is separated below.

Final verification at01:21Z confirmed all14 Functions ACTIVE, the original five revisions/update times unchanged, all six indexes READY (three existing/three added), exact reviewed Firestore Rules and original Storage Rules, enabled intended Scheduler/OIDC and genuine verified Coach Auth. Read-only booking integrity passes for both closed records with zero daily reservations and completed matching jobs. Remote branch remains exactly588c7ab; exact-head CI backend/flutter jobs and every verification/build step succeeded. Both new handoff documents and the four committed repair paths passed a bounded private-material scan (including known private Coach identifiers/email) and relative document-link checks. This scan is additional hygiene evidence, not a claim to audit every historical artifact or private log. New execution documents remain local/uncommitted for review; no historical report was overwritten.

## Later owner request: slow save/retrieval

After the completed CRUD smoke, owner reported slow saves/retrieval and requested optimization. Read-only real Cloud Run HTTP timing confirms Availability save12.9–17.2s, load3.5–7.2s, options15.1–17.8s and hold create17.2–17.8s. These are server request durations, not device end-to-end or pose latency. Current handlers await normally48 separate lock reads per date; Functions/Firestore region separation adds network exposure, but no precise causal allocation or cold-start fraction is claimed.

The [bounded performance repair](../planning/2026-10-15-coaching-read-performance.md) is locally committed as **6dd91d90980dcd351b9f3aec297f0e885aa60b30**, parent588c7ab. Exactly six paths,132 additions/7deletions: [transaction port/helper](../../functions/src/platform/firestore/store.ts), [native adapter](../../functions/src/platform/firestore/firestore-store.ts), [availability service](../../functions/src/modules/coaching/coach-availability-service.ts), [booking date validation](../../functions/src/modules/coaching/booking-validation.ts), [four focused regressions](../../functions/test/coaching-batch-reads.test.ts) and the linked plan. Native transactional getAll reads the same complete day/lock sets; no schema, Rules, identity, write-set, App Check, pose or phone changes.

Backend307/307, build/typecheck, architecture/analysis and independent review pass. Relevant emulator CRUD/read tests pass; initial lifecycle contention error and the successful unchanged3/3 rerun are both documented. Logs: coaching-batch-red/green/unit/build/typecheck/emulator/lifecycle-rerun/architecture/analysis under the ignored evidence directory. Under the owner's current optimization/integration authorization, guarded fast-forward pushed only6dd91d9 after independent review; remote SHA confirmed. **PASS:** [Exact-head CI38666339474](https://github.com/Haise0619/gainpath/actions/runs/38666339474), both jobs and all architecture/analysis/tests/emulator/AdminWeb/Mobile mock-build steps completed successfully. Downloaded logs confirm307 unit tests/16files and61 emulator tests/10files.

**PASS — selective performance deployment**, completed01:48Z. All four new revisions ACTIVE/Node22:

| Function | New revision |
|---|---|
| getCoachAvailabilityCommand | getcoachavailabilitycommand-00002-zay |
| saveCoachAvailabilityDayCommand | savecoachavailabilitydaycommand-00002-rir |
| getMemberBookingOptionsCommand | getmemberbookingoptionscommand-00002-qah |
| createBookingHold | createbookinghold-00002-fit |

Read-back confirms **ten other Functions unchanged**, including original five and cancellation/expiry. Protected content/org/branch/Member scopes and63 unrelated worktree entries unchanged; both closed bookings retain proper accounting/jobs. Private debug exchange still succeeds, and missing/invalid App Check or missing Auth requests still return401. No region migration, Scheduler/Rules/index deployment, APK reinstall or always-warm billing change. Original Function configs and588c7ab source privately snapshotted for rollback. Existing CLI image-cleanup warning repeated; no destructive cleanup.

**Post-update live smoke:** actual Admin browser loads the same permitted schedule. Owner Coach edit/restore produced revision5 at01:49:29.396Z and revision6 at01:49:46.888Z; restored09:00–11:00/main, receipts retained, owner confirms it feels faster. Member then loaded the permitted date/branch options without another hold and reports a small improvement.

| Cloud Run HTTP request boundary | Before, seconds | After, seconds | Interpretation |
|---|---|---|---|
| Availability save |12.917–17.237,n4|2.174–4.960,n2|Two real post-release saves completed and restored the original window |
| Availability read |3.468–7.183,n10|2.116–4.866,n4|First post-release read4.866; subsequent observed reads2.116–2.202. Coach and actual Admin UI still show correct scoped windows |
| Member booking options |15.124–17.832,n6|8.324,n1|Real Member observed permitted options; faster but still slow; proposed under5s target not reached in this sample |
| Hold creation |17.186–17.833,n2|Not measured|New handler source/emulator verified; no extra live hold created solely for timing |

These small, nonrandom live samples demonstrate specific request durations; they do not establish P95, exact UI roundtrip, cold-start attribution or a universal speedup percentage. Remaining sequential scope/identity transactions and region separation are possible next optimization areas, not permission to cache authorization or migrate regions. No further tuning loop was started. Pose latency is unrelated and unchanged.
