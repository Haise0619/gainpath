# Step 1: workout audit and one-exercise contract

Date: 2026-10-02. Scope: Step 1 of `docs/superpowers/plans/2026-10-02-real-pose-workout-handoff.md` only. The existing Firebase authoring/publishing slice and mock Workout layout are preserved. No SDK, camera, callable, deployment or real session is enabled by this work.

## Current implementation, before changes

| Component | Current behavior | Reuse decision |
| --- | --- | --- |
| Auth, verified active membership, profile/preferences | Firebase implementations | Stable dependency; do not rebuild |
| Admin exercise/blueprint authoring and `publishRoutineCommand` | Real Firebase authoring and trusted publication | Stable dependency; no schema/write changes |
| Published routine repository | Reads first published routine from authenticated account's organization using `Source.server`, 20s timeout | Reuse; offline content cache belongs to Step 2 |
| `PublishedRoutine.fromDocument` | Converts rows to prototype `Exercise`, losing `exerciseId` and `dayNumber` | Preserve identity in a mobile-owned display-compatible subtype |
| Member prep/routine UI in Firebase mode | Real catalog names/sets/reps; tutorial, camera, preview and session actions unavailable | Reuse layout/navigation; keep actions blocked in Step 1 |
| `application/live_session/WorkoutSessionBloc` | Prototype repository, random confidence, rep every third UI timer tick, synthetic cues | Keep for mock mode; do not feed real frames into timer ticks |
| `LiveWorkoutScreen` / `SkeletonPainter` | Timer and animation, no preview or measured landmarks | Reuse presentation layout with a real controller in Step 4 |
| `WorkoutResultScreen` | Aggregate prototype metrics, hash-derived per-exercise scores, hardcoded 120 points | Later bind actual one-exercise result; Firebase rewards remain unavailable |
| Consent sheet / camera setup | In-memory checkbox and instructional side-on guide; no acknowledgement, permission or calibration | Reuse presentation; replace adapters/ordering in Step 2 |
| `/workout/guided`, `MobileWorkoutScreen` | Simulation harness, explicitly simulated detector, scoped local persistence, unavailable uploader | Keep harness; do not substitute it for existing member Workout screens |
| Pure `gainpath_pose` | Useful ports/filter/FSM/health/score/cue foundations, not a validated squat engine | Reuse pure foundations; implement geometry/rules in Step 3 |
| Mobile `WorkoutSessionRepository` and application BLoCs | Scoped durable recording, stable IDs/save retry, stale completion suppression | Reuse these application/persistence boundaries in the real composition |
| Workout backend | Types/interface only; no exported acceptance or consent callable | Implement trusted handler in Step 5 |

Two colliding stacks are intentional here: domain `WorkoutRepository` provides routine/cues/prototype history/height; mobile feature `WorkoutRepository` provides scoped save/history/sync/dispose. Likewise, `application/live_session/WorkoutSessionBloc` is prototype presentation logic; `application/workout_session_bloc.dart` is the persistence-oriented application controller. Its caller-supplied movement ticks are still simulated and must be replaced deliberately. The final real path will use mobile persistence/application boundaries and the existing member UI, without letting prototype timer logic create real results.

## Exact published-content route

1. Blueprint `orgs/gainpath/routineBlueprints/PTe4DxLS3WZ2DsfpGTOy` references exercise ID `F3b8xIr8ynBDd3gEICKX`, day 1, 3 sets, 8 reps.
2. Trusted publication writes `orgs/gainpath/content/routine_PTe4DxLS3WZ2DsfpGTOy`, including that ID and display fields. Catalog content is neither assignment nor workout history.
3. `MobileApp`'s Firebase member composition supplies `FirebasePublishedRoutineRepository(scope).load` to `MemberShell` after the profile gate. The query selects `status=published`, `kind=routine`, limit 1; it does not pin this particular routine.
4. `MemberShell` loads the routine future and passes its result to Home and `WorkoutPrepScreen(live: true)` in the Workout tab. Home's routine action also pushes that prep screen with the same data.
5. Prep's View routine pushes `RoutineScreen(publishedRoutine: ...)`; every published row remains clickable with an unavailable message. Firebase Start/preview/camera actions stop with that message.
6. Mock Start opens the checkbox consent sheet and then named `/workout/guided` through `AppRouteBuilders` to `WorkoutRoute`, which composes `MobileWorkoutScreen` with `SimulatedPoseDetector` and `UnavailableWorkoutUploadGateway`. Mock preview separately opens `LiveWorkoutScreen`. Neither is a real Firebase execution path.

