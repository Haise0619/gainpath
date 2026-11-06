# Business Dashboard presentation — 5 November 2026

## Current status

The ordinary Admin client has a single business Dashboard with the existing sidebar, purple branding, typography and date selector. This presentation supersedes the source-separated4November layout recorded below. **Private client ACTIVE; fresh live Admin browser acceptance PASS.** The compact follow-up activated at10:25 MYT with served JavaScript SHA-256 `bc7b1154c7247c570c2575b8164a2a0fabe2704e559834ba6a1311a888f890a0`; the09:34 bundle remains preserved. A final read-only check confirms all72 Functions and870 protected records plus Rules/indexes/IAM unchanged. Browser access recovered on5November. The localhost static server was restarted without rebuilding or changing the client. Existing canonical Admin acceptance observed22 active Members,9 active Coaches,54 workout sessions,38 bookings,21 active subscriptions and MYR5,772 recorded revenue (MYR4,191 membership + MYR1,581 coaching). Today yields zero dated bookings/revenue while current census stays22/9. Last90days was restored. Reports retains the combined Revenue Overview and expandable financial detail table. The downloaded business CSV reconciles monthly1948+2645+1179 to5772 and contains no Member identifiers. Fresh screenshots are live proof, separate from fixture/emulator renders.

## Compact shell and loading follow-up — 5 November

Owner requested a narrower sidebar/header and an explanation of slow loading and ports. Sidebar is224px (collapsed72), header minimum64px with smaller16px breadcrumb and12px subtitle; navigation13/12.5px retains44px targets and existing responsive drawer/text scaling. The Dashboard previously rendered AdminReportingFeedback plus a second identical summary progress bar; the duplicate is removed. The workout section keeps its own contextual loader. Concurrent identical workout reads now share only an in-flight request within the account-scoped gateway, with caller session revalidation, eviction after completion/failure and no completed-result cache. This reduces redundant requests from report panels, not the underlying initial source-scan duration. Server authorization, bounded reads and source validation are unchanged.

Port7359 serves the prepared ordinary private release. Port7360 is the IDE Flutter development launch; both use Firebase, and origins retain separate sign-in sessions. Historical October references to mock7359 are obsolete.37 focused tests pass, including concurrent reads, account-switch rejection/retry, loading indicators and responsive shell. Scoped Flutter analysis and release build pass. Prior client and exact release evidence are preserved in build/admin-compact-20261105. Fresh existing-Admin browser acceptance confirms22/9/54/38 KPI values and MYR5772 revenue in the compact shell; live-dashboard-after.jpg captures it. All72 Functions/870 protected records and infrastructure remain unchanged. Initial workout read latency remains visible and has not been claimed solved. No backend deployment, Firebase write or native build.

## Presentation and calculations

Four primary KPIs show current Active Members/Coaches, date-filtered Workout Sessions and recorded Booking activity. Revenue Overview contains one combined monthly chart, Membership/Coaching Revenue and a matching breakdown. Membership Overview combines current plan records and excludes expired/unknown plans from active subscriptions. Booking Overview combines existing created-booking outcomes and dated appointment records; this is recorded activity, not a reservation or capacity claim. Workout Overview reuses the validated session/exercise aggregation and displays each compatible form group independently. Membership Trends displays dated Member registrations, not inferred attendance or subscription renewals.

The existing authoritative receipt total is never overwritten. The displayed recorded-revenue metric combines eligible collection values and non-cash scenario entries under this on-screen/export definition:

> Recorded membership and coaching value includes non-cash scenario entries; not settled cash, net income or payouts.

Membership, coaching and monthly values reconcile to that same metric. Refund/review cases remain excluded from the collection contribution; cancelled scenario appointments contribute no revenue. Financial details remain available within Reports, including plan filters, purchase/renewal counts, payment/refund states, comparisons and detailed CSV. Dashboard/Report business exports use the same combined metric and date boundaries. Internal provenance, original audit exports, ownership and payment lifecycle states remain unchanged. No fake provider reference, verification, settlement, entitlement, reward or enrollment is created.

Ordinary business views remove prominent FYP/Sample/Sandbox/Simulation source labels and counts. Existing identities and stored names are retained. Read-only controls stay enforced. Supplied credential records do not become external professional verification, recorded Program assignments do not become activated enrollment, and mock ranking is shown as rule-based relevance rather than actual AI inference.

## Implementation and validation

