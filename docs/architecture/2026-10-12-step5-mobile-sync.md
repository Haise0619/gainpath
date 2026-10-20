# Step 5 mobile sync evidence and completion boundary

Optional upload consent is separate from mandatory local camera/setup consent.
The app obtains or uses a cached server acknowledgement before capture, then
persists a scoped session opt-in before starting hardware. Only real-camera,
bounded v2 measured summaries can enter the separate trusted outbox. Local-only
sessions, fixtures and legacy/demo records are never upgraded by a later grant.

Capture intents recover a save-before-enqueue interruption through local history.
Normal completion queues after durable local save and before result navigation.
Network and sync-metadata failures cannot undo the saved measured result. Request
IDs and payloads remain immutable across restart and retries; accepted status is
published only after a matching bounded server receipt is durable. Transient
failures are retryable, while permanent validation/model rejection does not loop.

Revocation disables local eligibility immediately, persists a bounded revoke
command and blocks future sends. An in-flight grant is recovered under its old
request ID only to revoke it when consent is no longer desired. Operation epochs
prevent immediate revoke from being overwritten during asynchronous grant setup.
A valid receipt for a submission accepted before revocation is retained without
restoring consent. The UI does not promise that revocation deletes server data or
undoes an already sent request. Result/history routes retain account guards.

The app-private file store uses injective account paths, per-path serialization,
OS locks, flushed atomic replacement, exact schema parsing and an 8MB read/write
limit. Snapshots are bounded to 1000 entries plus capture intents. Corruption,
forged receipt shapes and cross-account snapshots fail explicitly rather than
being silently replaced. No raw landmarks, frames, video or audio are persisted.

## Verification on 2026-10-12

- Full integrated mobile suite: 248 passed, 15 optional diagnostic tests skipped.
- Additional receipt-disk-failure regression: focused outbox suite 9 passed;
  confirms no accepted UI state before durable receipt and stable retry request.
- File store: 12 tests pass, including restart, case-distinct scopes, corruption,
  oversized valid JSON, atomic interruption and independent-instance contention.
- Sync UI: 3 tests pass for pending/retry/accepted, disabled-model rejection and
  revocation retaining an already accepted result. Real flow UI: 4 pass.
- Mobile and pure pose source/test analysis: no issues. Pure pose: 46 pass.
- Profile APK builds successfully with the integrated sync composition.
- Server build, exported entry point and TypeScript source/test checks pass;
  114 unit tests pass. Parallel backend handoff records 28 emulator tests passing
  and one earlier intermittent local emulator contention failure.
- Independent review findings reproduced and fixed: immediate revoke/grant race,
  DTO reserved detector/version alignment, interrupted enqueue recovery and late
  acceptance semantics. Final integrated review found no remaining blockers.

## Software scope completed; physical acceptance remains

Step 4 and Step 5 software are implemented and committed on codex/real-squat-flow.
No live Firebase deployment or real server acceptance occurred in this work.
Production's enabled detector/rule/view list is empty. Consequently, an optional
upload can remain local or be rejected; this is an explicit quality boundary.
There are no reward, leaderboard or notification side effects.

Next acceptance work requires labeled human squat sequences, full versus partial
rep ground truth, supported deviation review, occlusion/rotation recovery and
camera-to-overlay/analysis/spoken-cue timing on representative phones. Existing
synthetic tests and APK builds do not establish those accuracy or latency claims.
Enabling production acceptance requires that evidence and a reviewed tuple-policy
change. Do not manufacture acceptance or bypass this boundary in unattended runs.

Earlier experimental documentation and unrelated workspace changes are preserved.
The continuation heartbeat should stop once these software commits are pushed.

Subsequent development deployment and the Firebase APK/physical-test handoff are
recorded in `2026-10-12-step6-development-deployment.md`. Physical acceptance
remains pending and the model/rule allow-list remains empty.
