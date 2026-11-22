# Multi-branch gym management and map integration

## Phase 7 — Assistant branch routing (19 November 2026)

The exported Singapore fitnessAssistantCommand had an anchored branch fast path and a Gemini registry without branch tools. The production archive reproduced that mismatch. The fast path now handles clear current/home/nearby questions, while unmatched natural language can invoke lookup_gym with validated structured arguments. The server resolves directory, details, opening hours, facilities, equipment and verified coaching options using the signed-in organization. In public mode, the app can send the last branch card name as a reference, while prior conversation text stays out of the provider request. Nearby uses the existing permission-gated on-device finder.

Production source-only release: fitnessassistantcommand-00007-hiv, SHA-256 f693cae42cebc7407574a055556d7939f39b2201c61c9f6ebe9d77c7e50fb5af. Runtime and IAM verified, anonymous calls return 401. Rollback: build/multi-branch-release/phase7-asia-southeast1-FRLSwD/rollback.zip.

Verification: 57 backend tests, TypeScript test typecheck, Functions build, Flutter DTO and widget suites, scoped Dart analysis and Android Debug build passed. Read-only production Assistant bootstrap returned 200 with existing ordinary and FYP test identities. Missing Auth and missing App Check returned 401, and foreign organization returned 403. Production reply was not invoked because reply updates the existing rate-limit state. Real Gemini was not called by verification. APK: apps/mobile/build/app/outputs/flutter-apk/app-debug.apk.

Manual acceptance: ask “which gym i currently using” after changing Selected Branch; ask “whats my home branch”; ask “which gym iz nearest to me” and open the finder with location allowed and denied; ask “where is gainpath 2” followed by “what time does it close”, “does it have a treadmill”, and “how do I get there”; ask for Jackson’s available times in each branch and compare against the existing booking view; ask a normal fitness question. Real Gemini phrasing and physical location/navigation remain pending. Rendered fixture screenshots: build/chatbot-message-refinement/screenshots/branch-card.png and nearby-gyms.png.


## Phase 6 — Reports simplification (19 November 2026)

**Superseded — Replaced by Dedicated Branch Analytics:** Global Branch Filter across all Reports Categories.

**Root cause:** The schema-2 Organization-wide commerce extension rejected every non-Billplz payment during source validation, before pending records were excluded from receipt totals. Its provider contract fell out of sync with the direct core aggregation after Xendit integration. The deployed unified Admin endpoint also retained the older Billplz-only base validator, so cleared Xendit receipts failed there even after the extension predicate was corrected. The same organization source scan ran for short and all-recorded date windows. Specific branches used the separate Branch Report reader. Fitness and Engagement used independent sources. The fix permits Xendit for coaching while retaining strict cleared-receipt checks and excluding pending records from receipts.

**Implemented:** Overview, Financial, Fitness, Coaching and Engagement keep organization-wide scope and their existing reporting components. Reports → Branches uses the existing authorized branch callable for All branches comparisons, inactive branches, Unassigned records and individual branch trends, inventory snapshots, daily tables and CSV. Branch Details → Reports opens Branch Analytics with the selected branch. Confirmed sandbox coaching receipts and actual revenue are separate. Actual revenue is unavailable under the current sandbox contract.

**Tested:** 151 focused backend tests, including booking settlement and Xendit checkout, TypeScript test typecheck and Functions build. 39 Flutter reporting tests passed and the final navigation/dialog rerun passed 11 tests with clean scoped Dart analysis. 14 Firestore Emulator tests passed across organization and branch reporting. Rendered screenshots use synthetic fixture data: `build/multi-branch-release/phase6-fixture-overview.png`, `phase6-fixture-all-branches.png` and `phase6-fixture-specific-branch.png` in the same directory.

**Release build:** Existing private App Check configuration and enabled Recommendations flag. Localhost:7359 serves the exact release bundle SHA-256 `74a801af167ae26d6cfdb76abe0254bcac08fb21406a7df5891b5e19fc36e6c9`. Previous bundles were retained. Android Studio's existing Admin configuration was retained. The Member app did not require a rebuild.

**Deployed:** Singapore `adminReportingCommand` (revision `adminreportingcommand-00004-zav`), `fypDatasetCommand` (normal Admin UI, revision `fypdatasetcommand-00022-ziz`) and `branchManagementCommand` (revision `branchmanagementcommand-00003-yes`). Active status, exact source hashes, runtime settings and IAM were verified. Rollback ZIPs and metadata are retained under `build/multi-branch-release/phase6-org-dsIWat`, `phase6-unified-Mr1La5` and `phase6-branch-report-du09Qa`.

**Production verification boundary:** The existing test identity passed Auth and App Check, but lacks access to the canonical organization. The exact production packages passed read-only canonical data replay for All recorded dates, 7, 30 and 90 days, and for branch comparison, both branches and Unassigned. The existing authenticated FYP Admin received 200 on its own cohort, canonical access was correctly denied, and anonymous requests returned 401. Signed-in canonical Admin browser and Callable acceptance are still pending. No production payment, booking, inventory or notification records were written.

**Manual acceptance pending**

