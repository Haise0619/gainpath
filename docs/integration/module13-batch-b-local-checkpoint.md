# Module 13 Batch B — integrated local checkpoint

**1 November 2026, Malaysia. Batch B is locally complete, including genuine synthetic Gemini inference.** This is one integrated milestone. No production recommendation processing, Member history read, consent/config activation, Firebase registration/deployment, lead/notification creation, booking/Program/reward mutation or APK build occurred. A1/A2 source hashes are preserved.

## Architecture and changed files

The internal pipeline is:

```text
explicit synthetic learning need + permitted fixture context
  -> current authoritative-shaped candidate eligibility
  -> deterministic baseline on that eligible set
  -> anonymous educational evidence projection / directive quarantine
  -> dedicated Gemini REST inference
  -> independent strict response validation
  -> class-preserving 40% baseline + 60% semantic ordering
  -> typed result + controlled explanations + provenance
```

New source files under `functions/src/modules/recommendation/`:

| File | Responsibility |
|---|---|
| `trainer-candidate-eligibility.ts` | Bounded read-only Coach identity/profile/credential/branch/booking/expertise eligibility, evidence and rejection codes. |
| `content-candidate-eligibility.ts` | Published instructional destinations, catalog/curation compatibility, evidence and content gaps. |
| `recommendation-ranking-contracts.ts` | Versioned learning need, candidate facts, anonymous request, evidence/reason codes, inference metadata. |
| `recommendation-baseline.ts` | Separate Trainer/Content experimental weights, unknown-aware normalization and stable ordering. |
| `recommendation-ai-validation.ts` | Anonymous labels, directive quarantine, full response schema and independent post-inference validator. |
| `gemini-recommendation-ranker.ts` | Dedicated server-side provider, existing key/model configuration pattern, verified structural schema, bounded REST/timeout/errors/usage. |
| `recommendation-engine.ts` | Synthetic-only composition, AI/fallback/abstention, final ordering and provenance. |
| `recommendation-candidate-service.ts` | Reusable Trainer/Content eligibility-to-ranking orchestration and trusted exercise mapping checks. |
| `recommendation-evaluation.ts` | Known-answer precision/nDCG, validity/fallback/order metrics and explicit price estimates. |

New verification: `functions/test/{trainer-candidate-eligibility,content-candidate-eligibility,recommendation-ranking,recommendation-engine,recommendation-candidate-service,recommendation-evaluation,recommendation-poc-budget,gemini-recommendation-ranker}.test.ts`, `trainer-candidate.fixture.ts`, and `recommendation-evaluation.fixture.ts`. New local tools: `functions/tools/module13-batch-b-{budget,poc,evaluate}.cjs`. This plan and the seven reading/operational references are updated. No package/dependency change was needed.

No A1/A2 backend/Admin source, Module 6 chatbot source, Coach/booking source, publication source, Module 12 metrics, workout measurement/scoring source, Functions index, Rules or indexes changed. Unrelated existing Mobile work remains untouched. No new Admin UI is activated: the normal A2 insights repository remains unavailable; persistent queues and actions are Batch C work.

## Trainer candidate eligibility

`evaluateTrainerCandidates(query, dependencies)` accepts schema/org/Member/exercise IDs, one allowlisted educational objective, level, one valid local booking date and a 30/60-minute duration. The injected repository lists at most 20 Coaches with a sentinel limit of 21; excess, duplicate, unsorted or invalid IDs fail closed. Source reads are bounded to 8,000 and 8 MiB across rechecked snapshots. No default Firestore reader exists.

Eligibility requires:

- Active canonical Member and Coach organization memberships; current Auth existence, enabled account and verified email; active organization.
- A valid currently published public Coach profile and allowed profile-photo ownership/path. The published snapshot is authoritative, preserving the existing separate draft/publication semantics.
- Current approved certification documents with matching Coach identity/storage scope and a consistent approval-state/public summary. This is deliberately conservative even while the existing directory's optional credential gate remains unchanged. The credential schema has no expiry/accreditation-validity fields: approval is not proof of an unexpired license or clinical competence.
- Shared published/assigned active branches, using existing `bookingCoachScope`.
- Explicit server-curated exact-exercise or reviewed expertise-to-exercise mapping, with matching educational objective and level. Bios, specialties and categories cannot manufacture this mapping. Missing mapping rejects rather than broadening the match.
- Current booking policy and `bookingDaySnapshot`: actual roster/day windows, advance horizon, leave/break exceptions, pending/confirmed slot locks, Member daily cap, cross-Coach Member conflicts and Coach daily capacity. Both half-hour slots must be free for a 60-minute option. Fewer bookings never implies availability.

