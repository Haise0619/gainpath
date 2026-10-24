# Scoped UAT guards deployed — automation disabled

Owner approved deployment of only the local scope-hardening worker and connection-status updates. Deployment completed successfully; fresh readback at 2026-10-22T15:13:31Z passed.

| Function | State | Revision |
| --- | --- | --- |
| synchronizeGoogleBooking | ACTIVE | synchronizegooglebooking-00002-yed |
| googleGymConnectionCommand | ACTIVE | googlegymconnectioncommand-00004-fow |

Both use Node.js 22 and gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com. Automation flag false; activation timestamp absent; recipient list empty; Coach/booking scope unset. New guards fail closed until the complete exact scope is configured. No environment was enabled and no test booking was created.

Complete pre/post snapshots verify all 48 other Functions, project and four Google-service IAM policies, all five secrets' metadata/versions/policies, Firebase Rules releases and worker Eventarc configuration unchanged. Worker has no public allUsers/allAuthenticatedUsers binding and invoker IAM enforcement remains enabled. No additional IAM grant or retry-policy override was needed for this update. Secret payloads were not read.

Before deployment: TypeScript build/test type-check and 31 focused tests passed. The prior broader local scope-hardening test run passed 44 tests. No live automatic-delivery UAT, payment/refund operation, Calendar/Gmail write, booking alteration, OAuth connection, Hosting deployment or Xiaomi APK installation was performed.

Firebase reported a build-image cleanup warning after successful deployment. Stored build artifacts can incur charges; no deletion or redeployment was attempted. Disabled worker invocations may still incur infrastructure costs. Local Node 24 versus deployed Node 22 remains a verification limitation.

Evidence: build/google-oauth-setup/scope-deployment-verification.json, with ignored private before-snapshot in build/google-oauth-setup/private/scope-deployment-before.json.

Next separate step: obtain authorization to prepare one fresh disposable unpaid hold for Jackson under the consenting Member account; record its exact ID and creation/expiry times and T0 before its creation. Present the fully populated activation configuration for explicit approval. Do not pay before activation approval or reuse historical bookings. If the hold expires before activation can be approved/read back, stop and prepare a replacement only with authorization. Automatic confirmation/reschedule/cancellation emails remain unapproved until that final activation gate.
