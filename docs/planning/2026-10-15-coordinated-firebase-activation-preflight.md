# GainPath B1–B4 coordinated Firebase activation preflight

Read-only observation on 2026-10-15 MYT (API snapshot `2026-10-14T23:21:40.099Z`), project `gainpath-0619`, organization `gainpath`. This document proposes future gates; it grants no deployment, account, policy, App Check, booking or device authorization. Approved integrated source: `0fb4d23172bb18d5f09cf0c829b5cf768b191609`. The source CI result is recorded in the [integration report](../architecture/2026-10-15-b4-hold-lifecycle-implementation.md).

## Current verified readiness

Evidence: ignored `build/b3-b4-integration/firebase-readiness.json`, API status map and deployed Rules copies. OAuth refresh/authentication stayed in memory. Auth lookup was a read operation; no sign-in, verification email or business command was invoked. Reports exclude emails, raw Auth records, private tokens and full media URLs. Cloud API access is not application Admin authorization.

| Area | Current observation | Required gate |
|---|---|---|
| Organization / branch | `orgs/gainpath` active, schema 1; `branches/main` active | Fresh revision checks before mutation; preserve IDs/status and unrelated fields |
| Firestore | Native `(default)`, `asia-southeast1`, pessimistic concurrency | Keep existing database; Functions remain `us-central1` as current source/default client region |
| Booking policy | `orgs/gainpath/settings/booking` returns 404 | Explicit approval of values and creation; timezone is **not configured yet** |
| Canonical Admin | **No `role: admin` membership** | Approve exact existing identity/role change or a genuine new Admin; no Staff authority workaround |
| Current identities | Three active, correctly assigned memberships: one Staff, two Members. All three Auth users observed enabled and email verified, branch `main` | Select consented development participants; do not expose IDs/emails publicly |
| Coach | No Coach membership; private/public Coach collections empty | Separately approved genuine Coach Auth + current user/membership records; owner verifies email normally |
| B1/B2/B3/B4 Functions | **All nine required exports absent** from complete v1/v2 deployment lists | Selective approved deployments; source integration alone enables nothing live |
| Existing deployed Functions | Five active Node 22 v2 exports: member provisioning, trusted routine publication and three workout consent/submission commands | Preserve all five revisions/settings; never deploy the entire source codebase incidentally |
| Firestore Rules | Current release differs only at B1 Coach directory/private-profile and B3 booking read blocks from local source | Approve exact reviewed Rules patch; client writes remain denied |
| Storage Rules | Live bucket Rules deny all client reads/writes; local Storage Rules differ | **No Storage deployment is needed for booking. Preserve live Rules** |
| Indexes | Three deployed READY indexes: content `(status,kind)`, bookings `(coachId,startAtMillis)`, notifications `(recipientId,createdAtMillis DESC)` | Add only the three missing indexes below and await READY |
| Billing / APIs | Billing enabled; Functions/Run/Firestore/Auth/Build/Artifact Registry/IAM APIs enabled. Scheduler API absent from complete enabled-service list; Scheduler GET returns 403 | Separately approve Scheduler API enablement/service-agent setup; job state cannot currently be enumerated |
| Scheduler IAM | No project Scheduler service-agent binding observed. Existing default compute account has project Editor | Approve/verify least necessary Scheduler invocation and runtime permissions; do not silently grant roles or broaden public access |
| Android registration | Existing active `com.zyang.gainpath` app; Play Integrity configuration resource exists, TTL 3600 seconds; **zero registered signing certificates** | Real certificate/provider/Play configuration and genuine token test still required |
| App Check enforcement | App Check services list returned empty; no debug-token list was read. Source options/create/cancel callables enforce App Check individually | Preserve per-callable enforcement; Console-wide enforcement and debug registration remain unverified/unchanged |
| Admin Web | Existing web app/domain configuration; localhost authorized; Hosting site exists but no release returned | Firebase-mode local server/browser smoke first; Hosting is an optional separate approval |
| Phone | Read-only ADB enumeration found no authorized connected device | Installed APK/signature/version/data rollback state is unverified; no build/install was performed here |
| Booking resources | No booking, slot-lock, booking-day or job documents; no Coach draft/public documents; three existing command receipts | Fresh bounded reads before worker activation; preserve receipts and all existing collections |

Important identity discrepancy: [FirebaseAuthRepository](../../packages/gainpath_data/lib/src/firebase_auth_repository.dart) maps Staff to the Admin **UI** role, but [B1 trusted authoring](../../functions/src/modules/coaching/coach-profile-service.ts) and B3 Admin list authority require canonical `admin`. Existing Staff login does not establish permission to publish Coaches. The CLI principal maps to an existing Member Auth identity, not a canonical application Admin. No identity was promoted or provisioned.