The service performs two read snapshots with Auth/scope rechecks and rejects source drift without partial candidate results. External Auth and Firestore are not one atomic snapshot. Options are observations, never reservations. Output contains stable internal Coach IDs, validated unreserved options, profile/mapping/policy revisions, credential semantics, optional published years of experience and curated teaching focus. Names, raw bios, private booking notes and Member identifiers do not enter the provider projection.

Rejected candidates retain internal reason codes such as `coach_unavailable`, `credentials_invalid`, `unsupported_relevance`, `no_shared_active_branch`, `member_daily_cap`, `coach_daily_capacity` and `no_bookable_slot`. Source outages are safe errors, not fabricated empty catalogs.

## Content candidate eligibility

`evaluateContentCandidates(query, source)` uses the existing `exerciseVideos` catalog and published `content` Routine/exercise contracts, `exerciseTutorialProjection` and `tutorialMediaUrl`. The source is explicitly organization-scoped and bounded: 1,000 catalog records, 500 publications, 2,000 suitability rows/mappings each and 16 MiB JSON.

An eligible destination requires active/nonarchived source and target exercises; published/nonarchived/noninactive Routine; valid exercise/day/index/sets/repetitions; real supplied instructional steps or a supported direct instructional video; and a valid existing Member destination. An image-only entry, general description, invalid media URL, draft publication or unknown destination does not qualify.

Exact exercise matches are separate from explicitly directed curated compatible exercise mappings; shared categories alone never imply compatibility. A versioned suitability record binds publication digest and exercise index to supported objectives/levels. Missing or stale curation rejects. Optional difficulty/equipment remains unknown when absent; no per-exercise duration is invented from whole-Routine duration.

Output includes stable destination-derived internal IDs, instructional/difficulty evidence and an internal resolution contract:

```text
{kind: published_routine_exercise_tutorial,
 organizationId, routineId, exerciseIndex, exerciseId, dayNumber}
```

This mirrors the current Member screen contract; it is not a new registered deep link. Batch C/delivery must resolve the current authorized publication again before use. URL syntax does not establish media reachability or licensing. No eligible instruction returns `no_candidate` and `no_eligible_published_instruction`.

## Deterministic baseline and final ordering

Experimental weights sum to 100:

| Component | Trainer | Content | Meaning |
|---|---:|---:|---|
| Exercise/specialty fit | 35 | 50 | Exact mapping 1; explicitly curated compatibility .85. |
| Learning objective fit | 30 | 30 | Required reviewed mapping; unsupported objectives cannot enter. |
| Level fit | 10 | 20 | Trainer reviewed level; Content known same difficulty 1, another curated-supported difficulty .5, missing difficulty unknown. |
| Supported availability | 15 | 0 | At least one actually validated option, not low booking load. |
| Published experience | 10 | 0 | `min(years/10,1)` when supplied; general self-reported career experience, not independently verified exercise-specific expertise or quality. |

These engineering choices emphasize explicit educational relevance, keep availability a hard gate and use experience only as a small soft factor. Ten years is an experimental normalization cap, not an efficacy threshold. Missing optional components are `null` and excluded from the weighted denominator; known-component weights are renormalized. This avoids treating unknown as poor, but can make sparse candidates optimistic, so component coverage remains visible. All criteria/weights remain local experimental policies.

Exact-exercise class sorts before curated-compatible class in baseline and final output. Within a class, final score is `0.4 × baseline + 0.6 × validated semantic relevance`, then stable internal ID. Semantic scores can therefore change order, while eligibility/class boundaries remain outside model control. Neither score is a confidence probability, clinical risk or measured recommendation accuracy.

No eligible candidates or insufficient/unsupported/missing-permission fixture context produces explicit abstention. One eligible candidate returns `deterministic_single_candidate` without a provider call. Missing provider, timeout, rate limit, access failure, malformed/invalid output or unsafe semantic projection returns `deterministic_fallback`. Valid model abstention is retained; all-candidate abstention yields no recommendation.

## Gemini request, validation and privacy

