> **SUPERSEDED — DO NOT EXECUTE.** The owner replaced this named-database/special-app proposal with the unified `(default)` architecture on 3 November 2026. Its deployment, isolated bucket and reserved-UID patch are not authorized. See `module13-shared-data-architecture.md` for the current audit and replacement preflight. Historical local evidence below remains a record of the former architecture.

# Module 13 Firebase demo — local implementation and live preflight

3 November 2026, Malaysia. **Local source and emulator acceptance complete. Real Firebase demo deployment/seeding has NOT occurred.** The remaining mandatory step is the owner's one consolidated approval of [the exact live scope](module13-firebase-demo-preflight.md). The target is the existing `gainpath-0619` project; a separate Firebase project is not required by this design.

## Implemented source and architecture

The new composition reuses A1–final validation, evidence derivation, Trainer/Content eligibility, deterministic baseline, strict semantic ranking, persistent queues, decisions, purpose consent, current destinations and delivery services. It does not register the previous synthetic HTTP gateway. Normal `functions/src/index.ts` and ordinary Firebase app entrypoints remain unchanged.

| Files / area | Implemented responsibility |
|---|---|
| `functions/src/modules/recommendation/demo-dataset.ts` | Reproducible fictional 8-Coach/18-Member/12-tutorial dataset, canonical exercise IDs, complete linked schemas, original PDF assets, independent purpose scenarios and ownership manifests. |
| `demo-seed.ts`; `functions/tools/seed-module13-demo.cjs` | Guarded actual emulator Auth/Firestore/Storage seeding, preflight collisions, create-only records, bounded chunks, real asset generation/hash binding, existing v2 consent commands, integrity validation, idempotent rerun and exact cleanup dry-run. Offline live-plan mode performs no SDK writes. Live apply deliberately refuses. |
| `demo-access-policy.ts`, `demo-runtime-capability.ts` | Current server manifest, approved UID roles, named-database SDK binding, immutable source digests, atomic runtime ownership and bounded writes. A serialized capability/client flag cannot authorize processing. |
| `demo-firestore-adapters.ts` | Scoped metadata-before-payload reads, source/current-consent revalidation, existing booking/candidate contracts, published instructions, read-only owned workout history and bounded queue/inbox adapters. |
| `demo-callables.ts`, `functions/src/module13-demo-index.ts` | Three grouped Firebase v2 callable compositions with App Check enforcement, current verified Auth/membership, safe errors and strict payload/response limits. Separate entrypoint only. |
| `evidence-queue-source.ts`, `recommendation-queue-security.ts`, `recommendation-delivery.ts` | Narrow support for the opaque controlled-demo capability alongside the existing fail-closed local fixture gates. No normal real-user processing path is enabled. |
| `functions/src/modules/identity/member-provisioning.ts` | Exact 27-UID reserved namespace guard, before ordinary membership writes. Required to prevent normal Mobile sign-in from enrolling demo accounts into `(default)`. Ordinary defaults/behavior are regression tested. Live source-only patch is prepared, not deployed. |
| `firebase/module13-demo.*`; dedicated TypeScript/package/emulator config | Named-database client Rules, two isolated indexes, private credential bucket Rules, separate codebase/deployment selectors and cached local emulator orchestration. Default Rules/indexes are untouched. |
| `packages/gainpath_data/lib/src/module13_demo_transport.dart` | Shared typed session-scoped protocol, current UID/email/App Check gate, operation allowlists, account-drift rejection and safe bounded responses. |
| Both apps' `firebase_demo_bootstrap.dart`, `firebase_demo_recommendation.dart`, `firebase_demo_emulator_transport.dart` | Actual named Firebase SDK binding and typed repositories. Live mode uses Firebase Functions SDK; only the exact emulator project can use the loopback official callable protocol. Live mode requires an explicit build and existing approved App Check provider. |
| Both apps' `main_module13_demo.dart`, `app/module13_demo_app.dart` | Separate demo composition reusing existing authentication and recommendation screens. Ordinary default-database payment/reporting/booking services do not initialize. No hardcoded Coach/Member lists in widgets. |
| Existing Admin login exports, Member privacy callback and recommendation navigator | Small injection seams only. Demo booking navigation is guarded; unsupported posture-sharing does not simulate a successful local save. Ordinary defaults stay the same. |
| New demo unit/connected tests and render helpers | Actual Auth/Functions/Firestore/Storage emulator workflow, negative authorization, UI review/delivery/destinations/history/consent and captured views. |

