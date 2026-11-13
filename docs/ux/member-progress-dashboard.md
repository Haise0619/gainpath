# Member Progress dashboard — 13 November 2026

Implemented the owner's compact dashboard specification. The screen now prioritizes weekly consistency, this week's activity, actual form assessments, personal goals and one latest workout.

## Experience

- Compact purple weekly card with a single label per weekday, accessible recorded/today states and a small Training plan action. Scheduled completion appears only with a known positive scheduled denominator. No 0/0, empty progress bar or embedded current/past schedule.
- One compact activity surface separates camera repetitions, video-timed active duration and self-reported manual sets. Empty categories are omitted; missing routine history is explicitly unavailable. All three use the same labelled Malaysia Monday–Sunday reporting week.
- Form preview shows up to three exercises with valid recorded assessments, one latest score each, date and an optional change from a genuinely compatible prior scored session. Newer unscored captures do not hide an older valid score. Unsupported scoring is never presented as a score. No keyword-only lookup or `rules pending` copy remains in the overview.
- View All Assessments opens an account-guarded secondary list with distinct no-session, saved-but-unscored and unsupported states. Saved sessions remain accessible. View Form Trends preserves the existing advanced-report membership gate.
- Compact goals retain existing calculations and editing destination. Their UTC training-frequency convention is still labelled; it was not silently changed to match the Malaysia activity week.
- Only the latest deduplicated workout appears, with View History. Linked camera captures remain in full history without duplicating workout events.
- Training Report, Workout backup and Measurement details are in the app-bar More menu. Detailed schedules stay in Training Plan. Custom injected program content remains accessible through a guarded secondary plan view.
- Existing entrance fade/slide respects reduced motion. Natural heights, wrapping action labels and unclipped content support narrow widths and enlarged text.

## Data and security boundaries

No pose/counting/Form Score algorithms, saved schemas, history, sync workers, Firebase services or backend rules changed. Aggregation is read-only presentation code. Existing scope checks reject foreign histories; future records are excluded. Comparisons require the complete existing version key, including exercise, scoring rule, detector/model, camera view and arm mode. These are assessment differences, not claims of physical accuracy or fitness improvement.

Camera activity uses saved end dates. Routine timed/manual totals use saved finish dates, falling back to last update for unfinished attempts, matching existing reports. Cross-week workouts are not split or reconstructed. Weekly training days use saved start dates. Technical explanations remain in Measurement details and existing detail/report screens.

## Verification

- 109 tests pass across 19 affected Mobile test files, both in the working checkout and in an isolated HEAD export overlaid with only the 15 intended Dart files.
- Static analysis of all 15 changed Dart files: no issues.
- Two enabled Flutter render tests pass: 18 dashboard scenarios (320/360/390 widths × 100/150/200% text × mixed/empty history), plus six secondary/goals scenarios. Every scroll segment is checked for rendering exceptions.
- Actual Flutter screenshot artifacts: 125 baseline PNGs, 44 final dashboard PNGs, 14 secondary/goals PNGs. Synthetic local fixtures only; no real account data or network media. Repository offline font support substitutes Barlow for any Poppins/Inter fallback; the Member Barlow/BarlowCondensed theme and production widget layouts are used. These are widget renders, not real-device screenshots.
- Android Debug build passes in the working checkout and from the isolated source export (72.1s Gradle build).
- Independent review completed; supplied program-composition regression was fixed and tested, including logout protection. No remaining actionable findings.

Evidence is retained under `build/progress-dashboard-20261113/`, with earlier working verification logs at `build/progress-*.log`.

## Screenshots

Reproduce final renders from `apps/mobile`:

```powershell
flutter test --no-pub --dart-define=GAINPATH_RENDER_PROGRESS=true --dart-define=PROGRESS_RENDER_STAGE=after-final test/member_progress_dashboard_render_test.dart
```

- Before, 390/100: `apps/mobile/build/member-progress-dashboard/before/390-100-mixed-0.png`
- After, 390/100: `apps/mobile/build/member-progress-dashboard/after-final/390-100-mixed-0.png` and `390-100-mixed-1.png`
- After, 320/200: `apps/mobile/build/member-progress-dashboard/after-final/320-200-mixed-0.png` and remaining scroll segments
- Assessment catalogue and populated goals: `apps/mobile/build/member-progress-dashboard/secondary/`

The before images were captured before production UI edits. Running the harness against the redesigned source with a `before` filename does not reproduce the old implementation.

## Acceptance limits

Synthetic rendering verifies layout, data states and wired callbacks. Real-user readability, screen-reader use and live Training Plan/report/PDF/backup acceptance still need device interaction. No live workout, score, goal, membership or payment data was modified to exercise this dashboard. The authorized Xiaomi was disconnected at final preflight, so no APK was installed; the isolated-source APK is retained under the evidence directory.
