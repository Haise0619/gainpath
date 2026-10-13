# Real Member Progress and Local Workout History — implementation report

Date: 2026-10-13. Starting commit: `98d5dec` on the existing `codex/real-squat-flow` checkout. Scope: the explicitly approved local dashboard slice of [P3/P4](../planning/master-implementation-roadmap.md). Implementation plan: [local Member Progress](../superpowers/plans/2026-10-13-local-member-progress.md).

## Result and boundaries

Firebase-mode Member Home, Progress, Activity Timeline, Workout Performance and Estimated Form now consume actual account-local measured camera summaries. Home and its report routes share an account-owned Cubit. The existing Workout preparation history entry uses the same mapper and guarded measured-result view. Mock mode retains its existing screens, seed repositories and navigation.

This completes this local dashboard slice, not all P3/P4. Remote/cross-device history, trusted physical acceptance, reconnect scheduling, guided sets/rest, voice-mode migration, body/goals and report export remain separate work. No pose/native inference/scoring behavior, consent/outbox wire contract, Firebase resource, deployment, APK or enabled tuple changed. Existing README, run configuration and historical/untracked reports were preserved; no commit was created.

## Actual sources and semantics

| Data | Source and computation | Meaning/limits |
|---|---|---|
| Saved measured captures | [FileWorkoutSessionStore](../../apps/mobile/lib/infrastructure/local/file_workout_session_store.dart), `WorkoutSessionStore.read()` under its existing exclusive lock | App-private `workouts-v2` hierarchy, encoded organization/user identity, `records.json`. Only `realCamera` plus valid pose metrics; demo, recorded-fixture and legacy summaries are excluded. A zero-rep capture counts as a saved session, not a completed routine. |
| Upload state | [FileRealWorkoutSyncStore](../../apps/mobile/lib/infrastructure/local/file_real_workout_sync_store.dart), scoped `real-workout-sync-v1` hierarchy, `state.json` | Read existing immutable submission, capture intent and durable receipt. This slice never acknowledges consent, enqueues, submits, revokes or starts a sync worker. Existing locks may create their normal directories/lock files; JSON payloads remain unchanged. |
| Weekly sessions/full repetitions/partial attempts | [calculateLocalMemberProgress](../../packages/gainpath_domain/lib/src/analytics/local_member_progress.dart) | Completion-time buckets, Monday 00:00 to next Monday exclusive, explicitly UTC+08:00 for this Malaysia FYP organization. Seven weeks include empty zero buckets. Future-ended records are excluded. No routine-completion or target claim. |
| Measurement coverage | Raw tracked and rejected microseconds | `tracked / (tracked + rejected)`. Zero measured denominator is unavailable. Pause/unmeasured elapsed time is excluded; this is not anatomical accuracy or a form-confidence score. Weekly coverage sums durations before division. |
| Estimated form | Nullable stored `WorkoutPoseMetrics.formScorePercent`; no legacy `accuracy` substitution | Groups are separated by exercise, scoring rule, detector, model version and camera view. Mean is weighted by full-plus-partial attempts, matching the current squat analyzer's session score denominator. Unassessed attempts remain separate; null chart points remain gaps. Zero attempts never imply a score. |
| Recent/all-time history | Eligible local records, completion descending with deterministic ID ties | All-time means this account's records present on this device, not all activity on other devices. Identical duplicate identities count once; conflicting facts fail rather than choose an arbitrary result. |

The adapter checks account scope before and after asynchronous reads. A corrupt/unreadable summary store produces a visible failure with retry, not invented empty totals. An incomplete typed row is excluded with a warning where the underlying store permits it; the existing file decoder may reject a corrupt file as a whole. An unreadable or unavailable upload-status store retains valid local measurements with unknown status and a warning.

### Status truthfulness

| UI label | Required evidence |
|---|---|
| Provisional · local only | Local measured record, readable sync snapshot, no matching entry/capture intent. A local summary's legacy `pending` flag alone does not prove upload eligibility. |
| Pending upload | Matching durable pending submission, or matching prior consent capture intent. |
| Pending upload · retry needed | Matching durable retryable submission and failure code. |
| Upload rejected | Matching durable rejected submission and failure code. The local measurement is retained. |
| Server-accepted | Matching durable accepted receipt plus immutable submission. Matching checks owner/org, session/exercise/routine, time, counts/nullable form, duration precision, rule/detector/model/view, provenance and consent version; receipt checks request/session/time. |
| Upload status unavailable | Unreadable metadata, mismatched upload facts or incompatible capture intent. No accepted badge is inferred from a session ID or local UI flag. |