New files: `apps/admin_web/lib/features/analytics/application/business_dashboard_metrics.dart`, `presentation/admin/business_dashboard.dart`, `apps/admin_web/lib/shared/admin_business_copy.dart`, `apps/admin_web/test/business_dashboard_test.dart` and `tools/admin_web/business-release.cjs`. The existing Dashboard dispatches the unified gateway to the business composition. Existing Reports/Revenue, Member/Coach details, Programs and recommendation/workout presentations receive minimal terminology/binding changes; their existing routes and mutation boundaries remain. The normal non-unified legacy Dashboard remains available to its existing composition.

109 focused Admin tests pass, including known-answer monetary/monthly reconciliation, membership states, null/unavailable values, mismatched dates,relevant Module12/13/account/content regressions, narrow layout and independent workout retry. Source/test TypeScript checks and changed-scope Flutter analysis pass. The staged ordinary Web release build succeeds. No APK or native build was run. Six dedicated actual Auth/Firestore/Functions emulator checks pass, including ordinary canonical Admin login, the combined revenue visualization, the fully loaded52-session KPI, existing queue navigation, authorization denials and original data preservation. They use synthetic records only and are separate from live browser acceptance.

One fresh independent review found no Critical issue and three Important issues. All three were reproduced and corrected in one pass: retained Reports financial controls, a persistent refresh/retry for independent workout failure, and visible compatibility identity for same-exercise form scores. Tests verify each correction.

## Release, evidence and recovery

Evidence root: `build/admin-business-dashboard-20261105/`. The existing private client is preserved under `before/`; staging is under `web/`. The source/build digest, successful tests, clean analysis and review are bound before activation. The unchanged loopback7359 mechanism serves the ordinary application. Assets are copied before entrypoints and served JavaScript hashes are verified. The existing tested recovery utility can restore known old/new partial-copy states and refuses unrelated bytes. No bundle is deleted.

Read-only preservation checks verify all72 deployed Functions, Rules, indexes, existing transport/project IAM and870 protected original plus projection/control records against the accepted baseline. The release tool contains no Firebase data-write or deployment path. No cohort re-seed, price/financial source mutation, account/claim change, provider/Gemini call, generation, Send, new consent or policy activation occurs.

The before image is the preserved actual4November browser screenshot `before-dashboard-20261104.jpg`; it is not represented as a new5November capture. Fixture/emulator screenshots disclose substitute offline fonts and synthetic data. Fresh5November live screenshots are saved as live-dashboard-after.jpg and live-reports-financial-after.jpg; the accepted CSV is live-business-overview.csv. Read-only preservation verification was repeated successfully after browser access recovered. A browser console warning notes missing glyphs in the installed font set; analytics and controls loaded successfully. Slow report reads initially show unavailable/loading placeholders before completing.

Native verification and real-Member recommendation consent, retention, thresholds and release-policy decisions remain held.

---

# Unified operational Admin integration — 4 November 2026

## Current checkpoint

**Deployed; existing real Admin browser acceptance passed.** The bounded live command update,232 exact-owned projection/control documents and matching ordinary private Admin are active at **http://localhost:7359/**. Local regressions, actual default-database emulator checks and final live preservation verification pass. The existing canonical Admin session sees the combined data without a fictional Admin login. Native verification remains deferred by the owner.

This implements the owner’s `bb768316-c5b3-4224-bc17-552ece8b933d` directive. It preserves `gainpath-0619` / `(default)` and the existing persistent `orgs/gainpath/cohorts/fyp-v1` graph. It adds an authorized server read model rather than copying identities into canonical collections. The earlier [FYP release](gainpath-fyp-live-integration.md) records the unchanged original cohort and delivery checkpoint.

## Access and architecture

The existing canonical Admin keeps the normal Admin login and canonical `SessionScope`. Fixed `admin.unified.*` operations use the existing Singapore `fypDatasetCommand` transport. Every request requires Firebase Auth, verified email, App Check, fresh SDK identity, current canonical Admin membership/lifecycle, organization `gainpath`, no dataset assignment, the original active cohort/release and a separately exact-owned enabled integration grant. Authority is checked again before a response is returned. A current Firebase UID check also rejects responses during account switches.

The in-process canonical Admin read scope cannot be serialized or forged. Its scoped store denies every create/set. No fictional Admin impersonation, new role, public cohort access or client-side cross-Member query is introduced. Unified recommendation operations permit existing Insights, configuration/choices and queue/detail/status reads only. Refresh, Send, Dismiss, configuration/consent writes and delivery processing are denied.

