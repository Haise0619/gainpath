# Multi-branch gym management and map integration

## Current delivery status

**Cancelled — Intentional Scope Reduction:** Exercise Equipment ID Mapping and compatibility in Exercise, Routine and Program, compatible-gym suggestions, workout restrictions and branch equipment-driven Routine recommendations, Planner and Outreach. The organization content catalog stays shared. Existing real inventory, maintenance, scanner, other-gym lookup and facilities remain in use.

| Item | Status |
|---|---|
| Core branch regression | Tested in 339 backend tests, 16 Member Flutter tests, 16 Admin report Flutter tests and one Firestore Emulator integration test. The Emulator CLI exited 0. The follow-up assistant and recommendation suite passed 67 tests, overlapping with the core set. |
| Release 1 | Deployed: booking hold, booking options, public Coach availability read, booking change, payment quote/create/read, both regional payment webhooks, and Assistant branch facts/card. Verified source-only updates. Private Admin Web is active on localhost:7359. |
| Production callable verification | Anonymous list returned HTTP 401 UNAUTHENTICATED. An existing verified TEST identity plus a registered App Check token returned HTTP 200 and one branch from the read-only list. |
| Booking navigation | Implemented in saved booking details, confirmed payment, reschedule and in-app notices. Signed-in device Maps check pending. |
| Admin Coach Management and drill-downs | Implemented: existing Coach schedule filters published windows by assigned branch. Branch Details links to the existing scoped Coaches and Reports pages; Equipment and Gym Visits keep their existing branch entry points. Member and Booking links, assignment editing and Admin schedule writes remain pending. |
| Reports scope and CSV | Implemented locally: top-level branch scope with inactive and unassigned choices, retained date range, scoped metrics and CSV across Reports tabs. Organization-wide membership revenue remains explicitly labeled. Scoped results use the existing Branch Report aggregation. Branch-level trend series and detailed tables remain pending. |
| Assistant branch card | Local card with cover, address, status and actions for View branch and Get directions. Existing available-slot component remains in use. The Flutter fixture card render passed and produced build/chatbot-message-refinement/screenshots/branch-card.png. The branch facts/card payload is deployed. Signed-in visual acceptance and the separate Coach availability response enhancement remain pending. |
| Automatic Coach recommendations | Local runtime prefers accepted workout branch or Home Branch, and expands eligible branches for verified paid members. Production release and full integration validation pending. |
| AI Content Planner | Cancelled — Intentional Scope Reduction. Existing organization-wide analysis stays in effect. |
| AI Member Outreach | Implemented locally: Home Branch filter for Top Active Members and Search Members, and Home Branch in Member Analysis, with primaryBranchId as the legacy fallback. 27 backend tests and TypeScript typecheck passed. Release 2 deployment pending. Gym Visit Analysis, extended branch context and Gemini prompt changes are cancelled by intentional scope reduction. |
| Release 2 | Blocked for production verification and deployment: Firebase CLI credentials expired and requested reauthentication. Local implementation and tests are noted above. |
| Builds and rendered screenshots | Release 1 private Admin Web build was activated and its served SHA-256 verified. Android arm64 Debug APK built from current working source. Assistant screenshot is a Flutter fixture. |

### Release 2 verification

- 70 backend tests for Outreach search, automatic recommendation, and Coach availability passed along with TypeScript typecheck. Admin Reports fixture verifies retention of inactive branch scope and date range across category navigation. No Firebase, IAM, Rules, Billing, provider or production data changes were made in this turn.

### Release 1 production evidence

- Eight Booking/Payment source overlays passed 111 package-level regressions. The Assistant card overlay passed a provider-free handler test and the Coach availability read overlay passed 24 package tests. Each submitted version was confirmed ACTIVE, with matching downloadable ZIP hash and unchanged service configuration and IAM. Booking hold and options opened only after payment and booking change revisions had been verified.
- The Android build completed on JDK 21 using the existing dependency versions after running Gradle outside the restricted process environment. The Admin bundle was built with the registered private App Check configuration, and both the previous bundle and new served hash were retained. The current Android APK SHA-256 is e6f86073392fbef7e50e1068b0fed24ab9e4892d8fc8cd312d9ed0b6eaf8859b. Source commits include 9097274 and 73a25b9.

- Rollback ZIPs and function metadata for Booking, Payment, both webhook regions and Assistant are captured under build/multi-branch-release/release1-baselines. The existing payment checkout uses getBookingPaymentCommand for method discovery. No standalone getBookingPaymentMethodsCommand was found in the Singapore inventory. Regional payment packages differ, so use the existing package for each endpoint as its update baseline.

