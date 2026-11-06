# Module 13 Batch A1 — Evidence foundation and read-only Exercise Insights

**Date:** 1 November 2026 (Malaysia). **Status:** implemented locally; synthetic-fixture verification only. No deployment, production reader, Admin UI integration, production consent/configuration write, model call or APK build/install.

## Delivered source

All new backend files are under `functions/src/modules/recommendation/`:

| File | Responsibility |
|---|---|
| `exercise-insights-contracts.ts` | Typed source, consent, compatibility, provisional sample policy, aggregate response, reader and dependency contracts. |
| `workout-evidence.ts` | `extractWorkoutEvidence(scope, row, now)` reuses the existing full backup payload/digest/ownership validator and projects typed internal session evidence. It narrows dates/identities/modes to the supported interpretation. |
| `recommendation-consent.ts` | `evaluateRecommendationConsent(raw, scope, now)`, independent versioned purpose evaluation; all purpose defaults off. No writer, grant endpoint or migration. |
| `exercise-insights-aggregation.ts` | `aggregateExerciseEvidence(...)`, pure compatible-group aggregation; per-Member means and explicitly injected sample-policy checks. |
| `exercise-insights.ts` | `exerciseInsightsHandler(request, dependencies)`, protected, bounded, read-only server handler. No registered Firebase export or production data adapter. |

Fixtures and known-answer/security tests: `functions/test/exercise-insights-fixture.ts`, `workout-evidence.test.ts`, `exercise-insights.test.ts`. Existing Module12, workout validator, backup transport, Firebase index, Rules, indexes and Mobile/Admin source are unchanged by A1.

## API design and activation boundary

Prepared local signature:

```ts
exerciseInsightsHandler(
  request: InsightsRequest,
  dependencies: ExerciseInsightsDependencies,
): Promise<ExerciseInsights>
```

Query accepts **only** `{schemaVersion: 1, organizationId, startAtMillis, endAtMillis}`. Dates are integer milliseconds, half-open `[start,end)`, end no later than scan start, maximum90-day window. Browser-supplied Member IDs, policy/thresholds and extra fields are rejected. The server dependencies supply a read-only-use `DocumentStore`, bounded organization/Member reader, current Auth identity reader, clock and optional provisional sample policy. Tests use only deterministic synthetic records and the existing in-memory store.

Current API status is **local handler/library, not reachable HTTP/Firebase API**. `functions/src/index.ts` is unchanged. Before future registration, a trusted `onCall` wrapper must enforce App Check, supply actual verified callable Auth/App Check context, and compose the reviewed source adapter/current Auth reader. Passing a plain `app` object to a unit-test handler is not cryptographic App Check validation. No real-history adapter is shipped in A1.

The handler reuses `authorizeAdminReport` for canonical organization/Admin/lifecycle authorization, and checks a fresh enabled/verified Auth identity, matching email and revocation cutoff. It rechecks authority before source pages and before output. Each participant must still have canonical active Member identity and unchanged purpose-consent/membership fingerprints at read boundaries and final verification. Scope/consent drift discards the result. It performs no transaction writes or external side effects; source/provider error messages are replaced with bounded public errors.

## Evidence extraction contract

`EvidenceRow = {id, data}` is a server-reader transport envelope. `id` is an ascending unique pagination cursor; `data` is the existing backup record (`schemaVersion`, `kind`, `id`, `key`, `digest`, `payloadJson`, `classification`, `updatedAtMillis`). A future reader should prefer canonical heads; if a supplied source includes revision copies, it must assign distinct stable cursor IDs. Neither cursor nor raw record is returned publicly.

Full source validation calls `validateBackupPayload(kind,id,org,member,payload)` and `digestOf(payload)` before use, including duplicate, unsupported and out-of-window copies. Malformed/missing form-score fields are invalid sources, not zero scores. Envelope integrity/owner/date failure produces a sanitized failed-precondition error with no partial aggregate. A future device session can be structurally valid but is excluded from activity; a future server envelope update is treated as source inconsistency. UTC timestamps support millisecond/microsecond serialization and reject rolled calendar dates.

