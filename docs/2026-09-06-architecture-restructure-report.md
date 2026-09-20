# GainPath Architecture Restructure — Session Report

**Date:** 2026-09-06
**Branch:** `restructure/feature-first` (46 commits), merged into `main` as `bdf1812`
**Scope delivered:** Phases 0–4 of the approved design
(`docs/superpowers/specs/2026-09-06-architecture-restructure-design.md`)

---

## 1. Starting point (diagnosis)

The brief described a Flutter + Firebase + BLoC + on-device ML system. The repository was a
**frontend-only prototype**: no Firebase, no Cloud Functions, no state-management package, no
camera or TFLite code. The "pose tracking" was a `Timer` and an `AnimationController` driving a
`CustomPainter`.

| Signal (before) | Value |
|---|---|
| Dart files / lines | 84 files, ~26,000 lines |
| Data source | one static `MockData` class, 1,694 lines, 33 model classes + all seed data |
| `MockData.` reads inside screens | 261 (60 of 84 files) |
| In-place `MockData` mutations from screens | 16 |
| `setState` calls / stateful screens | 214 / 54 |
| Stringly-typed `status == '...'` compares | 28 |
| Files holding 6–8 screens each | 3 (1,616 / 1,469 / 717 lines) |
| Cross-role imports (coach screen importing member screens) | 2 |
| Feature screens misplaced in `lib/widgets/` | 2 |
| Tests | 1 (the default counter test, failing) |
| Line endings | no `.gitattributes`; every touched file warned LF→CRLF |
| Uncommitted work | 10 dirty admin files (~1,900 lines) |

Root anti-patterns: no data layer, business rules embedded in widgets (refund window, risk
threshold, daily reward duplicated between home and rewards screens), no domain enums, no
seam for a real pose pipeline.

---

## 2. What was done, by phase

### Phase 0 — Hygiene (4 commits)
- Committed the 10 dirty admin files as-is before any move.
- Added `.gitattributes` (`* text=auto eol=lf`) so Git rename detection survives the moves.
- Added `flutter_bloc`, `equatable`, `bloc_test`.
- Replaced the broken counter test with an app smoke test.
- Converted every relative import to `package:gainpath/...`.

### Phase 1 — Mechanical moves (19 commits, imports only)
- Created `lib/app/` (shells, member home, theme, DI), `lib/core/` (`AppRole`, web CSV
  export), `lib/shared/` (widgets and charts, one per file behind a barrel) and
  `lib/features/<feature>/presentation/{shared,member,coach,admin}/`.
- `git mv`'d all 84 files into nine features, one commit per feature; `lib/screens/` and
  `lib/widgets/` removed.
- Removed the cross-role import by moving the public coach profile to
  `coaching/presentation/shared/` and `networkAvatar` to `shared/widgets/`.
- README rewritten for the new layout.

### Phase 2 — Domain extraction (4 commits)
- 33 model classes → `features/<f>/domain/entities/`, one file each.
- Six enums (`BookingStatus`, `AccountStatus`, `CertificationStatus`, `TransactionStatus`,
  `RefundStatus`, `TutorialStatus`) replaced every string status field, compare and assignment;
  display labels preserved.
- Rules moved out of widgets into tested pure policies: `RefundPolicy`, `RiskPolicy`,
  `BookingPolicy`, `RewardPolicy`.
- Seed data split into nine `features/<f>/data/in_memory/<f>_seed.dart` classes;
  `MockData` reduced to a forwarding facade.

### Phase 3 — Repositories (6 commits)
- 15 repository interfaces in `features/<f>/domain/repositories/` with `InMemory*` implementations
  and tests; `AppRepositories` (`lib/app/di/`) provides them via `MultiRepositoryProvider`.
- All 261 `MockData.` reads and 16 mutations replaced with `context.read<XRepository>()`;
  `MockData` deleted.
- `tool/check_imports.dart` enforces the feature boundaries (domain has no Flutter/app/shared
  imports; no feature imports another's role screens, `application/` or `data/` except
  data→data); it runs inside `flutter test`.

### Phase 4 — Blocs and file splits (12 commits)

