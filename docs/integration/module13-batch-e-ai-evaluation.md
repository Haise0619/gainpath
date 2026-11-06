# Batch E independent AI evaluation

Status: **local evaluation preparation complete; independent human review and held-out provider inference await review/authorization.** No new live-model performance is claimed. No provider requests, credentials, real Member histories, consent changes or production operations were used.

## Implementation plan

Authorized local implementation uses the writing-plans and test-driven-development skills. The user explicitly authorizes continuous implementation without intermediate approval. This scoped plan covers only evaluation; the Batch E coordinator owns integration and full requirement traceability.

- [x] Add failing known-answer tests for effective-K metrics, empty/invalid targets, sample denominators, stability and independent assessor/adjudication validation.
- [x] Implement isolated evaluation utilities without changing Batch B's engine or historical metrics.
- [x] Prepare reproducible held-out Trainer/Content cases using the unchanged real eligibility services with fictional source fixtures; never inherit provisional Batch B labels.
- [x] Add a network-free generator that verifies and reads recorded Batch B evidence, produces separate development comparisons, and emits blinded blank independent assessor/adjudication forms.
- [x] Verify focused regressions and both source/test TypeScript no-emit checks; document exact evidence and remaining human/provider gates. The coordinator also owns final integrated verification.

Review focus: fewer-than-three and empty sets; missing labels versus grade zero; fabricated/duplicate targets; disagreement without invented adjudication; historical development evidence confused with held-out inference.

## Evidence classes and data isolation

1. **Historical development evidence:** Batch B genuine recorded Gemini outputs on designed fictional cases, including development guard follow-ups. Original provisional engineering labels are retained. This is evidence of a real semantic contribution, not independent generalization.
2. **Offline replay:** Batch E recomputes eligibility from unchanged B fixtures, verifies exact eligible ID order and labels against recorded records, checks final provider request bytes against the durable ledger SHA256 through an injected local transport, and revalidates/replays recorded structured output. Baseline, validated semantic-only order and final hybrid order share the same eligible sets. Hard eligibility improvements are never attributed to Gemini.
3. **Held-out preparation:** 22 new fictional scenarios, 11 Trainer and 11 Content, have never received provider inference or human relevance labels. Their deterministic preparation uses the actual existing eligibility services with in-memory credential/roster/booking contracts and published Routine/curation contracts. It creates no alternate eligibility rules. Existing engine context remains explicitly synthetic-only; the new evaluation dataset is identified separately in scenario IDs and frozen assessor packet.
4. **Mock checks:** 18 multiple-candidate cases exercise accepted structured responses and malformed-response fallback through the real engine. Mock scores are arbitrary structural test inputs. They have no reported relevance metrics, provider latency, tokens or cost, and establish no Gemini performance.

Every file currently in `build/module13-batch-b/`, including its request ledger and original evaluation summary, is hashed before and after generation. The reproducibility test also independently checks those hashes. B source, recorded evidence and the 18-attempt ledger are unchanged. All23 entries in B's original `verification.json.sourceSha256` match the current files. Ledger SHA256 remains `89cf223ae3ba0158b555071f82829c548474ef63290abe09d4dbc62f9cc7e054`; POC-results SHA256 remains `4ec3ef200a6dc5fe5c9c2bb5df12ad2c96b479e3b6c901c49801ccae8678b1d0`. The generator never imports the POC runner/budget reservation, resolves secrets or invokes its network transport; global fetch fails closed during generation. It accepts no command-line flags and writes only `build/module13-e/evaluation/`.

## Held-out corpus and independent assessment

The 22 cases cover all six supported movements (`squat`, `wall_push_up`, `reverse_lunge`, `shoulder_press`, `single_arm_row`, `calf_raise`), all four objectives, beginner/intermediate/advanced, ambiguous descriptions, sparse descriptions, adversarial instructions, no-candidate controls and single-candidate controls. Each route has nine three-candidate cases, one empty case and one single-candidate case: **56 candidate judgments per assessor**, 112 judgments total. Candidate-empty cases are structural abstention controls with no invented relevance grade. Synthetic catalog/roster facts are not proof of live catalog quality, Coach qualification or actual availability.

