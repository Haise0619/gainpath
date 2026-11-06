# Module 13 Batch D — Member delivery and navigation local checkpoint

Date: 2 November 2026, Malaysia. **Batch D is locally complete.** Scope: local source, deterministic synthetic records and isolated Firestore Emulator. No production activation or signed-in production Member acceptance is claimed. A1/A2/B/C contracts, original requirement numbering and their outstanding policy gates remain applicable.

## Implemented architecture and files

| Area | Implemented files |
|---|---|
| Delivery and Member contracts | `functions/src/modules/recommendation/recommendation-member-contracts.ts`, `recommendation-delivery.ts`, `recommendation-member-service.ts` |
| Current source resolution and existing inbox composition | `functions/src/modules/recommendation/recommendation-target-resolver.ts`, `module9-recommendation-projection.ts`; extended `functions/src/modules/coaching/module9-member-service.ts` |
| Shared typed notification and parser | `packages/gainpath_domain/lib/src/coaching/module9.dart`, new `recommendation_notice.dart`; `apps/mobile/lib/infrastructure/firebase/firebase_module9_repository.dart` |
| Member transport and detail sheet | `apps/mobile/lib/features/recommendation/application/member_recommendation_repository.dart`, `presentation/member/member_recommendation_sheet.dart` |
| Existing Notification Center and target navigation | `apps/mobile/lib/app/notifications/member_notifications_screen.dart`, new `member_recommendation_navigator.dart`, `app/di/member_recommendation_factory.dart` |
| Necessary narrow destination layout correction | `apps/mobile/lib/features/coaching/presentation/shared/coach_profile_screen.dart`: wrap current rating/review/branch metadata; booking behavior preserved |
| Backend fixtures and tests | `functions/test/recommendation-delivery.fixture.ts`, `recommendation-delivery.test.ts`, `recommendation-member-service.test.ts`, `recommendation-target-resolver.test.ts`; extended `module9-member.test.ts` |
| Isolated workflow | `functions/test/module13-d-integration.fixture.ts`, `functions/emulator/module13-d.test.ts`, `run-module13-d.cjs`, `functions/vitest.module13-d.emulator.config.ts`, `firebase/module13-d.emulator.test.json`; standalone-suite accounting in `functions/emulator/run-suites.cjs` and `functions/test/emulator-suites.test.ts` |
| Mobile verification | `apps/mobile/test/member_recommendation_repository_test.dart`, `member_recommendation_ui_test.dart`, `member_recommendation_navigation_test.dart`, `emulator/module13_member_emulator_test.dart` |

There is one existing organization Notification Center. The D services are reusable typed local libraries with explicit trusted `localDelivery:{fixtureSetId:'module13-d-v1'}` and C synthetic composition required. The default is unavailable. No production callable, worker, notification scheduler, client direct-write permission or dependency was added. The optional Member factory is injectable; normal Member shell/app composition is preserved.

Documentation changes are this report, `docs/superpowers/plans/2026-11-02-module13-batch-d.md` and the checkpoint references in `README.md`, `AGENTS.md`, `docs/STATUS.md`, `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md`, `docs/PROGRESS_REPORT.md` and `docs/archive/README.md`. Exact D source/document hashes are retained in the verification manifest.

## Prepared-to-delivered lifecycle and atomicity

C's Admin `sent` decision means **prepared**, as before. D reads the stable `recipientRecommendationId`, validates its strict prepared record, sent lead, decision, immutable target/source binding and controlled draft, then checks current organization/Admin authority, current verified recipient identity, active canonical Member, relevant purpose grants, dates and current B/C-backed target eligibility.

One transaction creates:

- `orgs/{org}/notifications/recommendation-{recipientRecommendationId}` in the existing inbox;
- `orgs/{org}/recommendationDeliveryReceipts/{recipientRecommendationId}`;
- the delivered extension of the existing recipient, with revision 1, delivery time, notification ID and null dismissal time.

The receipt binds immutable recipient and original lead fingerprints. Subsequent member-state revisions do not invalidate the delivery receipt. Lost responses and simultaneous first delivery attempts converge on one logical notification/receipt. A replay still checks current authority, purposes, expiry and target; a historical receipt cannot bypass revocation. Corrupt/mismatched records, source errors, collisions or transaction failures return safe failure without partial delivery. Fresh Firebase Auth identity is checked outside retryable Firestore transactions; canonical membership, consent and source documents are checked inside them. Production token/attestation and real-world revocation timing remain release/UAT obligations.

