# Module 13 Batch C integrated implementation plan

> **For agentic workers:** Use executing-plans for integration and independent parallel agents for lifecycle/security and Admin UI. One local milestone; no intermediate approval checkpoints.

**Goal:** Persistent synthetic/emulator Admin recommendation queues with B engine generation, bounded refresh, truthful review/Send/Dismiss and durable audit/recipient preparation.

**Architecture:** Reuse existing DocumentStore/FirestoreStore, canonical Admin guards, A2 purpose consent evaluator, B candidate/ranking exports and Admin three-tab shell. New organization-scoped leads/runs/leases/receipts/audits/recipient drafts. Normal app repository unavailable; explicit local transport injection only. No production registrations or provider calls.

**Tech stack:** Existing TypeScript/Vitest/Firestore emulator, Flutter shared GainPath panels and tests. No dependencies/builds/APK.

**Spec:** Full attached Batch C instruction (1 November), original Chapter3 UC13.1–15/FR13.1–4 and Chapter4 lead designs; A1/A2/B checkpoint reports.

## Decisions and review focus

- Unified leads collection is justified by shared states, revision/receipt/audit semantics and type filters; discriminated validated targets preserve Coach/publication semantics.
- `sent` means durable prepared local recipient record only; no actual notification or Member receipt. Expiry is configurable synthetic validity, not a production retention policy.
- Reuse B without touching completed B evaluation artifacts/budget or calling Gemini. Explicit mocked semantic inference and deterministic fallback are labeled locally.
- Admin Auth/AppCheck trusted context + canonical org/account checks precede reads and writes. Member purpose grants/identity, current target and source fingerprints are rechecked before mutations.
- Durable request/page receipts, per-kind lease tokens, stable business keys and expected revisions prevent duplicate generation/Send/Dismiss races. Failing page commits no partial leads.
- Bound source manifest <=20 synthetic needs, generation pages <=2 needs, list source <=100 leads, page <=25, date <=90 days; continuation binds run and position. Limits fail closed.
- Review stale async responses/account drift, cross-org cursors, receipt collisions, partial-page source failures, revoked consent during inference, concurrent decision conflicts, and real datastore transport substitution.

## Tasks

- [x] Inspect current contracts/originals, read original notification architecture, establish strict shared lead/query/run/receipt/recipient types and failing validation tests.
- [x] Lifecycle agent: purpose evaluator extension (existing default preserved), synthetic/default-off security helpers, durable Send/Dismiss/blocked states, CAS/receipts/audits/recipient preparation; red/green focused tests.
- [x] Coordinator: B engine conversion, stable business deduplication, bounded leased generation/continuation/failure reporting, safe list/filter/facets API and fixture/emulator adapter; red/green focused tests.
- [x] UI agent: typed transport repository, default unavailable normal mode, responsive Trainer/Content panels, filters/pagination/details/actions/confirmations/errors and scope guards; focused Flutter tests/analysis.
- [x] Actual isolated demo emulator: seed fictional real-shaped Coach/publication/consent sources, test current authoritative B generation and durable races/receipt atomicity/org/client-write denial; no live project.
- [x] Review, focused A1/A2/B and Admin regressions, TS/Flutter checks, desktop/narrow fixture screenshots, exact source/artifact preservation and completion/D contract report.

## Progress

- Existing Admin prototype depended on Bloc seed data and removed cards on fake Send; replacement removes that dependency and keeps A2 Insights unchanged.
- Existing org notifications use server-owned transactional receipt/inbox documents. C prepares an explicit recommendation recipient/draft contract without writing notifications or claiming Member delivery.
- User direct execution authorization supersedes extra design approvals; preserve current checkout/unrelated Mobile changes and stop at local C checkpoint.

- Final: 640 backend/37 suites, 67 Admin/9 suites, 22 actual emulator checks (zero skips) including one real Flutter HTTP-gateway workflow pass. Source/test TypeScript and scoped Flutter analysis clean; four final synthetic renders inspected.
- Review fixes: terminal failed refresh recovery, revision-safe stale/expired/revoked renewal, preserved processed expiry labels and five validated abstention categories. Additional regressions verify corrupt receipt privacy, independent AI opt-out, retained abstention model, future dates and contradictory terminal states.
- Exact B 23 source/document hashes preserved; no B provider/evaluation tool executed, ledger stays18. Protected Module2/6/12/coaching/content/Functions index/Rules/indexes untouched. Narrow v2 purpose argument defaults to existing insights semantics.
- Completion and D contract: docs/integration/module13-batch-c-local-checkpoint.md. No further implementation remains in C scope; no D work started.