1. Open Reports → Overview. Run All recorded dates, 7 days, 30 days, 90 days and a custom MYT range. Refresh and confirm CSV includes the same reporting scope.
2. Open Financial, Fitness, Coaching and Engagement. Verify date range, refresh and CSV on each and confirm the Branch filter appears only under Reports → Branches.
3. Open Reports → Branches from the sidebar. Check All branches comparison, use View details, and compare date-scoped KPIs, daily rows and CSV. Change dates and check that inventory and assignments remain current snapshots.
4. Switch to an inactive branch and Unassigned. Check the report explicitly shows unavailable data when applicable. Confirm that pending sandbox attempts are excluded from receipts and membership receipts remain organization-wide.
5. Open Branch Details → Reports for each test branch. Verify the correct Branch Analytics filter is selected and can be cleared.


## Phase 5 acceptance follow-up

- The 20 November 2026 01:00 MYT booking stores its actual activity branch and 60-minute duration. The related RM100 Xendit attempt was pending with reconciliation_required / bill_creation_uncertain. Neither a provider session ID nor a checkout URL was persisted. The callable returned HTTP 200 on 19 November 2026 around 12:32 MYT. The raw provider response was not retained, so the exact reason for this individual provider outcome is unverified. No payment or lock was changed.
- The adapters previously accepted Xendit short links only. The mock test now exercises a documented checkout-staging.xendit.co session URL. The TypeScript gateway and Dart checkout URL validation support the documented HTTPS hosts with a constrained session path.
- The only updated production function was createBookingPaymentCommand in Singapore. Its source-only overlay, runtime configuration and IAM were verified. Original and staged ZIPs are retained under build/multi-branch-release/phase5-baselines and phase5-overlay.
- The Member Coach Directory loads the active branch names and all Coach directory pages before applying location, search and specialty filters. Local browsing does not persist branch preference changes. Coach cards show known assigned branch names.
- Verified 65 targeted backend tests, backend compilation, 19 Member Flutter tests, and Android Debug arm64 build. Real Browser / Xendit Sandbox acceptance remains manual.

## Current delivery status

- **Implemented:** Admin can edit Coach assignments and dated availability in the existing schedule view. Writes reuse revisions, branch IDs and global Coach slot locks. Branch Details opens scoped Members and Bookings alongside the existing drill-downs. Member scope uses Home Branch with primaryBranchId fallback. Reports shows daily trend, date details and scoped CSV. Automatic Coach matching and Outreach Home Branch filtering retain the existing recommendation flow.
- **Tested:** 149 targeted repository backend tests, TypeScript compilation and typecheck, scoped Dart analysis, 23 Admin widget regressions and two Coach roster widget tests. The Firestore Emulator branch test passed with daily totals and concurrent QR deduplication. Three recommendation fixture failures reproduced identically on the downloaded production baseline and overlay, covering existing routine behavior outside this change.
- **Deployed:** Eleven Singapore source-only updates are ACTIVE. Downloaded hashes, runtime configuration and IAM matched expectations. The 69 other endpoints retained their source. Rollback ZIPs and metadata are retained locally under build/multi-branch-release/release2-baselines.
- **Production verification:** Existing verified TEST Member with registered App Check returned 200 for Branch list and 403 for Admin-only Coach assignments. Anonymous Module 13 Admin, Booking List and Assistant calls returned 401. Positive Admin role workflow acceptance remains pending.
- **Cancelled — Intentional Scope Reduction:** Equipment compatibility and ID mapping, equipment-based Routine filtering, Planner branch scope, and Outreach gym visit analysis.
- **Manual Acceptance Pending:** Verify Coach assignment and dated schedule changes for an authorized Admin, confirm overlap is rejected, then open Members and Bookings from Branch Details. Compare a historical branch report with its CSV. Verify Outreach Home Branch results and recommendation booking destination using authorized test records. Android device, Maps, QR and Xendit Sandbox verification remain manual.
- **Builds:** Android Debug APK built successfully. Private Admin Web is active on localhost:7359, served SHA-256 fa9d8003cc5aacad59654ed1797258ae35836264d82130e9025d6a7a0047d1c3. Existing Android Studio run configurations and private App Check config were retained. The Flutter Reports fixture is build/multi-branch-release/release2-reports-fixture.png.
- **Source:** 8339463 contains the Admin and branch backend integration. Existing mixed AI edits are preserved in the working tree.

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

## Admin Branch Management Hub

The Admin console owns the Branches breadcrumb and browser routes. The directory opens in Grid view and retains search, status, view and marker selection when the administrator opens another branch page. Summary cards count authorized records currently available to the directory and label paginated results as loaded branches.

- `BranchDirectoryPage` holds the existing directory request and cursor state. `branch_admin_directory.dart` renders the grid, split map and branch overview. Branch-specific Equipment and Check-in & visits use `BranchActivityPage`. Members, Bookings, Coaches and Reports reuse their established branch-scoped views.
- The editor opens at `/console/branches/add` or `/console/branches/<id>/edit`. The permanent ID stays immutable on rename. Covers use the existing JPG/PNG upload and the branch keeps the saved URL only after a successful form save. Location picking stages a coordinate pair independently of the street address until confirmation.
- Opening hours use the existing Monday-first, seven-day Malaysia time schedule. The supported day states are Closed, 24 hours and a single interval that can cross midnight. An unset schedule remains unavailable. Facilities remain free-text values.
- New forms preselect Active, consistent with the prior editor. Inactive branches remain available to administrators for supported operations and visit history. Only active branches can generate new visit QR codes.
- The directory map uses saved coordinates and OpenStreetMap. Administrators can still manage branches without valid coordinates. Tile status distinguishes loading, partial coverage and failure. Manual retry uses the current viewport. The existing branch callable remains authoritative for authorization and mutations.

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
