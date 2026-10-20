# Real Member Tutorial Playback — bounded P8.1 implementation

Starting point: `f13478c`, after P0 CI recovery. The user authorized the next bounded functional slice, with Step 7C physical squat validation remaining separate. This slice implements software for tutorial viewing; no deployment, content write, media upload or phone installation occurred.

## Result and real data source

The existing Member Workout **Watch tutorial** action and every **View routine** row now open an app-composed, account-guarded real tutorial viewer. Selection carries the exact `PublishedRoutineExercise` object, exercise ID, day and published targets; equal display names cannot substitute another exercise. Mock navigation still opens the original animated demonstration.

The only Member data source is the existing server read of `orgs/{organizationId}/content/{routineId}` through [FirebasePublishedRoutineRepository](../../apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart). The trusted [publishRoutine](../../functions/src/modules/content/publish-routine.ts) implementation optionally snapshots a validated catalog `videoUrl` from each referenced active `exerciseVideos/{exerciseId}` record into its published row. It does not accept media/name overrides from the Member or blueprint. Members never read the staff-only catalog. Existing Rules and indexes are unchanged.

This is an additive optional field in the existing schema-1 projection. Older routines and invalid/missing optional media retain their existing exercise targets. **Current live routines are not automatically updated:** the deployed publisher and its existing snapshots still omit media. A reviewed backend deployment, owned/licensed direct media URLs entered by authorized staff, and a fresh publication request are required before the live app has real tutorial media. Reusing an old request ID returns its existing receipt; it does not refresh the snapshot. No automatic migration/backfill is included.

## Playback contract and behavior

