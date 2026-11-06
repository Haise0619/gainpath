# Controlled live FYP integration — 4 November 2026

## Checkpoint

The approved fictional cohort is deployed and enabled in **`gainpath-0619` / `(default)`**, under `orgs/gainpath/cohorts/fyp-v1`. The ordinary Admin application at **http://localhost:7362/** has exercised the real Firebase dataset, reporting, Exercise Insights, both generation queues, review details and four explicit Sends. This is a controlled fictional-data release, not approval for real Member recommendation processing or clinical claims.

**Admin and authenticated API acceptance passed; native acceptance remains pending by owner request.** After owner reauthentication, the sandbox's Google DNS restriction reproduced the CLI's generic authentication error; retrying the fixed-scope tools with approved network access succeeded. Final direct inventory confirms **four recipients, four notifications and four delivery receipts**. Member delivery/actions/idempotency, assignment revocation/restoration, source validation, deployment preservation and exact-owned cleanup inventory passed. No alternate credential or additional Send/generation was used. Native screenshots and Android App Check acceptance are not claimed.

The previous [local checkpoint](gainpath-fyp-cohort-integration.md) and [accepted preflight](gainpath-fyp-cohort-preflight.md) remain historical evidence. Their “live disabled” descriptions predate this separately authorized release.

## Authority and scope

The owner authorized the exact live executor, 27 fictional Auth identities, approved source graph, additive Rules, two new callables and source-only registration guard. A separate explicit exception approved `roles/run.invoker` for `allUsers` **only** on the two new callable transport services. Firebase Auth, App Check, verified identity, organization, assignment and cohort authorization remain enforced. No existing service or project IAM expansion was authorized.

The original accepted manifest SHA-256 is `8af85d9a07470fe2230f7fc42371d5a64618eca829fee70be1d22b2de247e855`; source digest is `cbca9c7b48b70d4dae6d5cb961eb11a07529f0a1a3a64c7b6581589dd545b405`. The anchor remains **4 November, 08:34:30 MYT** (`2026-11-04T00:34:30.496Z`). No re-anchor was consumed. Immutable source inventory, hash binding and bounded runtime ownership prevent an arbitrary cohort or source substitution.

## Deployed resources and evidence

| Resource | Actual result |
| --- | --- |
| `fypDatasetSessionCommand` | New Gen2 callable, `asia-southeast1`, Node22; Auth/App Check enforced |
| `fypDatasetCommand` | New Gen2 callable, same bounded runtime and security requirements |
| `provisionMemberRegistration` | Existing deployed Singapore function, source-only assignment guard; existing runtime/environment/IAM preserved |
| Firestore Rules | Actual deployed baseline plus reviewed additive cohort block; unrelated local unreleased Rules edits excluded |
| Other services | 69 unrelated existing Functions preserved; total72 after adding two |
| Other infrastructure | Existing project IAM, indexes, Storage, Hosting, database and normal Functions entrypoint preserved |

The two new functions use 540-second timeout, 512MiB, one CPU, maximum one instance and concurrency4. The dedicated release package exposes only those two exports. **Do not deploy the normal index with a broad deletion operation:** these separately packaged services must be accounted for explicitly in future releases.

Latest successful infrastructure verification was **`2026-11-04T07:58:11.504Z`** (15:58 MYT). It rechecked exact deployed function metadata/IAM, source archives, Rules and the enabled release. Evidence: `build/fyp-live-20261104/infrastructure-verified.json`. A final read-only summary at **`2026-11-04T08:00:03.378Z`** (16:00 MYT) verified the same metadata digests and recorded actual revisions:

| Function | Actual Cloud Run revision | Function update time (UTC) |
| --- | --- | --- |
| `fypDatasetSessionCommand` | `fypdatasetsessioncommand-00003-doc` | `2026-11-04T06:28:45.550309747Z` |
| `fypDatasetCommand` | `fypdatasetcommand-00003-xex` | `2026-11-04T06:29:55.927066622Z` |
| `provisionMemberRegistration` | `provisionmemberregistration-00002-lax` | `2026-11-04T02:22:17.703511287Z` |