There is no trusted Coach-account provisioning command in B1–B4. A later approved administrative setup must bind a genuine Auth UID to `users/{uid}.organizationId = gainpath` and an active matching `orgs/gainpath/members/{uid}` with canonical `role: coach`, `organizationId: gainpath`, `branchIds: [main]`, preserving the normal schema and real identity fields. Admin authority similarly requires canonical `role: admin`; choose an existing eligible account or genuine new account explicitly. Public registration is Member-only and must not be repurposed to choose Coach/Admin roles. The SDK gateways resolve organization from the user record and role/branches from membership; these are not client-editable role selections or a request to invent additional custom claims. Require a fresh authenticated session after authorized provisioning/reassignment.

### Exact missing Functions and indexes

| Slice | Required exports, all currently absent | Server authority |
|---|---|---|
| B1 | `saveCoachProfileCommand`, `setCoachDirectoryStatusCommand` | Verified current own Coach / canonical Admin publication |
| B2 | `getCoachAvailabilityCommand`, `saveCoachAvailabilityDayCommand` | Scoped reads / current own Coach with revision and branch checks |
| B3 | `getBookingListCommand`, `getMemberBookingOptionsCommand`, `createBookingHold` | Scoped persisted reads / attested eligible Member options / attested trusted hold creation |
| B4 | `cancelBookingHoldCommand`, `expireBookingHolds` | Attested own Member pending cancellation / private scheduled server expiry |

Missing composite indexes (retain ascending `__name__` suffix supplied by Firestore):

1. COLLECTION `bookings`: `memberId ASC, startAtMillis ASC`.
2. COLLECTION `bookings`: `coachId ASC, branchId ASC, startAtMillis ASC`.
3. COLLECTION_GROUP `jobs`: `schemaVersion ASC, type ASC, status ASC, dueAtMillis ASC`.

B1 public-directory queries use the existing status/document-ID query shape; B2 uses bounded transactional date-document reads. No extra speculative indexes are proposed. All existing indexes remain in the source manifest.

### Policy proposal requiring approval

The policy does not exist; do not treat fixture values as configured facts. A minimal proposed document is:

```json
{
  "schemaVersion": 1,
  "policyVersion": "booking-v1",
  "timeZone": "Asia/Kuala_Lumpur",
  "maxActiveBookingsPerMemberPerDay": 1,
  "holdMinutes": 15
}
```

The cap/hold duration are decisions for approval. Source bounds: cap 1–32; hold 1–30 minutes; IANA timezone and bounded nonblank policy version. UTC half-hour grid, 30/60-minute bookings, one organization-local date; availability authoring is tomorrow through +30 days, while options span today through +30. Freeze timezone/policy during the first real test; changing timezone with active accounting requires a separate migration review. A 15-minute hold needs a real elapsed-time expiry test; never shorten a stored deadline or fake the server clock to manufacture live success.

## Ordered activation gates — each requires separate approval

