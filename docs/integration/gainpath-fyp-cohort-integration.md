# Secure FYP cohort integration — local acceptance

4 November 2026, Malaysia. Target architecture: `gainpath-0619`, Firestore `(default)`, ordinary GainPath applications. **Local implementation; no live Firebase deployment or data mutation.** The earlier flat 202-path plan and named-database/special-app release proposals remain superseded and non-executable.

**Local acceptance: PASS.** Fresh verification covers 703 backend tests, 242 Flutter regressions, 32 emulator-suite checks and both ordinary Flutter client journeys, with 13 screenshots. The authoritative result and preservation audit are `build/fyp-cohort-integration/verification.json`. Native-device/browser acceptance and live execution remain pending.

## Implemented architecture

`datasetAssignments/{uid}` is server-owned. It binds the exact fictional identity, Auth creation timestamp, role, seed, dataset and revision. Verified email, Auth, App Check, current Auth custom claims, account lifecycle, membership, branches and assignment are checked on the server. Any existing canonical `users/{uid}` or `orgs/gainpath/members/{uid}` disqualifies the identity. A revoked assignment remains a provisioning tombstone; old-client registration cannot create canonical membership. Ordinary unassigned Member registration retains its previous contract.

An immutable in-process capability selects `orgs/gainpath/cohorts/fyp-v1`. Client `cohortId`, root, organization, role and demo flags cannot grant this authority. Logical domain organization IDs remain `gainpath`; typed stores map complete paths before reads. Server readers use fixed scoped collections, bounded limits and current identity revalidation. A failed source or policy check returns a safe failure, never a partial aggregate. Direct Firestore Rules validate current assignment/identity metadata and signed token claims; they cannot fetch a fresh Auth user record. Immediate direct-read revocation therefore requires disabling the assignment or cohort metadata, rather than relying solely on Auth disable/token expiry. The callable release gate alone does not disable direct Rules-authorized reads.

Canonical users retain canonical repositories. The ordinary Mobile and Admin Auth gateways discover only their own assignment and obtain the protected session. An assigned account with a failed protected session cannot fall back to canonical provisioning. The existing entrypoints, purple theme, navigation, cards and chart components are reused. Native SDK repositories select the verified root before fetching; forbidden records are not fetched and filtered in Flutter.

All supported cohort business writes pass through exact source/generated ownership checks. A transaction validates assignment/membership and existing target/ownership digests before flushing at most 80 staged domain writes. Foreign ownership, collisions and tampering fail closed. Generated ownership records are atomic sidecars; existing domain schemas remain unchanged. Consent revocation can legitimately change an owned source without allowing a later seed rerun to silently regrant it.

## Source graph and physical paths

| Entity | Count | Meaning |
|---|---:|---|
| Auth identities | 27 | 18 Members, 8 Coaches, 1 Admin; fictional invalid-domain email addresses |
| Source Firestore documents | 466 | Entire domain graph under the cohort root |
| Synthetic observations | 52 | Explicit `fictional_synthetic` outer provenance; `recordedFixture` payload |
| Published instructional tutorials | 12 | Compiled by the existing Routine publication service, including actual publication receipts |
| Published Programs | 3 | Existing Program save/publish services; complete 28-day schedules |
| Numeric Member goals | 18 | Plus 18 revision records |
| Published active Coaches | 7 | Eighth Coach intentionally inactive/unpublished; Admin management sees all eight |
| Assignments | 27 | Global exact UID bindings; no canonical Member/Admin grant |
| Seed ownership records | 493 | One for every source and assignment path |
| Auth ownership records | 27 | Actual Auth creation bindings |
| Seed run | 1 | Complete only after source validation and assignment provisioning |
| Initial emulator Firestore records | 1,014 | Excludes separate fictional baseline controls and later generated results |

Representative layout:

```text
datasetAssignments/{exactFictionalUid}
orgs/gainpath/cohorts/fyp-v1
  users/{uid}                       members/{uid}
  profiles/{memberId}/goals/{id}/revisions/{revision}
  coachProfiles/{coachId}/certifications/{id}/history/{revision}
  coaches/{coachId}                 coachAvailability/{coachId}/days/{date}
  exerciseVideos/{exerciseId}       routineBlueprints/{id}
  content/routine_demo-m13-tutorial-01-blueprint  [through 12]
  workoutProgramDrafts/{programId}  workoutProgramVersions/{programId}_v1
  members/{memberId}/syntheticObservations/{observationId}
  recommendationConsent/...        recommendationEvidencePolicies/...
  module13DemoSource/current
  seedRuns/gainpath-fyp-v1          seedOwnership/{pathDigest}
  seedAuthOwnership/{uid}           generatedOwnership/{pathDigest}
  [existing recommendation lead/recipient/receipt/notification collections]
```

The machine preflight lists every exact path and digest; it takes precedence over representative examples. Coach credential fixtures are metadata only: zero Storage uploads or fabricated download URLs, and no claim of real professional verification. No successful lead, recipient, delivery receipt or notification is preseeded.

