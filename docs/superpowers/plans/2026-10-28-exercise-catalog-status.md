# Exercise Catalog status and Delete

Owner requests archive/active status and a Delete button. Implement directly using the existing reversible archive path; preserve exercise IDs, media, published Routine/Program snapshots and Member history. No permanent deletion, cloud write, Rules deployment or running Admin replacement is authorized by this new task.

Design: derived Active/Inactive/Archived states, All/Active/Inactive/Archived filters, explicit per-entry Activate/Deactivate, confirmed Delete (archives and sets inactive), and Restore (returns an archived entry as inactive, then explicit Activate). Show text status and action labels; use wrapping layouts at narrow widths/large text. Disable conflicting actions while saving. Report verified success only after repository readback; on uncertain failure require Reload before further lifecycle actions. Archived entries cannot open normal content editing.

Domain/repository: separate TutorialCatalogStatusRepository.setCatalogStatus(TutorialVideo, ExerciseCatalogStatus) with opaque edit baseline, fresh canonical authority/source checks and status-only patch/readback. Retain existing TutorialArchivingRepository API. No title-based AI capabilities or changes to recognition.

Rules: inspect compatibility of pending source archive rules and deployed rules read-only. Any required source candidate must be limited to exact exercise status fields, enforce archived=>inactive, server update timestamp, current contentAuthor authority and preserved metadata. Hard delete stays denied. Test legacy author metadata, privilege/conflict/readback failures and protected existing content.

Verification: TDD domain/repository and UI regressions, focused Rules emulator, affected authoring/publication tests, analysis/architecture and separate private Admin build with exercise-only status feature enabled. Existing global Routine removal hold remains intact. Retain evidence under ignored build/exercise-catalog-status-20261028/. Review concrete Rules/Admin scope before any release; do not mutate live entries to prove controls.
