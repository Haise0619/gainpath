# Single-booking Google UAT scope — local patch

Deployment update: owner subsequently approved the two-Function disabled deployment. It completed and verified successfully; see automatic-google-scope-deployment-2026-10-22.md. Earlier local-only statements below describe the pre-deployment checkpoint. Automation remains disabled.

Owner approved local scope hardening and focused tests only. No deployment, IAM changes, activation, booking creation, payment, Calendar write or email attempt performed.

## Enforcement

Automatic delivery now requires an exact organization, exactly one configured recipient, valid nonempty test Coach ID and test booking ID, and valid activation cutoff. The event's canonical booking IDs must match; booking createdAtMillis must be an integer at or after the cutoff and no later than the event. Existing event-time cutoff, stale-event/revision, paid Sandbox proof, identity, receipt, lease and grant guards remain intact.

Worker scope filtering occurs before constructing the Firestore store/services, so other Coaches, other booking IDs and historical bookings are ignored without provider calls or Firestore status/receipt writes. Current configuration is rechecked before each provider request; changing the approved booking scope during Calendar lookup blocks mutation and subsequent Gmail. Missing filters and multiple recipients fail closed.

New configuration fields read from server environment only:

```text
GOOGLE_BOOKING_AUTOMATION_TEST_COACH_ID
GOOGLE_BOOKING_AUTOMATION_TEST_BOOKING_ID
```

Both default to empty (no automatic delivery). No placeholder IDs or enabled settings were written to any environment file. Shared status is enabled only when the full controlled scope is valid; otherwise remains disabled.

## Files and checks

Changed source: automatic-google-delivery.ts, automatic-google-worker.ts, google-automation-config.ts, google-gym-connection.ts in functions/src/modules/coaching. Updated tests: automatic-google-delivery.test.ts, google-automatic-enabled-worker.test.ts, google-automatic-worker.test.ts.

Watched the three new scope regression cases fail before implementation, then pass. Final targeted backend run: 44 tests passed across seven files, covering automatic orchestration/real handler with mocked providers and existing manual/provider/connection contracts. TypeScript build and test type-check passed. No full suites or new Flutter tests/builds needed; no Flutter source changed. Node 24 locally versus configured Node 22 deployment remains a limitation. Real deployed scope UAT remains pending.

## Next separate approval

Propose deploying only `synchronizeGoogleBooking` (scope enforcement) and `googleGymConnectionCommand` (complete-scope status), still with enabled=false, timestamp absent and recipients empty. No new IAM, OAuth scope, secret or collections required. Existing deployed worker remains its prior revision, disabled; local patch does not establish live scope enforcement yet.

```powershell
pnpm exec firebase deploy --project gainpath-0619 --only 'functions:synchronizeGoogleBooking,functions:googleGymConnectionCommand' --non-interactive
```

Do not run without approval. This updates the existing retry-enabled worker; if Firebase requests a separate acknowledgement or other unexpected requirement, stop and report. Read back disabled settings and preserved private worker IAM after deployment.

Only later, with authorization to prepare a test hold, obtain a fresh disposable booking ID and exact UTC T0; present the fully populated activation configuration from automatic-google-controlled-activation-proposal-2026-10-22.md for separate activation/send approval. Existing historical booking IDs remain excluded. Never complete a payment merely to obtain a preview or infer activation approval from deployment approval.