Step 1 now retains row IDs and day numbers in `PublishedRoutineExercise extends Exercise`; this preserves existing display consumers without modifying shared domain `Exercise` or the published schema. Old minimal parser fixtures without `dayNumber` remain day 1; malformed explicit days fail. Future preparation must carry `{organization scope, publishedRoutineId, exerciseId, dayNumber, sets, reps}` from the selected row into the existing screens; do not look up a rule by display name or silently launch the first mock exercise.

## Development squat identity and camera view

Read-only authenticated Firestore requests on 2026-10-02 returned HTTP 200 for all three development records. Exercise schema 1 has `isActive=true`, name `Codex Verification Squat`, category `Compound Lower-Body`, and placeholder URL `https://example.com/gainpath-dev-squat`. The published row has the exact ID, day 1, 3 × 8. Nothing was recreated or written.

Explicit candidate binding:

| Organization | Catalog exercise ID | Rule/scoring version | View | Targets |
| --- | --- | --- | --- | --- |
| `gainpath` | `F3b8xIr8ynBDd3gEICKX` | `bodyweight-squat-side-v1` | `side` | From the selected published row; currently 3 × 8 |

`DevelopmentSquatBinding.resolve` matches the organization/ID tuple only. Mock `bodyweight_squat`, the same ID in another organization, and all other catalog IDs do not match. This is a declared candidate contract, not a device-validated rule or launch permission. **Movement confirmation remains pending:** the record and placeholder tutorial cannot prove this represents an unweighted bodyweight squat. The user was asked to confirm that intended movement; keep real entry blocked until confirmed. Do not add movement fields to authoring or infer them from category/name.

The initial side view requires a consistently selected visible shoulder/hip/knee/ankle chain on one side. Missing essential joints freeze counting/scoring. Initial checks may cover side-view depth/extension and supported trunk inclination; bilateral frontal knee-valgus checks are unavailable. The external algorithm references (160°/90°/15° per second) are unvalidated starting values for Step 3, not thresholds implemented or validated here. Phone IMU is not athlete-motion evidence.

## Existing ports and constraints

- `PoseDetector.detect(PoseInput) -> Future<PoseFrame>`; input contains capture timestamp in microseconds and image width/height only. It cannot carry a real camera image. Choose a mobile-owned image association or a Dart-owned buffer contract after selecting the SDK; do not put `CameraImage`/native SDK types in the pure packages.
- `PoseFrame` has immutable landmark map, capture timestamp, detector ID/model version, mirror flag. Nine landmark IDs: nose, bilateral shoulder/hip/knee/ankle. Points carry x/y/z/visibility; axes, normalization, rotation and timestamp origin are not specified yet. Missing landmarks are representable. Define native mapping in Step 2 before processing.
- `PoseSessionCoordinator.process(input, movementMetric, deviation)` gets metric/deviation from its caller. The filter is not connected; health accepts any three sufficiently visible points. The two-phase threshold FSM does not derive joint angles. Score accuracy is `(1-deviation)*100`, with deviation defaulting to zero; confidence is a separate value, but the current live prototype equates it with accuracy. Healthy elapsed span is not an accumulated valid-interval total. Cue arbitration is pure and not mobile playback.
- Mobile `WorkoutSessionStore` exposes immutable `scope`, scoped `exclusive`, `read`, `write`. `FileWorkoutSessionStore` uses app-private `workouts-v2/<encoded org>/<encoded uid>/records.json`, per-path serialization, file locks, flushed snapshot replacement; preserve the directory to keep old data accessible.
- Mobile `WorkoutSessionRepository` checks scope before/after await, immutable summary by session ID, pending/accepted state, and persists each acknowledgement before the next upload. Upload port is `upload(WorkoutSessionSummary) -> WorkoutUploadReceipt(acceptedAt, serverReference)`; it is not a Firebase implementation.
- Existing local summary has user/org/session/exercise IDs, reps, integer accuracy and ISO start/end times. Constructors default to demo IDs. The existing session application BLoC creates these summaries, retains the same pending summary on failed save, and suppresses late frames by revision. Do not use this constructor to generate real submissions.
- Existing wire v1 contains schema/request/org/member/session/exercise IDs, epoch start/end, reps, nullable score, tracked/rejected milliseconds, scoring/detector/consent versions. Additional fields are forbidden. Response is schema/request/session IDs, accepted status and server acceptance timestamp. It remains a historical contract; there is no deployed workout consumer.
- Mobile pubspec has no camera/pose/audio plugin. Android main manifest declares no camera permission. No iOS Runner/Info.plist exists in this checkout. Camera lifecycle/permission handling does not exist; platform configuration remains a Step 2 task.

## Submission v2 and local migration

Keep v1 unchanged. New v2 schemas, fixture, TypeScript types and immutable Dart `RealWorkoutSubmission` add exactly five fields:

