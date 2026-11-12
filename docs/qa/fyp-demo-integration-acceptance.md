# FYP demo integration acceptance

Date: 12 November 2026. Baseline: `7e80aee`, including the Coach clean-build fix `8b6b20c`. Final application/test-routing source: `11e4e65`.

## Acceptance decision

**The requested membership, rewards/check-in, Coach booking and financial operations pass the local fixture/emulator acceptance gates, and both applications build from committed source.** Two confirmed integration defects were fixed. This is not a claim of live provider, deployed multi-client or physical-device acceptance. The complete repository backend suite is still not green because four legacy evidence/package test files depend on ignored historical build artifacts. Exact failures are recorded below.

All work used synthetic accounts, local service fixtures and demo-only Firestore projects. Billplz stays Sandbox. No production service was deployed, APK installed, real financial operation executed or real user data changed. Existing unrelated dirty tracked files were fingerprinted before work and confirmed byte-for-byte unchanged afterward. Unrelated untracked Coach, home and workout work was preserved.

## Confirmed bugs and commits

| Commit | Confirmed defect | Resolution and regression |
| --- | --- | --- |
| `0404c32` | `PaymentsScreen.initialBookingId` could not open linked financial detail: `_load` invoked `_open` while `_loading` remained true, so its guard returned immediately. | Finish the queue loading state when the page arrives, then start the guarded detail read. Regression failed before the change and passed afterward. Detail reads still increment the generation synchronously; stale page cleanup cannot clear the newer detail loading state. Existing mounted, session, organization and generation checks remain. |
| `11e4e65` | The default emulator registry assigned fixed-port FYP/cohort/audit tests to legacy core, whose ports and services do not satisfy those tests. | Register the five existing externally orchestrated tests as standalone, preserving all guards and exact-once classification. Seven harness regressions pass. These standalone suites require their reviewed Auth/Functions/Firestore preparation and were not represented as executed. |

Independent read-only review found no remaining important issue in these two changes. The new financial screenshot test also received a brace-style-only correction after the application build; its 21 cases were rerun successfully with scoped analysis clean. No application source changed in that correction.

## Functional acceptance matrix

| Area | Verified behavior and evidence |
| --- | --- |
| Free entitlements | Digital fitness remains available, check-in can issue base points, earned points remain available; paid booking/gym/Mini Game/physical reward actions do not gain authorization. Unknown paid status fails closed. Entitlement, capability, check-in and reward service tests cover these boundaries. |
| Basic / Premium | Active Basic permits paid booking and regular rewards. Premium permits exclusive rewards only when points, stock, publication and revision checks also pass. Bonus/discount behavior remains configuration-controlled; no live benefit or inventory was activated. |
| Purchase and renewal | Server pricing and supported plan IDs remain authoritative. Same-tier renewal is available anytime; `max(clearanceTime, previousExpiry) + 30 × 24h` preserves unused time. Tests cover immediately after activation, 20/13/1 days early, exact expiry, expired renewal, delayed clearance, duplicate callback, pending recovery and unsupported active-tier conversion. Membership changes do not reset wallet balances; points remain maintained by the separate trusted reward ledger. |
| Payment safety | Pending/initiated payment does not authorize access. Browser return cannot settle payment. Provider verification/signature, bill/amount/reference matching, account ownership, stale session rejection and idempotency remain tested. Paid-but-unfulfilled payment is shown for review, without inventing activation or booking confirmation. |
| Daily check-in | Real Firestore contention issues one receipt and one shared-balance credit for concurrent retries. Direct receipt/balance/profile writes are denied. Premium configuration and receipt tests run without enabling held bonuses. |
| Reward catalog | Admin create/edit/filter and existing `premiumOnly` compatibility pass. Published eligibility changes affect future redemption; existing vouchers retain their terms. Free/Basic/unknown restrictions and Premium qualification are checked server-side, not only by disabled buttons. |
| Redemption integrity | Real Firestore retries award duplicates once and allocate the final stock unit to one owner. Points deduction, stock, revision and retry identity remain protected; failed attempts do not create a fictitious voucher. |
| Booking create | Authoritative create gate requires verified active Basic/Premium; current availability, Coach eligibility and slot locks are checked. Existing committed booking receipts intentionally remain recoverable after paid membership expiry. New booking eligibility and historical receipt access remain distinct. |
| Booking payment/cancellation | Hold → verified payment → confirmation, expired hold/late payment reconciliation, cancellation/replacement allocation, history refresh and payment recovery are covered. Cancellation/expiry does not imply that a payment was refunded. |
| Refunds and synchronization | Admin approval remains a review decision; provider order completion is separate. Concurrent synthetic refund execution reserves one order and preserves the expired booking state. Member/Admin read tests consume persisted booking/payment facts; this proves local server/read-model consistency, not real simultaneous browser/device synchronization. |
| Admin operations | Transactions, Refund Requests and Reconciliation retain distinct filters, payment/refund/fulfilment labels, loaded-page metric scope and detail cross-links. Sidebar/sub-tab synchronization, stale-session denial, duplicate-action protection, required reasons, uncertain refund recovery and repository organization isolation pass. |
| UI navigation/states | Member purchase/renewal/reward/check-in/booking flows and Admin shell/financial detail/catalog loading, empty and error cases pass focused Flutter tests. Review navigation from `8b6b20c` remains included in the committed clean source. |

