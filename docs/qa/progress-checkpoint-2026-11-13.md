# GainPath progress checkpoint — 13 November 2026

## Scope and handoff

Owner requested committing all current progress and pushing to main. Existing work on codex/hybrid-workouts includes Member Rewards locked previews, check-in and points UX, Coach discovery/booking availability fixes, compact Progress/workout dashboard improvements, Admin Coach profile/publication/review operations, and commercial booking checkout.

Checkout retains Billplz Sandbox, server-verified confirmation, holds, immutable payment preferences, existing invoice recovery, refunds and reconciliation. Selected payment preference is distinct from the actual provider rail. The owner confirmed that payment methods load on the phone after the protected existing-command routing fix (54e23e9; activation documented in cc362db). Billplz's hosted simulator remains: no fabricated paid status or automatic success bypass was added.

This checkpoint also includes previously uncommitted Admin Coach roster/filter/profile/rating and private document UI work, Home/check-in components and tests, debug-only bounded pose timing diagnostics, equipment image MIME extension handling, a training-plan icon, portable Admin run configuration and design documents. The run configuration references ignored local Firebase configuration; credentials are not included.

Review corrections: private certificate loading retains authenticated bounded 5 MiB HTTP/SDK access; removed the unrestricted download-URL shortcut and the title-based generated-document fallback. Initial Coach review notification now requires authorized directory access and reports the actually loaded review.

## Fresh verification for this checkpoint

- Member affected regression tests: **38 passed** (eight files).
- Domain full suite: **200 passed**.
- Admin full suite before final review corrections: **608 passed, 6 skipped, 7 failed**. This is not a fully green release.
- Admin focused rating/publication/private-path tests after final corrections: **12 passed**.
- Android Debug APK: **built successfully**.
- Admin Web Release: **built successfully**; existing Wasm compatibility/font warnings remain.
- git diff --check: passed (line-ending normalization notices only).
- Final scoped Admin analysis (Coach screen, certificate adapter and ratings): **no issues found**. Repository-wide analysis did not complete in the checkpoint window; no all-repository clean-analysis claim.

Admin full-suite failures to continue in the next chat:

1. admin_operational_report_test: expected legacy Confirmed Sandbox receipts label.
2. admin_shared_people_test: selected review callback expectation.
3. admin_shared_people_test: failed review switch callback expectation.
4. admin_shared_people_test: denied initial review notification (corrected after full run; full suite not rerun).
5. admin_shared_people_test: old unknown-session stat text expectation.
6. emulator/unified_ordinary_admin_test: emulator-dependent ordinary Admin boot.
7. firebase_feature_availability_test: dashboard activity-feed expectation.

Do not assume all failures are baseline or merely stale tests; inspect and reproduce before changing behavior. Full Mobile, Backend and Emulator suites were not rerun for this source checkpoint. Earlier task-specific verification is documented in the existing feature reports and must not be represented as fresh checkpoint verification.

## Remaining acceptance and operational limits

- Real Billplz payment, authenticated callback/return, retry/recovery and refund/provider UAT remain pending; never mark paid solely on app return.
- Physical training accuracy, camera performance, Android PDF and other recorded feature-specific UAT remain subject to their existing reports.
- No deployment, phone install, production payment, real-user mutation or data migration was performed for this checkpoint.
- Ignored build logs, local Firebase JSON, credentials, rollback packages and device artifacts stay outside Git. Verification logs: build/progress-checkpoint-20261113/.
- Existing operational and feature reports contain the detailed source/release history; start with docs/STATUS.md and docs/ux/member-coach-booking-commercial-checkout.md.

## Next chat

Start from main after pulling origin. Read AGENTS.md and this report, then resolve the listed Admin full-suite failures and finish provider/device acceptance without weakening authorization, server payment verification, account isolation or workout scoring protections.