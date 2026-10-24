# P8.1B-R — Revised rename, media activation and rollback plan

**Current proposal; review only.** This supersedes the earlier URL-only/no-rename activation scope. The user intends the rename but explicitly restricted this task to impact review and preparation. No source fix, deployment, live edit, publication or device update is authorized by this document.

Read the [rename impact audit and exact diff](../architecture/2026-10-14-p8-1br-exercise-rename-impact.md), [validated media preflight](../architecture/2026-10-14-p8-1b-read-only-preflight.md) and [general activation handoff](p8-1b-tutorial-activation-handoff.md). Media passed URL/HTTP/range/full-software-decode checks; Xiaomi playback remains unverified.

## Frozen proposed scope

| Item | Exact value |
|---|---|
| Project/organization | `gainpath-0619` / `gainpath` |
| Catalog path/ID | `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX` |
| Rename | **Codex Verification Squat → Bodyweight Squat** |
| Video reference | Private verified Download URL for `gainpath-0619.firebasestorage.app` / `tutorials/bodyweight-squat-v1.mp4` |
| Media generation/hash | `1791941383409337`; SHA-256 `f9dedee1c818af39f4ee4e8970316805399f24f96d387dfee72b59cc51e86b9e` |
| Changed catalog values only | `exerciseName`, `videoUrl`, server `updatedAt` |
| Preserved catalog values | Existing ID, schema 1, `Compound Lower-Body`, active true, original `createdAt`, every other field |
| Blueprint | `PTe4DxLS3WZ2DsfpGTOy` — **Codex Verification Routine**, 45 minutes |
| Published content | `routine_PTe4DxLS3WZ2DsfpGTOy` — same title/source/45-minute duration |
| Targets | Day 1, `F3b8xIr8ynBDd3gEICKX`, 3 sets × 8 reps; all other approved targets preserved |
| Binding/policy | Existing `bodyweight-squat-side-v1` and detector/model/view; `ENABLED_WORKOUT_TUPLES` stays empty |
| Publisher | Only `publishRoutineCommand`, `us-central1`, Node.js 22 |

No new exercise, blueprint title change, routine title change, history relabeling/backfill, schema migration, media upload/token rotation or Step 7C work is included.

## Gate 0 — Resolve catalog concurrency protection before activation

**Current blocker:** the existing Admin `save()` blindly updates six fields and discards edit revision metadata. Its stale form can overwrite a concurrent category/status/name/video edit. It supports the values but does not satisfy the safe-update requirement.

**Recommended separately approved source increment:** preserve an immutable edit baseline/revision through the existing catalog port/form, compare it against the transaction's current document, abort on stale baseline/account loss, and update only fields actually intended by the editor plus server timestamp. The rename/video operation must leave category/status/schema/creation/other fields untouched. Use existing package/composition patterns; do not add Firebase types to pure-Dart domain APIs or create a parallel repository stack.

Files to inspect for that bounded change: [TutorialVideo](../../packages/gainpath_domain/lib/src/workout/entities/tutorial_video.dart), [TutorialRepository](../../packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart), [Firebase catalog adapter](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart), [Admin form](../../apps/admin_web/lib/features/workout/presentation/admin/exercise_tutorials_screen.dart), existing Admin content mapping/authoring tests. Whether to use an opaque revision or an app-local edit snapshot belongs to that approved design; no remote catalog/workout schema change is necessary.

Required verification for the fix: stale category/status/name/video edits are rejected and the other author's changes survive; clean rename/video commit changes exactly the intended fields; `createdAt`/ID/other fields remain intact; transaction retries do not adopt a new baseline silently; account/role change denies save; errors do not print token-bearing URLs; create/mock flows remain valid; Admin tests, checker and CI pass. Do not silently drop unexpected existing fields to make strict Rules pass. A transaction alone without original-baseline comparison is insufficient.

Alternatively, the user may separately authorize a reviewed one-off conditional three-field write with Firestore `updateTime` precondition and verified author authorization. That avoids claiming the blind Admin UI is safe but does not repair its general concurrency gap. Do not select an IAM/Rules bypass automatically. **Neither route is implemented or authorized now.**

## 1. Capture before-state and authorization