The reproducible labeling package includes:

- `assessor-packet.json`: neutral case/item IDs, educational need and candidate evidence, with stable seeded order independent of rankings. It contains no actual source IDs, scores, AI order, baseline order or provisional grades.
- `assessor-rubric.json`: explicit criteria/instructions below.
- `assessor-A.blank.json` and `assessor-B.blank.json`: separate independently completed forms, initially null grades/empty rationales and false independence/blinding declarations. Completed forms must be copied to separate files. Modified blank forms are protected against generator overwrite.
- `heldout-custodian-key.json`: private source-to-blind mapping. Custodian must withhold this file, provider input fixtures and evaluation summaries from assessors.
- `adjudication.blank.json`: the explicit distinct-human adjudicator contract. It contains no suggested judgment.

The scale is **0: no usable relevance/contradictory or directive evidence; 1: weak/generic or ambiguous relevance; 2: relevant movement/objective with plausible level suitability and indirect details; 3: direct, specific movement/objective evidence and clear level suitability.** Rationale must address movement, objective and experience level, explaining missing evidence. Assessors may assign identical grades or all zeros; they must not force a winner or follow adversarial text. Precision uses grade>0, so grade1 counts as weak-positive; graded nDCG is more discriminating.

`validateAssessment` requires exact schema/rubric/packet SHA256, complete unique item coverage, integer grades0–3, bounded nonempty rationale and explicit independent/blinded attestations. Missing grades remain missing, never zero. `reconcileAssessments` requires different assessor identifiers and records disagreement without averaging. Disagreement yields `awaiting_adjudication` with no resolved labels until a distinct adjudicator provides exactly the disputed IDs, grades and rationales. Agreement is reported with its candidate denominator. Software attestation cannot prove actual human independence/qualification; custodian verification is required. No forms have been completed and no independent judgments are asserted.

Before any held-out outcome is examined, freeze fixture/provider-input/packet hashes, predeclare the rubric and analysis, have two independent assessors complete blind forms, preserve original judgments and record adjudication. Record assessor qualifications/relationship to the developer and any amendments. Keep the labels private until outputs are frozen; do not tune prompts against this corpus and still call it held out.

## Recorded development comparison

The latest recorded B version provides 11 multiple-candidate cases (five Trainer, six Content) and four non-inference controls. All11 request hashes and recorded baseline/AI/final outputs replay exactly. One advanced Trainer response fails the existing strict validator and remains deterministic fallback; semantic-only order is unavailable for that case.

| All recorded paired cases | Baseline (n=11) | Validated semantic only (n=10; one unavailable) | Final hybrid including fallback (n=11) |
|---|---:|---:|---:|
| Precision@1 | .8182 | 1.0000 | 1.0000 |
| Precision@3 | .9394 | .9333 | .9394 |
| nDCG@3 | .6658 | .9983 | .9649 |
| Valid returned target rate | 1.0000 | 1.0000 | 1.0000 |
| Grade0/ineligible returned-item rate | .0606 | .0667 | .0606 |

Unequal semantic denominators above must not be used as an unconditional three-way improvement claim. On the **common valid-semantic subset n=10**, baseline/semantic/hybrid P@1 are .8000/1.0000/1.0000; P@3 are .9333/.9333/.9333; nDCG@3 are .6693/.9983/.9983. The hybrid includes deterministic components and exact-exercise class priority; semantic-only sorts accepted relevance descending with stable ID tie-breaking. Model abstentions remain removed. Per-kind sample counts and metrics appear in the generated summary.

Valid target rate is an eligibility-ID check, not relevance or therapeutic correctness. The grade0/ineligible rate is an explicitly defined unsupported-recommendation relevance proxy: two of 33 final returned items have provisional grade0 (6.06%); it does not audit the truth of every generated assertion. No independent claim-truth/clinical assessment is available.

