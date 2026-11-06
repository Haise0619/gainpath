# Unified operational Admin integration implementation plan

> Execute inline with superpowers:executing-plans. Preserve the current dirty checkout; do not commit, reset or remove accepted work. One fresh security review before live activation.

**Goal:** the existing legitimate canonical Admin uses ordinary GainPath screens to see canonical plus persistent FYP records, supported descriptive analytics and explicitly simulated business activity.

**Spec:** owner attachment `bb768316-c5b3-4224-bc17-552ece8b933d/Pasted text.txt`; this is explicit implementation/deployment authority and opts out of another design-approval conversation.

**Architecture:** retain both physical source graphs. Extend only the existing FYP command transport with fixed `admin.unified.*` read operations, authorized against current canonical Admin membership, fresh Auth and App Check. A separate nonserializable read-only scope permits reuse of existing cohort readers without impersonating the fictional Admin. Merge authorized source results server-side, enforce bounds and identity collision checks, retain provenance, and expose them through ordinary Admin repositories. New sample business records live in an exact-owned separate cohort projection; they never enter actual transactions, booking reservations, wallet or settlement collections. No new service/IAM is planned.

**Alternatives:** copying all records to canonical collections creates duplicate identities/ownership and is unnecessary; client-side cross-scope queries weaken the boundary. The owner-selected server read-model is the least disruptive valid approach. Canonical mutations remain unchanged; FYP records are visibly read-only and cannot accidentally enter canonical authoring calls.

## Constraints and review focus

- Project `gainpath-0619`, `(default)`, organization `gainpath`; cohort fixed to `fyp-v1`. No request selects a path, role or cohort.
- Preserve existing two recommendation runs,12 leads,4 recipients/notifications/delivery receipts and3 Member action receipts; no generation or Send.
- Preserve all original consent, ownership, account-lifecycle and scoring safeguards. Canonical histories never enter new recommendation processing.
- Preserve existing settled/Sandbox receipt definitions; simulation has its own versioned contract and labels in every applicable export.
- Reject source failures, collisions, pagination drift, oversized scans and mixed authorization; return no partial aggregates.
- Revalidate canonical Admin authority after reads; reject disabled/stale accounts, FYP accounts, staff, foreign organizations and forged scope objects.
- Native Member testing stays deferred by owner; no APK, Xiaomi, payment/provider, reward, booking creation, real-account/claim or destructive operation.

## Tasks

### 1. Baseline and authority

Files: new `functions/src/modules/dataset/unified-admin-scope.ts`; minimal brand/read-only integration in `fyp-scope.ts`; `functions/test/unified-admin-scope.test.ts`.

Interfaces: `resolveUnifiedAdminScope(request, dependencies)` returns only an in-process canonical Admin read grant; fresh authority checks include canonical membership/lifecycle, SDK identity, no dataset assignment and fixed released cohort. Bound transactions deny every create/set. Existing FYP scope behavior remains unchanged.

- [x] Capture live inventory, actual Rules/source archives, canonical record hashes and existing FYP counts before product edits (`build/unified-admin-20261104/live-baseline.json`).
- [x] Reproduce missing App Check, wrong role/org, stale Auth, revoked lifecycle, forged authority and read-store write attempts; implement and run scope/FYP regression tests.

### 2. Unified readers and shared reporting

Files: new `unified-admin-reader.ts`, `unified-admin-reporting.ts`, `unified-admin-backend.ts`; minimal `fyp-backend.ts` and `fyp-release-index.ts` integration; focused tests.

Interfaces: fixed `admin.unified.directory`, `.member`, `.coach`, `.programs`, `.report`, `.workouts`, `.business`, and read-only recommendation operations. Source-tagged stable IDs; bounded pagination; no arbitrary collection reads. Reuse existing aggregation and published contracts. Canonical/FYP identity collisions fail closed.

- [x] Tests for canonical/FYP merge, all18/8 records, filtering/pagination, exact source navigation and safe FYP details.
- [x] Tests for combined account/workout totals with source breakdown, scoring compatibility, Malaysia ranges and no raw histories in aggregate responses.
- [x] Tests for read-only existing lead/detail/status/Insights and preserved recipient state; deny every write operation through the unified route.

### 3. Coherent sample business projection

Files: new `unified-sample-business.ts` and exact-owned operator; independent known-answer tests.

Interfaces: versioned fictional plan/subscription/appointment/ledger rows with stable IDs, linked Member/Coach references, MYR minor units, common dated events and explicit simulation provenance. Separate actual/simulated/illustrative totals; zero provider, entitlement or wallet effects.

- [x] Pin deterministic amounts/date boundaries, cancellation exclusion, monthly totals, source references and no duplicate receipts.
- [x] Validate create-only/idempotent exact ownership and collisions; never modify original seed ownership or consent/history.

### 4. Ordinary Admin repositories and presentation

Files: new unified Firebase transport/repository adapters under Admin infrastructure, existing DI, member/coach detail models and existing Dashboard/Reports/Recommendations bindings.