## Shared observation contract

The normal measured-workout backup validator still rejects `recordedFixture`. Its existing real-camera acceptance path and Module 2 algorithms are unchanged. A separate validator shares summary shape/metric checks but requires fictional provenance and a minted cohort capability.

The observation reader verifies seed ownership, payload digest, owner/session identity, exact observation time and immutable source inventory. It queries only an authorized date interval, orders by date/document ID and fails on overflow beyond 100 records per Member. Missing, moved, future, malformed or incompatible sources are rejected. Existing scored/unscored, null score, tracking coverage, deduplication and scoring-version compatibility logic is reused.

Own Member history is a read-only basic-history projection. Insights/recommendation evidence additionally requires current purpose-specific consent and permitted history scope before source access. Admin browsers cannot read raw synthetic observation collections or the `member.history` endpoint. Module 12 receives the existing descriptive aggregation through the capability-bound reader: 52 sessions, 416 full repetitions, 104 partial repetitions and 404,000,000 tracked microseconds in the acceptance graph. It does not become accepted workout or reward evidence.

`FirebaseFypProgressRepository` hydrates the existing Member progress calculations/UI directly from this own-history projection. It writes neither device SQLite history nor backup/outbox state. Fictional timeline/result/report labels are explicit. Real accounts retain device-local progress behavior.

## Module 13 workflow and policy

The implementation reuses A1–E services: owned observation → validated compatibility/aggregation → explicit fictional educational policy → derived learning need → authoritative eligible Coach/published Tutorial candidates → existing baseline/validated mock semantic ranking → existing Admin queue → explicit review/Send → prepared recipient → existing once-only delivery → ordinary Member Notification Center → current scoped Coach/Tutorial destination.

The ordinary Admin widget explicitly sends both recommendations to `demo-m13-member-02`; the ordinary Member widget signs in as that exact recipient and verifies the two delivered inbox entries, current destinations and responses. A separate Member01 callable scenario verifies idempotent delivery, peer denial and subsequent consent/assignment revocation without interfering with the UI journey.

Acceptance processes 18 fictional Members per recommendation kind. Each kind generates six leads and abstains for twelve Members: seven insufficient-evidence, one unsupported-evidence and four missing-consent cases. Trainer generation evaluates 18 candidates in total; Content evaluates 20. One deterministic fallback per kind exercises missing external-inference permission. The provider is the controlled `gainpath-demo-structured-mock-v1`, **not a new Gemini measurement**. Existing Batch B's 18-attempt real synthetic ledger and results remain historical evidence, not new calls or independent recommendation-quality proof.

The fixture educational policy is explicitly `synthetic_reviewed` / `demo-educational-v1`: compatible exercise-specific groups, three scored sessions on three distinct days, at least 30 assessed attempts, tracking coverage at least 0.8, form score below 65 and maximum age seven days. These are fictional test choices, not approved real-Member thresholds or clinical-risk categories. The general configuration's production activation flags remain false. No real consent collection, retained-history processing, cohort-suppression threshold or retention/TTL decision is activated.

Four recommendation purposes remain separate: insights processing, generation, external inference and receiving recommendations. The graph includes explicit granted, missing, new-only and revoked fictional consent scenarios produced by the versioned consent service. Current consent and identity are revalidated for delivery and destination access. Delivery-purpose revocation redacts a previously available target, exercise label and explanations; assignment revocation closes the session.

## Verified module coverage

| Module/surface | Local coverage | Limits |
|---|---|---|
| Accounts / Member Profile | Ordinary login, protected scope, complete read projections, account isolation | No live accounts; profile mutation unsupported by cohort Rules |
| Module 2 / Member history | Truthful synthetic summary validation and read-only history/progress | Camera measurement/acceptance unchanged; no camera accuracy claim |
| Member analytics | Existing progress, activity and report calculations reuse own summaries | No local history overwrite, accepted workout or points |
| Coach Directory / Profiles | Seven published scoped Coaches; current profile reads | Inactive Coach excluded; no booking modification |
| Coach availability / roster | Existing authoritative availability, capacity, booking-list and roster read services | No holds, payments or booking creation |
| Credentials | Current metadata, status and history read services | No Storage uploads or credential download proof |
| Tutorials / Programs | Twelve service-published instructions and three published Programs | No invented tutorial URLs; no Member Program enrollment mutation |
| Notifications | Existing in-app inbox, once-only recommendation delivery, current navigation and Member response | No push/email or real notification |
| Admin management | Scoped Member/Coach reads using ordinary screens | No canonical Admin authority or cohort account edits |
| Module 12 | Scoped census and descriptive workout/check-in services; same observations | Existing canonical formulas unchanged; no private histories in response |
| Module 13 | Evidence-derived Trainer/Content queues, review/Send, delivery, acknowledge/dismiss | Manual synthetic workflow only; no new Gemini or automatic LeadEvaluator |
| Payment / membership / rewards / competition | Actual legacy endpoint denials tested | Intentionally unavailable to cohort actors; no paid success or rewards |
| Chatbot / external AI / other mutations | Existing canonical behavior preserved | Not enabled for cohort demonstrations; `getCoachAccountSettingsCommand` scoped operation unavailable |

