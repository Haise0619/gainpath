# Controlled FYP live integration implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline, with test-driven-development and a fresh security review before live mutation. Preserve this dirty checkout; no reset, stash, broad staging or new checkout that omits the accepted implementation.

**Goal:** Execute the owner's exact controlled live scope in `gainpath-0619` `(default)` and verify ordinary Admin/Member use.

**Architecture:** Retain `orgs/gainpath/cohorts/fyp-v1`, the accepted source manifest and all existing services. Add a separate manifest-bound live executor; leave the emulator guard unchanged. New accounts remain disabled until exact source/ownership validation, existing real App Check readiness and protected infrastructure checks pass. Use the existing configured CLI credential and registered App Check provider only.

**Spec:** `C:/Users/Ngzhe/.codex/attachments/4d9d1faa-b44b-4799-864e-9566d9cb9ab1/Pasted text.txt` and `docs/integration/gainpath-fyp-cohort-preflight.{md,json}`. Latest owner instruction supersedes those documents' preparation-only restriction for the exact listed scope. No further routine approval gate.

**Tech stack:** existing TypeScript/Admin SDK, Firestore/Auth, Node22 release runtime, Flutter ordinary entrypoints, existing CLI deployment/rollback patterns.

## Global constraints

- Only project `gainpath-0619`, database `(default)`, cohort `fyp-v1`, exact 27 UIDs and approved manifest paths.
- Deploy only two new FYP callables, source-only `provisionMemberRegistration` guard and additive reviewed Rules. No unrelated Functions, IAM/billing changes, Storage/index change, real histories, financial/reward/booking mutations or Gemini calls.
- Credentials encrypted outside the repository; never plaintext in logs/arguments/reports/Git.
- Preserve canonical data, UI/theme, original academic requirements, Module2/12 behavior and the 18-attempt Gemini ledger.
- One Trainer and one Content generation run; at most four Sends to Members01/02. Mock semantic provenance stays explicit.
- Any security/project/collision/infrastructure gate failure stops the dependent live operation. Complete independent authorized local work and report exact blockers.

## Review focus

- Interrupted Auth creation must not cause adoption of unrelated accounts; use a secret provisioning nonce while disabled and durable exact ownership binding before restoring manifest profile fields.
- Existing consent/recommendation activity must never be reset by a seed retry.
- Missing/stale/tampered readiness artifacts cannot enable activation; every live action rechecks project, manifest and ownership.
- A functioning App Check debug provider is legitimate controlled-test attestation, but must not be reported as Play Integrity or production reCAPTCHA proof.
- Direct Rules reads require assignment revocation as well as callable release shutdown on failure.

## Task 1 — Final read-only live preflight

**Files:** new `functions/tools/fyp-live-preflight.cjs`; evidence `build/fyp-live-20261104/`; preserve prior artifacts.

**Interfaces:** consumes accepted manifest/source hashes, existing CLI auth, existing registered App Check fixture; produces sanitized metadata/readiness and exact rollback artifacts, with no live writes.

- [x] Verify repository/manifest baseline, project/default DB, current Functions/Rules/indexes/IAM and trigger paths.
- [x] Read exact UID/email/path collision metadata only; verify App Check cryptographically with the already registered fixture.
- [x] Check local Node22 availability/compatibility, client UI availability, freshness and rollback scope. Stop dependent live work if any mandatory gate fails.

## Task 2 — Separate secure live executor

**Files:** new `functions/src/modules/dataset/fyp-live-{manifest,executor}.ts`, `functions/test/fyp-live-*.test.ts`, `functions/tools/fyp-live.cjs`, local encrypted credential helper outside the repository.

**Interfaces:** consumes exact accepted manifest/typed source graph, verified SDK clients, encrypted vault and durable audit ports; produces dry-run/apply/validate/cleanup-dry-run and bounded activation/revocation records.