| Field | Meaning |
| --- | --- |
| `provenance: real_camera` | Explicit client claim of real local camera capture; simulated/fixture/legacy payloads are not accepted |
| `publishedRoutineId` | Organization content document ID; server verifies the exercise occurs in the published routine |
| `cameraView: side` | Declared initial supported view |
| `detectorId` | Adapter family, separate from existing detector version; server enables explicit tested tuples only |
| `consentAcknowledgementId` | Reference to server acknowledgement for the authenticated member, separate from consent version |

Existing `scoringVersion` is the versioned squat rule/scoring contract; no duplicate `ruleVersion` field is needed. One session summarizes one exercise across its sets, not the routine. Day and prescribed targets stay preparation data and are not redundant upload fields. No frames, video, landmark streams, reward totals or client acceptance timestamps enter the request.

Structural bounds retain v1's ID regex (1–128 safe ID characters), finite score 0–100 or null, rep envelope 0–10000, and duration envelopes 0–86400000ms. Dart additionally enforces end > start, session duration ≤24h, tracked + rejected ≤wall time, and zero tracked time implies zero reps/null score. Paused/calibration intervals may account for the remainder. JSON Schema defines structural bounds; it cannot enforce these arithmetic relationships. The trusted parser must mirror arithmetic checks and add rule-specific plausibility before acceptance. These broad wire bounds are not validated physical movement thresholds.

The shared fixture uses `contract-test-detector`: it is synthetic test data, never an enabled detector version or real activity. No detector tuple is enabled in this step. Parsing a DTO is not proof of capture or server acceptance.

Local summary schema 2 adds `provenance` (`legacyUnknown`, `simulated`, `recordedFixture`, `realCamera`). Existing constructors default to simulated. Pre-migration JSON without `summarySchemaVersion` always restores as `legacyUnknown`, even if someone appends a provenance label. Unknown explicit versions/provenance fail. Equality includes provenance, so the same ID cannot be overwritten with different provenance. Old results, account IDs, pending/accepted state and storage path are retained.

**All current local summaries remain ineligible for real upload**, including a summary with only a `realCamera` label. The repository checks this before invoking any real gateway. An explicitly typed `DemoWorkoutUploadGateway` keeps prototype acceptance local; the existing in-memory gateway uses it, as do test doubles testing demo acknowledgement/account races. It must never be implemented by a network gateway or selected for real Firebase composition. Legacy/demo records are retained pending and skipped, without issuing a network retry.

Step 4 must introduce a separately validated real-result/outbox variant carrying the exact immutable v2 payload, including stable request/session IDs and consent receipt, and retain nullable score instead of backfilling prototype accuracy. That variant alone may become upload-eligible after the real composition exists. Persist its bounded payload before reporting Saved; retain the same payload and IDs through restart/retry. Keep legacy/demo readers for local history and never migrate their metrics into the real variant. Until then, v2 is a wire DTO and current summary schema 2 is a provenance migration only.

## Consent acknowledgement contract

Consent version: `pose-local-summary-v1`. The future sheet must explain local image/pose processing, bounded summary upload, no raw media/landmark upload, and the separate camera permission. Checkbox alone is insufficient.

Request schema 1: `{schemaVersion, requestId, organizationId, memberId, consentVersion, consented:true}`. UID must equal authenticated verified user and authoritative membership must be active. Decline produces no command and blocks entry. The server owns acknowledgement ID and time. Response schema 1: `{schemaVersion, requestId, organizationId, memberId, consentVersion, acknowledgementId, acknowledgedAtMillis}`.

Proposed current record: `orgs/{orgId}/workoutConsents/{uid}` with those bounded acknowledgement facts plus optional server `revokedAtMillis`. Repeated acknowledgement of the same current version preserves a stable receipt; changed versions/revocation require fresh acknowledgement. Persist the response under immutable account scope for offline use after the first server acknowledgement. Permission denial still blocks camera entry. Local `authorizes` matches org/member/version/receipt and acknowledgement time ≤session start; it cannot establish current revocation state. Acceptance rechecks the authoritative current record.

Required future rules: active verified owner can read their own receipt; **all client writes denied**. Trusted consent command writes only its authenticated member's record; request cannot inject server time, acknowledgement ID, roles or revocation. Existing catch-all denial already protects this unimplemented path; Step 1 makes no rules changes or consent writes. Add owner-read/rules tests only when that service is implemented. Cached old-version, cross-account or revoked receipts never authorize a new real session.

## Trusted acceptance requirements (Step 5, not implemented)

