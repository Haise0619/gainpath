# Module 8 UAT repair — 2026-10-18

## Admin root cause and observed result

Reproduced the exact generic Coach loading failure in the old `7df26ea` Admin build, using the same authenticated canonical Admin session as the working build. Its strict public Coach decoder predates `certificationVerified` and `approvedCertificationCount`, rejects those current fields with a FormatException, and the old cubit hides that behind the generic message. This was a stale acceptance application/schema mismatch, not a BR-5 denial of private drafts.

Before changes, the current integrated application loaded one real draft, one inactive public record and the private pending certification. After serving the main build at **http://localhost:7359/**, the same actual Firebase/Admin scope loaded those records and selected certification history. No private record values or credentials are included here.

Exact deployed Rules were freshly inspected: Firestore SHA256 `3b11087f0d21639249374ae17035fbc4d734a0827f1c7390acd118b0c486e2db`, Storage `50138b9c519882e03005c1f7f5821b306d9d35baf3aca701c716c1feb8b3fc8d`. Both matched Module 8 activation. No backend/Rules deployment or index change is required. Current queries order by document ID and succeeded; the certification callable/App Check and scoped reads succeeded. Member publication/booking eligibility restrictions remain unchanged.

`tools/admin_web/build.cjs` and `serve.cjs` rebuild/serve the existing complete Admin application at a stable root. Old build URLs redirect there, without deleting old recovery artifacts. Existing navigation/features are retained. Local responses disable caching and the current Flutter bootstrap does not register a service worker. The existing approved App Check fixture is reused privately; no credential is registered. UI copy now explains certification approval followed by explicit publication. Schema/timeout failures have specific recovery messages.

Admin tests: three affected loading/publication/session tests passed, plus one HTTP routing/security test. Targeted Admin analysis passed. Existing backend suite: 33 passed, including BR-5 and contact uniqueness/clearing. The publication widget test needed its missing account-avatar fake supplied; production account logic was unchanged.

## Coach phone repair

Old UI sent raw local text into the repository's E.164-only validation and placed errors above the visible field. The repair separates country selection from number entry and uses maintained country numbering metadata for normalization/validation, preserving the existing server uniqueness contract. Save performs explicit persistence read-back before success; errors appear inline and via feedback, with progress and duplicate submission prevention.

Phone tests: 12 passed across metadata-backed MY/SG/GB/US normalization, invalid/duplicate/empty/existing stored numbers, read-back mismatch/unavailable errors, selector flags/catalog and session/discard behavior. Targeted phone analysis passed. Dependencies are locked to `phone_numbers_parser 9.0.28` and `country_picker 2.0.28`; normalization happens locally, with no external phone-validation service. Server-side duplicate claims and E.164 storage are unchanged.

Commits: `9f6fb15` (main Admin/schema recovery) and `9c0fd6c` (phone UX). Stable main Admin served JavaScript SHA256: `65c3151b77ac89e788ff6af55a5573aabbfd72892a637d6a4ba26f1fc121c626`.

Final compatible Android build: `build/module-8-uat-fix/gainpath-coach-phone-firebase-debug.apk`, 219,359,073 bytes, SHA256 `2f416853f5aa05270b16bbc1fd2ae4a033dcf64ae3655ea4885c53e0ed48421c`; Firebase backend/debug App Check, same package/signing setup. Build succeeded. Owner-approved installation and launch succeeded on Xiaomi `23013RK75C`: previous APK/private data backed up, signing certificate matched, private data archive byte-identical before launch, and installed APK hash matched. No data clearing or uninstall.

## Approved live disposable Coach UAT

The owner explicitly approved one clearly labelled synthetic Coach fixture. Only its new identity/profile/evidence/settings were written; existing Coach records and bookings were excluded. The existing authenticated Admin session reviewed it at the main URL without credential extraction.

- Coach profile save, immutable synthetic PNG upload and pending certification submission succeeded in real Firebase.
- Main Admin displayed its unpublished draft and private certification; authenticated private preview opened successfully.
- Publication while pending was denied by BR-5. Rejection without a reason was blocked inline. Rejection with a synthetic test reason persisted as revision 2.
- Approval persisted as revision 3 and did **not** automatically publish. Explicit publication then succeeded, and explicit deactivation persisted the listing as inactive. UI history displayed pending/rejected/approved revisions with retained actors/timestamps.
- Fixture phone save and canonical reload matched E.164. Invalid server input was denied. A duplicate attempt against an existing active claim returned ALREADY_EXISTS without modifying that claim or its owner. Optional blank clear/reload succeeded and the fixture claim was released. No second fixture identity was created.

Final read-back verified the fixture listing inactive, certification archived at revision 4, verification flag false/approved count zero, membership inactive and phone cleared. The immutable evidence object, identity and four history snapshots (pending, rejected, approved, archived) remain retained. Both pre-existing Coach draft/public records matched their saved data exactly. No deletes or Booking writes occurred.

These are observed live backend/UI results on a disposable fixture, not owner manual UI PASS. No next module starts before owner acceptance. Sanitized live/install results are recorded in `module-8-uat-live-results.json`; private credentials and raw records remain excluded from Git.

Retest: open the stable main Admin, review the unpublished Coach and private history, then use authorized test evidence to reject/approve and explicitly publish. On the approved phone build, select MY +60, save `012-3456789`, reopen, test another country and invalid/duplicate numbers, then clear/reopen. Keep existing bookings and personal records unchanged.
