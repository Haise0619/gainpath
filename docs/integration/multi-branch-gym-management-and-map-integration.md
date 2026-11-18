# Multi-branch gym management and map integration

## Phase 0 findings

- The canonical branch collection already exists at `orgs/{orgId}/branches/{branchId}`. The read-only Firebase audit on 18 November 2026 found one active record, Main Branch, with no coordinates. No address or coordinates were fabricated.
- Booking, coach publication and availability already use branch assignments and active branch records. Current booking admission still checks the member’s authorized branch assignments. Existing payment records retain their original branch references.
- Provisioning assigns Main Branch through `primaryBranchId` and `branchIds`. The new preference uses `users/{uid}.homeBranchId`; older accounts fall back to their existing primary branch. Preference is separate from access authorization.
- The equipment catalog is already organization-scoped. Branch inventory, visit records, nearby sort and branch-scoped AI or reporting remain follow-up items. Existing app Daily Check-in continues to track its own gamification activity.

## Local implementation

- One regional callable provides a bounded branch directory, verified Admin create/edit/status updates, and verified Member home preference. It reuses the existing organization and membership checks and requires App Check. Updates preserve fields from older branch records.
- Admin has a Branches entry with search, pagination, details and an editor for address, contact, manual coordinates, facilities and weekly MYT hours. A 24-hour or overnight schedule can be entered.
- Member Home has a Find a gym entry with active branches, branch details, current opening status and a home-branch preference. Directions use Google Maps URLs and fall back to the saved address when coordinates are absent. No location permission, map billing or API key is introduced in this slice.
- Public OSM tiles and Nominatim were reviewed. No tile integration or geocoding requests are made in this slice.

## Release and acceptance

- The new callable has no cloud deployment in this slice. Its live client access requires an approved deployment and a review of the callable transport IAM. No Rules, secrets, billing or production records were modified.
- Pending: interactive OSM maps and location picker, covers upload, nearby positioning, persistent selected branch context, branch KPI and filtered drill-down, organization-wide booking access rollout, branch inventory, QR visits, branch reporting and AI integration.
- Pending: full end-to-end acceptance, APK, Admin Web release build and actual rendered screenshots. For the directory slice, first verify Admin save and Member readback on a test branch, then check overnight hours, missing coordinates and Google Maps directions.