Internal `SessionEvidence` retains dedupe identity/digest, session end/local Malaysia date, compatibility, estimated score/null, assessed full+partial attempts, tracked/rejected microseconds and coverage. Internal identities never cross the aggregate boundary. Routine checkpoints are validated and counted once as excluded source records; their embedded references/manual sets do not become form-score sessions.

Compatibility follows existing exact `gainpath` exercise/analyzer identities, current bundled detector `blazepose-tflite` / `mediapipe-full-e9a5c5cb-det-9ba9dd3d`, metric schema, scoring rule, view and mode:

- Scored: exact squat catalog ID `F3b8xIr8ynBDd3gEICKX`, standing single-arm curl, standing calf raise, wall push-up.
- Deliberately unscored: selected-arm row, selected-front-leg reverse lunge, front-view shoulder press and lateral raise. Their null score is not missing measurement or poor form.
- Curls retain `both`, `leftOnly`, `rightOnly` separately. Legacy schema-one curls with unknown mode are unsupported. Row/lunge retain selected side; front bilateral exercises retain `both`.
- Unknown exercise/rule/schema/model/view/mode is explicitly unsupported and counted by safe reason code, without echoing arbitrary source strings. Older/unregistered detector versions are not silently pooled; future support requires an explicit registered interpretation and tests.

This registry classifies evidence interpretation; it does not enable workout acceptance/rewards or validate physical/clinical accuracy. Legacy `accuracy:0` is never used as a substitute for `formScorePercent`.

## Aggregation and public contract

`ExerciseInsights` returns organization/query metadata, source classification/validator/timing/scan counts, coverage/exclusion counts, compatible-group aggregates, sample policy or null, and **`mode: descriptive_only`, `attentionThreshold: null`**. Source identifies a bounded non-atomic scan, not a database-wide historical snapshot. No Member/session IDs, revisions/digests, raw payloads, private source errors, per-Member samples or chronological histories are returned.

For each compatible group:

- Sessions, distinct Members, scored sessions, missing-score sessions, deliberately unscored sessions, assessed attempts and distinct recorded Malaysia dates.
- Mean Estimated Form Score = equal-weight mean of each Member's mean scored sessions; prolific Members do not dominate. No recency weighting or cross-rubric average is activated.
- Coverage = total tracked/(tracked+rejected); no observed denominator means null. This excludes unmeasured time and is not model confidence or validated accuracy.
- `evidenceState`: `unscored`, `no_scored_samples`, `policy_not_configured`, `insufficient_evidence`, or `meets_provisional_minimums`.
- `membersMeetingProvisionalMinimums` is null without a policy and for unscored exercises. With a policy it is computed separately per Member/group; pooling different Members cannot satisfy one Member's minimum.

Groups have deterministic identity ordering, **not severity ordering**. No risk/attention flag, cross-exercise risk ranking or individual recommendation is generated. `available` means descriptive aggregates exist; `no_consented_members` and `no_supported_evidence` distinguish absent permission from absent usable observations. Neither implies inactivity or poor performance.

Optional sample-policy fields are `schemaVersion`, `revision`, `minimumScoredSessions`, `minimumDistinctDays`, `minimumAssessedAttempts`, `minimumTrackingCoverage`. Every field must be supplied by trusted server composition. Only scored sessions meeting that session's coverage gate contribute to provisional sample sufficiency. The fixture policy (2 sessions/2 dates/15 attempts/0.7 coverage) is **a known-answer test input, not an approved scientific minimum, default or production setting**. No default sample policy or attention threshold is supplied.

Deduplication uses owner-scoped canonical record identity: identical immutable session head/revision copies count once; differing digests for one immutable session fail closed. Mutable routine revisions count as one excluded routine identity. Different Members may legitimately have equal local session IDs. Every scanned copy still counts toward cost bounds and is validated before deduplication.