Local full/partial/coverage/form facts remain provisional estimates even when a stored receipt says accepted. Submission v2 does not carry partial/deviation aggregates; the UI does not imply that the backend validated those local fields. Acceptance does not validate estimated form. Rejected captures still contribute to explicitly local totals.

## Integration and architecture

- [Domain calculator](../../packages/gainpath_domain/lib/src/analytics/local_member_progress.dart) is pure Dart. [Repository port](../../apps/mobile/lib/features/analytics/domain/local_member_progress_repository.dart) returns an immutable record/summary/warning snapshot. [Read adapter](../../apps/mobile/lib/features/analytics/data/local_member_progress_repository.dart) reuses existing workout/sync stores.
- [MemberProgressCubit](../../apps/mobile/lib/features/analytics/application/member_progress_cubit.dart) owns loading/ready/failure/inactive state, clock and newest-read generation. Account invalidation clears data and discards late results.
- [App factory](../../apps/mobile/lib/app/di/local_member_progress_factory.dart) owns concrete store construction; feature UI receives values/callbacks. [MemberProgressHost/Route](../../apps/mobile/lib/app/routing/member_progress_route.dart) owns account lifetime, lifecycle/week-boundary refresh, guarded report/detail navigation and warnings.
- Home refreshes on pull, return from its workout/result routes and selecting Home. Progress reloads before opening (including after a workout saved through another tab), on refresh and returning from child reports/results. Open nested reports observe the same Cubit, so their refresh updates them immediately. Account/role changes close app routes through the existing account-keyed MaterialApp and also guard each scoped page.
- Dashboard/History expose full and partial counts separately. Form dates use actual UTC X values plus explicitly formatted UTC+08 labels/tooltips, independent of device timezone. Bodyweight kg-volume, rewards, streaks, goals, unsupported reports and cosmetic export actions are absent from the live report branch.
- Existing record and outbox JSON formats/paths are unchanged. No migration, new dependencies or architectural rewrite was needed.

## Exact files changed by this slice

All paths below are relative to the repository root. They exclude pre-existing user changes and historical/untracked audit material.

| Area | Files |
|---|---|
| Pure domain | [analytics.dart](../../packages/gainpath_domain/lib/analytics.dart); [new local_member_progress.dart](../../packages/gainpath_domain/lib/src/analytics/local_member_progress.dart) |
| Mobile analytics contracts/application/data | [new local_member_progress_repository.dart port](../../apps/mobile/lib/features/analytics/domain/local_member_progress_repository.dart); [new local_member_progress_repository.dart adapter](../../apps/mobile/lib/features/analytics/data/local_member_progress_repository.dart); [new member_progress_cubit.dart](../../apps/mobile/lib/features/analytics/application/member_progress_cubit.dart) |
| Existing report layouts | [progress_dashboard_screen.dart](../../apps/mobile/lib/features/analytics/presentation/shared/progress_dashboard_screen.dart); [activity_timeline_screen.dart](../../apps/mobile/lib/features/analytics/presentation/member/activity_timeline_screen.dart); [workout_performance_screen.dart](../../apps/mobile/lib/features/analytics/presentation/member/workout_performance_screen.dart); [posture_accuracy_screen.dart](../../apps/mobile/lib/features/analytics/presentation/member/posture_accuracy_screen.dart); [new local_progress_widgets.dart](../../apps/mobile/lib/features/analytics/presentation/member/widgets/local_progress_widgets.dart) |
| App composition/navigation | [new local_member_progress_factory.dart](../../apps/mobile/lib/app/di/local_member_progress_factory.dart); [new member_progress_route.dart](../../apps/mobile/lib/app/routing/member_progress_route.dart); [saved_squat_sessions_route.dart](../../apps/mobile/lib/app/routing/saved_squat_sessions_route.dart); [feature_routes.dart](../../apps/mobile/lib/app/routing/feature_routes.dart); [mobile_app.dart](../../apps/mobile/lib/app/mobile_app.dart); [member_shell.dart](../../apps/mobile/lib/app/shells/member_shell.dart); [member_home_screen.dart](../../apps/mobile/lib/app/home/member_home_screen.dart) |
| Existing profile composition/navigation | [fitness_profile_gate.dart](../../apps/mobile/lib/features/identity/presentation/member/fitness_profile_gate.dart); [member_profile_screen.dart](../../apps/mobile/lib/features/identity/presentation/member/member_profile_screen.dart) |
| New tests | [local_member_progress_test.dart](../../packages/gainpath_domain/test/local_member_progress_test.dart); [local_member_progress_repository_test.dart](../../apps/mobile/test/local_member_progress_repository_test.dart); [member_progress_cubit_test.dart](../../apps/mobile/test/member_progress_cubit_test.dart); [local_member_progress_ui_test.dart](../../apps/mobile/test/local_member_progress_ui_test.dart); [member_progress_route_test.dart](../../apps/mobile/test/member_progress_route_test.dart); [member_local_progress_flow_test.dart](../../apps/mobile/test/member_local_progress_flow_test.dart) |
| Existing test updated | [real_workout_ui_test.dart](../../apps/mobile/test/real_workout_ui_test.dart): inject status-store fixture and locate the reused history row; existing consent/save/retry/logout assertions remain. |
| Documents | [implementation plan](../superpowers/plans/2026-10-13-local-member-progress.md); this report. |

