# Real Member Tutorial Playback Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline and request a fresh final review. Track RED/GREEN evidence here.

**Goal:** Members can watch real tutorial media for an exact published routine exercise using the current Workout layout; absent or failed media is explicitly unavailable.

**Architecture:** Extend the trusted publishRoutine projection with an optional validated HTTPS `videoUrl` copied from the referenced active catalog record. Members continue reading published org content through their current repository; they never read the staff-only exerciseVideos collection. App composition injects tutorial destinations; workout presentation receives builders and a player port, with the video_player adapter in infrastructure. Mock animation remains isolated.

**Tech stack:** Existing Flutter/Dart/Firebase workspace, official video_player plugin, TypeScript publication unit tests and isolated Firestore Rules emulator tests.

**Spec:** User's 2026-10-13 instruction to proceed to the next implementation, earlier preference for real functional modules alongside separate Step 7C validation, and [proposed tutorial slice](../../architecture/2026-10-13-local-member-progress.md#next-proposed-contenttutorial-slice--requires-review-first).

## Global constraints

- Reuse existing layouts/navigation and retain both mock and live composition. Preserve all unrelated working-tree edits and reports.
- No pose, counting/scoring, local workout, consent/outbox, rewards or enabled workout-tuple change.
- No deployment, Firebase resource writes, device install, media upload or live publication. Backend projection change requires later deployment and a new publication request before current live routines have tutorial URLs.
- Optional row `videoUrl` is additive to schema 1. Older snapshots parse normally; missing, malformed or unsupported media remains unavailable independently of workout targets. No Rules/index change needed.
- Media contract: trimmed bounded (<=2048) absolute HTTPS URL, nonempty host, no userinfo/fragment/control characters, direct `.mp4` path. Signed query strings allowed but not logged/displayed. Browser page/YouTube links, arbitrary schemes and insecure HTTP are not supported in this slice. This validates syntax, not media availability/content/license.
- No generic generated form cues/rest/score in the live tutorial. Only published fields/targets, null/missing states and actual player duration/position. No viewing-completion workout writes.

## Review focus

- Two exercises with the same name must retain distinct IDs/media; first-entry shortcuts cannot change row identity.
- Missing/invalid media must not fail the routine parser or invoke mock animation/native player.
- Initialization/read/playback errors must be bounded/retryable and sanitized; expired URL shows a truthful error.
- Background, disposal and auth scope/role loss release/pause player and suppress late initialization/control completion.
- Published/draft visibility, cross-org and unverified reads remain enforced; no staff-only catalog access or member write grants.

## Tasks

### Task 1: Trusted tutorial projection and backward-compatible parsing

Files: `functions/src/modules/content/publish-routine.ts`, new `functions/src/modules/content/tutorial-media.ts`; `functions/test/publish-routine.test.ts`; existing emulator Rules test; `apps/mobile/lib/features/workout/domain/published_routine_view.dart`, new `tutorial_media.dart`; `apps/mobile/test/published_routine_test.dart`.

Interfaces: optional `PublishedRoutineExercise.videoUrl` (String?); shared app-local `tutorialMediaUri(Object?) -> Uri?`; backend equivalent returns normalized URL or undefined.

- [x] Write and run failing tests for exact-ID media snapshot, immutable/retried projection, blank/invalid policy, and legacy/invalid optional fields.
- [x] Implement optional snapshot and parser; omit unsupported media without blocking publishing valid workout targets. Expected: all focused tests pass.
- [x] Pin existing Rules in isolated emulator: published media allowed to verified active member; draft/cross-org/unverified/staff catalog reads and member writes denied. No resource change.

### Task 2: Real player and account-owned destination

Files: new workout `domain/tutorial_player.dart`, presentation `member/published_exercise_tutorial_screen.dart`; new infrastructure `media/video_tutorial_player.dart`; new `app/routing/exercise_tutorial_route.dart`; `apps/mobile/pubspec.yaml`, root lockfile; new `apps/mobile/test/published_tutorial_test.dart`.

Interfaces: `TutorialPlayer extends ChangeNotifier` with ready/playing/buffering/error/duration/position/aspectRatio, initialize/play/pause/seek/dispose and `buildVideo`; factory `TutorialPlayer Function(Uri)`. Destination consumes SessionScope, exact published row and injected test factory; production constructs native adapter only when supported media and authorized.

- [x] Write/run failing missing/loading/ready/play/pause/replay/error/retry/lifecycle/account/late-init tests with a deterministic player port.
- [x] Resolve compatible official player dependency without changing existing dependency pins. Add native adapter with actual value mapping and sanitized errors.
- [x] Implement existing tutorial layout with real player, explicit play/pause/replay/scrub, actual duration, no autoplay, no unsupported form prose or fabricated rest. Dispose on leave/account loss, pause without auto-resume on background. Expected: focused suite passes.

### Task 3: Existing navigation, verification and report

Files: `navigation/workout_navigation.dart`, `app/routing/workout_prep_route.dart`, `features/workout/presentation/member/{workout_prep_screen,routine_screen}.dart`; updated/new navigation tests; dated tutorial report.

Interfaces: typed tutorial builder consumes exact `PublishedRoutineExercise`; compose guarded app route from AuthBloc scope, preserve AuthBloc across pushed destinations. RoutineScreen receives same builder. Direct feature construction without builder remains honestly unavailable.

- [x] RED/GREEN tests for live Watch tutorial and every routine row's exact exercise selection; mock paths unchanged; no-builder fallback.
- [x] Run maintained analysis, architecture checker, full mobile/admin/domain suites and backend build/typecheck/unit/emulator; build debug APK without installing.
- [x] Fresh review and fix material findings. Record exact files/results/limitations and deployment/media/physical gates. Stop for review; no next module or automatic deployment/push.

## Evidence / status

Starting head: `f13478c`; P0 run 38387351582 green. Current README/run config/local reports are preserved. Existing checkout on `codex/real-squat-flow` is reused so the local approved planning context is retained. This plan is the ledger; log files live in ignored `build/tutorial-logs/`. Revert only this slice's source changes for rollback; no data migration or live side effect.

Task 1: complete — mobile optional projection 6 passing, backend publication 20 passing; current Rules emulator 29 passing. No Rules change. Task 2: complete — real player controls/lifecycle, timeout and account recovery; isolated native adapter test passing. Task 3: complete — exact-ID navigation and app composition, mock regression, full runner/builds, final mobile 313 passing / 15 existing skips and backend 129 passing. Final review: three material findings reproduced with RED tests and fixed; no deferred findings. Source commits and dated report provide rollback/review evidence; no push/deployment/install.
