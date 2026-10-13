# Step 7A/7B execution ledger

Scope approved by user: implement attempt explainability and estimated 3D
comparison from the existing plan and reviewed external advice. Software/test
work only; do not install APKs, run phone trials or change production decisions.

BASE: codex/real-squat-flow at 758fa83. Preserve unrelated dirty files.
Ruling: reuse the established shared codex checkout — current integration and
ownership are already coordinated; a new checkout would omit unrelated local
reference evidence. Restrict edits/staging to the listed core/test/docs files.

Design: optional concrete bounded diagnostic recorder in the pure analyzer,
attached by a non-release mobile flag. It receives scalar observations and
terminal outcomes at existing decision boundaries, including aborted cycles.
No replacement FSM, no diagnostic callback controls decisions, no raw coordinate
history, no upload/result schema changes. Keep baseline thresholds/filtering.
World geometry is a separate pure helper added in 7B; compare raw and filtered
same-frame/same-side values, returning unavailable explicitly.

- [x] 7A: red tests, bounded recorder, minimal analyzer hooks and guarded mobile
  emission; verify exact baseline output parity, loss/abort/dwell/capacity/privacy.
- [x] 7A: verify, record evidence, commit and push.
- [ ] 7B: red analytic/invariance/invalid/identity tests; world geometry and bounded
  same-frame raw/filtered comparison summaries, no impact on 2D decisions.
- [ ] 7B: verify pure/mobile suites and analysis; one independent whole-change review.
- [ ] Prepare protocol with fixed independent depth labels, event matching,
  correction precision/recall separate from audible delivery, coverage/abstentions,
  responsiveness/stability and explicit limits on angle ground truth.
- [ ] Preserve/hash a separate profile diagnostic artifact; record example output,
  changed files, tests and limits; commit/push and stop for review before device work.

Depth annotation ruling: current rule semantics remain knee <=90 degrees sustained
150 ms. Any task-quality definition (e.g. hip-height relation) is a separately
declared label, not automatically equivalent or a reason to change thresholds.

7A evidence: missing recorder/analyzer contract and missing mobile guard produced
red tests. Pure recorder hooks then passed 33 focused tests; full pure suite 61
passed. Enabled focused mobile suite 22 passed. Changed-source analysis clean after
fixing 10 brace lints. Replay compares all baseline state/cues/geometry/attempt
facts at every frame; includes loss, pause, watchdog and frame-gap aborts.
Retention 64 by default (hard max128), terminal summaries only. Failed log sinks
cannot interrupt analysis. Timing excludes terminal JSON/log emission, and idle
emission avoids copying retained records. Mobile close clears buffers; scope change
suppresses previous-account emission. Default suite: 258 passed, 15 optional skips.
Product-mode guard tests with the diagnostic define set: 2 passed, recorder and
emission disabled. These are compiler-guard checks, not a release-device trial.
No result/upload schema or acceptance policy edits. One whole-change independent
review follows 7B.