Directory scans are bounded to 1,000 rows per source, at most 2,000 merged rows, with at most 50 returned per page. IDs use stable ordering and collisions fail closed. Existing manifest paths must still exist; returned FYP source/generated records require exact ownership. Missing/changed sources, foreign organization data, excess limits and upstream failures return safe errors rather than partial totals. Report output is capped at 256 KiB. Workout aggregation retains the original combined 200-Member/2,000-record/16-MiB limits and compatible scoring groups.

## Ordinary Admin behavior

| Existing surface | Integration |
| --- | --- |
| Dashboard | Calculated combined active account census, source breakdown, record-creation trend, published Program/Routine counts and separately labeled sample business chart. Unified default is last90 days; existing range options remain. |
| Member Management | Existing eligible canonical Members plus all18 FYP Members, without fictional login. FYP details expose existing profile/goals, validated synthetic activity summary, illustrative Program/subscription/appointment relationships and existing recommendation/notification history. FYP details are read-only. |
| Coach Management | Existing canonical publications/drafts plus all8 FYP Coaches. Seven remain published; the eighth remains inactive. Synthetic credential metadata is explicitly distinguished from external professional verification. Current cohort availability/roster reads and sample appointment summaries are supported. |
| Programs / Routine Templates | Combined server catalogs and published destinations; FYP records are read-only. Canonical Program editors cannot select FYP Routine references, and the adapter rejects them before a canonical write. |
| Reports / Workouts | Existing validators and date aggregation plus52 synthetic observations, explicit mixed-source classification and CSV provenance. Scored/unscored/null/compatibility semantics are preserved. |
| Reports / Revenue | Existing confirmed Sandbox receipt definitions remain unchanged. The separate sample section shows linked subscriptions, completed/cancelled appointments, MYR monthly simulation and an explicitly illustrative sum. Section CSV carries dates and simulation definitions. |
| Recommendations | Existing Exercise Insights, Trainer Matching and Content Recommendation queues through read-only adapters. The original2 runs/12 leads and existing delivery history are reused. No generation or Send is repeated. |

Counts use their actual inclusion rules. Active census requires current eligible identity/membership; administrative directory totals may include inactive/pending records. Member record creation includes fictional provisioning and does not assert login or gym attendance. Published Routine destinations do not make every image-only Exercise Catalog entry an instructional tutorial. Actual canonical totals must be read from the authorized live response; raw document counts and the illustrative “4+18=22” example are not hardcoded.

## Sample business contract

The deterministic plan creates114 simulation rows, one manifest and116 ownership proofs. Activation adds one grant: **232 new exact-owned documents total**. They occupy only cohort `unifiedSampleBusiness`, `unifiedSampleManifests`, `unifiedSampleOwnership` and the fixed `orgs/gainpath/adminDataIntegrations/fyp-v1` control document. Original seed ownership is untouched.

The rows comprise3 plan references,18 subscriptions (six each Free/Basic/Premium;17 active,1 expired),18 illustrative Program relationships,24 fictional appointments (16 completed,8 cancelled),35 membership and16 coaching ledger entries. They share stable Member/Coach/Program references and Malaysia dates in September–November2026. Cancelled appointments contribute no simulated revenue. Appointment branch is `main` and does not reserve a slot.

Live preparation references the existing active Basic89MYR/Premium129MYR,30-day plan definitions and versions; it does not change prices. The illustrative coaching fee is80MYR and is not represented as an actual Coach fee or settlement. Full source-window simulation is **MYR5,075**:18×89 +17×129 +16×80. November simulation is MYR1,179. Emulator known-answer fixtures intentionally use59/99MYR and total MYR4,025; those are test results, not live financial data.

Every row declares `fyp_business_simulation` and MYR minor units. There are no gateway references, verified payment states, tax receipts, real reservations, wallet credits, refunds, awards or membership entitlements. Existing confirmed provider **Sandbox receipts** remain a separate metric; neither they nor the simulation are presented as settled real income or profit.

Staging is atomic, create-only and accepts only issued immutable plans. Identical unowned records, orphan proofs, changed bytes and an existing activation grant are refused. Activation requires the complete exact staged projection and creates only the grant. Exact activated retries are idempotent. No source/consent/recipient/notification record is rewritten.

## Verification and review

Fresh focused results are retained in ignored `build/unified-admin-20261104/`:

| Check | Result |
| --- | --- |
| Backend focused tests |86 passed,0 failed, including scope/FYP/A1-A2 reporting regressions and recovery |
| Ordinary Admin regressions |121 passed,0 failed; subsequent33 focused Routine/Program checks pass after the live catalog-reference correction (overlapping checks, not an additional independent total) |
| Shared domain regressions |14 passed |
| Mobile Program regressions |14 passed; no Mobile source change or APK build |
| TypeScript | Source no-emit, test types and isolated release compilation pass |
| Scoped Flutter analysis | No issues found |
| Ordinary Admin Web | Release build succeeds into a separate directory; previous served bundle preserved |
| Actual Firebase emulators |6 integration checks pass, including actual ordinary Admin login/widgets,52-observation calculations, default-off/role/App Check/privacy denials and preservation |

The emulator uses `demo-gainpath-fyp` only, actual Auth/Firestore/Functions, the original source graph and replayed already-authorized fictional runtime state. It performs no inference/generation/Send or live fallback. Its canonical Admin fixture is not the owner’s real account. Screenshots under `screenshots/emulator-*.png` are explicitly **emulator widgets**, including populated ordinary Dashboard and Reports components, not signed-in live browser acceptance.

One independent fresh-context review found no Critical issue and five Important issues: activation ownership/adoption, mixed-source labels, missing expected sources/unowned notifications, FYP Routine references in canonical authoring, and interrupted Admin-copy recovery. All were corrected and checked. The first four were reproduced with failing behavioral tests; recovery is covered by a temporary-directory interrupted-copy test that also refuses unrelated concurrent bytes. Package sealing binds deploy sources, the compiled writer, operator scripts, Admin/domain/data/UI sources, test evidence and exact Admin build inventory.

## Changed implementation

Backend contracts/readers: `functions/src/modules/dataset/unified-admin-{scope,reader,reporting,backend}.ts`, `unified-{sample-business,business-reader,sample-plan}.ts`. Existing `fyp-{scope,backend,module-services}.ts` and `fyp-release-index.ts` receive the minimal scoped integration. Normal Functions index is unchanged. `unified-local-index.ts`, `tsconfig.unified-admin.json`, dedicated emulator test/config and focused `unified-*.test.ts` provide isolated verification.

Admin adapters: `firebase_unified_admin.dart`, `unified_admin_directories.dart`, `unified_admin_content.dart`; ordinary DI/shell and reporting gateway. Existing Dashboard/Reports/workout definitions gain typed source summaries and `UnifiedBusinessSection`; Member/Coach/Program/Routine presentations receive read-only guards. Shared domain additions are optional source/read-only metadata, preserving existing constructors. Recommendation queue/config controls use a read-only presentation capability. Focused Admin tests and `test/emulator/unified_ordinary_admin_test.dart` exercise these paths.

Controlled release tools: `functions/tools/unified-admin-{platform,release,prepare,web,web-files,emulator}.*`. The proposed command ZIP changes four existing compiled modules and adds six read modules; operator/writer/local emulator code is excluded from the deployed archive. All other archived files are byte-preserved.

## Live release and recovery

The approved sequence is `unified-admin-release.cjs plan/review`, exact reviewed staging, `apply`, one existing command source-only `deploy`, `activate`, `verify`, then `unified-admin-web.cjs activate`. The operator uses only the existing approved Firebase CLI credential. Its sealed evidence must match; it stops on source/data/configuration drift rather than searching for other credentials or retrying a mutation blindly.

Before/after evidence covers72 Functions (71 unchanged), the two callable transport policies and registration IAM, Rules release, indexes, project IAM, bounded canonical records and original FYP source/runtime hashes. Runtime/environment/IAM remain unchanged. No Rules/index/IAM deployment is needed. Previous command archive and ordinary Admin bundle are retained. Access-only rollback `unified-admin-release.cjs disable` verifies exact ownership and disables only the new grant/proof. `unified-admin-web.cjs rollback` accepts known old/new partial-copy bytes, refuses unrelated changes and restores previous entrypoints last without deleting either bundle. Neither rollback deletes original cohort or sample data.

Actual command revision is `fypdatasetcommand-00004-dos`, updated at `2026-11-04T14:12:59.119962907Z`. Command archive SHA-256 is `7410790cdd959c29a7fbe15de41b63087793c833661950ce6c9a976300f95754`; final served ordinary Admin JavaScript SHA-256 is `79728b7b2832c922125a2b36d7d5285e561548fde2440530caee271c0fbdff1a`. Final `command-deployed.json`, `live-verification.json` and `admin-activated.json` verify source-only configuration/IAM preservation,638 unchanged protected records,71 unchanged other Functions, unchanged Rules/indexes/project IAM,232 exact new records and the served client hash.

