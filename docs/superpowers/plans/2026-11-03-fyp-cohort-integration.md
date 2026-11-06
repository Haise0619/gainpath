# Authorized FYP cohort integration implementation

**Spec:** `C:/Users/Ngzhe/.codex/attachments/c2e1a2ec-73a0-4b98-8f04-ce33b4e68ddb/Pasted text.txt`.

The owner selected the reviewed cohort namespace and explicitly requested implementation now. No further design/implementation approval gate; no live action is authorized. Reuse the current dirty checkout and preserve the previous verified checkpoint.

**Design:** One physical `orgs/gainpath/cohorts/fyp-v1` graph inside `(default)`. Global server-owned `datasetAssignments/{uid}` binds Auth creation identity, role, revision and cohort. Demo identities have no canonical global users/membership; old services deny them. A fresh Auth/App Check resolver mints an immutable effective scope. Logical domain paths remain `gainpath`, with a typed store/query mapper, not an altered organization ID. Ordinary apps carry a verified dataset scope through existing composition and query the authorized root. All real-user paths and composition remain unchanged.

**Synthetic evidence:** Separate owned observations with `fictional_synthetic` outer provenance and `recordedFixture` summary. Factor common shape/aggregation logic without changing camera backup acceptance. A server capability admits these records only through the cohort reader. No realCamera relabeling, accepted workout, SQLite overwrite, points or real provider inference.

**Parallel ownership:** dataset/seeder; Flutter scopes/ordinary composition; additive Rules/security tests; coordinator auth/provisioning/store/observation/recommendation backend + integration. Skill-directed independent domains use shared contract messages; no concurrent edits to the same owned files.

## Review focus

- Assignment revocation/change or stale/disabled/recreated Auth must invalidate reads and commands, including after queries.
- Old clients must never enroll assigned actors into canonical membership; existing real registrations remain Member-only.
- Private source histories must not reach Admin clients; queries/denominators stay within one scope and fail without partial output.
- Synthetic observation projection must preserve null/unscored/compatibility/dedupe/date semantics and never pass normal camera acceptance.
- Ordinary app DI and current destinations must work through the verified scope, not historical demo app shells; no client flag grants access.

## Tasks

- [x] Capture prior checkpoint baseline; implement scope/auth/provisioning and capability tests first.
- [x] Implement scoped store/query adapters and additive Rules, cross-cohort private/public/Admin tests.
- [x] Complete coherent source graph, Programs and emulator-only idempotent seed/ownership/cleanup planning.
- [x] Implement truthful observation validation, shared evidence/analytics aggregation and read-only Member progress source.
- [x] Reuse A1–E services for scoped evidence→need→ranking→queue→send→delivery/current destinations.
- [x] Wire ordinary AuthSession/SessionScope, repositories and original Admin/Member composition.
- [x] Run actual Auth/Firestore/Functions default-emulator acceptance, ordinary Flutter repository/widget integration, privacy negatives and screenshots.
- [x] Run focused regressions/analysis, review preservation, update module coverage and exact live preflight; stop before live changes.

Completed local acceptance on 4 November 2026: 703 backend / 242 Flutter regressions / 32 actual emulator suite checks, including two passing ordinary-app widget journeys and 13 screenshots. Strict changed-file Dart analysis and source/test TypeScript checks pass. Exact evidence and source preservation: `build/fyp-cohort-integration/verification.json`. Current report: `docs/integration/gainpath-fyp-cohort-integration.md`. Replacement live preflight is review-only; production execution, native UAT and real-user processing remain gated.

Verification: focused Vitest/TypeScript; cached dedicated emulator `demo-gainpath-fyp` (Auth19131, Firestore18231, Functions15031); Flutter widget/emulator clients and analysis. No APK or unrelated full suite. Existing Gemini evidence/attempt ledger remains unchanged.
