# Routine template local cover upload

User requests local image selection instead of entering a cover URL in Admin. Preserve the routine form and separate draft/publication flow. Use the existing validated JPG/PNG/WebP picker (5 MB), memory preview, choose/replace/remove controls and upload-on-save status. Keep saved covers until a verified save; canceling a picker preserves the selection. No local filename/path is persisted.

Reuse the existing immutable organization workout-cover storage (`exerciseImages`), with its current verified Admin/Staff upload authorization and Member read policy. No Rules, backend, publication, or data migration is required. Add a distinct routine media capability; the unified Admin wrapper must forward it while retaining FYP read-only restrictions. Validate current author and original routine snapshot before upload, then use the original guarded save/readback after upload. Upload failure preserves the draft and permits retry; conflict/uncertain save still requires reload.

- [x] Regression tests RED: local selection/preview/cancel/remove/save/failure; real repository upload, stale edit/session loss and retained baseline.
- [x] Domain capability, guarded Firebase implementation, unified forwarding, and cover controls within existing form/summary.
- [x] Focused Admin tests/analysis, final independent review and release web build; preserve unrelated work and prior bundle; activate and verify served hash under standing authorization.
- [x] Record checks, operational docs and scoped commit. No actual template edits/publications during verification.

Verification:51 affected Admin tests across8files pass, including guarded real repository and ordinary Unified Admin routing. Source/test analysis has no errors/warnings and only8 pre-existing brace style infos. Final independent review has no Important/Critical findings. Release web build passed; previous bundle retained. The existing7359server was stopped; restarted hidden and served JavaScript hash matches the prepared bundle. No production template/media upload or publication was performed; real file-dialog/live upload acceptance remains for the owner. Private evidence: build/routine-cover-20261109/.
