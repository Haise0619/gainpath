# Module 13 Batch C — integrated local checkpoint

**1 November 2026, Malaysia. Locally complete: persistent Admin queues, Refresh, review, Send/Dismiss and audit workflow, using synthetic fixtures and an isolated Firestore emulator.** No production recommendation processing, registration/deployment, real Member data, notifications, Gemini requests, booking/Program/workout/reward mutation or APK work occurred. Batch B's completed source/evidence and 18-attempt budget remain preserved.

## Implemented architecture and files

The existing three-tab Admin hub remains: Exercise Insights, Trainer Matching, Content Recommendations. A2's insights panel is unchanged. The queues now use typed async repositories and server-owned records rather than prototype lists that removed cards and announced fake sends. Normal signed-in composition uses an unavailable queue repository. Synthetic mode requires deliberate repository injection and a visible label.

```text
Admin Refresh -> current Admin/App Check boundary -> explicit synthetic manifest
 -> current Member/purpose checks -> existing Batch B eligibility and ranking
 -> final source/consent/authority checks -> transactional page of leads + run receipt

Admin Send/Dismiss -> current authority + expected revision + idempotency receipt
 -> current Member/target validation for Send
 -> atomic lead + decision audit + receipt + prepared recipient record
```

New backend files under `functions/src/modules/recommendation/`:

| File | Responsibility |
|---|---|
| `recommendation-queue-contracts.ts` | Strict versioned leads, targets, run summaries, queries, receipts and recipient draft contracts. |
| `recommendation-queue-security.ts` | Default-off synthetic composition, current verified Admin/session/canonical role and independent Member-purpose checks. |
| `recommendation-queue-generation.ts` | B result conversion, bounded leased Refresh/continuation, stable business deduplication, safe renewals and run/page provenance. |
| `recommendation-queue-reader.ts` | Bounded ordered list, server filters/counts/facets, safe summary projection and final authorization recheck. |
| `recommendation-lead-decisions.ts` | Revision-safe Send/Dismiss/blocked lifecycle, actor-bound receipts, immutable audits and atomic prepared recipient records. |
| `firestore-recommendation-queue.ts` | Explicit emulator-only SDK reader; verifies actual project, endpoint and TLS configuration. |

One narrow A2 extension: `recommendation-consent-v2.ts` accepts an optional fifth purpose argument, defaulting to the original `exerciseInsights`. It reuses the complete existing schema/notice/history validator; default-off semantics and existing command behavior are preserved. No production notice, grant, migration or policy changed.

Admin source: new `application/recommendation_queue.dart`, `recommendation_queue_repository.dart`, `presentation/admin/recommendation_queue_panel.dart`; updated `admin_recommendation_screens.dart`. The old Bloc seed-list/queue CSV/fake-action implementation is removed from this hub. Queue export is absent, consistent with the original lead use cases.

Verification additions include seven backend queue/adapter/integration test files, two synthetic fixture helpers, consent-purpose regressions, `emulator/module13-c.test.ts`, `run-module13-c.cjs`, dedicated Vitest/Firebase test configs, two Admin queue test suites/support fixtures and `test/emulator/module13_queue_emulator_test.dart`. Existing emulator-suite discovery explicitly keeps C on its isolated runner. The seven operational reading references and implementation plan are updated.

## Persistence and schema

All proposed paths are organization-scoped:

| Path under `orgs/{org}/` | Purpose |
|---|---|
| `recommendationLeads/{leadId}` | Unified discriminated Trainer/Content review record. |
| `recommendationRuns/{runId}` and `/pages/{position}` | Request/input fingerprint, progress, cumulative summary and immutable page response. |
| `recommendationRefreshLocks/{kind}` | Expiring per-type lease with unique worker token. |
| `recommendationGenerationState/{kind}` | Latest safe generation summary for the UI. |
| `recommendationCommandReceipts/{actorCommandHash}` | Idempotent decision result bound to actor and exact command. |
| `recommendationDecisionAudits/{actorCommandHash}` | Immutable prior/new state, revisions, actor, reason and time. |
| `recommendationRefreshAudits/{refreshHash}` | Immutable record of a safe stale/expired/revoked/pending renewal. |
| `recommendationRecipients/{recipientRecommendationId}` | Durable prepared recipient recommendation plus Notification Center-compatible draft; not actual delivery. |

A unified collection reuses one authorization/state/receipt pipeline while validated target types preserve Coach and published tutorial semantics. This intentionally adapts the original `TrainerMatchingLead`/`ContentRecommendationLead` designs to the current organization architecture rather than creating top-level cross-organization collections.

