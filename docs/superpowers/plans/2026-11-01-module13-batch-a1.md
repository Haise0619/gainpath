# Module 13 Batch A1 implementation plan

**Authority:** owner's 1 November A1 instruction; the 31 October audit is planning context, not approval of its policy defaults.
**Goal:** typed, bounded, consent-aware, read-only Exercise Insights using synthetic tests only. No deployable export, production adapter, UI, recommendation engine, provider call or data mutation.
**Execution:** reuse the current checkout and preserve unrelated Mobile changes. No commit, merge or release is part of this task. Focused tests override the skill's generic full-suite suggestion.

## Tasks and interfaces

1. **Evidence extraction and consent contracts.** Add `functions/src/modules/recommendation/exercise-insights-contracts.ts`, `recommendation-consent.ts`, `workout-evidence.ts`. Reuse `validateBackupPayload`/`digestOf`; add compatibility classification rather than a second workout validator. Return typed internal evidence without using legacy accuracy as a form score. Keep null/unscored/unsupported distinct. Add deterministic fixtures/tests first.
2. **Read-only service.** Add `exercise-insights.ts` with an injected bounded reader and canonical Admin/fresh Auth/App Check guards. Accept only `{schemaVersion,organizationId,startAtMillis,endAtMillis}`. Read only current purpose-consented Member backups. Deduplicate immutable sessions and mutable routine revisions; do not turn routine/manual data into scored sessions. Return aggregate compatible groups/counts/provenance, never Member/session IDs, payloads or per-Member histories. No Firebase index export or live data adapter.
3. **Verification and documentation.** Known-answer extraction/aggregation, consent/auth/scope drift, dates, mode/version isolation, duplicates/conflicts/bounds/privacy and no-write tests. Run the new suites plus existing workout-report/backup contract regressions and no-emit typechecks; no unrelated suite or APK. Independent scoped review, resolve material findings, document contracts, complete all original UC/FR mappings and concise completion status. Update current operational references with the local-only boundary.

## Review focus

- A valid retained backup never substitutes for purpose consent; revocation during a scan invalidates its output.
- Mixed Member samples cannot satisfy a per-Member provisional minimum; unknown legacy modes/versions never merge with compatible scores.
- Duplicate sessions/revision copies cannot inflate scores; conflicting immutable sessions fail without partial totals.
- Invalid/future dates, out-of-window sessions and routine/manual records never become poor form scores.
- Injected source errors, unsupported metadata, or source identifiers cannot leak through the aggregate response or error messages.

## Policy boundary

Default `provisionalPolicy = null`; no attention/risk threshold, recency weighting, retention or outreach policy is activated. An optional server-injected provisional sample policy may test sessions/days/attempts/coverage; it is explicitly labeled and cannot be supplied by a client. Proposed consent schema is versioned and default-off, with distinct insights/generation/external-AI/delivery purposes. No writer or migration is implemented. Unsupported model versions remain excluded until explicitly registered; this does not imply poor performance.

## Progress

- Setup: inspected current validator, canonical reporting guard, registry, backup head/revision format and existing tests. No production reads.
- Task1 complete:39 extraction/consent tests pass. Typed projection reuses the existing validator; no Module12 change. Unsupported detector/rule/view/mode stays excluded, null and deliberately unscored remain distinct.
- Task2 complete:44 local handler/aggregation tests pass. Per-Member minimums cannot pool, duplicate revisions cannot inflate, current consent/auth/scope drift discards output, no private identifiers or source errors are projected. No Firebase export/adapter or policy default is added.
- Review focus correction before final review: coercible legacy curl mode arrays and score-with-zero-tracked-time failed new tests, then were excluded/rejected; unscored sessions now have a separate counter. Both suites green83/83.
- Task3 complete:181 focused tests pass (85 new A1 +96 existing), source and test no-emit checks pass separately. Contract/completion document and operational references updated.
- Final independent review: no critical/important findings; one malformed envelope-kind coercion was classified as a typed-contract defect and fixed with two failing-then-passing tests. No deferred code findings.
- Explicit scope decisions: production App Check wrapper/source completeness/deployed behavior remain unverified and unwired by the owner's A1 boundary; no atomic snapshot is promised. Wiring the handler without the later reviewed adapter/consent/transport gate would invalidate its production safety claims. No merge/commit/deployment/device action is performed in this batch.
