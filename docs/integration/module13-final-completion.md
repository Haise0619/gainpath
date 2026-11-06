# Module 13 — final local evidence integration and UI preservation

2 November 2026, Malaysia. One integrated local completion checkpoint following A1–E. **The canonical synthetic workout-evidence → recommendation → Admin review → Member destination workflow works. Production remains disabled and NOT READY.**

## A. Completed functional integration

`createEvidenceDrivenQueueSource` now prepares queue inputs from persisted, consent-scoped workout evidence. It does not start from a compiled `LearningNeed`. It reuses `extractWorkoutEvidence`, the full existing backup validator/digest/owner checks, exact A1 compatibility and `aggregateExerciseEvidence`. A reviewed synthetic policy produces a typed allowed educational objective only after scored samples, dates, assessed attempts, coverage and recency qualify.

`deriveEvidenceLearningNeed(scope,batch,policy,window,now)` returns `derived` with the minimal need/evidence/provenance, or typed abstention: missing consent, policy unavailable/invalid, invalid source, unsupported exercise, incompatible scoring, insufficient/stale evidence or no guidance opportunity. No missing/null/unscored value becomes zero. No movement fault, diagnosis or injury likelihood is inferred. Exact compatible curl modes are supported through an additive internal `single_arm_curl` objective context; the registry/scoring engine is unchanged. Exercises without supported scored evidence cannot manufacture a low-form need.

The factory validates current enabled/verified synthetic identity and canonical purposes before policy lookup, again after that await, after extraction and at persistence. The source adapter independently revalidates current canonical membership, purposes/history and unchanged consent fingerprint in the same transaction as each payload read after the metadata query. The isolated source cannot read a revoked history merely to reject it afterward.

Existing B candidate eligibility, baseline, structured semantic ranking validation, controlled explanations and fallback are reused. Existing C Refresh leases/pages, generation summaries, durable receipts, review and Send/Dismiss remain; no automatic trigger is added. A server-only evidence binding is written atomically with each lead and revalidated before fresh detail, approval and delivery/current target access. It binds exact scope, derived need, sample summary, compatibility/policy/source versions, current extraction permissions, recency and candidate fingerprint.

Logical observation identity is separate from freshness: equivalent immutable session revisions and a shifted query window over the same sessions do not recreate sent/dismissed leads. Source/policy/permission changes still invalidate stale actions. Conflicting digests for the same immutable session are rejected, preserving A1. Binding validation survives a recreated source service; it is not an in-memory provenance claim.

Existing D controlled delivery creates the existing Notification Center projection and durable Member commands. Opening uses the current Coach profile or published instructional Routine exercise. It does not book/reserve/pay, enroll/change Programs, complete workouts or issue points. Receiving, read, acknowledgment and dismissal remain separate actions.

## B. Exact source changes and reuse

Paths below are relative to the repository; [verification.json](../../build/module13-final/verification.json) gives exact current hashes and preservation results.