| Artifact | SHA-256 / identity |
| --- | --- |
| Deployed Rules | `537175790de2bca6f395effed00f1372051a812ca79b742237d0b68f29e0c51f` |
| Ruleset | `projects/gainpath-0619/rulesets/0ea6007e-8899-4433-831f-4b60c506ed51` |
| Registration archive | `002e7b8e2dbd7336b641745b94ac80c3595b7daa91b694876c45cd846dc9a326` |
| Current two-callable archive | `d535052a81a759ed352a60576910fbaac94a7851aa778d6df3c8e23ccf539b24` |
| Session function metadata digest | `77cbb16fe7b0c8cb435d35992031e2a6f0708bf1ba3ea249f2dba418d5049676` |
| Dataset function metadata digest | `c2be70877a59b5f3cfc7a884c64f9c3505aa67ff732f6742813cbaa8e3ef3bad` |
| Registration metadata digest | `34a49b759cfb284426f931d54922119ad53e65203343f525b4dd2367d5778c9e` |

The hashes above are metadata digests; the separate table records actual revision names. Prior source archives, Rules, metadata/IAM and private Admin bundle are retained under the ignored release evidence directory.

## Data actually seeded

Create-only application succeeded with disabled accounts/release, validated the exact graph, then enabled the controlled cohort after security checks.

| Initial resource | Count |
| --- | ---: |
| Fictional Firebase Auth identities | 27: 18 Members, 8 Coaches, 1 Admin |
| Source Firestore documents | 466 |
| Assignment documents | 27 |
| Source/control ownership documents | 493 |
| Auth ownership documents | 27 |
| Seed-run and runtime release documents | 2 |
| **Initial Firestore total** | **1015** |

The source graph includes 52 explicitly labeled recorded/synthetic workout observations, 12 published instructional Tutorials, three Programs and 18 learning goals. Seven of eight Coaches are active/published; inactive/ineligible candidates are retained as negative fixtures. These are not trusted physical-camera measurements or accepted workout/reward evidence.

One audited recovery subsequently added existing supported account-lifecycle session floors to the 27 fictional user records and advanced assignments to revision3. Seed-run recovery metadata pins those new digests. The original manifest/source digests remain baseline identities; current user records are **not claimed byte-identical to the initial snapshot**. Consent, observation history and publication records were not rewritten. The final Member18 denial probe advanced only its assignment from3 through disabled4 to restored5. All27 owned Auth accounts are enabled and email-verified; all54 exact fictional canonical user/member paths remain absent.

Final ownership inventory identifies **1,133 owned Firestore records and27 Auth bindings**, with zero drift/preserved exceptions. This inventory includes source, control, ownership and generated resources after the authorized workflow; it is distinct from the initial1,015 seed count. It was a dry run: **no deletion occurred**.

## Ordinary application acceptance

| Area | Actual live evidence | Remaining limit |
| --- | --- | --- |
| Admin dashboard / Members | 18 Members, 7 active Coaches; 18-row Member directory | Fictional cohort only |
| Coach management / directory | 8 management records, 7 published eligible profiles | No booking created or Coach contacted |
| Tutorial / Routine library | 12 actual published instructional Routines/Tutorials | Image-only catalog entries do not qualify |
| Programs | Three actual draft/publication relationships visible | Native enrollment/progress journey not exercised |
| Module12 Reports | Ordinary Admin displays 52 sessions, 416 full reps, 104 partial reps, 6m44s tracked time and 18/18 coverage | Metrics unchanged; fixture observations remain labeled |
| Module13 Insights | Real compatible groups, coverage, missing states, content coverage and CSV | Educational estimates; no clinical interpretation |
| Module13 queues | Both real refresh runs, review details and four Sends | No further refresh/Send budget remains |
| Member profile / history | Authenticated Member01 own profile, three owned observations | API proof; native screens pending |
| Member discovery | Authenticated published Coach, Tutorial and Program reads; current destinations | Native navigation pending |
| Availability | Existing roster/capacity validator returned eight60-minute options for fictional Coach01 on5 November | No reservation, booking, payment or attendance event |
| Notifications / recipient actions | Both intended inboxes contained two available items; four current destinations and cross-Member denials passed; Member01 Trainer read/acknowledge/dismiss and exact retries passed | API proof; native notification/navigation screens pending |
| Existing canonical control | Previously documented fictional canonical control retained own-document access and was denied FYP private access | No real Member history inspected |

