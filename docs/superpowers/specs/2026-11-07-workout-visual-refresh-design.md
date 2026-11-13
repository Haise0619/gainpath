# Workout visual refresh

7 November 2026. Owner request: reduce text density, use visual aids and meaningful colors, and prioritize the Member's next action and readable contrast.

## Approach

Use one photographic workout card, compact icon-led facts, a real completion ring and an ordered exercise list. The existing bundled gym photograph is decorative; only actual exercise media illustrates an exercise. Keep the app's Barlow typography and purple primary action. A photo-heavy exercise carousel would hide the training order; another statistics dashboard would compete with Start. The chosen approach keeps the workout and its action together.

```text
Workout                                      Settings
┌ Workout title                 gym photograph ┐
│ Free workout / dated program                │
│ Exercises    Sets    Estimated minutes       │
│ completion ring + saved status    Change     │
│                 START / CONTINUE            │
└─────────────────────────────────────────────┘
Exercises                         View routine
[image + step] Name · actual target · mode/state
[image + step] Name · actual target · mode/state
Tools: compact colored icon shortcuts
```

## Constraints and decisions

- Presentation only. Reuse current selected routine, typed completion status, capability resolver, start/resume/summary actions and navigation. Keep side/arm qualifiers, rest information and truthful manual/timed provenance.
- One primary Start/Continue/Summary action; do not add a second competing CTA or fabricated fitness metrics.
- Purple means primary/tracked; blue means timed/setup; green means completed; amber means partial/skipped/review. Pair colors with icons and explicit short labels. Not-started rows do not repeat that label.
- Normal text contrast >=4.5:1, meaningful icons >=3:1. Use semantic light/dark pairs and test them numerically. Hero text sits on a solid dark panel beside its decorative image.
- Exercise image has an overlaid order/check badge; completed rows carry a check icon and short completion label. Full measurement provenance remains accessible and mode remains visible.
- Compact tools use icon + wrapping label + chevron, retain their callbacks and 48dp touch targets.
- At narrow widths or >=150% text, stack hero content and tools as needed. No truncated exercise names/qualifiers. Respect safe areas and reduced motion; introduce no decorative animation.

## Validation

Fresh widget coverage for primary-action reachability, typed completed/partial/skipped states, accessible names, mode provenance, contrast, 320/375/390px, landscape/tablet, 200% text and dark mode. Run existing affected hub/navigation tests, scoped analysis and fresh fixture renders. Build a local debug APK if checks pass; device installation requires safe idle under the existing standing authority.

## References

- [Nike Training Club](https://www.nike.com/ntc-app): visual training hierarchy and clear workout entry point; no downloaded or copied branding.
- [Material color roles](https://m3.material.io/styles/color/roles): explicit foreground/container pairs.
- UI/UX Pro Max Fitness/Gym App product match and Flutter Semantics/LayoutBuilder guidance. Its marketing-page sections and orange palette do not fit the established Member app; retain GainPath's brand and native navigation.

Execution follows AGENTS.md's standing instruction to proceed with requested local development and choose routine design details without repeated approval. Unrelated dirty Program/Admin/pose work is preserved.