| New source | Responsibility |
|---|---|
| `functions/src/modules/recommendation/evidence-learning-need.ts` | Typed attested batches, reviewed synthetic exercise policy, derivation/abstention and minimal provenance. |
| `functions/src/modules/recommendation/evidence-queue-source.ts` | Current-purpose source preparation, persisted evidence bindings, freshness validation and queue adapter. |
| `functions/src/modules/recommendation/recommendation-assessment-import.ts` | Import/reconcile actual future blind assessor forms and evaluate available baseline labels. |
| `functions/tools/module13-import-assessments.cjs` | Bounded offline import CLI; refuses overwritten/old B/E evidence destinations and any network inference. |
| `functions/test/evidence-learning-need.test.ts`, `evidence-queue-source.test.ts` | Known answers, compatibility/modes, null/insufficient/stale/invalid data, policy/consent races, forgery, revision and rolling-window deduplication. |
| `functions/test/recommendation-assessment-import.test.ts`, `recommendation-assessment-import-cli.test.ts` | Complete independent/blind forms, missing labels, adjudication and safe file handling. Automated test judgments are not human assessment results. |
| `functions/test/module13-final-integration.fixture.ts` | Canonical fictional accounts/catalog, actual valid backup wire records, SDK-bound capture reader, explicit test policy and existing B composition. |
| `functions/emulator/module13-final.test.ts`, `run-module13-final.cjs` | Same-lifetime source-to-client integration, security/Rules/replay/source-failure checks; isolated installed emulator only. |
| `functions/vitest.module13-final.emulator.config.ts`, `firebase/module13-final.emulator.test.json` | Dedicated demo project/loopback ports and final evidence output; no production index/Rules change. |
| `apps/admin_web/test/emulator/module13_final_admin_emulator_test.dart` | Actual Admin Insights, evidence-derived queues, protected detail and Send. |
| `apps/mobile/test/emulator/module13_final_member_emulator_test.dart` | Actual existing inbox/current Coach/tutorial routes and Member commands. |
| `apps/admin_web/test/module13_ui_preservation_test.dart` | Original tab/card/chart/rail presentation regression checks. |

Modified implementation: `recommendation-queue-generation.ts` (dynamic preparation, canonical trusted org, atomic provenance and deduplication); `recommendation-queue-security.ts` (canonical organization in explicit local composition); `recommendation-engine.ts` (canonical synthetic context); `recommendation-ranking-contracts.ts` (additive curl allowlist); `recommendation-target-resolver.ts` (trusted organization binding). Existing synthetic-org C/D/E compositions remain compatible.

Modified supporting tests/registry: `functions/test/recommendation-independent-evaluation.fixture.ts` explicitly freezes its original six exercise contexts so the existing **22-case/56-judgment** assessment package cannot expand when the application allowlist evolves; `functions/emulator/run-suites.cjs` and `functions/test/emulator-suites.test.ts` keep the new guarded test out of legacy core. The original B model ledger and evaluation artifacts are unchanged.

Modified presentation: the three existing Admin recommendation files `admin_recommendation_screens.dart`, `exercise_insights_panel.dart`, `recommendation_queue_panel.dart`. Operational entrypoints and the final implementation plan link this checkpoint. **No Mobile production source was changed in this task.** All unrelated Mobile work, Module2 pose/measurement behavior, Module12 metrics, Module6 behavior, booking/payment/Program/reward source, Firebase registration, Rules and production indexes are preserved.

## C. Original UI preservation

The original pre-A1 Admin screen is recoverable from Git `39e28fc`, not an invented mockup. Restored structures are equal-width desktop tabs; shared 380px wrapping Panel cards; purple target inset/icons; paired Send/Dismiss buttons; and the Insights score chart/numbered evidence cards with a desktop 3:2 content/rail arrangement. Narrow layouts stack/scroll using existing conventions. Shared Panel, StatTile, filters/dialogs and Syncfusion components remain. Protected details/actions and typed repositories are retained.

Necessary differences: educational terminology replaces unsupported High-Risk claims; nullable scores remain compatibility-separated; date/category/status/specialization filters, definitions, suppression, confirmations and truthful synthetic labels need more space than the former mock. The universal 70% slider, fake success/local list removal and fake content actions are not restored. Source/model metadata is tucked into details; IDs/fingerprints/tokens are not prominent. Existing tutorial icon fallbacks are used because the lead projection has no verified image field; no random media was inserted.

Member Notifications, Coach/Tutorial destinations, Barlow typography, themes, shell/navigation and Privacy hierarchy were inspected and preserved. Existing booking and gym-announcement cards retain their hierarchy. Prior additive recommendation category/detail and accessibility wrapping remain; no new full-screen redesign was needed. The normal privacy route remains an inactive default-off preview.