- Supported media: bounded (2048 characters), absolute HTTPS direct `.mp4` URL with ASCII DNS/IPv4 host, valid port, no userinfo, fragment, backslash or whitespace/control characters. Query tokens are retained for playback and never shown/logged by GainPath UI. Matching backend/client edge-case tests cover empty fragments and URI normalization traps. This policy verifies syntax, not content, reachability, codec compatibility or licensing; redirects/server behavior still require media review.
- Missing/unsupported media displays **Tutorial video unavailable**, never a fake player or demo fallback in live mode. Expired/offline/decoder failures show a sanitized retry state without exposing a URL/token/native message. Initialization and controls time out after 20 seconds and release their player.
- Native playback uses the official [Flutter video_player plugin](https://docs.flutter.dev/cookbook/plugins/play-video). Installed SDK constraints resolved `video_player 2.11.1`, Android adapter `2.9.5`; all existing locked dependencies are unchanged. Android minSdk stays 26. INTERNET permission is added to the main manifest so release builds also have network access; Flutter regenerates its ignored native plugin registration.
- Actual player duration, position, buffering and play/pause/replay/seek replace the eight-second simulation in the live viewer. No autoplay. Background pauses playback without automatic resume, including delayed play completion. Account/scope/role loss disposes the player immediately; restored same-scope authorization reloads without playing. Late initialization/control results are ignored after disposal.
- Published targets/cues are shown only when present. Live tutorial/routine detail has no invented 90-second rest or generic form prose. Watching never completes a workout, writes a session, submits activity or awards rewards.

## Exact source changes

| Area | Files |
|---|---|
| Trusted publication | [publish-routine.ts](../../functions/src/modules/content/publish-routine.ts), new [tutorial-media.ts](../../functions/src/modules/content/tutorial-media.ts) |
| Optional row/ports | [published_routine_view.dart](../../apps/mobile/lib/features/workout/domain/published_routine_view.dart), new [tutorial_media.dart](../../apps/mobile/lib/features/workout/domain/tutorial_media.dart), new [tutorial_player.dart](../../apps/mobile/lib/features/workout/domain/tutorial_player.dart) |
| Real player/layout | new [video_tutorial_player.dart](../../apps/mobile/lib/infrastructure/media/video_tutorial_player.dart), new [published_exercise_tutorial_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/published_exercise_tutorial_screen.dart) |
| Composition/navigation | new [exercise_tutorial_route.dart](../../apps/mobile/lib/app/routing/exercise_tutorial_route.dart), [workout_prep_route.dart](../../apps/mobile/lib/app/routing/workout_prep_route.dart), [workout_navigation.dart](../../apps/mobile/lib/navigation/workout_navigation.dart), [workout_prep_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart), [routine_screen.dart](../../apps/mobile/lib/features/workout/presentation/member/routine_screen.dart) |
| Dependencies/network | [mobile pubspec](../../apps/mobile/pubspec.yaml), [workspace lockfile](../../pubspec.lock), [Android main manifest](../../apps/mobile/android/app/src/main/AndroidManifest.xml) |
| Tests | updated [published_routine_test.dart](../../apps/mobile/test/published_routine_test.dart), new [published_tutorial_test.dart](../../apps/mobile/test/published_tutorial_test.dart), new [tutorial_navigation_test.dart](../../apps/mobile/test/tutorial_navigation_test.dart), new [video_tutorial_player_test.dart](../../apps/mobile/test/video_tutorial_player_test.dart), updated [publish-routine.test.ts](../../functions/test/publish-routine.test.ts) and [firestore-rules.test.ts](../../functions/emulator/firestore-rules.test.ts) |
| Plan/evidence | [implementation plan and ledger](../superpowers/plans/2026-10-13-member-tutorial-playback.md), this report |

## Verification evidence

| Check | Actual result | Local log |
|---|---|---|
| Full runner `./tool/verify.ps1 -BuildApps` | Tooling 21, Data 77, Domain 54, Identity 19, Pose 70, UI 1, Admin 12, Mobile 310 passed before final review fixes; both debug app builds passed | [verify-full.log](../../build/tutorial-logs/verify-full.log) |
| Final mobile full suite after review fixes | **313 passed**, 15 existing optional diagnostic skips | [mobile-final.log](../../build/tutorial-logs/mobile-final.log) |
| Final maintained mobile analysis / architecture | **No issues found / zero findings**, exit 0 | [analyze-final.log](../../build/tutorial-logs/analyze-final.log); checker rerun in session |
| Backend final build / test typecheck / unit | Passed; **129 tests** across 9 files | [backend-build-final.log](../../build/tutorial-logs/backend-build-final.log), [backend-typecheck-final.log](../../build/tutorial-logs/backend-typecheck-final.log), [backend-unit-final.log](../../build/tutorial-logs/backend-unit-final.log) |
| Firestore/Storage emulator | **29 passed**, 4 files, exit 0; published media read, draft/cross-org/unverified/inactive denial, staff catalog denial and Member write denial | [backend-emulator-isolated.log](../../build/tutorial-logs/backend-emulator-isolated.log) |
| Final corrected debug APK | Built, exit 0; **not installed** | [mobile-build-final.log](../../build/tutorial-logs/mobile-build-final.log) |

Emulator startup initially encountered an existing Java 20 process occupying port 18080. The first alternate attempt had a temporary configuration path error and left its own failed-start process; only that verified task-owned PID was stopped. The successful run used installed Java 21, `demo-gainpath`, ports 18280/19399 and byte-identical Rules/index copies in an ignored temporary directory. Production Firebase was never contacted by these fixtures. The pre-existing emulator process was left untouched. No rule/configuration change is committed.

Meaningful RED/GREEN evidence is preserved in `build/tutorial-logs/`: projection tests failed before optional media existed; navigation failed before the builder existed. The fresh reviewer found stalled control, authorization-restoration and backend/client URL-policy issues. Four mobile regressions and four backend edge cases failed before their fix, then all focused tests and final full suites passed. There are no deferred review findings. Native adapter tests use an isolated platform fixture; they do not prove physical decoding/audio/resource behavior.

The final mock debug APK SHA-256 is `6BF0394B532BC29E08DDAC66549545E6BA2EAE19C3DED0E26136BC59A7E5C0FD`. This is a software build artifact, not a Firebase phone-validation result or Step 7C artifact.

## Preservation, gates and next review

Existing pose/analyzer/count/scoring/native inference, dashboard/history, local persistence, consent/outbox, workout acceptance and rewards source files are unchanged. Of the earlier 84 protected hashes, only the expected content publisher, main INTERNET manifest and ignored generated plugin registrant differ. Existing Firebase Rules/index files and all enabled-workout-tuple source remain unchanged. Original README/run edits, P0 report/plan edits and experimental artifacts remain local and preserved.

The bounded implementation is ready for review. Source commits are local; no new push/CI run, deployment or installation is claimed. Existing P0 GitHub success belongs to `f13478c`, not this slice.

Next gate: review the content projection/player and select actual licensed exercise videos, then separately authorize deployment, republishing and Firebase APK installation/physical playback tests (video load, audio, seek/replay, airplane mode/retry, background/resume, logout, disposal and real-content exercise mapping). Tutorial availability does not establish squat accuracy or open trusted acceptance. Durable offline content/media caching, media upload/retirement and a catalog independent of the currently loaded routine are subsequent bounded P8.1 work, not silently implemented here. Stop before another module.