After the safe route is approved/verified, confirm approved source head/lock/config and preserved working tree. The tutorial source is `58efe0e`; any approved concurrency-fix commit needs its own review/CI evidence before activation.

Re-read and privately snapshot the complete target catalog, blueprint, published content and Firestore document revisions. Current observed catalog metadata revision is `2026-10-02T01:20:14.697765Z`; field `createdAt` and `updatedAt` are both Timestamp `2026-10-02T01:20:14.658Z`. These are distinct types/meanings. Do not reuse this cached revision without rechecking current state; stop for review if protected fields, references or targets drift.

Use the verified active, email-verified organization Admin/Staff identity for edit/publication. Operator CLI IAM access alone is not proof of that client role. Check deployment permissions/project separately. Fetch the existing Storage token URL into memory; verify generation/hash/policy again, and never place the full URL in Git, logs, public before/after JSON or screenshots. Store any necessary URL-bearing rollback state privately with restricted access or use an approved private snapshot mechanism; public manifests contain IDs and fingerprints only.

Capture the publisher's actually deployed revision/source. Earlier inspected revision `publishroutinecommand-00001-xoy`, source generation `1790863446464832`, and private source archive remain rollback evidence; recheck rather than assuming it has not changed.

No Member workout/consent data needs cloud mutation. For phone preservation, record visible local history/progress/outbox/consent state before tutorial trials, and pull/hash the **actually installed** APK before replacement. A historical password-reset APK is a fallback, not proof of the current installed version.

## 2. Selective publisher deployment

After deployment approval, build/test the approved source with locked dependencies and isolated `demo-gainpath` emulators. From repository root, the only proposed deployment command is:

```powershell
firebase deploy --project gainpath-0619 --only functions:publishRoutineCommand
```

Verify readiness, `us-central1`, runtime and new revision. Do not deploy other functions, Rules, indexes, Storage or Hosting. The deployed publisher already snapshots catalog names but lacks the new video projection; deployment is needed for media, not for changing identity. No pose/scoring or acceptance callable is touched.

## 3. Atomic exact catalog rename and video update

After live-write approval and using the verified concurrency-safe route, apply to **the existing ID only**:

```text
exerciseName: "Codex Verification Squat" → "Bodyweight Squat"
videoUrl:    [private prior URL] → [private verified uploaded-MP4 URL]
updatedAt:   [prior Timestamp] → [authorized server commit Timestamp]
```

The changed-field set is exactly those three. Preserve all current protected/unrelated values. Do not invoke duplicate creation, full-document replacement or the unguarded stale-form save. On revision mismatch, deny the write and reload/review; do not automatically overwrite the latest author's values. Read back the new name and privately compare the URL/media identity; report only booleans/fingerprints. No blueprint edit is needed.

## 4. Trusted republishing with a fresh operation

After publication approval, verify the same current blueprint/catalog identity/targets/name/media and publish **`PTe4DxLS3WZ2DsfpGTOy`** through the trusted `publishRoutineCommand`:

```json
{
  "schemaVersion": 1,
  "requestId": "NEW_UNIQUE_OPERATION_ID",
  "organizationId": "gainpath",
  "blueprintId": "PTe4DxLS3WZ2DsfpGTOy"
}
```

A fresh operation copies current `source.exerciseName.trim()` and validated video URL into the published row. Same actor/request/payload returns the old receipt; it cannot refresh a rename/video change. Changed payload under the same request ID is rejected. Retain an unresolved operation ID for controlled retry. The current Admin Publish action generates a new ID on every click; inspect receipt/content after an ambiguous response before clicking again. Do not erase receipts or directly patch `content`.

This transaction replaces only `routine_PTe4DxLS3WZ2DsfpGTOy` and creates its receipt. Other published snapshots do not auto-rename; the current reference audit found no other content/blueprint documents. Recheck if inventory changes. Publisher reads are transactionally consistent, but the command does not carry expected catalog/blueprint revisions; enforce pre-call and read-back drift gates rather than claiming a source lock.

## 5. Read-back name, identity and target gate

Verify all of the following before device rollout:

