# Shared presentation across backend modes

Mock and Firebase are data modes of the same GainPath application. When their user-facing layout represents the same feature, both must render the same presentation widgets/screens. Use the existing approved Mock design as the visual baseline unless the owner requests a redesign.

- Map repositories into backend-neutral view data and action callbacks. Do not put an alternative Firebase page design behind a backend flag.
- Keep account ownership, Firebase commands, subscriptions and session checks in repositories or data-binding adapters. Shared visual widgets must not read Firebase singletons, roles or collection paths.
- Missing values render `-`; never fill real accounts with demo ratings, session totals, fees, photos or verification claims. Distinguish a known zero/false from unavailable data.
- Reuse existing cards, navigation, spacing and styling. Add matching widgets only when genuine data or actions cannot fit the established design.
- Private images must use scoped authenticated bytes and a bounded avatar with a safe placeholder. Never fall back from a real account to a demo URL, tutorial, document or other media.
- Verify the shared widget with both data adapters and exercise the affected real CRUD/session paths. Do not duplicate full layouts or bypass authorization to make Mock and Firebase look alike.

This applies to subsequent modules as well as the Module 8 Coach account/profile repair. Backend-only features may add appropriate loading/error states, without replacing the shared page layout.
