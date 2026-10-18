# Module 8 canonical presentation refactor — 2026-10-18

Root cause: earlier composition chose different page classes for Mock and Firebase. Sharing the account header did not remove the separate Settings, editor and certification bodies; Firebase-specific details were also appended to the account hub. The named Coach route could bypass the injected Firebase data composition.

Source commit: `052cfa2`.

## Final structure

- One canonical Profile (`CoachAccountScreen`), Settings (`CoachSettingsScreen`), Professional Editor (`EditCoachProfileScreen`), Certification Management (`CertificationsScreen`) and Preview (`CoachAccountProfilePreview`).
- Domain `CoachProfileRepository` plus application `CoachAccountGateway` provide data/capabilities. Mock and Firebase implementations are selected in composition, with no Firebase SDK dependencies in these page bodies.
- Existing Mock purple header, rounded avatar, status pill, compact summary tiles, preview, grouped professional/account menus and bottom navigation remain the baseline. Fee/bio/tags belong in Editor/Preview, certification counts in their menu and decisions/history in Certifications. Removed supplementary hub panels.
- Settings reuses grouped Contact Details/Notifications/Security/Account cards. Country selection is inside Contact Details. Phone normalization, duplicate handling, secure password callbacks, save/read-back, dirty/discard and error handling are preserved. Notification text makes no delivery claim; no Coach self-deactivation is offered.
- Private avatar validation and current-session guards remain. Missing real metrics use `-`, and a Coach needs verified credentials plus publication before the UI reports a live directory status. Experience tiles fit at 360px.
- Three old `live_*` files were consolidated to exports/type aliases only, retaining historical imports without alternate page bodies. Mock repositories, existing tests and historical assets were retained.

## Verification

33 affected tests passed together: shared-screen/route composition, Profile/Editor/Preview, Settings phone validation/save/read-back/discard, Certifications upload/history/archive/retry, avatar validation, adapter mapping and session invalidation. Targeted Flutter analysis and the Module 8 presentation-boundary check passed. No full CI or unrelated emulator suites were run.

Profile and Settings test captures were inspected at 360px. Equivalent Mock/Firebase-contract Settings data produced identical PNG hashes (`34419d98a9cd185e9ec0e9029a63f98bd19f4a140a03b6de50e6c149a1935e1a`). These captures use Flutter test fonts and are not device screenshots or owner manual acceptance. Profile captures use different sample/real-contract values and confirm shared structure, not pixel identity.

Existing Firebase callable names/payloads and Storage access remain inside the Firebase adapter. Typed summary/detail and password methods delegate to the existing operations. No Firebase identity schema, backend behavior, Rules, production data, Booking algorithms, AI, workout history or Admin functionality was changed or deployed.

## Manual UAT

1. Profile: check purple header/avatar/status, `-` for unavailable metrics, compact Experience tile, menus and bottom navigation.
2. Settings: check grouped Contact Details with integrated MY +60 selector; edit/save/reopen phone and preferences, invalid/duplicate errors, discard confirmation and secure Change Password.
3. Professional Editor: change bio/tags/experience/fee, save/reopen; replace/clear photo and check draft/publication messaging without duplicated hub details.
4. Certifications: upload a valid image/PDF, reopen/preview, view friendly review status/reason/history and archive test evidence.
5. Preview: verify published snapshot versus clearly labelled private draft, with the correct avatar and fee. Recheck narrow-screen wrapping.

One integrated Firebase APK built successfully: `build/module-8-architecture/gainpath-module8-canonical-ui-firebase-debug.apk`, SHA256 `44fa4701ef7a4407c15198b8c03deaf0304d61821fddfee1f126962c8ced0fb0`. After explicit owner approval, it was installed and launched on Xiaomi model `23013RK75C` at 2026-10-18 09:15 UTC. The installer backed up the previous APK and private data, confirmed matching signing certificates and the installed APK hash, and verified private data remained byte-identical before launch. No data clearing occurred. Sanitized evidence: `build/non-core-crud-sprint/module-8-architecture/install-result.json`. Module 8 remains pending owner manual PASS/FAIL.
