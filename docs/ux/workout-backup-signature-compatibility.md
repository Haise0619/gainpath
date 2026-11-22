# Routine backup signature compatibility — 15 November 2026

Repeated authenticated/App Check verified backup requests returned HTTP 400. A scoped diagnostic deployment identified the exact final routine-plan signature comparison in `timed-routine-backup-validation.js`, rather than network or session upload failure. Only the owner-specified account's backups were inspected; all 24 existing backups validated offline.

The old validator compared JSON signature strings byte-for-byte. Flutter signs a missing optional exercise video as `null` but serializes it as `''` in the routine snapshot. Equivalent target objects with different JSON key order also failed. Two new tests reproduced these rejections before the fix.

The validator now parses the signature, compares using the existing canonical value encoder, and normalizes only empty/absent optional video references in comparison copies. Original payloads, digests and persisted signatures remain unchanged. Identity, exercise order/mode, targets, media version/generation and nonempty video references must still match. No camera, counting, reward or authorization policy changes.

Verification: 180 backup tests pass; production and test TypeScript compilation pass; all 24 existing account backups pass unchanged; independent review found no actionable issues. Only the existing backup function's source is updated, preserving runtime and IAM. Private baseline archives, diagnostic locations, release seals and operation verification are retained under `build/sync-fix-20261115/`. Final owner retry confirms whether all queued records now sync; do not claim that a local test proves the device queue is cleared.

Owner acceptance: the device retry displayed **Synced**. The matching 15 November 2026 18:36–18:37 MYT request batch contains 16 HTTP 200 responses and no validation rejection. Active source archive hash, runtime configuration and IAM are verified. No APK update or record clearing was needed.