## Verification evidence

| Check | Actual result |
|---|---|
| Fresh pre-slice mobile baseline | 259 passed; 15 optional diagnostics skipped |
| Final full mobile `flutter test --no-pub` | **283 passed; 15 optional diagnostics skipped; 0 failed** |
| Full domain `dart test` | **54 passed; 0 failed**, including 28 progress tests |
| New focused mobile coverage | 9 adapter/persistence tests, 4 Cubit tests, 8 UI/chart tests, 2 route tests and 1 live local-data flow test: **24 passed** (also included in full suite) |
| Edited mobile source/tests and domain source/tests analysis | **No issues found** |
| `git diff --check` | Passed |
| Architecture checker | Still exits 1 with **21 existing findings**; no new boundary findings. Existing identity/workout presentation composition/data imports and benchmark/tool imports remain separate debt. This is not a clean global architecture result. |
| Fresh independent review | Two P2 findings reproduced and fixed: stale snapshot on Progress entry, double timezone offset in form chart. Reviewer rechecked both; no remaining material finding. |

Tests cover empty and unavailable states, year/week/UTC-offset boundaries, null/zero/partial data, future timestamps, duplicate/conflicting identities, account replacement and stale asynchronous reads, incompatible scoring/model/view versions, matching/rejected/unknown receipts, prior-consent capture intent, real file-store restart and unchanged JSON, report refresh while open, Home/Profile navigation, account switch, narrow layouts/large text and midnight chart formatting.

Feature tests were run failing before their implementations; the two review regressions were reproduced failing before their fixes. Test summaries and status receipts are isolated fixtures. No fixture was submitted to a live backend or installed as user activity.

Local SDK checks required sandbox escalation for the already installed Flutter/Dart runtime. No packages were installed. Final mobile log: `C:\Users\Ngzhe\AppData\Local\Temp\gainpath-progress-final-mobile.log`; domain log: `C:\Users\Ngzhe\AppData\Local\Temp\gainpath-progress-final-domain.log`.

These are software/integration-test results. At the initial implementation review, this slice had not been installed or physically exercised on the phone. The subsequent user-authorized installation is recorded below; no new exercise-accuracy trial was conducted. These tests do not establish anatomical, repetition-count or form-detection accuracy.

### Subsequent user-authorized phone installation and CI diagnosis

The user subsequently requested APK installation and an explanation of the red GitHub Actions runs. A fresh APK was built from this current working tree and installed successfully with `adb install -r` on Xiaomi 23013RK75C, serial `7c4cbff`, at 2026-10-13 16:17:31 Malaysia time. The app launched successfully; process `5397` and foreground `com.zyang.gainpath/.MainActivity` were verified. The captured screen showed the signed-in Firebase Workout page with its published routine. No uninstall, app-data clear or server change occurred. Package first-install time remained 2026-10-01 19:09:19; version remains `0.1.0` / code `1`.

Build command from `apps/mobile`:

```powershell
flutter build apk --profile --no-pub --dart-define=BACKEND=firebase --dart-define=APP_ENV=development --dart-define=GAINPATH_SQUAT_PERFORMANCE=true --dart-define=GAINPATH_POSE_GPU=true --dart-define=GAINPATH_SQUAT_REFINED_PREVIEW=true
```

