# Automatic Google delivery deployment — stopped safely

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

Owner explicitly approved the two documented IAM grants and three Function deployment with automation disabled. No activation or provider actions were authorized.

## Before deployment

- Actual database: `projects/gainpath-0619/databases/(default)`, Firestore Native, location `asia-southeast1`.
- Compatible Eventarc trigger location: `asia-southeast1`. Function region remains `us-central1`. Installed Firebase CLI reads the database location and sets the Firestore trigger region independently from the Function region; [Eventarc requires the trigger to match the Firestore database location](https://docs.cloud.google.com/eventarc/docs/locations).
- Runtime and proposed Eventarc trigger identity: `gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com`. Installed CLI maps the declared runtime service account to the event trigger service account. Post-deployment identity verification remains pending because no worker was created.
- Local deployment environment explicitly sets `GOOGLE_BOOKING_AUTOMATION_ENABLED=false`, omits `GOOGLE_BOOKING_AUTOMATION_ACTIVATED_AT`, and sets `GOOGLE_BOOKING_AUTOMATION_TEST_RECIPIENTS` empty. Removed the declared empty-default timestamp parameter so Firebase does not materialize an empty key when the operator requires it genuinely unset. Configuration behavior otherwise remains fail-closed.
- Build, test type-check and focused preflight tests passed. Added a real-trigger-handler regression showing disabled mode makes zero HTTP provider requests and zero Firestore delivery writes for a valid confirmation event; all six enabled/disabled worker test cases pass. No actual booking was mutated to test disabled mode.
- Snapshotted all 49 Function metadata records, project policy, three existing Google Cloud Run service policies, all five secrets' metadata/version lists/policies, and both Firebase Rules releases. No secret payload access.

## Applied change

Added only the approved project binding `roles/eventarc.eventReceiver` for the dedicated service account. Fresh readback verifies all unrelated project bindings/audit configurations preserved.

## Blocking deployment result

The selective Firebase command exited with:

```text
Error: Pass the --force option to deploy functions with a failure policy
```

The new worker intentionally declares `retry:true`. In non-interactive mode Firebase CLI requires `--force` to acknowledge billed failure-policy retries. The CLI warning says infrastructure retries can continue up to seven days; the implementation independently stops provider processing once an event is over one hour old and never automatically resends uncertain Gmail.

Stopped immediately under the owner's stop-on-failure instruction. Did not rerun with `--force`, remove retries, change regions, broaden IAM or deploy other resources.

## Fresh stopped-state verification

- All 49 existing Functions are exactly unchanged against preflight metadata. `googleGymConnectionCommand` and `syncGymBookingCommand` remain ACTIVE, Node.js 22, dedicated runtime, revisions `googlegymconnectioncommand-00002-zat` and `syncgymbookingcommand-00001-nah`.
- `synchronizeGoogleBooking` and Cloud Run service `synchronizegooglebooking` do not exist; no worker Eventarc configuration exists to read back. No worker service is publicly invokable.
- Worker-only `roles/run.invoker` grant was not applied because the target does not exist.
- Project policy differs only by the approved Eventarc Receiver member. Existing three Google service IAM policies, all secret metadata/versions/policies and both Rules releases match baseline.
- Non-mutating manual Callable smoke tests: both reject requests without authentication/App Check with 401 UNAUTHENTICATED. Manual Function code/configuration remains unchanged, so prior controlled compatibility is preserved; no Calendar mutation or email resend was used to test it.
- Disabled variables are prepared locally but have not been applied to the existing deployed Functions because deployment stopped. No claim of deployed disabled-setting readback is made.
- No Calendar/Gmail provider writes, new OAuth connections, payment/refund operations, booking mutations, Hosting deployment or Xiaomi APK installation.

Machine-readable evidence: `build/google-oauth-setup/automatic-location-preflight.json`, `automatic-deployment-baseline.json`, `automatic-event-receiver-applied.json`, `automatic-deployment-stopped-verification.json`. Full private snapshots remain in the ignored build directory.

## Cost and proposed continuation

No new worker/build was deployed; no new automatic worker/Eventarc traffic is active. An IAM grant itself does not run provider operations. If deployment later succeeds, Firestore events can incur Eventarc/Pub/Sub/Function invocations even with automation disabled; enabled work adds Firestore reads/writes, Secret Manager accesses, Google API quota consumption and potential cross-region transfer between Singapore and us-central1. Retry executions are billed. No credits were purchased, billing plan changed or paid API enabled by these steps.

Continuation requires acknowledgement to rerun only the same approved Function scope with Firebase's retry-policy confirmation flag, still disabled:

```powershell
pnpm exec firebase deploy --project gainpath-0619 --only 'functions:synchronizeGoogleBooking,functions:googleGymConnectionCommand,functions:syncGymBookingCommand' --non-interactive --force
```

Do not run automatically under the current stop-on-failure instruction. After successful creation, apply only the already-approved service-specific invoker binding to the dedicated identity, verify no `allUsers` and read back all identities/settings/policies. Stop on any unexpected requirement.

Separate future activation proposal: organization gainpath, only consenting recipient `owner-google-account-redacted@example.invalid`, Jackson's existing secondary Calendar, fresh UTC activation cutoff, and one new disposable confirmed paid Sandbox booking for confirmation/reschedule/cancellation UAT. No existing bookings altered or historical backfill. Activation remains unapproved.
