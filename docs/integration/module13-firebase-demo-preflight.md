> **SUPERSEDED — DO NOT EXECUTE.** The owner replaced this named-database/special-app proposal with the unified `(default)` architecture on 3 November 2026. Its deployment, isolated bucket and reserved-UID patch are not authorized. See `module13-shared-data-architecture.md` for the current audit and replacement preflight. Historical local evidence below remains a record of the former architecture.

# Module 13 controlled Firebase demo — consolidated approval scope

3 November 2026, Malaysia. **PROPOSED; no live mutation or deployment has occurred.** This is the single project/scope checkpoint required by the owner's updated authorization, attachment `a2cde923-3591-40d7-abc7-756f89ada987/Pasted text.txt`:

> Before the first real-project mutation, confirm the exact Firebase project ID, the complete proposed write/deployment manifest, existing-data isolation and rollback approach with me in one consolidated approval checkpoint.

Approval of this document authorizes only the fictional demo below. It does not approve real Member processing, production consent/policy rollout, another Gemini experiment, billing changes or a general deployment.

## Verified existing project

| Item | Read-only finding |
|---|---|
| Project | `gainpath-0619`, display name GainPath, number `879719977530`, ACTIVE |
| Configuration | `.firebaserc`, Firebase initialization and both clients agree on this project; CLI login alone was not used as project evidence |
| Firestore | Only `(default)` exists, `asia-southeast1`; proposed `module13-demo` is absent |
| Existing membership | Aggregate counts only: 4 Member, 3 Coach, 1 Admin records; treat these as protected existing accounts |
| Existing Functions | 70; the three proposed demo names are absent |
| Proposed Auth namespace | All 27 exact UIDs and fictional emails checked; zero collisions |
| Billing / Auth | Billing already enabled; email/password already enabled; neither is to be changed |
| App Check | Firestore enforcement is enabled; real acceptance by the new endpoints remains pending live verification |
| Registered clients | Web `1:879719977530:web:d694147dcc998025959b03`; Android `1:879719977530:android:1f5dee79bccc1ec1959b03` |
| Storage | Proposed demo bucket absent; existing default/media and Functions source buckets stay separate |

No Member documents or private workout histories were read in this preflight. Membership counts used Firestore aggregation. Auth lookup was restricted to the 27 proposed fictional identifiers. Raw credentials and environment values were not printed or copied into the report.

Read-only evidence: `build/module13-firebase-demo/project-metadata.json`, `isolation-preflight.json`, `live-guard-preflight.json`.

## Exact resource and deployment allowlist