| Operational recorded measurement | Observed denominator and uncertainty |
|---|---|
| Model-output validity | 10/11, .9091; descriptive Wilson95 .6226–.9838 |
| Fallback | 1/11, .0909; Wilson95 .0162–.3774 |
| Valid final targets | 33/33, 1.0000; Wilson95 .8957–1.0000; targets are clustered within scenarios |
| Required structural-control abstention coverage | 3/3, 1.0000; Wilson95 .4385–1.0000 |
| All-scenario abstention fraction | 3/15; separate from coverage of known abstention controls |
| Recorded latency | mean1,602.09ms, n11, range1,170–2,314ms, descriptive SE119.00ms |
| Recorded paired tokens | 10,304 input, 2,373 candidate-output, n11 observed; per-metric missing counts retained |
| Estimated paired generation cost | USD0.0090237 total, meanUSD0.00082034/request, n11; historical B rates only |
| All observed historical generation usage | 15 responses with usage across18 attempts; 14,366 input/3,359 charged output including thinking; failures1/2/4 have unknown usage/charges |
| Stochastic ranking stability | unavailable: no repeated validated outputs with identical request/model hashes; guard follow-ups changed payloads |

Means expose n, missing count, min/max and descriptive standard error. Zero observations yield null rather than perfect performance; single-observation SE is null. Wilson intervals are illustrative binomial summaries with explicit denominators; designed non-IID cases/clustered candidates do not justify population confidence claims or significance. B cost estimates use its historical USD0.30/M input and USD2.50/M charged output assumption, excluding metadata/countTokens. No current pricing, billing tier, invoice, failed-request charge or future quota is verified. Latency is historical synthetic-request latency, not Batch E measurement or production SLA.

## Metric contracts

Precision@3 uses `relevant(first3) / min(3, eligible count)`. If two candidates are eligible and only one relevant item is returned, it is1/2; unreturned slots are penalized, not removed. Eligible-empty P@1/P@3 are null; abstaining despite eligible relevant candidates scores0. nDCG uses `(2^grade−1)/log2(rank+1)`, ideal over all eligible candidates and a maximum of three positions; zero ideal relevance yields null. Duplicate returned/eligible IDs and incomplete/out-of-range labels are rejected. Unknown/forged targets earn no relevance and are counted invalid. Valid-target rate is null for empty output. Unsupported relevance rate is null when labels are absent or no items are returned.

Independent quality is null for every held-out case. Ranking stability requires fresh repeats with identical model/prompt/input/config; tests expose pairwise exact order agreement and top3 Jaccard with a comparison count. Empty-vs-empty repeats agree structurally, but one observation supplies no stability estimate. Replay determinism is separately proven by byte-identical generator outputs and exact historical replay; it is not stochastic-model stability.

## Separately approvable provider experiment

`heldout-provider-inputs.json` contains the 18 exact anonymized multi-candidate payloads; `proposed-provider-experiment.json` binds their projection hashes and proposes **three generations each:54 total, concurrency1, zero automatic retries**, 6,000 input-token/2,048 output-token caps, at most18 countTokens requests and one metadata read. Single-candidate/empty controls need no inference. Projected generation maximum at historical B rates is **USD0.37368**, excluding metadata/countTokens and unknown failed-request charges. This is a proposal, not authorization/current-price confirmation or execution.

A new experiment requires separate owner authorization, current model/pricing/budget verification, approved provider/privacy terms, frozen independent labels/fixtures and a distinct durable request ledger; it cannot reset/reuse B's ledger. Generated payloads share the same eligible facts for baseline/semantic/hybrid and contain no real histories. Report repeated outcomes, failures and uncertainty, preserve original outputs and lock all analysis before unblinding. No script in this deliverable performs that future experiment.

## FYP explanation and limits

