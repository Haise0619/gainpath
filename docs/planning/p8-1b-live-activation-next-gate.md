# P8.1B — next live activation gate after Gate 0A

Preparation only. No Firebase deployment, live edit, publication or phone build/install is authorized by this document. Historical preflight and rollback reports remain intact. Final Gate 0A CI/browser evidence is recorded in the accompanying source integration report.

## Source and browser prerequisites

Use approved source `e14f877f8cf2eb333eab909891a1b4df0b0133ca` on `codex/real-squat-flow`, descending directly from tutorial head `58efe0e1edeea6161da1bce75da823e3d6927077`. Retain the locked Flutter 3.38.9/Dart 3.10.8 workspace and exact-head CI evidence. A different source SHA needs its own review/verification before activation.

**Outstanding pre-activation verification:** actual Flutter Web Admin editing against isolated Auth/Firestore emulators. The local Windows attempt compiled/launched Chrome but failed before the suite loaded because the Flutter test server returned 404 for local CanvasKit assets. No browser edit-flow assertions passed. Production callbacks and SDK transaction contract tests are supporting evidence, not substitutes for this gate.

Complete the retained synthetic browser harness in a compatible test environment, or use a reviewed isolated Admin web harness that avoids the broken test-server routing. Preserve source boundaries; do not patch the installed SDK or add/push new test infrastructure silently. Use demo-gainpath only and synthetic IDs/media. Verify real Firebase plugin behavior for clean name/video save, a separate authenticated editor's concurrent change, stale conflict, disabled Save, explicit discard/reload, fresh save, logout/account changes, membership/assignment drift and sanitized errors. Capture successful assertion/server-read evidence. Any necessary source fix is a separately reviewed increment; unresolved behavior blocks the live catalog operation.

## Exact later scope

| Resource | Approved intended identity/values |
|---|---|
| Project / organization | `gainpath-0619` / `gainpath` |
| Existing catalog | `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX` |
| Display name | `Codex Verification Squat` → `Bodyweight Squat` |
| Media | Private validated Download URL for bucket `gainpath-0619.firebasestorage.app`, object `tutorials/bodyweight-squat-v1.mp4` |
| Blueprint | `PTe4DxLS3WZ2DsfpGTOy` |
| Published routine | `routine_PTe4DxLS3WZ2DsfpGTOy` |
| Blueprint / routine title | Preserve `Codex Verification Routine` |
| Targets | Preserve Day 1, same exercise ID, 3 sets × 8 reps, and every other current approved target |
| Publisher | Only `publishRoutineCommand`, us-central1; no other Firebase resource |

No duplicate exercise, schema/rule/model/binding migration, history rewrite or Step 7C change is included. The current workout acceptance policy and ENABLED_WORKOUT_TUPLES remain unchanged.

## Ordered execution, after explicit approval

