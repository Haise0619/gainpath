# GainPath

Flutter/Firebase fitness platform for the GainPath organization. This checkout contains separate **Member/Coach mobile** and **Admin Web** apps, shared packages and trusted Firebase services. The repository root is a workspace, not an application entrypoint.

## Start here

| Active reference | Read for |
|---|---|
| [README](README.md) | Workspace map and quick start |
| [AGENTS](AGENTS.md) | Practical workflow, existing approvals and release boundaries |
| [Architecture](docs/ARCHITECTURE.md) | Current composition, Admin navigation, repositories and backend modes |
| [Status](docs/STATUS.md) | Current delivery and known exceptions |
| [FYP progress report](docs/PROGRESS_REPORT.md) | Every module: implementation, evidence, deployment and unfinished work |
| [Operations](docs/OPERATIONS.md) | Exact supported commands, verification, release and retention procedures |
| [Historical index](docs/archive/README.md) | Original academic material, decisions, UAT, deployment and rollback evidence |

The six operational references and the requested FYP progress report are the active reading map. Redundant setup guides, handoffs and superseded plans have been deleted; the historical index maps removed paths to retained references. Original FYP material and financial/UAT/deployment/provenance/rollback evidence remain protected. Current source, deployed behavior, accepted UAT and proposed work are distinguished in STATUS.

## Workspace

- `apps/mobile`: Member/Coach Flutter app; normal entrypoint `lib/main.dart`, Android Firebase/native integration.
- `apps/admin_web`: independent Admin Flutter app; normal entrypoint `lib/main.dart`, sidebar/state navigation.
- `packages`: domain, data/repositories, identity, shared UI and protected pose packages.
- `functions`: trusted financial, booking, account, provider and consistency services.
- `firebase`, `contracts`, `tool`, `tools`: security/emulator definitions, schemas, verification and local tools.

CI pins Flutter 3.38.9, Node 22 and pnpm 11. Follow [operations](docs/OPERATIONS.md#workspace-and-prerequisites) for dependencies and affected checks.

## Current local launch paths

For the normal Firebase Admin application, from the repository root, using the existing approved private App Check fixture:

```powershell
node tools/admin_web/build.cjs
node tools/admin_web/serve.cjs
```

Build first, then start the server only if port 7359 is free. Open [localhost:7359](http://localhost:7359/) and navigate with the sidebar; individual Admin pages do not have dedicated URL routes. The existing temporary UAT server may already own that port. Local builds/serving do not deploy Hosting. See [Admin launch details](docs/OPERATIONS.md#normal-admin-web-firebase-local-build-and-launch) before rebuilding or handling cache/private inputs.

For authorized Firebase Android development, run from `apps/mobile`:

```powershell
flutter run -d <android-device-id> --target lib/main.dart
```

This command installs/launches on the chosen device; use only within an approved device scope. Build-only commands are in operations.

**Firebase-only startup:** both normal entrypoints initialize Firebase directly. No BACKEND selection or normal Mock app exists. Firebase failure displays setup guidance; it never opens sample data. Android Studio uses the checked-in `main.dart` Mobile run configuration without backend arguments. For Admin, select `GainPath Admin Web` and Chrome; the prepared ignored App Check file supplies existing private local security configuration. See [launch details](docs/OPERATIONS.md#android-studio-and-firebase-only-startup). Tests retain explicit `.injected(...)` factories and test-owned seeded helpers.

## Current boundaries

Current performance release: Coach settings/certifications read Firestore directly; other active client callables use Singapore. There are **59 Functions: 55 Singapore business handlers and four US compatibility transports**. Payment/OAuth URLs and the sole Google event queue remain compatible; all four forward business processing to Singapore. The Xiaomi and private local Admin are updated. See [current status](docs/STATUS.md#cleanup-state-and-next-boundary) and [recovery instructions](docs/OPERATIONS.md#next-regional-rollout-gate); old US endpoints must be restored before rolling clients back.

Membership is organization-wide: effective Free plus approved Basic MYR 89 and Premium MYR 129, each paid term 30 days. Manual renewal preserves paid time. Recurring billing is unavailable; Stage B rewards and Stage C vouchers remain held. [STATUS](docs/STATUS.md) records the accepted scopes and separate Billplz refund limitation.

Routine authorized local work uses focused checks and concise reports. Cloud, financial, sensitive configuration, destructive data and account/role actions need explicit approval within their exact scope. Documentation Phase 1 and the subsequent local backend-selection fix do not authorize source cleanup, cache deletion, cloud changes or device actions. A source fix does not update existing APKs or served bundles. Preserve frozen workout/pose implementations, dirty work and private financial/release evidence.
