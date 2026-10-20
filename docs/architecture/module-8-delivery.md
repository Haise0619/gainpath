# Module 8 delivery evidence — 2026-10-17

Implementation baseline: `ca89f215a3a03c761ba7c4c1738ec574869c8cde`. Backend/domain/Rules commit: `bbdc410`.

FR-8.1–FR-8.3 reuse established Firebase authentication, neutral reset flow, password reauthentication/change and session teardown. FR-8.4 adds canonical Coach contact/settings CRUD with private server-side uniqueness claims. FR-8.5 completes the existing professional profile editor, optional MYR fee and private camera/gallery cropped avatar CRUD. FR-8.6 adds immutable qualification uploads, private previews, archival, Admin decisions/reasons/history and verified publication enforcement. All remain **pending owner consolidated manual PASS**.

## Observed backend activation

- Seven new Coach callables and two updated profile/publication callables deployed successfully; Cloud Functions API read-back showed all nine active with BR-5 enabled. All 15 unrelated pre-existing function revisions were unchanged (24 total functions).
- Exact deployed Rules were fetched before changes. Seven focused authorization tests passed against additive candidates. Released candidates were read back with SHA256: Firestore `3b11087f0d21639249374ae17035fbc4d734a0827f1c7390acd118b0c486e2db`; Storage `50138b9c519882e03005c1f7f5821b306d9d35baf3aca701c716c1feb8b3fc8d`. Removing each addition recovers its original deployed content exactly. No blanket Firebase configuration/index deployment.
- At 13:29:29 UTC, owner-approved BR-5 maintenance inactivated exactly one previously published Coach lacking approved credentials. Update-time preconditions and private read-back confirmed all other public fields, identity, membership and private profile were preserved. An audit uses a server timestamp and records approved deployment maintenance. Booking writes: zero; data deleted: none.
- Firebase CLI reported successful deployment with a build-image cleanup warning. No unrelated registry cleanup was attempted.

## Focused verification and boundaries

Final backend service tests: 33 passed, including old Member session denial after reactivation, malformed lifecycle rejection and post-download authority recheck. Only the new photo callable was subsequently redeployed; final API read-back again confirmed nine active Coach functions and all 15 unrelated revisions unchanged. Domain tests: 7 passed. Mobile flow/session/discard tests: 8 passed. Admin adapter, discard and App Check configuration tests: 6 passed. Targeted analysis/typechecks passed. Rules emulator assertions passed 7 cases; its Java process reported a shutdown-only exception after successful assertion/script completion. These are 61 focused tests, not a full CI run.

Seven new live callable endpoints also returned HTTP 401 / UNAUTHENTICATED to anonymous requests, with no identity used or data writes. This verifies deployed denial behavior, not authenticated CRUD UI success.

No canonical account was used to manufacture certification approval or claim real Firebase CRUD UI success. Local Admin App Check registration was separately owner-approved; debug exchange returned HTTP 200. Credentials and private fixtures are ignored and excluded from Git. A local debug Web build is not a production Hosting release.

Original protected working files (`README.md`, `.run/main.dart.run.xml` and the two pre-existing planning documents) matched their saved hashes. AI, protected media, workout history, Scheduler and Booking transaction code were not modified. Consultation fee is profile information; existing Booking pricing behavior is preserved.

## Final artifacts and commits

- Backend/domain/Rules: `bbdc410`; Member photo lifecycle regression: `44553c0`; integrated UI: `e2fe6a4`; private preview cache eviction on session end: `93b1368`.
- Android: `build/module-8-activation/gainpath-module-8-firebase-debug.apk`, 218,847,521 bytes, SHA256 `66b3c35c1f8501e7250bbc516933730db283616d80a7f767fc2dfc5f302dac39`; Firebase backend / debug App Check. Final build and targeted analysis passed. Installation was explicitly owner-approved once for Module 8.
- Existing Admin Web: `http://localhost:7359/builds/module8/`; final served JavaScript SHA256 `e365e4bfd694cb80cecaa96c2ccde12a16d6f108e1546fdfd1c9814836b8d526`. Root redirects to Module 8 and previous version routes remain available; HTTP 200/base href/served hash verified. App Check debug exchange returned HTTP 200 using the same approved private fixture.

Android installation and launch succeeded on the authorized `23013RK75C` phone. The previous APK and private app data were backed up, signing certificates matched, update used `adb install -r`, private data archives were byte-identical before launch, and the installed APK hash matched the final artifact. No uninstall or data clearing occurred.

Use [the consolidated checklist](module-8-uat.md) for Coach, Admin and Member acceptance. Owner manual PASS remains pending; no next module is started.