Schema1 leads contain stable ID/org/intended Member, type, exercise/objective/level, minimal authorized display labels, validated target, minimal evidence, controlled reason/explanation codes, ranking origin/model/prompt/algorithm/fallback, source and Member-consent fingerprints, run ID, creation/expiry, status/revision and optional decision. Missing measured evidence stays null. C's persisted engine fixture explicitly states no real workout history was processed; semantic relevance is never presented as Estimated Form Score or confidence.

Trainer targets bind Coach, branch and observed unreserved option times. Content targets use B's actual `published_routine_exercise_tutorial` destination `{organizationId,routineId,exerciseIndex,exerciseId,dayNumber}`. No URL, destination or profile fact is invented. The supplied integration fixtures contain authored instructions, without a media preview URL; the UI shows text details and does not fabricate images.

Parsers reject unknown/private fields, wrong organization/type, unsupported enum values, invalid timestamps/metrics, inconsistent terminal decisions and corrupt generation/receipt shapes. No raw histories, pose/video, booking notes, unrestricted prompts/responses, tokens or private profile payloads enter Admin lead records.

## Refresh, ranking and deduplication

`createRecommendationQueueGeneration(deps)` accepts schema/org/type/command ID and nullable continuation. The trusted source is an explicitly compiled C fixture manifest, never a client-supplied Member catalog. B's `synthetic_local` restriction is retained; C does not relabel real data or recreate its engine.

Each run supports at most 20 needs, two needs/page, a 60-second worker lease, run-bound position cursor and exact page receipts. Stable request fingerprints bind source/config versions, validity policy and manifest. A lease token is checked again before commit, so an expired worker cannot overwrite its successor. Concurrent Refresh admits one worker; identical completed pages replay without generation. Source/auth failure is distinct from no-match and marks the run failed; no lead from a failed page is committed. Previously committed pages are explicit run progress, not a claim that the entire run completed. The test target validator refuses Send from an incomplete/failed run.

Insights + recommendation-generation permission are required. External AI is independent: with that permission off, the source invokes B without a provider and deterministic ranking remains available. C only injects mock/recorded synthetic inference; no provider credential is resolved or request made. Consent is rechecked after ranking before persistence. A2's receiving permission is additionally checked at Send, and inference-used leads require the inference purpose again.

Stable business keys bind org/Member/type/exercise/objective/source fingerprint. Another Refresh of unchanged valid input does not duplicate a pending lead. Sent and dismissed leads remain suppressed for the same input. A current re-evaluation can renew stale/revoked/expired records, or a pending record with changed consent fingerprint, **at the same lead ID and incremented revision**, with a separate refresh audit. The original creation time is preserved; expiry, current evidence/target/run and permission fingerprint are renewed. A stale UI decision therefore conflicts rather than overwriting the renewal. No arbitrary cooldown is introduced.

Generation summaries contain processed/candidate/generated/abstention/fallback counts, run/type/status/cursor, last observed model, algorithm version, timestamp and safe failure code. Aggregate abstention counts distinguish insufficient evidence, unsupported evidence, missing consent, no eligible candidates and semantic abstention, with validated totals. A model that abstains still retains its model provenance. No raw model body is retained.

Listing scans at most 100 leads, using ascending document IDs and bounded source pages; result pages are at most 25 and date windows at most 90 days, with Malaysia calendar conversion in the UI. Excess/corrupt sources fail instead of returning partial counts. Counts apply the active date/exercise/category/specialization predicates across statuses; pagination then applies status and ID cursor. Facets come from the bounded same-kind source. Pages are not an atomic cross-request snapshot: reload for newly inserted records or changed filters.

## Durable lifecycle and Admin UI

Core lifecycle: `pending -> sent | dismissed`, with explicit `expired | stale | revoked` refusal states. In C, **sent means prepared locally**, not Member delivery.

Send requires current verified Admin/session/canonical organization, matching pending revision, valid dates, current Member identity and purpose grants, unchanged permission fingerprint, a completed source run and current eligible Coach/tutorial. It rechecks the exact observation/destination through the B-backed test source. Source errors abort with safe errors and no partial writes. Expired/changed/revoked inputs are recorded as blocked without a recipient. Future-created leads are refused.