1. Create **one named native Firestore database**, `projects/gainpath-0619/databases/module13-demo`, in `asia-southeast1`. Inside it use the existing canonical organization `gainpath`, branch `main`, plus an isolated negative-scope branch `demo-other`. Do not create these records in `(default)`.
2. Create/register **one private Storage bucket**, `gainpath-0619-module13-demo-credentials`, Singapore/Standard, for eight original fictional PDF credential fixtures, **5,391 bytes total**. No public object access, download tokens, invented photos or external tutorial URLs. Direct client access is denied. Existing buckets are unchanged.
3. Create **27 Auth identities**: `demo-m13-admin`; `demo-m13-coach-01` through `08`; `demo-m13-member-01` through `18`. Emails are the UID followed by `@gainpath-demo.invalid`. Create no other Auth users and overwrite none. Seven Coaches are active; Coach 08 is intentionally inactive. All eight have fictional approval metadata and original PDF fixtures, which are not real professional qualifications.
4. Apply the **960 initial Firestore document templates** in [the offline live seed manifest](../../build/module13-firebase-demo/live-seed-plan.json). [Full proposed fictional payloads](../../build/module13-firebase-demo/live-seed-records.json) are available for review without passwords; real Storage generations/size acknowledgments are bound only after confirmed approved uploads. Approval includes one execution-time anchor for these fictional relative timestamps and the following Malaysia booking day, so the demonstration is not seeded with an already expired roster. Only date-derived daily-availability/booking-day paths and their ownership hashes vary with that anchor; Auth/exercise/Coach/Member/tutorial/seed IDs, counts, policy values and scenarios stay fixed. Generate and collision-check the final exact dated manifest before the first write, then persist its clock for idempotent reruns. This includes ownership, consent command receipts and the seed run record. No leads, prepared recipients or notifications are seeded as outcomes.
5. Deploy only these new Node 22 / Singapore callable Functions, codebase `module13-demo`: `module13DemoAdminCommand`, `module13DemoMemberCommand`, `module13DemoDeliveryCommand`. Each enforces App Check and current verified Auth, membership, role, seed identity and owned-record checks. Timeout 540 seconds, maximum one instance per Function, concurrency four. Normal Firebase callable HTTPS transport may be publicly reachable; business access requires the verified Auth/App Check and server-owned demo boundary. Scope any required invoker binding to these new services only; do not change existing service/project IAM or create another service account.
6. Apply a **source-only patch to existing `asia-southeast1/provisionMemberRegistration`**, before creating any demo Auth account. Ordinary Mobile sign-in otherwise tries to provision a missing default-database Member. The patch rejects only the exact reserved 27 UIDs before a transaction; ordinary organization/branch defaults stay unchanged. Use only `updateMask=buildConfig.source`, preserving the existing runtime, environment and IAM. The captured ZIP changes three files (`member-provisioning.ts`, its JS and map); **25 other package files are identical**. Seven exact-package tests pass. The other **69 existing Functions remain untouched**.
7. Release only the new named database's [Rules](../../firebase/module13-demo.firestore.rules) and [two indexes](../../firebase/module13-demo.firestore.indexes.json), and the new bucket's [deny-all client Rules](../../firebase/module13-demo.storage.rules). Do not modify default database Rules/indexes or any existing bucket's Rules.
8. Build/run the two explicit demo Web entrypoints privately on this computer, separately from the current private Admin bundle. No Hosting publication, APK build/install or ordinary app entrypoint activation. Reuse an existing approved registered App Check provider. Do not register another debug token, disable enforcement or change authorized domains to bypass a failure.

Selective configuration: [module13-demo.live.json](../../firebase/module13-demo.live.json). The installed CLI schema validates it. Use explicit `--project gainpath-0619 --config firebase/module13-demo.live.json` and only the three `functions:module13-demo:<exactName>` selectors. Rules/index release commands must use this single-resource configuration, never the ordinary root configuration. The existing registration Function uses its separately captured source-only patch, not this codebase. No blanket deploy or deletion prompt is authorized.

## Initial Firestore inventory

The linked JSON is authoritative for every individual path and collection, including nested credentials, approval history, availability dates and each Member's backups/capture metadata. Stable IDs are collision checked again immediately before writes.

| Record group | Count |
|---|---:|
| Organization / branches / booking policy | 1 / 2 / 1 |
| Canonical users / memberships / Member fitness profiles | 27 / 27 / 18 |
| Published/inactive Coach profiles | 8 |
| Credential states / credentials / approval-history records | 8 / 8 / 8 |
| Weekly rosters / daily availability / empty Member booking-day snapshots | 8 / 8 / 18 |
| Curated Coach expertise / active exercise catalog | 8 / 5 |
| Source routine blueprints / published instructional tutorials / suitability mappings | 12 / 12 / 12 |
| Reviewed synthetic evidence policies / configuration | 5 / 1 |
| Canonical workout sessions / identical revision / capture metadata | 52 / 1 / 53 |
| Isolated invalid/unsupported evidence fixtures | 6 |
| Current purpose-consent documents / command audits / command receipts | 17 / 65 / 65 |
| Source manifest / access manifest / Storage ownership | 1 / 1 / 8 |
| Source-record ownership sidecars / Auth ownership / seed run | 466 / 27 / 1 |
| **Total initial Firestore documents** | **960** |

One Member has no consent document and remains entirely default-off. Other scenarios include insights-only, no external inference, revoked generation, grant-time history exclusion, insufficient samples, low coverage, null scores, incompatible curl mode, stale evidence and unscored exercise. The 53 records represent **52 unique fictional sessions**, not 53 physical captures.

