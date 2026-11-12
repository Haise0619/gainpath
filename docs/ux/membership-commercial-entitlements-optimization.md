# GainPath commercial membership implementation

12 November 2026 · Local candidate · Asia/Kuala_Lumpur

| Capability | Free | Active Basic | Active Premium |
| --- | --- | --- | --- |
| AI rep counting, voice feedback, supported form estimates, timed and manual workouts | Included | Included | Included |
| Exercise catalog and tutorials, training programs, history, progress, reports, PDF, consented cloud sync | Included | Included | Included |
| Daily check-in, base points, wallet, points history | Included | Included | Included |
| Gym admission eligibility, paid Mini Games, Coach discovery and new bookings | — | Included | Included |
| Regular physical rewards | — | Points and stock required | Points and stock required |
| Premium-exclusive physical rewards | — | — | Explicitly classified and published items only, with points and stock required |
| Extra check-in points and Coach discount | — | — | Server configuration required. No values activated in this change. |
| Price and term | RM0, no paid expiry | RM89 per 30 × 24 hours | RM129 per 30 × 24 hours |

The existing identity, organization, ownership and consent checks apply throughout. The membership resolver separates the organization role from the effective paid tier. Expiry returns the effective tier to Free and retains historical evidence. Unknown evidence denies paid entry while digital fitness, wallets, histories and existing commitments remain available under their own authorization. Cached membership data cannot authorize paid actions.

## Entitlement boundaries

- Coach discovery lists require active paid entitlement through Firestore Rules, including the cohort list path. An individually published Coach profile remains readable where the existing Rules allow it, so booking history can resolve its Coach. New booking options and hold creation require paid entitlement. The existing reschedule, cancellation, refund and history paths retain their independent checks.
- The paid Mini Game catalog and gameplay routes verify membership before entry. The round service verifies paid entitlement for new server rounds. Existing game scoring and reward issuance follow their own policies. Device-only gameplay is gated by the Flutter route. There is no server-side verification of physical movement in this change.
- Admin membership verification provides the gym admission decision for active Basic and Premium. It does not operate a door, QR scanner or attendance system. Daily app check-in is separate from gym admission.
- A paid renewal or purchase leaves the points wallet intact. The Free reward shop displays the actual balance and an Explore membership link. New redemptions validate the effective tier, stock, points and item revision in the same transaction. The points-only catalog accepts the existing `premiumOnly` eligibility field and retains it on legacy edits. Previously issued vouchers remain independently readable.

## Configurable Premium benefits

The server reads `orgs/{org}/settings/premiumCheckInBonus`. A valid policy requires `schemaVersion: 1`, the matching `organizationId`, `enabled: true`, a version, positive integer `bonusPoints`, and an effective interval in milliseconds. Missing or invalid configuration leaves the base 50 points in effect. A new Malaysia-day claim checks Premium at its authoritative server timestamp and records base points, bonus points and policy version on the same immutable receipt. The wallet credit and receipt share a transaction. A replay cannot top up a prior base-only claim. Points history and leaderboard readers accept the verified receipt total.

The Coach voucher policy uses `orgs/{org}/settings/premiumCoachVoucher` with explicit basis points, cap in sen, eligible Coach IDs, branches and session durations, policy version and finance approval. The existing one voucher per verified paid 30-day cycle, nonstacking, gym funding, gross fee commission basis, no reinstatement after refund and provider-confirmed unpaid recovery remain in the contract. The quote and reservation bind the server price. Settlement rechecks active Premium and sends a cleared payment to review if the member is no longer eligible. No bonus amount, discount terms, new inventory or activation was supplied for production.

## Sandbox checkout and consumer UI

New quotes, purchases and activation recognize Basic and Premium with the 30-day term. An unsupported historical payment can still be viewed and requires review before activation. Commerce commands enforce the existing lifecycle session cutoff. Recovery verifies ownership even if an inconsistent pending pointer references another account. Verified reauthentication can recover the same bill. Changed prices, expired promo quotes and invalid promos return explicit pre-reservation rejections. An ambiguous checkout keeps its original request ID and recovery route.

