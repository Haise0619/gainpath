# Complete Workout UX implementation

Owner authorized direct implementation of all four phases in the supplied specification; UI/UX is a primary acceptance requirement. Keep the existing purple identity and workout architecture. Primary requirements: `docs/ux/workout-page-optimization-plan.md`; full owner spec retained privately under `build/workout-four-phases-20261107/requirements.md`.

## Scope and ownership

1. Root: baseline/source review, hub/discovery/settings/journey, integration, complete regression/analysis/build, scoped review, report and commits.
2. Program subtask: Program preview, inline validation, active/historical clarity, safe End Current Plan through controller/store and tests.
3. Execution subtask: shared grammar/time labels, setup/tutorial/camera guide, AI/timed/rest presentation and tests; preserve all camera/timing/consent algorithms and four images.
4. Results subtask: supported result hierarchy, history links where IDs permit, analytics definitions, backup/equipment/preview clarity and tests; no aggregation or backend contract changes.

## Rulings

- Continue on the established `codex/hybrid-workouts` branch, preserving baseline dirty Admin/pose and operational-doc work. Stage only owned files/notes.
- Direct owner instruction supersedes design approval between phases. Implement all phases continuously; use existing capabilities instead of inventing data.
- End plan means clearing activeId with incremented revision, never completion or deletion; retain enrollment snapshots and all workout evidence. Do not claim an Ended domain state.
- Missing stable equipment relationships and backup timestamps use honest unavailable UI; no fabricated links/timestamps.
- App installation only when idle; preserve signer, identity, data and previous APK. Use isolated committed-source export for APK if unrelated dirty pose work persists.

## Verification and delivery

Tests per subtask, then integrated affected suites. Check 320/360 widths, 640 height, 200% text and bottom inset, state-specific hub copy, end-plan cancel/save/conflict/account/reopen, mixed execution and safe interruptions, truthful metrics and history compatibility. Run changed-Dart analysis and Android debug build. Record actual counts, unresolved dependencies and physical limits in `docs/ux/workout-page-optimization-implementation.md`. Commit only completed verified changes and update operational references with isolated notes.

Completion: all four phases integrated; 366 tests passed in 73 affected files, 50-file analysis clean, targeted visual refinements and renders passed, isolated final Android debug build passed. Phone installation deferred because its black screen did not establish safe idle state. See the implementation report for exact files, data boundaries and remaining device/relationship-contract limitations.
