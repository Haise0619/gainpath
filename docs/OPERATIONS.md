# Development and operations

Current reference, 24 October 2026. Commands below describe existing tooling; documenting a command does not execute or approve it. Documentation Phase 1 is complete; the separately approved backend-selection correction is local implementation/testing only. See [AGENTS](../AGENTS.md) for approval boundaries and [STATUS](STATUS.md) before any release or business operation.

## Workspace and prerequisites

Run root commands from the GainPath checkout. Mobile commands run in `apps/mobile`; Admin commands run in `apps/admin_web` unless explicitly marked root. There is no root application to launch.

The [CI workflow](../.github/workflows/verify.yml) pins Flutter 3.38.9, Node 22 and pnpm 11; it uses Java 17 for Android and Java 21 for backend emulator tests. Use the workspace lockfiles and an installed Android SDK for mobile work. Dependency resolution is `flutter pub get --enforce-lockfile` at root and `pnpm install --frozen-lockfile` in `functions` when dependencies actually need resolving. These commands write local dependency/cache state and were not run for documentation cleanup.

## Android Studio and Firebase-only startup

Both normal main entrypoints initialize Firebase directly. No backend flag or alternate Mock runtime is required. Normal app constructors take no backend selection; `.injected(...)` retains explicit test dependencies. Seeded test graphs live under test/support, and initialization errors stay visible.

- **Mobile:** open the workspace in Android Studio, select the checked-in `main.dart` Flutter configuration and the existing Android device, then Run. Debug App Check activates automatically using the existing device registration. Keep the existing package/signing key; use an in-place run/update. Never uninstall or clear app data to fix setup.
- **Admin Web:** select `GainPath Admin Web` and Chrome. Its private App Check define file is already prepared in this checkout. The run configuration uses port 7360, leaving the normal private Admin server/session at 7359 available. The two origins have separate Auth persistence; this is one Firebase implementation, not separate backend editions.
- **New checkout:** prepare the Admin IDE security file using the existing authorized registered fixture; no new token registration is performed:

```powershell
node tools/admin_web/prepare-ide.cjs
```

The generated build/local-run/admin.firebase.json contains a private App Check debug token and stays ignored. A new workstation still needs legitimate Firebase/App Check provisioning; it must never silently use test data. Production web uses its approved reCAPTCHA site key through normal security build inputs. These security inputs are independent of repository selection.

## Normal Admin Web: Firebase local build and launch

The existing approved local builder consumes an **already registered**, private Web App Check fixture. Its default path is `build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json`; `GAINPATH_ADMIN_APP_CHECK_FIXTURE` can point to an existing approved fixture. `FLUTTER_ROOT` overrides its default SDK location `C:/flutter`. Do not print the fixture or register/change credentials to make a build succeed.

```powershell
# Working directory: repository root; build only when authorized
node tools/admin_web/build.cjs

# Start separately only when port 7359 is free
node tools/admin_web/serve.cjs
```

The builder runs the normal Admin Flutter entrypoint, release web output, Firebase-only composition, debug App Check and the existing registered token. It writes `build/admin-web/current`, a sanitized build log and `build/admin-web/build-result.json`. This local debug-App-Check bundle is private development output, not a production Hosting artifact. It must not be committed or publicly hosted. The builder does not deploy or register credentials.

