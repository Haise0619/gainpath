# Hybrid workout authoring and execution

Implementation committed as `8eb2dd2` on `codex/hybrid-workouts`, 6 November 2026. After explicit owner approval, the six matching backend Functions and Firestore Rules are active. The existing private Admin bundle was preserved. No mobile installation or new Member content publication occurred. The prerequisite source checkpoint `41f57bc4618c894f8f86fff4e070ce2c5ca50f66` was pushed to main before implementation.

## Loading failure and approved rollout

The new Admin was already requesting the new contracts while cloud dependencies remained old. The deployed Rules lacked `routineBlueprintsV2` access, and the original unified Admin command rejected schema-two Program requests. This produced both reported loading errors. A read-only probe reproduced the original rejection and confirmed the corrected packaged business logic accepts the request against live records: zero discoverable Programs, zero drafts and 24 preserved published routine choices. Canonical templates remain correctly archived (13 records, zero visible); the version-two collection is empty.

The owner approved deployment of `publishRoutineCommand`, `workoutProgramCommand`, `fypDatasetCommand`, `workoutBackupCommand`, `adminWorkoutReportingCommand` and new `exerciseCatalogCommand`, plus the matching Firestore Rules. Five existing Functions received source-only updates in `asia-southeast1`. All 67 unrelated Functions, the five existing service settings and IAM policies, and Firestore indexes are verified unchanged. Exact source archive hashes and active Rules contents are verified. Product data writes were not performed.

Automatic approval review initially rejected the new endpoint's invoker grant because its principal and scope were not explicit. The owner separately approved `allUsers` → `roles/run.invoker` only on the new `exerciseCatalogCommand` service. This matches existing callable transport policy; App Check and verified current Admin/Staff authorization remain enforced. Unauthenticated HTTP probes of the catalog, Program and unified Admin endpoints return401/UNAUTHENTICATED.

Two packaging errors were resolved before the Rules switch: the initial archive omitted the unchanged `pnpm-workspace.yaml` dependency-build policy, and the unified Admin requires its existing separate `lib/fyp-release-index.js` module entry point. Corrected builds passed; all six Functions are ACTIVE. The Cloud Functions API omits deprecated `dockerRegistry` after update; preservation comparison normalizes its Artifact Registry default while comparing the exact repository and all service settings.

Evidence: ignored `build/hybrid-workouts-20261106/deployment-verification.json`, `live-read-contract-proof.json`, `admin-served-verification.json` and the sealed rollout manifests. The existing Admin is reachable at localhost:7359, serves its unchanged hybrid-enabled bundle (SHA256 `2a288b995916fc0478ef824c668d14f413142dda26cf28bceccc150b1fef31e5`), and was not rebuilt during this rollout. The read probe used packaged business logic with an existing operator connection; it is not an authenticated HTTP/browser acceptance result. Browser automation remained unavailable because the tool could not verify its URL. Refresh/retry the two pages for authenticated visual acceptance.

## Catalog and authoring

- Existing registered AI exercises continue through the existing capability registry and measured session routes. The current repository has nine registrations; their analyzers and counting thresholds are unchanged.
- New catalog exercises use `videoGuidedTimed`, with a typed prescription containing sets, durationSeconds and restSeconds. Legacy records retain their original manual/tutorial behavior. Names and editable flags cannot grant AI capability.
- New timed exercises start inactive. Save, edit, archive and restore use the scoped `exerciseCatalogCommand` callable and clear the previous media validation. Activation requires a loaded Admin preview, current author authorization, matching edit revision, and authoritative managed Storage object validation (organization path, download token, generation, MP4 MIME and size).
- Defaults are copied into routine rows. Later catalog edits do not silently alter authored targets; reset-to-defaults is explicit. Routine rows carry stable entry IDs, mode and typed targets. The same exercise can occur more than once.
- Routine creation has Details, Structure and Review stages. Saving a draft and publishing are separate actions. Existing templates require an explicit upgrade before schema-two editing. Publishing freezes catalog/media identity and targets in a separate `routine_v2` content record; old published routines remain intact.
- Program creation has Details, Schedule and Review stages. Program schema version is separate from immutable publication version. Schema-two day rest overrides are nullable: absent means use each row's rest. Creating a routine from Program authoring preserves the draft and requires explicit slot selection afterward.

All timed catalog writes and schema-two template writes are server-authoritative. Actual emulator evaluation showed the intended direct-client validation exceeds Firestore's 1,000-expression budget at supported step/row counts. Rules permit scoped author reads and deny these direct writes; existing legacy authoring remains compatible. This replaces the original proposed direct-write draft path.

## Member flow and timer

`RoutineJourneyController` resolves every row using the existing tracker dispatcher plus `ExerciseExecutionResolver`. AI rows retain camera/consent and measured engines. Timed rows open the reusable guided route before any camera initialization. Legacy guided-only rows retain tutorial viewing and manual set logging.

