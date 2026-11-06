# Module 13 Batch E — final local integration and readiness record

Date: 2 November 2026, Malaysia. Scope: synthetic/offline development and isolated Firestore Emulator. This record separates implemented local functionality, observed client integration, academic evidence and production acceptance.

## A. Overall status

The existing A1 evidence extractor/aggregator, A2 reviewed-policy/default-off purpose contracts, B eligibility/baseline/Gemini ranking, C persistent Admin decisions and D Member delivery/navigation remain the foundation. E adds consent settings preview, typed callable readiness contracts, protected configuration/consent/lead/run reads, independent evaluation preparation, security corrections and connected Admin/Member acceptance.

Production recommendation APIs, production history readers, consent collection, automatic generation and delivery remain disabled. No real Member histories, live inference, production notification, deployment, billing/credential operation, retention cleanup, booking/payment/Program/workout/reward mutation or APK build/install occurred.

## B. Architecture and exact source changes

Backend source under `functions/src/modules/recommendation/`:

| File | E responsibility |
|---|---|
| `recommendation-callable-readiness.ts` | Exact versioned request/response map for 12 operation families, App Check/release metadata, 16KiB request and 256KiB response design limits; permanent disabled production facade; nonserializable SDK-bound local request validation without source execution. |
| `recommendation-read-services.ts` | Protected current configuration, owned v2 consent/null, bounded refresh summary and fresh authorized lead detail. Current identity/consent/source/expiry are revalidated; no scans or writes in getters. |
| `recommendation-configuration.ts`, `recommendation-consent-v2.ts` | Export existing strict parsers for read reuse; retain all validation, grants, audit/revision and default-off behavior. |
| `recommendation-queue-reader.ts` | Check current verified Member identities and relevant purposes inside the final canonical transaction after awaited identity work, before releasing any labels/evidence/facets/counts. Refuse the whole list on invalid access; preserve retained audit records. Refresh pending-expiry interpretation at response time. |
| `exercise-insights-presentation.ts` | Exclude archived/inactive publications from tutorial coverage; preserve the actual publication contract's omitted-day default of 1 while rejecting invalid explicit days. |
| `recommendation-independent-evaluation.ts`, `recommendation-independent-evaluation-labels.ts` | Effective-K metrics, denominators/uncertainty/stability, frozen blinded packets, independent assessor validation and explicit disagreement/adjudication. |

Admin changes are `apps/admin_web/lib/features/recommendation/application/recommendation_queue_repository.dart` and `presentation/admin/recommendation_queue_panel.dart`: View details requests the current protected lead instead of trusting a cached row; validates scope/kind/identity and exact response fields; withholds sensitive dialog content while pending; clears stale rows/facets on refusal and rejects account/repository drift. A visible progress state accompanies asynchronous detail verification. The existing three-tab design, filters, charts, CSV scope, Send/Dismiss and persisted receipt behavior remain.

Mobile changes are `apps/mobile/lib/features/recommendation/application/recommendation_consent_repository.dart`, `presentation/member/personalized_recommendation_settings_screen.dart`, `navigation/recommendation_privacy_navigation.dart` and the clean existing `features/identity/presentation/member/privacy_and_data_settings_screen.dart`. Normal Settings navigation opens a disabled review preview with no production repository or notice. Explicit test injection exercises real v2 command semantics.

Verification source includes new `functions/test/recommendation-{callable-readiness,read-services,release-boundaries,independent-evaluation,independent-evaluation-fixtures,independent-evaluation-generator}.test.ts`, the independent evaluation fixture, `module13-e-integration.fixture.ts`, `functions/emulator/module13-e.test.ts`, `run-module13-e.cjs`, `functions/vitest.module13-e.emulator.config.ts`, `firebase/module13-e.emulator.test.json` and `functions/tools/module13-batch-e-evaluate.cjs`. Existing queue-reader tests, standalone suite registry/accounting, Admin queue tests/transport fixture were extended. The C emulator gateway gains only the compatible protected detail method; its fixture data and original completion artifacts are preserved. New actual-client tests are `apps/admin_web/test/emulator/module13_e_admin_emulator_test.dart` and `apps/mobile/test/emulator/module13_e_member_emulator_test.dart`; Mobile adds consent repository/settings/render tests and `test/support/recommendation_consent_fixture.dart`.

The [verification manifest](../../build/module13-e/verification.json) enumerates exact files/hashes and approved earlier-source corrections. Four E reports, the E plan and seven operational references document the checkpoint. No commits, reset, stash or broad staging occurred.

### Callable readiness and activation boundary

