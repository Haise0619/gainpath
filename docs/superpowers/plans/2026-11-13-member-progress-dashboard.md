# Member Progress dashboard implementation plan

**Goal:** Implement the owner's specified compact fitness dashboard directly.

**Architecture:** Presentation-only read models reuse account-scoped saved records and existing report compatibility keys. No pose algorithms, persistence, sync or backend changes. Existing routes remain authoritative.

**Design:** Purple weekly activity/one seven-day indicator → compact same-week activity rows → latest valid form results → existing goal summary → one latest workout. Training plans retain schedules. Secondary actions retain reports, backup and measurement information. Missing activity is an invitation, not a wall of zeroes. Use existing GainPath colors, natural card heights, visible chevrons, 48dp controls and reduced-motion support.

**Constraints:** Preserve all unrelated working changes, records, account isolation and membership gates. Never synthesize improvement across incompatible exercise/rule/detector/view/arm-mode keys. Routine activity uses its saved completion/update timestamp, matching reports, and is labelled. Screenshots use synthetic local fixtures only.

## Tasks

- [x] Capture actual baseline Flutter renders before changing production UI.
- [x] Add failing regression tests: hidden empty schedules; consistent Malaysia week boundaries; latest valid assessment and compatible comparison; one latest workout; retained callbacks; narrow screens and 200% text.
- [x] Implement compact overview, read-only summary model, secondary assessment/measurement views and summary-only program composition. Retain detailed Training Plan behavior.
- [x] Compact goal presentation without changing goal calculations or their UTC semantics.
- [x] Run affected tests and analysis, render and inspect 320/360/390 widths at 100/150/200%, build Android Debug, review and commit only scoped changes.

## Review focus

Foreign account and future records must never enter summaries. Malaysia Monday midnight must not leak prior-week timed/manual activity. Unscored newer sessions must not conceal the last valid assessment. Unsupported scores must not appear scored. Missing routine history must remain distinct from no activity. Large text must wrap and actions remain reachable. Technical details must remain accessible in secondary views.
