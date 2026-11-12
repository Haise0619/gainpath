# Training Report and Rewards & Check-in — consumer redesign

12 November 2026. Baseline `2a53e81098d27026ff5647de65b075a4e2237e79`. The work changes presentation, navigation and narrowly scoped request coalescing; it does not activate reward policies or rewrite workout/report calculations.

## 1. Original UX problems

The Report repeated saved activity through a timeline, exercise breakdown and technical attempt list, and gave charts/evidence similar weight to consumer summaries. Its terminology obscured completed-workout semantics. The real Points & streak page used `LivePointsProgress`, not the legacy demo screen, and loaded receipt data once with no in-page retry. Points/check-in concepts were presented alongside workout Progress destinations.

Inspected actual Home, Workout Hub, History, Progress, Rewards, the live and legacy points routes, account-scoped repositories, check-in host/cubit, report engine and Android PDF exporter. Existing Member typography is Barlow/BarlowCondensed with purple, lavender, light backgrounds and rounded white surfaces. New pages reuse that language; global navigation/theme and unrelated Home edits remain intact.

## 2. Page responsibilities

| Destination | Responsibility |
| --- | --- |
| Workout | Start/manage training |
| History | Inspect individual saved workout records |
| Progress | Training consistency, trends and compatible AI assessments |
| Training Report | Selected-period summary, activity review and PDF export |
| Rewards & Check-in | Available points, explicit daily check-in and reward receipts |

## 3. Training Report hierarchy

The header is **Training Report**, with filter and Export PDF actions. The selected dates and Malaysia timezone remain visible. Routine/exercise filtering stays in the existing bottom sheet; Reset filters appears only when the selection differs from the default 30-day filter. Export captures the existing immutable result/document before awaiting the Android picker.

One compact summary shows completed workouts and distinct AI/Video Timed/Manual activity. The completion explanation moves to an info action: completed routine-day attempts count separately even on the same calendar day; an exercise match never completes the whole routine.

**Workout activity** is the single primary activity list. A routine appears once as a parent, expands to actual matching exercises, and retains links to individual AI captures and the saved workout record. Linked captures do not also become standalone parent workouts. Genuinely standalone AI sessions remain directly accessible. Reviewed/skipped/not-started rows explicitly say no activity recorded rather than becoming invented Manual zero-set results.

**AI Form Assessments** is separate. Existing compatible grouping remains authoritative. Supported recorded scores retain their exercise/scoring/detector/view/arm-mode separation; unassessed captures stay unavailable. A single capture has no meaningless trend chart; multi-capture charts retain gaps for missing assessments. Lateral Raise, Shoulder Press, Timed and Manual results do not receive fabricated scores or a routine-wide average.

Technical IDs, versions and other evidence move behind **Technical details** and assessment detail disclosure. No recorded evidence is deleted.

## 4. Rewards & Check-in redesign

The normal member route remains `LivePointsProgress` with the real Rewards repository, `AppCheckInHost`, session keys and repository guards. The new presentation page is `RewardsCheckInPage`.

- Available points is the actual spendable balance, never lifetime earnings.
- Daily check-in shows current/longest **check-in streak**, today's authoritative status and the explicit existing claim action. Opening the page only reads data.
- Points activity labels a fixed last-30-day Malaysia-time period, recorded earnings, recorded spending and compact receipts. Incomplete coverage is disclosed; returned-record totals are not presented as complete lifetime totals.
- View reward history opens the existing receipt destination and refreshes on return.
- Receipt-source failure can no longer hide a readable wallet: an independent existing overview read supplies a confirmed balance while the page explicitly marks receipts unavailable or stale. This also handles the existing receipt endpoint's bounded history behavior without backend changes.

The legacy `GamificationProgressScreen` was inspected and terminology aligned, but its demo charts were not connected to the real member route.

## 5. Navigation

Normal paths are Workout → Progress → Training Report and Rewards → Rewards & Check-in → reward history. The Rewards dashboard has a guarded live-route shortcut and refreshes after returning. Progress's former equally prominent Points & streak tile is replaced by a secondary Rewards & Check-in text action. Existing filtered trend → Report callbacks remain unchanged. Bottom navigation is unchanged.

## 6. Data integrity and PDF

Reporting calculations, filter semantics and comparison compatibility remain unchanged. The only report-domain edit is the exported document title, now Training Report. AI repetitions come from captures; timed active duration/sets from timed records; manual sets from explicit self-reported evidence. Elapsed workout duration does not become active exercise duration. Missing assessments do not become zero.

On-screen and PDF totals use the same `MemberWorkoutReport` snapshot. The existing PDF consumer summary, chart data, technical appendix, Android save/open/cancel transport and native pagination remain intact. Export cancellation and failure continue to show truthful feedback, and account drift discards late responses.

Native text-layout verification exercised the real `WorkoutReportTextLayout.java` with long names, Unicode surrogate boundaries and a 2,858-line wrapped report, including bounded page-block height. This is helper-level evidence; it does not claim a physical Android save-picker or pixel-level PDF acceptance run.

## 7. Refresh, retry and lifecycle

The live Rewards page adds pull-to-refresh, a toolbar refresh and in-page Retry. Receipt requests coalesce; check-in refresh also coalesces in `AppCheckInCubit`. Claims and history navigation have duplicate-action guards. Refresh does not submit claims.

