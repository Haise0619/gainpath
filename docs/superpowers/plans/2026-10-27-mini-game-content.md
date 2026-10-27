# Edit supported mini-game content

Owner request: Admin Content → Mini-games, edit existing supported games only. No creation, deletion or gameplay/reward configuration.

## Contract

- One supported ID: `move-catch-v1` (Move & Catch). Registry is system-managed.
- Content fields: display title (80 chars), introduction (2000), 1–8 instruction strings (500 each), optional cover URL and preview-video URL. Images: JPG/PNG/WebP ≤5MB; short MP4 previews ≤20MB. Files selected locally, uploaded on Save.
- Serialized game: schemaVersion1, organizationId, gameId, revision, title, introduction, instructions, coverUrl, previewVideoUrl, updatedAtMillis. Revision0 is the real built-in guide, returned for an absent override without writing or seeding anything.
- Shared reader `load()` returns scoped supported content. Admin repository adds `save(requestId, baseRevision, content)` and `upload(gameId, kind, uploadId, bytes, contentType)`.
- Callable `miniGameContentCommand` in Singapore: actions list/save/uploadMedia; verified fresh Auth, App Check, canonical active same-org authority. Admin-only saves/uploads; supported IDs and exact editable fields only. Revision conflicts and stable idempotency receipts. Media is immutable, content-validated and bound to the organization/game via server receipts.
- Member game selection/consent reads the description/media. Existing built-in guide remains an explicitly labelled offline guide if remote content is unavailable; no fabricated scores or rewards. Loaded content cannot change privacy, safety, mechanics or camera consent.

## Implementation batches

1. Parent: shared validated domain/ports and focused domain tests; Firebase repositories/transports and Admin DI/navigation wiring.
2. Backend worker: isolated content service, immutable media storage, callable and tests. No cloud/Rules/data operation.
3. Admin worker: Edit-only list/form, local media previews, conflicts/retry/reload and focused widget tests. Reuse console components.
4. Member worker: connected selection/consent content display, cover/preview, built-in guide status and tests; preserve game engine/camera/scoring.
5. Parent: integrate, run focused checks/typechecks/architecture, independent review, prepare private Admin Web and signed Android APK. Update operational references.
6. Present the exact release scope/artifacts for owner approval before any deployment, Admin activation or device installation.