There are **27 fresh comparison/detail renders**: 12 recovered-source/current Admin at 1400/600px, eight recovered-source/current Notifications at 393/375px, enlarged text and landscape, and seven current recommendation detail cases. Source-reference images are newly rendered original code with equivalent fictional records, **not historical production screenshots**. Exact old production data cannot be recovered. Original/current Admin comparisons use the same local Arial font substitution; the actual Poppins/Inter Admin theme is untouched. Member comparisons use existing Barlow. Original and restored structures were visually inspected with no observed overlap/clipped controls; viewport crops are scrollable content.

| Comparable state | Recovered source reference | Current preserved/restored implementation |
|---|---|---|
| Trainer desktop | [1400px](../../build/module13-final/source-reference-trainer-1400.png) | [1400px](../../build/module13-final/restored-trainer-1400.png) |
| Content narrow | [600px](../../build/module13-final/source-reference-content-600.png) | [600px](../../build/module13-final/restored-content-600.png) |
| Insights desktop | [1400px](../../build/module13-final/source-reference-insights-1400.png) | [1400px](../../build/module13-final/restored-insights-1400.png) |
| Existing Notifications | [393px](../../build/module13-final/source-reference-notifications-393.png) | [393px](../../build/module13-final/preserved-notifications-393.png) |

Additional views: [Insights 600](../../build/module13-final/restored-insights-600.png), [Member enlarged](../../build/module13-final/preserved-notifications-enlarged.png), [Trainer 375](../../build/module13-final/trainer-375.png), [Tutorial landscape](../../build/module13-final/content-landscape.png). Exact comparison limitations/hashes are in [UI audit](../../build/module13-final/ui-preservation.md) and [render manifest](../../build/module13-final/ui-preservation-verification.json). These are Flutter widget renders, not staging/device screenshots.

## D. Actual end-to-end evidence

The dedicated project is `demo-gainpath-module13-final`, Firestore `127.0.0.1:18117`, test-only gateway `127.0.0.1:18118`. Every SDK read checks the effective installed project/host/port/TLS binding. The organization is canonical `gainpath` and the Squat ID is `F3b8xIr8ynBDd3gEICKX`; the production registry is not rewritten or aliased. Test Auth/App Check contexts are explicitly synthetic, not proof of real token/attestation verification.

1. Fictional active Member and peer receive four explicit v2 grants using a **synthetic-only retained-history notice** starting 40 days before the fixed 2 November fixture clock. It approves no real retained history.
2. Each has three valid session backups ending 30/31 October and 1 November UTC, estimated scores **58,62,66**, eight complete/two partial assessed attempts, eight tracked/two rejected seconds per session. An identical older revision is inserted; a poisoned 50-day-old payload remains outside the metadata query and is never fetched.
3. Capture metadata is queried by permitted half-open time range with limit101; more than100 refuses before payload reads. Each owner/key/digest/update/capture attestation binds the existing full validator. Distinct immutable sessions aggregate to **three scored sessions, three Malaysia dates, 30 assessed attempts, mean62 and coverage.8**. An identical revision contributes once; conflicting immutable digests fail.
4. Explicit synthetic policy `synthetic-squat-education`/`fixture-v1` requires three scored sessions/three days/30 attempts/.8coverage, seven-day recency and estimated score below65. These are test inputs, not approved universal or production values. They derive `{exercise:'squat',objective:'technique_foundations',level:'beginner'}` and actual bound provenance.
5. One Coach passes actual existing identity/credential/branch/roster/booking-slot/capacity checks, so Trainer ranking is honestly `deterministic_single_candidate` without a model call. Two published exact instructional tutorials pass actual existing contracts; a strictly structured **mock** semantic response runs through B validation/composition, with model label `synthetic-structured-mock-v1`. This request makes zero genuine Gemini calls. B's recorded genuine results remain separate historical engineering evidence.
6. Actual Admin widgets load positive descriptive Insights (six deduplicated sessions/two Members/mean62 under an explicit synthetic disclosure policy), Refresh both queues, assert real evidence fields, fetch current protected details and Send. Two durable leads/bindings produce **two PREPARED recipients and zero notifications before delivery**.
7. Controlled delivery/retry creates **two notifications/two delivery receipts**. Actual Member widgets open the existing current Coach profile and published tutorial; both read, Trainer acknowledgment and Content dismissal persist as **four Member command receipts**. Current Coach withdrawal removes the stale destination. Opening never invokes booking.
8. Repeated Refresh/commands do not duplicate recommendations; Send/Dismiss revision/concurrency behavior remains covered. Consent revocation before lookup reads zero histories; revocation during metadata await reads zero subsequent payloads. Policy/source/provenance drift blocks Send. Missing source data refuses the whole queue/Insights result. Direct client access to evidence bindings/policies/capture metadata and existing private records is denied by unchanged Rules.

