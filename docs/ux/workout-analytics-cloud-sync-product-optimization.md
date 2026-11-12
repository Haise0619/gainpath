# Workout analytics and automatic cloud sync — implementation

Source baseline: `0da25e9`. Implements the owner's five-phase request and [data audit](../superpowers/plans/2026-11-12-workout-history-progress-report-data-audit.md). No live deployment, real-account writes or device installation is part of this change.

## Phase 1 — local-first automatic sync

- Reused the existing shared account lease, foreground save/network/startup scheduler and Firebase callable. Committed local summaries/checkpoints plus acknowledged content baselines form the durable pending queue: a process restart rediscovers unacknowledged content without relying on in-memory notifications.
- New result-status composition acquires the same account-scoped coordinator; the summary never awaits network initialization. Status is based on the current summary digest or an exactly matching routine snapshot, never on workout acceptance/rewards or a global last-success time.
- Consumer states: Saved on this device, Syncing, Synced, Sync failed — Retry. Conflicting copies retain local data and ask for review. Disabling future sync preserves confirmation of an unchanged existing cloud copy; changed content is not marked synced.
- Added a backward-compatible optional `consentChoiceMade` metadata field. A new store can offer informed setup; any legacy persisted preference is treated conservatively as an existing choice. Neither camera consent nor a new screen enables cloud sync. Existing disabled preferences remain disabled.
- All supported AI, timed, manual and checkpoint writes continue to use the existing durable stores and save notifications. Scheduler refreshes its local view even without network/opt-in; bounded retries, foreground lifecycle and account guards remain.
- Program journals are not accepted by the deployed session/routine-only backup contract. Restored routine results remain reviewable; resume is fail-closed when scheduling provenance is unavailable. Full Program recovery remains unsupported. A future negotiated envelope/kind must add versioned Program journals, dependency ordering, CAS restore and old-client filtering before enabling schedule restore; no existing cloud record is rewritten here.

Verification: 39 focused sync/store/scheduler/integration tests passed, including startup without Progress, offline retries/restart, duplicate opportunities, in-flight opt-out/account switching, receipt matching and restored summaries. Scoped analysis and Flutter render evidence are recorded per phase in the final verification section.

## Phases 2–5

Implementation and integrated verification in progress; this section will be replaced with completed outcomes and exact commit evidence.

## Phase 2 — consumer workout summary

Added a shared purple/ivory completion header, responsive activity facts and expandable exercise cards used by both the live journey summary and saved routine results. AI reps, timer-recorded sets/time and self-reported sets remain separate. Cards expose only linked, matching-account exercise assessments; individual result routes retain original movement evidence and put model/identity/upload verification behind Technical details. No unrelated scores are averaged. Lateral Raise/Shoulder Press show assessment unavailable, never legacy 0%; historic assessed Wall Push-up data remains inspectable.

The primary summary no longer leads with reward/acceptance internals. Completion motion is finite and respects reduced motion. Elapsed time is disclosed separately because it includes breaks/time away. The existing workout continuation, partial/skipped statuses and safe resume/repeat actions are preserved.

Verification: 26 summary/history/mixed/continuity tests passed (including 5 new product tests); six-file analysis clean. Actual 390dp Flutter summary render inspected against the before image. The first run exposed stale copy assertions and an offscreen test finder, corrected without dropping evidence assertions.