Original Chapter 3/4 UC13.1–UC13.15 and FR13.1–FR13.4 traceability remains in `module13-final-completion.md`; academic originals are unchanged. This integration supplies the scope/source/ordinary-app plumbing, without redefining those requirements or claiming clinical validation.

## Verification and reproduction

Fresh result files are under `build/fyp-cohort-integration/`:

- `backend-results.json`: 703 focused backend tests across 55 files, including A1/A2, ranking/consent/delivery, Module 12, backup validation, Programs and provisioning.
- `shared-data-summary.json`, `admin-summary.json`, `mobile-summary.json`: 27, 107 and 108 focused Flutter regressions, with raw JSON event logs and exact file lists.
- `emulator-results.json`, `integration-proof.json`, redacted `*-client-output-*.log`: actual default Auth/Firestore/Functions/Rules acceptance and both ordinary Flutter compositions. Use the final PASS artifact, not earlier failed-run logs.
- `dart-analysis.txt`: strict analysis of changed Dart files; source/test TypeScript no-emit checks are recorded separately.
- `source-changes.json`, `verification.json`: baseline comparison, exact changed/added files, artifact hashes, preserved academic/provider evidence and protected sources.

Run from the repository root using installed dependencies:

```text
node functions/tools/test-fyp-regressions.cjs
node functions/tools/test-fyp-clients.cjs
node functions/emulator/run-fyp-cohort.cjs --with-clients
```

The dedicated emulator project is `demo-gainpath-fyp`, default database, Auth19131/Firestore18231/Functions15031. Credentials are ephemeral, never source-controlled or logged. The seed runner refuses live/custom SDK endpoints. `functions/tools/fyp-seed.cjs` supports offline plan and dedicated-emulator dry-run/apply/validate/cleanup-dry-run with an explicit immutable anchor. There is no delete executor or live apply mode. Changed or unowned records are preserved.

Rules tests cover published queries, owner notifications, management, profiles/goals, sibling cohort/organization denial, lifecycle/branch/current-binding drift, recreated UID and canonical-orphan rejection, and server-only raw/internal records. Admin SDK and actual callable tests additionally prove scoped denominators, legacy registration/payment/membership/reward/competition denial, missing Auth/App Check, request-scope forgery, wrong roles, destination ownership, idempotency and revocation. Baseline fictional canonical controls remain byte-equivalent; financial/reward/workout-acceptance collections remain empty.

Ordinary UI screenshots are `build/fyp-shared-data/ordinary-admin-*.png` and `ordinary-member-*.png`. Widget tests instantiate the normal `.injected` applications and use actual email/password Auth, protected callable HTTP and Rules-backed Firestore REST with real emulator records; they do not use the historical special Demo Apps or hardcoded fixture lists. Native Firestore SDK root selection has focused adapter tests. This is **not** signed-in native-device/browser UAT. Test-only offline font aliases and the chart font family use bundled Barlow bytes; production typography and assets are unchanged. Some tab text still uses the widget-test fallback font, so these renders do not establish native typography acceptance. The emulator uses installed Node24 although the proposed Functions runtime is Node22. Emulator decoded App Check tokens establish handler enforcement boundaries, not cryptographic production attestation.

## Changed source map and remaining gates

Core files: `functions/src/modules/dataset/fyp-{scope,backend,module-services,dataset,integrity,seed,observations,evidence-reader,runtime-release}.ts`; prepared `fyp-local-index.ts` / `fyp-release-index.ts`; assignment-aware Member provisioning; narrow existing evidence/queue/delivery/Module12 adapters; additive `firebase/firestore.rules`; shared typed Dart session/transport; both Auth gateways/scoped SDK adapters; ordinary app DI; read-only Mobile FYP progress repository. Exact source lists/hashes are in `source-changes.json`. No broad rebuild of ranking, validation or booking services was introduced.

The normal production Functions index, indexes, Storage Rules, Module 2 measurement code, existing UI theme assets and historical Gemini artifacts are preservation targets. The separate release package exports only two FYP callables, with enforced App Check and a default-closed exact-manifest/27-UID server gate. It is prepared, unregistered and undeployed. No live release record exists as a result of this task.

The replacement [live preflight](gainpath-fyp-cohort-preflight.md) and its exact machine manifest are for one consolidated owner review after local acceptance. Fresh live collision/trigger/runtime checks, a separately verified manifest-bound live executor, real App Check and native SDK UAT remain release gates. Real-Member consent/policy/retention, independent human recommendation evaluation, financial/reward activation and clinical validation are outside this checkpoint. No APK, IAM/billing action, deployment, cloud seed, real Member-history read or new Gemini request occurred.