## Exact verification results

Counts below overlap and must not be summed as distinct tests.

| Check | Exact observed result |
| --- | --- |
| Demo-scope Backend | **466 passed, 33 files**. Selected membership, booking, Billplz, check-in, verified/Premium/points-only rewards, reward catalog/direct-save/journey and emulator registry tests. |
| Full Backend on final committed source | **2,087 passed, 3 failed tests; 169 passed / 4 failed files**. Two of the failed files fail during loading, in addition to the three failed test cases. Details below; full-suite exit was 1. |
| TypeScript source and test compilation | Both `tsc --noEmit` and `tsc -p tsconfig.test.json --noEmit` exited 0 on final committed source. |
| Shared Domain | **192 passed**, complete package suite from isolated committed baseline; Domain source was not changed by this task. |
| Member acceptance on final committed source | **161 passed**, 28 files covering membership repositories/UI/gates, check-in, rewards/receipts, booking repositories/payment/cancellation/history and live composition. |
| Admin acceptance on final committed source | **85 passed**, 10 files covering financial UI/repository/renders, shell, shared people, booking list, membership verification and reward management/repository/catalog. |
| Additional Admin reward render mode | **30 passed**, including four viewport cases and normal reward management/repository/catalog coverage. |
| Financial focused validation | **41 passed**: 10 presentation, 10 repository, 21 actual render cases. Final style-only screenshot test rerun: **21 passed**, scoped analysis: **no issues**. |
| Member membership and eligibility renders | **24 passed** viewport/text-scale cases. The conditionally disabled check-in render was initially skipped; it was then explicitly enabled and **1 passed**, generating 42 screenshots. |
| Booking history/detail/Coach renders | **4 passed**, generating 12 screenshots. |
| Firestore cross-module integration | **26 passed, 7 files**, using local loopback port 56182 and demo projects. |
| Dedicated check-in Firestore integration | **4 passed**, using its guarded `127.0.0.1:18087` and `demo-gainpath-checkin`. |
| Full Member static analysis | **0 errors, 0 warnings**, 37 existing informational style lints; `--no-fatal-infos` exited 0. |
| Full Admin static analysis | **0 errors, 0 warnings**, initially 29 informational style lints. One was in the new render test and was corrected; scoped final analysis has no issues. The other 28 are existing lints. |
| Android Debug | **Passed**, arm64, clean committed application source `11e4e65`. Existing Java deprecated-API notice remains. |
| Admin Web Release | **Passed**, clean committed application source `11e4e65`; Wasm dry run passed. Existing CupertinoIcons font warning remains. |

