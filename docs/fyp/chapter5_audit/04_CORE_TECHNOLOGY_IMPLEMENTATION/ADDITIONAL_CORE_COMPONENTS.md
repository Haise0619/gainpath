# Additional core components

## Local backup transactions

Cloud backup is descriptive replication. In `functions/src/modules/workouts/workout-backup.ts:43–76`, the server validates kind, owner, payload schema and base digest, computes the canonical digest and checks the current owner and scope in a transaction. An exact repeat returns success. Session conflicts and routine updates with mismatched base digest fail with a conflict result. Success preserves a revision record and a current pointer. This gives retry safety without silently merging conflicting histories. See [source excerpt](../evidence/code_snippets/backup-idempotency.md).

## Payments and booking constraints

Server payment processing separates initiation, verified provider status and fulfillment. Booking uses a transactional hold and validates time-zone-specific roster/branch availability, conflicts and capacity before creating state. Cancellation and reschedule notice rules are 12 hours and 24 hours in `functions/src/modules/coaching/member-booking-change-service.ts:14,64`. Membership refund request requires cleared payment within seven days in `membership-payment-service.ts:353–355`. Later approval and provider results are distinct. See M04 and M07.

## Activity, rewards and summaries

Member local report and Admin aggregates read compatible evidence. Workout reward admission checks saved source and published exercise eligibility. The working tree has distinct policy for AI-tracked and guided timed points. Hard-coded proposals in older documents do not represent current source. See M03, M05 and M12.

## Recommended academic figures

Choose one sequence for booking/payment reconciliation, one for offline queue/recovery and one architecture diagram showing the device/cloud boundary. The [architecture diagram set](../evidence/diagrams/SYSTEM_ARCHITECTURE.md) and module-specific figures support these.
