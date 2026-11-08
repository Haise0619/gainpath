# Mobile Member Coach UX implementation — 8 November 2026

Implemented the owner-approved mobile member plan. The Admin plan remains deferred and no Admin source was changed in this implementation batch.

## Result

Members can compare compact purple/neutral coach cards, search actual names/specialties/tags, apply data-derived specialty filters, choose a stable sort, inspect a focused public profile and enter the existing schedule or booking flow. Unsupported statistics and testimonial placeholders are removed.

## Coach list

Cards show photo, full wrapping name, verified indicator with its actual meaning, primary specialty, explicit singular/plural rating and review count, location fallback and published session price. Identical specialty tags are suppressed while other actual tags remain. Missing or zero published prices are unavailable under the existing positive-fee paid consultation contract, never Free/RM 0. Missing prices and experience sort last; ties use name then stable ID.

Loading, no published coaches, search/filter no matches, network errors, revoked sessions and page-load failures have separate states. Clear filters and My bookings remain. Pull-to-refresh is available; Load more is below results, with a retry that keeps loaded coaches. Copy explains that search/sorting apply to loaded pages. Return navigation retains query/filter/list state. Same-account adapter reconstruction does not reset the controller; changed account/dataset scope clears old state.

## Coach profile and booking access

A compact identity panel shows rating/review count once, actual experience with a self-reported qualifier and approved-certification meaning. All real specializations and biography remain readable. Missing biography has concise copy. Sessions run, response time, unknown duration and empty testimonials are omitted. No fabricated availability or reviewer identity is introduced.

A persistent SafeArea bottom bar presents the published price and Book a session; it stacks at narrow widths/enlarged text and has at least a 48px button. The body viewport ends above it. View schedule remains a secondary action. Missing prices and unavailable booking callbacks disable booking with an explanation. Existing callbacks still open the authoritative duration/slot/eligibility/payment flow; backend validation remains mandatory.

## Files changed

Production:
- apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart
- apps/mobile/lib/features/coaching/presentation/member/widgets/coach_card.dart
- apps/mobile/lib/features/coaching/presentation/shared/coach_profile_screen.dart
- apps/mobile/lib/features/coaching/presentation/shared/member_coach_presentation.dart (new shared display formatting/typography)

Tests:
- apps/mobile/test/member_coach_ux_test.dart (new)
- apps/mobile/test/member_coach_ux_render_test.dart (new)
- apps/mobile/test/coach_rating_card_test.dart
- apps/mobile/test/coach_directory_flow_test.dart
- apps/mobile/test/coaching_mock_presentation_continuity_test.dart
- apps/mobile/test/live_booking_composition_test.dart
- apps/mobile/test/coach_availability_flow_test.dart

Planning: docs/superpowers/plans/2026-11-08-mobile-member-coach-ux-optimization.md.

## Contracts preserved

Published-only discovery; existing Firebase repositories and authorized rating aggregation; Auth/App Check/organization/account/dataset guards; approved-certification semantics; private certificates/contact/reviewer privacy; paid consultation pricing; duration/slot/payment/hold/cancellation rules and booking navigation. No backend, Rules, account, financial or product-data changes. No Admin plan implementation. No new dependencies.

## Fresh verification

- 64 affected Flutter tests passed across 11 files, including 8 render scenarios.
- Static analysis across all 11 changed source/test files: no issues found.
- 24 fixture renders generated at 320px/360px with normal/200% system text and the member app's additional 1.1 text scaling, light and dark palettes. Representative normal/large-text renders were visually inspected. Light uses the production member theme; dark uses a theme test harness because the ordinary app currently exposes a light theme. Actual bundled Barlow fonts are loaded for coach text; the shared offline helper substitutes font assets for unused Google font setup. These are deterministic widget renders, not device captures.
- The previously timing-out member schedule integration test was reproduced on untouched committed source, before opening Coaches. Injecting existing in-memory program/journey stores removes its unrelated persistence dependency; schedule navigation/logout now passes. Existing booking composition fixture now supplies a valid positive published fee so it can exercise the paid booking journey.
- Fresh scoped independent review: no actionable findings.
- Android debug APK built from an isolated committed-source snapshot plus only the requested coach source changes; see ignored build/member-coach-ux-20261108/ for build completion, hashes and source manifest.

## Deferred dependencies and limits

Published profiles expose branch IDs but no authorized human-readable branch names. Widgets accept trusted name maps for future composition; until supplied, members see Location confirmed when booking. Review-detail and next-slot enhancements are deferred; aggregate-only reviews are not testimonials. Search/sort remain limited to loaded pages and say so. No private credential document access was added.

No physical-device acceptance or installation is claimed. On a safely idle phone, verify authenticated list/profile/refresh, real photos, search/filter/sort, back-state preservation, 200% system text, safe-area behavior, schedule and navigation into booking without initiating an unintended paid reservation. Also verify sign-out and unavailable/unpublished cases. Installation must retain app signer/data and the previous APK under standing rules.

## Commit and evidence

The source, relevant test updates, this report and mobile plan are committed together; the final delivery names the exact Git commit. Existing unrelated dirty/staged work remains outside that commit. Private build evidence is retained under build/member-coach-ux-20261108/.