Actual durable lead evidence, need, provenance, candidate/ranking outcome, RPC counts and delivery/navigation assertions are serialized from verified records in [combined-client-proof.json](../../build/module13-final/combined-client-proof.json), rather than claimed from hardcoded proof fields. Booking, payment, Program, workout/reward snapshots **and source backup/capture records** are unchanged across the connected workflow. Model payload tests exclude Member IDs, histories, metrics, session keys and source fingerprints; only allowlisted objectives and anonymous candidate evidence are sent to the injected mock.

## E. Focused verification and evaluation

| Fresh verification | Result |
|---|---|
| Backend A1–E/final, relevant Module12/backup/Coach/booking/content/chatbot | **752 passed,51 files** |
| Admin recommendations/Insights/UI preservation/Module12 reporting | **84 passed,10 files** |
| Mobile recommendations/consent/settings/notifications/booking/tutorial | **94 passed,12 files** |
| Shared booking/tutorial domain contracts | **11 passed,3 files** |
| Final canonical evidence-driven Firestore integration | **12 passed,zero skips**, including actual Admin and Member widgets |
| Prior C/D/E Firestore regressions | **21+19+5 passed**; two optional legacy isolated-client cases skipped; E reruns both actual clients together |
| Additional visual comparisons/detail renders | **27 passed**; seven consent renders are also included in Mobile94 |
| Source/test TypeScript no-emit; scoped Admin/Mobile analysis | Passed; scoped analysis no issues |
| Shared architecture and Admin/Mobile presentation boundaries | Passed |

Raw JSON/JSONL, successful process logs, selected files, hashes and environment are under `build/module13-final/`; [verification manifest](../../build/module13-final/verification.json) is authoritative. Counts overlap with independent review checks and render tests as stated; they are not added as independent samples. Earlier diagnostic failures are retained and are not final passing results. No APK/release build/deploy, dependency installation or unrelated full suite was run.

Independent review found and verified fixes for consent during awaited lookup, protected metadata-to-payload access, forged projections, equivalent revisions and rolling-window deduplication, and proof derived from actual stored records. Its [audit](../../build/module13-final/readiness-audit.md) also checked representative original/current UI renders. The final source preserves all nine historical B artifacts and its **18-request ledger**; no new provider request or budget reset occurred.

The original 22 held-out cases and two blank 56-judgment forms remain unchanged in meaning. The new importer accepts completed actual assessor forms, verifies exact packet identity/independent and blinded declarations, requires explicit independent adjudication for disagreements, and computes the available baseline metrics. Example: `node functions/tools/module13-import-assessments.cjs --assessment-a <completed-A.json> --assessment-b <completed-B.json> --adjudication <completed-adjudication.json> --output <new-result.json>` from repo root. Blank/incomplete forms refuse; files are bounded; B/E outputs and existing destinations cannot be overwritten. Synthetic software-test labels are never represented as human assessments. Held-out semantic/hybrid values remain null until separately authorized actual inference is available.

Baseline/semantic/hybrid Precision@1,Precision@3,nDCG@3, validity, fallback/abstention and provenance remain available through the existing evaluation contracts and historical B replay. The previous development result is not independent proof of superiority. There are no new measured Gemini latency/token/cost or independent human-performance claims in this checkpoint.

## F. Original requirement traceability

