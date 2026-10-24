# Equipment Edit image replacement — 2026-10-20

Reproduced on the running Firebase-mode local admin (`localhost:7359`): opening the existing record in Edit and choosing the repository's valid PNG icon left the old image visible. The picker reported a decode error. This happens before Save, so this specific failure does not depend on Firebase Storage upload permissions or billing.

The earlier single-codec simplification passed an isolated release-browser check but still failed in the actual debug-browser runtime. It was not sufficient. The final repair uses the browser's native HTML image decoder for web validation and an HTML image element for selected-image preview. Native validation preserves the original pre-decode intrinsic-size check and bounded 256px validation decode.

The form now displays image-selection errors beside the picker, previews the replacement immediately, and states that Save changes is required. A failed subsequent selection keeps the previous valid selection. Image bytes stay local until Save; URLs, file paths and names are not logged or persisted by selection. The 5MB, type-signature and 24MP checks remain, with a 10-second browser decode timeout.

## Verification

- Six focused picker/catalog tests pass, including Edit replacement preview, no upload before Save, one upload on Save, and inline failed-replacement feedback without losing the valid selection.
- Focused analysis reports no issues. Diff whitespace check passes.
- Real browser file chooser and preview verified both in an isolated form with an in-memory repository and on the repaired actual Firebase-mode Edit form at localhost:7359. The live test selection was discarded; the original equipment image was confirmed unchanged.
- Screenshot: `build/equipment-image-edit-preview.png`.
- Full Chrome test runner remains unusable in this SDK setup due to its stale precompiled test-host path. Manual browser verification was used; no full suites were run.

The local admin development server was restarted with its existing Firebase/debug-App-Check settings. No Firebase resources, billing settings, rules, APKs, or live equipment records were modified. Actual replacement upload/read-back through production Storage was not performed with a test logo; the user can select their intended image and press Save changes.

Changed files: equipment catalog screen, local image picker, platform-specific image-validation helpers, focused catalog test, and admin pubspec (direct dependency on the already-cached `web` package). `tool/equipment_image_edit_probe.dart` provides a reproducible browser regression without Firebase writes.
