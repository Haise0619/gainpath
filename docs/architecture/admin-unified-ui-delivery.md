# Unified Admin Web — integration fixes

The owner implemented the Admin integration plan, then requested correction of the four remaining review findings. This delivery includes the reviewed Admin integration and those corrections; mobile and unrelated owner changes are excluded.

## Corrected behavior

- `CoachesScreen` owns one canonical page body for both source adapters: original stat chips, branch-grouped card layout, Add Coach control and review area. Real records are joined by stable IDs; unknown branch assignments are labelled Unassigned rather than invented. Unknown rating/session widgets show `-`. Unsupported provisioning remains visible but disabled. Private certification review/history, separate publication/deactivation and discard protection are preserved.
- Dashboard hourly session counts have an independent `hourlySessions` view-data series. They never reuse monetary revenue points. Unknown series stay empty inside their chart frames, with an unavailable indicator; no zero series is fabricated. Initial Dashboard range matches Today; Reports loads the selected initial range.
- Starting a report request clears the previous snapshot. Only the current matching query can populate state. Failures clear values, show a sanitized error and expose Retry inside the same page. A closed Cubit ignores pending success/failure responses.
- Existing fixes are retained: shared Members body, fail-closed production account composition, disabled unavailable CSV exports and in-shell Coach bookings/schedule with breadcrumbs.

## Verification

66 tests passed in the final affected 14-file selection: reporting stale-filter/close/mapping/retry regressions, shared composition/people/reporting/responsive/unavailable sections, authentication/account/member-directory behavior, Coach publication, scoped booking/schedule, certification adapter authorization and review discard protection. Targeted analysis reported no issues. The strengthened Admin presentation checker and `git diff --check` passed. No full CI or emulator suite was run.

The tests use injected repositories/synthetic data. They do not establish live Firebase CRUD success or owner manual acceptance. The local build reuses the already approved App Check fixture without registering credentials. No backend deployment, Rules/schema change, data migration or live CRUD mutation is part of this delivery.

## Official entry and manual retest

Official local entry: **http://localhost:7359/**. The integrated build replaces the existing canonical build output; no new module website or acceptance port is introduced.

1. Refresh the main URL and open Coaches. Confirm the original stat chips, branch cards and disabled Add Coach control remain; inspect a private draft and certification history.
2. On approved disposable evidence only, verify reject-with-reason, approval and separate publication. Confirm unsaved reasons trigger discard protection. Existing published/personal records need not be modified for visual testing.
3. Open a selected Coach's bookings/schedule; verify sidebar/breadcrumbs remain and access is read-only. Return to Coaches through the breadcrumb.
4. Open Dashboard/Reports, change filters and inspect unavailable states. Missing values should show `—`/empty chart frames; unsupported exports remain disabled. A failed report request should show Retry and no previous-filter values. With the default unavailable reporting adapter, no real analytics pipeline is claimed.
5. Check Members, existing content/equipment/routine/governance/settings destinations, narrower browser widths, and sign-out. Previously implemented Firebase functionality and private-session isolation should remain intact.

The owner confirmed Unified Admin Web Manual UAT **PASS** for commit `18e4130` on **19 October 2026**, Asia/Kuala_Lumpur. This records owner manual acceptance separately from the automated checks above. The owner authorized an integration checkpoint followed by Module 10; pushing the checkpoint and any later security-sensitive/policy/production deployment operation require separate approval.