This retains the phone's existing experimental GPU/direct-refined-preview/performance configuration without changing pose-analysis parameters. Newly prepared decision/3D shadow diagnostics were not enabled by this dashboard install. Production/default CPU behavior and tuple gating remain unchanged.

- APK: `apps/mobile/build/member-progress-install/gainpath-firebase-local-progress-profile.apk` (ignored local artifact).
- SHA-256: `23A714FA5EF25D536E9297F0382BC275CFE6A7AF973E801663B58A0A1B61D511`.
- Actual previously installed APK pulled before update for rollback: `apps/mobile/build/member-progress-install/previous-installed.apk`.
- Build log: `apps/mobile/build/member-progress-apk-build.log`; launch screenshot: `apps/mobile/build/member-progress-install/phone-after-install.png`.
- No local record/outbox migration was performed. Update installation preserves app data; record-level phone validation remains the user's next test, not an inferred pass from installation.

The [latest GitHub run](https://github.com/Haise0619/gainpath/actions/runs/38354219490) for `98d5dec` and the preceding run for `a862007` both have a successful backend job and a failing Flutter `dart run tool/check_architecture.dart` step. The subsequent analysis, workspace tests, web build and APK build steps are skipped. Local reproduction again exits 1 with 21 existing findings. They include feature imports of app composition/concrete data/cross-feature implementations and diagnostic tool/test boundary imports. These commits predate this uncommitted dashboard slice. GitHub Node/setup-java/runner migration annotations are warnings; the failing step is the architecture check. Full raw job logs require authentication and returned 403 through the unauthenticated API; job/step results and annotations were available. No CI configuration or dependency boundary was modified during installation/diagnosis.

## Remaining Firebase and physical gates

1. Finish the separate [Step 7C physical protocol](2026-10-13-step7-physical-protocol.md) for the supported side-view squat and review its acceptance evidence. Dashboard completion does not satisfy that gate.
2. [ENABLED_WORKOUT_TUPLES](../../functions/src/modules/workouts/workout-service.ts) remains `Object.freeze([])`. Only after physical evidence and explicit approval should an exact exercise/detector/model/rule/view tuple be enabled and selectively deployed.
3. Prove a genuinely new, consented human session is accepted once, durably receipted, deduplicated on retry/restart and correctly rejected for conflicts/revocation. Server-accepted fixture labels here do not mean real acceptance is operational.
4. Design/test scoped remote history queries, Rules/indexes, pagination and local/remote merge independently using isolated emulators. Cross-device history requires that future reader; this slice does not query Firebase history.
5. Reconnect scheduling and bounded storage retention/recovery remain the separate P3 increments. Progress browsing must continue to avoid initiating uploads. Rewards require their own authoritative acceptance/policy gates.

## Next proposed content/tutorial slice — requires review first

Implement **real Member exercise tutorial playback for exercises in a published routine**, independently of pose validation. Reuse [exercise_tutorial_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/exercise_tutorial_screen.dart), [routine_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/routine_screen.dart), [workout_prep_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart), [published_routine.dart](../../apps/mobile/lib/features/workout/data/published_routine.dart) and the domain [TutorialRepository](../../packages/gainpath_domain/lib/src/workout/repositories/tutorial_repository.dart)/[TutorialVideo](../../packages/gainpath_domain/lib/src/workout/entities/tutorial_video.dart). Use the existing admin [Firebase exercise catalog mapper](../../apps/admin_web/lib/infrastructure/firebase/firebase_exercise_catalog_repository.dart) as contract evidence, without importing admin implementation into mobile.

The current Member tutorial screen animates an eight-second demonstration and painted skeleton; it is not video playback. First freeze a bounded member-readable tutorial projection and exercise-ID/media-reference mapping against the real catalog/Rules. Then add a member query adapter, reuse the existing tutorial layout with a real player, and bind Watch tutorial/View routine to that published exercise identity. Show loading, missing media, read denial and offline/playback errors truthfully; pause/dispose on background/logout. Keep tutorial viewing separate from measured workout completion/rewards. Tests should cover published/draft visibility in isolated emulators, ID mapping, unsupported exercises, failed/missing media and player/account lifecycle. Any new Rules/resource change must be a separately reviewed increment.

No next-module implementation has started. Stop for user review of this local-data slice.
