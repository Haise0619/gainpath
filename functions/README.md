# Firebase backend foundation

This implements the backend boundaries in `docs/architecture/2026-09-17-gainpath-target-architecture.md`.
It is a modular backend foundation, not the complete product backend. No deployment is part of this change.

## Implemented exports

`createBookingHold` is an authenticated, App-Check-enforced callable. Its V1 payload is:

```json
{
  "schemaVersion": 1,
  "requestId": "stable-client-retry-key",
  "organizationId": "org-1",
  "memberId": "member-1",
  "branchId": "branch-1",
  "coachId": "coach-1",
  "startAtMillis": 1790906400000,
  "durationMinutes": 60
}
```

The response contains `schemaVersion`, `requestId`, `bookingId`, `status: pending_hold`,
and `holdExpiresAtMillis`. The member must be active and assigned to the branch. A member can
book only for themselves; staff can book for a member in their assigned branch; organization
admins can act across branches. The coach must have active coach membership, branch access,
a published directory entry and an availability window covering the whole interval.

The server requires `settings/booking`, `branches/{branchId}` and
`coachAvailability/{coachId}/days/{YYYY-MM-DD}` under the organization. Schemas and
explicit policy semantics are in `../contracts`. There are no fallback policy defaults.
Half-hour slots are coach-wide across branches. Booking, every occupied slot, the
member's organization-wide local-date accounting, receipt and expiry job commit together.
Expired holds can be replaced immediately without waiting for TTL or a cleanup worker.
Confirmed locks are never reclaimed by expiration. Cross-midnight bookings are rejected.

Retries with the same actor, command and key return the original result, even if it is
now expired. Reusing that key with different data fails with `already-exists`. Clients
must compare the original expiry to current time; a retry does not extend a hold. Current
membership is checked again before replay. `memberId` is explicit; staff identity is
recorded separately as `createdBy`. Caller-supplied prices are not accepted.

`paymentWebhook` accepts POST only and currently returns HTTP 503 for every POST because
no real provider verifier is configured. The commerce service provides a trusted
`PaymentVerifier` interface and durable ingress implementation. It does not emulate
Billplz with a generic HMAC. A verified event and exact raw bytes are committed at
`system/paymentIngress/events/{sha256(provider,eventId)}` before acknowledgement, even
when bill mapping does not yet exist. Duplicate identical events acknowledge once;
different payloads under the same provider/event identity return a conflict. This is a
conservative byte-level replay rule: a future provider adapter must confirm its delivery
semantics before activation. Request headers never supply trusted event identity.
The 64-KiB ingress limit bounds Firestore payload size. Secrets/headers are not retained.

The workout module currently exports TypeScript contracts only, not a callable function.
`../contracts/v1/submit-workout-session.*` defines the future upload seam. Clients must
continue to fail closed until its acceptance service exists.

## Verification

With Node 20, pnpm and Java 21 available, from `functions/`:

```sh
pnpm install --frozen-lockfile
pnpm run build
pnpm run typecheck:tests
pnpm test
pnpm run test:emulator
```

The build compiles only `src/` to `lib/` and loads the actual package entry point,
`lib/index.js`. Unit tests use a transactional memory adapter; emulator tests cover
real Firestore contention, lock replacement, payment persistence, negative Rules
authorization and constrained client queries. `test:emulator` uses demo-gainpath on
isolated test ports from `../firebase/emulator.test.json`. It does not need a Firebase login.

## Remaining product gates

- Trusted provisioning/configuration commands for members, branches, booking policy and availability.
- Expiry job scheduling/worker and reconciliation; cancellation, rescheduling, completion and reviews.
- Billplz contract verification, signature test vectors, checkout mapping, settlement/entitlement
  transaction, late-payment compensation and refund/reconciliation workers. Do not activate
  the webhook before both verification and downstream reconciliation are implemented.
- Workout acceptance with ownership, consent, plausible metrics, session-level deduplication
  and atomic acknowledgement. No raw camera frames/landmarks belong in that request.
- Other module services listed in `src/modules/README.md`, operational alerts, IAM, secrets,
  retention, backup/recovery and environment-specific release gates.

Durable jobs and payment inbox rows are currently pending work records; no worker claims
to process them. Hold expiration is nevertheless authoritative immediately in allocation.
Late payment must check both booking expiry and current slot ownership before confirming.
