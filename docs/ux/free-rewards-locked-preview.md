# Free Rewards locked previews

Implemented in `c658751` on 12 November 2026. Backend rules, account data, point issuance and reward redemption are unchanged.

Known Free membership now retains **Play Mini-Games** with visible, dimmed Move & Catch / Reach & Tap covers. A white foreground card adds a circular purple lock, concise copy and **View membership plans**. Paid game hosts are not mounted for this preview. Unknown/error access still shows verification/retry, and Basic/Premium still use their existing content.

**My Reward Goal** displays the saved or first available published product, its actual image/title/point cost, and locked redemption guidance. Premium-only products remain explicitly Premium-only. Empty/unavailable catalogs use honest gift artwork without invented products or prices. **Browse rewards** opens the existing shop, whose server-backed redemption restrictions remain in force. Free goal-edit controls are absent from this preview; no selection, balance or stock is mutated.

Points balance, daily check-in/base earnings, weekly rank, badges and points history stay in their existing dashboard positions. Existing paid goal behavior remains covered by regressions.

Background previews use `IgnorePointer`, `ExcludeFocus` and `ExcludeSemantics`, with an accessible informational summary. Only foreground navigation actions are interactive. Overlay copy and buttons have natural height and wrap at large text scales. A one-time 240ms fade with a small entrance translation respects reduced-motion/accessible-navigation settings. Native Material button feedback supplies CTA interaction; continuous pulsing/shimmer is intentionally avoided to keep reading calm and avoid an ongoing animation.

## Verification

- **56 focused Flutter tests passed**, both in the working checkout and an independent Git export of `c658751`. Covers previews, Free-only gating, paid/unknown states, real reward data, Premium-only copy, empty catalog, pointer/focus/accessibility exclusion, reduced motion, existing check-in/history/redemption and paid-game flow.
- **No issues** in scoped Dart analysis across all changed source and test files.
- **Nine viewport/text combinations passed**: 320, 360 and 390 dp at 100%, 150% and 200% text. **45 actual Flutter PNGs** capture top, game cards, game CTA, goal product and goal CTA.
- Representative images were opened and inspected, including 360/100% games, 390/150% goal, and 320/200% CTA/navigation. The render suite checks every requested combination for Flutter exceptions; not every PNG received individual visual inspection.
- Independent read-only code review found no important defects.
- Android arm64 Debug build passed from clean source. [APK](../../build/free-rewards-locked-20261112/clean-c658751/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk). It was not installed during this UI task.

## Visual evidence

- [Mini-Games at 360dp / 100%](../../build/free-rewards-locked-20261112/360-100-games.png)
- [Reward goal at 390dp / 150%](../../build/free-rewards-locked-20261112/390-150-goal.png)
- [Large-text CTA/navigation at 320dp / 200%](../../build/free-rewards-locked-20261112/320-200-goal-cta.png)
- [Clean-source test log](../../build/free-rewards-locked-20261112/clean-c658751/verification.log)

Screenshots use synthetic fixture accounts and an empty product image URL to exercise the genuine catalog-image fallback; configured live product images use the existing cover widget. Offline rendering loads bundled fonts, with the existing test helper substituting Barlow where runtime Google Fonts are unavailable. No live account was signed out or changed, backend deployed, or unrelated dirty Coach/home/workout source included in the APK. Physical-device layout, screen-reader navigation and a real purchase/return remain separate UAT steps.
