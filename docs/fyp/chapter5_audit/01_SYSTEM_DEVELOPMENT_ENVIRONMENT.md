# 5.1.1 System development environment

Audit date 25 November 2026 (Asia/Kuala_Lumpur). Primary snapshot is the `membership-upgrade-work` working tree based on `f81fb2d5d48857c75cb5f1b8491086fc4bcceba6`, branch `codex/member-notification-bell-dot`. Working-tree changes are part of the source audit. See [snapshot evidence](evidence/snapshot.md) and [test execution](12_TEST_EXECUTION_RESULTS.md).

## Configured and observed tooling

| Technology | Repository or CI configuration | Observed on audit host or from retained evidence |
|---|---|---|
| OS and hardware | Flutter CI runs on Ubuntu; Android is the native camera path | Current host is Windows with PowerShell. Development CPU, RAM and GPU history need developer confirmation. Historical physical pose checks name a Xiaomi device. Model, Android patch level and camera configuration must be taken from the individual test run where recorded. |
| Flutter / Dart | Flutter 3.38.9 stable CI; Dart SDK `>=3.6.0 <4.0.0` manifests | Flutter 3.38.9 (67323de), Dart 3.10.8. |
| Android | min SDK 26; compile/target SDK and NDK inherit Flutter values; AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, Java/JVM target 17 | With the installed Flutter SDK, inherited compile and target SDK are 36 and NDK is 28.2.13676358 (FlutterExtension.kt:23,34,42). Android Studio version and historical device targets require confirmation. Gradle release signing validates production inputs. |
| Java | Flutter CI Temurin 17 and backend CI Temurin 21 | Java 20.0.2 was used in the audit environment. Use the runtime captured in each test log for attribution. |
| Node and package management | Firebase runtime Node 22; CI Node 22, pnpm 11 and frozen lockfile | Node 24.19.0, npm 11.17.0, pnpm 11.25.0. This affects reproducibility against CI. |
| Functions toolchain | TypeScript 5.9.3, Firebase Functions 6.6.0, Admin SDK 13.10.0, Firebase CLI 13.35.1 and Vitest 2.1.9 from pnpm lock | Package-cache presence and successful invocation are separate claims. See test logs. |
| Git | GitHub Actions verifies pushes and PRs | Git 2.53.0.windows.2. |
| Emulator Suite / browsers | Root emulator config and focused test profiles under `firebase/`; Admin is a Flutter Web SPA | Cached Firestore jars 1.19.8 and 1.22.0 and Storage runtime 1.1.3 were discovered. Historical browser acceptance and fresh test execution have distinct evidence. |

Sources `pubspec.yaml`, `functions/package.json`, `functions/pnpm-lock.yaml`, `firebase.json`, `.github/workflows/verify.yml`, `apps/mobile/android/settings.gradle.kts`, `apps/mobile/android/app/build.gradle.kts`, and the Gradle wrapper properties.

## Material client dependencies

Versions below are resolved by the root `pubspec.lock`. Verify usage from the indicated application or platform adapter.