- Catalog ID `F3b8xIr8ynBDd3gEICKX`, **Bodyweight Squat**, private correct video URL; protected fields equal the approved before-state.
- Content ID `routine_PTe4DxLS3WZ2DsfpGTOy`; schema 1, published routine, source blueprint `PTe4DxLS3WZ2DsfpGTOy`.
- Published exercise row: same ID/day 1/3×8, **Bodyweight Squat**, expected category/muscle group and privately matching video URL.
- Root blueprint and routine title remain **Codex Verification Routine**; duration remains **45 minutes**; every target matches the approved before-state.
- Only expected catalog/content/receipt changes occurred; no history/session/consent/outbox/reward/model-policy changes.

If a concurrent legitimate source edit appears, stop rather than restoring over it automatically. The current Member server query selects this routine; restart/re-enter the authenticated shell to reload its cached future. Member exercise labels update from the published row; the routine header keeps its original title. Old open routes/snapshots need not update in place. Historical ID-based records stay unchanged.

## 6. Named Firebase development APK and Xiaomi trial

After build/install approval, use the approved source head and Flutter 3.38.9/Dart 3.10.8 lockfile. Reconfirm the actual phone/configuration and preserve its APK/signing identity/data before building a new named artifact under ignored `apps/mobile/build/p8-1b-tutorial-activation/`.

Last documented phone defines, to confirm rather than silently alter:

```powershell
flutter pub get --enforce-lockfile
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true
```

Preserving the existing experimental phone configuration does not change the production/default CPU pipeline or start Step 7C. Record source/APK SHA, signing/package/version/defines; never overwrite historical artifacts. Confirm Xiaomi 23013RK75C/actual serial before `adb ... install -r`; do not uninstall, clear data or force a downgrade on conflict.

Trial both Watch tutorial and the exact routine row. Verify exercise **Bodyweight Squat**, unchanged **Codex Verification Routine** header and 3×8 target; real 15.807s portrait video/audio; play/pause/seek/replay; background/lock/return and close/reopen; logout/account switch; connectivity/error/retry; unchanged pre/post history/progress/consent/outbox. HTTP range/full software decode evidence does not replace these physical trials. Do not launch a squat, create records/rewards or modify policy. Missing/failing cases remain unvalidated; propose any fix separately.

## 7. Independent rollback plans

| Layer | Authorized rollback approach |
|---|---|
| Catalog | Compare current revision/values with the activation's expected after-state. Restore only prior `exerciseName`, private `videoUrl` and a **new normal server `updatedAt`**, through the safe guarded path. Do not reset `updatedAt` to an old timestamp or overwrite another author's later edits. Preserve ID/category/status/schema/creation/other fields. |
| Published content | After approved catalog restoration, issue a new trusted publication and verify old exercise name/media semantics with unchanged routine title/targets. Keep receipts. Catalog rollback alone does not undo a published snapshot. Exact old publication timestamps are not recreated. If the captured historical snapshot cannot be reconstructed by current trusted authoring (for example old omitted media versus currently valid prior URL), stop for a specifically reviewed restoration instead of direct-patching content. |
| Publisher | If required and separately approved, selectively restore the captured previous publisher source/revision only. It does not remove already-published name/media data; reconcile content independently. Preserve archive/hash and never reset the shared branch/deploy unrelated functions. |
| Phone | Update-install the actually captured compatible prior APK after approval, preserving app data and documented defines. A previous APK may still display newly published names; app rollback is not content rollback. Stop if signature/version recovery would require uninstall/data clearing. |
| Media/history/policies | No deletion, token rotation, media change, historical workout migration, consent/outbox reset or tuple change is included. |

## Approvals and stopping gate

1. Approve a bounded **catalog stale-edit protection source fix**, or explicitly select a reviewed one-off conditional write route. Existing blind Admin save is not acceptable for the requested concurrency guarantee.
2. Approve **only `publishRoutineCommand` deployment** in the named development project.
3. Approve the **atomic existing-record rename + URL update** and normal server timestamp under the safe route.
4. Approve **trusted republishing** of the named blueprint with a fresh operation ID, without changing title/targets.
5. Approve **Firebase APK build/update-install and Xiaomi tutorial playback trials**, after actual installed-APK/data preservation.

The intended rename is understood. **Wait for explicit execution authorization**; this review did not implement the prerequisite, deploy, write, republish, install, change historical records or start Step 7C.
