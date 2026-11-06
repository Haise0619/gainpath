# FYP cohort live preflight — owner review, execution disabled

4 November 2026, Malaysia. Existing project `gainpath-0619`, Firestore `(default)`, logical organization `gainpath`. This replaces the superseded flat-path and named-database proposals. **No live mutation is authorized or performed by this document.**

This proposal is valid only with successful ordinary-app local acceptance in `build/fyp-cohort-integration/verification.json` and the matching [exact machine manifest](gainpath-fyp-cohort-preflight.json). The manifest includes the fixed accepted anchor, source digest, all 27 identities, every initial path, ownership registry paths, release contract and current Rules SHA256. Full typed source records are in the locally generated review artifact referenced by its SHA256. Reanchoring or changing any source requires regeneration, validation and review; do not silently substitute execution-time data.

Accepted source anchor: **4 November 2026, 08:34:30.496 MYT** (`2026-11-04T00:34:30.496Z`). Source manifest digest: `cbca9c7b48b70d4dae6d5cb961eb11a07529f0a1a3a64c7b6581589dd545b405`. The machine manifest additionally pins backend and ordinary-client source file hashes. Live collision/readiness checks have **not** been refreshed under this local-only task.

## One proposed controlled release

| Proposed action | Exact scope | Safety condition |
|---|---|---|
| New callables | `fypDatasetSessionCommand`, `fypDatasetCommand`, `asia-southeast1`, Node22, enforced App Check, maxInstances1, concurrency4, timeout540s | Separate reviewed `fyp-release.package.json`/`fyp-release-index.ts`; do not deploy emulator package or replace all existing exports |
| Existing Function patch | `provisionMemberRegistration` source-only assignment/tombstone guard | Preserve deployed runtime, environment, region, IAM and normal Member-only behavior |
| Firestore Rules | Exact current hash, additive fixed cohort/read-only assignment projections | Rerun focused Rules/security tests against exact package; preserve existing canonical grants/denials |
| Ordinary Admin/Mobile clients | Existing main entrypoints with verified-scope repositories | No special Demo App, hidden mock fallback or public Hosting change; native signed-in acceptance required |
| Auth | Exactly 27 new fictional identities in the manifest | Fresh UID and email collision checks; initially disabled, sole creation-binding custom claim; no existing identity/role/password edits |
| Domain source | Exactly 466 reviewed records under `orgs/gainpath/cohorts/fyp-v1` | Create-only and exact digest validation; no canonical source writes |
| Assignment/ownership | 27 assignments, 493 source/assignment ownership records, 27 Auth ownership records, one seed run | 54 canonical absence checks; transactional absence recheck before assignment; complete graph before enabling accounts |
| Release control | `datasetRuntimeReleases/fyp-v1` | Initially disabled, exact accepted source digest + all 27 UIDs + fictionalOnly; enable only after approved source validation |
| Manual synthetic smoke | One Trainer and one Content generation run, at most four explicit Admin Sends to Members01/02 | Same existing services and generated ownership sidecars; no preseeded success, external AI, push/email or automatic trigger |

Initial Firestore inventory is 1,014 source/control/ownership records, plus at most one release record (1,015 total). Auth creation timestamps are runtime-derived parameters bound from actual newly created Auth metadata and checked against ownership; they must not be copied from the emulator. Later recommendation/consent/inbox records are produced only by bounded authorized services and are not part of the initial source inventory. The manual smoke's exact generated paths depend on real service IDs and are recorded with generated ownership/digests, never blanket cloud-write authority.

Zero Storage objects, Storage Rules changes, index changes, billing/IAM changes, accepted workouts, paid transactions, rewards, Member Program changes or new Gemini requests are proposed. Coach credential attachments are unavailable; metadata fixtures are not real verification. No APK packaging/install or real-user policy rollout is covered.

## Mandatory preparation before first live write

1. Review and approve the exact manifest and deployment scope. All names and paths must remain fixed. Existing standing deployment permissions do not override this task's explicit no-live boundary.
2. Capture a fresh read-only project/default-database, deployed Function/runtime/environment/IAM and trigger inventory. Confirm no Auth trigger or collection-group worker can act on these paths. Do not read private Member histories. Snapshot rollback metadata and preserve every unrelated Function/configuration.
3. Check every proposed UID/email, source/assignment/ownership/control path and its canonical `users/{uid}`/membership absence. Any occupied, changed or unowned path stops the operation; never overwrite or repurpose an existing account. Previous collision checks are not current authority. Recheck evidence/booking freshness at the intended live clock; expired fixtures require a new validated/reviewed anchor, never relaxed age or availability requirements.
4. Prepare and verify a **manifest-bound live executor** with the same transaction, source/ownership, collision and Auth-binding safeguards. The implemented seeder intentionally accepts only `demo-gainpath-fyp` loopback emulators; removing its guard or passing a live project is prohibited. No live executor is implemented in this checkpoint.
5. Stage exact release artifacts, rerun Node22 compatibility/security checks and validate deployment selection/rollback. The ordinary production index remains unchanged locally; do not blanket-deploy from that dirty checkout.
6. Keep release control disabled while provisioning; validate persisted timestamps/digests/graph/27 assignments before enabling fictional accounts and the exact release. Real App Check must verify both callables; missing or invalid attestations must fail.
7. Verify ordinary native SDK Admin browser/Member device sign-in, scoped public/private queries, history/progress/report denominators and manual review→delivery/current destinations. Retain before/after evidence and pause the release on any isolation failure. Emulator REST-backed widgets are not this native UAT.

## Consent, educational policy and retention decision

Owner review must explicitly cover the fictional scoped consent scenarios and `demo-educational-v1` fixture values (three scored sessions, three distinct days, 30 assessed attempts, coverage0.8, compatible exercise score below65, maximum age7days). They are experimental educational fixtures. This requests no universal70 threshold, High-Risk classification, clinical claim or permission for real Members.

The four recommendation purposes stay separate and default-off for real accounts. Existing camera/backup consent is never recommendation or external-AI permission. No migration, retained real-history processing, real consent collection, arbitrary minimum-cohort threshold, TTL or retention period is included. An owner-approved data lifecycle and exact future cleanup plan remain necessary; the current cleanup command only inventories exact owned records and preserves anything changed or unowned.

## Stop / rollback

Disable the release control first and stop manual processing. Disable the exact fictional assignments (or the cohort's enabled metadata) to stop direct Rules-authorized reads as well; the callable gate or Auth disable alone is insufficient for immediate direct-read revocation. Change these records/accounts only within the approved recovery scope and preserve evidence. Do not restore an old source snapshot over newer consent revocations or Member response state. Restore only the scoped Function/Rules/client artifacts with current canonical regression checks. Cleanup is dry-run only: **no recursive cloud deletion or canonical data cleanup is authorized**.

The requested next approval is one consolidated review of this specific proposed release and fictional data inventory, conditional on the mandatory pre-write gates. It is not authorization to execute the superseded manifests, modify real users or remove the emulator-only seed guard.
