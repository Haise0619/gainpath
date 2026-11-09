# Member Home refinement

Implement the supplied requirements directly, preserving existing controllers, data stores, authorization and routes. Content order: Daily check-in, Today's Workout, Weekly Progress, optional Upcoming Coaching, Recent Activity, Quick Access, Your Goals. Use the supplied WebP unmodified as the workout background with a restrained legibility scrim.

Keep existing header/page structure. Compact the Home check-in using actual server days/streak/claim eligibility; leave other check-in presentations and reward logic alone. Remove workout chips/badges; choose Start/Continue/View summary using current-account, matching-plan attempts (completed summary only for today). Weekly completion comes from RoutineProgress, with truthful loading/empty states and no invented weekly target. Resolve activity labels from stored routine exercise names then published catalog names; show at most two records with inline backup status. Four shortcuts: Progress, Bookings, My Plan, Equipment; preserve others in a scrollable More sheet. Goal names have no pretend percentages. Owner follow-up: retain the previous circular FloatingActionButton presentation at 56px, preserving chatbot routes. Reserve 72px plus bottom SafeArea inside the body so the floating entry cannot overlap the scrolling viewport or Bottom Navigation.

- [x] RED→GREEN tests for hierarchy, attempt states, real weekly completion/activity names, check-in eligibility, navigation and non-overlapping AI placement.
- [x] Implement compact widgets, matching-plan data selection, My Plan routing, and supplied image asset.
- [x] Verify 320/360px normal and 200% text, scroll all sections and inspect screenshots. Run affected tests and analysis; final independent review.
- [x] Build isolated Android Debug APK excluding unrelated dirty work, verify source/lock/asset hashes. Preserve device/data; install only if authorized safe idle is observable.
- [x] Update verification/docs and commit exact scope. No backend, reward/tracking/enrollment/backup contract changes.

Verification: 63 tests across 14 affected files passed; all scoped source/test analysis is clean. Four 320/360px and 100/200% text scenarios generated 24 captures, including the scrollable More sheet. Normal and enlarged views were inspected. A real large-text header overlap was corrected. Final independent review found no Important/Critical issues. A grouped child-backup status omission was then reproduced RED and corrected GREEN; the complete suite and renders passed again.

Upcoming coaching uses the existing scoped booking reader over the allowed 30-day window, including cursor paging and account late-response checks. It refreshes on initialization, pull-down refresh and return from Home-pushed routes; no periodic polling. My Plan uses the existing auth-wrapped route and injected stores. No goals or percentages are invented.

The isolated Android Debug APK excludes unrelated dirty work, matches all scoped source/test hashes, preserves the dependency lock, and contains the supplied WebP byte-for-byte. APK SHA-256: 1c9d0b13b451508e5f41d25c0c87aee93cff763c67c297c13e0012b41d76c25b. Xiaomi 7c4cbff is Dozing; installation and physical acceptance remain pending. Physical checks: scroll/claim, workout Start/Continue/summary, My Plan and booking routes, backup labels, chatbot open/return and actual SafeArea/Bottom Navigation with Android font settings. No backend change or product-data writes. Private evidence: build/home-refinement-20261109/.

Final owner steering: restored the circular floating chatbot button, with the same navigation and smaller mobile size. The floating-button RED test passed after implementation; all 63 affected tests and four render scenarios passed again, scoped analysis stayed clean, and the final isolated APK was rebuilt and hash-verified.

Modified implementation files:
- apps/mobile/lib/app/home/member_home_screen.dart
- apps/mobile/lib/app/home/member_home_data.dart
- apps/mobile/lib/app/shells/member_shell.dart
- apps/mobile/lib/features/gamification/presentation/member/app_check_in_card.dart
- apps/mobile/lib/features/gamification/presentation/member/home_daily_check_in_card.dart
- apps/mobile/pubspec.yaml
- apps/mobile/assets/images/home_workout_gym.webp

Updated/new Home tests:
- apps/mobile/test/member_home_refinement_test.dart
- apps/mobile/test/member_home_refinement_render_test.dart
- apps/mobile/test/member_home_redesign_ux_test.dart
- apps/mobile/test/member_home_header_test.dart
- apps/mobile/test/member_home_mock_continuity_test.dart