Interfaces: canonical session remains canonical; defaults include both sources. Existing canonical authoring delegates only for canonical IDs. FYP details and content are read-only; profile/goal/recorded activity/business/recommendation summaries use typed server data. Separate labeled sample revenue/membership/booking components reuse existing layout/Syncfusion charts; export retains provenance.

- [x] Widget/repository tests render calculated combined dashboard, member/coach lists, sample finances and existing leads; verify FYP actions cannot target canonical mutation paths.
- [x] Run affected Flutter/TypeScript analysis and canonical/FYP regressions; preserve normal Mobile composition.

### 5. Actual default-database emulator integration

Files: focused unified emulator suite and ordinary Admin widget bridge.

- [x] Real canonical Admin Auth+App Check request enters server services, sees canonical plus18/8, reports52 observations and coherent sample business data; real components render results.
- [x] Actual wrong-role/cross-org/FYP escalation/direct-private access denials, default-off activation, missing source/no partial data and unchanged financial/reward operations.
- [x] Verify original recommendation/consent/source hashes unchanged.

### 6. Reviewed bounded live activation

Files: exact source-only archive and new controlled operator/release evidence under `build/unified-admin-20261104/`.

- [x] Fresh security review of source, data plan and exact package; reproduce/fix important findings before live changes.
- [x] Capture narrow rollback; create only reviewed exact-owned sample/control rows; deploy only the existing command service source, preserving runtime/env/IAM, session endpoint, registration,69 other Functions, Rules/indexes unless a tested necessity is found.
- [x] Activate the ordinary private Admin after local gates. Sign in as existing legitimate canonical Admin and verify actual screens, no Send/payment/booking writes.
- [x] Verify canonical hashes and old FYP state preserved, new records exact-owned, deployed archives/config/IAM and served assets; retain screenshots and report limitations.

### 7. Completion

- [x] Update one integration report and operational references with actual counts, existing-account access, source definitions, actual/simulated finances, screenshots, verification and remaining policy/native limits.

## Execution ledger

Ruling: user explicitly selected execution and server-authorized read-model architecture; no repeat design approval or worktree question. Reuse the dirty checkout. Do not commit unrelated work.

Baseline: actual4 November deployment has72 Functions and the expected Rules hash. Canonical source scan found8 organization memberships,3 published Coach documents,2 professional drafts,11 content documents,15 transactions and14 bookings (raw collection counts, not yet eligible-account KPIs). FYP state remains27 memberships including18 Members/8 Coaches/Admin,8 Coach publications,12 Tutorials,2 runs/12 leads/4 recipients/4 delivery receipts/3 Member action receipts/4 notifications. Program contracts use their existing physical collection names; do not infer absence from an unrelated `workoutPrograms` collection.

Local checkpoint:86 focused backend,121 Admin,14 domain and14 Mobile Program tests pass; source/test TypeScript and14-item scoped Dart analysis pass. Ordinary Admin Web build succeeds. Actual emulator6-check acceptance includes canonical Admin login/widgets, combined census/52 observations, existing queue reads, Auth/App Check/role/private Rules denials and preserved source/runtime. These are synthetic/emulator results, not live Admin acceptance.

Review: one fresh-context reviewer found five Important issues and no Critical issue. Reproduced/fixed grant adoption/ownership and staged-only activation; mixed source labels/CSV; deleted manifest source completeness and unowned notification rejection; cross-source Routine references in canonical Program writes; partial-copy Admin recovery. Tests cover all corrections. Seal includes compiled writer/operator/Admin inputs. No re-review loop or unrelated worktree reset.

Ruling: do not expand the canonical Exercise Catalog or ordinary Member/Module6 public-data exposure in this release. Supported unified Admin Routine/Program/recommendation readers use existing publications; private cohort public exposure and FYP authoring remain unsupported and are documented. No real histories enter recommendation processing.


Final checkpoint: source-only command revision fypdatasetcommand-00004-dos and232 exact-owned new documents are active. Final protected-record/infrastructure verification at2026-11-04T14:59:28.940Z passes:638 protected source/runtime records and71 other Functions unchanged; Rules/indexes/IAM preserved. Existing real Admin browser acceptance passes at7359 with22 active Members,9 active Coaches/11 directory Coaches,54 descriptive sessions,6 Programs/23 published Routine destinations and24 blueprints. Actual CSV507500 simulation/577200 illustrative minor units matches UI and contains no Member IDs. Today/90-day filters pass. Existing2 recommendation runs/12 leads and delivery state preserved; no generation/Send/provider call. Final served client79728b7b2832c922125a2b36d7d5285e561548fde2440530caee271c0fbdff1a; prior client versions preserved.

Live correction: shared exercise IDs occur in both source catalogs. Reproduced the missing-name and duplicate-identity failure conditions. Reused the existing canonical TutorialRepository for FYP Routine names without changing server collision checks;33 focused follow-up tests and scoped analysis pass. Final real Routine screen shows24 records including12 read-only FYP records. No backend/data/consent mutation was needed for this correction. Native and real-user policy gates remain held; all unsupported operations are in the integration report.
