# 5.1.2 System architecture implementation

## Repository and boundaries

```text
apps/mobile        Flutter Android-oriented Member and Coach app, camera/audio and phone adapters
apps/admin_web     Flutter SPA for Admin operations and reports
packages/          gainpath_domain, gainpath_data, gainpath_identity, gainpath_pose, gainpath_ui
functions/src      export index, domain modules and platform adapters
functions/test     Vitest service tests; functions/emulator contains local integration suites
firebase/          Firestore Rules and indexes, Storage Rules and focused emulator profiles
contracts/         machine-readable compatibility contracts
test/, tool/       workspace/architecture verification and test harnesses
.github/workflows  dependency checks, test and build workflow
docs/              historical implementation, experiments and acceptance records
```

The Flutter workspace uses a layered dependency structure with feature-local presentation, application state, domain types and infrastructure adapters. AuthBloc and FitnessProfileCubit are concrete evidence of BLoC/Cubit use. Other paths use StatefulWidget controllers, repositories or native MethodChannels. The two apps share domain models, data adapters, identity and UI primitives. Only Mobile depends on the pose package and native inference adapter. Test compositions inject repositories and clocks explicitly.

## Clients and backend

Both `main.dart` files initialize Firebase and show startup/setup errors on failure. Mobile creates `GainPathMobileApp`, injects the AuthRepository and AuthBloc, configures Material routes, and resolves Member/Coach shells by session and readiness. Admin creates `GainPathAdminWebApp` with its Admin role gate, namespace-specific URL parsing and shell navigation. See Mobile `mobile_app.dart:99–181,243–449`; Admin `admin_app.dart:79–156` and `app/shells/admin_shell.dart`. Common session scope carries organization, branch and UID. Feature loaders and Cubits distinguish unavailable, loading, empty and loaded state. Widgets use shared UI elements, breakpoints or constrained layouts. Actual accessibility and browser/phone compatibility coverage varies.

Firebase direct reads or bounded authoring writes pass Rules. Callables use App Check where configured per export, Firebase identity, auth/scope validation and domain service dispatch. Side-effects and sensitive invariants use Admin SDK transactions, durable receipts or controlled event workers. HTTP endpoints include payment ingress/return and Google OAuth callback. Scheduler jobs and document triggers run under service authority. The [85-export inventory](evidence/backend_function_inventory.csv) records exact entry/definition anchors. Roles for multi-action commands should be read at each operation's service layer. Historical selective releases and separate packages make the deployed service count incomparable with the number exported by this source tree. See `firebase.json`, `functions/src/index.ts`, `functions/src/platform/firestore/` and `functions/src/platform/auth-context.ts`.

## Storage and integration

The [data model register](evidence/DATA_MODEL.md) records source-backed paths and field/lifecycle examples. The database uses canonical `users/{uid}`, organization-owned membership and feature documents, denormalized public coach records, and server-owned datasets and command receipts. Most client-denied writes are exposed through narrower callables. The [index inventory](evidence/firestore_indexes.csv) shows declared composite indexes. Runtime index and Firebase project configuration require separate readback. Rules use verified roles, branch scopes and ownership. Storage restricts owner media and author/credential purpose paths. Checkout validates provider callbacks and uses provider read-back before treating a payment as cleared. Scoped hosting rewrites map Admin navigation to its build. See M11 and [Rules source excerpt](evidence/code_snippets/rules-access.md).

App Check behavior varies by entry point and environment. The Mobile adapter activates debug or Play Integrity as configured. Admin permits explicit web App Check configuration and routes emulator mode directly to local SDK endpoints. Initial registration has an Auth gate and delegates role/organization assignment to the server. Account lifecycle uses revision and authentication-epoch checks. Privacy includes separate workout consent, compliance document versions, and Module 13 consent/governance. Protections and remaining deployment questions are listed in the [limitations register](16_SYSTEM_LIMITATIONS.md).

## Local persistence and recovery

Source spans `apps/mobile/lib/infrastructure/local/file_workout_session_store.dart:16–98`, `file_workout_backup_store.dart`, `file_routine_journey_store.dart`, `file_program_enrollment_store.dart` and `features/workout/application/workout_backup_coordinator.dart:37–255`. Session data is scoped to the signed-in user and organization. File writes are serialized; validation and replace/write handling guard corrupt or partial state. Active journey/session lifecycle code owns recovery checkpoints. Completed local records can remain usable during connectivity loss. A separate backup coordinator queues descriptive records, handles eligible backup only after setting/consent checks, restores pages with bounded cursors, and preserves knowledge of conflicts or failures. Server keys combine record kind and ID and claims compare canonical content and owner. Conflicts can require an explicit local decision. Backup is distinct from the legacy accepted-workout admission/analytics path. Local data loss before backup and restart/network/device reliability still need physical acceptance. Profile, remote booking and payment need their corresponding live services.

See the seven diagram sources in [architecture diagrams](evidence/diagrams/SYSTEM_ARCHITECTURE.md).
