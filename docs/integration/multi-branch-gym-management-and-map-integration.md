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
- Admin and Member can open a shared interactive OpenStreetMap view. Admin can tap or drag a pin to fill the coordinate fields, then save through the existing editor. The list and navigation remain usable if tile requests fail.
- Map tiles load only while a map is open, with attribution, the GainPath mobile app identifier, built-in tile caching and no tile prefetch. Web uses the browser's default referrer behavior. The optional `GAINPATH_BRANCH_TILE_URL` build setting selects an alternative provider. The public map service is intended for small-scale FYP use. No geocoding API is called.
- Android asks for foreground location only after Use my location. Distances are calculated locally and sorted across loaded results with missing coordinates last. The selected branch lasts for the current directory session. No member location is sent to Firebase.
- Two Flutter widget tests cover nearby order, location privacy at the repository boundary, denial, and address navigation.

## Release and acceptance

### Inventory, visits and branch preferences

- Admin can upload a JPG or PNG cover up to 2 MB through the existing Firebase Storage upload implementation. The editor saves the returned cover URL with branch information. The public branch list and detail show images with fallbacks.
- The account's selected branch is stored separately from Home Branch and omitted on read if inactive. Branch Equipment and scanner availability use existing equipment IDs. The scanner uses the stored selected branch, with Home Branch and the legacy primary branch as fallbacks. Inventory quantity tracks usable and maintenance units, not real-time occupancy.
- Admin can add, edit or remove branch inventory associations and open branch visit history or display a five-minute QR. Member can scan the QR and open personal history. Check-in verifies existing gym-access capability, validates a server-stored token digest and uses an atomic visit ID plus a 15-minute branch cooldown. No gamification rewards or attendance claims are generated.
- Branch Details now has live aggregate queries for coach profiles, equipment units, bookings and recorded visits. The assistant can answer narrowly recognized branch hours, directions and treadmill questions using stored facts, or direct a nearby query to the existing on-device locator without a Gemini call.
- New storage paths: `orgs/{org}/branches/{branch}/equipmentInventory`, `gymCheckIn`, `gymVisitLatest`, `gymVisits`; Member history uses `orgs/{org}/members/{member}/gymVisits`. Branch cover objects are stored at `orgs/{org}/branchCovers/{sha256}`. Existing branch and equipment catalogs remain canonical.

- The new callable has no cloud deployment in this slice. Its live client access requires an approved deployment and a review of the callable transport IAM. No Rules, secrets, billing or production records were modified.
- Pending: full dashboard-level branch filtering and CSV analytics, authorized organization-wide booking and Coach filtering, management drill-down links, QR download, equipment compatibility for routines/programs and other-branch scanner lookup; recommendation, Content Planner and Outreach integration. Branch totals do not cover legacy home-member assignments. Assistant branch cards and coach availability intent are still pending.
- Deployment still needs explicit approval to expose the new callable through Firebase callable transport. If scoped Storage access is missing, grant it separately. Existing Rules, Secrets, IAM and Billing were not changed.
- Pending: full end-to-end acceptance, APK, Admin Web release build and actual rendered screenshots. For the directory slice, first verify Admin save and Member readback on a test branch, then check overnight hours, missing coordinates and Google Maps directions.
