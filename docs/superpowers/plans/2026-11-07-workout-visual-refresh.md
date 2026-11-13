# Workout Visual Refresh Implementation Plan

> **For agentic workers:** execute this scoped presentation change inline, then request one independent review.

**Goal:** Make the Workout hub easier to scan and act on with less repeated text and stronger visual hierarchy.

**Architecture:** Keep WorkoutPrepScreen state, routes and execution unchanged. Refine private overview/list/tool widgets and expose a small semantic palette for contrast verification. Use typed RoutineExerciseStatus for presentation.

**Tech Stack:** Flutter, existing Barlow fonts, Material icons and bundled artwork.

**Spec:** docs/superpowers/specs/2026-11-07-workout-visual-refresh-design.md

## Task 1: Visual hierarchy and accessible state presentation

Files: modify workout_prep_screen.dart, create member/widgets/workout_hub_visuals.dart; add test/workout_hub_visual_refresh_test.dart; extend the existing hub render fixture.

- [x] Write widget coverage: primary action stays visible on 375x812; no redundant initial row status; completed/manual and partial/skipped states remain distinct and named; tutorial tap calls existing destination. Test contrast for all palette pairs and light/dark, narrow/large-text/landscape/tablet layouts.
- [x] Run new tests against the original page and observe the intended failure.
- [x] Implement photo/solid-text hero, compact metrics/progress, overlaid order/check thumbnails, typed state badges and compact tool shortcuts. Keep existing copy contracts for CTA, progress fraction and mode labels.
- [x] Run new and affected hub/launch/prep tests with the cached Flutter tool and --no-pub. Run scoped Dart analysis. Inspect fresh renders at normal, narrow/large-text and dark layouts.
- [x] Request independent review of only this change. Fix important findings; re-run affected checks.
- [x] Build local debug APK with unrelated dirty files excluded if practical. Record exact evidence and update active docs concisely. Do not claim device acceptance from fixture renders.

## Review focus

Scheduled versus free attempt status; manual/timed provenance; partial/skipped must not look completed; multi-day indexing; large text with long qualifiers; photo must not masquerade as actual exercise media; accessible actions and contrast in both themes.

## Execution record

Baseline: current hub render test passed. Python search ran using bundled runtime. Existing main checkout is dirty with unrelated Admin/Program/pose work; scoped edits stay in place under AGENTS.md's normal-development/preservation policy. No dependency installation, branch mutation or broad staging.

Task 1 complete: status test observed missing Done before implementation; final 42/42 tests pass (tests.log), seven-file analysis clean (analysis.log), independent review has no important findings, isolated arm64 APK build passes (android-build.log). Large-text metric overflow was reproduced and fixed by allowing labels to wrap. Final UI renders inspected. Device preflight is AOD/Dozing with a black screenshot; no installation. No unresolved review findings.
