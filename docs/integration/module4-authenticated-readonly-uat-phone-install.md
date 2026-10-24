# Membership read-only UAT and Xiaomi APK installation

23 October 2026 · Project `gainpath-0619` · Organization `gainpath`.

The owner authorized proceeding through installation of the new APK on the phone. The Firebase APK was installed and launched successfully; **13 authenticated read-only API checks passed** on 23 October. The real phone Member's Membership Dashboard and Browse plans were subsequently observed and passed the stated display checks. **The pending Admin-positive case subsequently passed on 24 October**, recorded in `module4-admin-readonly-uat-2026-10-24.md`; the total is 14 authenticated read-only cases across the two runs, not financial acceptance.

## Phone installation — completed

- One authorized connected Xiaomi-family device, model **23013RK75C**. GainPath was already installed and signed in as the existing Member. Before stopping the app, the observed screen was idle Profile, not a workout or checkout.
- Exact prepared artifact: `build/module4/gainpath-three-tier-remaining-firebase-debug.apk`, package `com.zyang.gainpath`, version `0.1.0+1`, minimum SDK 26, target SDK 36. This is the Firebase/debug-App-Check build; access enforcement remains disabled by default. No new cloud release was bundled.
- SHA-256: **`fc1b1cf3bd34815bb8546cf5732e9ad8dd42dd08cbfa1b3b1041a050d8019034`**.
- Signing certificate SHA-256: **`38154139b51d8bbfed38fe1d673d2fbdaafb8ee5e3f8e60abb1fab95ef9f7450`**. APK Signature Scheme v2 verification passed and the installed old APK has the same signing identity.
- Preserved the prior installed APK and private app-data snapshot in the ignored local directory `build/module4/private/phone-install-20261023/`. The private snapshot was 99,529,216 bytes; it may contain session/personal data and is not shareable test evidence.
- Used **`adb install -r`**, without uninstall or data clearing. Compared the private archives before and after installation while the app was stopped: **byte-identical**.
- Pulled the installed APK after the update and verified its SHA-256 matches the prepared artifact. Android reported `lastUpdateTime=2026-10-23 22:36:13`.
- Launched GainPath successfully at approximately 22:36 Malaysia time. The existing Member session was preserved and the Home screen rendered. No logout, sign-in replacement or profile edit was performed on the phone.

Machine-readable evidence: `build/module4/phone-install-result.json`. Screenshots: `phone-before.png` and `phone-after-install.png`. Keep screenshots local; they may show the real Member identity. Installation rollback binaries/data are local recovery material, not an executed rollback or permission to restore/clear data.

## Authenticated API UAT — 13 PASS

The test harness reused a **previously authorized existing verified Member fixture** from the earlier Module 1/7 test infrastructure. It signed into that existing account normally, required `email_verified:true`, and the deployed overview/access resolver revalidated current identity and organization authority. No new account was created, verified, reactivated or assigned a role.

This harness account is **different from the real Member still signed in on the phone**. The redacted UID SHA-256 is `5c4e91f25957c2fccd05c2200d80922f85e0d34d74662e7dd6eedf929a489b4f`. Existing fixture credentials stayed private; ID/App Check tokens were held only in process memory and were not logged or written by the harness. Installation backups separately preserve app-private session data as described above.

App Check used the phone's existing, unexpired cached token from its already configured app context. No debug token was registered/exchanged or enforcement changed. Positive calls and paired negative probes validate actual server rejection, not merely local token shape. The harness allowed only `getMembershipOverviewCommand`, `getMembershipQuoteCommand`, `getMembershipAccessCommand` and `verifyMemberMembershipCommand`; it made **13 calls total**.

| Case | Observed result |
|---|---|
| Effective Free + active catalogue | 200; `resolved/free`, no paid tier/expiry, zero existing Membership transactions, two active plans, `autoRenewSupported:false` |
| Basic trusted quote | 200; **8900 sen, MYR, 30 days**, `basic-three-tier-uat-v1` |
| Premium trusted quote | 200; **12900 sen, MYR, 30 days**, `premium-three-tier-uat-v1` |
| Free as a paid plan | 400 `FAILED_PRECONDITION`; no artificial Free checkout |
| Client price override | 400 `INVALID_ARGUMENT` |
| Member invoking Admin verification | 403 `PERMISSION_DENIED`; no target entitlement/identity returned |
| Caller-selected Member field on overview | 400 `INVALID_ARGUMENT`; caller cannot choose another identity through this DTO |
| Wrong organization | 403 `PERMISSION_DENIED` |
| Valid Auth, missing App Check | 401 `UNAUTHENTICATED` |
| Valid Auth, invalid App Check | 401 `UNAUTHENTICATED` |
| Valid App Check, missing Auth | 401 `UNAUTHENTICATED` |
| Report access compatibility | 200; `decision:'legacy'`, `reason:'policy_not_enforced'` for `goal_comparison` |
| Final owner-scoped snapshot | 200; account, catalogue, Membership history and nonvolatile entitlement facts unchanged |

