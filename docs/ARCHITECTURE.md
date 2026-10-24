# Current architecture

Source inspected 24 October 2026. [Status](STATUS.md) distinguishes deployed/accepted capabilities from local or planned work; [operations](OPERATIONS.md) contains commands. This reference describes the current code, not a proposed rewrite.

## Workspace and authority

| Area | Current responsibility |
|---|---|
| `apps/mobile` | Independent Member/Coach Flutter app; Android Firebase configuration, native pose/audio/PDF integration |
| `apps/admin_web` | Independent Flutter Admin app and its own Firebase initialization/configuration |
| `packages/gainpath_domain` | Pure Dart entities, policies and repository contracts |
| `packages/gainpath_data` | Pure Dart adapters, DTOs, scoped repositories and in-memory sessions; app code supplies Firebase transports |
| `packages/gainpath_identity` | Shared Flutter AuthBloc and role policy, consuming domain contracts |
| `packages/gainpath_ui` | Shared Flutter visual primitives/design tokens |
| `packages/gainpath_pose` | Pure Dart pose processing and detector contract; protected core |
| `functions/src/modules`, `functions/src/platform` | Trusted services, validation, authorization, transactions, provider adapters and background consistency |
| `firebase`, `contracts` | Security Rules/index/emulator source and versioned transport schemas |
| `tool`, `tools` | Architecture/verification checks and local development tools |

The workspace root is not a third Flutter app. Apps do not import each other. Domain/pose remain independent of Flutter/Firebase; composition selects adapters and owns cross-feature navigation. Shared code does not imply shared session state. The architecture checker is [check_architecture.dart](../tool/check_architecture.dart).

Use direct Firestore reads/writes for existing permitted ordinary CRUD. Use trusted commands for authoritative financial mutations, reservations, privileged projections, role administration and secret-backed provider operations. A `get` command may still mutate: payment status can settle money, account lifecycle status can finish revocation, and coach performance can recognize earnings. Existing Rules are not replaced by client-side checks.

Own Coach settings and Coach/Admin certification list/details/history now use the shared `CoachDirectReads` adapter with `DIRECT_COACH_READS=true` by default. The deployed Rules use server-owned `orgs/{org}/coachReadScopes/{uid}` attestations, checked against live identity, membership, organization status and lifecycle; Coaches do not gain access to the private organization document. Three existing active Coach/Admin actors have validated scope records. New actors or role/branch changes require a trusted scope creation/refresh; stale/missing scopes fail closed. Settings use existing identity fields; writes and phone uniqueness remain on trusted commands. No additional Function or settings projection is introduced. Firestore App Check is enforced; SDK and REST checks reject missing tokens. Both former read Functions have been retired in both regions.

Membership is organization-wide, distinct from branch-scoped coaching reservations. Callback, recovery and Admin verification reuse settlement services. Assistant booking suggestions reuse options/quote services; they do not create a separate payment authority. Manual and automatic Google delivery reuse a coordinator with leases/receipts/revision checks.

### Callable regional transport in current source

Both apps use their local `firebase_function_transport.dart` helper and the pure-Dart `FunctionEndpointSelector`. `FUNCTIONS_REGION` defaults to `asia-southeast1` for the deployed logical callable inventory. Ratings and Booking List/Availability retain their verified Singapore aliases. `SINGAPORE_CALLABLES` remains an explicit override; it no longer controls the normal default region. The two retired Coach reads use Firestore instead. Explicit SDK/repository injection remains available for tests; emulator calls use original logical names in local `us-central1`, never regional cloud fallbacks. Held Stage B/C, HTTP callbacks, schedules and event workers are outside the client allowlist. Payments, entitlement, reservations, earnings and integrations remain trusted backend operations. US client flags are recovery configuration only: retired endpoints must be restored from retained exact sources before using them.

## Admin startup and navigation

1. [lib/main.dart](../apps/admin_web/lib/main.dart) calls `launchGainPathAdminApp()`, awaits Firebase/App Check initialization and runs the Firebase-only Admin application. Failed initialization displays setup guidance; no sample graph is created.
2. [admin_app.dart](../apps/admin_web/lib/app/admin_app.dart) builds `GainPathAdminWebApp`, validates its required configuration and creates Auth. Normal constructors accept only configuration/key; `.injected(...)` explicitly permits test/development Auth/repository overrides. `MaterialApp(home: _AdminAuthGate(...))` selects checking, email-verification, login or authenticated shell states.
3. The gate uses `AuthRolePolicy` with `AppRole.admin`. The shared Firebase auth repository maps stored `admin`, `staff` and `branch_staff` to this presentation role. This normalization does **not** grant server-side Admin permission: individual Rules/commands still authorize the actual stored role and scope.
4. [AdminShell](../apps/admin_web/lib/app/shells/admin_shell.dart) owns sidebar destinations, `_index`, expanded groups, visited pages and an `IndexedStack`. Live pages mount lazily after first visit; coach edit discard guards participate in navigation.