The verification manifest lists every changed/new file with its hash. New generated JS output is ignored by Git. Existing uncommitted work is preserved; no commit, stash, reset, dependency installation, APK action or public Hosting operation occurred.

## Dataset and known answers

One clean emulator lifetime contains **27 fictional Auth accounts, 932 dataset documents plus 27 Auth ownership records and one seed-run ledger = 960 initial Firestore documents**, and eight original PDF objects totaling 5,391 bytes. Auth creation has no plaintext password in the fixture/source. Emulator UI acceptance uses Auth Emulator custom sign-in tokens; normal live password login is still pending securely generated demo credentials after approval.

There are 52 unique valid standalone measured-workout wire records and one identical nested backup revision, with 53 matching synthetic capture metadata rows. These are fictional compatibility fixtures, not verified physical camera captures. Six intentionally bad/unsupported sources are isolated outside the normal backup queries. All 12 published instructional projections resolve through current exercise/tutorial contracts, have matching source blueprints and contain authored instructions; no image-only or invented media URL is promoted to a tutorial. All blueprints also pass the existing publisher in known-answer tests. No Member Program is needed for these standalone sessions, and no Program is created.

Four Squat Coaches (01, 02, 03, 07) pass actual existing verification, expertise, branch, roster, capacity and booking-slot validation. Coach 01 has eight supported one-hour options around a real fixture break; the others have eleven. Inactive Coach 08 is rejected. Availability is an observation, not a reservation or permission to book/pay. Optional fee/photo information remains unknown where absent.

The seeded generation processes all 18 scenarios for each kind:

| Result | Trainer | Content |
|---|---:|---:|
| Derived leads | 6 | 6 |
| Abstentions | 12 | 12 |
| Ranked eligible candidates across qualifying needs | 18 | 20 |
| Deterministic fallback for the no-external-inference case | 1 | 1 |

Member 01's duplicate revision contributes only once: three scored sessions, Estimated Form Score 60, coverage 0.8. Strong scores, insufficient sessions, poor coverage, null scores, incompatible curl modes, missing/revoked purposes, out-of-scope history, stale evidence and unscored exercises do not force a recommendation. Explicit per-scenario outcomes are in the dataset and connected proof.

Ranking uses the existing 40% experimental baseline / 60% validated semantic composition with provider `gainpath-demo-structured-mock-v1`. Several eligible candidates pass the same deterministic eligibility boundary. **This is structured mock inference, not a new Gemini call or evidence of improved recommendation accuracy.** The actual historical Batch B results, all nine evidence artifacts and its 18-attempt ledger remain byte-identical. Independent human labels/held-out model evaluation remain pending.

## Actual connected UI behavior

The actual Admin widgets load typed Insights and persisted leads, fetch fresh details, confirm Send and explicitly deliver two prepared recommendations for Member 02. A delivery-success message requires a strict delivered receipt, not a prepared state or assumed success. The actual Member widgets restore the current canonical account from Auth/Firestore, load the owned Notification Center, open the current published tutorial and Coach profile, independently read/acknowledge/dismiss, open read-only Activity Timeline from owned backups and load revision-bound four-purpose settings through the current server notice.

The connected test inspects the stored Member 02 records: both delivered and read; Trainer acknowledged, Content dismissed. Separate backend cases verify Member 01's Send/delivery retry receipts, cross-Member refusal, Admin Dismiss, purpose revocation and manifest withdrawal. Bookings, consultations, payments, Programs, rewards and accepted workouts stay unchanged. A fresh source seed contains zero prewritten leads/recipients/notifications.

The normal signed-in applications do not silently show these fixtures. They retain their prior disabled recommendation transports. The demo has explicit separate entrypoints, named database and “Demo Data” / mock-ranking notices. Existing tab/card/chart/filter bodies, Notification Center, Coach profile, tutorial and privacy screens are reused. Some inherited v1 labels say “synthetic local”; these describe the current local checkpoint and must not be presented as proof of real-project connection. Existing ordinary privacy posture sharing is unsupported in the demo composition and cannot be faked with an in-memory successful toggle.