Module13's existing design combines upstream AI-derived workout observations (estimated, compatibility-bounded educational evidence), deterministic authorized eligibility, actual Gemini interpretation of bounded candidate educational text, strict independent output/schema/ID validation, deterministic hybrid ranking/fallback, human Admin review and Member control over any subsequent navigation/booking action. In this evaluation only fictional learning needs/source facts were consumed. Recorded semantic scores genuinely changed ordering on unchanged eligible sets; B's recorded development evidence establishes that contribution. Validation establishes contracts, not independent human relevance. The independent relevance package remains awaiting actual assessors and authorized inference. Semantic ranking is not clinically validated injury-risk prediction.

This deliverable supports the AI-ranking/evaluation evidence for UC13.2/UC13.3/UC13.14/UC13.15 and FR13.3/FR13.4 without rewriting original requirements or establishing full runtime/production acceptance. The Batch E integration/traceability report owns the complete UC13.1–15/FR13.1–4 matrix.

## Verification and exact changed files

Red: seven metric/assessor behavior tests first failed against unimplemented exports; a packet-binding regression failed before packet hashes were added. Fixture/generator tests first failed because their new implementation was absent. Green: **127 tests in11 focused suites pass**, including all nine new checks and118 unchanged Batch B eligibility/ranking/engine/provider/evaluation/budget regressions. The generator runs twice under a deliberately unusable API-key environment and produces byte-identical summaries, leaves B file hashes unchanged and fills no labels. No build/release or real-data operation ran.

Fresh source and test TypeScript no-emit checks both pass independently with exit0. An earlier source check observed an in-progress callable SDK typing error in the coordinator's file; the coordinator corrected it before these final passing checks. No errors originated from these evaluation files. The coordinator owns the final integrated checkpoint verification.

New tracked-source candidates (no existing files modified):

- `functions/src/modules/recommendation/recommendation-independent-evaluation.ts`: denominator-aware pure metrics and uncertainty/stability summaries.
- `functions/src/modules/recommendation/recommendation-independent-evaluation-labels.ts`: blinded frozen packets, assessor validation and explicit adjudication.
- `functions/test/recommendation-independent-evaluation.fixture.ts`: unlabeled held-out source fixtures through actual eligibility.
- `functions/test/recommendation-independent-evaluation.test.ts`: metric/assessment known-answer and invalid-input tests.
- `functions/test/recommendation-independent-evaluation-fixtures.test.ts`: deterministic actual-eligibility/source isolation checks.
- `functions/test/recommendation-independent-evaluation-generator.test.ts`: child-process offline replay, protected-evidence and output-reproducibility checks.
- `functions/tools/module13-batch-e-evaluate.cjs`: offline generator only.
- `docs/integration/module13-batch-e-ai-evaluation.md`: this protocol/results record.

Generated ignored artifacts live only in `build/module13-e/evaluation/`: summary, blind assessor packet/rubric, two blank forms, separate custodian key, blank adjudication contract, held-out provider payload fixtures and proposed experiment budget. Do not share the whole directory with assessors.

Reproduce locally from `functions/`:

```text
node tools/module13-batch-e-evaluate.cjs
node node_modules/vitest/vitest.mjs run test/recommendation-independent-evaluation.test.ts test/recommendation-independent-evaluation-fixtures.test.ts test/recommendation-independent-evaluation-generator.test.ts test/trainer-candidate-eligibility.test.ts test/content-candidate-eligibility.test.ts test/recommendation-ranking.test.ts test/recommendation-engine.test.ts test/recommendation-candidate-service.test.ts test/recommendation-evaluation.test.ts test/recommendation-poc-budget.test.ts test/gemini-recommendation-ranker.test.ts --reporter=dot
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.test.json
```

The exact source fixtures and algorithm are checked into source; generated evidence is ignored local output. No genuinely independent human evaluation, fresh held-out live inference, signed-in staging UAT, physical-device UAT or production recommendation availability is asserted.
