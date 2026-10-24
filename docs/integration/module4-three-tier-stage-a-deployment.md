# Three-tier Stage A — approved selective deployment

23 October 2026 · Firebase project `gainpath-0619` · Organization `gainpath`.

The owner explicitly approved Stage A after reviewing the remaining delivery report. Scope: update `getMembershipOverviewCommand`; create `getMembershipAccessCommand` and `verifyMemberMembershipCommand`. These are read-only commands. This approval excludes reward/voucher financial handlers, catalogue/policy/account writes, APK installation, Hosting/Rules/indexes and financial/authenticated account UAT.

## Preflight and isolated source

Read-only metadata captured 55 existing Functions, two Rules releases, seven composite indexes and no Hosting release. The overview was ACTIVE on Node 22, revision `getmembershipoverviewcommand-00003-xil`, with the already-recorded maximum of 20 instances. The prior deployed source was preserved before deployment:

- `build/module4/stage-a-overview-rollback-source.zip`, SHA-256 `86b56335541bcb1098bcae8835883428ee33fc6116bbf65c516986f41c370bda`.
- Extracted baseline: `build/module4/stage-a-rollback-source/`.
- Snapshot: `build/module4/stage-a-deployment-before.json`.

The release source was constructed from that exact deployed archive in `build/module4/stage-a-source/`. Only five source files differ:

1. `src/index.ts` — exports the two additional read-only commands.
2. `src/modules/commerce/membership-access-callables.ts` — new App Check-enforced command adapters.
3. `src/modules/commerce/membership-access-service.ts` — trusted access and Admin verification reads.
4. `src/modules/commerce/membership-entitlement.ts` — shared read-only facts with privileged target identity lookup; existing Member contract retained.
5. `src/modules/commerce/membership-payment-callables.ts` — overview uses `preserveExternalChanges:true` to prevent generated runtime-setting resets.

All financial service source, package/lock/build files and project environment configuration match the deployed baseline. Pending reward/voucher implementation files and exports are absent from the isolated bundle. Existing shared-checkout work was not reset or repackaged wholesale. The Functions-only deployment configuration is `build/module4/stage-a.firebase.json`; it excludes local tests and the dependency junction. Reviewed hashes are retained in `build/module4/stage-a-source-review.json`.

Windows sandbox restrictions initially blocked the local dependency junction; the authorized local preparation was rerun with the required filesystem access. No new package installation/dependency upgrade was needed. The isolated build/load and targeted test typecheck passed. **120 focused tests passed, two Stage C voucher cases explicitly excluded** because the approved bundle retains original financial services. The first unfiltered regression run correctly exposed the absent Stage C Admin voucher projection; this was not addressed by deploying out-of-scope financial code.

The final test selection covers entitlement/access/privileged lookup, manifest preservation, Membership purchase/renewal/promo/refund/recovery, existing Booking/Admin/callback, chatbot and automatic Google delivery behavior. Local execution used Node 24.19.0; the deployed runtime remains Node 22. The two excluded case names are `projects the approved gross fee, voucher discount and funding snapshot for financial review` and `atomically retains one earned Premium voucher term for each verified paid period`. Their local full-implementation results remain in the earlier delivery report; Stage A does not claim their deployment.

## Command and verification

From `functions`, the approved selective command uses the isolated source configuration:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../build/module4/stage-a.firebase.json --only functions:getMembershipOverviewCommand,functions:getMembershipAccessCommand,functions:verifyMemberMembershipCommand --non-interactive
```

Deployment completed successfully. No authenticated Member/Admin call was used as a smoke test, and no policy was published to activate feature restrictions.

| Selected Function | Verified result | Revision |
|---|---|---|
| `getMembershipOverviewCommand` | ACTIVE, Node 22; existing complete service configuration preserved | `getmembershipoverviewcommand-00004-yuz` |
| `getMembershipAccessCommand` | ACTIVE, Node 22; new read-only callable | `getmembershipaccesscommand-00001-wan` |
| `verifyMemberMembershipCommand` | ACTIVE, Node 22; new read-only Admin callable | `verifymembermembershipcommand-00001-rof` |

Final metadata at `2026-10-23T13:46:31.759Z` contains 57 Functions: one existing update and two new Functions. **All other 54 Functions are byte-for-byte unchanged in the normalized metadata comparison.** Both Rules releases, all seven indexes and Hosting release metadata are unchanged. The overview's service configuration is identical except its expected revision field, including environment hash, secret bindings, runtime account, memory/CPU, concurrency, timeout and maximum **20**. The historical maximum-instance exception was neither fixed nor changed. The two new Functions have 256 MiB memory, one CPU, concurrency 80, timeout 60 seconds, no secrets and no explicit maximum in Cloud Functions metadata.

All three endpoints returned **401 `UNAUTHENTICATED`** to POSTs without authentication/App Check. This establishes service availability/rejection only, not authenticated App Check success, Member/Admin acceptance, financial UAT or feature-policy activation. No account, catalogue or policy writes and no provider/financial operations were executed.

Each deployed source archive was independently downloaded read-only. All three have identical SHA-256 `8cf413aef4eaabbeaac1fe4cf2e0e7ee33ba1e7369cd5d77259841e88d0ea97f`, 609,336 bytes. All **293 archive entries** match the local isolated approved source/build; no reward or voucher implementation was inadvertently included. Financial service source hashes continue to match the rollback baseline.

Evidence under `build/module4/`:

- `stage-a-deployment-before.json`, `stage-a-deployment-after.json`, `stage-a-deployment-verification.json` — metadata and preservation comparison.
- `stage-a-source-review.json` — exact five changed source files and reviewed hashes.
- `stage-a-deployed-source.json`, `stage-a-deployed-source-comparison.json` — all target source generations/digests and 293-entry comparison.
- `stage-a-smoke.json` — three unauthenticated rejection checks.
- `stage-a-overview-rollback-source.zip` and `stage-a-rollback-source/` — preserved baseline. These contain project configuration and remain local.

Firebase warned that the installed Functions SDK is outdated and that automatic build-image cleanup failed. Deployment itself succeeded. No dependency upgrade, artifact deletion, billing/service purchase or cleanup retry was performed. The build-image retention warning remains for separate review.

**Stage A is technically complete.** Stage B rewards, Stage C voucher/finance deployment, business catalogue/policies, authenticated/device UAT, Admin Hosting publication and APK installation remain unapproved/unperformed. Default client access enforcement remains off.

## Rollback readiness

The original overview source/configuration is preserved locally. If rollback is separately requested, selectively redeploy its preserved baseline to `getMembershipOverviewCommand`, preserving the captured current service configuration. Do not use the original unset-scaling assumption: the baseline maximum is currently 20, and the historical exception remains unresolved. No data rollback is needed for these read-only commands.

Removing either new Function, changing feature policy, changing scaling, distributing a client or deploying another stage requires its own approved scope. Do not delete catalogue/accounts/receipts or deploy a whole codebase as rollback. The default APK access-enforcement flag remains false; deploying Stage A alone introduces no new Workout/Booking/AI restrictions.