The dedicated adapter reuses Module 6's existing named `GEMINI_API_KEY` integration, configured `GEMINI_CHAT_MODEL`/current default `gemini-3.5-flash-lite`, REST key-header pattern and bounded AbortSignal behavior. It does not invoke chatbot tools or modify chatbot prompts, modes or behavior. No new credential store, SDK, vector database or training pipeline was introduced.

Request schema1/prompt `module13-rank-v1` contains only kind, allowlisted objective/level/canonical exercise and per-request labels `C1…C20` with evidence refs such as `E1_1`. A server-only map resolves labels back to eligible IDs. The wire payload excludes org/Member/Coach/content IDs, names, raw history, pose/video, URLs, bookings, private goals and notes. Trainer context is an explicitly curated educational synopsis, never a raw bio; Content context is a bounded excerpt of currently eligible authored instructions. The same eligible sets and baseline facts are used for comparison.

The provider receives a basic OpenAPI structural schema and JSON MIME type. Rich JSON Schema and rich OpenAPI constraints returned HTTP400 in actual probes; the basic schema succeeded. The full strict schema is also supplied in the prompt and **always** independently enforced after inference. There is no automatic downgrade/retry during inference.

Response:

```text
{schemaVersion: 1, rankings: [
  {label, relevance: 0..100, reasonCodes: [...], evidenceRefs: [...], abstain: boolean}
]}
```

Exactly one entry is required for every eligible candidate. Unknown/missing/duplicate labels, nonfinite/out-of-range scores, unknown reasons, nonexistent or another candidate's references, unsupported code/reference combinations, extra JSON fields, malformed/oversized output and arbitrary explanations fail the entire AI response. Abstention requires score0 and empty reasons/references. Allowed reasons are `exercise_match`, `objective_match`, `level_match`, `available_slot`, `experience`, `instructional_focus`. Freeform assertions, clinical claims, medical treatment explanations and permission/booking instructions have no accepted output field. User-facing sentences come from controlled evidence templates.

Obvious role/directive/medical-instruction text is quarantined before inference; withheld evidence is unknown, without downgrading candidate eligibility or baseline features. If a candidate has no safe semantic evidence, inference is skipped and baseline retained. This is defense in depth, **not** a complete injection detector or proof of semantic truth. An earlier unquarantined synthetic injection received a high valid relevance score despite no business-rule bypass; that result is retained. The model can still misunderstand plausible descriptions. It cannot alter consent, IDs, eligibility, access controls or booking rules through these output contracts.

Bounds: 20 candidates, 12 evidence items/candidate, 480 characters/item, 16,000 request bytes, 2,048 output tokens, 131,072 provider-envelope bytes, 32,768 ranking-output bytes and 15-second full-operation timeout. POC token counting additionally enforces 6,000 input tokens. Safe errors omit provider bodies/secrets; local POC captures only bounded redacted diagnostic status.

## Genuine synthetic proof and evaluation

Artifacts are local under `build/module13-batch-b/`: `request-ledger.json`, `poc-results.json`, `contract-probe-*.json`, `evaluation-summary.json`, and `verification.json`. They contain fictional fixture results, not private records. The offline replay checks the **exact final provider request hash**, eligible IDs, recorded raw output and final ranking for every measured case. It does not make new provider calls.

**18 total generation attempts of the approved maximum20, concurrency1, zero automatic retries.** Three rich-schema attempts failed HTTP400; two successful contract probes established JSON/basic-schema behavior; eleven initial comparative cases and two injection-guard follow-ups completed. Earlier failures/outputs were preserved, not replaced with invented results. Across the recorded execution there were also 18 token-count requests and five model-metadata reads, separate from recommendation-generation attempts.

Configured model metadata confirmed `gemini-3.5-flash-lite`, version `3.5-flash-lite-07-2026`, `generateContent`/`countTokens`, input limit1,048,576 and output limit65,536. Existing secret access succeeded without displaying/storing its value. No alternate credential, login change or billing setting was used. Exact remaining project quota/billing tier was not available from metadata and was not changed; actual access/token counting and successful generation established availability for this small run, not future capacity.

The corpus contains 15 scenarios: five Trainer and six Content comparisons covering beginner/intermediate/advanced, multiple supported exercises/objectives, sparse text and injection; plus missing candidates, single candidate, inactive Coaches and missing permission controls. Labels0–3 and rationale were declared in fixture source before inference. They are provisional engineering judgments, not blinded independent human assessment. Positive relevance for precision means grade>0; grade1 is weak relevance, so precision is deliberately less discriminating than graded nDCG. Precision@3 is null when fewer than three results exist; empty/all-zero-ground-truth nDCG is null.

