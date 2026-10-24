# P8.1B — Member tutorial live activation handoff

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

> **2026-10-14 rename update:** The latest requested scope includes renaming the same existing exercise to **Bodyweight Squat**. Follow the [revised rename activation/rollback plan](p8-1b-bodyweight-squat-rename-activation-plan.md) and [impact audit](../architecture/2026-10-14-p8-1br-exercise-rename-impact.md). The general authoring instructions below do not establish stale-edit protection: current Admin save is blind, so its concurrency-safety prerequisite must be resolved before any live edit. Deployment/write/publication/install remain unapproved.

**Prepared only; not execution authorization.** P8.1A passed [exact-head CI](https://github.com/Haise0619/gainpath/actions/runs/38402844745) for `58efe0e1edeea6161da1bce75da823e3d6927077`. The user accepted software integration, not physical playback. Every deployment, live record edit, publication and device installation below waits for further approval. No activation operation was executed while preparing this handoff.

**Objective:** Activate one real, licensed tutorial for a verified published exercise and validate the existing Member viewing workflow on Xiaomi, preserving all data and the separate Step 7C workstream. No new player/catalog feature, pose tuning, workout capture, tuple enablement or rewards work is included.

## Current facts and items to resolve

| Item | Current evidence / required decision |
|---|---|
| Source | Three accepted tutorial commits ending at `58efe0e1edeea6161da1bce75da823e3d6927077`; both CI jobs green. [Implementation report](../architecture/2026-10-13-member-tutorial-playback.md), [P8.1A report](../architecture/2026-10-13-member-tutorial-playback.md). |
| Project | Local `.firebaserc` maps `dev` to `gainpath-0619`; mobile/admin Firebase options agree. Reconfirm intended development project and deployed publisher metadata before any mutation; no remote state was inspected in P8.1A. |
| Media | No candidate URL, licensing grant, availability or Xiaomi decoding has been verified. Choose actual media and record permission before writing a live URL. |
| Identity | Organization, blueprint, published routine, exercise ID and day/targets must be captured from actual authorized records. Historical squat ID `F3b8xIr8ynBDd3gEICKX` under organization `gainpath` is context, not an authorization to edit it or proof that a selected video depicts it. Never select by title alone. |
| Admin | Existing verified active Admin/Staff account in the same organization; no new account/provisioning or Hosting deployment is authorized. Use the existing Firebase-mode Exercise Tutorials/Routine Templates UI after verifying its code/configuration. |
| Phone | Latest documented device: Xiaomi 23013RK75C, serial `xiaomi-device-serial-redacted`, package `com.zyang.gainpath`. Confirm the connected device and installed build in P8.1B; do not assume the historical APK is still installed. |

## 1. Capture a bounded pre-activation manifest and rollback state

After approval, record the approved SHA/lockfile, project, operator role/organization, target exercise/blueprint/content IDs and selected media fingerprint. Store full token-bearing URLs and any record exports privately outside committed reports; sanitized reports use exercise IDs and media hashes instead. Save the complete target catalog and published-content before-values with timestamps and the current blueprint references. Record the actually deployed publisher revision/source rollback artifact; a Git SHA alone does not identify the deployed revision.

Read and hash the actual installed APK before replacement. Keep existing password-reset, dashboard, Step 6 and Step 7 APKs/reports intact. Record local dashboard/history counts and consent/upload status without initiating uploads. If a rollback package cannot be reinstalled with the same signing identity, stop before replacing the current app. Do not uninstall, clear app data, reset credentials or delete local workout/outbox records.

**Gate:** Approved project, records, media, operator, artifact and rollback plan are explicit. Deployment/live-write/install approval covers these exact targets; unresolved targets stop dependent operations.

## 2. Select and validate licensed playable media

Use an owned recording or documented permission/license that covers distribution and in-app streaming; retain attribution/consent obligations and relevant expiry/retention conditions. Verify the video demonstrates the exact intended exercise, equipment, setup and movement, rather than relying on its filename. Tutorial review does not validate GainPath's pose/form scores.

The source validators are [backend tutorial-media.ts](../../functions/src/modules/content/tutorial-media.ts) and [Member tutorial_media.dart](../../apps/mobile/lib/features/workout/domain/tutorial_media.dart). Supported input is a trimmed absolute HTTPS URL, at most 2048 characters, ASCII DNS/IPv4 host and valid port, direct `.mp4` path; no userinfo, fragment (even empty `#`), backslash or whitespace/control characters. Signed query strings are allowed. HTML/YouTube/share pages, HTTP, `file:` and `gs:` URLs are unsupported. Do not weaken the policy to admit unsuitable media.

After separate activation approval, verify actual responses and playback: the URL returns video bytes with an appropriate media type, has no browser-session dependency, and its redirects/TLS/token lifetime allow the Member app to load and seek. A `.mp4` suffix or HEAD success does not prove decoding. Record actual video/audio codec, size, duration, dimensions, license and observed playback; choose the final encoding only after the target phone can decode it. Check seek/range behavior through the real player. Never persist Firebase Auth credentials in media URLs or public reports.

**Gate:** The selected URL passes both validators and genuinely streams/decodes; rights and exercise identity are documented. Media upload/new Storage objects, bucket permissions or Hosting changes require their own explicit approval if needed. Prefer an already authorized hosting location; no upload is implied by this handoff.

## 3. Author the exact Exercise Catalog URL

Use existing Firebase-mode **Exercise Tutorials** edit/save, backed by [FirebaseExerciseCatalogRepository](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart), for the approved document `orgs/{orgId}/exerciseVideos/{exerciseId}`. Preserve its ID, name/category and intended active/draft status; do not create a replacement ID just to attach media. Confirm it is an active source eligible for the selected routine.

The physical schema is `schemaVersion:1`, `exerciseName`, `muscleCategory`, `videoUrl`, `isActive`, `createdAt`, `updatedAt`. The catalog UI currently checks a nonempty URL and its length, not full tutorial playback policy; saving successfully is insufficient proof that publication will include it. Do not infer difficulty, thumbnail, duration or generic form prose from prototype fields.

Verify the authorized saved document contains the intended trimmed URL and unchanged identity. Do not bypass the UI/Rules with broad Admin SDK edits. Catalog changes alone do not update existing published snapshots. Keep Members unable to read the staff-only catalog; do not deploy relaxed Rules.

**Gate:** Exact catalog read-back and before/after comparison succeed, with no unrelated field/document change. This is a separately approved live write.

## 4. Deploy only the trusted publisher, after an explicit deployment gate

Required source: [publish-routine.ts](../../functions/src/modules/content/publish-routine.ts), [tutorial-media.ts](../../functions/src/modules/content/tutorial-media.ts), exported [publishRoutineCommand](../../functions/src/modules/content/publish-routine-callable.ts) via [index.ts](../../functions/src/index.ts). The project uses Node.js 22 / second-generation callables. Clients use the default Firebase Functions instance; confirm the deployed callable's region/endpoint matches before changing resources. No schema/Rules/index deployment is needed for this optional row field.

Future commands, **not executed**:

```powershell
# From functions, after confirming the exact approved checkout and environment:
pnpm install --frozen-lockfile
pnpm run build
pnpm run typecheck:tests
pnpm test
# Isolated demo-gainpath emulator checks, never real activity:
pnpm run test:emulator

# From repository root, ONLY after explicit selective deployment approval:
firebase deploy --project gainpath-0619 --only functions:publishRoutineCommand
```

Do not use broad `firebase deploy`, the broad `functions` package deploy script, or select workout/identity/payment callables, Rules, indexes, Storage or Hosting. Use already installed compatible tooling; do not upgrade dependencies during activation. Record deployment output/revision and confirm successful readiness. If additional resources, credentials or compatibility fixes are needed, stop and report the concrete blocker.

**Gate:** Only the approved publisher is changed remotely; metadata and rollback source are captured. A build/deploy success still does not establish real media playback.

## 5. Republish through the trusted command with deliberate request IDs

After catalog verification and publisher readiness, publish the exact approved blueprint using **Routine Templates → Publish**, backed by [FirebaseRoutineTemplateRepository](../../apps/admin_web/lib/infrastructure/firebase/firebase_routine_template_repository.dart). Server auth requires verified active Admin/Staff assigned to that organization. The blueprint supplies exercise IDs/sets/reps; the server copies media from the referenced active catalog record. Do not send client-authored exercise arrays/video overrides or directly patch `content`.

The command contract is exactly:

```json
{
  "schemaVersion": 1,
  "requestId": "NEW_OPERATION_ID",
  "organizationId": "APPROVED_ORGANIZATION_ID",
  "blueprintId": "APPROVED_BLUEPRINT_ID"
}
```

IDs use 1–128 letters/digits/underscores/hyphens. A deliberate new publication after media changes needs a **fresh** request ID. Same actor + same request ID + same payload returns the saved receipt without re-reading the catalog or refreshing media. Reusing the ID with a different payload is rejected. A new publication replaces the existing document `orgs/{orgId}/content/routine_{blueprintId}` and creates a new command receipt; it does not create a workout or rewards event.

Current Admin behavior creates a fresh random/timestamp ID on **each Publish invocation** and does not retain an unresolved ID for a user-initiated retry. If the response is lost, do not claim another click is a same-ID retry: inspect the content/receipt first and reconcile success. Any separately approved controlled retry must retain the original actor, payload and request ID. Do not erase receipts to force refresh. Durable publication retry UX is a known later improvement, not part of P8.1B.

**Gate:** Capture the returned content ID and request ID/receipt when available, then verify the server projection. A toast alone is not the gate.

## 6. Verify Firestore projection and Member selection

After the approved publication, authorized read-back must confirm `schemaVersion:1`, `kind:'routine'`, `status:'published'`, expected `sourceBlueprintId`, title/duration, and every intended row's exact `exerciseId`, `dayNumber`, sets/reps and optional `videoUrl`. Match by ID and day/row position; duplicate display names are insufficient. Compare targets before/after; media activation must not silently alter the measured workout binding or targets. A syntactically unsupported URL is omitted by the publisher without rejecting valid targets, so explicitly check its presence/value.

Verify published data is readable by a verified active Member in the same organization. Existing isolated tests already cover draft/cross-org/unverified/inactive denial, staff-catalog denial and Member write denial; do not create live invalid accounts/fixture records to repeat them. Use separately approved accounts/read-only checks where available, otherwise retain emulator evidence and mark physical authorization cases untested.

[FirebasePublishedRoutineRepository](../../apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart) currently queries published routine content with `limit(1)` and no explicit ordering/selection; [MemberShell](../../apps/mobile/lib/app/shells/member_shell.dart) loads it at initialization. Republishing a different routine does not guarantee the app selects it. Identify the actually returned routine, or agree an approved content-selection change separately; do not retire/delete other routines to manufacture selection. Restart/re-enter the authenticated shell to fetch a fresh server snapshot. Progress refresh does not refresh the routine future.

**Gate:** The Member actually displays the approved published routine and exact media-bearing exercise, including correct duplicate-name mapping where applicable. Catalog success without this check is incomplete activation.

## 7. Prepare the Firebase APK and test Xiaomi, only after build/install approval

Pin the approved SHA, Flutter 3.38.9 / Dart 3.10.8 and lockfile. CI built mock-mode apps; create a named Firebase development profile artifact for the later trial. Historical phone defines are below; confirm the actually installed configuration and preserve it before building. They keep the existing experimental GPU/direct-refined/performance baseline; they do not make it the production CPU default or authorize Step 7C tuning.

Future build command from `apps/mobile`, **not executed**:

```powershell
flutter pub get --enforce-lockfile
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true
```

Store a separate named APK and build log under a new ignored `apps/mobile/build/p8-1b-tutorial-activation/` directory; record SHA-256, package/signing identity, version and all defines. Do not overwrite historical Step 7 or password-reset APKs. After install approval and pulling/hashing the current installed APK, use update installation on the confirmed Xiaomi; never uninstall/clear data. Example future command: `adb -s xiaomi-device-serial-redacted install -r <verified-activation-apk>`; recheck serial rather than blindly using the historical value. If Android refuses the update/signature/version, stop instead of resetting the app.

Record the actual phone/OS/build/network, account scope and exercise/content IDs, sanitized screenshots and outcomes for these cases:

| Trial | Required observed behavior |
|---|---|
| Watch tutorial and View routine | Both reach the correct published exercise/targets; first-entry shortcut and per-row selection are distinguished. No live skeleton demo fallback. |
| Load and controls | Real first frame, actual duration, play/pause, seek and replay; no autoplay; video/audio content matches reviewed media. Record actual latency, not an assumed threshold result. |
| Background/lock/return and close | Playback/audio stop as expected; return does not auto-resume; reopening works. Exercise delayed startup/control and repeated open/close without native errors. |
| Logout/account switch | Old viewer releases/hides content and cannot control a prior player; new account uses its authorized scope. Check no old workout/history leaks. |
| Missing/failed media and connectivity | Existing missing-media state is truthful; with approved test media/failure setup, load failure is sanitized/retryable. Airplane-before-load and restore/retry work as observed. Mid-play may consume buffered bytes; that is not durable offline support. Persistent buffering/stalls are recorded as failures, not inferred timeout passes. Do not mutate an unrelated live record just to create a failure. |
| Data preservation | Dashboard/history/outbox counts and consent settings remain unchanged from the pre-test snapshot. Tutorial viewing creates no workout session, accepted record, upload request or reward. |

Initialization/control software timeout is 20 seconds; measure physical behavior independently. Streaming continuity, codecs/audio/resource lifecycle and Xiaomi performance are unvalidated until these trials pass. No cache/offline-completion guarantee is added by this slice. Tutorial testing does not launch a guided squat or collect pose media.

## 8. Rollback and final acceptance

- **Content rollback:** Stop new publications. With explicit live-write approval, restore only the approved catalog before-values through existing authoring. A previously published snapshot remains unchanged by a catalog-only rollback; to restore Member-facing content, use a reviewed trusted republish with a new request ID and verify the restored projection. Preserve command receipts and untouched records. If an exact historical snapshot cannot be reconstructed by current authoring, stop for a specifically reviewed restoration rather than direct-patching content.
- **Backend rollback:** If necessary and approved, deploy only the previously captured publisher source/revision. Old publisher behavior omits media on future publications; rolling it back does not remove already published URLs. Reconcile content separately. Do not redeploy workout functions or weaken tuple/consent policy.
- **Device rollback:** Update-install the captured compatible prior APK only after approval; preserve app data. If it requires destructive recovery, stop for a new decision. Restore the documented experimental defines/build artifact for the independent Step 7C workstream.
- **Media rollback:** Do not delete shared media or revoke URLs blindly. Determine usage and approvals; content snapshots can retain old URLs. Record authorized retirement separately.

**Definition of done:** Approved media rights and exact identity documented; selective deployment and authorized catalog/republish evidence recorded; actual Member projection selected; named Firebase APK tested on Xiaomi with all supported playback/lifecycle/data-preservation trials passing or explicit failures; rollback evidence retained. Write a sanitized physical-results report distinguishing software CI from phone outcomes. Missing trials remain unvalidated. No enabled-workout-tuple, acceptance-policy, scoring, pose parameter or Step 7C status changes are implied.

**Stopping point:** Review this handoff and obtain explicit activation approval for the named project/media/records/deployment/build/install scope. P8.1A ends here; this document does not authorize executing any P8.1B step.