The server binds `127.0.0.1:7359` and exposes the normal app at [localhost:7359](http://localhost:7359/). It supports GET/HEAD with no-store responses and a SPA fallback. Navigate using the sidebar: `/members` and `/refunds` are not registered application routes. Selection lives in widget state; a refresh normally starts at Dashboard.

The builder versions JavaScript asset URLs and removes the generated service-worker registration. A service worker retained from an older build can still serve an old root page. If needed, open `http://localhost:7359/?build=<sha256 from build-result.json>` to select a fresh document while preserving the origin and existing Auth session. Do not automatically clear browser/private session data. `localhost` and `127.0.0.1` are different browser origins; keep the approved origin consistent.

The retained Module 4 UAT server can also map `/membership-uat/` alongside the normal app; the canonical server above does not map that bundle. Do not start a second server on the occupied port, replace a running UAT server or assume a temporary UAT page is a normal Admin feature. See [the distinction](ARCHITECTURE.md#normal-admin-versus-temporary-uat-pages).

`firebase.json` currently points Hosting at `apps/admin_web/build/web`, **not** `build/admin-web/current`. Neither serving locally nor building the normal app publishes Hosting. Deployment is a separate approved operation.

## Mobile: Firebase Android

Use an existing authorized Android device and registered App Check context. The checked-in mobile Firebase options cover Android; unsupported desktop initialization displays setup-needed UI. These commands describe the normal Firebase entrypoint:

```powershell
# Working directory: apps/mobile
flutter devices
flutter run -d <android-device-id> --target lib/main.dart
flutter build apk --debug --no-pub --target lib/main.dart
```

`flutter run` installs/launches on the target device and requires authorization for that device action. APK build alone does not install. Preserve the retained released/UAT APKs, signing evidence and private backups; verify package/certificate identity before any separately approved update. Do not use `flutter clean`, Gradle clean or blanket build deletion during this cleanup.

## Focused verification

Choose affected tests and run them in the owning package. Ordinary future implementation does not require the full workspace gate after every edit. Examples of existing checks:

```powershell
# Root: architecture and pure Dart tooling
dart run tool/check_architecture.dart
dart test test

# packages/gainpath_domain: domain example
dart test test/membership_commerce_test.dart

# apps/mobile: shared membership presentation
flutter test --no-pub test/membership_screens_test.dart

# apps/admin_web: trusted membership verification UI
flutter test --no-pub test/member_membership_verification_test.dart

# functions: local finance/domain tests, no provider transaction
pnpm exec vitest run test/membership-payment.test.ts test/membership-entitlement.test.ts
```

For a broader integration/release gate, the existing root command is `./tool/verify.ps1 -BuildApps -Backend -Emulators`. It resolves dependencies, analyzes maintained source paths, runs suites, builds apps and executes emulator checks. Its debug app builds use the same Firebase-only normal entrypoints without backend flags. It does not deploy, but regenerates outputs and was not run as a whole for this local correction. The [script](../tool/verify.ps1) and CI are authoritative for exact checks. Backend emulator scripts use `demo-gainpath`; keep provider calls stubbed and inspect the chosen emulator configuration rather than assuming all external services are isolated.

Startup verification uses `flutter test --no-pub test/backend_startup_test.dart` in each app, with no backend flags. The tests prove default Firebase initialization and a visible failure without fallback, using no real account/provider transaction. Installed SDK commands may need access to normal local telemetry/cache state; that is separate from cloud permission.

## Singapore ratings pilot: local preparation

**Historical pilot record:** the current deployment and endpoint-restoration requirement are in [the current regional release](#next-regional-rollout-gate). Original US endpoints mentioned below have since been retired. Do not use these historical commands or old flags alone to roll back.

`getCoachRatingsPilotCommand` reuses the unchanged US ratings handler with `region: 'asia-southeast1'` and enforced App Check. Its isolated package is `build/functions-performance-20261024/ratings-pilot-release/`; only the pilot is exported. `ratings-pilot-release-manifest.json` records the source closure, excluding commerce/gamification/Google/workouts and all other exports. The dependency junction reuses installed local packages and is excluded from upload. No dotenv, secrets or private fixtures are included. Local tests ran on Node 24; the approved cloud deployment/readback is ACTIVE on Node 22.

The owner approved deployment of **only** this callable, project `gainpath-0619`, region `asia-southeast1`, using the package's `firebase.json` and `--only functions:getCoachRatingsPilotCommand`. Creation first failed on pnpm 11's install-script policy. The isolated package now explicitly denies unnecessary `@firebase/util` and `protobufjs` hooks using `allowBuilds` in `pnpm-workspace.yaml`; production installation/handler loading passed locally, and retry deployed successfully. It ships precompiled JS without cloud build scripts. This follows [pnpm's explicit build decisions](https://pnpm.io/cli/approve-builds); main project dependency policy was not changed. The CLI's build-image cleanup warning remains unresolved; no image deletion was authorized or attempted.

**Transport verified:** the owner subsequently explicitly approved the pilot's service-only `allUsers` → `roles/run.invoker` binding. It was applied after an unchanged-policy readback. Missing Auth or App Check now reaches the Firebase boundary and returns HTTP 401; wrong organization returns 403. Valid authenticated calls succeed. Original US ratings and all other service policies remain unchanged. Evidence: `build/latency-optimization-20261024/pilot-iam-applied.json` and `ratings-benchmark.json`. IAM beyond this pilot still requires separate approval.

The completed comparison used the same existing email-verified Member, registered App Check context, coach IDs, payload and host/network, with three warmups and 20 alternating paired samples. Ratings warm p50/p95: **US 2,719.6/2,765.2 ms; Singapore 270.7/308.5 ms**, matching responses. First-request times are retained separately without claiming cold-start proof. The measured Directory data path (published-profile query plus ratings) improved **2,809.4 → 258.5 ms**. No account, database or financial mutations were made; phone/browser sessions were preserved. The initial Mobile transport selector added ratings; build with `--dart-define=COACH_RATINGS_REGION=us-central1` for rollback. The later two-read rollout and approved client activation are described below.

The authorized US optimization deployment used only `build/latency-optimization-20261024/nonfinancial-read-release/firebase.json` and `--only functions:getBookingListCommand,functions:getCoachAvailabilityCommand`. Both are ACTIVE on Node 22; IAM and every service runtime setting were preserved, with the other 56 Functions identical. Original source ZIPs and hashes are retained as `rollback-getBookingListCommand.zip` and `rollback-getCoachAvailabilityCommand.zip`; any rollback must use its exact original export/source and preserve configuration. `screen-data-comparison.json` contains seven-sample before/after latency and response equivalence; `read-release-after.json` records configuration readback. Do not deploy the default source tree or held finance/reward/voucher exports.

The owner subsequently approved and deployed `getBookingListReadCommand` and `getCoachAvailabilityReadCommand` in Singapore with their service-specific invoker bindings. The reviewed 23-file `regional-read-release/` bundle exports only these two reads and reuses the trusted handlers with enforced App Check. Exact selection was `--only functions:getBookingListReadCommand,functions:getCoachAvailabilityReadCommand` using that bundle's `firebase.json`. Readback verifies both ACTIVE on Node 22 and all previous 58 Functions/policies unchanged (unordered Eventarc filter sets compared canonically). Evidence: `build/latency-optimization-20261024/regional-rollout/deployment-verification.json`. The same-host Member comparison measured warm p50/p95 **Booking List US 1,926.7/1,970.1 → Singapore 203.1/287.7 ms**, **Availability US 995.5/1,069.5 → Singapore 116.2/127.9 ms**. Responses and security rejections match; raw first-request times are not cold-start proof.

Both apps use the shared endpoint selector for these two reads. After the explicit client release approval, normal source builds default these verified reads to Singapore; `BOOKING_READS_REGION=us-central1` restores the US originals. The approved Xiaomi/private Admin artifacts already use the explicit Singapore build flag. Live authorized Coach and Admin checks have now passed in the isolated browser harness: eight warm samples per read, response parity, Auth/App Check/org rejection and Coach other-owner isolation. Sanitized evidence is retained as `browser-coach-*.json` and `browser-admin-*.json` in the rollout directory. For isolated UAT build with `--dart-define=BOOKING_READS_REGION=asia-southeast1`; restore `us-central1` to roll back. Ratings has its independent `COACH_RATINGS_REGION` flag. All payment, membership, reservation, roster writes and Google commands keep their original US names/regions. Explicit repository/callable injection remains available for tests; injected availability SDKs retain original logical command names. Valid configured App Check is required by the new endpoints; there is no automatic fallback that bypasses rejection.

`regional-rollout/client-artifacts/` contains the built Firebase debug APK and separate private Admin UAT web bundle, with hashes in their build JSONs and verified APK signing. The owner explicitly approved installation/activation: Xiaomi received an `install -r` update, verified against the approved APK hash and actual installed signing identity; package UID/data directory/first-install time are unchanged. The normal server at `http://localhost:7359/` serves all three approved code hashes. Prior installed APK and Admin static files are retained under `regional-rollout/client-release/`; no app data or browser Auth/storage was cleared and no Hosting deployment occurred. Final owner-reported screen UAT passed: the updated Xiaomi Directory/My bookings/Coach availability and normal Admin Coach Booking List/Schedule all loaded normally. No booking/payment/refund was initiated. Retained confirmations are in `client-release/verification.json`; this is functional UAT, not a new timing benchmark. The role verification page at `http://localhost:7361/` is a temporary local-only harness, **not the normal Admin app at port 7359**. It uses memory-only Auth and the existing registered debug App Check context, permits only read comparisons/security checks, and saves sanitized results. An authorized Coach/Admin must sign in themselves; the rejected legacy fixture is not a reason to change roles or accounts. Debug-App-Check artifacts must not be publicly hosted. Existing Rules lack full callable authorization parity for other apparent direct-read candidates; no switch or Rules modification is approved implicitly.

### Next regional rollout gate

**Current completed release:** build/final-region-cutover-20261024/verification.json records 59 ACTIVE Functions: 55 Singapore business handlers and four US compatibility transports. The preceding build/latency-completion-20261024/verification.json records the earlier 55-Function client/direct-read stage. Coach own settings and Coach/Admin certification list/details/history use direct Firestore. The installed Xiaomi and private normal Admin are updated. The five-copy artifacts under function-region-rollout-20261024 were superseded; do not activate those older bundles.

Normal builds default to FUNCTIONS_REGION=asia-southeast1 and DIRECT_COACH_READS=true. The existing ratings/booking aliases remain in Singapore. The Admin builder accepts these environment values independently for its own build, along with the optional SINGAPORE_CALLABLES override. Emulator transport uses original logical names in local US namespace; explicit test injection remains available. No held Stage B/C command is enabled. Production Functions were isolated from exact deployed source closures, not the dirty root source; do not run a broad firebase deploy or treat root exports/default regions as the active release inventory.

**Rollback order changed after endpoint retirement:** first restore only the required original Functions from archives/, callable-snapshot.json, worker-snapshot.json and the earlier five-copy snapshot. Preserve the captured environment, secret references, identity and IAM. Then verify their availability before switching any client to FUNCTIONS_REGION=us-central1, BOOKING_READS_REGION=us-central1, COACH_RATINGS_REGION=us-central1, or DIRECT_COACH_READS=false, or reinstalling an old APK/bundle. Flags and old binaries alone cannot restore deleted endpoints. Actual prior APK and Admin files are retained in client-rollback/; never uninstall, clear data or switch accounts for rollback.

## Release, financial recovery and retention

The owner authorized this bounded direct-read/regional release without repeated approval. direct-activation.json records the isolated Rules release and three create-only Coach/Admin scope records; no existing account/role/financial records were changed. Firestore App Check is ENFORCED and valid-token/missing-token checks pass on both SDK and REST surfaces. The records at orgs/gainpath/coachReadScopes/{uid} bind validated branch IDs and role to the live actor membership; clients cannot create, update, delete or list scopes. Organization inactivity and authority drift deny access. Settings writes, phone uniqueness and certification review stay on the existing trusted commands.

**Scope maintenance:** before provisioning another Coach/Admin or changing an actor's role/branches, prepare its exact scope using tools/functions/coach-read-scope.cjs, with fresh user/membership/organization snapshots and source revisions. Apply only through a reviewed trusted transaction, matching all source revisions and absent-document or exact existing-document preconditions. Read back the exact result. Do not refresh scopes from clients, broaden Rules or automatically infer a role from UI state. Missing/stale scopes intentionally fail closed. The current app has no self-service Coach/Admin provisioning action; maintenance is a privileged operational step, not an additional Function.

The two existing authenticated Scheduler jobs retain their original cadence, identity and retries, now targeting the verified Singapore services; no extra jobs or manual runs were introduced. The four former US business handlers now run in Singapore. Same-name US compatibility transports preserve signed raw callback bodies/query parameters, single-use OAuth state handling in the unchanged Singapore handler, and exactly one Google event-delivery path. Do not delete these transports while existing bills/OAuth configuration and the managed Eventarc destination reference them. New bill creation still uses the compatible US callback URLs. Do not detach the Google Function, delete its managed trigger/topic/subscription, create a parallel trigger or replay a booking event as a migration check. Earlier automatic-review rejections were resolved through the single-trigger forwarding design, not retried dual-trigger/global-region changes.

Callback/event rollback: retain all of build/final-region-cutover-20261024/. Restore a US original by uploading its generation-pinned original ZIP from archives and patching only buildConfig.source, with no trigger/queue/IAM change. OAuth must retain its original effective capacity, now explicit maxInstanceCount=100; the other limits are unchanged. Keep Singapore handlers available while requests drain. Do not roll back by replaying payments or removing ledgers. This release used eight local transport checks and harmless GET/IAM-denial parity only; genuine payment/OAuth/Google delivery UAT was not performed.

Retain the full latency-completion-20261024/ evidence directory: sealed per-target sources, runtime/IAM snapshots, operation checkpoints, retirement manifest, Rules baseline and client rollback. Rules rollback must check for subsequent releases and use direct-activation.json's prior ruleset only after endpoint/client recovery is ready. Do not delete scopes or any ledger as a convenience rollback. The original active APK, source packages and previously retained financial/UAT evidence remain protected. This release ran only affected checks/builds; it performed no new financial/provider UAT and no latency benchmarks.

### Historical optimization release records

The following paragraphs describe earlier deployments and their evidence, not current endpoint locations or commands to rerun. The current release and recovery sequence above supersede their active/rollback statements.

The next latency batch is retained under `build/latency-batch2-20261024/`. Reviewed `certification-only-release/` and `photo-only-release/` update only their existing US non-financial read exports; each is derived from that target's own deployed source. Do not use `coach-reads-release/`: its manifest is marked `SUPERSEDED_DO_NOT_DEPLOY` after cross-target source verification found different historical baselines. Both corrected updates are ACTIVE; all other 58 Functions and IAM are unchanged. `deployment-after.json` explicitly records the certification maximum-instance exception: unset became 20, and a field-only restoration retained 20. The owner subsequently approved retaining 20; record it as an accepted configuration change, not runtime parity. Further tuning/deletion remains gated. Photo has full runtime parity; `photo-live-before.json` / `photo-live-after.json` record actual same-payload timing and response equivalence.

The owner approved the two Payment Review read deployments and prepared local Admin activation. The exact selective command is in `financial-release-approval.json`: use only `payment-review-release/firebase.json` with `--only functions:listAdminBookingPaymentsCommand,functions:getAdminBookingPaymentCommand` in `us-central1`. The 22-file closure preserves the currently deployed financial helper implementations and non-secret runtime parameters; no manage command, secret value, Stage B/C, Rules, IAM or provider operation is included. Re-read deployed source/runtime/IAM and stop on drift before a later approved deployment. Its rollback sources are `deployed-listAdminBookingPaymentsCommand.zip` and `deployed-getAdminBookingPaymentCommand.zip`. The new private Admin bundle is under `client-artifacts/admin-web/`; hashes/cache policy are recorded in `admin-build.json`. It has replaced `build/admin-web/current` with its exact hashes verified over HTTP; previous static files are retained in `admin-before-approved-release/`, and browser Auth/storage is preserved. The authenticated baseline was captured on the private memory-only helper at `http://localhost:7362/`, and both approved read exports are now ACTIVE with full runtime/IAM parity; remote read-only verification subsequently passed with the same Admin identity and exact response hashes, and the owner confirmed normal Admin Payment Review list/detail loading. `payment-live-before.json`, `payment-live-after.json` and `payment-latency-comparison.json` retain the timings. The after-client used Node fetch instead of browser Firebase SDK, so the gains are indicative; a strict browser-to-browser/rendering benchmark was waived when the owner was remote. The remote helper accepts credentials only via stdin/in-memory and must never save tokens or credentials. Firebase CLI replaced rather than merged the isolated dotenv map during deployment; the exact captured environment was restored with a field-only update. The corrected private package preserves all 16 prior user environment values, verified using the actual CLI parser and an environment-file hash gate. Restoration and final parity evidence are in `payment-environment-restoration.json` and `payment-deployment-verified.json`. No APK update is needed for the deployed photo/certification reads. Direct client reads remain deferred where current Rules omit trusted callable checks; Rules are not weakened for latency.

- Preserve exact-scope prior approvals. Local implementation approval does not authorize a broad `firebase deploy`, Rules/index/IAM change, account change, payment/refund, catalogue write or Google automation expansion.
- Before a selective deployment, compare the approved source/bundle, exported functions, live configuration and rollback artifact. Current source includes held rewards/voucher work; a whole Functions deployment would exceed the accepted scope. The [cleanup inventory](project-cleanup-report-2026-10-24.md) and [archive index](archive/README.md) retain deployment provenance and rollback records.
- Only verified cleared payments settle membership; client totals and redirect success are not authority. For uncertain outcomes, reconcile the original bill/payment attempt and its persisted settlement before proposing another attempt. Status/recovery commands may mutate settlement and need financial authorization. Refund approval is not transfer; do not replay the unresolved Billplz HTTP 422 refund operation.
- Retain financial UAT ledgers, invoices, callback evidence, rollback ZIPs and signing/source provenance. Preserve private evidence in its existing protected location; do not copy credentials, account identities or screenshots into public documentation.
- `build/` currently contains generated output, authored scripts and protected evidence. `.dart_tool` can include a private browser profile. A future cleanup needs a reviewed retention manifest and path validation; no blanket clean, relocation or deletion is approved.

Use [STATUS](STATUS.md) for current business holds and [the archive index](archive/README.md) for historical procedures. Dated instructions are not permission to rerun them.