1. Parse only bounded v2 with no extra fields; reject v1, simulated/fixture claims, demo identities and unsupported detector/rule/view tuples. No enabled detector registry exists yet, so deployment remains disabled.
2. Derive actor UID from verified Firebase authentication, compare `memberId`, read authoritative active organization membership. Client roles are not authorization; preserve existing branch checks where required. Read only the requested organization's source records.
3. Recheck current unrevoked consent/version/acknowledgement and that it predates the session. Validate active catalog exercise, published routine membership and exact org/exercise-to-rule binding. Catalog availability is not assignment.
4. Validate finite score, chronology, duration accounting, future/skew bounds and rule-specific rep-rate/score plausibility against the device-validated rule policy. Insufficient evidence keeps score null; no confidence-as-form substitution.
5. Transactionally deduplicate a command key scoped to actor/org/request plus immutable member/session facts. Canonical session hash excludes retry `requestId` but includes all workout facts; changed facts under either existing key conflict. A retry with a fresh command key and identical facts returns the original immutable acceptance. A colliding org session ID owned by another member fails; do not overwrite it.
6. Server writes `orgs/{orgId}/workoutSessions/{sessionId}` with authenticated ownership and server acceptance metadata; direct client writes remain denied. All transaction reads precede writes. Persist acknowledgements before advancing the outbox; retain pending data on retryable failures, distinguish permanent validation failure in the later outbox variant, and suppress stale acknowledgements after logout.

These controls validate client assertions and receipt ownership. They cannot prove physical exercise occurred. Genuine camera/count/correction/device evidence, save/restart/upload/retry tests and exactly one accepted Firestore document are later completion requirements, not claimed here.

## Step 1 execution record

- Audit reported in chat before code changes. Read existing routes, pose, persistence, contracts, rules, external algorithm references and platform manifests.
- RED: catalog parser lacked identity getters; real gateway was invoked twice for legacy/simulated records restored from disk. GREEN: identity preservation and fail-closed guard pass.
- RED: missing v2/consent schemas and missing Dart validation behavior. GREEN: bounded shared fixture, unknown fields/provenance, nullable score, chronology, consent scope/time and exact candidate binding pass.
- Ruling: retain this dirty working checkout because it contains the completed Firebase slice; no fresh worktree, broad staging or reset. Cost if wrong: review requires the explicit Step 1 file list below rather than treating all dirty files as this change.
- Ruling: implement Step 1 only despite the request's broader vertical-slice phrase; camera processing, real UI/controller binding and trusted acceptance remain Steps 2–5. Cost if wrong: another implementation turn is required, rather than silently crossing the user's SDK gate.
- Ruling: movement binding remains candidate-only pending user confirmation; a name and placeholder URL do not establish movement semantics. Cost if wrong: real activation stays blocked until confirmation.
- Ruling: preserve submission v1 and add v2; local summaries stay upload-ineligible until the separate real outbox variant is integrated. Cost if wrong: later server/client composition must explicitly select v2 and the real variant.

Step 1 files: mobile `data/published_routine.dart`, `domain/{workout_contracts,real_workout_contract}.dart`, `data/workout_session_repository.dart`; mobile tests `published_routine_test.dart`, `features/{real_workout_contract,workout_provenance,workout_sync,workout_account_scope}_test.dart`; shared v2 request/response/fixture and v1 consent request/response schemas; functions `modules/workouts/contracts.ts` and `test/workout-v2-contract.test.ts`; this audit. Existing dirty Firebase authoring/publishing, routing/UI, identity and rules files are prior work and are not Step 1 edits.

Validation: mobile full suite 90 tests; mobile analysis no issues; pure pose 9 tests; functions build/test typecheck and 73 tests; focused Admin catalog/authoring/auth 7 tests; Firestore/Storage/transaction emulator 20 tests all passed. `git diff --check` passed. Test host uses Node 24.19.0 and emits the existing Node 22 engine warning.

The standard emulator command initially failed because PID 221844 already listened on port 18080. Tests were rerun using a temporary config on ports 28080/29199/24400/24500. The test run shut down its own emulators, and that temporary config was removed. Existing emulator process/configuration were left intact. No production Firebase writes or deployments were made.

Final review: a separate read-only reviewer found no material migration, upload-isolation, retry, account-scope or schema/type consistency defect.

Final: minor (deferred): parser `dayNumber: null` currently defaults to day 1, just like an absent day. This differs from the intended missing-only compatibility rule above; current authoritative published rows always contain an integer day. Fix by distinguishing `containsKey` and adding a regression test when tightening historical parser compatibility.

Final: Ruling: SDK/camera wiring, detector activation, real outbox persistence, authoritative consent/revocation, trusted semantic/plausibility parser, network upload and server acceptance were considered by review and left for Steps 2–5 — these are outside the explicitly authorized Step 1 and real upload eligibility is closed — cost if wrong: this work does not deliver an end-to-end real workout.

Final: Ruling: movement confirmation remains a pending user question, not a verified result of code review or Firestore inspection — an active record and placeholder tutorial do not prove bodyweight movement semantics — cost if wrong: the candidate cannot be safely enabled yet.
