# Automatic Google Booking Delivery — deployed disabled, IAM review pending

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.

## Subsequent read-only pre-activation review

Fresh readback at 2026-10-22T14:33:30Z confirms all three Functions ACTIVE with automation false, timestamp absent and recipients empty; stored gym connection remains connected to owner-google-account-redacted@example.invalid. No provider writes or IAM changes performed.

Technical review of the platform-added role against [Google's service-agent catalog](https://docs.cloud.google.com/iam/docs/service-agents) and [Pub/Sub access-control documentation](https://docs.cloud.google.com/pubsub/docs/access-control) confirms that `service-879719977530@gcp-sa-pubsub.iam.gserviceaccount.com` is the expected Pub/Sub primary service agent for this project number, and `roles/pubsub.serviceAgent` is its documented automatically granted service-agent role. It is assigned only to that Google-managed agent, not the GainPath runtime or a human account. Recommendation: retain this standard platform grant; no additional IAM mutation is proposed. This technical review does not imply approval to activate automatic delivery.

Chrome browser automation remains unavailable; only the in-app browser is connected without the prior authenticated Admin session. Owner can finish the remaining non-mutating UI check in their existing Chrome session: open http://localhost:7360/, System Settings → Google integration, refresh status, and verify Connected / Automatic delivery: Disabled. No Sync/Send action is needed. Then request explicit scoped UAT activation approval before changing configuration or redeploying.

Owner approved the selective deployment, documented Eventarc/worker-invoker grants and subsequent Firebase `--force` retry-policy acknowledgement. No activation or provider writes authorized.

## Deployment readback

All three Functions are ACTIVE in us-central1, Node.js 22, using `gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com` and GOOGLE_GYM_CLIENT_SECRET version 1:

| Function | Revision |
| --- | --- |
| synchronizeGoogleBooking | synchronizegooglebooking-00001-duy |
| googleGymConnectionCommand | googlegymconnectioncommand-00003-foq |
| syncGymBookingCommand | syncgymbookingcommand-00002-hac |

Read back on each Function:

```text
GOOGLE_BOOKING_AUTOMATION_ENABLED=false
GOOGLE_BOOKING_AUTOMATION_ACTIVATED_AT: absent
GOOGLE_BOOKING_AUTOMATION_TEST_RECIPIENTS: empty
```

Actual Firestore Native database location is asia-southeast1. Eventarc trigger `projects/gainpath-0619/locations/asia-southeast1/triggers/synchronizegooglebooking-601069` matches it. Runtime and Eventarc trigger service account are exactly the dedicated account above. Event filters: type google.cloud.firestore.document.v1.updated, database (default), namespace (default), document path pattern `orgs/{organizationId}/bookings/{bookingId}`. Eventarc represents the managed destination as Cloud Function `projects/gainpath-0619/locations/us-central1/functions/synchronizeGoogleBooking`; this matches the intended target. A verifier initially assumed the Cloud Run destination field and was corrected without changing deployed configuration. Retry policy is enabled; application provider processing stops for events older than one hour.

Approved `roles/eventarc.eventReceiver` binding is at project scope. Approved `roles/run.invoker` was applied only on Cloud Run service `projects/gainpath-0619/locations/us-central1/services/synchronizegooglebooking` for the dedicated service account, after creation. Worker IAM contains no allUsers/allAuthenticatedUsers; invoker-IAM enforcement is enabled. Unauthenticated worker request returns HTTP 403.

## Unexpected platform IAM grant — stopped for review

Fresh comparison found Google provisioning also added this project-level binding during Eventarc/Pub/Sub creation:

```text
Principal: serviceAccount:service-879719977530@gcp-sa-pubsub.iam.gserviceaccount.com
Role: roles/pubsub.serviceAgent
Scope: projects/gainpath-0619
Condition: none
```

This is the Google-managed Pub/Sub service agent, not the GainPath runtime or a human principal. It was not in the owner's explicitly approved two-grant scope. No further resource mutations were made after discovery; the role has not been removed or accepted as approved. Owner review is required before further changes or activation.

Exact predefined-role permissions read independently: iam.serviceAccounts.get, iam.serviceAccounts.getAccessToken, iam.serviceAccounts.getOpenIdToken, iam.serviceAccounts.implicitDelegation, iam.serviceAccounts.list, iam.serviceAccounts.signBlob, iam.serviceAccounts.signJwt, resourcemanager.projects.get, resourcemanager.projects.list, serviceusage.services.use. No new Owner, Editor or unrestricted Secret Manager Admin grants were found. No project bindings removed; audit configurations unchanged.

## Preserved resources and non-mutating checks

- Total Functions now 50. All 47 non-target Functions match their complete pre-deployment metadata, including OAuth callback. Only the approved two existing Functions and new worker changed.
- All three pre-existing Google Cloud Run service IAM policies match baseline.
- All five secrets' metadata, version lists and IAM policies match baseline. No secret payloads read by verification.
- Both Firebase Rules releases match baseline. No payment code/resource or booking/Calendar mutation was executed by this deployment workflow.
- Updated manual Callables retain their public transport settings and reject unauthenticated requests with HTTP 401 UNAUTHENTICATED. No Sync/Send request was used for compatibility testing.
- Source build/type-check and targeted automatic/manual handler regressions passed before deployment. Disabled-mode actual-handler test verified zero HTTP provider calls and zero Firestore delivery writes for a valid confirmation transition.
- Authenticated Admin UI refresh could not finish: Chrome browser control connection was unavailable. No assertion of a fresh live authenticated manual-provider operation is made. Real provider operations were deliberately excluded by the owner's scope.
- No new OAuth connection, provider writes, payments/refunds, booking alterations, Hosting deployment or Xiaomi APK installation. No automatic UAT performed.

Machine-readable evidence: build/google-oauth-setup/automatic-deployment-verification.json, automatic-worker-invoker-verified.json and automatic-deployment-auth-smoke.json. Original baseline snapshots remain in the private ignored build directory.

## Costs and limitations

Although provider processing is disabled, booking updates can invoke Eventarc/Pub/Sub/Cloud Run and incur metered infrastructure charges. Enabled processing would add Firestore, Secret Manager, Google API quota usage and possible transfer between asia-southeast1 and us-central1. Retry executions are billed; uncertain Gmail attempts are never automatically resent.

Firebase reported an unhandled build-image cleanup warning after successful deployment. Stored artifacts may incur storage charges. No artifact deletion or extra redeployment was attempted under the scoped approval. Local build/test Node was 24; deployed runtime readback is Node 22.

## Proposed controlled activation — not approved

First review the unexpected Pub/Sub managed-service-agent grant and restore authenticated Admin verification. Then, only with separate explicit approval: organization gainpath; consenting test recipient `owner-google-account-redacted@example.invalid` only; Jackson's existing secondary calendar; fresh UTC activation cutoff; one fresh disposable paid Sandbox booking. Verify automatic confirmation, repeated-event/manual deduplication, A → B → A reschedule and cancellation notifications. Do not alter existing tested bookings or backfill history. Production-wide recipients and broader activation remain gated.
