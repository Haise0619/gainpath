# Member and Coach unified mobile UI

18 October 2026. Source commit: `fc9ba78`. Module 8 was accepted by the owner before this broader presentation integration was requested.

## Delivered behavior

- Normal mobile startup uses Firebase directly, without a separate sample-data product. Explicit injected sample adapters and historical assets remain available for tests.
- Existing Mock layouts remain the baseline for Member Home, Profile/Settings, workout preparation, equipment scanning/browsing, progress reports, rewards, membership and chatbot destinations, and Coach Profile/Settings, directory/detail, roster, availability and earnings.
- Implemented profile/photo/preferences/goals/contact/password/lifecycle, content, equipment, published routines, directory, dated availability, pending booking/list/cancellation and measured local progress keep their existing repositories and actions. Module 8 certification review/publication behavior remains intact.
- Original widgets remain visible. Unknown authoritative values use `-`; verified zero remains zero. Unimplemented payment/refund/reward/AI/game capabilities show truthful unavailable states and cannot manufacture persistence or success. No new backend FR completion is claimed for those placeholders.
- Original report widgets remain alongside measured activity widgets where their meanings differ. Local repetitions, partial attempts, coverage, version-grouped estimates and status receipts retain their semantics; they are not converted into kilograms, reward points or validated routine completion.
- Canonical `AvailabilityPage` and `BookingSelectionPage`, original schedule/roster/card widgets, and scoped controller adapters replace separate persisted-page layouts. Home quick actions, report cards, Rewards and checkout headers wrap at phone widths with enlarged text. Shared `ProgressRow` labels wrap within their existing component.

## Verification and safety

63 focused tests passed in the final 15-file selection, covering Member/Coach navigation and continuity, account CRUD/read-back/error/discard behavior, scoped directory/booking/availability, cancellation, local report semantics, disabled unsupported actions and phone layouts. Targeted analysis reported no issues. `node tools/check-mobile-presentation.cjs` and `git diff --check` passed. No full CI or broad emulator suite was run.

Root inspected captured Home, Rewards and Earnings at 360×800 with 1.3 text scaling. These synthetic-data test captures use test fonts; they are structural checks, not real-device screenshots, live Firebase success or owner manual acceptance. Logs and captures are in ignored `build/mobile-unified-ui/`.

No Firebase deployment, Rules change, backend/domain mutation, identity migration or production data write was performed. Existing AI/pose/scoring, workout stores/history/consent/outbox, Booking allocation/cancellation/expiry algorithms, protected media and Admin functionality were preserved. The four pre-existing owner-modified files retain their original hashes. No push was performed.

## Integrated APK and manual UAT

One integrated Android debug APK built successfully using the normal entry point, without a `BACKEND` selector: `build/mobile-unified-ui/gainpath-unified-member-coach-firebase-debug.apk`. SHA256: `72a2fbb455adae89ebdac7fc88d5597ceada75a38d474103daf0795ac28e3bf7`. The application ID and signing setup were preserved. After explicit owner approval, this exact artifact was installed and launched on Xiaomi model `23013RK75C` on 18 October 2026 at 17:48 Malaysia time. The installer backed up the previous APK/private data, verified matching signing certificates and the installed APK hash, and confirmed private data remained byte-identical before launch. No data clearing occurred. Sanitized evidence: `build/non-core-crud-sprint/mobile-unified-ui/install-result.json`. Manual acceptance of this broader integration remains pending.

1. Member Home/Profile: inspect all original cards/menus; check real name, physical profile, goals, photo and preferences. Save/reopen an authorized own-account edit; check unavailable values show `-`.
2. Member content/workout/progress: open equipment through scanner → browse, published routines/tutorials and existing measured sessions/reports. Confirm actual values and history remain intact; unavailable report sections stay visible.
3. Member Coaches/Bookings: search/open a published verified Coach, inspect real details/availability and existing bookings. Use only disposable authorized test data for any new pending hold/cancellation.
4. Member secondary menus: open rewards, membership and chatbot/saved advice. Original designs should remain, with `-` and truthful unavailable actions where no backend exists; no fake payment, points or AI answer.
5. Coach: inspect roster/availability/earnings and the accepted Profile/Settings/Editor/Certifications/Preview. Confirm real authorized data, safe empty states, save/reopen/discard behavior and sign-out/session isolation. Do not alter existing availability or bookings merely to inspect the UI.
