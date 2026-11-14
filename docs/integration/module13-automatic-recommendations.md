# Module 13 automatic recommendations and Admin monitoring

The [workout-triggered integration](module13-workout-automatic.md) now defines the prepared automatic Member workflow. The batch command below remains a legacy maintenance operation.

The FYP workflow runs eligible evidence through the existing generation, consent, target validation and delivery services. An authorized operator starts a source batch through `admin.queue.automatic`. Each qualifying recommendation is sent automatically after the batch completes. The operator does not select recipients or approve individual records. Reuse the batch ID after interruption. The existing delivery transaction verifies or creates the inbox notification and receipt together.

The Admin page uses Overview, History and Needs Attention. Both recommendation types load concurrently. Search, date range and tab changes use the pages already in memory. Details open immediately with a loading state and fetch fresh authorization and target evidence. The monitor distinguishes delivery receipts from legacy sent records. The legacy server does not supply delivery proof, so its records show Delivery unverified. The existing FYP API has no authorized Admin withdrawal operation. Coach and tutorial details use the available published matching fields and an icon fallback.

## Measurements

Authenticated reads against the same deployed Singapore revision, 13 records per type and three pairs per mode. The first observation includes the first callable sign-in overhead. No Cloud Run startup was conclusively correlated.

| Measurement | Sequential baseline | Parallel workload |
| --- | ---: | ---: |
| First pair | 9.572 s | 5.740 s |
| Subsequent pairs | 9.573 / 7.882 s | 4.476 / 4.443 s |
| Median | 9.572 s | 4.476 s |
| Tutorial detail | 3.169 s | 3.414 s |
| Coach detail | 6.455 s | 6.706 s |

A privileged ordered Firestore read of up to 26 records took 71–171 ms. Callable time includes authorization, consent and source checks. The source optimization bypasses candidate initialization for list operations and parallelizes independent identity and consent reads. The measurements above quantify request orchestration on the current deployment. The source optimization requires a release before its production latency can be measured. Both the deployed callable and Flutter transport use `asia-southeast1`. Widget verification covers interaction behavior and rendering geometry. Browser paint timing was unavailable.

Reproduce the timing with `node functions/tools/module13-admin-latency.cjs baseline` and `node functions/tools/module13-admin-latency.cjs after`. The report is written to `build/module13-admin-performance`. Responsive renders are in its `screenshots` subdirectory.

## Activation

The prepared archive is `build/module13-admin-performance/fyp-automatic-prepared.zip`. Compile `functions/tsconfig.fyp-release.json` to the archive's `lib` folder and package it with `functions/fyp-release.package.json` as `package.json`.

1. Obtain explicit release approval and capture the current source and service configuration for `projects/gainpath-0619/locations/asia-southeast1/functions/fypDatasetCommand`.
2. Update only that function's source with the prepared archive and entry point `fypDatasetCommand`. Preserve its runtime, region, IAM, service settings, App Check and existing environment configuration. The updated operations are `admin.queue.automatic`, `admin.queue.monitor` and the optimized existing list operation.
3. Use Node 22 to run `node functions/tools/module13-fyp-automatic.cjs <stable-batch-id>` from the repo against the authorized sample cohort. Run after an eligible source batch is ready. The FYP workflow uses this operator trigger and has no continuously scheduled worker.
4. Verify receipt-backed delivery in Admin and the assigned Member inbox. Replay the same batch ID to confirm there is no duplicate notification. Restore the saved source if release verification fails.

Cloud Functions and Rules were not deployed. Real-camera generation still requires separately reviewed scoring and evidence admission. The existing Member feed reads actual delivered inbox records and uses its existing navigation and dismissal flows.

## Verification

- Firebase Emulator verified automatic Coach and Tutorial delivery into the assigned Member inbox, target eligibility, account isolation and replay without duplicate inbox entries. The suite passed 30 tests with one skipped. Backend regression tests passed 41.
- Admin regression tests passed 68 with 13 skipped. The 12 responsive render cases covered six widths from 320 to 1920 px at 100% and 200% text scaling. The separate authenticated Flutter render read 26 live records using the current deployed callable, without writing data. Output is in `build/module13-admin-performance/live-renders`.
- Mobile regression tests passed 34 and the Android Debug build completed. The existing Mobile UI reads delivered records through its existing consent and ownership checks. Live automatic delivery awaits activation.
