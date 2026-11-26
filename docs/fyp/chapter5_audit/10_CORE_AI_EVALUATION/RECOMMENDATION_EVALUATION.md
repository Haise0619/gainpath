# 5.5.5.9 — Recommendation engine evaluation

**Objectives:** independently measure rule compliance, target validity, provider response validation, end-to-end delivery, and relevance. **Ground truth:** versioned eligibility and frozen destination fixtures for deterministic checks; independent assessor grades and adjudication for relevance.

## Historical observations

| Evidence | Actual result | Limit |
|---|---|---|
| November 18 standing calf raise controlled backup | Two candidates, 7,505 ms Gemini response and 235/95 input/output tokens. Strict validation produced `rule_fallback` with invalid provider output. Delivery after 13,225 ms, one Inbox item, real read model available. | This is a provider-output failure with successful fallback; precise cause was not attributable from retained output. `docs/integration/module13-final-gemini-acceptance-20261118.md:8–28`. |
| November 18 later single-arm curl controlled backup | Two Tutorial candidates, `gemini-3.5-flash-lite`; 629 ms provider, 227 total tokens, 4,301 ms backup-to-delivery, one Inbox item with receipt, matching first choice for baseline and Gemini. Actual signed-in Member resolve and authorized Admin detail validated; related Flutter widget navigation exercised. | One reviewed automatic result with compared two valid candidates and no first-choice change, generated from a controlled backup; not independent relevance or camera-based validation. `docs/integration/module13-gemini-output-fix-20261118.md:1–33`. |
| Earlier Batch B/E recorded development cases | 11 multi-candidate trainer/content cases; 10 validated semantic responses and one fallback. Same-eligible common n=10: Baseline/Semantic-only/Hybrid P@1 .800/1/1; P@3 .9333/.9333/.9333; nDCG@3 .6693/.9983/.9983. Overall final 33/33 structurally valid targets, but two final results carried provisional grade zero. | Provisional engineering labels, small designed fictional corpus and earlier 80:20 engine; no generalization, no automatically measured clinical performance. `docs/integration/module13-batch-e-ai-evaluation.md:17–23,43–79`. |
| Held-out preparations | 22 new fictional scenarios, 11 Trainer and 11 Content, frozen preparatory packets, no provider inference or human grades. Separately 18 mocked multiple-candidate cases exercise schema/fallback behavior. | No held-out score available. Mock fixtures establish structural behavior. `docs/integration/module13-batch-e-ai-evaluation.md:19–37,75–89`. |

[Abridged historical quantitative CSV](../evidence/evaluation_results/recommendation_historical_observations.csv) contains redacted actual checkpoint observations. It omits raw source identifiers and case-level ranking outputs.

## Measurements and pending execution

\(P@k=\frac{\text{relevant results in first k}}{\min(k,\text{eligible count})}\); use null on empty eligible sets. \(DCG@k=\sum_{r=1}^{k}(2^{g_r}-1)/\log_2(r+1)\), with nDCG relative to the ideal ordering over the same eligible candidates. Count fallback, ineligible target, zero eligible/abstention, consent denial, duplicate delivery, unsupported explanation and unavailable destination separately. Measure latency segmented into inference, decision, and atomic delivery. Statistical summaries should show sample sizes and missing values; repeated same-input model calls would be needed for consistency. Rule compliance success uses fixtures with explicit expected allowance/denial or eligible sets, and should not improve the model's relevance credit.

Fixture strata: unsupported/insufficient workout scores, revoked consent, expiring target, published unpublished pairs, Beginner filtering, exact Tutorial with same exercise, Routine with/without target exercises, published specialty and slot gaps for trainer, and duplicate/fatigue/expiry paths. Use existing pure contract tests and add separate controlled blinded assessment of each kind. Include provider refusal or malformed results without promoting a fallback to Gemini evidence. Controlled provider experiments require approval and privacy/budget review. Results of current audit test execution appear in the parent test report if run.

Relevant suites: `functions/test/recommendation-independent-evaluation.test.ts`, `recommendation-independent-evaluation-fixtures.test.ts`, `workout-recommendation-ranking.test.ts`, `workout-backup-recommendations.test.ts`, `recommendation-delivery.test.ts`, `recommendation-consent-v2.test.ts`.

