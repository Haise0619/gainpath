# Local Member Progress implementation plan

Approved scope: the user's 2026-10-13 request for real Member Progress and Local Workout History. This plan executes only that slice; remote history, pose changes, Firebase policy/resource changes, awards and other modules are excluded.

Baseline: `98d5dec`, current feature checkout. Existing user changes/untracked audit and experimental reports remain untouched. Retain this checkout rather than omit its local evidence or move other work; no branch reset or broad staging/commit.

## Design and data boundaries

- Reuse Member Home, profile navigation, progress dashboard, activity timeline, performance and form report layouts. Existing mock branches stay unchanged.
- Pure-Dart immutable progress records/calculator belong to `gainpath_domain` analytics. Mobile adapters map existing measured summaries and matching durable upload entries; no native/Firebase dependency enters domain.
- Read existing `WorkoutSessionStore` and `RealWorkoutSyncStore` under immutable `SessionScope`; reads only. Do not call consent, enqueue, sync or network upload when opening progress/history.
- Include only `realCamera` records with valid pose metrics and matching owner/organization. Exclude demo, legacy and recorded fixtures; deduplicate identities, reject conflicting facts. Never infer acceptance from legacy local `pending/accepted` flags.
- Upload status comes from a matching stored v2 submission plus durable receipt. Preserve local provisional, pending, retryable, rejected, accepted and unknown metadata states. Match payload facts, not only session ID. Unknown/unreadable sync metadata does not fabricate provisional/accepted status; show a warning while retaining usable local counts.
- Count saved sessions, full reps and partial attempts truthfully; a zero-rep saved capture is a session, not proof of a completed exercise/routine. Use completion time and Monday–Sunday weeks in explicitly labelled Malaysia/UTC+08 policy for the existing development organization; injected calendar offset/asOf keeps tests independent of host timezone.
- Keep nullable estimated form, tracked/rejected microseconds and rule/model/view versions. Chart separate version groups; average scored attempts within a compatible group only, preserve excluded/unassessed denominators. Score is an estimated rule metric, not anatomical/AI classification accuracy. No load volume, rewards, streak, goal completion or fabricated values.
- Refresh on pull/retry, opening progress, returning from result/history, tab/lifecycle resume. Account/role changes synchronously hide old data and discard late reads. Current account-scoped file formats remain unchanged.

## Task 1 — Pure progress model and calculator

Files: `packages/gainpath_domain/lib/src/analytics/local_member_progress.dart`, analytics barrel and `test/local_member_progress_test.dart`.

Interface: immutable `LocalWorkoutProgressRecord` with scope/session/exercise/UTC start/end, full/partial counts, nullable form, tracked/rejected durations, scoring/detector/model/view version, status/failure/accepted time. `MemberLocalProgress calculateLocalMemberProgress({required SessionScope scope, required Iterable<LocalWorkoutProgressRecord> records, required DateTime asOf, Duration utcOffset=8h, int weekCount=7})`. Output includes current week/all-time totals, sorted records, seven weekly buckets and separate form series with scored/unassessed attempts/coverage. Annotate local/provisional status regardless of upload acceptance; never grant authority.

- [x] Write tests first: empty, Sunday/Monday UTC+08 boundary, year boundary, future/incomplete records, wrong account, fixtures filtered by adapter, duplicate/conflict, nullable scores, different versions, chronological gaps and duration coverage. Confirm failing feature tests before implementation.
- [x] Implement minimal immutable calculation and run full domain suite.

## Task 2 — Read-only local adapter and account-owned cubit

Files: mobile `features/analytics/domain/local_member_progress_repository.dart`, `data/local_member_progress_repository.dart`, `application/member_progress_cubit.dart`; focused adapter/cubit/disk tests.

Interface: repository scope, `Future<LocalMemberProgressSnapshot> load()` with records, summaries and warnings, no write/upload API; constructor receives existing scoped workout/sync stores and `activeScope`. Cubit state loading/ready/failure/inactive, immutable scope/data/error; reload invalidates pending generation and clears stale data. Composition owns concrete factories.

- [x] Test scope before/after awaits, receipt/submission matching, pending intent, retry/reject/accepted, malformed/mismatched metadata, unknown sync status, disk restart/no mutations and read errors.
- [x] Map local records/versioned measured fields, read outbox separately and preserve partial failure explicitly. Do not modify workout/outbox/consent wire contracts.
- [x] Implement cubit with current clock/calendar injection and late-result/account guards.

## Task 3 — Reuse existing progress/report templates

Files: existing `progress_dashboard_screen.dart`, `activity_timeline_screen.dart`, `workout_performance_screen.dart`, `posture_accuracy_screen.dart`; a shared analytics presentation status/coverage helper if needed; `local_member_progress_ui_test.dart`.

All four screens accept optional `MemberLocalProgress localProgress`, refresh and record-open callbacks where useful. Null selects unchanged mock templates. Live dashboard retains highlight/stat grid/deep-dive tiles; cards show weekly saved sessions, full reps, partial attempts and coverage. Reports use actual weekly sessions/reps and separate estimated-form version series; hide unsupported rewards/body/goal/kg metrics and cosmetic export actions. History shows every applicable durable upload status, nullable form, versions and coverage; no fabricated points or acceptance.

- [x] Write UI tests first with hand-derived data, empty/null/version/status states and no seeded metrics. Existing mock tests remain.
- [x] Implement using existing theme, Panel, StatTile/tiles/charts; text labels accompany status colors. Handle small screens and refresh/empty/failure states.

## Task 4 — Composition, Home/Profile and saved-history integration

Files: MemberShell/Home/Profile, `app/routing/member_progress_route.dart`, existing feature routes and saved-squat history; injection seams at current mobile/profile gate if needed. Composition supplies stores and callbacks; feature presentation does not import route implementations/concrete adapters.

- [x] Write live shell/Home/Profile navigation tests, logout/account switch during pending read, refresh after save/return and date changes, local persistence test.
- [x] Live Home reads account-local snapshot, replaces unavailable weekly placeholders with truthful totals, adds recent sessions and enables Progress action. No invented ring targets.
- [x] Progress from Home/Profile/named route and existing saved history use the same calculator/read adapter and explicit account guards. Opening a record may use existing guarded measured-result view, but must not initiate upload merely by browsing this slice.
- [x] Preserve existing real result/consent/upload behavior and all mock routes.

## Verification and stop

- [x] Run affected tests RED then GREEN, full domain and mobile suites, maintained source analysis and architecture checker; report existing failures separately without unrelated refactoring.
- [x] Fresh review of diff plus focused privacy/status/calendar/data assertions. Fix material findings with regression tests.
- [x] Record exact files/results/source semantics and remaining physical/Firebase gates in a dated implementation report. Keep Step7C separate. Recommend tutorial playback/routine consumption next; stop for user review.

No deployment/APK install/new model tuning/server tuple change, synthetic real submission, rewards or remote acceptance claim is authorized by this plan.

