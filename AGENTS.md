# GainPath development guide

Start with [README](README.md) and [current status](docs/STATUS.md), then the relevant [architecture](docs/ARCHITECTURE.md) or [operations](docs/OPERATIONS.md) section. Historical plans are evidence, not current task instructions. Read original FYP requirements when changing requirement behavior; the [archive index](docs/archive/README.md) locates them.

## Authority and approvals

The current task's scope takes precedence over these defaults. Documentation Phase 1 and the local backend-selection batch are complete. Obsolete Markdown pruning is separately owner-approved; this does not authorize source removal, build artifact cleanup, cloud/pilot deployment or device changes. Removed-document replacements are listed in the historical index.

- **Normal local development:** when requested, proceed with implementation, refactoring, analysis, focused builds/tests, read-only inspection, mock/emulator work and active documentation. Choose routine details without repeatedly asking permission.
- **Review before release:** complete local work and affected checks, then present the concrete changes/artifacts and release scope for review.
- **Explicit owner approval:** cloud deployment/removal; Rules/indexes/IAM; migrations, bulk/destructive data changes; payment/refund/provider operations; financial configuration; secrets/credentials; account/role changes; destructive device actions; Google automation expansion; application publication/installation outside an already approved scope.
- Apply existing approvals within their exact actions, targets and limits. Reconfirm only when authority is missing or the scope materially changes. Approval of local code does not approve cloud, financial or personal-data mutations.

## Essential working rules

- Inspect and reuse existing implementations. Both normal app entrypoints initialize Firebase directly; there is no runtime backend selector or seeded Mock composition. Use `.injected(...)` explicitly for tests, with seeded app graphs confined to test/support. Never recover Firebase initialization failure with sample data. Preserve per-app App Check security inputs; see architecture and operations.
- Preserve unrelated tracked/untracked work. Do not reset, clean, stash, broadly stage or overwrite it to simplify a task.
- Preserve Auth, email verification, App Check, role/organization/ownership checks and session isolation. Sensitive totals, membership settlement, reservations and accounting stay server-controlled.
- Financial success requires verified clearance, idempotency and reconciliation. Refund approval is not money transfer. Do not invent prices, benefits, recurring billing or access restrictions; current holds and exceptions are in STATUS.
- Keep frozen workout/pose/counting/scoring/audio/consent/history behavior unchanged unless explicitly authorized.
- Keep private fixtures, tokens, screenshots and device/session backups out of source control/public reports. Ignored `build/` paths contain protected evidence and authored tools; no blanket clean, move or deletion without a reviewed retention scope.
- Use focused affected-module checks for routine changes and broader gates for integration/release. Never report historical or unrun tests as fresh passes.
- Keep completion reports concise: changes, verification, material risks/blockers, and the next approval action if any. Update the six operational references and the requested docs/PROGRESS_REPORT.md when their facts change; do not create a long new report for every small task.
