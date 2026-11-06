# Module13 Batch A2 — local completion checkpoint

**1 November 2026, Malaysia. Status: locally implemented and fixture/emulator verified. Production recommendation processing remains disabled.** A1 is preserved; Module12 metrics, existing workout validation/scoring, Firebase exports/Rules/indexes and unrelated Mobile changes are unchanged.

## Implemented functionality versus runtime availability

| Area | Local implementation | Normal signed-in application / production |
|---|---|---|
| Exercise Insights | Existing Recommendations page's first tab now uses the typed A1-derived presentation, shared GainPath panels and Syncfusion. Compatible groups show score/null/unscored state, scored sessions, distinct Members, tracking coverage, missing scores and evidence definitions. | Uses `UnavailableExerciseInsightsRepository`. No Firebase request, seeded fallback or manufactured analytics. Source UI integration is tested; no new Web build or served-bundle activation was performed. |
| Filters/dates | Exercise and actual catalog-category filters;7/30/90-day or custom Malaysia calendar ranges, end clamped to now and90-day maximum. New queries clear old values; stale responses and account drift cannot repopulate them. | Controls can explain scope, but analytics remain unavailable until a reviewed source/endpoint is wired. |
| Content coverage/gaps | Bounded ID-based join of active/nonarchived `exerciseVideos` metadata with `content` published Routine tutorial projections. Existing tutorial instruction/media validators are reused. Archived/inactive/unpublished/image-only entries do not fill instruction gaps. | No production catalog reader is registered. Supplied synthetic catalog/publication records use the actual field contracts. Media URL syntax does not establish reachability/licensing. |
| CSV | Separate insights, content coverage and gap exports use the exact display filters. Formula-leading text is escaped. Insights retain all eight compatibility fields, source/query definitions and sample states. Exports recheck scope before creating rows. | Unavailable sections cannot export fabricated status datasets. Browser download UAT remains pending; the existing browser CSV implementation is reused. |
| Configuration | Local server command selects only injected reviewed exact-group policy IDs, with validation, expected revision, atomic audit and idempotent receipt. Descriptive stats, sample minimums, score-below attention and actual recommendation eligibility remain separate. | No approved registry/default threshold exists. All generation/AI/matching/delivery activation fields are permanently false in this contract. No deployed command or production config change. |
| Consent | Local version2 command/evaluator for four independent default-off purposes, reviewed notice/content acceptance, own-account authorization, total/per-purpose revisions, grant/revoke receipts and audits. | No production consent collection, Mobile UI, migration or automatic inheritance from camera/backup/Coach-sharing/chatbot permissions. |
| Firestore adapter | Explicitly reviewed demo-emulator-only injected reader: organization-bound, ascending bounded nested head queries; current identity/consent revalidation remains in A1 handler. Transport guard verifies actual SDK endpoint/TLS, not just environment/project name. | No SDK default app/bootstrap, real datastore adapter or registered API. V2 cannot use the broad legacy reader. |

**No later-batch functionality:** no Gemini calls/ranking, Coach/tutorial lead generation, LeadEvaluator, Send/Dismiss, delivery, paid booking, Program/history/reward/consent-default changes, retention jobs, Firebase deployment or APK packaging/install.

## Source inventory

Backend additions under `functions/src/modules/recommendation/`:

- `recommendation-configuration.ts`: `createRecommendationConfigurationCommand`, `defaultRecommendationConfiguration`, reviewed group policy types and shared local command guards.
- `recommendation-consent-v2.ts`: `createRecommendationConsentV2Command`, `evaluateRecommendationConsentV2`, independent purpose grants and reviewed notice/history policies.
- `firestore-exercise-insights-reader.ts`: `createFirestoreExerciseInsightsReader`, disabled unless dedicated demo/loopback/actual-transport gates match.
- `exercise-insights-presentation.ts`: `projectExerciseInsights`, bounded published-content coverage and reviewed cohort disclosure boundary.

A1 extensions: `exercise-insights-contracts.ts`, `recommendation-consent.ts`, `exercise-insights.ts`. They add v2 notice validation/history bounds and an optional `consentScopedBackups` reader capability, retaining all A1 validation, dedupe, compatibility, bounded aggregation and default-null policies.

Admin additions under `apps/admin_web/lib/features/recommendation/`:

- `application/exercise_insights.dart`: strict typed parser, compatible groups/content DTOs, Malaysia queries, matching filter/export logic and CSV safety.
- `application/exercise_insights_repository.dart`: explicit repository/configuration interfaces and the normal unavailable implementation; no Firebase or fixture fallback.
- `presentation/admin/exercise_insights_panel.dart`: states, group evidence/count chart, filters/dates, content/gaps, reviewed-policy selection and guarded exports.
- Existing `presentation/admin/admin_recommendation_screens.dart` replaces only its first-tab implementation and old universal slider; its three-tab hub/navigation and deferred queue capability boundaries remain. Live queue exports are disabled.

Verification files: backend `test/recommendation-configuration.test.ts`, `recommendation-consent-v2.test.ts`, `firestore-exercise-insights-reader.test.ts`, `exercise-insights-presentation.test.ts`; Admin `test/exercise_insights_test.dart`, `admin_exercise_insights_test.dart`, `support/exercise_insights_fixture.dart`; updated unavailable-copy and emulator-harness tests. Dedicated emulator files: `functions/emulator/module13-a2.test.ts`, `run-module13-a2.cjs`, `functions/vitest.module13-a2.emulator.config.ts`, `firebase/module13-a2.emulator.test.json`. Existing broad harness explicitly accounts for the standalone suite without running it as core.

## Configuration, consent and history contracts

`orgs/{org}/recommendationConfiguration/current` is proposed server-owned storage. Its default is revision0, no policies and all activation fields false. The command accepts only schema/org/command ID/expected revision/policy IDs; an Admin cannot submit or approve an arbitrary score threshold. Injected `ReviewedRecommendationPolicy` values bind all compatibility fields and review version, optional sample minimums, optional strict `score_below` Estimated Form Score threshold and separate descriptive cohort minimum. There is no High-Risk tier/default70.

The display projection applies attention only when exact compatibility and the sample-policy contract match, all contributing Members meet that policy's provisional minimums, any configured descriptive cohort minimum is met, and privacy disclosure is permitted. Otherwise it remains descriptive/not assessed. Attention is educational descriptive classification; `recommendationEligibility` remains `not_evaluated`. No actual recommendation eligibility is computed.

A1 currently carries one sample-policy profile per response. Configuration can store multiple exact-group policies, but any group requiring a different sample profile remains not assessed; a future reviewed composition must support those profiles without mixing measurements. Catalog coverage is bounded to 1,000 catalog/500 published Routine records and 16MiB supplied JSON; invalid/excess sources fail without partial output. “Published projections” counts qualifying Routine/exercise projections, deduped within each Routine, not unique video files.

Consent path remains `orgs/{org}/recommendationConsent/{memberId}`. V2 contains schema2/policy version `module13-purpose-v2-local`, org/Member identity, total revision/update time and four purpose entries:

```text
exerciseInsights, recommendationGeneration, externalAiInference, recommendationDelivery
  granted: false by default
  revision: 0 initially
  grantedAtMillis / revokedAtMillis
  noticePolicyId / noticeVersion / contentVersion
  historyStartAtMillis
```

Grant/revoke modifies only the authenticated Member's selected purpose, with expected total revision, incremented own-purpose revision and immutable audit/receipt. Grant requires matching currently reviewed notice/content versions. Revoke does not need a new consent grant and never changes workout history/backups. Regrant resets its time boundary. Requests cannot assert retained-history approval or another Member ID. No v1 record is silently migrated; A1's v1 fixtures remain supported only as the existing local contract.

**History blocker:** the current backup heads hold actual session time only inside `payloadJson`. Reading all heads and then filtering would already read unapproved older histories. V2 therefore requires a separately enforceable `reader.consentScopedBackups(scope,window,after,limit)` capability and checks the permitted query start before any v2 history read. The prepared legacy Firestore adapter deliberately does not implement it; v2 fails closed. A synthetic scoped callback proves the contract; the real source needs separately reviewed trusted capture-time metadata/index/query/migration design. Neither upload time nor client assertions can substitute. No metadata migration is part of A2.

The entire requested window must currently be within the grant's approved history scope; no implicit retrospective permission or silent per-Member clipping is introduced. Missing notice approval or consent remains off. Raw A1 aggregates are an internal server contract, not a browser transport; future endpoint composition must apply the disclosure projection.

## Proposed Member settings and wording — owner review required

Navigation proposal: **Profile > Settings > Privacy & Data > Personalized Recommendations**. This is a proposal, not a Mobile screen activated in A2. Show feature availability, current server choices and notice versions. Initially all four switches remain off/unavailable until the privacy/release gate is approved. Do not bundle them into one master opt-in or change them when camera/backup consent changes.

Proposed copy:

| Separate setting | Proposed explanation |
|---|---|
| Exercise insights processing | “Allow eligible workout summaries to contribute to exercise-level insights for your gym's authorized Admins, subject to reviewed group-disclosure limits. These summaries contain counts and estimated form measurements, not workout video or raw pose landmarks.” |
| Personalized recommendation generation | “Allow the separately permitted workout evidence and fitness information described in the notice to help prepare Coach or tutorial suggestions for Admin review. This does not change your Program, book a Coach or approve a paid service.” |
| External AI inference | “Allow the minimum learning context described in the notice to be sent to the approved AI provider for ranking. Your name, raw workout history, video and pose landmarks will not be sent.” Provider identity, actual fields, location and retention must be finalized before this notice is offered. |
| Receiving recommendations | “Allow Admin-approved Coach or tutorial suggestions to appear in your existing Notification Center. You choose whether to open or act on them.” |

Grant review should show the exact purpose, notice/content version, data/source types and permitted start date before confirmation. The conservative notice policy is from-grant only; permission for retained history needs a separate reviewed notice/policy and source capability, not a preselected checkbox. Current A2 cannot process either production history path.

Revoke copy proposal: “Turning this off stops future use for this purpose. It does not delete your workout history or backups. Treatment of prior insights, recommendations and minimal audit records is explained in the reviewed retention notice.” Do not promise deletion/retention periods that have not been approved. Reopen/retry must reload current server state; command receipts describe past operations and are not a substitute for the current settings snapshot. UI grant collection/read composition remains future work.

## Small-cohort disclosure proposal — not activated

Removing direct IDs does not make singleton/two-Member groups anonymous. The new projection's default, with no approved cohort policy, is to withhold **all observed groups and measurement-derived counts**. It does not silently select 3 or 5. Public catalog coverage is independent and can remain available. The normal app still has no reader.

For owner review, consider minimum 3 as a limited synthetic/FYP demonstration policy versus minimum 5 for a more conservative real-data pilot. Choose only after examining cohort size and inferential risk; neither number is a statistical privacy guarantee. The explicit 3-Member policy in tests is synthetic-only.

When an approved policy is injected, a group below its distinct-Member limit is omitted with all its counts, mean, coverage, sample counts and attention flags. No suppressed-group count, overall Member denominator, source scan counts or other complement is returned by the presentation. Omitted evidence is labeled withheld/unavailable, never zero. All section exports consume the same disclosed projection and filters; client parsing rejects groups or attention-derived content flags when disclosure review is pending.

The policy still needs decisions on overlapping date windows, filter differencing, repeated queries, longitudinal linkage and auxiliary knowledge. A per-group cutoff alone does not prevent these attacks. Do not expose the internal A1 response or enable production exports before this review. Catalog-only instruction gaps must not be confused with attention-linked Member needs.

## Verification and limitations

Fresh focused results after the review corrections:

- **232 backend tests:** 11 files including A1, Module12 reporting/workout validation regressions, config/consent, privacy/content projection, adapter and emulator-harness accounting.
- **38 Admin tests:** 7 files covering typed parsing, filters/Malaysia dates, null/unscored states, fixture provenance, scope/stale-response handling, reviewed selection, CSV/filter consistency/formula safety/exact identity, existing neutral composition and Module12 workout/reporting behavior.
- **11 actual isolated Firestore emulator tests:** real `FirestoreStore` and reader pagination, ownership/org boundaries, consent/Admin/Member drift, v2 missing-scoped-source zero-read refusal and unchanged client Rules denial for private histories/M13 settings/audits/receipts.
- Source and test TypeScript no-emit checks passed; focused Flutter analysis found no issues; Admin presentation-boundary check passed. No unrelated full suite, release Web build or Android packaging ran.
- Desktop 1400px and narrow 600px fixture renders were inspected. They use existing local substitute fonts and the shared component palette, not authenticated browser pixels. Browser download and full signed-in UAT remain pending. Preview artifacts: `build/module13-a2/fixture-1400.png`, `fixture-600.png`.

Run backend suites using installed Vitest; run the dedicated emulator with `cd functions; node emulator/run-module13-a2.cjs`. It uses only `demo-gainpath-module13-a2`, loopback 18110, isolated CLI preferences and the existing cached emulator JAR. It strips inherited Firebase token/credential-file settings and uses an installed Java runtime. No owner login or live application records are required. Expected Rules permission-denied test logs and the installed Vite CJS deprecation warning do not indicate failed tests.

Real App Check attestation, real Firebase Auth token verification, production source completeness and deployed behavior are **not** established by these tests. Local handlers check the trusted context/identity contract; any later registered callable must independently enforce App Check and supply current verified Auth from Firebase. No callable is registered here. The source remains a bounded non-atomic scan with final authority/consent revalidation, not an atomic snapshot.