Timed sessions loop the tutorial, count active foreground playback time, and expose Start, Pause, Resume, Rest, next set, Skip and save-and-exit. Full target duration credits a set. Mid-set rest preserves partial time without crediting a set. The next set requires an explicit action, including when rest is zero. Loading, buffering, stopped playback, errors, backgrounding, route obscuration and account revocation freeze timing. Returning to the foreground does not silently resume. Initialization is bounded and retryable.

Commands are serialized, with synchronous interruption invalidation. Progress saves at transitions and every five active seconds. Save failure pauses the player and leaves retryable local progress. Completion returns to the same routine progression only after durable checkpoint persistence. Reopening uses the same run, entry, routine and attempt identity; skip retains truthful partial duration.

## Persistence and compatibility

- Typed timed results contain active duration, completed sets, target, run/entry/exercise/routine identity, media identity and `timerElapsed` provenance. They omit repetitions, pose metrics, form scores, measured session IDs and AI verification.
- Schema-one codecs and exact old routine signatures remain supported. Schema-two signatures include stable entry, mode, typed target, order and media identity.
- Account-scoped schema-two routine checkpoints use a sibling versioned local directory. Existing schema-one files are preserved. Program enrollment uses a versioned journal with a digest of the old file; a downgrade conflict retains both files and surfaces a conflict.
- Optional backup negotiates routine checkpoint schema two independently of measured-session schema seven. Old servers preserve local data and show an unsupported-server state. Old clients receive compatible routine records only; pagination retains scanned cursors. Timed payloads are strictly validated, including microsecond duration precision and unique run IDs.
- History and reports label guided duration and timer-completed sets separately. Timed activity does not add measured reps, form aggregates or manual sets. Module 13 evidence extraction rejects schema-two routine evidence; workout acceptance and rewards remain disabled.
- Firebase authorization, organization/account scoping and opt-in backup behavior are retained. No raw video or Program enrollment is added to backup.

## Verification and acceptance

Prepared evidence is in ignored `build/hybrid-workouts-20261106/`:

- Shared domain suite: 192 tests passed.
- Affected Member suite: 112 passed, plus focused timer/player, versioned-store and discovery suites recorded in the ledger. Final identity/backup negotiation regression: 3 passed. Full-shell backup integration: 3 passed.
- Affected Admin suite: 121 passed; final authoring/retry/publication recheck: 26 passed.
- Backend integration/reporting/backup batch: 204 passed; final new catalog/publication/timed-backup batch: 37 passed. Source and test TypeScript checks passed.
- Backend authoring review regressions: 116 passed. Actual catalog Rules: 31 passed; existing catalog edit transaction emulator cases: 28 passed.
- Android debug APK and Admin debug web builds passed. The initial custom relative web output failed shader asset writes; rebuilding in the default output directory passed.
- Final scoped Dart analysis passed with no errors or warnings and 45 informational brace-style findings. The whole-workspace architecture checker reports existing cross-package relative test imports in unchanged FYP/support tests; no feature file is implicated. This is not a clean whole-workspace architecture result.
- Cross-reviews covered backend authoring authority, Admin contracts and timed persistence. A fresh whole-feature independent review could not run because the review agent reached its account usage limit; the implementer performed the final separate review. Do not describe this as a completed whole-feature independent review.

The broad backend run was not fully green: 2,023 passed and 11 failed, including loopback EACCES, emulator routing and retained FYP package cases. These are recorded limitations, not a claim of a clean baseline. A shell backup test originally timed out on global animation settlement; bounded pumps plus explicit readiness, upload, opt-out and lease-disposal assertions now pass.

Before wider release, perform browser visual acceptance and physical Android media acceptance: Admin upload/preview/activation, mixed routine publication, all nine measured route smoke tests, video loop boundaries, offline/buffering/error retry, audio focus, background/foreground, interruptions during save, early exit/reopen, zero-rest and multi-set completion, account switching, backup/restore and old-client discovery. Automated fakes and Storage metadata validation do not prove native media decoder compatibility or exercise accuracy. Backend deployment is approved and complete; device installation remains pending.

## Prior content reset

The separately authorized prerequisite archived 25 Admin templates and retired six Programs from discovery. Published routines, enrollments and workout history were preserved. Evidence remains in the private chat workspace `reset-review/verification.json`. Do not rerun the reset during feature rollout.

## Source map

Shared contracts: `packages/gainpath_domain/lib/src/workout/exercise_prescription.dart`, exercise/tutorial/template entities and `workout_program.dart`.

Backend: `functions/src/modules/content/{exercise-execution,exercise-catalog,exercise-catalog-callable,timed-catalog-draft,blueprint-catalog,publish-routine-v2}.ts`, existing publication/Program adapters, `workouts/timed-routine-backup-validation.ts`, backup/reporting/evidence adapters and `firebase/firestore.rules`.

Admin: workout catalog/template/Program screens, Firebase catalog/template/Program repositories, fixed-region transport and shared video preview adapters.

Member: guided timed controller/progress/route/screen, execution resolver and signature; routine controller/checkpoint/attempt; published catalog, Program, backup and versioned local-store adapters; tutorial playback and history/report presentation. Measured route adapters only consume validated repetition targets.

The implementation commit contains the exact source and test file list. Concurrent Admin identity/coach changes are excluded from this feature commit.
