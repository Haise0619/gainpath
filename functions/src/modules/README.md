# Module ownership

The ten backend capabilities cover the thirteen product modules in the target architecture.
They share one deployment/codebase; they are not thirteen placeholder services.

| Capability | Owns | Foundation status |
| --- | --- | --- |
| Identity | User profiles, organization membership, roles, invitations, verification, suspension/deletion | Current membership authorization and Rules; lifecycle commands deferred |
| Workouts | Accepted workout/mini-game summaries, history, consent references | Versioned workout submission contract; acceptance deferred |
| Coaching | Availability, slot allocation, bookings, notes, completion/reviews | Transactional create-hold service and Firestore adapter |
| Commerce | Checkout mapping, verified settlement, entitlement/refund/commission state | Trusted verifier port and durable payment inbox; live provider disabled |
| Rewards | Attendance, points ledger, badges, stock, voucher issue/redeem | Responsibility reserved; services deferred |
| Content | Published exercises, routines, equipment, announcements, disclaimers/settings | Published reads; trusted authoring commands deferred |
| Analytics | Versioned progress, coach/branch aggregates | Scoped reports read boundary; projections deferred |
| Recommendations | Rule scoring, evidence, leads, approval and dispatch | Deferred |
| Assistant | Authorized context, LLM responses, conversation ownership and usage limits | Deferred |
| Notifications | Durable inbox, preferences, FCM/mail delivery and retries | Recipient-only inbox reads; workers deferred |

Handlers translate transports and errors. Services enforce ownership/invariants and use
ports; only adapters import Firestore. A service never calls another module's HTTP handler.
Cross-module immediate invariants belong in one transaction coordinated by the operation
owner. Delayed effects require a durable job/inbox entry committed with the source state.

Other modules cannot write coaching locks or commerce settlement records independently.
Future confirm/cancel/reschedule/expiry commands must update booking, locks and daily
accounting atomically. An expiry worker may release a slot only if that lock still belongs
to its booking; it must not delete a newer replacement. Payment reconciliation must check
provider bill mapping, amount, currency, expiry and lock ownership and atomically commit
its processed marker with the state transition. Unknown mappings remain durable/retryable.

Module-specific policies stay with the module. Add concrete folders only when implementing
their first operation, with bounded schemas and appropriate authorization tests.