Successful Send atomically writes the lead revision/status, decision audit, command receipt and stable recipient record. The UI reports success only after that transaction returns. A recipient collision aborts all writes. Two Admin sends or Send/Dismiss against the same revision produce one durable winner. Identical retries replay the actor-bound receipt; changed commands/old revisions conflict. Receipts describe past operations, not current delivery eligibility.

Dismiss requires a meaningful trimmed 8–300-character reason and records actor/time/reason. It remains available for a pending record whose Member/target permission has since disappeared, without reading private histories or requiring a new consent grant. Sent/dismissed history retains its decision label after validity passes. Pending expiry is presented as unavailable until refreshed/reviewed.

Trainer and Content panels provide pending/processed/unavailable metrics, Malaysia 7/30/90/custom dates, status/exercise/category filters, Trainer specialization filters, stable pagination, visible Refresh/continuation, review details, Send confirmation, reason dialog and accessible persisted success/error/conflict feedback. Details show supported Coach specialty/branch/observed unreserved option or current tutorial destination, evidence limitations and AI/fallback/single-candidate origin. IDs are transport references, not prominent display text. Loading, unavailable, empty/no-candidate, insufficient evidence, consent-withheld, fallback, stale, busy and conflict states are exercised.

Unknown/lost Refresh responses retain their command ID for idempotent retry. A confirmed failed run found on reload clears that ID/cursor so a new Refresh can recover. Relative date endpoints advance on reload after generation, while pagination retains its original window. Filters, transport responses and decisions are guarded against account/repository drift; controls disable conflicting actions while work is pending.

## Actual emulator and UI evidence

Fresh final verification:

- **640 backend tests across 37 suites**, including 69 added C/purpose cases and all selected A1/A2/B, Coach/booking/publication/chatbot/Module12 regressions.
- **67 Admin tests across 9 suites**, including 29 new queue DTO/repository/widget checks plus A2/shared-composition/Module12 regressions.
- **22 actual Firestore emulator checks, zero skipped**, including one nested **Flutter widget-to-HTTP-to-Firestore workflow**. The widget refreshes Trainer/Content queues, confirms Send and Dismiss, and the test verifies one recipient, two decision audits and zero notifications in the real emulator.
- Source/test TypeScript no-emit checks passed; focused Flutter analysis found no issues; Admin presentation boundary passed.
- Four desktop/narrow synthetic renders passed and were inspected: [Trainer desktop](../../build/module13-c/trainer-1400.png), [Trainer narrow](../../build/module13-c/trainer-600.png), [Content desktop](../../build/module13-c/content-1400.png), [Content narrow](../../build/module13-c/content-600.png). They use existing local substitute fonts and injected fixture records, not signed-in browser screenshots.

The isolated project is `demo-gainpath-module13-c`, Firestore loopback 18111, with optional fixture gateway loopback 18112. The SDK guard checks actual project/servicePath/port/TLS, not an environment flag alone. CLI preferences are isolated and inherited credential-file/token settings removed. Tests seed fictional current Coach/credentials/rosters, published instructions and purpose records, then call the actual B eligibility/ranking composition against persisted source reads. Fictional Auth/App Check context is explicit; it does not prove real token verification/attestation.

Actual emulator cases include no candidates, all abstention categories, source/consent drift during inference, current target withdrawal, request/recipient conflicts, concurrent Refresh/Send/Dismiss, revoke/regrant followed by stale refusal and revision 3 renewal, expiry renewal, cross-org denial and checked-in Rules denial for lead/run/lock/state/audit/receipt/recipient paths. The existing Rules file was tested without modification; this is not a deployed-Rules verification claim. The static fixture gateway header grants no production authority and is not a production authentication design.

Reproduce the combined workflow with `cd functions; node emulator/run-module13-c.cjs --with-admin-ui`. The source fixtures use a declared November1 clock/November2 coaching observation for deterministic backend cases; the optional gateway uses runtime timestamps for UI queries. No real Member scheduling availability is asserted. The separate widget unit suites use fixed clocks and no network.

Independent review found failed-Refresh recovery, stale/expired renewal, processed-status expiry labeling and missing abstention taxonomy; all were corrected with failing-then-passing regressions. Additional checks cover corrupt page-receipt privacy fields, independent AI opt-out, future-created leads and contradictory terminal states. No remaining known material finding is recorded. No unrelated full build, APK, provider experiment or production acceptance test ran.

