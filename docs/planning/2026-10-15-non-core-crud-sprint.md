# Existing non-core CRUD reliability sprint

Approved task: user attachment10201399-a45e-4e71-8761-12985002e626, 15October2026. Source baseline6dd91d90980dcd351b9f3aec297f0e885aa60b30, codex/real-squat-flow. Preserve66 pre-existing dirty/untracked files by byte hash. [Implementation matrix](../architecture/2026-10-15-non-core-crud-matrix.md) inventories source/FR/live evidence; historical reports remain intact.

## Binding scope

Reuse existing UI and repositories, remote paths and command contracts. No new schema or parallel business modules. Freeze pose/model/filter/scoring/workout acceptance/history/consent/outbox/Step7C, tutorial activation/media/anchors and trusted booking algorithms/performance. Do not deploy resources or install phone updates in this sprint. Do not mutate personal values or protected content without exact additional authorization. Existing original live Functions/Rules/indexes/Storage/identities/booking records must remain unchanged.

## Bounded increments

1. **Catalog:** retain existing guarded C/R/U/Active↔Draft implementation. Pin truthful Firebase preview (activation is publication eligibility, not immediate Member visibility; no unsupported preview metrics). Run existing conflict/create/mock/authorization tests; actual UI CRUD only on a clearly identified isolated test record, retaining it inactive. Never touch the existing squat/media anchor.
2. **Routines:** add an opaque nonserialized immutable original edit baseline, using the catalog's existing pattern. Existing Firebase adapter transactionally compares original document/assignment/membership and updates only intended fields plus existing updatedAt/updatedBy. Never silently rebase during retries. Preserve stable exercise IDs/targets/order and existing create/mock behavior. UI disables stale save, offers discard/reload, blocks duplicate pending save, sanitizes errors, and explicitly distinguishes save from publish. Do not add archive/withdraw/assignment or reorder controls that do not exist.
3. **Member profile/preferences:** preserve existing schema and supported fields. Original form baselines, patch-only transactional save, authoritative read-back, active-scope invalidation; narrow Rules owner checks deny old active membership after canonical reassignment. Synthetic values/emulator only until exact owner-approved live values and before-state are available. Preserve notification/voice semantics; saving booleans does not mean delivery is implemented.
4. **Existing unsupported-flow honesty:** after first three increments, wire the already existing Admin reset UI to Firebase Auth if its missing callback is confirmed; gate legacy Firebase routes that can show mock checkout success. Correct stale Coach availability/booking unavailable copy. No new commerce/analytics/rewards/chat services or dashboard redesign.

## Essential verification and handoff

- TDD regressions target real preservation/concurrency/authorization/false-success defects; one representative UI smoke per changed workflow, no repetitive presentation suites.
- Relevant domain/data/identity/Admin/mobile tests, backend/emulator Rules/publication tests, architecture and maintained-source analysis; one full exact-head CI after bounded reviewed commits. No broad suite repetition after minor edits.
- Isolated demo-gainpath Firebase SDK/emulator writes are not live verification. Record actual browser-emulator UI separately from transport tests.
- Live Catalog C/R/U/deactivate can use a new isolated development record and preserve its metadata; retain inactive rather than hard-delete. Routine live publication needs an agreed retention/withdrawal plan because the current contract has no withdraw/delete. Never create disposable public routines and silently delete server-owned content to clean up.
- Member live tests require exact approved values and a private before snapshot. If no updated-phone installation is approved, do not claim current-device validation of later source repairs.
- Commit only owned source/test/docs paths in reviewable increments; preserve all unrelated files. New Rules source is not deployment approval. Report exact executed checks, failures, untested boundaries and remaining scope; stop before a new business module or live activation.