1. **Fresh before-state and identity checks.** Re-read complete catalog, blueprint and published content under authorized access. Capture fresh Firestore metadata revisions and typed field snapshots privately; old report timestamps are historical only. Verify verified active organization Admin/Staff identity, user assignment and membership; verify deployment permissions separately. Stop on changed category/status/schema/creation values, title, duration, exercise references or targets until reviewed. Recheck the Storage object generation/hash and licensed-use basis. Obtain URL in memory from approved private configuration/input; keep tokens out of command arguments, Git, logs, screenshots and public manifests. Retain private rollback values in an approved restricted store and report only IDs/fingerprints.
2. **Selective deployment.** After deployment approval, verify the approved build/tests and capture the currently deployed publisher revision/source for rollback. Proposed root command only: `firebase deploy --project gainpath-0619 --only functions:publishRoutineCommand`. Verify new readiness/revision/us-central1. No Rules/indexes/Storage/Hosting/workout function deployment.
3. **Fresh guarded existing-record edit.** Immediately before live edit, re-read the exact catalog and blueprint revisions and compare to reviewed before-state. Open the current Firebase Admin catalog at the approved source; its opaque baseline is a field snapshot including updatedAt, not metadata updateTime. Change only title and video URL. Save must transactionally compare the original catalog, user assignment and membership and patch only exerciseName/videoUrl plus server updatedAt. No duplicate creation or full-document replacement. A conflict requires explicit reload and a reviewed new baseline. Read back exact changed-field set, preserved ID/createdAt/schema/category/status and private media equality; do not print the URL.
4. **Fresh publication-source gate.** Re-read catalog AND blueprint revisions immediately before publication. Verify intended new name/media and unchanged title/Day 1/3×8/exercise ID/all targets. Stop on drift. The publish command does not carry expected revisions; its transaction reads a consistent current source, so a pre-read is not an atomic publication precondition. Concurrent authoring can still change that source. Coordinate the bounded authoring window and require post-publication verification; no claim of revision-pinned publication is made.
5. **Trusted publication with a new operation.** After publication approval, call publishRoutineCommand with schemaVersion 1, organizationId gainpath, blueprintId PTe4DxLS3WZ2DsfpGTOy and a NEW_UNIQUE_OPERATION_ID. Capture the actor/payload/request ID and receipt privately. Reusing an old successful request returns its old receipt without refreshing name/media. If a response is lost, reconcile content/receipt before another invocation; the current Admin creates a fresh ID per click and is not a durable same-ID retry UI. Do not delete receipts or patch published content directly.
6. **Published identity and Member selection.** Read back orgs/gainpath/content/routine_PTe4DxLS3WZ2DsfpGTOy. Verify published status/schema/source ID, Codex Verification Routine title, duration, each row's ID/day/sets/reps/category, Bodyweight Squat and private validated video URL. Catalog changes alone do not update old content. Re-enter/restart the authenticated Member shell and verify it actually selects this routine; its current limit(1) query and cached future are not a guaranteed identity selection mechanism if other content appears. Stop on wrong selection instead of deleting/retiring other routines.
7. **Separately approved phone preparation and playback.** Preserve the actually installed Xiaomi APK (pull/hash), signing/version/configuration and pre-test workout history/progress/consent/outbox state. Only after build/install approval create a separately named Firebase development APK at the approved SHA; confirm current phone defines rather than inferring them from old reports. CI mock APK success is not Firebase activation. Use update installation on the confirmed serial with compatible signature/version; never uninstall, clear data or force recovery. Verify real media load/audio/play/pause/seek/replay, lifecycle/lock/background/close, logout/account switch and network failure/retry, correct names/title/targets, and unchanged workout/consent/outbox counts. Do not start a squat or create synthetic real activity.

## Separate rollback and preservation

- **Catalog:** Capture private before-values and the activation after-revision. After rollback approval, compare current state with that expected after-state, then guardedly restore only prior name/media and a NEW server updatedAt. Do not restore old timestamps, overwrite a later author's edit or change ID/protected fields.
- **Published content:** Catalog rollback does not revert published snapshots. Use a new trusted request after approved catalog restoration, then verify restored projection. Preserve receipts. If exact historical content cannot be reproduced by the current publisher, stop for a specifically reviewed restoration.
- **Publisher:** Restore only the captured previous publisher source/revision if approved. Backend rollback does not remove existing published name/media. Reconcile content independently; no other resources are included.
- **Phone:** Update-install the preserved compatible prior APK only after approval, retaining app data. Stop if recovery requires uninstall, clear-data or incompatible downgrade. App rollback does not revert Firestore content.
- **Media/history:** No Storage deletion/token rotation, workout-history migration, consent/outbox reset or acceptance policy change.

## Stop and approval boundary

Source-only Gate 0A does not authorize these operations. Next review must resolve the outstanding real browser verification gate and explicitly authorize the chosen named deployment/live-edit/publication/device sub-gates. Fresh revision checks and exact read-back evidence are required even after approval. Stop on drift, conflict, wrong Member selection, incompatible APK or failed preservation. Step 7C remains a separate workstream.
