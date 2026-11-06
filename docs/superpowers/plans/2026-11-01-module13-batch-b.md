# Module 13 Batch B integrated implementation plan

> **For agentic workers:** Use executing-plans for integration and parallel agents for the independent candidate services. This is one Batch B milestone, with no B1/B2 approval boundary.

**Goal:** A synthetic-only, reusable Trainer and Content eligibility/ranking engine with a genuine bounded Gemini proof, honest evaluation and deterministic fallback.

**Architecture:** Existing coaching booking validation and published tutorial projections remain authoritative. Separate candidate services feed a common strict ranking projection, experimental baseline, anonymous Gemini structured request, independent validator and stable ranking composition. No Firebase registration, persistence or production composition is introduced.

**Tech stack:** Existing TypeScript, Node fetch/AbortSignal, Vitest; existing GEMINI_API_KEY secret integration and configured Module 6 model, without changing chatbot behavior.

**Spec:** Owner's full Batch B request (1 November 2026), original Chapter 3 UC13.1–15/FR13.1–4 and Chapter 4 Algorithm 4.9.7; A1/A2 completion reports.

## Constraints and decisions

- Entire batch authorized locally; no additional implementation approval. Keep current checkout to preserve existing A1/A2 and unrelated uncommitted Mobile work.
- Synthetic fixtures only. No Member histories, consent migration/defaults, leads, notifications, bookings, rewards, deployed Functions/Rules/indexes or builds.
- Existing directory metadata does not authorize exact educational fit. Versioned curated mappings must supply that fact explicitly; missing optional evidence stays unknown.
- AI request contains allowlisted objective/level/exercise context, anonymous labels and bounded public educational evidence. No internal IDs, Member data, URLs, bookings or freeform goals.
- Exact exercise eligibility class precedes curated compatible class. Within a class use 40% baseline + 60% validated semantic relevance, stable ID tie-break. These are experimental engineering weights.
- No candidate: abstain. One candidate: baseline without provider. Invalid/unavailable AI: deterministic fallback, no retries.
- Real POC: existing configured credential only; at most 20 generation attempts total with durable reservation ledger, concurrency 1, bounded tokens and timeout. Stop on auth/quota/payment/access failure. No alternate credentials or billing changes.

## Review focus

1. Booking eligibility uses actual capacity/locks/roster, never low booking count; test full/leave/branch/credential failures.
2. Content destinations and instructional media come from current publication contracts; test image-only/unpublished/missing destinations.
3. Model cannot add candidates, cross eligibility classes or produce arbitrary explanations; test duplicates/unknown/extra fields/unsupported references.
4. Injection text is untrusted data, not executable instructions; controlled reason codes and evidence templates constrain displayed output.
5. Provider failures preserve baseline and usage provenance; test timeout/rate-limit/malformed/oversize, and distinguish real-model evidence from mocks.

## Tasks

- [x] Candidate services: read originals/current source, write failing synthetic tests, implement independent bounded Trainer/Content services, run focused eligibility checks. Files: `trainer-candidate-eligibility.ts`, `content-candidate-eligibility.ts`, corresponding tests.
- [x] Ranking contracts and baseline: typed need, eligible candidate facts/evidence, deterministic unknown-aware weighted rankers, controlled explanations. Files: `recommendation-ranking-contracts.ts`, `recommendation-baseline.ts`, focused tests. Demonstrate ties/input permutation/missing evidence and exact-class precedence.
- [x] Gemini and validator: versioned schemas, anonymous labels/evidence references, bounded REST adapter, safe failure/usage/latency. Files: `gemini-recommendation-ranker.ts`, `recommendation-ai-validation.ts`, tests. Validate strict output independently, no tools or freeform assertions.
- [x] Engine and evaluation: integrate both eligibility contracts, synthetic-only execution gate, baseline/AI/final provenance and abstention. Reproducible independent provisional labels and precision/nDCG/validity/fallback metrics. Files: `recommendation-engine.ts`, `recommendation-evaluation.ts`, fixtures/tests.
- [x] Genuine POC: verify official model/schema/pricing docs, existing credential and model availability, bound expected cost; run durable-budget synthetic harness if accessible. Record actual output/usage/latency and incomplete blockers honestly. No mock inference counted as real.
- [x] Review and checkpoint: independent code review, correct findings, focused A1/A2/coaching/content/chatbot/Module12 regressions, source/test no-emit checks, update operational references and final report. No deployment/commit required.

## Progress

- Read A1/A2 completion reports, original requirements, existing Module 6 REST and named secret configuration. Module 6 currently defaults to `gemini-3.5-flash-lite`; no local environment key or Gemini overrides were present. Model documentation supports structured output; per-project quotas/billing require actual access verification.
- Parallel Trainer and Content agents own disjoint files and tests; coordinator owns ranking/provider/evaluation.

- Final checkpoint: 571/571 focused tests across 30 suites (118 new Batch B), source/test no-emit checks and exact A2 source preservation passed. Independent enum-coercion finding fixed with red/green regressions; directive quarantine and safe-empty fallback verified. No remaining known material finding.
- Genuine POC completed: 18/20 total generation attempts, concurrency 1; rich-schema failures, basic-schema probes and guard follow-ups retained. Final 11 paired cases: 10 valid outputs, 9 order changes, 1 fallback; 4 no-call controls. Offline exact-request-hash replay passed. No further provider requests or production actions performed.
- Ruling: verified basic provider structural schema plus strict independent local schema is used because rich constrained schemas failed HTTP400. This preserves every local validation rule; it does not promise model-semantic truth.
- Completion report: docs/integration/module13-batch-b-local-checkpoint.md. Ready only for separately authorized local/synthetic Batch C integration.
