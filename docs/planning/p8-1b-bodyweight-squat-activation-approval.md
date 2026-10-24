# P8.1B — Concrete Bodyweight Squat activation approval plan

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

> **2026-10-14 rename revision:** This file preserves the earlier URL-only/no-rename proposal. The user's new intended name is **Bodyweight Squat** on the same ID. Use the [revised rename activation/rollback plan](p8-1b-bodyweight-squat-rename-activation-plan.md), which supersedes this proposal's frozen-name scope and adds a catalog concurrency-protection gate. No operation is authorized by either document.

**Prepared after read-only preflight; not executed.** See [2026-10-14 findings](../architecture/2026-10-14-p8-1b-read-only-preflight.md) and the [general activation handoff](p8-1b-tutorial-activation-handoff.md). All live writes, selective deployment, republishing and device installation below require the user's further approval.

## Frozen scope

| Item | Exact target |
|---|---|
| Accepted software | `58efe0e1edeea6161da1bce75da823e3d6927077`; [CI success](https://github.com/Haise0619/gainpath/actions/runs/38402844745) |
| Firebase project / organization | `gainpath-0619` / `gainpath` |
| Uploaded media | Bucket `gainpath-0619.firebasestorage.app`, object `tutorials/bodyweight-squat-v1.mp4`, generation `1791941383409337` |
| Media SHA-256 | `f9dedee1c818af39f4ee4e8970316805399f24f96d387dfee72b59cc51e86b9e` |
| Exercise Catalog | `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX`, currently **Codex Verification Squat**, active, schema 1 |
| Blueprint | `orgs/gainpath/routineBlueprints/PTe4DxLS3WZ2DsfpGTOy` |
| Published routine | `orgs/gainpath/content/routine_PTe4DxLS3WZ2DsfpGTOy`, currently **Codex Verification Routine** |
| Unchanged targets | Same exercise ID; day 1; 3 sets × 8 reps |
| Publisher deployment | Only `publishRoutineCommand`, `us-central1`, Node.js 22 |
| Phone | Confirm Xiaomi 23013RK75C / historical serial `xiaomi-device-serial-redacted`; none attached during preflight |

The approval should explicitly permit reusing the existing verification-named exercise/routine for this tutorial. No new ID or display-name change is included. Media is accessible, both validators accept its URL, and full software decode passes; physical Xiaomi playback remains pending. Confirm permission to distribute/use the chosen footage. Do not alter or re-encode the uploaded asset unless a later device result warrants a separately reviewed change.

## Ordered execution after approval

### Gate A — Recheck state and prepare rollback

- Confirm the exact branch/head, clean staged area and preserved unrelated working-tree edits. Re-read target record values/update times so another user's edits are not overwritten. Reacquire the existing Download URL from object metadata in memory; verify generation/media fingerprint still matches. Do not copy its token into a command, Git, public report or logged JSON.
- Capture token-private catalog/content before-values, source-generation/revision metadata and the media reference needed for rollback. Existing deployed revision is `publishroutinecommand-00001-xoy`, with captured source generation `1790863446464832`; recheck before deployment.
- Verify an active, email-verified Admin/Staff client account in organization `gainpath` for authoring/publication. Operator IAM read access alone does not satisfy callable role authorization. Check deployment permissions separately before attempting the approved deployment.
- Require the actual connected phone and pull/hash its currently installed compatible APK before any replacement. Historical password-reset fallback is `apps/mobile/build/password-reset-install/gainpath-firebase-password-reset-profile.apk`, SHA-256 `AF9B3AB15CFD58284493C35FD5A044EE47361A6A5E741CBD33108DC326A3612D`; do not assume it is still the currently installed version. Preserve all prior APKs and local workout/outbox data.

### Gate B — Selective backend deployment

From `functions`, run current locked dependency/build/typecheck/unit checks and isolated `demo-gainpath` emulator checks using compatible installed tooling. Then, **only after deployment approval**, from repository root:

```powershell
firebase deploy --project gainpath-0619 --only functions:publishRoutineCommand
```

Record the new deployed revision and confirm function readiness in `us-central1`. Do not use broad deployment scripts. No workout/identity/payment function, Rules, index, Storage or Hosting deployment is included. No acceptance tuple is enabled.

### Gate C — One catalog URL update

Through existing Firebase-mode Admin/Staff **Exercise Tutorials → Edit**, identify the exact ID `F3b8xIr8ynBDd3gEICKX` and set its Video URL to the in-memory verified URL. Retain **Codex Verification Squat**, **Compound Lower-Body**, schema 1 and Active; preserve `createdAt`. The only intended value change is `videoUrl` plus normal `updatedAt`. Do not expose the URL field in committed screenshots. Verify the saved reference matches the uploaded bucket/object/token privately, reporting only match/fingerprint results.

No blueprint target change is required. Catalog editing alone does not update the published snapshot.

### Gate D — Trusted routine republishing

Publish existing blueprint `PTe4DxLS3WZ2DsfpGTOy` through the trusted callable, using a **fresh** request ID. The token is not in the command payload; the server reads it from the approved catalog record.

```json
{
  "schemaVersion": 1,
  "requestId": "NEW_UNIQUE_REQUEST_ID",
  "organizationId": "gainpath",
  "blueprintId": "PTe4DxLS3WZ2DsfpGTOy"
}
```

Identifiers use 1–128 letters/digits/underscores/hyphens. Reusing an old successful ID returns the old receipt and will not refresh media. Reusing an ID with a different payload fails. A deliberate republish creates a new receipt and replaces the same published document. The current Admin repository creates a fresh ID for every Publish invocation; after a lost response, inspect the receipt/content before another click instead of pretending it is a same-ID retry. A controlled retry retains actor, payload and operation ID.

Read back `routine_PTe4DxLS3WZ2DsfpGTOy`: schema 1, published routine, correct source blueprint, exact exercise ID/day/3×8 targets, and privately verified matching video URL. Confirm no unrelated row/name/target or business record changed. No direct content edit, test workout, accepted session or reward is permitted.

### Gate E — Firebase APK and Xiaomi playback trial

Prepare a distinct named artifact and log directory under ignored `apps/mobile/build/p8-1b-tutorial-activation/`. After build approval and rechecking installed configuration, from `apps/mobile`:

```powershell
flutter pub get --enforce-lockfile
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true
```

Those are the last documented phone defines, not a proposal to switch default CPU behavior or tune pose analysis. Confirm them against the actual installed artifact before replacement. Record APK SHA/signing/package/version/source/lock/defines; CI's mock APK is not the Firebase test artifact. Do not overwrite existing APKs. After installation approval, update-install (`adb -s <confirmed-serial> install -r <verified-apk>`) without uninstall/data clearing; stop on a signature/version conflict.

Restart/re-enter the authenticated Member shell so its existing server future reloads. The preflight's exact `status=published`, `kind=routine`, `limit(1)` query returns `routine_PTe4DxLS3WZ2DsfpGTOy`; verify the device displays that actual identity/title. Do not remove other routines or change query selection just for this trial.

| Trial | Required observation |
|---|---|
| Both entry points | Watch tutorial and the exact View routine row show the correct exercise, day/3×8 targets and real uploaded clip; no live demo skeleton |
| Decode/display/audio | Portrait clip displays correctly without distortion; duration approximately 15.807s; real audio/video decode and readable controls; no autoplay |
| Seek/replay | Seek to early/middle/late positions and replay; actual time/frame/audio change correctly without sustained stall. HTTP range probes alone are not this result |
| Lifecycle | Background/lock/return, close/reopen and repeated viewing; stop audio/playback on background/close, no automatic resume, no native/resource error |
| Account boundary | Logout invalidates/disposes old viewer; same-account restoration and an approved account switch cannot retain old player/control ownership |
| Connectivity/error | Approved airplane/failure setup, restore connection and retry; honest error/buffering states, no raw token/native URL in feedback. Buffered bytes are not durable offline support |
| Data preservation | Same pre/post local workout/history/outbox/consent state; no session/acceptance/upload/reward created by viewing |

Do not launch a guided squat, capture pose/media evaluation data or interpret this video as labeled squat-accuracy ground truth. Keep Step 7C independently scheduled. If High Profile/1080p decoding, network/audio seeking or portrait UI fails, record the concrete failure and propose a bounded fix/transcode separately; do not silently change rules, player policy or media.

## Rollback and definition of done

- **Catalog/content:** With approval, restore only privately captured prior catalog values through existing authoring. Restore Member-facing content through a reviewed trusted republish with a new operation ID and verify targets/snapshot. A catalog-only rollback does not undo a published media snapshot; preserve receipts and all other records. No direct content patch is implied.
- **Publisher:** If necessary and approved, restore only the captured previous publisher source/revision. Preserve the private source archive and its hash; do not reset the shared branch or redeploy other functions. An old publisher does not remove URLs already in content, so reconcile content separately.
- **Phone:** After approval, update-install the captured compatible prior APK, preserving data and documented experimental defines. Do not force a downgrade/uninstall/clear on conflict. Restore the actual pre-activation APK rather than assuming a historical fallback is current.
- **Media:** The uploaded object is unchanged by this plan. No delete, token rotation, ACL/Rules change or re-encoding is included.

Done means approved writes/deployment are documented, the exact trusted projection is verified, the named Firebase APK passes the supported Xiaomi playback/lifecycle/data-preservation cases, and rollback evidence remains intact. Failures/missing trials remain explicit. No pose/scoring/result/consent/outbox/tuple/Step 7C status is changed by tutorial acceptance.

**Stop for review:** Approve the specified publisher deployment, reuse/URL update of the exact catalog record, trusted blueprint republishing, and named Firebase APK build/update-install/playback trial before execution. This handoff authorizes none of them by itself.