Read-only live security acceptance verified missing Auth, missing App Check, wrong role, cross-Member/private/canonical access and legacy registration denials. A Firebase-signed token from the **already registered Web debug App Check provider** was verified cryptographically. This is not a Play Integrity or reCAPTCHA acceptance claim. No new Android debug credential was registered.

The ordinary Admin bundle uses the existing Firebase composition and Syncfusion UI. It is served privately on loopback7362; the existing7359 console and previous bundle were preserved. No synthetic HTTP gateway or fallback mock analytics is used. Screens identify the fictional educational dataset. Some inherited generic queue prose still says “completed locally” / “prepared locally”; the FYP Send success explicitly says delivery to the fictional Member inbox. That wording is a presentation limitation, not evidence of local-only persistence.

## Generation, review and delivery budget

Exactly one Trainer run and one Content run completed, each processing18 fictional Members. Continue-page operations retained the same run IDs; they were not new runs.

| Run | Generated | Abstained | Abstention reasons |
| --- | ---: | ---: | --- |
| Trainer `b70faff49cef7538620c36be094c2c3de0efbc4f7e9a7860323e7e9777582a98` | 6 | 12 | 7 insufficient evidence, 1 unsupported, 4 missing consent |
| Content `7dd11c86e6481716ed55fcc8f43d95c4bb45b62d5a6ba21eb305ad960fd57913` | 6 | 12 | Same fixture distribution |

The pre-Send direct inventory verified12 leads, two runs and36 generated-ownership records. Ten leads use the explicitly labeled mock semantic model **`gainpath-demo-structured-mock-v1`** and `ai_reranked` origin; two use deterministic fallback. These origins exercise the engine contract and **are not new Gemini results**. No new Gemini request was made; Batch B's existing18-attempt evidence is historical and separate.

Four explicit Admin review/confirmation sequences completed:

1. Content → `demo-m13-member-02`.
2. Content → `demo-m13-member-01`.
3. Trainer → `demo-m13-member-02`.
4. Trainer → `demo-m13-member-01`.

Both queue tabs showed pending4/processed2 after their two Sends. The Trainer review showed a current fictional Coach availability observation on5 November,10:00–11:00 MYT, explicitly without reserving a slot. Content review referenced the current published Squat foundations destination. `live-smoke-budget.json` records all four UI confirmations, subsequently verified directly in Firebase. **Do not refresh either queue or Send another lead under this completed budget.**

Authenticated Member acceptance verified both two-item inboxes, all four current destinations and cross-Member callable/direct-notification denials. Member01's Trainer recommendation was read, acknowledged and dismissed with exact command replays; final revision4 redacts its target/explanations. Three Member action receipts exist. Two explicit delivery replays created zero additional recipients or notifications; counts remain4/4/4. Member02 retains both available recommendations for a later demo. These are API results, not native UI results (`live-delivery-acceptance.json`).

## Implemented files and integration corrections

| Files | Responsibility |
| --- | --- |
| `functions/src/modules/dataset/fyp-live-manifest.ts` | Exact accepted manifest compiler, immutable authority and source/digest verification |
| `functions/src/modules/dataset/fyp-live-executor.ts` | Create-only owned live seed, disabled staging, validation, activation/quarantine, bounded recovery and cleanup inventory |
| `functions/tools/fyp-live{,-platform,-vault,-credentials}.cjs` / `.ps1` | Fixed-project operator, existing CLI integration, external encrypted credential storage and safe manual retrieval |
| `functions/tools/fyp-live-{prepare,package-check}.ps1` | Dedicated packaging and exact release checks |
| `functions/tools/fyp-live-{deploy,reader-fix,rules-check}.cjs` | Scoped deployment, preserved deployed baseline and additive Rules verification |
| `functions/tools/fyp-live-{admin,client,read-check,insights-check,control-read,runtime-audit}.cjs` | Ordinary private Admin and bounded actual Firebase acceptance |
| `functions/tools/fyp-live-{delivery-acceptance,member-security}.cjs` | Executed once-only Member delivery/actions/retries and assignment-denial acceptance |
| `functions/tsconfig.fyp-{live,release}.json` | Separate operator/release compilation; normal index and emulator guard retained |
| Three `functions/test/fyp-live-*.test.ts` files | Authority, ownership, recovery, credential and package known-answer checks |
| Existing `fyp-evidence-reader.ts` + test | Bounded through-now Insights presentation correction |
| Existing Admin Insights application/panel and queue panel + two tests | Truthful fictional educational labels |
| Existing `functions/emulator/fyp-cohort-rules.test.ts` + staged config | Exact deployed-baseline overlay tests without changing ordinary emulator defaults |

