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

## Published covers, orange accents and Coach preview follow-up

`102cf35` corrects the initial game preview's use of built-in art: it now loads published content through the existing read-only `MiniGameContentReader`, with current-session, organization and generation checks. It does not construct gameplay, scoring or reward services. Real cover images use their complete 16:9 frame. The shared overlay now has a warm orange lock badge/halo and orange section rail; primary CTAs remain purple and previews remain dimmed and inert.

`018014f` applies the same foreground overlay to Free Coach discovery. It reuses current published Coach cards/photos, limits the preview to two, and has honest loading/empty/error content. Previous paid search filters do not hide preview entries. Profile/bookings controls beneath the overlay cannot receive pointer/focus/accessibility actions. Unknown membership remains closed, paid discovery remains unchanged, and My Bookings remains reachable.

**81 combined Flutter regressions passed**, including the nine Rewards and nine Coach width/text-scale combinations (320/360/390, 100/150/200%). Scoped analysis reports **no issues**; independent review found no important defects. A fresh Git export of `018014f` reran all 81 tests and built Android arm64 Debug successfully. [Updated APK](../../build/free-preview-followup-20261112/clean-018014f/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk). It was not installed.

Two actual published game images were retrieved read-only and loaded into the test image cache for deterministic renders; their URLs/tokens and downloads remain ignored local evidence. [Real game covers and orange overlay](../../build/free-rewards-locked-20261112/360-100-games.png), [Coach preview](../../apps/mobile/build/coach-preview-renders/coach-360-1.0.png), [320dp / 200% Coach layout](../../apps/mobile/build/coach-preview-renders/coach-320-2.0.png), [clean verification log](../../build/free-preview-followup-20261112/clean-018014f/verification.log). Representative images were opened and inspected. Coach data in screenshots is synthetic; production uses the published directory/photo reader. No backend deployment or member/points/booking data write occurred.
