# Module 4 selective deployment — 23 October 2026

The owner approved deploying only the ten Functions listed in the delivery report by replying “proceed”. Deployment completed on project `gainpath-0619`; metadata verified at **14:10 MYT**, endpoint checks at **14:11 MYT**.

## Deployed and verified

| Function | Result | Revision |
|---|---|---|
| getMembershipOverviewCommand | Created, ACTIVE | getmembershipoverviewcommand-00001-bij |
| getMembershipQuoteCommand | Created, ACTIVE | getmembershipquotecommand-00001-dij |
| createMembershipPaymentCommand | Created, ACTIVE | createmembershippaymentcommand-00001-lug |
| getMembershipPaymentCommand | Created, ACTIVE | getmembershippaymentcommand-00001-bet |
| requestMembershipRefundCommand | Created, ACTIVE | requestmembershiprefundcommand-00001-cec |
| paymentWebhook | Updated, ACTIVE | paymentwebhook-00003-ceg |
| billplzSandboxReturn | Updated, ACTIVE | billplzsandboxreturn-00003-kis |
| listAdminBookingPaymentsCommand | Updated, ACTIVE | listadminbookingpaymentscommand-00003-foj |
| getAdminBookingPaymentCommand | Updated, ACTIVE | getadminbookingpaymentcommand-00003-hub |
| manageAdminBookingPaymentCommand | Updated, ACTIVE | manageadminbookingpaymentcommand-00005-hos |

All ten run Node.js 22 in `us-central1`. Total Function count increased from 50 to 55. Before/after comparison confirms **45 unrelated Functions unchanged**, including Google synchronization revision, environment and Eventarc configuration. The API returned Eventarc filters in a different order; comparison normalizes unordered metadata arrays rather than treating ordering as a configuration change.

Existing selected Functions retained their runtime account and secret bindings. Billplz Sandbox remains enabled for organization `gainpath`, collection `cd9oovf8`; refund collection configuration is unchanged. No secret versions or payloads were modified/read by these verification scripts.

Firestore/Storage Rules release references and Hosting release metadata are unchanged. No Rules, indexes, Hosting or catalogue data were deployed. APK remains uninstalled. No payment, refund, subscription modification or authenticated financial UAT was executed.

## Verification and scope

- Fresh build and focused backend regression check: **47 tests passed** before deployment.
- Firebase CLI reported successful creation/update for exactly the ten selected names.
- Hosted return endpoint: GET **200**, neutral text explicitly says return is not payment/activation confirmation.
- Payment webhook: GET **405**, enforcing POST-only ingress without invoking the provider.
- Membership overview without authentication/App Check: **401 UNAUTHENTICATED**.
- These are deployment/unauthenticated smoke checks, not proof of authenticated purchase, refund, promo or device acceptance. Those remain on the existing UAT checklist.

Machine-readable local evidence:

- `build/module4/deployment-before.json`
- `build/module4/deployment-after.json`
- `build/module4/deployment-verification.json`
- `build/module4/deployment-smoke.json`

Firebase warned about an outdated `firebase-functions` dependency and a failure to clean up build images. Deployment itself completed successfully. No dependency upgrade, artifact deletion, additional deployment or billing change was performed to address those warnings.

## Remaining gates

The read-only audit found no trusted membership catalogue or promo configuration. Approved plan prices, duration, benefits and versions are still required before purchase UAT; no values were invented or seeded. Auto-renew remains unavailable. Membership refund execution remains blocked; the existing Billplz HTTP 422 issue is unresolved.

Admin Hosting publication, Xiaomi APK installation, catalogue writes and any Sandbox financial UAT still require their own explicit approval. The original [delivery report and UAT checklist](module4-membership-delivery.md) remain applicable with the ten-Function deployment gate now satisfied.
