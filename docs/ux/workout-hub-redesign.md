# Member Workout Hub redesign

Implemented 7 November 2026. The supplied prompt is a visual reference; existing GainPath state, capabilities and navigation determine the actual experience.

## Changes

The previous dark overview and stacked full-width utility cards are replaced by a light lavender overview and compact tool grid. The overview displays the real routine title, exercise/set totals, estimate and progress, including zero progress before starting. Existing Start, Continue, summary and unavailable-state behavior is retained. Change workout remains connected to the current catalog flow, with its color adjusted for the lighter surface.

Exercise rows retain actual targets, execution labels, completion state and existing navigation. One-set exercises omit the inapplicable between-set rest label; their stored rest prescription is unchanged. The exercise heading wraps at narrow widths and large text sizes.

Workout tools use two columns at ordinary phone widths and one column below 330 logical pixels of available space or above 150% text scale. Cards grow with content. Existing callbacks determine availability: training plan, camera setup, equipment scanning and saved sessions. Existing Settings and bottom navigation are preserved. No new controller, execution engine, camera initialization, schema, timer, reward or persistence behavior was introduced.

## Modified files

- `apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart`: overview, progress presentation, wrapping header, compact rows and private responsive tool widget.
- `apps/mobile/lib/features/workout/presentation/member/published_routine_catalog_controls.dart`: compact Change workout button contrast.
- `apps/mobile/test/workout_hub_dashboard_test.dart`: normal and narrow/large-text responsive layout, navigation callback and presentation-only rest assertions.

## Verification

- 32 focused behavior/widget tests passed across seven test files; the optional render test also passed (33 total across eight files).
- Scoped Dart analysis reported no issues across four checked files, including the unchanged route integration.
- Fresh top and bottom renders inspected; these use a fixture, not a live account or physical AI-tracking session.
- Isolated Android debug APK built successfully from committed source plus only this change, excluding unrelated dirty Admin and pose-instrumentation work.
- Device read-only preflight preserved the previous signed APK and recorded 22 protected saved-data files. The captured screen was black, so safe idle could not be established. No installation or app-data clearing occurred.

Private evidence: `build/workout-hub-redesign-20261107/`. Render fixtures: `apps/mobile/build/member-workout-hub-preview/`.

## Remaining physical checks

Install in place once the phone is visibly idle, then confirm actual free/scheduled routine content, Start/Continue/summary transitions, each available tool destination, device text scaling and bottom navigation. Widget tests and fixture renders do not establish physical-camera accuracy or live-account acceptance. Firebase authorization, optional backup, history identity and Module 13 exclusions remain unchanged.
