# Platform boundaries

- `command.ts` defines the versioned transport envelope; `validation.ts` parses the live
  booking command, rejecting unknown fields and unsafe Firestore path identifiers.
- `auth-context.ts` evaluates authoritative membership snapshots, never role hints or stale
  custom claims. Commands read these inside their transaction so suspension races retry.
- `errors.ts` contains transport-independent failures. Callable/HTTP handlers map them to
  Firebase/HTTP errors without returning database exceptions or payloads.
- `idempotency.ts` hashes unambiguous tuples. Receipt identity includes command and actor;
  fingerprints include the entire validated payload. No untrusted ID is interpolated into
  a document path without validation or hashing.
- `firestore/store.ts` is the transaction port. `firestore/firestore-store.ts` is the sole
  concrete database adapter. Server SDK access bypasses Rules, so services always authorize.

Transaction callbacks can run repeatedly. Read before writing; keep network/provider calls
outside them. Commit processed markers with effects, not separately. An external API call
requires durable operation state, provider idempotency if available and reconciliation of
uncertain outcomes. A payment provider verifier is a trusted commerce port; only a reviewed
adapter with provider test vectors may implement it in production.

Future worker adapters own bounded retries/leases and operation version checks; Scheduler
reconciles missed scheduling. TTL only removes obsolete data, never establishes expiration.
Future observability should correlate command/booking/session/job IDs and log safe error
codes; never raw request bodies, tokens, payment secrets or biometric data. FCM is a delivery
hint backed by durable inbox records. IAM, secrets and environment selection are deployment
concerns, not values supplied by clients.
