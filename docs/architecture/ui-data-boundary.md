# Shared presentation across backend modes

## Single mobile application (18 October 2026)

The Member and Coach mobile entry points now default directly to Firebase. `BACKEND` does not select a second mobile product or sample accounts. Explicitly injected sample repositories remain for tests and historical design references; they are not a runtime fallback when Firebase fails.

Preserve the original Mock widgets, cards, menus and navigation when binding an implemented function. Supply authoritative values through repositories/view data and show `-` when unknown. Keep known zero distinct from missing data. Unsupported actions must not manufacture a booking, payment, reward, AI answer or successful save. New data may add a matching widget where its meaning cannot fit an existing one; camera repetitions must never be relabelled as lifted kilograms, validated form, points or completed routines.

Member Home/Profile, measured reports, rewards, membership and chatbot destinations retain the original presentation. Directory/detail, booking schedule, Coach roster, availability and booking selection share their canonical bodies with the persisted controllers. `AvailabilityPage` and `BookingSelectionPage` own their layouts; historical `live_*` entry points provide state/actions rather than a separate visual product. Module 8's previously accepted shared screens remain in use.

Run `node tools/check-mobile-presentation.cjs` to enforce connected mobile startup and the shared report/coaching composition in addition to the Module 8 boundary. Use focused phone-width and scoped navigation/CRUD tests after changes. Sample data must never populate a connected account.

Mock and Firebase are data modes of the same GainPath application. When their user-facing layout represents the same feature, both must render the same presentation widgets/screens. Use the existing approved Mock design as the visual baseline unless the owner requests a redesign.

- Map repositories into backend-neutral view data and action callbacks. Do not put an alternative Firebase page design behind a backend flag.
- Keep account ownership, Firebase commands, subscriptions and session checks in repositories or data-binding adapters. Shared visual widgets must not read Firebase singletons, roles or collection paths.
- Missing values render `-`; never fill real accounts with demo ratings, session totals, fees, photos or verification claims. Distinguish a known zero/false from unavailable data.
- Reuse existing cards, navigation, spacing and styling. Add matching widgets only when genuine data or actions cannot fit the established design.
- Private images must use scoped authenticated bytes and a bounded avatar with a safe placeholder. Never fall back from a real account to a demo URL, tutorial, document or other media.
- Verify the shared widget with both data adapters and exercise the affected real CRUD/session paths. Do not duplicate full layouts or bypass authorization to make Mock and Firebase look alike.

This applies to subsequent modules as well as the Module 8 Coach account/profile repair. Backend-only features may add appropriate loading/error states, without replacing the shared page layout.

## Enforced Module 8 pattern

`CoachAccountScreen`, `CoachSettingsScreen`, `EditCoachProfileScreen`, `CertificationsScreen` and `CoachAccountProfilePreview` are the canonical implementations for **both** data sources. `CoachProfileRepository` and the application-level `CoachAccountGateway` supply their data and capabilities. `MockCoachModule8Repository` adapts existing sample repositories; `FirebaseCoachAccountRepository` adapts the unchanged Firebase commands and private Storage access. Composition injects them through `CoachModule8Dependencies`; both home and named Coach routes use this composition.

The historical `live_coach_profile_views.dart`, `live_coach_account_settings.dart` and `live_coach_certifications.dart` now contain exports/type aliases only. Do not restore page bodies there. Unsupported capabilities are explicit (for example, sample-mode password management), rather than fake success or a different Settings design. Coach self-deactivation is not provided.

Run `node tools/check-module8-presentation.cjs` to check that Module 8 presentation has no Firebase SDK/adapter imports, duplicate live-page classes or backend-selecting page-body branches. Shared-screen widget/composition tests cover both sources, phone save/read-back, dirty/discard behavior and 360px layouts. Extend this contract/composition pattern for later modules; do not rewrite unrelated modules merely to adopt it.