| Bloc | Owns | Tests |
|---|---|---|
| `BookingBloc` (coaching) | create, cancel, reschedule, rate, publish notes, message | 6 |
| `WorkoutSessionBloc` (workout) | ticks, rep counting, routine progress, confidence state machine, auto-pause | 8 |
| `GamificationBloc` (gamification) | points, streak, daily check-in, mini-game credit | 4 |
| `MembershipBloc` (membership) | purchase, renew, auto-renew, refund claims (policy-checked) | 5 |
| `ChatBloc` (chatbot) | send, FAQ prompt, progress audit, bookmark, clear | 6 |
| `AuthBloc` (identity) | role selection, login/registration validation, sign-out | 5 |

- New policies with tests: `PromoPolicy`, `CredentialsPolicy`, `ReplyGenerator`.
- Split the three multi-screen files into 6 + 8 + 6 screen files plus small widgets.
- Removed the duplicated points/streak state in the home screen; home and rewards now share
  `GamificationBloc`.
- `AppScope` (`lib/app/app.dart`) holds repositories and app-wide Blocs above `MaterialApp`;
  session-scoped Blocs (`WorkoutSessionBloc`, `ChatBloc`) are provided by their screens.
- Shell widget tests tap every member and coach tab and render the admin shell.

---

## 3. Result

| Metric | Before | After |
|---|---|---|
| Dart files | 84 | 217 |
| Lines | ~26,000 | ~28,000 |
| Screens per file (max) | 8 | 1 |
| `MockData` references | 261 | 0 |
| String status compares | 28 | 0 |
| Repository interfaces | 0 | 15 |
| Blocs | 0 | 6 |
| Tests | 1 (failing) | 82 (passing) |
| Analyzer | 5 infos | 5 infos (same pre-existing ones) |
| Import-boundary check | none | `tool/check_imports.dart`, run by `flutter test` |

Final layout:

```
lib/
  main.dart
  app/        di/ home/ shells/ theme/ app.dart (AppScope, GainPathApp)
  core/       domain/ platform/
  shared/     widgets/ charts/ shared.dart
  features/   identity  workout  gamification  coaching  membership
              chatbot   analytics  recommendation  content
              each: domain/ (entities, enums, policies, repositories)
                    data/in_memory/  application/  presentation/{shared,member,coach,admin}
tool/check_imports.dart
test/app  test/features/<feature>/{domain,data,application}  test/tool
```

---

## 4. Verification performed

- `flutter analyze`: no errors or warnings (5 pre-existing info lints unchanged).
- `flutter test`: 82 tests pass (unit, policy, repository, bloc_test, widget, boundary check).
- `flutter build web`: succeeds.
- Browser click-through of the built admin console: sign-in (AuthBloc), dashboard, members
  (enum statuses), refunds, reports; no console errors.
- `git log --follow` on moved files traces back through the original commits.
- Working tree clean after merge.

---

## 5. Deliberate deviations from the plan

Recorded in the spec's "Implementation notes":

- Member home dashboard lives in `lib/app/home/` (it composes six features).
- Admin dialog primitives and report chart widgets live in `lib/shared/`.
- Cross-feature imports of `domain/` and `presentation/shared/` are allowed; `data/` may import
  another feature's `data/` (one shared prototype dataset).
- `domain/` may import `package:flutter/material.dart` only with a `show` list
  (`TimeOfDay`, `IconData`).
- Repository interfaces mirror the seed members one-to-one; mutators were added only where a
  Bloc needed them.
- Small behaviour changes accepted with the Blocs: mini-game results credit points (1 per 10
  score), purchase switches the current plan and records a transaction, refund requests file a
  pending claim and are refused outside the 7-day window, daily check-in is once per session.
- Two tiny layout fixes in the admin dashboard delta tags (shrink/ellipsize instead of overflow).

---

## 6. Still open

- **Phase 5 — partial**: named route boundaries and role policy are now in place. A future
  slice may replace the compatibility navigation implementation with `go_router` and fully
  compose the independently hosted app shells.
- **Phase 6 — seam complete, production integration open**: `lib/engine/` and
  `packages/gainpath_pose/` now provide the pure-Dart `PoseDetector` interface,
  `SimulatedPoseDetector`, One Euro filter, rep FSM, tracking health monitor, form score,
  audio priority arbiter and session coordinator. A platform camera detector, device
  benchmarks and the end-to-end local-save/upload flow remain open.