Bounds:2,000 membership rows;200 canonical active Members;2,000 backup copies;16MiB payload JSON;251 membership/25 backup rows per page;90-day query window. Excess, oversized/nonascending pages and corruption fail without partial totals. These are query safety caps, not fitness thresholds. No live population is implied by them. Small-cohort suppression/reidentification policy still requires review before browser integration; removal of direct identifiers alone is not an anonymity guarantee.

## Proposed separate consent contract

```ts
{
  schemaVersion: 1,
  policyVersion: 'module13-purpose-v1-proposed',
  organizationId, memberId, revision,
  purposes: {
    exerciseInsights: false,
    recommendationGeneration: false,
    externalAiInference: false,
    recommendationDelivery: false,
  },
  grantedAtMillis: null,
  revokedAtMillis: null,
  updatedAtMillis,
}
```

Proposed future location: `orgs/{org}/recommendationConsent/{memberId}`. A1 defines the contract/evaluator only; synthetic tests inject explicit grants. Missing/unknown/invalid/foreign/future/revoked records fail off. Only a current valid `exerciseInsights:true` grant permits this service's backup reads. Other purpose flags cannot substitute. Camera acknowledgment, backup upload consent, Coach sharing and chatbot disclaimer are not accepted as this grant. Fingerprints stay internal and are rechecked before returning results.

Owner review is still required for wording, legal/purpose basis, permitted historical data window/retained backups, granularity, revocation/redaction, future retention and delivery/AI transfer. The proposed schema does not itself establish consent validity in production. No existing Member is opted in or migrated, and no Member consent UI is added.

## Known-answer and verification evidence

| Synthetic case | Required result |
|---|---|
| One Member, two compatible scores80/60 across two Malaysia dates | Mean70;2 sessions;20 assessed attempts;0.8 coverage; no active minimum/threshold. |
| Member A mean70; Member B mean100 | Equal-Member mean85, not session-weighted80. |
| Valid score0 | One scored session; mean0, no attention claim. |
| Null score | Null mean and `no_scored_samples`; missing field fails source validation. |
| Unscored row | Null mean;1 unscored session;0 missing-score sessions. |
| Three curl modes plus unknown rule/model | Three distinct groups; unsupported copies excluded/countable without raw metadata. |
| Session head+revision and three routine copies | One measured session, one excluded routine identity, three duplicate copies. |
| Conflicting immutable copies or corrupt duplicate | Failed precondition; no partial totals. |
| Two Members with one sample each | Cannot satisfy per-Member2-session test policy. |
| Missing/revoked/legacy consent | No history read; `no_consented_members`. |
| Consent/Admin/Member drift during scan | Output rejected, not stale data returned. |
| Invalid/future dates, half-open boundary, zero denominator | Invalid fails; future/out-of-window excluded; unknown coverage stays null. |
| Record/member/byte/page bounds and injected errors | Bounded failure with sanitized error, no private history or identifiers. |

Fresh focused command, from `functions/`:

```text
node node_modules/vitest/vitest.mjs run test/workout-evidence.test.ts test/exercise-insights.test.ts test/admin-workout-reporting.test.ts test/workout-backup.test.ts test/workout-backup-negotiation.test.ts --reporter=dot
```

Final result after independent review and correction: **181 passed** (85 new A1 +96 existing reporting/backup regression checks). Source and test TypeScript no-emit checks passed separately:

```text
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.test.json
```

The tests use no Firebase/emulator writes, paid API or live identities. No full unrelated suite/build/APK ran. Independent review found coercible array-valued envelope kinds: two regression cases first failed, then passed after requiring literal session/routine strings. There were no remaining material code findings. Production App Check enforcement, source-reader completeness and deployed behavior are unverified because no adapter/export exists. Atomic snapshot behavior is not promised: the result explicitly declares a bounded non-atomic scan. Independent review/final verification are recorded in the A1 implementation plan's progress section. Exact final focused-test output and check results are retained locally at `build/module13-batch-a1-20261101/verification.json`.

