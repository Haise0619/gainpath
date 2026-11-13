# Workout Hub: visual-first refinement

## Latest visual refresh — 7 November 2026

The hub now uses a compact photographic title card with a solid high-contrast text panel, inline icon-led facts and real saved progress. Decorative bundled gym artwork stays separate from actual exercise thumbnails. Start/Continue/Summary remains the primary action and is visible on an ordinary phone's first screen.

Exercise order/check badges overlay thumbnails. Typed saved statuses use short Done/In progress/Skipped/Reviewed labels, with green completion and amber unfinished/review states. Full manual/timer/AI provenance remains accessible and execution mode remains visible. Initial rows omit repeated Not started labels. Tools use compact icon-and-label shortcuts: Training plan, Camera setup, Scan equipment and Saved sessions. Semantic foreground/container pairs and Change workout adapt to light/dark themes; no theme switch was introduced.

Fresh verification: **42 tests passed across ten affected files**, including three opt-in render variants; **seven-file analysis clean**; independent scoped review found no important issues; isolated arm64 Android debug APK built successfully. Contrast tests verify all custom text pairs at >=4.5:1. Layout/action tests cover 320/375/390px, landscape, tablet and 200% text. Fresh fixture top/bottom light, dark and large-text renders were inspected. Fixtures do not establish live-account or physical-camera acceptance.

Evidence and APK are under ignored `build/workout-visual-refresh-20261107/`; its manifest records source/APK hashes and the unchanged dependency lock. The build contains committed source plus only this UI change, excluding unrelated dirty Admin/Program/pose work. Read-only Xiaomi preflight found AOD/Dozing and a black screenshot; safe idle could not be established, so no installation was performed. Existing phone application/data were preserved.

[Design](../superpowers/specs/2026-11-07-workout-visual-refresh-design.md) · [Implementation plan](../superpowers/plans/2026-11-07-workout-visual-refresh.md)

## Earlier refinement

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