There is no general URL router mapping `/members`, `/refunds`, etc. The [route constants](../apps/admin_web/lib/app/routing/app_routes.dart) only define login/role selection as `/`. Sidebar selection changes widget state rather than browser location. Nested coach bookings/schedule are shell state; Account → My account uses a `MaterialPageRoute`. Breadcrumbs describe in-app state, not routable URLs. Refresh normally returns to the initial shell destination, not a URL-addressable page.

The local static server's SPA fallback can return index.html for an unknown path, but that does not create an application route. Use sidebar/group controls to open modules. A `?build=<hash>` query is a cache-busting asset/document selection aid, not a module route.

### Reachable Admin areas

“Reachable” means wired into the current shell; it does not mean every chart/action has a live implementation.

| Destination | Current Firebase behavior / limits |
|---|---|
| Dashboard | Authenticated organization shell; unsupported aggregate metrics use unavailable/neutral reporting, not fabricated revenue |
| Users & Coaches → Members | Directory/search/details and trusted membership verification; local rewards work remains subject to the Stage B hold |
| Users & Coaches → Coaches | Profile/publication/certification review; nested booking and schedule views; review alerts |
| Recommendations | Shared layout with neutral/empty live datasets and unavailable matching actions; not a completed live recommendation engine |
| Refunds | Existing payment review for both CoachingBooking and Membership purchase/renewal; trusted commands, explicit refund-transfer limits |
| Content → Exercise Tutorials | Connected catalog authoring; publishing/media activation remains separately controlled |
| Content → Routine Templates | Connected template authoring and trusted publication |
| Equipment Catalog | Connected equipment/image/video metadata workflow |
| Governance → Reward Catalog | Connected metadata drafts/archive; not activation of trusted Premium points, fulfilment or voucher accounting |
| Governance → Announcements | Connected organization content workflow |
| Governance → AI Chatbot Disclaimer | Versioned connected safety notice authoring; current notice is not a generic legal acceptance service |
| Reports | Shared reporting UI; default live reporting gateway is unavailable and unsupported series remain empty/unknown |
| System Settings | Facility/compliance drafts and Google integration controls; reward conversion/operational policies are not broadly activated by the screen |

Account → My account additionally reaches Admin identity/photo/preferences. Coach review notifications can select an existing coach view. The three expandable groups are navigation containers, not extra pages.

## Backend selection: actual behavior

Normal Mobile and Admin execution is **Firebase-only**. Both main entrypoints await their Firebase bootstrap, then construct the application without a backend argument. The obsolete BackendConfig parser, runtime enum and seeded Mock host branches were removed. Old BACKEND flags in dated evidence describe earlier artifacts and no longer select any implementation.

Android Studio Mobile runs apps/mobile/lib/main.dart directly with the existing Android package/signing identity. Debug builds activate the existing native App Check debug provider by default; release builds select Play Integrity. This does not register a token or weaken cloud enforcement. Admin has its independent Web App Check setup: its checked-in run configuration consumes an ignored private define file generated from the existing registered fixture. No token is checked into Git.

Explicit `.injected(...)` constructors retain Auth and repository factories for tests. Seeded Mobile scope/app composition and Admin shell fixtures now live under test/support; fakes are not an alternate normal application mode.

### Repository selection and possible mixing

[AppRepositories](../apps/admin_web/lib/app/di/app_repositories.dart) receives the authenticated session and optional explicitly injected test factories. The host is keyed by session; scoped guards are disposed when the identity changes.

- Before sign-in, the host returns the child without creating the signed-in feature graph. After sign-in, it injects Firebase tutorial/routine/coach/availability/booking/member/content/account/equipment/reward-metadata/facility repositories, plus app-local file pickers and the scoped Google transport.
- Unsupported legacy presentation ports are supplied by [AdminPresentationDependencies](../apps/admin_web/lib/app/di/admin_presentation_dependencies.dart) as **neutral/unavailable** repositories. Empty lists, unknown metrics and placeholders are not seeded mock financial/member records. The normal reporting gateway defaults to unavailable unless explicitly injected.
- The payment review route creates its own scoped [FirebasePaymentReviewRepository](../apps/admin_web/lib/app/di/payment_review_factory.dart), rather than using the neutral legacy membership presentation repository.
- Named `.injected(...)` constructors intentionally permit test substitutes. Normal constructors expose no repository overrides and always use the Firebase adapters. Neutral/unavailable capabilities and measured local stores remain truthful dependencies, with no fabricated business data.