Final paired set (11 cases, using the two guard follow-ups; historical results retained separately):

| Measurement | Baseline | Final engine including fallback |
|---|---:|---:|
| Precision@1 | .8182 | 1.0000 |
| Precision@3 | .9394 | .9394 |
| nDCG@3 | .6658 | .9649 |
| Returned candidate validity | — | 100% |

- 10/11 model outputs passed validation; 1/11 fell back (9.09%). The advanced Trainer response contained unsupported `prescription`, correctly rejected. The earlier Content injection response also failed validation before the guard follow-up.
- 9/11 final orders changed. Trainer beginner baseline `[Coach1, Coach3, Coach2]` became `[Coach2, Coach1, Coach3]`; semantic scores95/80/60 put foundational instruction first. Content foundations likewise moved the specific technique tutorial from third to first, using the same eligible set. The intermediate Content case retained its existing order.
- Four control cases made zero generation calls: three abstentions (no candidates, inactive Coaches, missing permission) and one single-candidate deterministic result. No clinical or eligibility threshold was needed for these fixture decisions.
- Mean paired latency1,602ms; paired usage10,304 input and2,373 output tokens; estimated standard paid-rate generation cost **US$0.009024**.
- All15 generation responses with reported usage, including probes and earlier evaluated outputs, totaled14,366 input and3,359 charged output tokens, estimated **US$0.012707**. Attempts1/2/4 exposed no token usage: unknown charges are not asserted to be zero. No invoice/tier verification was performed.
- Published standard text pricing used for estimates: US$0.30/M input andUS$2.50/M output including thinking. Pre-run worst-case20×(6,000 input +2,048 output) estimate wasUS$0.1384. Metadata/token-count requests are separate from this generation estimate.

The designed small corpus demonstrates a real semantic-ordering contribution. It does **not** establish general AI superiority, statistical significance, production accuracy, medical benefit or clinical validity. Guard follow-ups are development iterations, not a held-out benchmark. Weak relevance/ambiguous descriptions and injection remain reasons for independent review before real use.

Mock-only failure checks separately cover timeout, HTTP429, malformed JSON and unknown labels, all yielding deterministic fallback. Their `inferenceMeasurement` is `mock`; they supply no claimed provider tokens/cost/latency. Network timeouts/rate limits were simulated, not induced against the real service.

