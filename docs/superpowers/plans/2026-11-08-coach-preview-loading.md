# Immediate Coach preview navigation

Root cause: owner preview awaited draft and then published photo reads before Navigator.push, leaving the account page unresponsive with no transition. Owner approved correction by requesting this interaction fix.

- [x] Reproduce delayed photo blocking navigation with a controllable Future.
- [x] Push the existing preview immediately from loaded profile data. Load photos asynchronously in the fixed-size avatar, show progress, fade into the result, reuse matching draft/photo reads, retain error/session guards and published/draft isolation.
- [x] Run affected tests/analysis and final review, isolated APK, authorized idle-device install if safe, scoped operational notes/commit. No backend changes.


Verification: slow draft reads blocked navigation in two reproduced RED tests; immediate Preview route and fixed-size photo progress/fade now pass GREEN. Slow published read/version switching covered separately; completing a discarded photo does not reopen the route or replace the selected draft.48 affected tests across7 files and scoped analysis pass; source review found no actionable blockers. Existing eight font-loaded Profile/preview renders regenerated during the affected suite; layout unchanged. Fade honors reduced-motion settings. Photos time out to a safe placeholder after20seconds without blocking navigation.

Isolated Android debug build passed; source allowlist and dependency lock verified. Installed/launched in place on authorized idle Xiaomi7c4cbff observed on static owner Preview, without unsaved editors. Signer and exact installed APK hash match; all59 protected saved files unchanged before launch, old APK/data retained. Actual tap-to-route latency, image rendering/fade smoothness and pending-read account-change physical acceptance remain unverified. No backend/data writes. APK/evidence: build/coach-preview-loading-20261108/gainpath-coach-preview-loading-debug.apk.
