# Module13 Batch A2 — local implementation plan

Binding scope: owner A2 instruction. Preserve A1/M12. No production registration, data access, consent collection, policy activation, deployment, model call or APK. Work in the existing checkout, preserving unrelated Mobile edits.

1. Server configuration and independent consent-v2 commands: expected revisions, audit/idempotency, fresh identity, App Check context, org/ownership isolation. Only injected reviewed policies/notices may be selected. No registered export. Preserve A1 synthetic-v1 contract; enforce explicit historical bounds and fail closed when source cannot enforce them before reading histories.
2. Default-disabled, explicit demo-emulator-only Firestore adapter; nested scoped paginated heads. Actual synthetic Firestore/Rules/auth/consent tests on a unique guarded loopback emulator; no existing Rules release or broad suite.
3. Bounded published catalog coverage and privacy-safe aggregate projection. No cohort policy approved => withhold all observed groups/counts. Synthetic reviewed policy fixtures exercise suppression; no hidden-group totals that expose complements. Static catalog coverage remains separate from attention-linked gaps. No general raw-score comparison or actual recommendation eligibility claim.
4. Typed Dart A1/A2 view parser, Malaysia range/filter/CSV logic and existing first Recommendations tab. Shared panels/report controls/Syncfusion; replace old universal-threshold slider with reviewed configuration status/selection contract. Normal app uses explicitly disabled repository; fixtures are injected and labeled. Preserve deferred queues as unavailable in Firebase mode.
5. Focused TDD, backend/Flutter tests, TypeScript/Flutter analysis, scoped independent review and completion record. Report actual UI versus fixture-only behavior, all original UC/FR mapping and privacy/threshold/retention/source readiness blockers. Stop at A2, no Batch B implementation.

## Progress

- Backend configuration/consent and emulator-reader tasks run independently in owned files. Parent owns content/privacy projection and Admin presentation.
- Design decision: no unreviewed minimum-cohort number is activated. Default projection withholds measurement-derived groups; fixture-only policy explicitly enables the test threshold.
- Source constraint: legacy heads store capture timestamps only inside payload JSON. V2 requires a separately bounded reader capability, otherwise fail before history reads; no retrospective metadata migration is authorized.
- Tasks1–5 complete locally.232 backend,38 Admin and11 actual dedicated Firestore emulator checks pass; TypeScript no-emit, focused Flutter analysis and Admin presentation guard pass. No source/live activation beyond this scope.
- Final independent review: fixed effective SDK transport verification and full compatibility CSV identity with failing-then-passing regressions; also reject attention-derived content bits when disclosure is pending. No remaining material finding.
- Deferred documented minor: a mixed v1/v2 fixture run can perform earlier authorized v1 work before a later v2 capability failure; no partial output or unauthorized v2 read occurs. Preflighting all participants could avoid that local wasted work.
- Governance decision: reviewed allowlist/notice removal can refuse an identical older command retry before receipt replay. This conservative refusal preserves current policy authority; it reduces retry availability and is documented rather than bypassing review.
- Production context/App Check attestation, deployed behavior, source completeness and Member consent collection are deliberately unverified by A2 scope. The source advertises a non-atomic bounded scan. Normal Admin uses the unavailable repository, not fixtures.