State distinctions are explicit: Admin prepared; delivered to inbox; read; acknowledged; dismissed; expired/withdrawn/unavailable. Inbox delivery does not prove a device saw a notice. There is no push delivery claim or acted-upon tracking. Expiry is evaluated on access; no background withdrawal/deletion job is installed.

## Read-only projections and Member commands

Local Admin delivery request: `{schemaVersion:1, organizationId, recommendationId}`. Its verified receipt contains schema/mode, organization/recommendation/notification IDs, initial revision, delivery time and `status:delivered`.

Member service request:

```typescript
{
  schemaVersion: 1,
  organizationId: string,
  recommendationId: string,
  action: 'get' | 'resolve' | 'read' | 'acknowledge' | 'dismiss',
  commandId: string | null,
  expectedRevision: number | null
}
```

`get`/`resolve` require null command metadata. Mutations require an actor-bound command ID and expected delivered revision. Durable receipts under `recommendationMemberCommandReceipts` bind actor, request fingerprint, prior/new revision, action and time. Changed reuse conflicts; duplicate/lost-response retries are safe. Concurrent commands against one revision have one winner.

The exact `MemberRecommendationDetail` schema 1 includes synthetic mode, org/recommendation/kind/revision/state, controlled title/summary, optional exercise/objective/verified explanations/current target label/specialization/image/photo path, and creation/delivery/expiry/read/acknowledgment/dismissal times. It excludes Member identifiers, raw histories, metric samples, source fingerprints, AI output and confidence scores. Trainer targets retain current Coach/branch and an **unreserved observation**; content targets retain the existing nested `published_routine_exercise_tutorial` destination with org/routine/index/exercise/day. Dart parses these strict shapes and rejects foreign scope or extra fields.

A prepared record returns redacted `not_delivered`, revision 0, no delivery/interaction timestamps or sensitive target. Only this strict state permits revision 0. Unavailable states redact exercise/objective/reasons/target/media. An active owner may dismiss a previously delivered unavailable/expired/revoked suggestion without renewed sensitive target processing. Prepared drafts cannot be dismissed through delivered commands. Read and acknowledgment require current available details. Read updates the existing notification flag and recipient read timestamp atomically; acknowledgment and dismissal do not silently mark read.

The existing Module9 projection and Dart parser changed together. The optional protected projector adds exactly six typed recommendation fields; legacy booking and announcement envelopes remain compatible. Without D composition, recommendation text is generic and unavailable. Malformed recommendation references fail closed; legacy mark-read cannot bypass the D read command. Pages remain bounded to 30 entries with a 31st sentinel and an owner-scoped cursor. The UI retains loaded older pages and offers “Load older notifications,” including when the selected category has no entries on the first page. Server lookup also reaches older owned recommendations directly.

## Member UI and current navigation

The existing purple Notification Center adds a recommendation category, compact cards and one scrollable detail sheet. It shows controlled reasons, learning context, current Coach specialty or tutorial title, available imagery/fallback, View Coach/Tutorial, explicit acknowledgment and dismissal. Fixture injection visibly says “Synthetic local preview.” Normal unavailable Firebase composition never substitutes fictional notices. Loading/offline/error/session-change and unavailable states use safe Member-facing text.

Trainer navigation resolves the server recommendation again, then current published/verified Coach data and permitted branch. It opens the existing `LiveCoachDetailView` through the session host. The existing booking factory is reached **only after a separate Member choice** and retains current availability, pricing and booking validation. No reservation, checkout, payment, Program, reward or record sharing occurs from opening a recommendation. Current Coach images reuse the existing scoped protected photo resolver, with matching current publication/photo path; no public URL is invented. Unavailable Trainer details offer normal Coach browsing.

Content navigation resolves the current published Routine through `loadById`, verifies organization, exact index/exercise/day, and authored steps or a sanitized supported video. It passes that actual `PublishedRoutineExercise` to the existing `ExerciseTutorialRoute`/`PublishedExerciseTutorialScreen`; it never constructs an exercise from a stale lead snapshot. Video-only instructional tutorials remain valid. Withdrawn/changed/missing sources refuse navigation. Actual network media playback/licensing availability is not proven by synthetic fixtures; existing player loading/error behavior remains responsible for playback failures.

Failed protected actions clear cached sensitive details and destination controls. Explicit lost-response retry preserves the original command/revision only after a fresh authorized fetch; no cached private detail is redisplayed during failure. Route/session guards clear content on account drift. An already rendered view has no continuous consent-change push subscription; fresh fetch/open/action checks enforce current access, and production revocation UX still needs staging review. Screens and buttons were tested at 393/375 widths, landscape and enlarged text; primary destination action targets are at least 48 pixels.