Billplz Sandbox, signed callback verification, provider reconciliation and idempotent settlement stay in use. Same-tier early renewal preserves the remaining paid time. A browser return does not activate membership. Recurring billing and direct active-tier conversion remain unavailable.

The overview puts verified tier, MYT expiry and the relevant purchase, renewal or verification action first. Plan comparison separates the Free digital features from paid gym features. Checkout shows server base price, promotion, discount and final amount. Payment results separate verification, activation and manual review, with a copyable reference under details. Payment assistance provides the gym administrator route and reference. Billing shows plain purchase and renewal labels. Refunds show the precise seven-day deadline and explain eligibility before opening the form. Admin approval is a review decision and does not send funds or alter the paid expiry.

## Visual evidence

All final images use local Flutter widgets and synthetic transactions. The screenshot harness covers 320, 360 and 390 dp portrait and 844 × 390 dp landscape at 100%, 150% and 200% text sizes with reduced motion. There are 216 renders covering membership states, both paid plan cards, checkout with and without promo, changed quote, payment results, billing, refund and reward eligibility. Representative images were visually inspected. Live TalkBack, real-device layout and authenticated provider UAT remain pending.

| View | Before | After |
| --- | --- | --- |
| Membership overview | [Prior phone capture](../../build/module4/phone-membership-dashboard.png) | [Free overview](../../build/membership-commercial-20261112/renders/360x800-1.0-free.png) |
| Plan comparison | [Prior phone capture](../../build/module4/phone-membership-plans.png) | [Comparison](../../build/membership-commercial-20261112/renders/360x800-1.0-plans.png), [Premium card](../../build/membership-commercial-20261112/renders/360x800-1.0-premium-plan.png) |
| Checkout and activation | — | [Changed quote](../../build/membership-commercial-20261112/renders/360x800-1.0-price-changed.png), [Activated](../../build/membership-commercial-20261112/renders/360x800-1.0-activated.png) |
| Rewards and refund | — | [Free points](../../build/membership-commercial-20261112/renders/360x800-1.0-free-rewards.png), [Refund at 200%](../../build/membership-commercial-20261112/renders/320x760-2.0-refund.png) |

## Verification and release limits

- 390 focused Functions tests, 192 Domain tests, and 8 isolated Firestore emulator tests passed. The emulators covered Coach list eligibility, pending checkout contention, promo capacity, same-tier renewal and denial of financial writes or cross-account reads.
- The complete backend run passed 2,093 tests with two failures. The FYP cohort suite still has a fixed-port registry mismatch, which reproduces on the pre-change revision. The FYP release package test requires Node 22 and the run used Node 24. See `build/membership-commercial-20261112/backend-full.log`.
- The exact application source exported from `896a211` passed 164 focused backend and 39 Flutter regressions using installed dependency caches. The visual harness passed 12 additional device and text-scale cases. TypeScript source and test checks passed. Scoped Dart analysis reported zero errors and warnings, with three brace style suggestions.
- The arm64 Android Debug APK built from the same clean export. [APK](../../build/membership-commercial-20261112/clean-896a211/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk)
  - SHA-256 `33105d8e5d58139424b8ec3ba58e4862a8147b4a91df9693034c174ade028947`
- Provider checkout on a real device, Android invoice save/open, live TalkBack, and production Firebase deployment remain separate acceptance steps. Local tests used fixtures and the Firestore emulator. Billplz remains in Sandbox and Premium bonus, discount and exclusive inventory require approved live values and activation.

## Implementation commits

| Commit | Scope |
| --- | --- |
| `f2ea1ca` | Commerce session freshness and supported plan registry |
| `b221a6b` | Unified capabilities and shared digital access |
| `cc7c36a` | Free points, Premium check-in configuration and reward eligibility |
| `e13402a` | Coach and Mini Game entry, discount settlement and Rules |
| `fea4c1c` | Checkout ownership and expired offer handling |
| `2a504ee` | Membership, plans, billing, refund and checkout UI |
| `896a211` | UI navigation and responsive verification |