The registry covers Admin Insights/configuration read/save, Trainer/Content Refresh, list/filter/detail/decision/status; Member purpose read/grant/revoke and owned detail/resolve/read/ack/dismiss; controlled delivery/recovery. Existing strict leaf contracts remain authoritative for roles, revisions, current purposes, source freshness and durable receipts. `enforceAppCheck:true` is readiness metadata, not a registered verifier.

The production facade **always refuses**. Even a valid emulator capability combined with an arbitrary handler cannot make it execute a production source. Local request validation requires a real installed Firestore SDK instance bound to `demo-gainpath-module13-e`, loopback18115, TLS off, matching environment and a server-minted WeakMap capability. Copied/JSON/flag/fixture-ID objects are insufficient. The fixed test-only dispatcher constructs every store and reader from that same verified SDK. The fixture HTTP header is explicit synthetic trust, never a production authentication design. A future production composition requires reviewed implementation and registration; there is no enabled flag to flip here.

## C. Data, consent, evidence and disclosure readiness

The [architecture/governance report](module13-batch-e-architecture-and-governance.md) provides the pre-payload capture attestation/query/migration proposal, eight exact compatibility policy groups, catalog curation checklist, aggregate inference risks, 12-type lifecycle matrix and selective release/rollback checklist.

Existing backup heads have immutable keys/digests and server update time, but capture dates remain inside client-declared payloads. Upload/update time cannot prove session capture time, especially for offline uploads. No existing production reader can enforce the required trusted historical scope before reading payloads. E proposes separate trusted metadata/attestation bound to organization/Member/backup identity and revision/digest, bounded capture-time queries and indexed pagination. Old unattested records remain excluded unless a separately approved trust/migration design can establish eligibility. No migration, backfill, new production index or Module2 measurement/schema change is activated.

All compatible exercise groups remain unapproved/descriptive-only for real attention eligibility. Minimum scored sessions/dates/assessed attempts/coverage/window, recency and `score_below` interpretation require compatible-group review. Unscored/null/unsupported observations never become zero scores or High-Risk classifications. Estimated Form Score is not a clinical injury probability; no universal 70% threshold is enabled.

A cohort minimum alone cannot prevent small-group or complementary/differencing inference. The proposal adds reviewed compatible reporting partitions, complementary suppression, bounded filter combinations, consistent export suppression and repeated-query/export safeguards. Exact cutoffs and enforcement policy remain owner decisions; no arbitrary threshold is installed. Default disclosure continues to withhold observed groups without approved policy.

The [consent preview and proposed wording](module13-batch-e-consent-preview.md) includes four independent purposes under Profile → Settings → Privacy & Data → Personalized Recommendations. It presents server state, notice/content versions, historical scope, explicit confirmations, current-state reload and safe failure/retry/account isolation. Null server state means all off; failure never means a successful default read. Camera/backup consent provides no recommendation authority. Grant/revoke receipts are not enrollment, inferred permission, booking acceptance or external-AI approval for other purposes.

Owner decisions remain exact wording/version, permitted history start and capture trust, regrant semantics, provider transfer/privacy terms, relevant-purpose revocation, and retention/redaction of grants/audits/configuration/runs/locks/leads/decisions/recipients/delivery receipts/Member receipts/inbox/provenance. Recommendation validity, lock expiry and retry idempotency are distinct from retention. No 7/30/90-day retention default, TTL or deletion worker is introduced.

## D. AI evidence and independent evaluation

The [evaluation report](module13-batch-e-ai-evaluation.md) and [offline summary](../../build/module13-e/evaluation/summary.json) separate historical development, offline replay, held-out preparation and mock structural tests. All B source/evidence hashes and its 18-attempt request ledger remain unchanged; E made zero provider calls.

| Recorded B development comparison | Baseline, n=11 | Valid semantic-only, n=10 | Hybrid including fallback, n=11 |
|---|---:|---:|---:|
| Precision@1 | .8182 | 1.0000 | 1.0000 |
| Precision@3 | .9394 | .9333 | .9394 |
| nDCG@3 | .6658 | .9983 | .9649 |
| Valid target rate | 1.0000 | 1.0000 | 1.0000 |

These use identical eligible sets and provisional development labels. One of 11 model outputs was invalid/fallback; the valid semantic subset has a different denominator. They demonstrate ordering contribution, not independent superiority or generalization. Fewer-than-K/empty sets, missing judgments and zero-relevance cases have explicit denominator/null rules; uncertainty and unavailable stochastic stability are documented rather than manufactured.