The catalogue comparison included both full approved benefit arrays, names, currencies, terms and versions from activation readback. Both quotes returned only quote information, with no transaction ID, bill ID or checkout URL. No promo was used. A Free entitlement existed without paid facts or any Membership transaction.

Evidence: `build/module4/authenticated-readonly-uat-result.json`; bounded harness: `membership-readonly-uat.cjs`. No payment-status reader was called, because those commands can reconcile and mutate financial state.

## Adjacent-module configuration — unchanged, bounded evidence

Fresh read-only metadata/configuration checks confirmed:

- All **57 Functions** retain the same revisions/update times as the verified Stage A release; no Function was deployed by this run.
- Rules releases, all seven indexes and Hosting metadata remain unchanged.
- `orgs/gainpath/membershipPolicies/access`, `settings/premiumCoachVoucher` and `rewardPolicies/current` are absent. No new access restriction, reward economy or voucher finance policy was enabled.
- `verifiedRewardsCommand` remains undeployed. The Stage C financial/voucher implementation remains outside the deployed financial handlers.
- The actual read-only report gate returns legacy access; the installed APK retains `MEMBERSHIP_ACCESS_ENFORCEMENT=false`.

Evidence: `build/module4/phone-uat-readonly-metadata.json`. This supports no new Membership restriction/configuration change to Workout, Reports, Rewards, Booking, AI or Google integration. It is **not** a claim that a new workout, paid booking, AI conversation or Calendar/Gmail delivery was executed successfully. Those actions were deliberately not invoked.

## Pending or blocked coverage

| Area | Status / reason |
|---|---|
| New APK installation and launch | **PASS**, package/signature/hash/data/session verified |
| Read-only Member APIs, catalogue, quotes, isolation/App Check | **13 PASS** with the existing verified fixture |
| Real phone Member's Membership Dashboard | **PASS — observed after owner navigation at 22:51 Malaysia time.** Screenshot `build/module4/phone-membership-dashboard.png` shows `CURRENT PLAN · ALL BRANCHES`, Free, `No expiry · No membership charge`, automatic renewal unavailable/manual renewal wording, existing digital-access permissions and `No membership payments yet.` No offline/cached/unavailable banner is visible. This is the real existing phone Member, separately from the fixture used for API tests |
| Browse plans on the phone | **PASS — observed after owner navigation at 22:53 Malaysia time.** Screenshot `build/module4/phone-membership-plans.png` shows the Basic card (identified by `Choose Basic`) at **RM89.00 / 30 days**, Premium at **RM129.00 / 30 days**, and all five approved foundation benefits on both cards. The Basic title is above the viewport, but its price, complete benefits and named button are visible. No plan selection or checkout occurred. Xiaomi remote taps remain denied by `INJECT_EVENTS`; no device security setting was changed or bypassed |
| Admin-positive verification of M1 | **PASS on 24 October after owner sign-in with the existing Admin account.** The server returned verified Free, general gym admission not included, and fresh verification time 08:36:01.110 Malaysia time. See `module4-admin-readonly-uat-2026-10-24.md`. No account or role was created/elevated; the earlier ordinary Member denial remains separate evidence |
| Naturally occurring unknown/unverified/suspended cases | **NOT EXERCISED LIVE**. No cloud records/verification/lifecycle were changed to manufacture them. Earlier focused local tests remain separate evidence |
| Operational cross-module and financial UAT | **OUT OF SCOPE / NOT PERFORMED** |

No Member account/subscription, catalogue, promo or policy writes; no payment/refund/provider-payment calls; no new test accounts; no booking/reward/workout/chat/Calendar/Gmail mutations. Normal sign-in/session metadata for the existing API fixture is the only authentication lifecycle activity, and it did not replace the phone's Member session. No billing, scaling, Rules, index, Functions or Hosting changes occurred. The prior overview maximum-instance exception and Billplz HTTP 422 refund-transfer issue remain separate.

**Read-only closeout:** the Admin-positive case has now passed, alongside the earlier Member Dashboard/plan-list and API observations. Payment, renewal, refund and account changes still require a separately approved concrete Sandbox financial-UAT scope. No additional deployment follows automatically from read-only acceptance.

**Minor UI observation, not changed during read-only UAT:** the `Billplz Sandbox · Test payments only` line above the purple card has low text/background contrast on this device. The main Free/status/manual-renewal text is readable; improving this label is a future local UI correction, not a reason to create a payment or change provider mode.