Original c3/c4 documents remain unchanged. All UC/FR numbers retain their original mapping. Exact c3 line references and implementation/test paths are in the [19-row audit](../../build/module13-final/readiness-audit.md); the current integrated verdict supersedes that audit's preliminary pending-run wording.

| Original requirement | Current local acceptance | Production/semantic limitation |
|---|---|---|
| UC13.1 High-Risk Exercise Leaderboard | PASS descriptive compatible Insights; PARTIAL clinical/high-risk meaning | Educational terminology; no clinical validation or approved real thresholds/disclosure. |
| UC13.2 Trainer Matching leads | PASS evidence-derived persistent queue/current detail | Actual real-data/candidate adapters and release blocked. |
| UC13.3 Content Recommendation leads | PASS evidence-derived published instructional queue | Actual curation/media/release blocked. |
| UC13.4 Category filtering | PASS existing compatible-group filters | Real aggregate release policy pending. |
| UC13.5 Configure threshold | PASS versioned reviewed-policy mechanism; PARTIAL original arbitrary numeric UI | No universal70/high-risk default; approved group-specific policy required. |
| UC13.6 Export leaderboard | PASS section/filter-specific suppressed CSV mechanism | Complementary/repeated-query disclosure review pending. |
| UC13.7 Content Gap Report | PASS actual catalog gaps; PARTIAL original clinical-risk linkage | Attention intersection needs approved policy. |
| UC13.8 Filter Trainer leads | PASS supported scoped/date/category/status/specialization filters | No invented severity. |
| UC13.9 Send Trainer recommendation | PASS evidence→Admin→prepared→inbox→current Coach | Open does not book/pay; real release pending. |
| UC13.10 Dismiss Trainer match | PASS audited revision/idempotency lifecycle | No production execution. |
| UC13.11 Filter Content leads | PASS typed scoped filters/pagination | Real indexed-query/privacy acceptance pending. |
| UC13.12 Send Content recommendation | PASS evidence→Admin→inbox→published tutorial | No Program/workout/reward mutation. |
| UC13.13 Dismiss Content lead | PASS audited kind-bound lifecycle | No production execution. |
| UC13.14 Manual Trainer refresh from workout evidence | PASS canonical validated evidence-derived need into B/C | Production source/capture/policy absent; no automatic trigger. |
| UC13.15 Manual Content refresh from workout evidence | PASS canonical validated evidence-derived need into B/C | No image-only instructional fallback. |
| FR13.1 Insights/configurable posture threshold | PASS local descriptive/configuration; PARTIAL clinical meaning | Real attention/disclosure policies unapproved. |
| FR13.2 Tutorial gaps for attention exercises | PASS coverage/policy-intersection mechanism | Actual approved attention meaning still pending. |
| FR13.3 Admin Trainer generation/approve/dismiss | PASS complete synthetic evidence-to-current-Coach workflow | Independent quality and real release pending. |
| FR13.4 Admin Content generation/approve/dismiss | PASS complete synthetic evidence-to-current-tutorial workflow | Independent quality and real release pending. |

Current services intentionally require literal Admin; original Staff parity is not implemented or silently expanded. Chapter3 manual generation/Member recipients are followed over Chapter4 reactive LeadEvaluator/CoachNotifier differences; educational terminology, organization-scoped records and these actor/flow amendments need academic/owner acceptance. The final c3 Markdown contains the Module13 Use Case Diagram caption but no embedded graphic; the available earlier Chapter3 PDF differs, so exact final diagram visual recovery is unavailable. Textual traceability remains intact.

## G. Production-shaped boundaries and exact release blockers

Prepared: bounded typed source/attestation and reviewed-policy interfaces; versioned purpose/configuration/queue/Member/read/delivery contracts; independently tested eligibility/ranking/validation; fresh identity/ownership and consent checks; safe errors/no partial aggregates; permanent disabled production facade. `enforceAppCheck:true` remains readiness metadata. The new canonical organization is not permission to process production data. No fixture gateway is registered/published and no request can select fixture activation in normal Firebase startup.

