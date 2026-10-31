# Member Progress presentation refresh

Local preparation only. No installation, deployment, content or account writes.

The former overview was a stack of similarly weighted panels: weekly values had little emphasis, source caveats competed with the next action, and Form/Points/Backup navigation was hidden inside Measurement details. The existing report timeline, account guards, goal comparisons and program schedule already supply the required facts; this refresh reuses them.

## Main page structure

1. Purple This week hero: distinct active training days, completed/scheduled calendar workouts and their adherence percentage. Loading, failed or absent denominators remain unavailable; zero scheduled workouts never imply 0% or 100% adherence. No streak is invented.
2. White Current program card: program name, program week when scheduled, calendar completion bar, actual next-workout/rest state and View program. Past programs and full day status remain expandable.
3. Start workout action, then compact Goal summary with current/target/remaining facts and View/edit entry. Profile weight stays self-reported with an unknown measurement date and no implied direction or progress percentage.
4. Three recent chronological, deduplicated activity rows with timestamp and source badges. Existing detail callbacks are retained.
5. History, reports, Estimated Form Scores, Points and Backup stay outside collapsed Measurement details. Measurement explanation and detailed performance remain secondary.

## Reuse and review scope

Changes stay in the overview, program host, compact goal mode and optional presentation callback plumbing through the dashboard/live route. Legacy summary callbacks remain supported. Malaysia calendar boundaries, training-day eligibility, timeline dedupe, account scope, stale reads, report filters, PDF exporter, backend contracts, rewards and full report calculations are unchanged.

Purple uses the existing GainPath token. White card headings use explicit dark ink; the hero uses explicit white text. Natural-height rows and wrapping labels support 320px screens and enlarged text without a fixed-height grid.

Validation: widget regression first failed on the missing Adherence field. Scoped widget checks cover narrow 320px/1.6x overview, 320px/2x program, real manual/camera rows and callbacks, source semantics, loading/error/account replacement and denominator/zero-schedule presentation. Root coordinator performs final focused suite, analysis, architecture and Android build. Physical visual acceptance remains pending.

Final verification:68 combined affected tests pass, strict scoped Flutter analysis clean, architecture passes and Android profile build/signature verified. Exact evidence: `build/progress-sporty-redesign-20261030/verification.json`. No install/deploy/live writes. Xiaomi appearance, real large-font scrolling and comparison with the visual reference remain pending on the new artifact.
