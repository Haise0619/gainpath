# 5.5.5.3 — Posture correction evaluation

The product reports provisional geometry-derived estimates. It has no recorded labelled human posture accuracy benchmark for the inspected snapshot. Floor right-side review exposed earlier score/cue conditions and two incomplete extension examples. Current software thresholds and cue delivery policy have changed since that review. Historical display, correction decision and audio delivery must be attributed to specific builds.

| Evidence | Scope |
|---|---|
| packages/gainpath_pose/test/floor_push_up_release_acceptance_test.dart, floor_push_up_projection_test.dart, floor_push_up_recovery_test.dart, squat_analyzer_test.dart | Scripted faults, partials and false-motion/valid-recovery behavior. |
| docs/integration/standard-floor-push-up.md:140–155 and docs/integration/floor-push-up-physical-acceptance.md:42–49 | Owner had not completed whole set. Physical form-score correctness and full save/reopen remain open; older feedback was judged late/confusing. |
| 04_CORE_TECHNOLOGY_IMPLEMENTATION/POSTURE_CORRECTION_AND_SCORING.md | Form rules and scoring mechanics, with current geometric and version limits. |

For each exercise, register observable labels (e.g. adequate depth, limited extension, lean or sag/pike) and blind a second reviewer to system output. Annotate valid/invalid/ambiguous frames and event windows. Use per-fault TP/FP/FN, confusion table and median cue deviation across agreed comparable attempts. Report app score availability and provisional distribution by rule version; include separately a blinded observer agreement score if available. Where occlusion/recovery makes score unavailable, track abstention rate and reason. Shoulder Press and Lateral Raise evaluate setup/tracking guidance and cycle classification. They do not supply form accuracy percentages. No clinical inference follows from a high app score.