| Gate | Exact future actions | Exit criterion / rollback boundary |
|---|---|---|
| 0 — source hardening | Approve the [two-validator repair proposal](../architecture/2026-10-15-firebase-demo-execution.md); implement/review locally, then separately approve push and exact-head CI | Repaired source green. No live schema/data repair. Existing approved HEAD remains recoverable |
| 1 — private baseline and participants | Refresh this preflight; choose exact Admin/Coach/Member identities; preserve private before-state snapshots/revisions of affected identity/policy/docs and deployed resource metadata | No unexplained drift; secure snapshots, stable IDs and named human owners. Do not commit raw records or credentials |
| 2 — infrastructure prerequisites | Separately approve the three additive indexes, Scheduler API/service-agent prerequisites and required IAM review | All required indexes READY. Scheduler API/agent available; **no worker job deployed yet**. Existing indexes/Rules/Functions untouched |
| 3 — compatible reads and Firestore Rules | Selectively deploy `getBookingListCommand` and `getCoachAvailabilityCommand`; apply only reviewed Firestore Rules changes | Handler/auth denial and honest missing-policy/identity failures verified; positive reads wait for Gates 4–7. No lifecycle writer. Roll back only these new resources/Rules if needed; preserve existing five Functions and Storage |
| 4 — genuine identities and policy | Approve exact Admin provisioning/promotion choice, genuine Coach provisioning and approved policy document; preserve current `users`/membership fields and branch `main` | Current canonical roles, org assignment, enabled Auth, real owner email verification, nonempty Coach branches and valid policy. Existing Members remain Members |
| 5 — App Check and compatible clients | Approve provider registration separately; prepare Firebase Admin Web and Member/Coach client; separately approve phone backup/build/install | Compatible `expired`/resolution readers ready **before any lifecycle writer**. Genuine attested options request can be tested once Gate 8 enables it. Mock build success is insufficient |
| 6 — B1 profile/directory | Selectively deploy the two B1 commands; approved Coach enters real professional data; Admin reviews and publishes using fresh revisions/current branches | Member sees only the published allowlist, stable UID. No fabricated certification/rating/earnings. Withdraw via trusted deactivate if rollback needed |
| 7 — B2 dated availability | Selectively deploy `saveCoachAvailabilityDayCommand`; Coach authors a future 60+ minute `main` window through real UI | Member/Admin see the same UTC interval with organization labels. Revise/remove only through expected revisions; no deletion/restoration over a reservation |
| 8 — lifecycle and protected options | After fresh zero/malformed-job checks and READY indexes, deploy `cancelBookingHoldCommand`, then `expireBookingHolds`, then `getMemberBookingOptionsCommand`; verify private worker invocation and real attestation | Worker service IAM excludes `allUsers`/`allAuthenticatedUsers`, Scheduler OIDC account is the intended invoker, empty batch succeeds. Options reject absent/invalid App Check. **No hold creator yet** |
| 9 — first real holds and smoke | Separately approve deployment of `createBookingHold` and the exact bounded real test records/participants; execute the checklist below | All three roles read identical persisted IDs/status; cancellation/expiry/replacement correct. Stop immediately on authorization/ownership inconsistency; do not enable confirmation/payment |

**Selective-deployment caveat verified in installed CLI source:** Functions `prepare.js` ensures manifest `requiredAPIs` before applying endpoint filters. The exported scheduled worker advertises Cloud Scheduler as required. Therefore even a read-only Function deployment may attempt API enablement despite `--only functions:<readName>`. Gate 2 explicitly approves/establishes the API prerequisites **before the first Functions deployment**; endpoint filtering still keeps the worker/job absent until Gate 8. Do not use a deployment or claimed dry-run as a read-only probe. Installed `fabricator.js` assigns scheduled invoker to the function's service account or default compute account; `cloudscheduler.js` uses it in OIDC. Verify actual IAM after the separately approved deployment rather than assuming source behavior is sufficient.

No broad `firebase deploy`, `--only functions` or Storage/Hosting deployment is authorized. No automatic enabling of unrelated APIs, IAM grants, resource deletion or full-repository deployment is part of these gates. The existing compute account's Editor role is observed inherited configuration, not a recommendation to grant Editor.

## Client/account setup and data preservation

