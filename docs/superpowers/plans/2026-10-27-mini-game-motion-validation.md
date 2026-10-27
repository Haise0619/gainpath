# Mini-game motion validation implementation plan

Superseded before release by the owner's explicit participation-based FYP policy. The unshipped motion observer, UI and tests were removed; intermediate private logs remain retained. Continue with `2026-10-27-mini-game-participation.md`. No motion/landmark evidence collection or physical attestation is requested.

**Goal:** make physical Move & Catch testing measurable and prepare the owner-selected verification method without activating points.

**Architecture:** preserve the current pose engine, basket smoothing, game clock, local scores and optional timing-only service. Add a bounded, ephemeral on-device observer for active game intervals and fresh torso samples. Report observations separately from reward eligibility. The evidence method is an explicit owner decision because automatic remote verification would change the current movement-data boundary; do not implement dependent data upload or trusted-evidence acceptance until answered.

**Tech stack:** pure Dart diagnostics with Flutter result presentation; focused controller/widget tests. Existing TypeScript/Firebase boundaries remain unchanged until evidence selection.

**Rulings:** user requested direct execution, so implementation proceeds without intermediate design signoffs. No point-policy or release-gate changes, no new thresholds for reward eligibility, no raw-pose recording or persistence. A single live sample does not count as a tracked interval; freshness is bounded and pause/dropout time is excluded. Side observations describe local basket movement from valid torso input, not server-proven physical movement.

- [ ] Add `move_catch_motion_observations.dart`: immutable summary, active duration, fresh tracked duration, accepted sample count, partial-torso sample count, observed left/right movement and tracking interruptions. Clamp to active intervals; clear on replay; no coordinates or per-frame history retained.
- [ ] Attach observer to current controller only, leaving engine/pose/scoring untouched. Pause/background/close cannot add coverage; stale/duplicate input cannot count. Focused tests establish these boundaries and local-score independence.
- [ ] Add a compact, expandable result panel for local motion observations, explicit device-only status and no reward eligibility claim. Cover narrow/large-text layout and reset/session-loss behaviour.
- [ ] Resolve owner evidence choice before dependent verification work. Preserve timing-only upload scope while pending; no automatic physical-verified receipt can be inferred from the diagnostics.
- [ ] Run affected checks, update operational references and prepare only reviewable artifacts needed for the selected flow. Any new remote movement evidence, cloud release or APK installation needs exact release approval. No production test rounds or point transactions in local preparation.