## Original requirement traceability

Originals remain unchanged: Chapter3 UC section6270–6745/Table3.33 (FR13.1–4), Chapter4 Module13 UI/sequence/Algorithm4.9.7 and lead/data designs. Original paths are in [the academic register](../archive/README.md#academic-source-register). Figure3.19's actual image was unavailable in the prior audit; A1 adds no visual-verification claim. The [31 October audit](C:/Users/Ngzhe/Documents/ChatGPT/GainPath/docs/superpowers/plans/2026-10-31-module13-audit-and-proposed-plan.md) retains the full evidence matrix and specification conflicts.

| Original UC | A1 contribution / remaining original obligation |
|---|---|
|13.1 High-Risk Exercise Leaderboard | Partial foundation: descriptive compatible insights under “Exercises Needing Attention”; no clinical risk, configured attention policy, complete ranked leaderboard or Admin UI. |
|13.2 View Trainer Matching Leads | Unchanged prototype; no real lead service in A1. |
|13.3 View Content Recommendation Leads | Unchanged prototype; no real lead service in A1. |
|13.4 Filter Leaderboard by Exercise Category | Date window service only; category catalog/filter UI deferred. |
|13.5 Configure Risk Threshold Parameters | No active threshold; proposed independent sample-policy contract only. Persistent threshold/config UI deferred. |
|13.6 Export Leaderboard Data | No export implemented in A1. |
|13.7 View Content Gap Report | Evidence foundation only; tutorial join/gaps deferred. |
|13.8 Filter Trainer Matching Leads | Deferred, no lead generation/filter changes. |
|13.9 Send Coach Recommendation to At-Risk Member | Deferred, no delivery/booking/points side effects. |
|13.10 Dismiss Trainer Match Suggestion | Deferred, no Admin decision mutation. |
|13.11 Filter Content Recommendation Leads | Deferred, no lead/filter changes. |
|13.12 Send Content Recommendation to At-Risk Member | Deferred, no delivery. |
|13.13 Dismiss Content Recommendation | Deferred, no Admin decision mutation. |
|13.14 Refresh Trainer Matching Queue | Deferred; no automatic trigger or matching. |
|13.15 Refresh Content Recommendation Queue | Deferred; no automatic trigger or matching. |
|FR13.1 Ranked exercise risk leaderboard/configuration | Partial evidence foundation only; scientifically unsupported clinical interpretation not asserted. |
|FR13.2 High-risk exercise/tutorial gap report | Deferred beyond evidence foundation. |
|FR13.3 On-request Member/available Coach pairings and decisions | Deferred. |
|FR13.4 On-request Member/relevant content pairings and decisions | Deferred. |

No full original UC/FR becomes PASS merely from A1. The existing Module13 UI remains neutral/unavailable. Manual backend versus reactive/client generation, Member recipient versus Coach recipient, score-versus-complement threshold direction and Admin/Staff scope remain explicit decisions for later approved work.

## Remaining blockers / decisions

- Real consent, data population/quality, physical score reliability and authenticated live behavior are not verified. The prior audit's live OAuth attempt failed; A1 does not attempt reauthentication or live reads.
- Approve purpose notice/contract including historical scope, current consent/revocation semantics and organization/Member governance before production data composition.
- Review any proposed per-compatible-group sample minima/coverage/recency/attention score threshold. No universal score70, minimum3-session rule, half-life or clinical-risk policy is activated.
- Decide small-cohort disclosure/suppression and retention separately; no7/30/90-day retention or14-day cooldown is installed.
- Production adapter, callable registration with enforced App Check/current Auth, indexes/Rules if needed, positive integration UAT and Admin UI require a later scope. No cross-Member browser access is granted.
- Gemini, ranking, Coach/tutorial candidates, LeadEvaluator, Send/Dismiss and Member delivery remain deferred.