| Concern | Resolved technology | GainPath role and source |
|---|---|---|
| Presentation and state | Flutter, flutter_bloc 9.1.1, bloc 9.2.1 | Shared AuthBloc, profile Cubit plus feature Cubits and widget composition. `packages/gainpath_identity/lib/src/`; app composition and shells. |
| Routing | Flutter Material Navigator | Named feature routes and role-gated home composition, with Admin URL/deep-link handling. `apps/mobile/lib/app/mobile_app.dart:145–181`; `apps/admin_web/lib/app/shells/admin_shell.dart`. |
| Cloud SDKs | firebase_core 4.15.0, firebase_auth 6.7.0, firebase_app_check 0.4.8, cloud_firestore 6.10.0, cloud_functions 6.5.0, firebase_storage 13.6.0 | Real SDK configuration per app, authentication, guarded callable operations, client read models and media. See both `firebase_bootstrap.dart` files. |
| Federated identity | google_sign_in 7.2.0 | Android/mobile Google credential path integrated into Firebase Auth. `apps/mobile/lib/infrastructure/firebase/firebase_auth_gateway.dart`. |
| Native perception | camera 0.11.4, tflite_flutter 0.12.1 | Frame acquisition and BlazePose CPU inference. Android GPU candidate through a native adapter. See pose pipeline. |
| Audio and video | Native Android workout audio bridge, video_player 2.11.1 | Bundled coaching clips and native speech/audio orchestration; video-guided timed exercise plus published media playback. |
| Reports and calendar | Syncfusion charts/gauges 34.2.3, kalender 0.34.0, timezone 0.11.2 | Workout reporting charts and Admin calendar. `apps/admin_web/lib/features/analytics/`, `apps/admin_web/lib/features/operations_calendar/`. |
| Scan and media | mobile_scanner 7.4.2, file_selector 1.1.0, geolocator 14.0.2 | QR scanning, media/document selection and facility/location features. Equipment photo recognition is a separate service. |
| Local persistence | path_provider 2.1.6 and Dart file/JSON APIs | App-scoped records, workout backup state, routine/program progress, settings and local continuity. `apps/mobile/lib/infrastructure/local/`. |
| HTTP and digest | http 1.6.0, crypto 3.0.6; Node crypto server-side | Client adapters and structured-digest identities. Monetary webhook authenticity is checked in Functions. |
| Testing | flutter_test from SDK, Dart test 1.26.3, bloc_test 10.0.0, Vitest 2.1.9 and Rules Unit Testing | Domain/adapter, widget, backend and emulator coverage. See test strategy and fresh results. |

## External service boundaries

| Integration | Data and flow | Configuration and verification limit |
|---|---|---|
| Firebase Auth / App Check | Firebase handles identities and short-lived tokens. Android has debug and Play Integrity modes. Admin App Check uses web configuration. Callable code independently checks scope and state. | Local manifests and source contracts inspected. App registration, production attestation enforcement and live identity configuration require a separate readback. |
| Firestore / Cloud Storage / Hosting | Firestore stores scoped metadata and transactional records. Storage carries authorized image, video and certification assets. Hosting config serves Admin SPA from a Flutter Web build. | Root Firebase config declares deploy targets and emulators. Historical private Admin browser/service acceptance is target-specific. |
| Cloud Functions | Node 22, Admin SDK and typed callable commands; HTTP callbacks and Firestore/scheduled jobs share domain services via transactional adapters. | See [export inventory](evidence/backend_function_inventory.csv). Export presence does not establish current deployment. |
| Billplz and Xendit | Server starts sandbox checkout, sends a hosted link, validates ingress and reconciles provider-owned amounts, status and references. | Booking methods are configuration-driven. Payment reports preserve sandbox provenance. No fresh transaction was initiated. |
| Gemini | Functions mediate entitled fitness assistant requests, equipment photo identification and eligible recommendation guidance. | API secret remains server-side. Runtime enablement, provider response quality, quota and costs remain separate verification questions. |
| Google Calendar / Gmail | Gym OAuth and booking-event delivery worker project authorized bookings to calendar/mail. Read-back and bounded retry state protect delivery. | Historical controlled delivery reports exist. Provider and real recipient acceptance for this snapshot were outside the fresh run. |
| Brevo | Admin Member provisioning uses a backend transactional-mail adapter for setup and verification links. A recovery email template is also in source. | Mail adapter existence and live mail delivery are independent. The main backend index lacks the OTP callable in this snapshot. |
| Local AI | Camera frames feed on-device pose inference and geometric analyzers. Pose rendering, rep counting and game hit checks run on-device. | No fresh device experiment. Cloud equipment identification follows its own image upload path. |

The literature review explains framework selection (`c2.md`, including around lines 1050–1087 and 1280–1387). Provider motives and current performance should be attributed to implementation records or measured evidence where available.