- **Phase 7 — partial**: `firebase.json`, Rules, indexes, the TypeScript Functions scaffold,
  a booking-hold command, payment-webhook boundary, shared `BackendConfig`, the
  claim-validating `FirebaseAuthRepository` boundary and `--dart-define=BACKEND=mock|firebase`
  are present. The platform-specific Firebase Auth SDK gateway, other concrete Flutter
  `Firebase*Repository` adapters, npm/Functions verification, emulator fixtures and
  production environment wiring remain open.

Housekeeping notes: `flutter analyze` exits non-zero on info-level lints, so CI should grep for
` error `; the admin console is a desktop layout, so its widget tests pump a desktop-sized window.

---

## 7. Commit log (branch `restructure/feature-first`)

```
19bf8a3 chore: add .gitattributes (eol=lf) to keep rename detection stable
7dcaf7f chore: add flutter_bloc, equatable, bloc_test
6d14e2b test: replace default counter test with app smoke test
cce6dd0 refactor: use package:gainpath imports throughout lib
1500206 refactor(app): move theme, shells and member home into lib/app
460409e refactor(core): move csv export to core/platform
9ef421f refactor(core): extract AppRole into core/domain
8be63d8 refactor(shared): move shared.dart to lib/shared
3fbc356 refactor(shared): split shared.dart into one widget per file behind a barrel
76ddeff refactor: move feature screens out of lib/widgets
fe5dea4 refactor(identity): move account/auth/profile screens into features/identity
511ba7b refactor(workout): move workout, equipment and content screens into features/workout
d9be1c1 refactor(gamification): move screens into features/gamification
dd1c71e refactor(coaching): move booking, roster and availability screens into features/coaching
cdcfa91 refactor(membership): move plan, billing and refund screens into features/membership
27e498d refactor(chatbot): move chat screens into features/chatbot
0bf1020 refactor(analytics): move progress, earnings, reports and admin dashboard into features/analytics
eb7543a refactor(recommendation): move admin recommendation screens into features/recommendation
d1c40bd refactor(content): move announcements and system settings into features/content
80e8e09 refactor(shared): move admin dialog primitives to shared/widgets
270d884 refactor(coaching): public coach profile screen lives in presentation/shared
d4fcf66 refactor(coaching): share networkAvatar via shared widgets instead of cross-role import
de3e80f docs: describe feature-first layout in README
a87c38d refactor(domain): extract entities from mock_data into feature domain folders
e8c34bc refactor(domain): typed status enums replace stringly-typed status fields
94b88bc refactor(domain): extract refund, risk, booking and reward policies
47f83d3 refactor(data): split MockData seeds per feature; MockData is a forwarding facade
64c7876 feat(data): repository interfaces, in-memory implementations and DI root
4afea6a refactor(content,recommendation): read through repositories instead of MockData
64ed3dd refactor(analytics,chatbot,membership): read through repositories instead of MockData
f70dbff refactor(gamification,coaching,workout,identity,app): read through repositories; remove MockData
1b4235b refactor: expose cross-feature entry screens via presentation/shared
52fed2d chore: feature import boundary check (tool/check_imports.dart) with test
758fb94 feat(coaching): BookingBloc drives booking screens
e1f8ae5 refactor(workout): one screen per file
32841e8 fix(workout): equipment detail imports the tutorial screen directly; add WorkoutSessionBloc
fb0027b feat(workout): live workout screen driven by WorkoutSessionBloc
8b47e6e refactor(gamification): one screen per file
3dea069 feat(gamification): GamificationBloc shared by home and rewards screens
acb5777 fix(gamification): mini-game result screen imports flutter_bloc
b9335cb feat(membership): MembershipBloc owns plan, auto-renew, ledger and refunds
c7a1f5c feat(chatbot): ChatBloc drives the AI coach conversation
b852653 refactor(identity): one profile screen per file; add AuthBloc and CredentialsPolicy
9643d67 feat(identity): AuthBloc drives login, role selection and sign-out
4a1f719 docs: record implementation notes, status, and setup/check commands
89f1b99 test(app): shell widget tests; AppScope wraps repositories and root Blocs
bdf1812 Merge restructure/feature-first into main
```

---

## 8. Implementation continuation — 2026-09-18

The approved next slice has started in the current checkout. The repository's Git
metadata is read-only in the managed workspace, so no branch or commit was created;
existing documentation changes were preserved.

Implemented:

- Named application routes for member, coach and admin shells, with a role-aware
  route policy and guarded shell entries. Login and logout now use named route
  boundaries rather than constructing shell routes directly.
