# B4 — Pending hold cancellation and expiry

Approved starting point: B3 `9a960d106e12fd469a9a09acb12a9e1081b04a65`. Source only; no push, deployment, live mutation, provisioning or device installation.

## Bounded decisions

- Current verified, active Members cancel only their own pending holds. Coach/Admin lists read the resulting state. Paid/confirmed/completed/refunded booking policies remain outside this slice.
- Server time decides `cancelled` before the hold deadline, or `expired` at/after it. Phone time never changes persisted status.
- Reuse existing bookings, expiry jobs, slot locks, daily accounting and command receipts. An immutable cancellation request ID supports uncertain transport replay after current authorization is checked.
- Transactions release only matching pending resources. Cancellation marks owned lock expiries elapsed; existing allocation already treats those locks as free. Expiry needs no lock deletion. Foreign replacement locks and other reservations remain intact.
- Retain booking records and original creation receipts. Optional resolution metadata and the `expired` enum extend schema version 1; deploy compatible readers before enabling the worker. No historical migration.
- A bounded scheduled worker processes due pending jobs. Malformed ownership fails closed; no speculative cleanup. Scheduler IAM, index deployment and real triggering remain separate activation gates.

## Implementation and verification

1. Backend: shared stored-record validation, Member cancellation callable with App Check, atomic lifecycle service, scheduled expiry adapter/index. Deterministic tests plus real Firestore contention/replacement checks.
2. Flutter: pure-Dart cancellation port and terminal-state contracts; guarded Firebase adapter; Member confirmation/retry and refresh; truthful read-only Coach/Admin status. Preserve mock behavior.
3. One synthetic Coach → Admin → Member SDK smoke, essential regression/analysis/architecture checks, final source review, evidence report and local commits.

Essential cases: ownership/current authorization, duplicate/reused IDs, expiry boundary, confirmed protection, missing/corrupt documents, cancellation/worker contention, late jobs after slot reuse, preserved unrelated accounting, stale session responses and original receipt semantics.

## Activation restrictions and known debt

No B3/B4 live capability is claimed. Before coordinated activation: review B1 malformed timestamp and B2 malformed lock-status debt; approve resources/indexes and App Check; provision a real Coach explicitly; verify scheduler service-account invocation and retry behavior; smoke the three-role UI against the intended environment. Existing CanvasKit integration limitation is not expanded under B4. No changes to payments, confirmation, pose, exercise bindings, workout acceptance/history or consent/outbox.