## Consent, authorization and privacy

Delivery/detail/resolve/current actions revalidate `exerciseInsights`, `recommendationGeneration` and `recommendationDelivery`. `externalAiInference` is additionally required when recorded provenance indicates inference was used/attempted; it is not mandatory for provider-unconfigured/single-candidate deterministic paths. Current verified Auth/App Check context, active organization/canonical Member and recipient ownership remain independent gates. Camera and workout-backup grants provide no recommendation authority. Only explicitly granted fictional purpose records are seeded.

Server-owned recipient/receipt/command state cannot be read or written directly by clients under unchanged checked-in Rules. Existing owner-readable generic inbox metadata is not a substitute for protected detail consent. Cross-Member and cross-organization calls fail; UI/transport source scope and current account are checked before and after asynchronous work. There is no aggregate disclosure, extra engagement tracking, retained-history processing or raw-model display introduced by D.

## Verification evidence

Final results and exact source hashes: [local verification manifest](../../build/module13-d/verification.json).

- Backend: **696 passed across 41 files**, including delivery/member/source/projection cases and focused A1/A2/B/C, Module12, Coach/booking/publication/chatbot regressions. [Raw results](../../build/module13-d/backend-results.json).
- TypeScript source and test no-emit checks passed.
- Firestore Emulator: **20 passed, zero failures/skips**, including the actual Flutter → HTTP → backend → Firestore Member workflow. [Raw emulator results](../../build/module13-d/emulator-results.json), [durable integration proof](../../build/module13-d/member-integration-proof.json). Four delivery requests produced exactly two recipients, two inbox notifications and two delivery receipts. Four Member command receipts prove both read states, Trainer acknowledgment and Content dismissal independently. Current Coach and tutorial RPCs were exercised; protected booking/payment/Program/workout/reward collections remained unchanged. The gateway and emulator shut down with no remaining listeners.
- Mobile: **43 passed across 7 files**, including 32 new DTO/UI/current-navigation checks and 11 existing inbox/booking composition/cubit/tutorial-player regressions. [Raw final results](../../build/module13-d/mobile-results.jsonl). Scoped Flutter/shared-contract/Coach-profile analysis found no issues; architecture and Mobile presentation boundary checks passed.
- Shared domain booking/tutorial contract regressions: **11 passed across 3 files**.
- Five actual synthetic Flutter widget renders passed and were inspected: [Notification Center, 393px](../../build/module13-d/inbox.png), [Trainer detail](../../build/module13-d/trainer.png), [Content detail](../../build/module13-d/content.png), [Expired state, 393px](../../build/module13-d/expired.png), [393px with 1.6× text](../../build/module13-d/narrow-accessible.png). They load the existing local Barlow font and explicit missing-image fallbacks. These are widget renders, not signed-in production or physical Xiaomi screenshots.

The emulator is guarded to `demo-gainpath-module13-d`, Firestore `127.0.0.1:18113`; optional fixture-only gateway is `127.0.0.1:18114`. Actual SDK project/host/port/TLS and bounded requests are checked. The logical November1 clock plus elapsed runtime keeps the declared fictional November2 slot deterministic, independent of host date. No real scheduling claim follows from that clock.

Reproduce with `cd functions` then `node emulator/run-module13-d.cjs --with-member-ui`. The nested Flutter test refreshes Trainer and Content through the existing B/C services, approves prepared records through C's real decision service, delivers twice each, opens the real inbox and current Coach/tutorial widgets, then records independent read/ack/dismiss outcomes. Its Admin actions use the loopback RPC; C's separate actual Admin-widget proof remains preserved, rather than being relabeled as a fresh D Admin-browser session.

Required failures include wrong Member/org/App Check, revoked consent after preparation/delivery, inactive recipient/Coach, withdrawn tutorials, expiry, prepared-only state, lost responses, duplicate/concurrent delivery, expected-revision action races, source/precommit failure, older-page lookup and unchanged-Rules direct-write denial. Auth/App Check stubs are explicit synthetic trust inputs, not proof of production token verification or real device attestation. The fixture gateway header is not a production authentication design.

Independent review corrections cover revoked-action cached detail, valid video-only tutorial navigation, protected Coach photo reuse, strict prepared revision 0, and safe dismissal of delivered unavailable records. The real narrow workflow also exposed metadata-row overflows in the inbox and existing Coach profile. Wrapping corrected them; the current profile has additional 393/375px and 2× text regressions that also verify its booking callback remains a separate choice. No known material review finding remains after focused regression verification.

