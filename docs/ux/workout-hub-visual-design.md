# Workout Hub: visual-first refinement

7 November 2026. Implements the owner's request for lower text density and more visual guidance in the existing Flutter Workout page.

## Design and implementation plan

1. Keep existing free/scheduled/partial/completed/recovery/catalog states and all callbacks. Replace prose metadata with icon-led metric tiles and a single completion ring driven by actual attempt progress, with a readable fraction. Preserve the primary CTA.
2. Keep actual exercise images with existing safe fallbacks. Use short target text and execution-mode badges; move equipment/rest supporting details to tooltips and accessibility labels and existing exercise detail screens. Keep provenance explicit for manual/timed modes. Keep tracker-specific side qualifiers.
3. Reduce utility card copy to a title and colored icon tile. Retain accessible descriptions and existing navigation. Purple identifies plan/primary actions; blue identifies setup/equipment; green indicates completion. Color never acts as the only signal.
4. Extend widget coverage before source changes, verify normal/narrow/200% text layouts and truthful progress; run affected tests, scoped analysis, inspect fresh renders, build isolated Android APK. Preserve unrelated working changes.

Reference: [Apple activity summary](https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios) for glanceable progress and [Nike Training Club](https://apps.apple.com/us/app/nike-training-club/id301521403) for workout browsing. These inform hierarchy, not copied brand artwork. Reuse GainPath assets and Material icons; no external asset download or runtime dependency.

UI/UX Pro Max accessibility/layout guidance applied. Its search script could not run because no usable Python installation was available; recommendations use the read skill guidance and existing GainPath tokens.

## Implemented changes

`apps/mobile/lib/features/workout/presentation/member/workout_prep_screen.dart` now uses private icon-led metric tiles, a completion ring, explicit mode badges and colored utility icon tiles. Exercise thumbnails still come from the actual exercise media with the same safe fallback. Manual exercises display “Self-reported”; timed and AI labels retain the existing capability resolution. Rest and equipment details remain in long-press tooltips, screen-reader labels and existing detail navigation. Tracker-specific arm/leg qualifiers remain visible. Utility descriptions remain accessible without occupying visible lines. Primary actions and all authorizing routes are unchanged.

`apps/mobile/test/workout_hub_dashboard_test.dart` verifies the new information hierarchy and reduced copy at normal/narrow/200% text sizes. `apps/mobile/test/workout_hub_state_copy_test.dart` verifies actual saved checkpoint completion drives ring values and fractions, with existing completed/unfinished/recovery actions preserved.

## Verification and limits

33 tests passed across eight focused files, including one opt-in render test. Scoped analysis of the three modified Dart files is clean. The isolated Android debug APK build passed. Fresh normal-size top/bottom renders were visually inspected; 320px/200% text tests pass without overflow. Rendering uses a clearly separate fixture, so its manual labels do not describe the live catalog's AI capabilities.

Private logs, isolated source and build evidence are under `build/workout-hub-visual-20261107/`. No backend, persistence, counting threshold or analyzer changes. Unrelated Admin and pose work is excluded. Physical acceptance and installation remain pending: the earlier captured test-phone screen was black and safe idle was not established. Existing installed APK and saved data remain preserved.