- A pure-Dart pose engine under lib/engine/pose/: canonical detector frames,
  detector port plus simulated adapter, One Euro filtering, tracking-health
  states, hysteresis repetition FSM, form score, cue priority arbitration, and a
  session coordinator.
- BackendConfig with explicit mock and firebase modes. The composition root
  fails closed when Firebase mode is selected until concrete Firebase repository
  adapters are connected; it cannot silently run mock data in a production build.
- Firebase project configuration, organization-scoped Firestore and Storage Rules,
  indexes, and a TypeScript Cloud Functions scaffold.
- The first server-authoritative command, createBookingHold, validates the
  request, checks current organization membership and branch access, atomically
  locks every occupied half-hour slot, creates a pending booking hold, and stores
  an idempotency receipt.
- A provider-neutral payment webhook boundary that verifies an HMAC signature,
  deduplicates provider event IDs, and persists receipt state before later
  entitlement transitions. Provider-specific Billplz field mapping remains an
  adapter decision.

Verification note: the initial slice was subsequently re-verified in the current
workspace. The targeted route/backend/pose tests passed, the full root Flutter suite
passes (94 tests), the shared domain/data/pose package tests pass (5 tests), and the
independent mobile/admin app tests pass (2 tests). `flutter analyze --no-pub` reports
no errors and five informational lints, all from the existing root application. The
root compatibility app, mobile app host, and admin
web app each complete `flutter build web --no-pub`. TypeScript Functions build/tests
and Firebase Emulator Suite Rules tests remain pending because `npm` and the Firebase
CLI are not installed in this environment.

## 9. Workspace extraction — 2026-09-18

The target monorepo boundary is now represented in source without moving the existing
feature screens prematurely:

```text
apps/
  mobile/                         independent Flutter application host
  admin_web/                      independent Flutter web application host
packages/
  gainpath_domain/                pure business contracts and value objects
  gainpath_data/                  repository ports and remote DTO mapping
  gainpath_ui/                    shared theme and application-frame boundary
  gainpath_pose/                  portable pure-Dart pose engine
  gainpath_identity/              shared auth contracts, AuthBloc and role policy
```

The root `pubspec.yaml` is a Dart workspace manifest. The root application depends on
`gainpath_pose` through a package boundary, while its existing UI remains available as
the compatibility host during migration. The mobile app now also contains the first
vertical feature slice under `apps/mobile/lib/features/workout/`; the admin app remains
an authentication-only host until an admin-owned feature is migrated.

The next implementation slice should move one vertical feature at a time into the
appropriate app/package boundary, beginning with durable workout history and accepted
upload behind the local session summary, then connect concrete Flutter Firebase adapters
behind the existing repository ports.
Do not delete the compatibility root until both app entry points cover all required
roles and their release builds are independently verified.

## 10. Identity boundary — 2026-09-18

Authentication/session bootstrap is now shared as a capability rather than copied into
the two application hosts:

- `packages/gainpath_domain` owns the shared `AppRole` and immutable `AuthSession` contract.
- `packages/gainpath_data` owns the `AuthRepository` port, `AuthException`, and the
  `InMemoryAuthRepository` used by local development.
- `packages/gainpath_identity` owns credential validation, `AuthBloc`, session state and
  the `AuthRolePolicy` used by both apps.
- `apps/mobile` owns the member/coach login presentation and permits only those roles.
- `apps/admin_web` owns the administrator login presentation and permits only the admin role.

The root app's existing `AppRole` and credential-policy paths now re-export the shared
contracts, preserving compatibility while the legacy screens remain in place. The new
app hosts have real sign-in, validation, recoverable repository errors, role selection,
email-verification state and sign-out behavior. They intentionally do not share
presentation widgets, so mobile and admin can evolve their UX and release dependencies
independently.

This slice still uses an in-memory repository. The next identity step is a Firebase Auth
SDK gateway that maps provider credentials and custom claims into the tested repository
boundary, with negative tests for stale roles, suspended users, cross-organization access
and sign-out during an in-flight request. Until that gateway and Firebase initialization
exist, the new app hosts are development/demo entry points and must not be treated as
production authentication.

Verification for this slice: five shared identity tests and two app-host tests pass;
the existing root suite remains at 94 passing tests; root, mobile and admin web builds
complete successfully; analyzer remains at the previous five informational lints with
no new identity-package lint; and app/package imports do not point back to the legacy
root package.

