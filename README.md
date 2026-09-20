# GainPath

Two independent Flutter apps in one Dart workspace, with shared packages and a modular Firebase backend foundation. The architecture migration is implemented; most product workflows still use isolated prototype data, not live backend services.

## Run

From this repository root:

```powershell
flutter pub get
cd apps/mobile
flutter run --dart-define=BACKEND=mock
```

For the separate admin console:

```powershell
cd apps/admin_web
flutter run -d chrome --dart-define=BACKEND=mock
```

Use Flutter 3.38.9 / Dart 3.10.8 (the versions used for local verification and CI). Mobile includes Android and Windows runners; only Android was build-verified. The root is a workspace, not a third Flutter application.

## Structure

```text
apps/
  mobile/                 Member/coach app, Android and Windows runners
    lib/app/              Composition, guarded routes, navigation shells
    lib/navigation/       Names and arguments, no destination construction
    lib/features/         Feature BLoCs and presentation; scoped workout slice
    lib/infrastructure/   Account-scoped durable workout storage
  admin_web/              Independent staff/admin app and web runner
    lib/app/              Composition, guarded home, admin shell
    lib/navigation/       App-local navigation primitives
    lib/features/         Administrative feature screens
packages/
  gainpath_domain/        Pure Dart entities, policies and repository ports
  gainpath_data/          Pure Dart adapters, DTO mapping, isolated demo data
  gainpath_identity/      Shared AuthBloc and role policy; domain contracts only
  gainpath_ui/            Shared Flutter design tokens and visual primitives
  gainpath_pose/          Pure Dart pose-processing engine and detector port
functions/src/
  modules/                Coaching command, commerce ingress, workout contracts
  platform/               Authorization, validation, transactions, idempotency
contracts/                Versioned backend request/result schemas
firebase/                 Rules, indexes and emulator configuration
tool/                     Architecture enforcement and workspace verification
```

Dependency direction: presentation → application → domain ← data. App composition selects concrete implementations. Apps never import each other; domain and pose never import Flutter/Firebase; features navigate across boundaries using names/arguments. Shared source does not mean shared runtime state.

## What is functional now

- Member/coach and admin prototype screens reside in their respective apps.
- Authentication contracts support restoration, stale-result cancellation and role gates. Demo repository state is recreated per authenticated session.
- Guided workout simulation saves account/organization-scoped records atomically in application-support storage on native mobile/desktop. History retains pending uploads; the default uploader does not pretend that a server accepted them.
- Booking-hold backend transactions validate membership, branches, availability, overlapping slots, daily caps and idempotent retries.
- Payment ingress has a tested verification/persistence boundary; the deployed handler deliberately returns unavailable until a provider-specific verifier is supplied.
- Firestore rules and real-emulator transaction tests cover ownership and authorization failures. Hosting targets only `apps/admin_web/build/web`.

## Production gates

`BACKEND=firebase` fails closed until concrete SDK gateways and feature adapters are connected. Mock mode is prohibited in release/production builds. Build the current demonstration with `--debug`; do not deploy it as a production service.

Real Firebase initialization, membership provisioning, branch-aware client capabilities, native camera/ML, workout upload, provider checkout/refunds and the remaining server business flows are future work. Existing synchronous repositories, client-side demo payment screens, and static analytics are explicitly prototype interfaces, not production authority. The architecture supports replacing these feature by feature.

## Verify

```powershell
./tool/verify.ps1 -BuildApps -Backend -Emulators
```

Requires Flutter, Node/pnpm, Java and the Android SDK on PATH. The script stops on failures. CI runs the equivalent checks without deploying. The root `pubspec.lock` and `functions/pnpm-lock.yaml` pin dependency resolution.

See [implementation report](docs/architecture/2026-09-19-architecture-implementation.md) for the implementation map, evidence and next process. The [target blueprint](docs/architecture/2026-09-17-gainpath-target-architecture.md) includes the longer-term backend/runtime diagram.