Thirteen emulator-backed screenshots are under `build/module13-firebase-demo/seeded-*.png`. Admin uses a documented Arial substitute for test rendering; Member captures load the bundled Barlow/BarlowCondensed fonts. Widths include 1400/600 Admin and 393/375/landscape Member. An additional consent-only run verified the heading-font correction; the final complete workflow also uses the corrected loader. The separate capture check is not counted as another full-workflow result. Earlier original/restored UI comparison artifacts remain byte-identical.

These are **Flutter widget renders over real emulator records and official callable protocol**, not signed-in live Firebase browser/device screenshots. Live attestation and UI acceptance have not happened.

## Verification

| Fresh check | Result |
|---|---|
| Focused A1–final, Module 12/booking/content/reporting/backend regressions and new demo tests | 774 passed across 56 files |
| Existing Admin recommendation/Insights/filter/CSV/UI regressions plus demo repository/receipt tests | 87 passed |
| Existing Member consent/notification/navigation/privacy/booking composition regressions plus demo history tests | 97 passed |
| Focused shared domain / demo transport contracts | 11 / 5 passed |
| Full seeded Auth + named Firestore + Storage + Functions acceptance, with both actual Flutter clients | 8 passed; both nested client processes passed |
| A2 / C / D / E / final emulator regressions | 11 / 21 / 19 / 4 / 11 passed; four optional old client cases skipped; current clients verified in the new suite |
| Exact existing registration Function package | 7 passed; only three package files change, 25 preserved |
| Additional consent-only authenticated font-corrected capture | Passed from a fresh full seed, with zero recommendation outcomes seeded |
| TypeScript source, test and dedicated demo no-emit checks | Passed |
| Scoped Admin / Member / shared transport analysis; architecture boundaries | Passed |
| Installed Firebase CLI schema for the isolated live configuration | Passed |

The full connected acceptance made 89 callable invocations, all local. Missing Auth/App Check, wrong role/org, non-demo identity, direct cross-Member reads/writes, ordinary directory isolation, invalid source/consent states, current eligibility, duplicate revisions, once-only delivery and safe revocation are covered. Actual Auth Emulator verification-code exchange is tested separately from fixture creation with `emailVerified:true`; no actual email is sent.

App Check in Functions Emulator decodes a test token. **It does not establish real cryptographic App Check acceptance.** The host runs Node 24 although the deployment target is Node 22; the installed emulator reports that mismatch. No runtime upgrade was installed. Live Node 22 smoke/attestation checks remain necessary.

One prior final regression mixed today's wall clock with its fixed 2 November source window. Its test-only query/handler now consistently uses the fixture clock; it passes without changing production validation. Earlier diagnostic failures are excluded from passing totals. Review was completed by the coordinator after the dispatched agents became unavailable; no independent reviewer sign-off is claimed.

Primary evidence: [verification manifest](../../build/module13-firebase-demo/verification.json), [connected stored-record proof](../../build/module13-firebase-demo/connected-proof.json), [full successful frozen-source run](../../build/module13-firebase-demo/release-checkpoint-output.log), [cleanup dry-run](../../build/module13-firebase-demo/cleanup-dry-run.json). The final inventory contains 1,112 owned paths after the last consent revocation, 27 Auth identities and eight objects; nothing was deleted. The manifest records commands, raw outputs, file hashes and preservation checks.

## API contract and status

All three endpoints accept `{schemaVersion:1, operation, data}`. The server chooses the database, organization, actor and eligibility; client flags cannot select them. Requests are bounded to 16 KiB and responses to 256 KiB. Existing leaf schemas remain versioned; consent commands use v2, queue/member/delivery contracts retain v1. Member identity comes from verified Auth, not a submitted Member ID.

- Admin: `session.access`, `admin.insights`, `admin.configuration.get/choices/save`, `admin.queue.refresh/list/detail/decide/status`.
- Member: `session.access`, `member.consent.get/set/notice`, `member.recommendation.command`, `member.inbox`, `member.coach`, `member.routine`, `member.workoutHistory`.
- Delivery: `delivery.process`, Admin-only, current prepared recipient validation and durable idempotent receipt.