One activation verifier stalled during a read-only preservation check. The new grant was independently confirmed absent before stopping only that task-owned process. Phase-only diagnostics were added and the seal refreshed without changing product/archive/writer/permission semantics; the same checks then passed and activation created exactly one grant. The existing port7359 loopback server had stopped, so its unchanged `serve.cjs` mechanism was restarted hidden; no browser/session data was cleared.

Live acceptance exposed shared exercise IDs in FYP Routine references. The initial FYP-only name lookup missed canonical entries; a combined source query correctly refused duplicate exercise IDs. The final adapter reuses the existing canonical `TutorialRepository` for stable exercise names, while reading owned FYP blueprints through the server. It refuses unresolved references and preserves server collision checks. Both failure conditions were reproduced and corrected with focused tests. This was a client-only correction; no backend re-deployment, catalog rewrite or dataset re-seed occurred. The original served bundle and both intermediate client versions are preserved for recovery.

## Limits and remaining acceptance

Browser access initially remained disabled, then became available. The existing real Admin session was recovered normally at the existing URL without entering a password or reading storage. Before activation its actual canonical Dashboard showed4 current active Members and2 current active Coaches. No real Admin password or token was extracted, minted or replaced.

Actual signed-in browser checks passed for Dashboard,22-Member directory (all18 FYP),11-Coach directory (all8 FYP;7 remain published), read-only fictional Member details/history, Coach review/working-hours navigation, Programs (3 canonical +3 FYP), and24 Routine blueprints (12 canonical +12 FYP). FYP authoring controls remain disabled; the Coach schedule explicitly says booking unavailable. The final Routine lookup was rechecked in the served corrected build.

The actual90-day Dashboard shows **22 active Members,9 active Coaches,54 descriptive workout sessions (2 canonical +52 FYP),6 published Programs and23 published Routine destinations**. Source breakdowns show4+18 Members and2+7 active Coaches. Existing confirmed Sandbox receipts are **MYR697**, separate simulation is **MYR5,075**, and the labeled illustrative sum is **MYR5,772**. Current sample subscriptions are18 (17 active/1 expired); appointments are24 (16 completed/8 cancelled). Today correctly changes dated receipts/simulation/appointments to zero for this dataset while retaining current account census; restoring90 days restores the source totals.

Live Exercise Insights displays configuration revision1, compatible scored groups/missing-score/coverage definitions and the existing Reverse lunge instruction gap. Both existing queues show4 pending and2 processed leads; Trainer details load with supported facts and ranking provenance. Mock semantic rankings remain labeled mock, deterministic fallback remains labeled, Refresh queue is disabled and no Send/Dismiss action is exposed. No new inference, generation, decision or delivery occurred.

The ordinary Reports page renders combined census and the same separate sample section alongside unchanged canonical commerce, engagement, reward and booking reports. The actual section export is retained as `build/unified-admin-20261104/live-sample-business.csv`, SHA-256 `0347dd18ce6c83b4150064755db8c82b6011762cdd9abe0d4d5d63b4dc9d6efa`. Its minor-unit totals507500/577200, monthly194800/194800/117900, source counts, dated boundaries and simulation definitions match the screen; it contains no Member IDs, emails or individual histories. The browser download-event helper timed out, but the successful exact-named download was independently recovered from Downloads and verified; no duplicate export retry was needed. Private `screenshots/live-*.jpg` capture actual browser evidence; `emulator-*.png` remain separately labeled fixture evidence.

Actual canonical commerce, check-in, rewards, engagement telemetry and booking definitions remain intact. Fictional appointments/Program assignments are simulation summaries rather than actual bookings/enrollments. Existing receipt/reward/settlement/financial mutation workflows remain canonical. The canonical Exercise Catalog authoring repository and ordinary Member/Module6 public-data services have not been broadly merged across private cohorts; unified Admin published Routine/Program and recommendation readers provide the supported shared content views. No fabricated tutorial usage, real camera acceptance, login activity, Gemini conversations or external credential verification is claimed.

Real Member recommendation processing, consent collection/defaults, historical backup reuse, thresholds/minimum-cohort suppression and retention/expiry decisions remain held for owner policy/release review. Existing original Module13 requirement traceability remains in the A1–E/final reports. No new clinical-risk threshold, real Gemini request, notification delivery, automatic LeadEvaluator, financial/reward/booking effect, account/claim change, deletion, APK or native test occurred in this task.