## 11. Firebase Auth adapter boundary — 2026-09-18

The shared data package now contains a testable provider boundary before adding platform
credentials:

- `FirebaseAuthGateway` represents the small SDK surface needed by the application.
- `FirebaseAuthRepository` maps Firebase user records and custom claims into
  `AuthSession`, rejecting missing, unknown or mismatched roles.
- Only members may self-register through this boundary; coach/admin accounts must be
  provisioned by an authorized backend workflow.
- `AuthRepositoryFactory` selects the in-memory adapter for mock mode and fails closed
  for Firebase mode unless a gateway is explicitly provided.

No Firebase API key is required for this slice. To connect the real SDK next, provide the
environment's generated Firebase options/configuration and confirm the custom claim
shape (currently `role: member|coach|admin|staff|branch_staff`).

## 13. Milestone status after 2026-09-18 implementation

| Target milestone | Status | Remaining work |
|---|---|---|
| 1. Approve boundaries and organization scope | Complete | Keep diagrams and thesis requirements aligned. |
| 2. Separate mobile/admin packages | Complete as a build boundary | Migrate the remaining legacy root screens vertically. |
| 3. Domain contracts and Firebase identity | Partial | Connect the real Firebase SDK gateway and user lifecycle claims. |
| 4. Pose/workout vertical flow | Partial | Replace simulated detector, add durable local storage, accepted upload and history. |
| 5. Booking/commerce backend | Partial | Complete availability, checkout/refunds and concurrency/idempotency coverage. |
| 6. Rewards/content/analytics/assistant backend | Not started as production flows | Implement server ledgers, projections, recommendations and bounded assistant access. |
| 7. Completion gates and deployment readiness | Partial | Add requirement matrix, device benchmarks, emulator/Functions CI and deployment runbooks. |

Therefore, five of the seven milestones are not fully complete: milestones 3–5 are
partially implemented, and milestones 6–7 still need their main implementation work.

## 12. Mobile workout vertical slice — 2026-09-18

The first post-identity feature now lives in the mobile application rather than the
legacy root package:

- `apps/mobile/lib/features/workout/domain/` defines the starter workout plan and typed
  `WorkoutSessionSummary`.
- `apps/mobile/lib/features/workout/application/` coordinates `PoseSessionCoordinator`,
  repetition counting, tracking confidence, form accuracy and local completion state.
- `apps/mobile/lib/features/workout/data/` provides an isolated local repository boundary
  that can later be replaced by durable storage and an upload queue.
- `apps/mobile/lib/features/workout/presentation/` provides the authenticated workout
  entry screen and explicit finish/save-local action.

The current detector is still the deterministic simulator, and the local repository is
memory-backed. This is deliberate: the feature boundary is proven before adding camera
plugins, durable storage, offline retry and server acceptance. The next workout gate is
`local save -> accepted upload -> history`, followed by a real detector validation pass.

## 14. Durable workout history and upload boundary — 2026-09-18

The workout vertical slice now has the first offline-capable persistence boundary:

- `WorkoutSessionSummary` has validated JSON serialization for a stable local DTO.
- `WorkoutSessionStore` separates storage from application logic. The mobile app uses a
  `SharedPreferencesWorkoutSessionStore`, while tests use an in-memory store.
- Each completed session is stored as a `WorkoutSessionRecord` with `pending` or `accepted`
  state, optional server acknowledgement time and server reference.
- `WorkoutUploadGateway` is the provider-neutral upload port. The test gateway proves
  idempotent accepted uploads; the default app gateway intentionally fails closed until a
  real authenticated Firebase/Functions adapter is connected.
- `WorkoutSessionRepository.syncPending()` retries pending sessions and marks them accepted
  only after the upload gateway returns a receipt. Failed uploads remain pending.
- `WorkoutHistoryBloc` and `MobileWorkoutHistoryScreen` expose local history and an explicit
  sync action without requiring network access to render saved sessions.

This completes the local-save and history portions of the workout gate and establishes the
accepted-upload seam. It does not claim production upload support: the remaining work is a
Firebase/Functions adapter that binds the gateway to the authenticated user and organization,
server-side duplicate protection, and offline restart/retry instrumentation.

Verification for this slice: the focused mobile workout suite passes 8 tests, including
summary round-tripping, shared-preferences restoration, accepted-upload deduplication,
failed-upload retention, history loading and sync-state exposure.