## Authorized demo runtime effects

After successful seed validation, enable only `module13Demo/current` in the named database. Exercise the protected generation, review, configuration, purpose grant/revoke and delivery APIs for the manifest identities. A complete initial Refresh should derive six Trainer and six Content leads, with explicit abstentions for the other scenarios. Runtime outcomes must come from the existing engine and transactional services, never from a prewritten success fixture.

Allow one initial bounded acceptance pass, at most **250 protected callable requests**, with no automatic unbounded retries. Expected review cases: two recommendations for Member 02 through actual Admin/Member screens; separate once-only/retry and Dismiss/revoke checks using designated fictional accounts. Every runtime write obtains an atomic `module13DemoOwnership` sidecar. Backend per-query/page/transaction limits remain in force; cleanup inventory refuses more than 2,000 ownership entries. Stop if scope, ownership, costs, configuration or required permissions differ from this manifest.

Derived runtime IDs are created by the engine, not preseeded. The complete permitted runtime collection families, all under `orgs/gainpath` in **the named database only**, are: `recommendationRuns` (including `pages`), `recommendationRefreshLocks`, `recommendationRefreshAudits`, `recommendationGenerationState`, `recommendationEvidenceBindings`, `recommendationLeads`, `recommendationDecisionAudits`, `recommendationCommandReceipts`, `recommendationRecipients`, `recommendationDeliveryReceipts`, `recommendationMemberCommandReceipts`, `notifications`, plus versioned `recommendationConfiguration`/audit/receipt and `recommendationConsent`/audit/receipt records. Ownership sidecars accompany them. No runtime source-history, credential, roster, booking, Program, payment or reward write is allowed.

Opening a recommendation does not book, pay, start a workout, change a Program, award points, push an external notification or contact anyone. Inbox delivery is only to fictional accounts inside the named database. Demo booking navigation is guarded so the ordinary default-database booking composition cannot initialize.

## Explicit demo-only policy decisions included in this approval

- Synthetic educational policy: three scored sessions on three days, at least 30 assessed attempts, coverage at least 0.8, Estimated Form Score below 65, maximum evidence age seven days. Five exact exercise/version/view/mode groups are configured; incompatible groups cannot inherit another group's policy. These values are engineering fixtures, not clinical or real-user thresholds.
- Generation uses the seed's fixed 30-day evidence window. Retained-history notices allow only the fictional 40-day scope; the separate new-only scenario starts at its explicit grant. Prepared suggestions have a 24-hour validity window and current targets are revalidated; validity is not a record-deletion or retention period.
- Aggregate disclosure uses a **two-Member minimum only inside this fictional demo**. Counts, averages, exports and derived gaps retain the existing suppression contract. This does not approve two as a real-world disclosure threshold.
- Notices `demo-m13-notice-retained` and `demo-m13-notice-new-only`, both notice/content version `demo-v1`, permit only manifest-owned fictional records. Four purposes remain independent; existing camera/backup/chatbot consent is not used as recommendation permission. All grants/revocations are explicit versioned commands, not inferred from login.
- Inference is **structured mock only**, visibly labeled; no new Gemini request or spending authorization. Historical Batch B genuine evidence and its 18-attempt ledger remain unchanged.
- Fictional `realCamera` wire syntax and `synthetic_emulator_attested` metadata are compatibility fixtures. They provide **no production physical-capture trust** and are fenced to the named demo database/ownership manifest.
- No real-user retention period, TTL, historical-backup migration or automatic deletion is activated. Demo shutdown/cleanup is manual and ownership checked. Longer-term retention and any later refresh of dated roster/evidence fixtures need an explicit owner decision; old evidence must not silently become current.

## Isolation and existing-data impact

