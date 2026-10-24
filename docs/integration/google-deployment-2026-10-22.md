# Google integration selective deployment — 2026-10-22

## Update — approved transport correction verified

Owner explicitly approved the proposed `allUsers` → `roles/run.invoker` binding by replying “proceed”. Applied only to Cloud Run service `googlegymconnectioncommand`; fresh policy comparison confirmed unrelated bindings were preserved. The transport blocker described below is resolved.

Fresh HTTP checks now pass: both Callables return 401 UNAUTHENTICATED without credentials/App Check; the callback returns 400 without OAuth state. All three Functions remain ACTIVE under the dedicated runtime account with secret version 1; the original 46 Functions retain their revisions. No redeployment, Google connection, provider writes or booking changes occurred in this correction. Consent and real delivery UAT remain separately gated, as does independent Console verification.

Owner approved deployment of only `googleGymConnectionCommand`, `googleGymOAuthCallback` and `syncGymBookingCommand` by replying “proceed” to the selective deployment proposal.

All three now report ACTIVE in us-central1, Node.js 22, with runtime `gainpath-google-sync@gainpath-0619.iam.gserviceaccount.com` and `GOOGLE_GYM_CLIENT_SECRET` version 1. All 46 pre-existing Functions retained their states and revisions; total is now 49.

Revisions:

- `googlegymconnectioncommand-00002-zat`
- `googlegymoauthcallback-00001-ced`
- `syncgymbookingcommand-00001-nah`

## Deployment correction and validation

Firebase CLI source discovery runs before dotenv loading. A raw `process.env.GOOGLE_GYM_SERVICE_ACCOUNT` therefore omitted the intended runtime identity. Changed the three declarations to use required `defineString('GOOGLE_GYM_SERVICE_ACCOUNT')`; added a regression test that checks deployment metadata without dotenv loaded. Initial deployment automatically added default-compute secret access; that unintended grant was removed and its absence verified after deployment. Final runtime identities are correct.

Build and test type-check passed; 29 focused tests across seven backend files passed. Local Node 24 differs from deployed Node 22. No full suite or APK build performed.

Fresh unauthenticated HTTP checks:

- `syncGymBookingCommand`: 401 with Firebase UNAUTHENTICATED.
- `googleGymOAuthCallback`: 400 for missing OAuth state.
- `googleGymConnectionCommand`: 403 at Cloud Run IAM, before Firebase checks. Its transport-invoker binding is absent following the interrupted initial create. This remains a functional blocker.

Attempt to complete that Function's standard transport policy was rejected by automatic approval review: adding persistent `allUsers` / `roles/run.invoker` was considered a separate public-exposure change needing explicit approval. No such change was applied. Proposed scope is only Cloud Run service `projects/gainpath-0619/locations/us-central1/services/googlegymconnectioncommand`. Firebase Auth, enforced App Check and server-side Admin/org authorization remain required for operations. Runtime IAM roles are unchanged by this proposal.

Firebase deployment completed with a build-image cleanup warning; unused image storage may incur charges. No artifact deletion performed.

## Remaining gates

1. Explicit approval to add the connection service's public transport-invoker binding, then rerun its unauthenticated rejection smoke test.
2. Independent Console verification of registered OAuth callback/scopes and External/Testing test user remains pending; source/env matches and owner confirmation are recorded separately.
3. Separate approval for Google account consent, secondary Calendar creation and real Gmail/Calendar delivery UAT. No account connection, provider writes or booking changes occurred. First UAT remains Admin-triggered; personal primary Calendar stays untouched.

Callback URL: `https://us-central1-gainpath-0619.cloudfunctions.net/googleGymOAuthCallback`.

Machine-readable fresh metadata: `build/google-oauth-setup/deployment-verification.json`; HTTP checks: `build/google-oauth-setup/deployment-auth-smoke.json`.