- [x] Write and run failing tests for project/endpoint/manifest/ownership/collision/interruption/activation boundaries.
- [x] Implement create-only source transactions, actual Auth creation binding, interrupted disabled-account resumption and source validation before activation.
- [x] Run focused tests, emulator-seeder regression and source/test TypeScript checks; retain exact source changes and credentials only in DPAPI-protected external storage.

## Task 3 — Protected deployment and seed

**Files:** exact staged archives/configuration under the new release evidence directory; normal production Functions index unchanged.

**Interfaces:** consumes successful preflight/executor tests/review; produces exact deployed revisions/Rules release and owned source graph, initially disabled.

- [x] Fresh review of all new release/executor code and exact deployment package.
- [x] Patch current deployed registration source only; deploy exact additive Rules and two FYP callables, preserving unrelated configuration/IAM.
- [x] Verify disabled release; apply source graph with disabled identities; validate references, ownership, Rules/Auth/App Check and no unintended writes.
- [x] Activate exact fictional identities/release only after every required check passes; bounded shutdown on failure.

## Task 4 — Ordinary live acceptance and final report

**Interfaces:** consumes the deployed validated graph and real Auth/App Check ordinary clients; produces actual live counts, signed-in screenshots, once-only workflow proof and reproduction/recovery guide.

- [ ] Verify each supported ordinary Admin/Member screen and real repositories, preserving existing sessions/local history and branding.
- [x] Run one Trainer/Content refresh and at most four Sends; verify intended recipient, current destinations, responses, duplicates and revocation.
- [x] Verify isolation/legacy endpoint denials and canonical preservation; report unsupported scenarios honestly.
- [x] Update operational references/report with actual live evidence, exact counts/revisions and secure credential retrieval instructions; do not expose credentials.

## Execution ledger

Pre-flight: Task1 readiness and accepted source manifest feed Task2 guard and Task3 activation. Task2's validated exact resource report feeds Task3 and Task4; a failure cannot become an activation grant. Task3's fixed two-callable scope feeds ordinary client routing in Task4. Existing source schema1/consent2 contracts and canonical organization IDs remain unchanged.

Ruling: The owner has already selected/authorized the architecture and uninterrupted execution. No design approval, worktree question or routine live-operation approval is needed. Reuse the current checkout to retain accepted uncommitted work. Do not commit unrelated work.

Ruling: Current clock 4 November 2026, approximately one hour after the accepted anchor. Preserve the existing anchor unless actual freshness validation disproves readiness; no re-anchor has been consumed.

Owner clarification (4 November): explicitly approved `roles/run.invoker` / `allUsers` bindings **only** for the two new FYP Cloud Run services, after the fresh project policy proved no inherited public invoker. Firebase Auth, enforced App Check and cohort authorization remain mandatory; no existing service/project IAM change is authorized.

Ruling: The actual deployed Rules hash `3d46c773...` matches the retained 28 October verified release. The accepted local file also includes unrelated unreleased canonical edits. Stage the reviewed FYP block on the exact deployed baseline, preserving that baseline byte-for-byte outside the insertion; do not deploy the unrelated local edits or overwrite them in the worktree. The initial SDK permission diagnostic was a GoogleAuth9/10 header-version mismatch; using Firestore's own installed GoogleAuth9 with the same existing CLI account passes, without new credentials or permissions.

Task 1: read-only gates pass, Node22.23.4 portable runtime official checksum/Windows signature verified. Existing configured CLI account and registered web debug App Check exchange verified cryptographically. Fresh rollback archive retained; zero collisions. Owner cannot currently connect a phone; native Member acceptance remains pending independently of backend preparation.
Task 2: exact-manifest live executor, CurrentUser DPAPI external vault, fixed operator modes and bounded activation/quarantine implemented. Emulator-only seed guards preserved. Observed RED→GREEN for immutable authority, alternate-universe guard, partial Auth-enable quarantine, incomplete infrastructure-proof rejection and vault outside-repo enforcement.
Task 3: prepared exact registration source-only archive, two-export release archive and actual deployed Rules baseline + additive FYP block. 13 staged Rules checks and31 package/backend checks pass. Fresh read-only security review found no remaining Critical/Important findings after reproduced fixes. No live deployment or data writes yet.
Ruling: use the existing registered web debug App Check provider for controlled live browser/backend verification; report it as Firebase-signed debug-provider attestation, never as Play Integrity/reCAPTCHA. No new debug credential registration is authorized or attempted.