E prepared 22 held-out fictional cases across Trainer/Content, supported movements/objectives/levels, sparse/ambiguous descriptions, injection and abstention controls. Two blind assessor forms each contain 56 **blank** judgments with a 0–3 rubric; disagreement requires recorded adjudication. No human judgments or held-out real-model metrics exist yet. The custodian key/provider fixtures must be withheld from assessors. A separately approvable inference experiment is prepared; it does not reuse B's remaining budget or authorize a request.

Module13 is AI-powered through upstream pose-derived observations and the implemented Gemini semantic relevance/order contribution over deterministically eligible candidates. The server validates structured output and IDs/evidence independently, composes stable hybrid/fallback rankings, gives controlled explanations to human Admin review and leaves final actions to the Member. This is educational recommendation ranking, not clinically validated risk prediction.

## E–F. Client UAT, security and verification evidence

Final exact counts, commands, source hashes and environment are in [verification.json](../../build/module13-e/verification.json).

| Fresh focused verification | Result |
|---|---|
| Backend A1–D/new E and relevant Module12/backup/Coach/booking/publication/chatbot | **729 passed, 47 files** |
| Admin Insights/queue/detail/default-composition/reporting | **80 passed, 9 files** |
| Mobile consent/settings/notifications/routes/booking/tutorial | **94 passed, 12 files**, including seven consent renders |
| Shared booking/tutorial domain contracts | **11 passed, 3 files** |
| Final E same-lifetime Firestore acceptance | **5 passed, zero skips**, including actual Admin and Member widget workflows and two current Admin detail reads |
| Prior C/D Firestore regressions | **21 +19 passed**; one opt-in legacy client case skipped in each because E runs both actual clients together; no failures |
| Additional Admin/Member widget renders | **4 +5 passed**; 16 total fresh render cases including the seven consent cases already counted in Mobile |
| Source/test TypeScript, scoped Flutter, architecture and Admin/Mobile presentation boundaries | Passed; scoped analysis reports no issues |

Raw evidence is `backend-results.json`, `admin-results.jsonl`, `mobile-results.jsonl`, `domain-results.jsonl`, `emulator-results.json`, `c-regression-emulator-results.json`, `d-regression-emulator-results.json` and `combined-client-proof.json`, all under `build/module13-e/`. Final E `final-emulator-output.log` records successful process exit and clean shutdown. Earlier diagnostic failures are not counted as final passes.

The integrated E test uses actual Flutter Admin and Member widgets through loopback HTTP into the same live Firestore/backend lifetime. Admin loads truthful protected Insights, refreshes both queues, fetches fresh current details, reviews and Sends both. C creates two prepared records with no inbox entries. Controlled D delivery/retry produces two entries/receipts. The Member opens both current existing Coach/tutorial routes and records separate read/acknowledgment/dismissal outcomes. The controller verifies four Member command receipts and unchanged booking/consultation/payment/Program/workout/reward snapshots. Wrong-role/org/Member, missing App Check, direct writes, revocation, stale sources, duplicate/concurrent requests and failures are exercised in focused suites.

The engineering bridge is explicit: E Insights returns catalog-only descriptive output and reads zero histories because its preceding-month window predates from-grant consent. C/B Refresh then uses the existing compiled fictional learning need. This is not approved automatic insight-derived eligibility. A1's registry currently scopes supported exercise identities to `gainpath`; C's synthetic fixture uses `synthetic-org`/a curated fictional alias. The harness does not rewrite identity or invent scores to hide this source gap. Positive validated evidence known-answers remain covered by A1 regressions; a production positive-history adapter remains blocked.

Independent review and actual integration found and corrected: archived/inactive coverage mismatch; stale retained queue disclosure after revocation; revocation during final awaited Admin identity refresh; expiry crossing identity work; ability to pair local capability with unrelated handler in an earlier facade design; cached Admin detail bypass; missing pending-detail progress. Each behavioral correction has failing-then-passing focused evidence. Current source uses the permanent production barrier and fresh detail path.

Current fetch/open/mutation commands revalidate relevant purposes. Already-rendered views have no continuous consent-change push subscription; account drift is handled, stale actions refuse and denied reads clear sensitive state. Real-time revocation UX, actual Firebase token validation, real App Check attestation, private-photo/media availability and signed-in staging/physical-device behavior still require authorized acceptance. Emulator Auth/App Check stubs and widget renders cannot establish those results.