`FirebaseDemoAdminRepositories` and `FirebaseDemoMemberRepositories` are the client contracts. `createModule13DemoBackend`, owned adapters and existing B/C/D services are the server contracts. Live registration exists only in the separate prepared entrypoint/configuration, and has not been deployed. The seed CLI accepts emulator operations or offline live dry-run; it cannot perform a live apply before the required approval.

## Original requirements and unresolved decisions

All original UC13.1–UC13.15 and FR13.1–FR13.4 mappings remain in [the original traceability table](module13-final-completion.md). This checkpoint strengthens the data/source/authentication integration for Insights/category/configuration/CSV/gaps (UC13.1/4/5/6/7), Trainer/Content queue filters and decisions (UC13.2/3/8–13), and manual evidence-driven refresh (UC13.14/15). It does not change the original documents or claim clinically validated “High-Risk” semantics. FR13.1/2 remain educational/provisional; FR13.3/4 are demonstrated with fictional data and mock ranking.

Owner review is still required for the **exact live demo** project/resources, the necessary shared registration guard, four-purpose demo notices/history, five synthetic threshold groups, two-Member fictional disclosure rule, 24-hour suggestion validity, dated roster/evidence and manual shutdown/retention approach. The preflight specifies every value and scope. Real-user purpose consent, trustworthy physical capture, retained-history eligibility, clinical interpretation, curation/verification governance, disclosure under repeated filters/CSV, retention/deletion and independent recommendation quality remain unapproved. No Staff parity, automatic LeadEvaluator, Coach notification, external push/email, booking/payment, Program mutation, points or production ranking rollout is implemented here.

Auth, Firestore and Storage are not one cross-service transaction. Uncertain partially created resources fail closed and need exact ownership review; they are never automatically adopted or overwritten. Rollback is an owned dry-run procedure, not an automatic broad delete.

## Answers for the real-Firebase completion request

| Question | Current truthful answer |
|---|---|
| Exact real project used? | `gainpath-0619` was inspected read-only; integration is proposed there. Runtime tests used `demo-gainpath-module13-demo`. |
| Demo accounts created? | Per clean emulator run: 8 Coaches, 18 Members, 1 Admin. **Real project: zero.** |
| Required linked records complete? | Emulator integrity validates the described 960-record initial scope and eight assets. Real creation remains pending approval. |
| Several Coaches for one exercise? | Four eligible Squat Coaches with actual validated available options in the emulator. |
| Valid workouts/tutorials? | 52 unique fictional sessions plus one duplicate revision; 12 instructional publications/source blueprints. |
| Workout History derives a need? | Yes from owned consent-scoped emulator records; real project not yet tested. |
| Admin generates and sends? | Yes through actual Admin widgets + protected emulator callables; real project pending. |
| Member receives/opens? | Yes, both current destinations and owned read/acknowledge/dismiss; real project pending. |
| Original UI preserved? | Existing bodies/components retained, required demo composition/indicators/injection guards added; no normal application redesign. |
| Real Member records accessed/modified? | No private Member documents or histories read, and no live app data written. Only metadata, aggregate counts and fixed proposed-identity collision checks. |
| Production-wide capabilities? | Remain disabled; no existing consent/history/policy migration or deployment occurred. |
| Reproducible without emulator? | **Not yet.** Requires the consolidated scope approval, bounded live resource/deployment/seed execution, actual Auth/App Check acceptance and signed-in UI evidence. |

Reproduce the full current local flow from `functions` with `node emulator/run-module13-demo.cjs --with-clients`, using installed cached tools. Offline live plan: `node tools/seed-module13-demo.cjs --live-plan --dry-run --clock <manifest clockMillis> --output <new file under build/module13-firebase-demo>`. The full proposed fictional payloads are [available for review](../../build/module13-firebase-demo/live-seed-records.json); they contain no passwords.

**Ready for the consolidated live-scope approval checkpoint. Not deployed, not a completed real-Firebase demonstration, and not production-ready or clinically validated.**
