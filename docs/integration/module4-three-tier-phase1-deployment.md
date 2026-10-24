# Three-tier Phase 1 — approved overview deployment

23 October 2026. Project `gainpath-0619`, organization `gainpath`. The owner explicitly approved the single-Function proposal by replying **“approve”** after the [local delivery report](module4-three-tier-phase1-delivery.md).

## Deployed result

Only `getMembershipOverviewCommand` was updated, in `us-central1`, on Node.js 22. Final metadata verified at **18:04 MYT**:

| Item | Result |
|---|---|
| Final state | `ACTIVE` |
| Previous revision | `getmembershipoverviewcommand-00001-bij` |
| Final revision | `getmembershipoverviewcommand-00003-xil` |
| Functions present | 55, unchanged count |
| Unrelated Functions | All 54 unchanged by full normalized metadata comparison, including Membership financial commands, Module 7, AI and Google delivery Functions |
| Rules | Both Firestore/Storage release records unchanged |
| Hosting | Release metadata unchanged; no publication |
| Composite indexes | All seven unchanged |
| Authentication smoke | POST without authentication/App Check returned `401 UNAUTHENTICATED` |

The overview adds the server-derived Free/Basic/Premium entitlement while retaining the legacy account/plans/transactions response. No catalogue record or Member account was written, and no financial or provider transaction was performed. APK installation, authenticated account/device UAT, catalogue approval/activation and later implementation phases remain outside this deployment approval.

## Configuration exception — original scaling setting not restored

The deployment produced revision `00002-xip` and materialized `serviceConfig.maxInstanceCount: 20`; the original Function and backing revision had no explicit maximum. Verification caught this difference rather than treating the target configuration as completely unchanged.

A narrow follow-up PATCH to **the same Function only**, with update mask `serviceConfig.maxInstanceCount` and value `0`, attempted to restore the prior unset setting. The operation completed successfully and produced final revision `00003-xil`, but both Cloud Functions and the backing Cloud Run revision still report **20**. The attempted restoration did **not** restore the original setting. No higher ceiling was chosen and no other service was changed.

Current verified configuration is therefore preserved **except for this recorded 20-instance maximum**. Environment hash, secrets bindings, runtime account, ingress, timeout, memory, CPU, concurrency and the remaining service configuration match the original. A future scaling decision should explicitly resolve this exception before claiming complete configuration equivalence or relying on higher capacity. The clear-to-zero attempt was based on [Google's documented clear-max-instances semantics](https://docs.cloud.google.com/sdk/gcloud/reference/functions/deploy); the actual project readback takes precedence over an assumption that clearing succeeded.

Firebase also warned that the installed `firebase-functions` version is outdated and that automatic build-image cleanup failed. Deployment itself succeeded. No SDK upgrade, artifact deletion, billing configuration or purchased service change was performed.

## Preflight and evidence

Fresh local Functions build passed. The exact seven-file backend regression selection from the delivery report passed **90 tests**, including entitlement, Membership payment, Module 7 payment/Admin/callback, chatbot and automatic Google delivery cases. The earlier 152-test local delivery evidence remains separate; only the backend subset was rerun for this deployment.

The currently deployed original source archive was downloaded before deployment. Comparison against that archive confirmed exactly three changed backend source files:

- `modules/commerce/membership-entitlement.ts` — new read-only resolver.
- `modules/commerce/membership-payment-service.ts` — overview projection/eligibility only.
- `modules/commerce/membership-payment-callables.ts` — overview injects current Auth reader.

Package, lockfile, TypeScript and project environment file hashes matched the previous deployment bundle. No unrelated source differences were included. The selective command, run from `functions`, was:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../firebase.json --only functions:getMembershipOverviewCommand --non-interactive
```

Local evidence under `build/module4/`:

- `phase1-source-review.json` — changed source list, reviewed hashes and configuration-file comparison.
- `phase1-deployment-before.json`, `phase1-deployment-initial-after.json`, `phase1-deployment-after.json` — metadata snapshots.
- `phase1-deployment-verification.json` — preservation checks with `selectedConfigurationPreserved: false` and the explicit maximum-instance exception.
- `phase1-runtime-initial-readback.json`, `phase1-runtime-readback.json` — original/new backing revision scaling and resources.
- `phase1-scaling-restoration.json` — same-Function PATCH operation and completion.
- `phase1-deployment-smoke.json` — final unauthenticated smoke result.
- `phase1-deployed-source-verification.json` — the initial approved upload and final deployed source have identical bytes/SHA-256 (`86b56335541bcb1098bcae8835883428ee33fc6116bbf65c516986f41c370bda`). The configuration update created a new storage generation but did not change the source content; this was independently checked by downloading both archives.

Authenticated Free/paid/expired response UAT was not performed. The smoke test demonstrates rejection and service availability, not financial/device acceptance or App Check success with a verified client token.

## Rollback readiness

The original source/build is preserved as `build/module4/phase1-overview-rollback-source.zip`, SHA-256 `7dd3550194539da6c8c21c22ac01dcc9c4fbdb6e2c7873234771181f442229e7`, and extracted to `build/module4/phase1-rollback-source/`. The original compiled entrypoint and Node 22 package configuration are present. The archive contains project configuration and should remain local.

If a rollback is separately requested, the prepared Functions-only configuration permits redeploying that preserved source to the same single target, from `functions`:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --config ../build/module4/phase1-rollback.firebase.json --only functions:getMembershipOverviewCommand --non-interactive
```

No rollback was executed. An application rollback does not by itself prove restoration of the maximum-instance setting; read back and explicitly resolve that configuration separately. No Firestore restoration, receipt deletion, membership change or financial reversal is needed because the entitlement resolver performs no writes.
