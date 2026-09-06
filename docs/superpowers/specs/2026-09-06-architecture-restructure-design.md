# Architecture Restructure — Design Spec

**Date:** 2026-09-06
**Status:** Approved by user. Scope for this pass: Phases 0–4. Phases 5–7 are recorded here for direction only and get their own specs.

## Goal

Move the GainPath Flutter prototype from a flat `screens/` + one static `MockData` class into the feature-first, BLoC + repository layout described in the FYP report (Chapter 4, sections 4.1.3, 4.2, 4.3), without changing visible behaviour and without losing Git history on moved files.

## Current state (verified 2026-09-06)

- One Flutter package, 84 Dart files, ~26k lines. Dependencies: `google_fonts`, `syncfusion_flutter_charts`, `syncfusion_flutter_gauges`, `web`. No Firebase, no Cloud Functions, no state-management package, no ML/camera code. The "pose tracking" is a `Timer` + `AnimationController` + `CustomPainter` inside `LiveWorkoutScreen`.
- `lib/data/mock_data.dart` (1,694 lines) holds 33 model classes, all seed data, policy constants and computed helpers.
- 261 `MockData.` reads and 16 in-place `MockData.<list>.add/remove` mutations from inside screens (60 of 84 files import it).
- 214 `setState` calls across 54 stateful widgets. 144 raw `Navigator` calls. 28 stringly-typed `status == '...'` comparisons.
- Three files each hold 6–8 screens (`gamification_screens.dart`, `workout_screens.dart`, `profile_screens.dart`).
- Cross-role import: `coach/profile/coach_account_screen.dart` imports `member/coach_booking/coach_profile_screen.dart` and `member/coach_booking/widgets/coach_card.dart`.
- `widgets/` contains feature screens (`billplz_checkout_screen.dart`, `change_password_sheet.dart`).
- `test/widget_test.dart` is the default counter test and fails.
- No `.gitattributes`; `core.autocrlf=true` on this machine, so Git warns LF→CRLF on every touched file.

## Decisions

| Question | Decision |
|---|---|
| Layout | Feature-first by domain, single package (Option A). Structured so a Melos monorepo split is a later mechanical lift. |
| State management | `flutter_bloc` (per report §4.1.3). Blocs for flows with rules/async; Cubits for simple lists. |
| Data access | Abstract repositories in `features/*/domain/repositories/`; `InMemory*Repository` in `features/*/data/in_memory/` wrapping today's seed lists (session-scoped, mutable). Firebase implementations come in Phase 7 behind the same interfaces. |
| Routing | Unchanged in this pass (`Navigator`). `go_router` is Phase 5. |
| Imports | Absolute `package:gainpath/...` everywhere. |
| Git history | Pure moves (`git mv`, import-only fixes) are committed separately from content edits. `.gitattributes` with `* text=auto eol=lf` is added and the tree normalised before any move. |
| Scope now | Phases 0–4. |

## Target layout

```
lib/
  main.dart                       bootstrap: build repositories, runApp
  app/
    app.dart                      GainPathApp
    shells/                       member_shell, coach_shell, admin_shell, admin_breadcrumb
    di/                           app_repositories.dart (RepositoryProvider tree)
    theme/                        theme.dart (split later if needed)
  core/
    domain/                       app_role.dart, shared value objects
    platform/                     csv_export.dart (+ stub/web)
    utils/                        formatters
  shared/
    widgets/                      one file per widget from shared.dart
    charts/                       bar_chart.dart, trend_chart.dart
  engine/                         Phase 6 (pure Dart pose/form/audio/minigame)
  features/
    identity/      M1, M8, M11 — accounts, auth, profiles, branches
    workout/       M2 — exercises, sessions, tutorials, routines, equipment
    gamification/  M3 — points, streaks, badges, mini-games, rewards, leaderboard
    coaching/      M7, M9, M10 — bookings, availability, roster, notes, messages, reviews
    membership/    M4 — plans, transactions, refunds, promo, Billplz checkout
    chatbot/       M6 — chat, saved advice, disclaimer config
    analytics/     M5, M9.3, M12 — member progress, coach earnings, admin reports
    recommendation/ M13 — risk leads, threshold
    content/       M11 — announcements, system settings
      each feature:
        domain/      entities/, enums, policies/, repositories/ (interfaces)   — no Flutter imports
        data/        in_memory/ (seed + repository impls)
        application/ blocs / cubits
        presentation/ shared/ | member/ | coach/ | admin/
test/
  app/app_smoke_test.dart
  features/<feature>/domain/*_test.dart, application/*_bloc_test.dart
```

Dependency rule: `presentation → application → domain ← data`. `domain` imports nothing from Flutter or other features. Features never import another feature's `presentation` folder; shared cross-role views live in that feature's `presentation/shared/`.

## Phases

**Phase 0 — hygiene.** Commit dirty files (done, `9240e57`). Add `.gitattributes`, normalise EOL. Replace broken test with a smoke test. Add `flutter_bloc`, `equatable`, `bloc_test` deps. Convert all relative imports to `package:gainpath/...`.

**Phase 1 — mechanical moves.** Create skeleton. `git mv` every screen to `features/<f>/presentation/<role>/`, one feature per commit, imports only. Shells → `app/shells/`. `AppRole` → `core/domain/`. `csv_export*` → `core/platform/`. `shared.dart` → one file per widget. `billplz_checkout_screen` → membership; `change_password_sheet` → identity. New `coaching/presentation/shared/coach_public_profile_view.dart` removes the cross-role import.

**Phase 2 — domain extraction.** Split `mock_data.dart`: entities → `features/*/domain/entities/` (one file each); enums from report Table 4.3 replace string statuses where the code compares them; policy constants/rules → `features/*/domain/policies/` as pure functions with tests; seed data → `features/*/data/in_memory/*_seed.dart`. `MockData` becomes a facade re-exporting seeds so screens compile unchanged; deleted at end of Phase 3.

**Phase 3 — repositories.** Interfaces per feature; `InMemory*Repository` over the seeds; `RepositoryProvider` tree in `app/di/`. Replace every `MockData.` read/mutation with repository calls, feature by feature. Delete the facade. Add an import-boundary check (script in `tool/check_imports.dart`, run in CI/test).

**Phase 4 — Blocs and splits.** Coaching bookings first (richest rules), then workout, gamification (merges the duplicated points state in `home_screen.dart`), membership, chatbot, identity. Split multi-screen files one screen per file while converting. `bloc_test` per Bloc.

**Phase 5 (later)** — `go_router` role-gated shells. **Phase 6 (later)** — `engine/` seam: `PoseDetector` interface, `SimulatedPoseDetector` extracted from `LiveWorkoutScreen`, One Euro filter, rep FSM, tracking health monitor, accuracy score, audio arbiter. **Phase 7 (later)** — `firebase.json`, rules, `functions/` TS scaffold (command/reactive/scheduled/adapters), `Firebase*Repository` implementations, `--dart-define=BACKEND`.

## Verification per phase

`flutter analyze` clean (no new warnings vs baseline of 5 infos), `flutter test` green, `flutter build web` succeeds, app launches on web and Windows and each role's shell renders.

## Out of scope for this pass

Behaviour changes, new features, Firebase, ML, routing library, monorepo split, UI redesign.