Normal clients and all ordinary repositories continue to select `(default)`. Demo clients explicitly select `module13-demo` and use the new protected SDK callables. Named-database client Rules allow only a listed identity's own canonical bootstrap records; directory, tutorial, history, queue, consent and notification data use owned server adapters. Direct list/write access is denied. Emulator tests use the **actual existing default Rules** to prove a normal Member can access its normal directory/catalog while demo identities without default memberships cannot; normal identities cannot enter the named database or demo callables.

Every server transaction revalidates the enabled manifest. Source facts are digest pinned, current identities and purposes are rechecked, and payload reads follow scoped metadata authorization. No collection-group/default-database fallback exists. The registration guard closes the automatic default-membership enrollment path; a branch name alone is not being used for isolation.

No real Member history is to be read or modified. Live verification may inspect only fixed demo paths plus configuration/resource metadata and aggregate existing-data invariants. Do not enumerate real account profiles to prove preservation.

## Cost, credential handling and release gates

Billing is already enabled, but a named database does not inherit the default database's free allowance. This plan incurs ordinary Firestore reads/writes/storage, Function build/runtime/artifact costs and negligible PDF storage; no SMS, paid booking, email campaign or new Gemini cost is intended. Counts and request limits bound application work, **not a guaranteed cloud-billing cap**. Inspect current project quota/pricing before mutation; stop rather than change billing or permissions. [Firebase database/pricing guidance](https://firebase.google.com/docs/firestore/manage-databases), [Firestore pricing](https://firebase.google.com/docs/firestore/pricing), [Functions codebases](https://firebase.google.com/docs/functions/organize-functions).

Generate 27 unique random passwords only during approved execution, keep them out of arguments/logs/reports/Git, and store a per-user DPAPI-encrypted credential vault outside the repository at `C:/Users/Ngzhe/.gainpath-demo/module13-demo-v1.credentials.clixml`. Do not store a plaintext password file in `build/`. Reuse only the existing approved administrative credential integration. No alternate credentials or IAM/billing changes are authorized.

Before live apply: recheck target identity, source hashes, zero collisions, resource absence, guard baseline update time and valid booking dates. The JSON uses a fixed reproducible **review-example clock**; the single approved execution-time anchor must preserve the exact template rules above. Do not reinterpret or refresh real histories, silently re-anchor an existing seed, or change any other scope without a decision. Real ID-token/password login, deployed enforcement, actual App Check attestation and signed-in screenshots must be verified after deployment. Emulator token decoding is not proof of live attestation. If these gates fail, keep demo access disabled and report the exact blocker.

## Stop, rollback and cleanup

1. Immediately disable the named access manifest; all three demo handlers and direct bootstrap Rules fail closed. Disable only the exact manifest-owned demo Auth UIDs after checking creation times and ownership.
2. Keep `provisionMemberRegistration`'s namespace guard until all demo Auth identities are disabled/removed, so rollback cannot reopen default enrollment. If necessary, restore the captured `provisionMemberRegistration-before.zip` with only the source update mask, checking the original runtime/environment/IAM hashes and preserving unrelated Functions.
3. Remove only the three newly created demo Functions after recording their current metadata. Preserve the current private Admin bundle; stop only the separate demo Web processes.
4. Run the seed cleanup dry-run first. Review exact source **and runtime** paths, Auth creation times and Storage generations against durable ownership. Rollback of this initial integration's confirmed newly created demo records/assets/accounts is included in this consolidated scope; it does not require permission for every record. Later routine cleanup must follow an owner request and the same dry-run/ownership checks. Uncertain ownership or resources outside this manifest require a scope decision. No broad Auth/collection reset, automatic named-database deletion or recursive removal of existing buckets is authorized.
5. Preserve the durable seed ledger and verification/rollback artifacts. Confirm `(default)`, existing buckets, the other 69 Functions, default Rules/indexes, billing and existing IAM remain unchanged.

Prepared rollback evidence: `provisionMemberRegistration-before.zip`, `-ready.zip`, `guard-package-files.json`, `exact-guard-results.json` and the source/configuration hashes in `live-guard-preflight.json`. The emulator cleanup inventory is `cleanup-dry-run.json`. **Live apply is still disabled pending this approval.**