Independent review identified an actual-transport gate gap and incomplete CSV group identity. Regression tests first failed, then passed after effective SDK endpoint/TLS verification and full compatibility export. Pending-disclosure content flags were also rejected client-side. The adapter's fail-closed effective-settings check depends on the installed SDK representation; a dependency upgrade requires revalidation.

Two documented minor limits remain: a mixed legacy-v1/v2 fixture scan can perform earlier authorized v1 work before discovering the missing v2 capability, but returns no partial result and never reads unauthorized v2 history; removing a reviewed policy/notice can cause an identical old command retry to be refused before its receipt is returned. This is safe fail-closed behavior, not guaranteed retry availability after governance changes. Replayed receipts do not reapply old grants/configurations.

## Original requirements coverage

Original chapters, UC13.1–15 and FR13.1–4 remain unchanged and mapped through the [audit](C:/Users/Ngzhe/Documents/ChatGPT/GainPath/docs/superpowers/plans/2026-10-31-module13-audit-and-proposed-plan.md) and [A1 matrix](module13-batch-a1-evidence-and-insights.md#original-requirement-traceability). Figure 3.19's actual image remains unverified; A2 adds no contrary claim.

| Requirement | A2 evidence | Completion classification |
|---|---|---|
| UC13.1 exercise leaderboard | Typed compatible-group insights, counts/coverage/states and count chart in existing tab; no cross-rubric score ranking or clinical-risk claim. | PARTIAL original UC; local insight presentation PASS. Live source, approved operational ranking/policy and UAT remain blocked. |
| UC13.4 category filter | Actual category/exercise filters shared by display and CSV, plus bounded Malaysia dates. | PASS fixture/widget behavior; PARTIAL original operational acceptance until live/UAT gates. |
| UC13.5 threshold configuration | Server-reviewed policy selection, revision/audit/idempotency, exact groups and separate sample/attention/eligibility semantics; no default slider. | PASS local contract/tests; PARTIAL original UC because no production settings or approved threshold. |
| UC13.6 leaderboard export | Section CSVs with exact compatibility/filter/date/provenance and disclosure consistency. | PASS row-generation/guard tests; PARTIAL browser/live export acceptance. |
| UC13.7 content gap report | Actual catalog/publication-contract join, active instruction gaps, separate optional reviewed attention linkage. | PARTIAL original attention-driven UC; local catalog coverage/gap contract PASS. |
| FR13.1 ranked aggregate posture-risk/configuration | Evidence and configuration foundations implemented; educational terminology retained. | PARTIAL; no clinical risk, default policy or full live ranked leaderboard. |
| FR13.2 high-risk/tutorial gaps | Published-content gap projection and policy-gated attention linkage. | PARTIAL; real data/policy and full original acceptance unproven. |

UC13.2/3/8/9/10/11/12/13/14/15 and FR13.3/4 remain deferred/prototype as in A1; no matching, refresh-generation, send/dismiss or Member delivery is completed. Admin/Staff actor parity and original Chapter 3/4 manual/reactive/recipient conflicts remain explicit later decisions.

## Exact decisions still requiring approval / Batch B readiness

1. Purpose wording/data fields/notice versions and whether any retained history may be used; Member grant/revoke UX and current-state read model. Default remains off.
2. Trusted capture-time metadata and bounded scoped reader/query/index/migration design. Current v2 source cannot enforce history permission before reads and is therefore unavailable.
3. Which exact exercise/rule/model/view/mode policies are reviewed; sample sessions/days/attempts/coverage minimums, score-below thresholds, age/recency rules and aggregation meaning. Test values 60/68 and 2-session policies are not production approval; no universal 70 is activated.
4. Cohort cutoff, suppression/export/filter-differencing/longitudinal policy and authorized Admin/Staff visibility. No cutoff is chosen by default.
5. Retention/redaction for grants, receipts, configuration/consent audits, future pending leads/delivery and prior aggregates after revocation. No TTL, deletion job, 7/30/90-day retention or 14-day suppression period is activated.
6. Future callable/App Check/Auth composition, actual data readiness, media accessibility, privacy acceptance and selective release/UAT approval. No production reader/API/build is activated automatically.

**Batch B is not ready for real-Member or production processing.** The local contracts can support a separately authorized synthetic-only baseline/ranking proof of concept, but permission/data-source/privacy/threshold decisions must precede real recommendation generation. This task stops at the local A2 checkpoint; no Batch B code or provider request was started.

Local check metadata and exact source hashes: `build/module13-a2/verification.json`.
