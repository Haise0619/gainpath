# GainPath Workout Hub — visual and motion redesign

Implemented on 11 November 2026. Implementation commit: `1b98573107789c4b20aac60cbb327a64364fea45` on `codex/hybrid-workouts`. Baseline: `7df040f`. Presentation and navigation integration only; existing workout controllers, checkpoint formats, tracking, authorization and persistence remain unchanged.

## Previous design and existing app language

The previous hero combined the workout action, plan/history/progress navigation, initial progress ring, metrics and switching. This weakened the primary action and made the first card disproportionately tall. Every exercise was displayed immediately, while camera, scanning and browsing competed as tools of similar visual weight.

Inspected current Member Home, Rewards (`AppCheckInDashboard` and related screens), Workout, Member shell, Member typography theme, shared tokens, Panel, exercise media and Material routing. Current Home edits were read as references and preserved. The shared language is Barlow body / BarlowCondensed headings, purple `AppColors.primary`, lavender background and selected surfaces, rounded white cards, modest borders and native Material feedback. Home's photographic workout card and Rewards' purple points hero have different jobs; the redesigned Workout uses their shared typography, palette and surface treatment without duplicating either composition.

Public references informed organization rather than artwork: [Hevy routine organization](https://www.hevyapp.com/features/gym-routines/), [Nike Training Club's separation of workouts and programs](https://www.nike.com/ntc-app/), and [Fitbod's distinct exercise history and trend views](https://fitbod.me/blog/exercise-history-and-records/). The UI/UX skill search script could not run because no usable Python interpreter is installed. Design decisions use the inspected app and the skill's general accessibility guidance; no database palette result is claimed.

## Final visual specification and information architecture

| Element | Specification |
| --- | --- |
| Screen | Existing Member theme/background and compact pinned Workout header; Settings stays in the header |
| Spacing | 20dp horizontal margin; 24dp major-section gap; hero padding 18dp; row padding 12–14dp |
| Surfaces | White/theme surface; 20dp hero radius; 16dp row radius; subtle lavender hero outline; no heavy shadow |
| Typography | Theme titleLarge for section headings; theme-derived condensed 26dp hero title; 15.5dp exercise titles; 12dp metadata |
| Action | Purple full-width 52dp minimum primary CTA with wrapping; existing catalog switcher remains secondary |
| Accent | Small `#FF9A3C` not-started status dot; restrained completion treatment; purple remains interactive |
| Exercise media | Existing actual exercise URLs and safe missing-media fallback; uniform 56×60dp thumbnail area; retained network image cache |
| Accessibility | Labels wrap; no fixed hero height; meaningful statuses and provenance; explicit destination button semantics; native touch targets |

The six responsibilities are now separated:

1. **Header:** Workout and Settings.
2. **Current workout:** selected identity, name, genuine metrics, status and one existing state-resolved action. A fresh workout has no dominant zero-progress ring. Started attempts use a lightweight real-count progress bar. The representative fresh 390dp render has an approximately 214dp hero; long content and large text may increase it.
3. **Training Plan:** active enrollment title and actual next scheduled session, independent of whether Free Workout is selected. It has View Plan, or an Explore programs empty state. Existing recovery and return-to-planned actions are retained.
4. **Your exercises:** first three selected-day rows, total count, View all / Show fewer, actual prescriptions and mode/provenance. Preview opens the exact selected exercise through existing callbacks.
5. **Your Activity:** coordinated History and Progress destinations; existing Routines / Exercise sessions and analytics/goal routes stay intact.
6. **Help & Equipment:** compact Equipment and Camera setup rows. Equipment opens scoped browsing; its toolbar now offers Scan equipment through the existing authorized scanner.

## Before / after

| Before | After |
| --- | --- |
| Composite hero with unrelated shortcuts | Focused action card followed by independent Plan and Activity |
| Empty progress ring before starting | Small truthful status; real linear progress only after starting |
| Full exercise list immediately | Compact first-three preview and animated disclosure |
| Larger thumbnails, outlined elevated rows | Uniform smaller media, minimal white rows, wrapping titles |
| Three competing tool tiles | Two low-priority help/equipment entries; scanning inside Equipment |
| Static presentation | Controlled entrance, press, progress, identity and disclosure transitions |

## Motion and correctness

- One 300ms controller belongs to the mounted hub layout; section fades and small upward movement use staggered intervals. Parent updates and tab returns do not restart it.
- CTA scales gently to 0.985 over 100ms on pointer press, retaining Material feedback. A local synchronous guard coalesces rapid taps and remains held across asynchronous launch callbacks. Existing route-level launch, account, foreground and identity checks remain authoritative.
- Genuine completion counts animate over 280ms. Status changes use 180ms switching. A completion icon reflects supplied saved state; there is no new haptic, confetti, unsaved success or replayable celebration.
- Expand/collapse uses a 260ms AnimatedSize with easeInOutCubic. Collapse first returns to the exercise section anchor. Stable row keys and the existing image cache prevent identity confusion and unnecessary image churn.
- Switching keys include Free/Scheduled source, routine/day or enrollment/day identity. Outgoing hero content is removed from layout and semantics; old progress cannot remain interactive or appear under the new identity. The new hero fades in and height adjusts.
- `disableAnimations` and `accessibleNavigation` disable custom motion. Size animation is bypassed entirely in that mode, correcting Flutter's zero-duration AnimatedSize layout assertion.
- Existing MaterialPageRoute transitions remain consistent across destinations. Camera/tracking animation and processing code were not changed.

Compared the consent, preview launch and capture-lease method region against baseline after removing formatting whitespace: identical. Route changes add only two read-only Plan projections. No domain model, backend API, Firestore schema, tracker threshold, reward policy or historical data was changed. Existing finished Free workouts retain their established repeat/start-new-attempt semantics; completed scheduled attempts retain View Workout Summary.

## Responsive and visual review

Validated 320, 360 and 390dp widths at 100%, 150% and 200% text, plus 844×390 landscape and existing dark/tablet variants. No redesigned hub overflow remains. Long names, disclosure, initial/in-progress/completed scheduled states, Plan empty/active, identity switches, recovery/error/empty states, Settings, rapid taps, asynchronous launches, destination roles and preview-back scroll preservation are covered by new or retained tests. Larger text increases component height and uses normal scrolling rather than clipping or shrinking text.

Reviewed actual Flutter renders of the top, middle, bottom and expanded list; fresh and in-progress heroes; active and empty Plan; narrow/double text and dark variants. Corrected metadata overflow, default-font glyph gaps in rendering, Activity card balance and reduced-motion layout behavior during review. The reviewer identified missing button semantics on destination cards; fixed and regression-tested, then independently rechecked with no remaining finding.

Screenshots use synthetic test data, not production records. Missing fixture media intentionally exercises the existing missing-image fallback; production images and prescriptions are unchanged. The final Workout renders use the Member theme and bundled Barlow fonts. Reference Home rendering uses the repository's documented offline font substitution helper; it proves widget composition, not live-account or pixel-identical device rendering.

Artifact root:

`C:/Users/Ngzhe/Documents/Codex/2026-11-11/files-pasted-by-the-user-gainpath/outputs/`

- `previews/before/`: 12 baseline top/middle/bottom PNGs.
- `previews/after/`: 40 new Member-theme/Rewards reference PNGs covering the width/text matrix and three scheduled states.
- `previews/after/matched-fixture/`: 12 after PNGs using the same fixture/theme as the baseline, including dark and large-text variants.
- `previews/references/home-workout.png` and `rewards.png`: existing Home and Rewards reference widgets.
- Representative images: `previews/after/free-390-1.0-top.png`, `free-390-1.0-middle.png`, `free-390-1.0-expanded.png`, `free-390-1.0-bottom.png`, `scheduled-2-top.png`, `scheduled-6-top.png`.

## Verification

All results below are fresh for this task. Clean-source verification used an archive of `7df040f` plus only the 16 scoped Dart files, excluding unrelated dirty Admin, Home, pose instrumentation and domain edits.

| Gate | Result |
| --- | --- |
| Clean-source Workout regression manifest, 125 test files | 694 passed, 29 default feature/render skips; the subsequent added scroll-preservation case passes in the six-case hub test |
| Final render + hub behavior configuration | 25 passed; includes the scroll-preservation case and 19 render scenarios |
| Preview authorization / pose diagnostic flags | 34 passed, no skips |
| Full Pose suite, documented `dart test` runner | 759 passed |
| Final scoped Flutter analysis | 16 files, no issues |
| Android arm64 Debug APK, clean source | Passed; existing Java deprecated-API compiler note only |
| Complete current-checkout Mobile suite | 1,962 passed, 34 skipped, 31 failed; all 31 names reproduce on untouched HEAD |
| Untouched HEAD reproduction of broad-suite failures | 41 passed, 31 failed; identical remaining failing test names |
| Dependency lock | Unchanged SHA-256: `033EA1B9C6F07F442BB73DB960D758D122F72EFA584CE1BDDC559DE0E47D3D79` |

The initial complete Mobile run had one additional failure caused by the new camera label. Retaining the established Camera setup label fixed it without touching the user's dirty fitness-profile test. The optional Preview flag run exposed a fixture tapping before scroll/entrance settled; it now waits for settled layout and retains all consent/account/lifecycle assertions. An initial Pose run used `flutter test`, whose executable caused three CLI subprocess timeouts; rerunning with the documented `dart test` runner passed all 759 cases.

Commands: `flutter test --no-pub --reporter expanded` with `verification/final-workout-manifest.txt`; `dart test --reporter expanded` in `packages/gainpath_pose`; scoped `flutter analyze --no-pub`; and `flutter build apk --debug --target-platform android-arm64 --no-pub`. Render defines: `GAINPATH_RENDER_WORKOUT_HUB=true`, `GAINPATH_RENDER_WORKOUT_MOTION=true`. Diagnostic defines: `GAINPATH_POSE_PREVIEW`, `GAINPATH_POSE_QUALITY_DEBUG`, `GAINPATH_POSE_JOINT_LAG_DEBUG`, `GAINPATH_POSE_REFINED_SKELETON`, all true.

The APK is `gainpath-workout-hub-debug.apk`; SHA-256:

`DE7327B484A7942A65988EF07BC208CBC3896962C39C012428A897C16CC4C247`

Exact clean-source hashes, logs and manifest are in `verification/`. The APK's six production Dart files match the committed implementation; later changes were test-only verification refinements and documentation. Layout and motion were committed together because their presentation widgets and interaction contracts form one coherent implementation; verification/reporting is a separate commit.

## Remaining limitations

The complete Mobile suite is not green because 31 existing failures reproduce on untouched HEAD. They are listed individually below and are outside the redesigned hub's passing regression gate. No unrelated production logic was changed to hide or fix these failures.

The connected authorized Xiaomi reports Dozing, keyguard showing and input restricted. No installation, wake/unlock, active-session interruption or application-data change occurred. Physical TalkBack/touch, real-account visual acceptance, image-loading conditions and performance/thermal testing remain pending. No device FPS measurement or 60 FPS claim is made. Fixture rendering does not establish camera/counting accuracy.

### Existing broad-suite failures

- coach_availability_flow_test.dart: Coach adds and saves a server-boundary window; Member sees persisted schedule and unavailable booking
- coach_availability_flow_test.dart: Firebase Coach reaches dated tab and loses open editor on account drift
- coach_availability_flow_test.dart: open window editor freezes row mutations until Update or Cancel
- lateral_raise_integration_test.dart: 320px double-text setup wraps and prevents duplicate starts
- lateral_raise_integration_test.dart: lateral raise consent requires front setup acknowledgement and offers no upload
- member_contact_details_repository_test.dart: display name membership or session drift never commits either identity field
- member_contact_details_repository_test.dart: display name rejects stale and forged baselines plus blank, control and oversize values
- member_contact_details_repository_test.dart: display name saves both existing identity names and preserves contacts and private photo
- member_contact_details_repository_test.dart: foreign repository baseline, oversized text and control characters never write
- member_contact_details_repository_test.dart: optional contact details save, reopen, replace and clear without touching photo or other fields
- member_contact_details_repository_test.dart: session loss during load stays invalid; email and membership drift prevent writes
- member_contact_details_repository_test.dart: stale baseline rejects write and remains aborted if transaction retries against original
- member_contact_details_repository_test.dart: wrong role, inactive and mismatched organization deny reads
- member_journey_ux_test.dart: active tutorial returns through consent in the same saved attempt
- member_journey_ux_test.dart: manual tutorial opens the same set logger without awarding work
- member_photo_gateway_test.dart: membership change aborts the transaction and invalidates future reads
- member_photo_gateway_test.dart: session loss during read and Auth email drift reject stale results
- member_photo_gateway_test.dart: stale first transaction abort remains sticky when retry sees original again
- member_photo_gateway_test.dart: transaction updates only own photo and timestamp
- member_recommendation_navigation_test.dart: current Coach profile wraps long branch at 375.0px text1.0
- member_recommendation_navigation_test.dart: current Coach profile wraps long branch at 375.0px text2.0
- member_recommendation_navigation_test.dart: current Coach profile wraps long branch at 393.0px text1.0
- member_recommendation_navigation_test.dart: current Coach profile wraps long branch at 393.0px text2.0
- mobile_shared_phone_layout_test.dart: shared mobile hubs retain their layout on a narrow phone
- reverse_lunge_integration_test.dart: lunge consent requires stable phone and both legs acknowledgement without upload
- reward_journey_test.dart: shop, details and My Rewards support small screens with large text
- row_tracker_integration_test.dart: row consent requires stable bench acknowledgement without upload
- shoulder_press_integration_test.dart: 320px double-text setup wraps and prevents duplicate starts
- shoulder_press_integration_test.dart: press consent requires front setup acknowledgement and offers no upload
- squat_decision_diagnostics_test.dart: terminal reports are scalar and buffers clear on close even when logging fails
- tutorial_navigation_test.dart: Watch tutorial and routine rows use injected exact row identity
