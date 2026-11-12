# FYP demo integration acceptance plan

Goal: validate committed Member, Backend and Admin integration with local fixtures, Firestore emulators and Sandbox contracts; fix confirmed defects without deploying or changing user data.

Baseline: `7e80aee`, including Coach clean-build integration fix `8b6b20c`. Preserve all unrelated dirty files. Work in ignored `build/fyp-demo-acceptance-20261112/source`, exported from Git; reuse installed dependencies, never unrelated application source.

1. Run backend and Domain coverage; inspect payment, membership and reward authorization/state transitions. Reproduce failures before scoped fixes.
2. Independently inspect booking purchase/cancellation/refund synchronization and run booking tests. Add regressions for confirmed defects.
3. Independently inspect Admin financial modes/navigation, loading/error/empty/detail states and authorization/idempotency; render actual Flutter screens at narrow and desktop sizes. Fix confirmed defects only.
4. Run Member membership/reward/check-in/booking Flutter regressions and actual renders at multiple sizes/text scales. Verify paid eligibility, retained points, pending recovery and truthful payment states.
5. Run local Firestore integration suites with explicit demo project/loopback guards, checked-in Rules and no live credentials. Separate environmental/test-harness issues from application failures.
6. Review fixes, stage only minimal changed blobs from isolated source, commit logically, and export the final application commit afresh. Run affected Flutter/Domain/backend/emulator checks, static analysis, Android Debug and Admin Web release builds.
7. Write `docs/qa/fyp-demo-integration-acceptance.md` with exact counts, commands, screenshot evidence, commits, build results and provider/device UAT limitations. Do not imply real provider end-to-end clearance from fixtures.
