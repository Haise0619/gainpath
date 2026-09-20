# Complete GainPath Architecture Implementation Plan

**Goal:** Finish the structural migration of the existing prototype into two usable Flutter applications with enforceable package boundaries and a tested Firebase foundation.

**Architecture:** Mobile owns member/coach workflows; admin web owns staff workflows. Pure Dart domain and pose packages provide contracts and processing. Data implementations are injected at app composition roots. A modular TypeScript backend owns authoritative operations.

**Spec:** `docs/architecture/2026-09-17-gainpath-target-architecture.md`

**Scope:** Complete architecture and migrate existing behavior. Actual payment-provider provisioning, deployed Firebase resources, trained/native ML integration and all future business features remain subsequent implementation work. Existing screens must remain available in their respective applications.

## Execution

- [x] Migrate every root feature: domain to `packages/gainpath_domain/lib/src/<feature>`, fake data to `packages/gainpath_data/lib/src/<feature>`, shared visual components to `packages/gainpath_ui`, and screens/BLoCs to their owning app. Remove the root compatibility runtime after consumers and tests are migrated. Replace Flutter domain types with portable values and keep conversions in UI.
- [x] Consolidate identity contracts under domain, shared AuthBloc under identity, backend configuration under data, and user/organization scopes at the app roots. Prevent stale login results and mock production startup. Put durable workout storage and sync behind domain interfaces, with account isolation and concurrency tests.
- [x] Correct backend module boundaries, output entry point, booking lock reuse, branch authorization and payment ingress. Establish validated command contracts and emulator-tested Rules. Keep unavailable external integrations explicitly unavailable.
- [x] Move the Android runner into mobile, point Hosting at admin web, track dependency resolution in lockfiles, and add workspace verification/CI. Enforce no app-to-app imports, no Flutter/Firebase in domain/pose, and no data implementations in BLoCs/screens.
- [x] Run all migrated/new tests, analyzer, architecture checks, backend build/tests and independent application builds. Update README and blueprint with actual implemented boundaries and remaining integration work.

## Review gates

1. Account B cannot read or upload account A's local workout records; concurrent save/sync cannot lose a record.
2. Mobile routes cannot render admin workflows; admin imports neither mobile UI nor pose/native dependencies.
3. Backend tests reject unauthorized branches, malformed paths, duplicate-key payload conflicts and unavailable booking slots.
4. Every original role screen remains reachable through the owning application's shell.
5. Verification reports distinguish executed checks from unavailable deployment/device checks.

The current checkout contains the implementation being migrated. Work proceeds on `codex/architecture-completion`, preserving those changes. No deployment or Git history rewrite is included.

Completed structural scope on 2026-09-19. All verification results and remaining production integrations are recorded in `docs/architecture/2026-09-19-architecture-implementation.md`. The migration and lockfiles are committed on `codex/architecture-completion`; no deployment was performed.