Actual Flutter screenshots: [Admin desktop](../../build/module13-e/trainer-1400.png), [Admin narrow](../../build/module13-e/content-600.png), [Member inbox](../../build/module13-e/inbox.png), [Trainer](../../build/module13-e/trainer.png), [Tutorial](../../build/module13-e/content.png), [Expired](../../build/module13-e/expired.png), [Member enlarged text](../../build/module13-e/narrow-accessible.png), [Consent375](../../build/module13-e/consent-preview-375.png), [Consent393](../../build/module13-e/consent-preview-393.png), [Consent enlarged text](../../build/module13-e/consent-accessible-393.png), [Consent landscape](../../build/module13-e/consent-landscape-851.png), [Grant confirmation](../../build/module13-e/consent-grant-confirmation.png). Synthetic mode is visibly labeled; imagery fallbacks are explicit. Admin captures use existing local Arial substitution; Member captures load existing Barlow/Barlow Condensed. No generated concept art or physical Xiaomi/staging screenshot claim is made.

## G. Original FYP traceability

The [full 19-row matrix](module13-batch-e-architecture-and-governance.md) reassesses UC13.1–UC13.15 and FR13.1–FR13.4 with original source lines, exact implementation/test paths, local PASS/PARTIAL/MISSING, production status, limitations and amendments. Academic c3/c4 files retain their hashes.

Core local mechanics for queues, manual Refresh, filters, approval/dismissal, delivery and navigation are implemented and emulator verified. Original clinical-risk interpretation/threshold policy, independent relevance evidence, Staff actor parity, approved real source adapters and runtime release acceptance remain partial or blocked. Chapter3 manual Admin generation versus Chapter4 reactive LeadEvaluator, Member versus Coach recipient, original High-Risk terminology and threshold direction, top-level versus organization-scoped collections and Admin/Staff scope are explicit design amendments requiring acceptance. They are not silently rewritten or marked production PASS.

## H. Production release — NOT READY

Required actions are: approve source/capture/history and purpose notice contracts; curate current Coach qualifications/availability/fees and instructional compatibility/media; approve compatible evidence and aggregate-disclosure policy; approve expiry/redaction/retention and controlled delivery recovery; implement reviewed production adapters/composition and real Auth/App Check wrappers; register an exact selective callable allowlist; add only reviewed query indexes/Rules where needed; connect reviewed Admin/Member transports with safe old-client behavior; perform signed-in staging and physical UAT; prepare exact package/deployed baselines, rollback and post-release checks.

The bounded read-only [deployed metadata review](../../build/module13-e/deployed-metadata-review.json), using existing configured CLI access, returned **70 Functions and no recommendation/ExerciseInsights/Module13-named exports**. Only allowlisted names/runtime metadata were retained; no Member records, raw environment/secrets, authentication changes or production writes occurred. This verifies the observed export inventory, not deployed source-package, environment/IAM, Rules/index or served-client equality. A future release must capture those fresh exact baselines and preserve unrelated services. Rollback must retain receipts/audits and disable generation/provider/delivery before restoring compatible prior artifacts. No blanket Functions deployment, default enrollment, fixture-gateway publication or bypass of unresolved decisions is appropriate.

## I. Reproduction and checkpoint evidence

From `functions`: run the focused tests named in `build/module13-e/backend-results.json`, source/test `tsc --noEmit`, and `node emulator/run-module13-e.cjs --with-clients`. The E runner requires the already installed JAR/Java/Node/Flutter SDK and dedicated demo loopback project; it strips inherited provider/service-account CLI credential variables. Offline evaluation: `node functions/tools/module13-batch-e-evaluate.cjs` from repository root. It performs no network inference and preserves B artifacts.

Flutter verification uses installed `C:/flutter/bin/cache/dart-sdk/bin/dart.exe C:/flutter/bin/cache/flutter_tools.snapshot test --no-pub …`; scoped analysis/architecture and presentation checks are recorded. Raw JSON/JSONL, full final emulator output, initial diagnostic failures, blank assessment materials, screenshots and source preservation results remain in ignored `build/module13-e/`. Earlier C/D regression output is redirected into E to preserve their completion artifacts. No dependency installation or full repository/release build was needed.

## J. Separate final recommendations

1. **Batch E safe local development: COMPLETE.** All feasible implementation, evaluation preparation, review and focused verification are recorded. External human/policy/release prerequisites are explicitly pending.
2. **Full original Module13 emulator integration: PARTIAL overall.** The connected compiled-fixture Admin-to-Member workflow is PASS, including actual clients and current details. Positive authorized-history-to-approved-policy integration remains blocked and must not be inferred from it.
3. **FYP demonstration:** suitable for a clearly labeled engineering demonstration of eligibility, genuine recorded Gemini ordering, validation/fallback, human review and Member delivery. Independent recommendation-quality conclusions await actual assessors and authorized held-out inference.
4. **Production deployment:** **NOT READY**.
5. **Further approval/work:** required for the explicit source, policy, consent, curation, retention, real identity/attestation/UAT and selective-release gates above. Batch E stops locally.