- Cloud Functions source generation 1795023721822166, deploy hash 0edb28a2ade8ed602af2c461efc31076d8c6f5e7. The before/after inventory shows 79 existing entries with unchanged deployment hashes and exactly one addition.
- IAM readback on Cloud Run service branchmanagementcommand shows roles/run.invoker for allUsers on that service. Callable Auth and App Check remain required to execute business actions.
- Firebase CLI reported Successful create operation and subsequently exited 1 while offering Artifact Registry cleanup configuration. Independent Functions list and IAM readback confirmed the endpoint is active. Cleanup policy was left unchanged.
- The isolated source and before/after inventories stay under the local release workspace. They include deployment metadata and should be kept local.

### Manual acceptance

1. Use an authorized Admin session to create a branch fixture in an authorized environment, upload a cover, set opening hours and facilities, and save a map pin. Keep Main Branch coordinates blank until verified.
2. As a Member, open Find a gym and verify the cover, map, selected branch after restart, location denial, device distance sorting and Maps navigation.
3. Add usable and maintenance inventory, check alternative gym availability, issue a visit QR, scan it once and confirm duplicate blocking, then verify visit history.
4. Choose a Coach at another gym, book and complete Xendit Sandbox payment manually, then compare confirmation, history, reschedule and notification navigation with the actual booking branch. Also open an existing historical booking for an inactive branch.
5. Check scoped report and CSV totals against the fixture. In the assistant verify branch card actions and bookable slots. Verify Admin drill-down, uniform report filters, Coach recommendations and the Outreach Home Branch filter after Release 2.

## Branch assistant follow-up

- The assistant reads recorded facilities and resolves recognized equipment questions against the active organization catalog. Inventory reads use canonical equipment IDs. A missing stock record is reported as unavailable data. Cross-branch equipment questions check up to 30 active gyms in one inventory batch.
- Coach questions can use a name, a date, or the current gym. Answers use existing bookable slots and eligibility checks. The directory lookup is bounded, so an empty result describes the checked page only. The new paths do not request Gemini.
- Eighteen focused backend tests and the test TypeScript typecheck passed. See the current checklist for outstanding client work. This follow-up has no production deployment or fresh Flutter build.

## Final-integration progress

- Paid Member hold, slot options, verified payment confirmation, and same-branch rescheduling now follow the active activity branch. Coach publication, Coach assignments, overlapping-slot locks, organization membership and existing Basic/Premium entitlement controls still apply. The Member Coach Directory can match loaded published profiles against the saved Selected Branch. Existing price, checkout gateway and historical records were not edited.
- Equipment lookup uses the exact equipment ID. If the selected gym has no usable stock, the callable checks up to 30 other branch records using batch reads and returns available alternatives. Directions use stored coordinates or address. The UI discloses the bounded result set.
- Admin visit QR adds countdown, expiration, refresh, fullscreen and browser PNG download. Server token validity and duplicate protection remain authoritative.
- Reports has a Branch report dialog using the active date range, including inactive branches and unassigned facts. It displays branch counts, coaching receipts, accepted workouts and visit metrics, with scope and dates in the CSV. Existing dashboard and membership revenue stay organization-wide. There is no new branch allocation on historical facts.
- Validation: 137 focused unit tests and test TypeScript typecheck. Three branch widget tests, 22 Member Coach/Payment widget tests, 15 Admin Reports regression tests, one historical-branch report widget test and scoped Dart analysis. Clean-source Android arm64 Debug and Admin Web Release builds exited successfully. The web build emitted a CupertinoIcons asset warning. Eight booking/branch Firestore Emulator tests passed with Firebase CLI exit 0 using an isolated writable `XDG_CONFIG_HOME`. The earlier exit 2 followed passing Vitest and emulator shutdown; it is reproducible with the restricted default CLI configuration, not a failing fixture or startup failure. The branch emulator scenario was also rerun with the scoped report/date assertions.

## Phase 0 findings

- The canonical branch collection already exists at `orgs/{orgId}/branches/{branchId}`. The read-only Firebase audit on 18 November 2026 found one active record, Main Branch, with no coordinates. No address or coordinates were fabricated.
- Booking, coach publication and availability already use branch assignments and active branch records. Current booking admission uses organization-wide paid entitlement and actual Coach assignment. Existing payment records retain their original branch references.
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

- Clean-source Android arm64 Debug and Admin Web Release builds are in `build/multi-branch-release/source/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` and `build/multi-branch-release/source/apps/admin_web/build/web/`. These are local artifacts. The web bundle requires the existing authorized App Check configuration for signed-in service use.
- Six Flutter fixture screenshots are in `build/multi-branch-release/`: `admin-branches.png`, `admin-inventory.png`, `admin-visit-qr.png`, `member-branches.png`, `member-branch-details.png` and `member-visit-history.png`. Their records and QR are synthetic, separate from production data. Map, full booking and Reports captures are still pending.