Two integration faults were reproduced and corrected before acceptance:

- Direct Cloud Functions API creation omitted standard Firebase project bootstrap variables. Only public `FIREBASE_CONFIG`/`GCLOUD_PROJECT` were added to the two new services. The cohort was quarantined during diagnosis; one exact-owned recovery revoked fictional refresh tokens, advanced assignment revisions and pinned lifecycle session floors before reactivation. No real account was changed.
- The frozen fixture end rejected an otherwise bounded “through now” Insights presentation. Presentation queries now allow at most90days through the server clock while requiring consent over the entire requested interval and exact approved source-path inventory. Generation and revalidation retain their original source-window restrictions; unknown rows and source failures fail closed.

The literal four-file source-fix allowlist preserves the original accepted data manifest. The last two-function archive differs from its predecessor only in reader JavaScript/source map:169 of171 files unchanged. Operator/vault code is excluded from that deployment package.

## Verification and preservation

Fresh checks retained in `build/fyp-live-20261104/`:

- **132 focused backend tests passed**, zero failures,12 files (`final-focused-tests.json`). Includes authority/ownership, lifecycle recovery, bounded assignment probe behavior, A1 aggregation/compatibility, consent/source boundaries, seed guards and existing registration behavior.
- **33 Admin widget tests passed**, including existing Insights/queue states; scoped analysis of the three changed Admin files passed.
- **13 exact staged Firestore Rules checks passed** using the actual deployed baseline plus additive cohort block.
- Source and test TypeScript no-emit checks passed; Node22 operator/release compilation passed.
- Ordinary Admin Web build and permitted debug/profile Android builds passed. Neither new Android artifact was successfully installed.
- Actual signed-in Admin screenshots, read-only Firebase acceptance, Insights CSV and generation audit are retained separately from fixture/mock test results.

The historical703 backend /242 Flutter /32 emulator local-checkpoint results were not rerun or relabeled as fresh live results.

Local preservation compares2,286 accepted source paths:2,278 unchanged, eight reviewed integration-source/test changes, zero missing. All nine hash-recorded previous cohort artifacts and both original academic Chapter3/4 documents remain unchanged (`preservation-final.json`). Original Module13 requirement traceability and existing Module2 measurement, Module6 provider behavior, Module12 metrics, booking/publication contracts and real-user consent policies remain preserved. The independent security review found no remaining Critical/Important findings after reproduced fixes. Fresh cloud validation, preservation checks and exact-owned inventory also passed. The fixed Member18 probe verified real callable and Rules denials while disabled, restored access with a forward revision, and passed owner-integrity validation with zero consent/history writes (`member-assignment-security.json`).

## Pending gates and unsupported outcomes

1. **Owner-deferred native UI:** both Pixel emulators lacked installation headroom; debug/profile attempts returned `INSTALL_FAILED_INSUFFICIENT_STORAGE`. No uninstall, data clearing or Xiaomi change occurred. A later off-screen window issue could not be resolved through computer capture; the owner explicitly chose to leave native verification pending. No Member-screen screenshots, Android App Check, camera or physical scoring acceptance is claimed.
2. **Earlier CLI/network blocker resolved:** the owner reauthenticated the same account. A public Google metadata request then reproduced sandbox `ENOTFOUND`, explaining the repeated generic CLI authentication error. Approved network execution completed all remaining checks; no alternate credential, IAM expansion or further deployment was needed.
3. **Real-user privacy/policy:** purpose-specific consent collection, retained-history processing, real Member activation, external AI permission, threshold meaning, minimum evidence, small-cohort suppression and retention periods still require explicit owner/privacy approval. The fixture's five compatible policies use three scored sessions/three days/30 assessed attempts, coverage≥0.8, attention below65 and maximum evidence age7days; minimum disclosure cohort2 is **synthetic-only engineering configuration**, not a universal approved policy. No default real-user grants or clinical high-risk classification was activated.
4. **Financial/reward/booking scenarios:** no payment settlement, refund, points, reward issuance, real booking, attendance, Member enrollment/progress mutation or external notification channel was exercised. No email/SMS/FCM delivery claim follows from an in-app Send.
5. **Freshness:** booking fixtures are dated5 November and leads expire under their24-hour policy. Expiry must remain truthful. No automatic date extension, destructive reseed, consent reset or history rewrite is authorized.