Official references checked 1 November: [configured model](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite), [legacy GenerateContent structured output](https://ai.google.dev/gemini-api/docs/generate-content/structured-output), [token counting](https://ai.google.dev/api/tokens), [pricing](https://ai.google.dev/gemini-api/docs/pricing), [project-dependent rate limits](https://ai.google.dev/gemini-api/docs/rate-limits). Actual configured-model behavior, not documentation alone, determined the final schema adapter.

## Verification

Fresh final focused run: **571 tests across30 suites**, including118 new Batch B tests, A1/A2 validation/aggregation/configuration/consent/privacy regressions, Module12 reporting, backup compatibility, existing Coach management/profile/roster/availability/booking/options, published Routines and Module6 chatbot/callable behavior. Both source and test TypeScript no-emit checks passed. A2's15 recorded source hashes match exactly; protected source paths/Functions index/Rules/indexes have no new diff. No Flutter source changed in B, and no full build/APK/unrelated suite ran.

Independent review reproduced array-valued enum coercion in eligibility class/provider kind/context. Regression tests first failed, then passed after literal string checks. It also identified semantic injection as a limitation; obvious directives were quarantined, safe-empty projection fallback tested, and the two changed provider payloads were checked with real synthetic calls. No remaining material review finding is known. Review does not establish deployed behavior, real App Check/Auth attestation, current live catalog completeness or booking availability.

Reproduce without network:

```text
cd functions
node node_modules/vitest/vitest.mjs run test/trainer-candidate-eligibility.test.ts test/content-candidate-eligibility.test.ts test/recommendation-ranking.test.ts test/recommendation-engine.test.ts test/recommendation-candidate-service.test.ts test/recommendation-evaluation.test.ts test/recommendation-poc-budget.test.ts test/gemini-recommendation-ranker.test.ts --reporter=dot
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.test.json
node tools/module13-batch-b-evaluate.cjs
```

The real runner requires explicit `--run-real`, only the existing named credential and durable budget lock. It skips already recorded final cases and refuses duplicate reserved attempts; do not delete/reset its ledger to repeat paid experiments. No more real requests are needed for this checkpoint. Failed/interrupted reservations remain consumed. A corrupt ledger/stale runner lock fails closed rather than being automatically cleared.

## Exact Batch C contracts and remaining gates

Batch C can consume these internal TypeScript exports:

```text
evaluateTrainerCandidates(query: TrainerCandidateQuery, dependencies)
evaluateContentCandidates(query: ContentCandidateQuery, source)
baselineRankCandidates(candidates: readonly RankingCandidate[])
rankRecommendationCandidates(need: LearningNeed, candidates, options: RankingOptions)
recommendTrainerCandidates(need, query, dependencies, options: CandidateRecommendationOptions)
recommendContentCandidates(need, query, source, options: CandidateRecommendationOptions)
```

The orchestration returns `{schemaVersion:1, eligibility, rankingCandidates, ranking}`. `eligibility` includes internal rejection/evidence/destination facts (null when permission/evidence stopped before reading); `ranking` contains baseline components/order, AI scores/reasons/references, final entries, origin, model, prompt/schema/ranking policy, validation/fallback, quarantined-evidence count, latency and tokens. These are server/internal contracts, not a browser transport or ready-made persistent lead document. Batch C must design a safe reviewed view and persistent audit/decision lifecycle without exposing histories.

The current composition **only** accepts `mode:synthetic_local`, `datasetId:module13-batch-b-v1`, organization`synthetic-org`, an explicit synthetic exercise mapping and a fixture evidence-status assertion. This assertion does not establish actual A1 sample sufficiency or Member consent. Default-off A2 consent and permanently false production activation flags are unchanged. No production wrapper may relabel real data as a fixture to bypass them.

Before real processing or delivery, the owner still must approve/resolve:

1. Purpose-specific insights/generation/external-AI/delivery notices, current identity/organization/role authority, explicit grants/revocations and historical scope. Camera/backup/chatbot consent never substitutes. Revalidate authority/purpose consent and candidate facts after inference and before persisting or acting on any future result.
2. A1/A2's trusted capture-time-scoped backup source, scoring compatibility/sample policy and actual data quality. Existing legacy reader cannot enforce v2 history scope before reads and remains blocked. No universal70, clinical High-Risk rule, evidence minimum or production threshold is installed.
3. Authoritative pedagogical exercise/objective/level curation and compatible-exercise policy; credential expiry/qualification meaning, factual expertise and experience quality; current complete directory/catalog/roster/media availability. Synthetic maps are not production policy.
4. Aggregate cohort/filter/export disclosure rules; individual queue access and minimum necessary data; external-provider fields, privacy terms, region, retention/training/billing/quota review. Quarantine is not a general injection/privacy guarantee.
5. Consent/configuration/audit/receipt/lead/AI trace retention, revocation/redaction/deletion and history reuse. No retention duration/TTL/cooldown is activated by B.
6. A separately authorized current-Auth/App Check/organization-scoped production composition, safe errors and snapshots, idempotent persistent queue commands and selective UAT/release. No callable is registered here; no Send/Dismiss, automatic LeadEvaluator, notification, paid booking or Program change is implemented.

Original Chapter3 UC13.1–15/FR13.1–4 and Chapter4 Algorithm4.9.7 remain unchanged. [A1's complete traceability matrix](module13-batch-a1-evidence-and-insights.md#original-requirement-traceability) and [A2's presentation/configuration coverage](module13-batch-a2-local-checkpoint.md#original-requirements-coverage) remain authoritative for those checkpoints. B adds the local candidate/ranking foundation to UC13.2/3/14/15 and FR13.3/4; actual queues, refresh persistence, Admin approval/dismissal and Member delivery remain incomplete original obligations. UC13.8–13 and full FR13.3/4 acceptance are not marked PASS by this engine. Chapter3's on-request generation versus Chapter4's reactive trigger conflict remains a later explicit decision; no trigger is installed.

**Ready for separately authorized local/synthetic Batch C Admin queue integration: yes. Ready for real-Member processing or production release: no.** The complete local Batch B milestone stops here.