Firestore coverage by file: membership payment **5**, verified rewards **2**, booking payment **4**, booking lifecycle **3**, booking reads **5**, Member booking changes **4**, Coach directory **3**, check-in **4**. Expected `PERMISSION_DENIED` logs belong to assertions denying unauthorized access.

### Full Backend failures retained transparently

The initial baseline full run had 2,085 passing / 4 failing test cases across five failing files. The registry fix removes its confirmed failure and adds a regression. The final full run still has these four evidence-dependent files:

1. `test/fyp-live-executor.test.ts`: loading fails because `build/fyp-cohort-integration/proposed-source-records.json` is absent from a Git export.
2. `test/fyp-live-package.test.ts`: loading fails because the historical `build/fyp-live-20261104/registration-ready/lib/modules/identity/member-provisioning.js` package is absent.
3. `test/recommendation-assessment-import-cli.test.ts`: two cases fail because historical `build/module13-batch-b` evidence is absent; the missing evidence is encountered before the second case reaches its expected validation error.
4. `test/recommendation-independent-evaluation-generator.test.ts`: one case fails on the same absent historical recommendation evidence.

No historical evidence or assessor judgments were fabricated, copied into source, or silently skipped to make this suite green. These test-packaging prerequisites require separate offline preparation or a reviewed self-contained fixture change. The requested demo modules' 466-test gate passes. The local Node version was **24.19.0**, while Functions declares **Node 22**; provider/runtime release acceptance should also be repeated under the declared runtime. No production-runtime claim is made from this local run.

## Actual Flutter screenshot inspection

All images use synthetic fixture data. Offline harnesses use local Arial and/or bundled Barlow in place of unavailable runtime fonts; production theme/assets are unchanged. These are Flutter widget renders, not authenticated browser screenshots or physical-device captures. Images and logs remain ignored local build evidence.

| Set | Sizes/states | Generated evidence |
| --- | --- | --- |
| Membership | 320×760, 360×800, 390×844, 844×390; 100/150/200% text; Free/Basic/Premium/expired/unknown, renewal, quote, recovery, payment, billing, refund | **276 PNGs** |
| Reward eligibility | Same 12 viewport/text combinations; Free, regular, Basic locked, Premium, insufficient points, out of stock, unknown and retry | **96 PNGs** |
| Rewards/check-in | Three portrait widths with three text scales; landscape 200%, loading/error/empty/claimed, with scrolled top/middle/bottom | **42 PNGs** |
| Admin catalog | 768/1024/1280/1440, mixed catalog, Premium filter, exclusive edit and create | **16 PNGs** |
| Admin finance | 390/768/1440, Transactions/Refund Requests/Reconciliation/details/loading/error/empty | **21 PNGs** |
| Booking | 320/360, 100/200% text, history/detail/Coach | **12 PNGs** |

The finance reviewer opened all 21 finance images. Representative Member, booking and reward images were opened and inspected; not every generated image received individual visual review. No new confirmed overflow or broken label was found in those inspected renders. Phone finance navigation scrolls horizontally; long Member content remains vertically scrollable. Tests also exercise 320px/200% booking layouts and enlarged Admin reward forms.

Representative inspected evidence:

- [Basic renewal: preserved expiry and provisional estimate](../../build/fyp-demo-acceptance-20261112/source/build/membership-renewal-premium-rewards-20261112/membership/360x800-1.0-renew-basic.png)
- [Basic locked Premium reward](../../build/fyp-demo-acceptance-20261112/source/build/membership-renewal-premium-rewards-20261112/member-rewards/360x800-1.0-basic-locked.png)
- [Check-in at 320px / 200%](../../build/fyp-demo-acceptance-20261112/source/build/fyp-acceptance-rewards/320-200-top.png)
- [Phone financial detail: separate payment, fulfilment and refund states](../../build/fyp-demo-acceptance-20261112/source/build/acceptance/admin-finance/390-details.png)
- [Desktop refund queue](../../build/fyp-demo-acceptance-20261112/source/build/acceptance/admin-finance/1440-refunds.png)
- [Booking detail at 320px / 200%](../../build/fyp-demo-acceptance-20261112/source/build/booking-history-coach-fix-20261108/renders/details-320-2x.png)