The mobile Member shell injects a session-bound membership commerce repository into Profile. Its badge and account row use the same validated entitlement as the Membership dashboard: effective tier, paid expiry, and an explicit historical label for offline cache. Unknown or failed reads stay unavailable. Profile refreshes on app resume, manual refresh, and return from Membership; test-owned shell fixtures may explicitly provide fake commerce. This is local source behavior, not new phone or financial UAT.

## Normal Admin versus temporary UAT pages

The normal app is `apps/admin_web/lib/main.dart`, conventionally served at `http://localhost:7359/` by [tools/admin_web/serve.cjs](../tools/admin_web/serve.cjs). It serves `build/admin-web/current`; [build.cjs](../tools/admin_web/build.cjs) compiles the normal app using an existing privately supplied registered Web App Check context. This is local serving, not Firebase Hosting publication.

[tool/membership_readonly_uat.dart](../apps/admin_web/tool/membership_readonly_uat.dart) is a separate local-only entrypoint: it reuses the normal same-origin Auth session, permits only a bounded verification command for one exact target, and is not imported by the normal app. Its historical `/membership-uat/` URL exists only when the special local UAT server maps that prefix. It is not a normal Admin module/deep link. The equipment image probe is another diagnostic tool, not a second product console.

The retained Module 4 UAT server can currently serve the normal app at `/` and the scoped UAT bundle at `/membership-uat/` on the same port. The canonical normal server does not provide that UAT mapping. Do not run competing servers on 7359 or infer behavior from an old `/builds/...` snapshot. The [operations guide](OPERATIONS.md) documents current commands and cache behavior without changing any server in this phase.

## Source, deployment and evidence

Current deployment: **59 ACTIVE Node 22 Functions: 55 Singapore, four US compatibility transports**. Singapore contains 49 callables, two scheduled workers, `paymentWebhook`, `googleGymOAuthCallback`, static `billplzSandboxReturn` and the private `synchronizeGoogleBooking` CloudEvent receiver. Four same-name US transports preserve provider URLs and the original single Eventarc queue while forwarding unchanged payloads to Singapore; they contain no Firestore or financial/provider business handlers. The initial inventory was 57; the intermediate regional-copy count was 65. The prior client/direct-read cutover created 45 replacements and retired 55 endpoints (65 to 55). The final callback/event cutover added four Singapore handlers and retained four US transports (55 to 59). Two logical read Functions were eliminated relative to the original inventory; migration copies are not additional eliminated dependencies. Functions were copied from each exact deployed source closure; current index.ts still includes held work, so broad source-tree deployment remains inappropriate. Source declarations/default regions are not a substitute for the isolated deployed inventory.

The installed Xiaomi APK and normal private Admin bundle use direct Coach reads and Singapore callables. Existing accounts/browser/device data were preserved. Existing Scheduler jobs target Singapore; no jobs were duplicated or manually run. US payment/OAuth URLs and the single Google event trigger remain unchanged, with US source replaced by tested forwarding. The Google receiver is private and has no second Eventarc trigger; the original runtime identity invokes it with an audience-bound ID token. HTTP forwarding preserves raw signed bytes, query parameters, response status and security headers, and does not automatically retry uncertain callbacks. The earlier rejected parallel-trigger/incomplete-global approaches were not used. No provider/payment operation or Stage B/C activation occurred. Evidence and rollback sources: `build/final-region-cutover-20261024/verification.json`, its original four source archives/runtime/IAM snapshot, and prior `build/latency-completion-20261024/verification.json`, archives and client rollback. OAuth effective original maximum 100 is now explicit in both regions; other runtime settings and all invoker policies are preserved. This is not a Hosting release or a claim of new financial UAT.

Use [STATUS](STATUS.md) for the current evidence boundary, [the cleanup audit](project-cleanup-report-2026-10-24.md) for the exact Function/artifact inventory, and [the archive index](archive/README.md) for original decisions and rollback records. The separately approved local backend-selection correction changes startup/composition only; it does not deploy or alter financial services, routing, security policies or held benefits.
