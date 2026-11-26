# 5.5.5.1 — Pose detection evaluation

**Status.** Physical pilot observations exist for earlier profile/debug builds. This audit did not run a new labelled pose accuracy experiment. There is no established detector precision/recall, joint-position accuracy, lighting accuracy or multi-person performance figure for the audited snapshot.

| Evidence | Observation | Interpretation |
|---|---|---|
| docs/architecture/2026-10-06-pose-live-gpu-candidate.md:61–77 | 12 matched landmark tensor input pairs, one detector input pair, 0.0008765 px maximum refined XY difference and 0.000005442 m maximum world difference. No acceptance flips or nonfinite outputs in that matched subset. | CPU/GPU agreement on sampled inference inputs. Numerical agreement is not anatomical ground truth. |
| docs/architecture/2026-10-03-pose-physical-latency-baseline.md, “Visible overlay interruption” | One visible blank around recorded frames 354–356 and a separate partly missing moving-arm sequence. | Retained positive counterexample to perfect continuity. No general dropout incidence or unique failure cause. |
| apps/mobile/test/blazepose_contract_test.dart, pose_refined_skeleton_test.dart, pose_rendering_test.dart, pose_quality_diagnostics_test.dart | Tests cover contract, mapping/refinement and rendering admission/diagnostics. | Source assertions address software behavior without labelled human accuracy. |

**Physical protocol pending.** Use a consented pilot with a stable phone and capture device/OS, app version, backend, camera/lens, framing and per-frame ground truth. Label person visible/absent, expected joints observable/occluded and whether overlay accepts those joints. In a small independent eval set, report confusion counts and $P=TP/(TP+FP)$, $R=TP/(TP+FN)$ and visible-joint detection rate. For annotated joint centers report mean absolute pixel error and a torso-normalized percentage-correct criterion with threshold registered before evaluation. Specify denominator, invalid clips, annotator agreement and uncertainty. Separate repeated display frames from independent inference records. A synthetic scene/camera fixture can support geometry QA without filling human count cells.