- **Admin:** choose a real canonical Admin first. The existing authorized localhost domain permits a local Firebase-mode web server; proposed command after approval: from `apps/admin_web`, `flutter run -d web-server --web-hostname=127.0.0.1 --web-port=7357 --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=false`. Actual browser load/login/commands remain to be tested. Bound any CanvasKit failure investigation to the chosen smoke; do not switch to mock success. Hosting deployment is optional and independently approved.
- **Android:** verify `com.zyang.gainpath`, the existing Firebase app, installed version/signing certificate and current build defines. Release currently uses debug signing in Gradle; it is not a production distribution setup. Before approved install, preserve current base/split APKs privately and document package/version/certificate plus safe recovery of existing local data using supported facilities. Never uninstall, clear app data, force a downgrade or silently change application ID/signature. Abort installation on mismatch. A prior APK alone is not a backup of workout data.
- **Debug provider:** for a locally installed development APK, approve private debug-provider registration and use an explicit non-release debug build with `BACKEND=firebase`, `USE_FIREBASE_EMULATORS=false`, `APP_CHECK_MODE=debug`. Capture generated debug material privately; do not put it in Dart defines/source, Git, shell histories or public logs. Do not weaken enforcement. Default `APP_CHECK_MODE=off` truthfully leaves booking mutations unavailable. Source rejects debug provider in release mode. [Firebase debug-provider guidance](https://firebase.google.com/docs/app-check/flutter/debug-provider).
- **Play Integrity:** the observed configuration resource is not proof of successful attestation. Register the actual SHA-256 certificate and review linked Play project/distribution/verdict requirements for the intended build. Zero registered hashes and no real device evidence mean it is not ready to claim success. Do not assume a sideloaded debug APK meets the same verdicts as a Play-distributed release. [Official Android setup](https://firebase.google.com/docs/app-check/android/play-integrity-provider).
- **Scheduler:** verify the intended runtime identity's Firestore permissions and the Cloud Scheduler service agent/token generation; grant invocation only to the selected OIDC caller at the target service. The scheduled endpoint relies on IAM, not Member Auth/App Check. Source config alone does not prove live IAM. [Firebase scheduling](https://firebase.google.com/docs/functions/schedule-functions), [authenticated HTTP targets](https://docs.cloud.google.com/scheduler/docs/http-target-auth).
- Preserve all existing Auth users, user/membership/profile records, organization/branch, three command receipts, published content, Exercise Catalog, routine blueprints, consent/workout data and media metadata/tokens. Org collection discovery also observed profiles/content/exerciseVideos/routineBlueprints/workoutConsents. No deletion or migration is proposed. Snapshot hashes/revisions of the exact squat exercise and both routine records were captured without saving their private URL-bearing values; their future mutations belong to the separate tutorial activation task.
- Keep account-scoped local workout history, consent/outbox and current pose flags unchanged. Role testing can use separate app/browser sessions or deliberate logout/login; never reuse a stale session or share credentials. No automatic withdrawal of existing public Coach projections on later suspension/reassignment is claimed; new options/holds recheck current eligibility.

## Short three-role demonstration and acceptance checklist

1. Genuine Coach signs in, saves a professional draft; genuine Admin reviews/publishes; Member refreshes and opens that same stable Coach UID.
2. Coach creates one approved tomorrow `main` window. Member and Admin read matching dates/labels; unrelated branch/org data is unavailable.
3. Attested Member chooses an eligible 60-minute interval and requests one pending hold. Record its actual ID/server expiry. Coach Roster and Admin selected-Coach list show that exact ID, Member, branch and pending status. No payment/success/confirmation screen is used.
4. Verify same-intent receipt recovery using the authorized genuine client path if transport testing is approved; no new request ID on uncertainty. Optional competing Member test needs its own approved participant/record scope. Invalid attestation and unauthorized operations must produce no writes.
5. Owner confirms cancellation. All lists refresh to cancelled; original record/receipt persist; both owned half-hour locks become reusable and only that daily reservation is removed. Create one replacement in the same interval after explicit test approval.
6. Let the replacement reach its real server deadline and Scheduler tick. Refresh all roles to persisted expired status/reason; verify job completion, retained history, no other reservation/lock change. Reusing the interval must not erase the old record. A pending label with elapsed deadline is **not** a passing expiry result.
7. Logout/account/role switch clears old UI responses. Confirm local workout history/consent/outbox unchanged. Deactivate the directory profile or remove only unreserved future availability through trusted commands if approved as cleanup; retain all booking/receipt/job evidence.

## Rollback and remaining risks

- Before any lifecycle record exists, disable/roll back only newly introduced functions/clients/Rules as approved; retain additive indexes unless removal is separately needed.
- Once lifecycle records exist, stop new hold creation first, pause the scheduled job before worker rollback, and retain compatible readers. Never restore closed records to pending or restore old lock/accounting snapshots over newer activity. Resolve any genuine pending holds through a separately approved trusted procedure; no ad hoc client deletes.
- B3-only strict clients reject B4 terminal fields/states. A phone downgrade therefore requires a compatible-reader strategy, not blindly reinstalling the prior APK. App data/signature/version constraints remain a separate gate.
- Worker processes at most 50 due jobs per batch. Blocked/malformed jobs need authorized review; no guaranteed exact-deadline closure, automatic data repair or operations dashboard is claimed. Auth revocation can lag; public projection withdrawal is not automatic.
- Firestore is in Singapore and the existing/default Functions region is `us-central1`. Real cross-region callable/transaction latency is unmeasured; capture safe timings during the first smoke and stop on timeouts/uncertain outcomes rather than submitting a new intent. No regional rewrite is proposed. Booking lists cover a bounded current/upcoming range, not complete past consultation reporting.
- Largest immediate blockers: missing canonical Admin, missing genuine Coach and policy, all nine Functions absent, three indexes absent, Scheduler setup absent, real App Check unproven, no authorized connected phone. Also complete the two narrow source repairs before deploying these workflows.

No production source repair, deployment, live record write, real account provisioning, App Check registration, verification email, APK install, tutorial activation, Step 7C or unrelated feature work occurred during this preflight. Stop for review.
