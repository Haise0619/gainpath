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

## Phase 3 — routine-centered History and meaningful Progress

History now defaults consistently to Routines; its AI-only tab is named AI Sessions. Routine cards include mode-aware activity summaries and use the shared, read-only sync coordinator for per-content status. Date (7/30/all) and completion filters compose; both tabs remain mounted to preserve navigation context. Dates default to 30 days throughout detailed analytics.

Progress uses workout-centered recent cards, retaining unlinked AI captures but hiding linked captures from duplicate top-level activity. Workout start days use saved routine starts (standalone capture starts only when not represented by a known routine); empty attempts do not count. This is explicitly not a reconstructed active-time calendar. Activity trends is a direct primary link and includes completed routines, recorded video time and manual sets, with AI-only charts clearly scoped. Scheduled completion identifies the full-week denominator, including upcoming slots; numeric goals retain their existing UTC semantics and display them explicitly instead of silently changing a contract.

Curl arm mode is read from existing summary evidence, carried in the progress DTO, included in comparison keys and shown in comparisons/form groups. Left/right/both/unknown remain separate; no historical values are invented. Technical versions and workout verification states remain inspectable behind details. Single-day names reuse one domain title helper.

Verification: 43 focused Mobile tests plus 36 Domain tests passed; 19-file scoped analysis clean. Actual History/Progress Flutter renders inspected. A broader analytics directory scan also reported a pre-existing coach earnings style info; final scoped analysis excludes that unrelated file. No scoring, scheduling backend or Firebase schema/formula was changed.

## Phase 4 — mixed-workout report and PDF

Report now leads with whole-workout completion and separate AI, Video Timed and Manual sections. AI reps/time come only from capture records, timed sets/active time only from guided records and manual sets only from self-reports. Primary activity is routine-centered; all matching captures and exercise breakdowns remain available without being double-added to totals. Internal IDs and detailed record/state metadata live in the technical section. Reset and direct entry use 30 days; inherited filters and immutable export snapshots are preserved.

PDF adds a useful mixed-evidence summary and assessment scope/method before the technical appendix. The native renderer places charts between that summary and appendix, adds section typography and a consumer header/footer, preserves wrapping/pagination/cancellation and keeps its legacy seven-line layout for old payloads. Friendly chart labels retain separate compatible groups; rule/model/arm evidence remains in the appendix. Member attempt-weighted/local scope versus Admin session-average/cloud-backed scope is explicit; Admin contracts are unchanged.

Verification: 32 report/export/route tests passed, including coherent four-mode fixtures, missing scores, large output, matching filters/chart points, export failure/cancel/retry and account drift. Three-file analysis clean; actual report Flutter rendering inspected. Native PDF compilation is covered by the final Android build; device PDF picker/render/open acceptance remains pending, not inferred from widget tests.
