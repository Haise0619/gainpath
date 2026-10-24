# Admin-positive Membership verification — PASS

24 October 2026 · Project `gainpath-0619` · Organization `gainpath`.

The owner requested the next step and signed into the existing GainPath Admin account through the usual local Admin login page. The pending Admin-positive read-only verification is now **PASS**. Together with the 13 successful Member/API cases on 23 October, **14 authenticated read-only cases passed across the two runs**. The earlier phone Dashboard/plan-list observations and APK installation remain separately recorded; the 13 prior API cases were not rerun or relabelled as fresh today.

## Scope and existing authority

Initially no Admin browser tab or saved session was available. A local-only UAT entry point reused the existing `MemberMembershipVerificationPanel` and `FirebaseAdminMemberDirectoryRepository`. It consumed normal Firebase Auth session state, using the same localhost origin and existing web Firebase configuration; it did not read browser credential storage or impersonate an Admin through privileged IAM credentials.

The owner signed in privately through the existing Admin login page. No password/token was requested in chat, copied, logged or saved by the UAT tool. The server, not the local view, authorized the actual current verified Admin role and organization membership. No new account, role, permission or email-verification change was made. Normal sign-in and App Check token handling remained on the existing Firebase SDK paths.

The target was pinned to the same previously authorized existing Member fixture used in the earlier API matrix. Target UID SHA-256: `5c4e91f25957c2fccd05c2200d80922f85e0d34d74662e7dd6eedf929a489b4f`. This is not the real Member session retained on the phone. No directory search/list was offered or used by the scoped view.

## Actual result

The existing **Verify current membership** button was invoked **once**. The local transport allowed only:

```text
verifyMemberMembershipCommand
{ schemaVersion: 1, organizationId: "gainpath", memberId: <pinned fixture UID> }
```

Every other Function, target, extra field or schema/organization value is rejected locally before transmission. The deployed command retains the authoritative role/Auth/App Check checks. There is no payment, account edit, reward fulfilment, policy publication or admission-record action in this view.

The browser showed:

- **Server result: verified**.
- **Verified membership: Free**.
- **General gym admission: Not included**.
- **Verified (local): 2026-10-24 08:36:01.110** (Malaysia time; server verification timestamp).
- No paid-validity line was displayed.

This is an actual successful Firebase callable result rendered through the existing typed verification panel. Raw HTTP/network response headers were not separately captured. The earlier genuine Member attempt to use this Admin endpoint returned `403 PERMISSION_DENIED`; that negative result and this positive result now cover both authorization paths. The successful request used enforced App Check with the existing registered web debug context; no registration or enforcement setting was created/changed.

Evidence:

- `build/module4/admin-positive-uat-result.json` — redacted result and bounded scope.
- `build/module4/private/admin-positive-membership-uat.png` — full observed browser result; includes the Admin's displayed email and remains private/local.
- `build/module4/admin-readonly-uat-build.json` — local build/target proof. Bundle SHA-256 `34ce196048e3a554f432c4b0f5b46e43be5ea8ad79d9e30803ee5613a06bc8a5`.
- `build/module4/private/admin-readonly-uat-build.log` — sanitized build log.

## Local preparation and checks

New local UAT entry point: `apps/admin_web/tool/membership_readonly_uat.dart`. It is not imported by the product entry point and was not included in a Hosting/APK/Functions deployment. `build/module4/prepare-admin-readonly-uat.cjs` strictly reuses the already registered App Check configuration and pins the existing fixture hash. `serve-admin-readonly-uat.cjs` serves this private build only on `127.0.0.1:7359` under `/membership-uat/`; the normal existing Admin login stays at the same origin.

Local build succeeded, targeted Dart analysis reports **no issues**, and the existing verification-panel test passed (**1 test**). Two initial style-only analyzer notices were corrected; rebuilding produced the same compiled bundle hash. No package/dependency upgrade or product behavior change was needed. The new view is a local test harness, not a new product dashboard or CRUD interface.

## Unchanged boundaries and remaining gates

No membership/catalogue/promo/policy/account writes, payments, refunds, reward/booking/workout/chat mutations, Calendar/Gmail actions, Functions/Rules/indexes/Hosting deployment, billing/scaling changes or APK installation occurred during this check. The phone's existing sign-in and installed APK were untouched. Do not infer zero unrelated background activity project-wide; this records the bounded UAT actions.

The read-only cases requested for effective Free, active catalogue, trusted RM89/RM129 quotes, no Free payment/expiry, approved foundation versions/benefits, Member Dashboard, Member denial/Admin verification and App Check rejection are now evidenced. Unknown/suspended/unverified variants remain labelled local-regression-only or not exercised live, because no cloud state was manufactured. Unchanged adjacent-module evidence remains configuration/probe/regression evidence, not a new end-to-end Booking/AI/Google transaction.

**Next gate:** separately scoped Sandbox purchase/renewal acceptance, only after a concrete approved test plan naming the existing test account(s), allowed test payments and expected lifecycle changes. No such financial operation is authorized or initiated by completing this read-only check. Pending reward/voucher business policies and Stage B/C deployments remain separate, as do the Billplz HTTP 422 refund-transfer issue and historical overview scaling exception.
