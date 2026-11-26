# 5.5.5.2 — Repetition counting evaluation

**Status.** Implemented, with deterministic analyzer trajectories and retained physical observations. Physical repeatability and event-level accuracy remain to be measured across six current tracked exercises.

| Evidence, with boundary | Observed result |
|---|---|
| docs/architecture/2026-10-12-squat-fixture-validation.md:79–101 | Analytic 72-frame CLI fixture, expected 1 full and 0 partial, observed matching totals. Supplied delivery age 20 ms. Earlier software report recorded 57 pure tests passed including 11 evaluator/CLI cases. |
| docs/integration/standard-floor-push-up.md:130–149 | Retained right-side debug sequence yielded five counts and two observed correctly rejected partial threshold cases. Left view was explicitly untested, full-session acceptance remained open and the same report retains an unresolved interruption. |
| packages/gainpath_pose/test/squat_fixture_evaluator_test.dart and floor_push_up_fixture_evaluator_test.dart | Fixture evaluator tests validate parse, scoped aggregate outputs, threshold/trajectory handling and synthetic expectations. |
| packages/gainpath_pose/test/support/ | Constructed Left/Right, phase timing, visible-foot arc, projection and continuity samples exist. An optional local replay is evidence only when an attributable input/result is retained. |

Constructed frame cases and source-defined score thresholds cannot supply ground truth for people. Record side-specific valid, partial, interrupted, fast and stationary/noise trials on the released test artifact. Have an independent observer label start, deepest/peak position and return, record an agreed matching tolerance and evaluate events, not alone clip count totals. Per clip use signed error $n_{\mathrm{app}}-n_{\mathrm{label}}$, MAE across clips, false/missed event counts and a full/partial/invalid confusion matrix with an explicit unmatched category. Do not infer TP/FP/FN from equal totals. Include missed, disqualified, censored and recovery-event observations.
