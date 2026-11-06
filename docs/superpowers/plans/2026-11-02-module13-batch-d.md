# Module 13 Batch D integrated implementation plan

> **For agentic workers:** Use executing-plans for integration, parallel delivery/UI/emulator domains and a fresh final review. One continuous local milestone; no intermediate approval checkpoints.

**Goal:** Close C's prepared-recipient gap with atomic inbox delivery and usable Member details/actions/current Coach and tutorial navigation, verified through Flutter and isolated Firestore.

**Architecture:** Reuse existing organization notifications and Module9 projection/parser/model, C authorization/consent/recipient/lead integrity, B eligibility and existing Member target repositories/routes. New default-off synthetic delivery/member services and injected transport only; no production exports, worker, Rules change or consent rollout.

**Tech stack:** Existing TypeScript/Vitest/Firestore emulator and Flutter shared GainPath components. No dependency install, provider experiment, full build or APK.

**Spec:** Full attached Batch D request (2 November2026), A1/A2/B/C reports, original Chapter3 UC13.9/12 and FR13.3/4, Chapter4 lead/notification designs.

## Decisions and constraints

- Preserve actual dirty Mobile workspace: 40 preexisting file hashes plus binary diff saved to ignored `build/module13-d/preexisting-mobile-work.*` before edits. Avoid touching those paths; add optional injection/helpers around clean inbox/parser files.
- Stable recipient ID -> one deterministic existing inbox entry and delivery receipt, atomically with recipient delivery state. C Admin `sent` remains prepared; inbox delivery/read/ack/dismiss/withdrawal are distinct.
- Fresh verified Auth/AppCheck context, canonical active Member/org/ownership and relevant purpose grants precede delivery/details/resolve/actions. External-AI opt-out still permits deterministic recommendations.
- Strictly bind recipient to original sent lead/decision/target/source; revalidate current authoritative target through existing C/B source guard. No booking, checkout, payment, Program/workout/reward effect on opening.
- Extend Module9 backend projection and Dart DTO/parser together. Default projection without D composition redacts recommendations; ordinary notices remain compatible. Recommendation reads use protected D command, not legacy mark-read bypass.
- Member detail transport excludes raw histories, IDs beyond target references, fingerprints, model text and confidence scores. Unknown/stale/revoked/prepared states are redacted and non-actionable.
- Use current Coach directory and published Routine `loadById`, exact index/exercise/day and real PublishedRoutineExercise, then existing widgets/routes. No fabricated source object or imagery.
- Controlled demo project `demo-gainpath-module13-d`, Firestore18113 and fixture gateway18114. Logical fixture clock avoids host-date-dependent training availability. Mock/recorded inference only; B evidence/18-attempt ledger unchanged.

## Review focus

1. Lost responses/concurrent workers create one notification and no false delivery; source/transaction failures commit no partial success.
2. Revocation/inactive/foreign accounts and target withdrawal redact every detail/open path, including older inbox pages and receipt retries.
3. Read, acknowledgment and dismissal stay independent and actor-owned, with idempotent CAS receipts.
4. Existing inbox projection must preserve the typed recommendation reference while protecting ordinary booking/announcement behavior.
5. Real Flutter navigation must resolve authoritative current models, retain session guards and never trigger booking/payment automatically.

## Tasks

- [x] Inspect request/current tree/reports/contracts and snapshot unrelated Mobile work; define shared wire contract with delivery/UI implementers.
- [x] Delivery agent: strict prepared/delivered/member contracts, atomic delivery/receipt, current purpose/target validation, Member commands, redaction/concurrency tests.
- [x] Coordinator: safe existing Module9 projection hook/read boundary, current target resolver reusing C/B/helpers, focused legacy compatibility and source tests.
- [x] UI agent: typed domain/parser/repository, existing inbox pagination/cards, compact detail/actions, current Coach/tutorial navigation helpers and focused Mobile tests.
- [x] Emulator agent: real B+C+D+Module9 workflow, server-owned protections and failures/races, actual Member Flutter HTTP-gateway target navigation and durable actions.
- [x] Final review/fixes, focused A1/A2/B/C/notification/Mobile regressions, TS/Flutter checks, branded/narrow renders, preservation hashes, operational references and D/E completion report. Stop locally.

## Progress

- Shared types are in `recommendation-member-contracts.ts`; new notification ID is `recommendation-{recipientRecommendationId}`. The previous Module9 projection dropped unknown fields; its protected optional projection and Mobile parser now preserve the typed contract together.
- Existing published catalog supports `loadById`; current tutorial route requires a real PublishedRoutineExercise and AuthBloc/session guard. Coach profile/booking factories already provide the independently chosen booking flow.

- Final local checkpoint: 696 backend, 43 focused Mobile, 11 domain and 20 isolated emulator checks pass (zero emulator skips), plus five actual synthetic widget renders. Source/test types, scoped analysis and architecture/presentation checks pass. Review fixes include consent-denied cache redaction, strict prepared revision zero, protected photos, video-only instructions, unavailable dismissal and narrow inbox/Coach metadata wrapping. Actual existing Coach/tutorial routes and persisted independent interaction records are proven through Flutter/HTTP/Firestore. Forty preexisting Mobile files and B evidence/18-attempt ledger are preserved; no production/provider/APK action. See the D report and build/module13-d/verification.json. Stop at D; E is not started.