Useful existing values remain visible during transient failures with explicit stale-data copy. Generation, repository-current, mounted and foreground checks reject late results. Account/session replacement rebuilds keyed live content. Background/resume invalidates pending work and refreshes on return. Returning from history refreshes both points and check-in; returning to the Rewards dashboard refreshes its existing state. No periodic polling was added.

## 8. Visuals, motion and accessibility

Purple remains primary, with light/lavender surfaces, compact icon treatments and consistent rounded cards. No bright orange filters, new gradients or decorative statistics were introduced. Meaningful report filtering/export/refresh feedback and section expansion use native Flutter components. Report and Rewards transitions respect reduced-motion settings. Native route/back behavior is retained.

Responsive Flutter coverage uses 320/360/390dp at 100/150/200% text, portrait and landscape. Text wraps rather than shrinking; cards grow without fixed-height clipping. Actual screenshot review found and corrected inherited-font gaps, missing mode headings and overly dark receipt dividers. New destination controls retain native semantics/touch targets. Existing high-text-scale and back/account tests remain in the regression gate.

## 9. Before/after visual evidence

Evidence root: `build/report-rewards-consumer-20261112/` (ignored, synthetic test data only).

| Folder | Evidence |
| --- | --- |
| `renders/before-report-*.png` | 32 baseline Report captures from untouched HEAD |
| `renders/after-report-*.png` | 50 Report captures: top/activity/expanded/assessments/lower, filtered, missing-score, empty/loading/error and landscape |
| `rewards-before/` | 42 baseline live-route captures |
| `rewards-after/` | 42 final live-route captures across the width/text matrix and additional states |
| `references/` | Fresh History/Progress top and lower captures with loaded fonts |

Reviewed Report top, lower, expanded, filtered and assessment renders; Rewards top, receipts, narrow/double-text, empty and error renders; compared with actual History/Progress captures and previously inspected Home/Workout/Rewards references. Screenshot fixtures are synthetic and offline. The real Member theme and bundled Barlow assets are used; the existing offline font helper substitutes Barlow only for fallback Poppins/Inter initialization. No live account screenshot or product data was captured.

## 10. Verification

All results are fresh for this task. Clean verification source is an archive of baseline HEAD plus only the scoped changes, excluding unrelated dirty Home/Admin/pose/domain edits. Dependency lock hashes match.

| Gate | Result |
| --- | --- |
| Report phase focused tests | 47 passed: UI 8, product 11, report domain 12, Android exporter 2, render harness 14 |
| Rewards/check-in focused tests | 22 passed, including live route, refresh/retry/claims/account cases and actual-theme state renders |
| Navigation/route final focused gate | 21 passed |
| Firebase Rewards repositories, receipts, redemption and export contracts | 22 passed |
| Related full Domain suite | 192 passed |
| Full Pose suite (`dart test`) | 759 passed |
| Independent consumer Rewards review regression | 9 passed |
| Clean 156-file Mobile regression manifest | 839 passed, 33 default feature/render skips; no failures |
| Clean scoped analysis | 20 files, no issues |
| Clean arm64 Android Debug APK | Passed |
| Native PDF text layout | Long-name/Unicode/large-report checks passed |

The initial clean manifest run found one outdated assertion for the old Workout report title (838 passed, 33 skipped, 1 failed). The assertion now checks Training Report and retains the repository initialization/retry behavior. No reporting calculation or authorization was changed to satisfy it. An initial root navigation fixture needed proper async AuthBloc cleanup; corrected before its passing gate. No known failing relevant case is omitted.

Reproduce with `flutter test --no-pub --reporter expanded` and `mobile-manifest.txt`; full Domain/Pose `dart test --reporter expanded`; scoped `flutter analyze --no-pub` using `changed-dart.txt`; `flutter build apk --debug --target-platform android-arm64 --no-pub`. Render flags: `GAINPATH_RENDER_REPORT=true`, `GAINPATH_RENDER_REWARDS=true`, `GAINPATH_RENDER_REFERENCE=true`. Baseline Report stage uses `REPORT_STAGE=before`.

## 11. Limitations and release boundaries

Real-device Android PDF pagination/rendering/save-picker/open/cancellation, real Firebase refresh and actual daily check-in/redemption acceptance remain pending. Native helper tests and mocked method-channel tests do not establish these physical behaviors. No APK installation, Firebase deployment, live reward/check-in mutation or destructive data operation occurred. No performance/FPS claim is made.

The receipt backend's existing bounded history remains unchanged. Partial/unavailable history is shown explicitly, and wallet fallback remains available. This task does not add backend pagination or invent missing receipt coverage.

The full unrelated application test suite was not used as a release-green claim; the documented clean affected-module manifest is the regression gate. Existing uncommitted work remains unstaged and is excluded from the APK.

## 12. Commits and deliverables

- `0b807c3` — Training Report redesign and regressions.
- `d358cb7` — live Rewards & Check-in and scoped refresh/partial-data behavior.
- `0d0b50e` — Rewards ownership, Progress navigation and terminology.
- Verification/report/reference-harness commit follows these phases.

APK: `build/report-rewards-consumer-20261112/training-report-rewards-debug.apk`.

SHA-256: `A0B1A6B3071CF37A2BBDDB2E2772E0046E0A0E828D210C45228B65D51D50447E`.

`source-manifest.json`, `mobile-manifest.txt`, `changed-dart.txt` and the gate logs record exact source/verification scope. Public-facing copies of the report, selected before/after previews and APK accompany this delivery.