## Reproduction and recovery

Run from `C:\Users\Ngzhe\StudioProjects\gainpath`. Credentials are CurrentUser-DPAPI encrypted with a user-only ACL at `C:\Users\Ngzhe\AppData\Local\GainPath\FypDemo\fyp-v1.credential-vault.dpapi`. They are not in this report, Git, logs or command arguments.

```powershell
# Retrieve a SecureString credential object; never print its password.
& functions/tools/fyp-live-credentials.ps1 -Uid demo-m13-admin
# Explicit manual password copy, only when needed for approved sign-in.
& functions/tools/fyp-live-credentials.ps1 -Uid demo-m13-admin -CopyPassword
```

Sign in at http://localhost:7362/ as `demo-m13-admin@gainpath-demo.invalid`. Member01/02 use the corresponding `demo-m13-member-01@gainpath-demo.invalid` and `demo-m13-member-02@gainpath-demo.invalid` identities; select their UID in the same secure helper. Existing accounts are fictional and email-verified by the controlled executor; normal registration must not canonically enroll them.

If the private server is stopped, start it with:

```powershell
& build/fyp-live-20261104/toolchain/v22.23.4/node.exe functions/tools/fyp-live-admin.cjs serve
```

Use dashboard, Members, Coach management, Routine Templates, Programs, Reports→Workout Reporting and Recommendations→Exercise Insights/Trainer/Content. Select Malaysia dates including4 November for the current observations. Review existing queue/history entries; **do not repeat generation or Send**. Member02's two available inbox recommendations are the retained demo pair; Member01's Trainer item was intentionally dismissed during API acceptance. Native rendering remains unverified.

For future read-only verification, use the **same** approved CLI account (`firebase login --reauth` only when required) and permit network access to the fixed Firebase endpoints:

```powershell
& build/fyp-live-20261104/toolchain/v22.23.4/node.exe functions/tools/fyp-live-runtime-audit.cjs
& build/fyp-live-20261104/toolchain/v22.23.4/node.exe functions/tools/fyp-live.cjs validate
& build/fyp-live-20261104/toolchain/v22.23.4/node.exe functions/tools/fyp-live.cjs cleanup-dry-run
```

**Do not rerun** `fyp-live-delivery-acceptance.cjs` or `fyp-live-member-security.cjs`: their one-time acceptance completed. Delivery acceptance exercised Member01 Trainer read/acknowledge/dismiss with exact retries, current destinations, cross-Member denials and two delivery replays, leaving Member02 available. Its durable intent/receipts remain preserved. The Member18 probe expected revision3, verified callable/direct-read denial at disabled4 and restored5 without changing consent/history/Auth. Never overwrite these audit records or concurrent drift to repeat a demonstration.

`cleanup-dry-run` inventories exact owned source/control/generated/Auth bindings and preserved drift; **it does not delete**. No deletion is authorized by this report. For necessary cohort shutdown, the fixed operator quarantines cohort/release before disabling exact owned assignments and Auth:

```powershell
& build/fyp-live-20261104/toolchain/v22.23.4/node.exe functions/tools/fyp-live.cjs disable
```

Shutdown still requires valid existing cloud authentication. Do not reactivate from an expired infrastructure proof. Source rollback archives are retained; a rollback must preserve supported assignment denial and exact ownership boundaries, not expose seeded identities through canonical registration.

A future fixture date refresh requires a separately reviewed exact-owned delta/new manifest and acceptance budget. Preserve Auth identity, consent decisions, historical observations, delivery receipts and review history. The existing create-only apply command rejects collisions; it is not a reset tool.

This checkpoint delivers an actual deployed, isolated fictional dataset, ordinary Admin workflow and verified Member API delivery/security behavior. Native Member UI acceptance remains open by owner request; real-user recommendation production readiness is not claimed.