Live execution update (4 November): registration guard and additive Rules deployed; both exact new Node22 callables created with the separately approved transport IAM bindings. Source/archive,69 unrelated Functions, existing registration runtime/environment/IAM, project IAM and indexes verified preserved. Exact1015 initial Firestore resources and27 Auth identities were created disabled and validated. No seed re-anchor used.
Live recovery: direct API creation omitted standard Firebase project bootstrap variables; SDK boot reproduced the missing-project gap. Added only public FIREBASE_CONFIG/GCLOUD_PROJECT on the two new services. Quarantined source/assignments/Auth while investigating. One bounded owned recovery revokes all27 fictional refresh tokens, advances assignments to revision3, and pins supported accountLifecycle session floors in27 fictional user records; original consent/history/publication records and baseline manifest remain untouched.57 focused recovery/guard checks pass. Release is enabled after validated recovery.
Live acceptance: fresh Admin/Member Auth/AppCheck sessions pass. Ordinary Admin dashboard18 Members/7 active Coaches;18-Member directory,eight-Coach management,12 Routines andthree published Programs load. Real backend reads pass own profile,three owned observations,seven published Coaches,12 Tutorials,three Programs,current destinations/availability,52-session Module12 and isolation/legacy-registration denials. Existing documented fictional canonical control can still read its own user document and is denied FYP private access. No real histories read.
Ruling: frozen fixture end time must not reject a bounded through-now Insights presentation. Consent still covers the entire requested range, every queried row must match the immutable approved path inventory, future/oversized queries and unapproved rows fail closed; generation/revalidation keep original source-window limits.73 targeted backend checks and33 existing Admin widget checks pass. A literal four-file before/after source-fix allowlist preserves the original accepted data manifest; labels now identify fictional educational data in both local and deployed use.
Native blocker: both existing Pixel emulators lack safe installation headroom. Debug and smaller profile updates on Pixel9 failed with INSTALL_FAILED_INSUFFICIENT_STORAGE; no uninstall/data clearing occurred. Pixel9Pro was inspected only and stopped after its boot reduced available space below the required headroom. Owner cannot currently connect the phone. Native Member UI/AppCheck acceptance remains pending; no new App Check debug credential is registered.

Final live workflow (4 November): exactly one Trainer and one Content run completed, each6 leads/12 abstentions across18 Members. Four explicit ordinary Admin Sends to Members01/02 are UI-confirmed; no budget remains. Final screenshot retained. Native acceptance was explicitly deferred by the owner; both emulator updates failed for insufficient storage without data clearing. Existing CLI authentication then expired; the final runtime inventory, post-Send Member action/idempotency checks, fixed Member18 live denial probe and cleanup inventory have NOT executed. No alternate credentials or new IAM were attempted. Local132 backend/33 Admin/13 staged Rules checks and type/analysis checks passed. Operational references now point to the partial live checkpoint; no full completion claim.

Final acceptance continuation (4 November,16:00 MYT): owner reauthenticated the same account. Sandbox DNS ENOTFOUND reproduced the misleading CLI authentication response; approved network execution restored the fixed-scope tools without alternate credentials. Direct counts4/4/4, Member inbox/destination/cross-Member/action/exact-retry/delivery-replay checks all pass. Member18 denied callable and direct reads at disabled revision4, restored at5; source validation passes466/27, all27 Auth enabled/verified,54 fictional canonical paths absent. Exact deployed revisions captured;69 unrelated Functions/Rules baseline/index/project IAM preservation passes. Cleanup dry-run inventories1133 owned Firestore records and27 Auth bindings with zero drift; no deletion. Only native UI remains incomplete by explicit owner instruction, with real-user production/policy gates still held. Do not replay the one-time acceptance scripts.