Missing actual Firebase integration: reviewed production trusted-capture writer/reader/query indexes and current policy/curation adapters; actual Auth/App Check callable wrappers/registration and live transports; signed-in staging/device acceptance. Existing legacy backups expose capture dates inside client-declared payloads, so upload time cannot establish historical authority. Old unattested histories remain excluded. A production source must refuse before payload access when it cannot enforce trust/purposes; synthetic attestations are not a migration strategy.

Owner/release decisions still required:

1. **Consent/history:** exact wording, notice/content versions, four independent purposes, allowed history start, retained-record trust/migration, regrant/revocation behavior and external-provider transfer terms. Camera/backup consent grants nothing here.
2. **Exercise policy:** each exact scoring/model/view/mode group's minimum sessions/dates/attempts/coverage/window/recency, threshold direction/value and allowed objective/experience-level authority. Synthetic65/three-days/.8/seven-days are not proposed production defaults.
3. **Aggregate disclosure:** cohort cutoff, compatible partitions, complementary suppression, bounded filters and repeated-query/CSV safeguards. The synthetic minimum2 is not a production privacy approval.
4. **Candidate curation:** Coach credentials/expiry limitations, expertise, branch/roster/capacity and current booking availability; tutorial compatibility/objectives/difficulty, publication, instructions and media/destination accessibility. Never relax eligibility to force a result.
5. **Lifecycle:** separate validity, leases/retries/idempotency and retention/redaction/access durations for consents/audits/configuration/policies, capture metadata, evidence bindings/provenance, runs/locks/leads/decisions/recipients/receipts/inbox. No retention period, TTL/deletion or backfill is activated.
6. **Evaluation and requirement amendments:** real independent assessors/adjudication; separate authorization if held-out Gemini measurements are wanted; acceptance of educational wording, Admin-only scope and manual flow differences. No clinical or general superiority claim.
7. **Release:** review actual source/composition and verified token/App Check enforcement; signed-in staging/browser/device/media/accessibility/performance UAT; fresh exact deployed package/environment/IAM/Rules/index/client baseline, selective deployment allowlist and rollback; explicit release authorization. This task authorizes no production access/deployment or APK action.

## H. Final verdict and local reproduction

**Complete local evidence-to-recommendation pipeline: YES**, in the isolated canonical synthetic environment, from real validated backup wire records rather than a compiled need. **Complete FYP engineering demonstration: YES**, with clearly labeled synthetic policy/data/mock inference and separate genuine historical Gemini replay. **Original UI: recovered structures restored/preserved**, with documented necessary functional/accessibility differences and honest recovered-source comparisons. **Production: NOT READY.** Important remaining work is the actual trusted real-data/callable/client composition, approved governance/curation, independent assessment and signed-in staging/device acceptance; it is not hidden by passing emulator tests.

All 14 local acceptance criteria pass within that runtime scope; criteria concerning original clinical meaning, exact historical screen data or production approvals retain the PARTIAL/BLOCKED qualifications above. No production record, real Member history, production service, billing/credential configuration, model ledger, posture algorithm or unrelated working-tree change was modified. No new paid Gemini request, deployment, release APK build/install, automatic LeadEvaluator or retention job occurred.

Reproduce the full connected local scenario from `functions` with `node emulator/run-module13-final.cjs --with-clients`, using installed cached SDK/JAR/Java/Flutter only. The runner removes explicit service-account and Firebase CLI token variables, uses the dedicated demo endpoint and writes final artifacts locally; ranking uses only an injected structured mock. Reproduce focused tests/typechecks using selected commands/files in the verification manifest. The engineering demonstration starts by inspecting the persisted synthetic backups and policy result, then shows derived provenance, B eligibility/baseline/validated mock ranking, Admin review, controlled delivery/current Member destinations and repeat/revoke/withdraw refusal. It does not present new mock inference as genuine Gemini evidence.
