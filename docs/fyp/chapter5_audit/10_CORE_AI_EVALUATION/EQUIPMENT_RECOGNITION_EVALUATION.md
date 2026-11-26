# 5.5.5.7 — Equipment recognition evaluation

**Objective:** measure vision classification, catalogue resolution, and human-confirmed navigation separately. **Available evidence:** scanner callable fixtures, pure matcher fixtures, camera platform fakes, injected widget catalogue and a historical text-only generic service diagnostic. No labelled equipment-photo collection or observed real-image pipeline outcomes were located.

| Evidence level | Observed outcome | Academic interpretation |
|---|---|---|
| Historical local checks | 24 scanner backend cases and 18 matcher cases passed; the historical report identifies 17 camera-enabled scanner widget scenarios among its broad 555-pass/15-skip mobile run. | Firestore/provider and native camera fakes validate shape, caps, errors, catalogue selection and navigation logic. They cannot measure recognition sensitivity. |
| Historical deployment diagnostic | A text-only structured JSON request returned 200 using the configured Flash Lite model, and callable deployment was read back as active. | Provider/key and deployed callable configuration were exercised at that checkpoint. No real image entered that diagnostic. |
| Current device/safe evaluation | Not Executed. | Android permission/capture → multimodal result → active scoped item → confirmation/detail remains pending. |

Sources: `docs/integration/equipment-scanner-secure-setup.md:34–70`; `functions/test/equipment-scanner.test.ts`; `packages/gainpath_domain/test/equipment_matcher_test.dart`; `apps/mobile/test/equipment_scanner_test.dart`, `equipment_image_picker_test.dart`, `member_equipment_test.dart`.

**Practical held-out dataset proposal:** five distinct common supported equipment classes present in the test catalogue, four photos each (canonical angle, alternate angle, dim, cluttered), plus 10 negative photos (five non-gym items, three difficult/occluded, two equipment classes absent from the test catalogue). Use owner-authorized devices/photos, no bystanders, explicit catalogue snapshot and per-image human label + catalogue ID where available. Two images with visually similar racks or bench variants should have allowed ambiguity labels defined before the run. Freeze device/build/provider/test data and request budget, and use a seed-only catalogue where live testing is inappropriate.

Log each case as `case_id,scene,ground_truth_equipment,expected_catalog_id,expected_unknown,returned_label,confidence,normalized_label_correct,matcher_state,returned_catalog_id,confirmed_target_correct,error_stage,elapsed_ms`. A vision recognition can be correct while its record is absent. Publish recognition accuracy \(C/N\) over labelled positives, unknown rejection rate over negatives, correct record matches over cases with expected available item, top-k/disambiguation hit rate, and end-to-end confirmed accuracy. Count ambiguous, invalid response, request failure, wrong class, absent active record and wrong navigation separately. Report denominators, label policy and confidence cutoff; calculate no percentage until actual annotations and runs exist.

