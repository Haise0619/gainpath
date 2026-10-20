# Step 5: consent and trusted measured-session sync

User authorizes autonomous implementation, parallel backend work, scoped commits
and pushes. Finish the real squat boundary without enabling an unvalidated model.

- Existing chat owns authenticated transaction services, callable exports,
  exact contract validation and emulator/rules tests. No deployment there.
- This chat owns a separate bounded v2 outbox and server-consent cache. Never
  convert legacy, mock, fixture or local-only pre-consent sessions to eligible
  uploads. Server acknowledgement must precede capture; no client grant is minted.
- App-private scoped atomic state includes immutable requests, validated receipts
  and explicit pending/retryable/rejected/accepted status. Stable IDs survive
  restart and response loss. Network calls do not hold local storage locks.
- Revocation disables cached consent and blocks old pending uploads immediately,
  then retries the bounded server command. Delayed responses cannot re-enable
  locally revoked consent or publish state to another account.
- Optional server upload opt-in in prep; failure keeps capture local. Result and
  history expose sync status, bounded retry and revocation without fake rewards.
- Production server policy remains empty until labeled physical quality evidence.

Verification: test-first consent chronology, DTO/receipt bounds, durable restart,
  idempotent payloads, transient/permanent errors, revocation/account races and UI
  status. Run full mobile/pure/backend suites, source analysis and profile build.
  Review independently, then commit and push each coherent step.

Completed implementation and verification are recorded in
`docs/architecture/2026-10-12-step5-mobile-sync.md` and the backend handoff.
Physical model acceptance and live deployment are separate remaining boundaries.
