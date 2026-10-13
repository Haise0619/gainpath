# P0 Architecture Checker and CI Recovery Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for the root runner/CI work and focused parallel tasks for independent checker, identity/UI and workout boundary repairs. Each task ends with tests and review.

**Goal:** Zero genuine checker findings and a GitHub verification run that executes and passes app tests/builds, preserving the latest local dashboard and real squat contracts.

**Architecture:** Keep production import and transitive dependency rules strict. Permit only normalized intra-package tool/tool and tool/test-support references as nonruntime edges. Compose shells/navigation/concrete repositories in app code; presentation consumes injected builders and domain ports.

**Tech stack:** Dart/Flutter workspace, Firebase Functions/Rules tests, PowerShell verification runner, GitHub Actions.

**Spec:** User's approved 2026-10-13 P0 request and [next implementation handoff](../../planning/next-implementation-handoff.md), Task 1; current source supersedes the old baseline counts.

## Global constraints

- Preserve uncommitted authorized Dashboard/password reset work in a separate prerequisite commit, then P0-only commits. Preserve unrelated README/run settings, local historical artifacts and reports.
- No changes to pose estimator/analyzer/counting/scoring, Firebase schemas/Rules/deployment or enabled workout tuples. Hash protected sources before/after.
- Keep mock/live behavior, account guards, consent and durable outbox semantics intact. No broad skips, disabled checker or relaxed production boundary.
- Push the approved commits to the existing branch and inspect actual CI outcomes, repairing only P0 blockers.

## Review focus

- Encoded/normalized relative paths and conditional exports must not let lib/bin reach tools/test support or another package.
- Tool-only dependencies must not become runtime edges; genuine runtime dependency and source-import checks must still reject violations.
- Profile ready construction must retain the account-owned Cubit/providers and clear old account routes.
- Workout route factories must retain real exercise/routine identity, prior consent, save/result callbacks and existing logout guards.
- Verification must analyze maintained code, retain experimental snapshots, and run subprocess tests with their actual Dart runtime rather than flutter_tester.

## Increments

- [x] Record working tree, commit/workflow/checker baseline (21 = six tool + fifteen runtime findings); preserve prior authorized slices separately and protected hashes.
- [ ] Checker: `tool/check_architecture.dart`, `test/tool/check_imports_test.dart`; RED regression tests, narrowly scoped same-package tool/test-support allowance and unchanged runtime/encoded/cross-package negative checks. Commit independently after review.
- [ ] Identity/common UI: profile-ready WidgetBuilder from mobile composition; move unavailable UI helper into shared UI; remove feature imports of app composition. Add focused profile/account tests; retain dashboard factories.
- [ ] Workout: published routine view belongs to domain, old data import path remains compatible; typed navigation/builders injected by app; sync panel consumes a listenable domain port implemented by existing outbox. Add focused route/sync tests; leave business logic/wire formats untouched.
- [ ] Runner/CI: root/pure packages use `dart test`; Flutter UI/identity/apps use `flutter test`. Fix actual maintained analyzer blockers without editing experimental controls. Keep checker first and blocking; build both apps. Inspect admin live availability and preserve honest connected-only behavior.
- [ ] Run checker regressions, full mobile/domain/data/pose/UI/identity/admin, backend build/typechecks/unit/emulator suites and app builds. Fresh review, source-hash comparison and exact report. Commit then push; wait for actual GitHub jobs/test/build stage outcomes. Stop after recovery.

## Evidence and rollback

Logs are preserved in ignored `build/p0-logs/`; baseline checker also in the local temporary log. Each increment has a separate commit and can be reverted without resetting unrelated work. Remote history/acceptance, device installs and new feature implementation are outside P0.