## Clean-source procedure and artifacts

Initial testing used `git archive 7e80aee` under `build/fyp-demo-acceptance-20261112/source`. After both fixes were committed, a fresh `git archive 11e4e65` was extracted into `build/fyp-demo-acceptance-20261112/clean-11e4e65`. Flutter package configuration and installed dependency caches, Android SDK location and a Functions dependency junction were reused. Application source was exclusively from the specified Git revision, with no dirty Coach/home/workout files. The final screenshot-test brace correction was tested separately and changes no application/build source.

Commands were run from the relevant package directory:

```text
functions: node_modules/.bin/vitest run
functions: node_modules/.bin/tsc --noEmit
functions: node_modules/.bin/tsc -p tsconfig.test.json --noEmit
packages/gainpath_domain: dart test
apps/mobile and apps/admin_web: flutter test --no-pub <acceptance test files>
apps/mobile and apps/admin_web: flutter analyze --no-pub --no-fatal-infos
apps/mobile: flutter build apk --debug --no-pub --target-platform android-arm64
apps/admin_web: flutter build web --release --no-pub
```

The 33-file backend selection matches test basenames beginning with `membership`, `booking`, `billplz`, `coach-booking`, `member-booking`, `verified-rewards`, `premium-reward`, `points-only`, `reward-(catalog|direct-save|journey)`, `app-check-in`, `daily-check`, `check-in`, or `emulator-suites`.

Firestore execution used `firebase emulators:exec --project demo-gainpath --only firestore` with an isolated local config that references the checked-in Rules/indexes and invokes the seven named files with `vitest.emulator.config.ts`; file parallelism is disabled. The separate check-in run uses its required dedicated port/project. The newly classified standalone FYP/audit suites were not executed by these commands.

- [Android Debug APK](../../build/fyp-demo-acceptance-20261112/clean-11e4e65/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk)
  - SHA-256: `3325db8730e6e8509f1f64f182d27cba1ab26faf58703a68e21c9760e20dfbd2`
- [Admin Web Release output](../../build/fyp-demo-acceptance-20261112/clean-11e4e65/apps/admin_web/build/web/index.html)
- [Final complete Backend log](../../build/fyp-demo-acceptance-20261112/clean-11e4e65/backend-full.log)
- [Member acceptance log](../../build/fyp-demo-acceptance-20261112/clean-11e4e65/mobile-acceptance.log)
- [Admin acceptance log](../../build/fyp-demo-acceptance-20261112/clean-11e4e65/admin-acceptance.log)
- [Cross-module Firestore log](../../build/fyp-demo-acceptance-20261112/source/emulator-integration.log)
- [Check-in Firestore log](../../build/fyp-demo-acceptance-20261112/source/emulator-checkin.log)

## Remaining acceptance work

- Authenticated real-device Member and browser Admin walkthrough, simultaneous clients, session expiry/account changes, and actual deployed App Check/network behavior.
- Billplz Sandbox hosted checkout, signed external callback ingress/browser return, recovery after app interruption, provider reconciliation and Payment Order refund completion. Local gateways are synthetic; they do not prove provider credentials, dashboard configuration or money movement.
- Android receipt/PDF save/open, TalkBack/accessibility focus and production font loading. No APK was installed during this task.
- Repeat runtime/provider release checks under Node 22 and prepare or repair the four legacy offline evidence/package test prerequisites before claiming a completely green repository-wide backend gate.

No further confirmed defect in the requested demo module scope remains from this local acceptance pass. These outstanding device/provider and test-packaging conditions prevent an unconditional claim that every FYP runtime path has been accepted end to end.