## Original requirements, preservation and remaining gates

Academic Chapter3/4 documents and numbering are unchanged; see [A1 full original mapping](module13-batch-a1-evidence-and-insights.md#original-requirement-traceability), [A2](module13-batch-a2-local-checkpoint.md), [B](module13-batch-b-local-checkpoint.md), [C](module13-batch-c-local-checkpoint.md) and [academic source register](../archive/README.md#academic-source-register).

| Original requirement | D coverage and acceptance boundary |
|---|---|
| UC13.9 Send Trainer recommendation | Local prepared → actual existing inbox entry → Member detail → current Coach profile → separately chosen existing booking route implemented. Atomic delivery/read/explicit response and emulator ownership/target failures verified. Production delivery and real signed-in acceptance remain unproven. |
| UC13.12 Send Content recommendation | Local prepared → inbox → current published tutorial/exact exercise route implemented and emulator verified, including withdrawn refusal. Production content/media and signed-in acceptance remain pending. |
| FR13.3 Trainer pairings/decisions | B/C matching/approval preserved; D closes local recipient delivery/navigation gap. Original operational acceptance, approved sources/policies and authorized actor parity remain partial. |
| FR13.4 Content pairings/decisions | B/C content eligibility/ranking/approval preserved; D adds local actual inbox/tutorial flow. No production or clinical validation claim. |

A1 compatibility/aggregation and A2 default-off independent consent/configuration remain intact. All 40 preexisting unrelated Mobile files retain their saved hashes; no reset/stash/staging occurred. B's 23 source/report hashes and completed 18-attempt provider ledger are preserved; no Gemini calls were made. C's 32 other source/report hashes are preserved; its generic harness registry alone adds D to the standalone exclusions. No Module2 scoring, Module12 metrics, chatbot behavior, production Function exports, Rules or indexes changed.

Decisions still requiring owner/privacy/release review:

1. Exact purpose notice/version, independent grant/revoke UX, historical capture-time scope, regrant semantics and permitted provenance after inference opt-out. No production consent capture/migration/default is enabled.
2. Approved compatible exercise minimum-evidence and attention policy, curation and any aggregate minimum-cohort suppression/export policy. Descriptive-only/default-off safeguards remain; no universal 70% or High-Risk classification is activated.
3. Production source readiness: authorized histories, current credentials/availability/branch capacity, curated tutorial compatibility, publication/media availability and real access checks. D conservatively invalidates changed source fingerprints/observed targets; it does not relax eligibility to force results.
4. Recommendation validity versus retention: approve expiry/renewal, post-revocation redaction or withdrawal, lead/run/lease/audit/recipient/notification/delivery receipt/Member-command receipt retention and deletion/legal-audit treatment. Fixture validity/bounds are engineering test constraints, not approved retention. No TTL, arbitrary deletion duration or automatic deletion was introduced.
5. Production delivery mechanism and actor scope (Admin versus original Staff), rate/query limits, error/retry monitoring, real Auth/App Check composition, private photos/media and selective registration/deployment/rollback. Actual device/browser UAT and release approval remain separate.

## Exact Batch E handoff

Batch E is **not started or authorized by this checkpoint**. A future scope should resolve the decisions above, then:

1. Define a reviewed production composition/transport version from the exact request/detail/receipt/target contracts above, preserving canonical ownership/purpose/source guards and transaction semantics. Current `synthetic_local` modes, literal fixture organization and trusted local gates are intentional; registering this fixture composition against production is not supported.
2. Select a controlled production delivery invocation/recovery mechanism, with bounded idempotent work and observable failures. Do not convert C preparation into confirmed delivery or add unrestricted triggers.
3. Register reviewed callable endpoints with actual verified Auth and enforced App Check; connect the optional Member factory to those endpoints and current authorized Coach/catalog/photo/booking repositories. The local gateway must never become a production transport.
4. Implement only approved consent/retention/redaction/expiry handling, authorized data migration and disclosure policy. No historical processing or default grants may be inferred from this local checkpoint.
5. Verify real staging identity/attestation, revocation/races, canonical access, older inbox pages, current Coach/price/availability and published media; perform signed-in Admin/Member and physical-device accessibility/navigation UAT under a separately approved release plan.
6. Retain exact package/source baselines, regression evidence, rollback and post-release checks before any approved selective deployment. Preserve B's completed provider budget/evidence; further paid inference needs its own authority.

Batch D stops at the integrated local checkpoint. Production Member delivery, consent collection, background processing, Firebase deployment and APK build/install remain disabled.