Raw local evidence: `build/module13-c/emulator-results.json`, `emulator-integration-evidence.json`, and `verification.json`. All 23 B source/document hashes match; B's ledger remains 18 attempts. Its completed evaluation artifacts are unchanged. A1 extraction/aggregation, B engine and A2 Insights are preserved; only the documented purpose-evaluator/hub extensions and isolated harness accounting change those earlier integration surfaces.

## Exact Batch D delivery contract

`RecommendationRecipientRecord` in `recommendation-queue-contracts.ts` is the server-owned handoff. Stable `recipientRecommendationId` is the logical recommendation idempotency key. It contains org/Member/lead, type, validated target, creation/expiry, `status:prepared`, null Member-read/acknowledged/withdrawn times and `notificationDraft`.

The draft follows the existing org notification envelope: schema 1, type `recommendation`, recipientId, recommendationId, controlled title/message, createdAtMillis and read:false. **C writes neither `orgs/{org}/notifications` nor a Member feed.** Batch D must resolve this record through current authorized server logic, validate expiry/current Member/consent/target and then atomically prepare the existing Notification Center entry plus a delivery receipt keyed by the same recommendation ID. A notification cannot be treated as read or accepted merely because an Admin prepared it.

Batch D must implement:

1. Verified Member Auth/App Check, current active canonical organization and ownership; never accept another recipient ID from the browser as authority.
2. Independent receiving/generation/insights and, where relevant, inference-purpose policy revalidation. Handle revocation and stale targets before exposing or navigating a suggestion.
3. Current published Routine/index/exercise/day resolution for Content; current Coach directory/branch/availability for Trainer. Opening a suggestion is not a booking or Program change.
4. A separate idempotent delivery receipt and notification ID; separate unread/read state and optional acknowledgment. Neither implies purchase, booking or acceptance of advice.
5. Defined expired/withdrawn behavior: unavailable navigation/message, no automatic resurrection, and reviewed handling of existing notifications/records after revocation. Retention/redaction is still an owner decision.

No Member read/write API, production Rules overlay, notification worker or navigation route is enabled by C.

## Original requirements and remaining gates

Original documents and numbering are unchanged; [A1's full matrix](module13-batch-a1-evidence-and-insights.md#original-requirement-traceability), [A2 coverage](module13-batch-a2-local-checkpoint.md#original-requirements-coverage) and [B engine record](module13-batch-b-local-checkpoint.md) remain linked.

| Original requirement | C evidence / acceptance boundary |
|---|---|
| UC13.2 /13.3 queue views | Persistent B-derived Trainer/Content queues, filters/details and actual UI-to-emulator verification pass locally. Real-data/signed-in operational acceptance remains partial. |
| UC13.8 /13.11 filters | Type/date/status/exercise/category/specialization behavior passes. No unapproved risk-severity classification; original clinical/risk and Staff parity obligations are not silently waived. |
| UC13.9 /13.12 Send | Atomic prepared recipient/decision/receipt/audit passes. Original Member notification/receipt obligation remains partial until D; not marked complete from a widget or draft alone. |
| UC13.10 /13.13 Dismiss | Durable bounded reason, revision race/idempotency and same-input suppression pass locally; live actor/UAT acceptance remains pending. |
| UC13.14 /13.15 Refresh | Secure manual, bounded, leased, resumable B generation with provenance/dedup/abstention/failure states passes locally. Production source/policy remains disabled. |
| FR13.3 /13.4 | Local queue/decision foundation implemented and emulator verified; complete original acceptance remains partial because actual Member delivery, reviewed real sources and release/UAT are absent. |

UC13.1/4/5/6/7 and FR13.1/2 retain A1/A2 status. Original Chapter3 on-request generation is followed for C; Chapter4's reactive LeadEvaluator is not activated. Admin-only authority is implemented; broadening to original Staff actors requires an explicit authorization decision.

Remaining gates: trusted capture-time-scoped histories and compatible evidence readiness; approved minimum evidence/attention policies; purpose-specific notice/grant/history scope and revocation policy; authoritative pedagogical curation/current credentials/media; aggregate cohort and individual queue disclosure policy; external-AI privacy and real-purpose approval; retention/deletion/redaction for leads, runs, leases, receipts, audits and recipient drafts; production Auth/App Check composition, selective release and signed-in UAT. The fixture's one-day recommendation validity and seven-day maximum engineering bound are **not** production retention/expiry approval. No TTL/deletion/cooldown/default threshold/default consent is installed.

**Batch C is locally complete and ready for separately authorized local/synthetic Batch D implementation. Production processing and actual Member delivery remain disabled.** This task stops at the local C checkpoint.
