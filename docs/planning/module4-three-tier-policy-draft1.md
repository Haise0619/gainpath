# GainPath — Three-Tier Membership Policy & Implementation Roadmap

**Version:** Draft 1.0\
**Module:** Module 4 — Membership and Payment\
**Related Modules:** 2, 3, 5, 6, 7, 11, 12\
**Firebase Project:** `gainpath-0619`\
**Organization:** `gainpath`\
**Status:** Business Design Proposal — No Implementation Authorization

## 1. Membership Strategy

GainPath adopts a three-tier membership model:

| Tier | Positioning | Proposed Price | Duration |
|---|---|---|---|
| Free | Free digital fitness access | RM0 | No expiry |
| Basic | Full Gym Membership | RM49 | 30 days |
| Premium | Enhanced Gym Membership | RM89 | 30 days |

All pricing and duration values remain subject to separate business approval.

Membership applies across GainPath branches. It is independent of the Firebase user role: a Member account may have an effective Free, Basic or Premium entitlement, while Coach/Admin permissions remain separately controlled.

## 2. Official Proposed Feature Matrix

Legend: ✓ = included; — = not included; Paid = separate Coach Booking payment.

### 2.1 Physical Gym and Membership

| Feature | Free | Basic | Premium |
|---|---|---|---|
| Register and log in | ✓ | ✓ | ✓ |
| Membership dashboard | ✓ | ✓ | ✓ |
| General fitness centre entry | — | ✓ | ✓ |
| Access to all participating GainPath branches | — | ✓ | ✓ |
| Staff membership verification | Free status | Active verification | Active verification |
| Membership renewal | Upgrade | Manual | Manual |
| Membership invoices | N/A | ✓ | ✓ |
| Refund request for eligible paid membership | N/A | ✓ | ✓ |

Gym entry is a business entitlement verified by authorized staff. No QR scanner, turnstile or automatic physical access control is included in this initial scope.

### 2.2 Module 2 — AI Workout

| Feature | Free | Basic | Premium |
|---|---|---|---|
| Basic AI workout exercises | Unlimited | Unlimited | Unlimited |
| Full supported exercise catalogue | — | ✓ | ✓ |
| Real-time pose detection | ✓ | ✓ | ✓ |
| Posture correction | ✓ | ✓ | ✓ |
| Voice corrective feedback | ✓ | ✓ | ✓ |
| Equipment scanner and tutorials | ✓ | ✓ | ✓ |
| Full workout history | Limited view | ✓ | ✓ |

The actual Free exercise list must be determined using supported exercise identifiers, not invented names or unavailable exercises.

**Safety rule:** All available exercises retain their complete pose-correction and safety feedback. Membership restrictions must not disable corrective guidance during a workout.

No change to the frozen pose-analysis implementation is authorized by this policy.

### 2.3 Module 5 — Progress and Analytics

| Feature | Free | Basic | Premium |
|---|---|---|---|
| Personal progress summary | ✓ | ✓ | ✓ |
| Basic charts and statistics | ✓ | ✓ | ✓ |
| Full workout performance history | — | ✓ | ✓ |
| Deep-Dive Analytics | — | — | ✓ |
| Advanced performance trends | — | — | ✓ |
| Goal Progress Comparison | — | — | ✓ |

Advanced reporting must use real existing session data. Historical data must remain stored when membership expires or is downgraded, even if access to premium visualizations is reduced.

### 2.4 Module 3 — Gamification and Rewards

| Feature | Free | Basic | Premium |
|---|---|---|---|
| Mini-games | ✓ | ✓ | ✓ |
| Daily rewards and streaks | ✓ | ✓ | ✓ |
| Achievements and badges | ✓ | ✓ | ✓ |
| Leaderboards | ✓ | ✓ | ✓ |
| Earn points | 1.0× | 1.0× | 1.5× |
| Redeem standard reward items | — | ✓ | ✓ |
| Redeem Premium-exclusive items | — | — | ✓ |

Free members can accumulate points but cannot redeem physical reward items until upgrading to a paid tier. Their earned balances remain preserved.

The Premium 1.5× multiplier applies to specifically eligible server-verified point-awarding events. It is not a blanket multiplier on existing balances or point redemptions.

### 2.5 Module 6 — AI Fitness Chatbot

| Feature | Free | Basic | Premium |
|---|---|---|---|
| General fitness advice | ✓ | ✓ | ✓ |
| Coach discovery | ✓ | ✓ | ✓ |
| Workout recommendations | ✓ | ✓ | ✓ |
| Booking review assistance | ✓ | ✓ | ✓ |

Initial recommendation: maintain the same existing chatbot capabilities for all three tiers. Additional usage quotas or premium-only AI tools are deferred until costs and implementation are independently evaluated.

### 2.6 Module 7 — Coach Booking

| Feature | Free | Basic | Premium |
|---|---|---|---|
| Browse professional coaches | ✓ | ✓ | ✓ |
| View real coach availability | ✓ | ✓ | ✓ |
| Book and pay for sessions | Paid | Paid | Paid |
| Reschedule/cancel eligible bookings | ✓ | ✓ | ✓ |
| Automatic Calendar/Gmail notification | Existing policy | Existing policy | Existing policy |
| Premium Coach Discount Voucher | — | — | 1 per 30-day entitlement cycle |
| Voucher discount | — | — | 10%, capped at RM15 |

Coaching sessions are not included free in any membership plan. Membership discounts must not bypass Billplz settlement, booking capacity, refunds or Admin financial controls.

## 3. Membership Lifecycle Rules

### 3.1 Free Membership

1. Eligible verified Member accounts without active paid membership receive effective Free entitlements.
2. Free does not require a Billplz transaction and does not expire.
3. Free is not stored as an artificial zero-MYR paid checkout.
4. Account suspension, role authorization, email verification and organization membership checks still apply.

### 3.2 Basic and Premium Activation

1. Paid membership becomes active only following independent server-verified payment clearance.
2. Paid membership expiry is calculated using trusted server timestamps.
3. A proposed 30-day term means 30 × 24 hours, not a calendar month.
4. Same-tier early renewal preserves the remaining paid period.
5. Duplicate webhooks or payment callbacks cannot activate or extend membership twice.
6. Automatic recurring billing is unavailable; renewal remains manual.

### 3.3 Membership Expiry

Upon expiry, the member's **effective entitlement** becomes Free while the previous paid tier, expiry and financial history are retained.

Expiry must not delete workout data, reward balances, invoices or existing confirmed paid Coach Bookings.

### 3.4 Tier Changes

| Transition | Proposed behavior |
|---|---|
| Free → Basic | Paid purchase |
| Free → Premium | Paid purchase |
| Basic → Basic | Manual renewal |
| Premium → Premium | Manual renewal |
| Active Basic → Premium | Deferred until upgrade/proration policy |
| Active Premium → Basic | Deferred until downgrade policy |
| Expired paid tier → another tier | New paid purchase |

The initial implementation must not silently discard unused paid membership time.

## 4. Premium Reward Points Policy

Premium members receive 1.5× the normal points for eligible activities.

For an eligible event:

`awardedPoints = floor(basePoints × 1.5)`

Examples:

| Normal reward | Premium reward |
|---:|---:|
| 10 points | 15 points |
| 20 points | 30 points |
| 100 points | 150 points |

Additional rules:

- The multiplier is applied only by the trusted backend.
- The tier is verified against the event's eligible earning time, not a client-supplied claim.
- An event can be rewarded only once.
- Original point-earning limits and anti-abuse policies still apply.
- Downgrading does not remove previously earned points.
- No retroactive bonus is granted for activities performed before Premium activation.
- Premium-exclusive reward items require server-side redemption eligibility checks.

The precise eligible earning sources and any new reward caps require a separate configuration review.

## 5. Premium Coach Booking Voucher Policy

A Premium member is entitled to **one 10% Coach Booking discount voucher per earned 30-day Premium entitlement cycle**, with a maximum discount of RM15.

Examples:

| Original booking fee | Discount | Member pays |
|---:|---:|---:|
| RM50 | RM5 | RM45 |
| RM100 | RM10 | RM90 |
| RM200 | RM15 | RM185 |

Proposed protection rules:

1. The member must have an active, verified Premium entitlement when applying the voucher.
2. One voucher may discount one eligible Coach Booking only.
3. One voucher is issued per non-overlapping 30-day paid Premium period; early renewal must not grant an immediate extra voucher.
4. The voucher cannot be combined with another discount unless a separate stacking policy is approved.
5. Discount amounts are calculated in integer sen by the backend.
6. Voucher usage must be reserved atomically against the booking checkout.
7. Failed or abandoned checkout recovery must verify the provider outcome before releasing or reusing a voucher.
8. Concurrent checkouts cannot redeem the same voucher twice.
9. A successful discounted booking retains its approved price snapshot, even if membership later expires.
10. Cancellation, refund and voucher reinstatement require an explicit policy; automatic reinstatement is not assumed.

The Gym/Coach financial responsibility for discounts and the effect on coach commission must be approved before implementation.

## 6. Physical Fitness Centre Entry

For the initial release, authorized Gym staff manually verify membership in GainPath.

| Effective membership | General gym admission |
|---|---|
| Free | Not included |
| Basic Active | Included |
| Premium Active | Included |
| Expired paid membership | Not included |
| Suspended/deactivated account | Not permitted through membership verification |

The staff interface should display a server-verified effective tier, member identity, validity and expiry.

A screenshot, cached membership card or client-reported status must not be accepted as authoritative.

**Separate decision:** Free members with a paid Coach Booking may require appointment-specific admission. A paid coaching appointment must not automatically imply general gym-floor access.

No new entry tracking, attendance reward or gate hardware integration is required initially.

## 7. Current Implementation Gap Assessment

This is a preliminary assessment based on the existing Module 4 deployment report and known GainPath modules. Repository-level verification is still required.

| Area | Known baseline | Required work |
|---|---|---|
| Module 4 payment | Purchase/renewal backend deployed | Validate three-tier compatibility |
| Plan catalogue | No trusted catalogue published | Define final paid-plan configuration |
| Free membership | No Free paid-plan contract | Derive Free entitlements without billing |
| Member UI | Shared Membership UI implemented | Three-tier comparison and status presentation |
| Gym entry | No verified entry workflow established | Staff-only membership verification |
| AI workout | Existing workout and pose features | Safe exercise-catalogue entitlement gate |
| Reports | Dashboard/deep-dive concepts exist | Verify and enforce tier access |
| Reward points | Existing gamification model | Backend Premium multiplier |
| Reward catalogue | Existing reward redemption model | Tier-specific item eligibility |
| Coach booking | Paid Sandbox flow implemented | Voucher lifecycle, discount quotes and settlement |
| AI chatbot | Existing Gemini integration | Compatibility regression, not redesign |
| Admin payments/refunds | Existing Admin review integration | Verify tier displays and financial cases |
| Auto-renewal | Unsupported | Keep unavailable |
| Membership refund transfer | Blocked | Separate provider/entitlement resolution |

A `benefits` text array is not an authorization system. Enforcing these tiers requires trusted entitlement checks in the relevant backend and client entry points.

## 8. Proposed Delivery Phases

### Phase 0 — Business Design and Gap Audit

**Goal:** Finalize and validate the three-tier specification without modifying cloud resources.

- Compare the Feature Matrix against Chapter 3/4 requirements.
- Identify exact Flutter screens, repositories and backend entry points requiring changes.
- Inventory workout exercise IDs, report endpoints, points-award logic and Coach Booking pricing.
- Confirm the new Free status representation and expired-member behavior.
- Identify security, testing and migration impacts.

**Deliverable:** Traceable requirement-gap matrix, affected-file map and separate approval proposal.

### Phase 1 — Membership Foundation

**Goal:** Safely introduce the three effective tiers.

- Add a server-derived Free entitlement.
- Extend membership tier/domain models.
- Update shared membership comparison and dashboard screens.
- Implement consistent server-side entitlement resolution.
- Preserve all payment receipts and existing Membership billing logic.
- Test Free, paid, expired and suspended states.

**Gate:** Explicit implementation, deployment and catalogue approvals.

### Phase 2 — Gym Entry and Workout/Report Access

**Goal:** Apply meaningful tier differentiation without modifying pose safety algorithms.

- Read-only staff membership verification.
- Basic exercise catalogue entitlement.
- Full paid exercise catalogue.
- Deep-Dive Report and Goal Comparison enforcement.
- Preserve saved data and existing paid bookings.

**Gate:** Separate UI/backend security regression and Xiaomi UAT.

### Phase 3 — Gamification Benefits

**Goal:** Deliver verified Premium rewards.

- Backend 1.5× points multiplier.
- Tier-aware reward catalogue.
- Premium-exclusive redemption checks.
- Duplicate-event, downgrade and concurrency testing.

**Gate:** Points integrity and voucher/reward UAT.

### Phase 4 — Premium Coach Voucher

**Goal:** Deliver the discounted Coach Booking experience.

- Cycle-based voucher issuance.
- Trusted 10%-up-to-RM15 quote.
- Atomic voucher reservation and redemption.
- Payment, callback, cancellation and refund reconciliation.
- Booking, coach payment and Google Calendar/Gmail regression.

**Gate:** Explicit finance-rule and Sandbox UAT approval.

### Phase 5 — Final Integration and FYP Acceptance

**Goal:** Validate the complete product and align documentation.

- Three separate test accounts representing Free, Basic and Premium.
- Purchase, renewal, expiry and entitlement tests.
- Gym staff verification.
- AI Workout and advanced report checks.
- Premium points and rewards tests.
- Discounted Coach Booking and Billplz Sandbox payment.
- Financial history, invoices and refund-request verification.
- Updated use cases, class diagram, sequence diagrams and FYP test evidence.

## 9. Critical Approval Boundaries

This document approves no operational changes.

Do not:

- Modify application source code.
- Write or activate Firestore Membership Plans.
- Change prices or existing membership accounts.
- Deploy Functions, Hosting, Rules or indexes.
- Install an APK or trigger Sandbox payments.
- Change Coach Booking commissions, discounts or refunds.
- Modify Google Calendar/Gmail integrations.
- Change existing reward balances or workouts.
- Introduce automatic recurring payments.

Proceed only with read-only design review and gap analysis until separate authorization is given.

**Business status:** The three-tier product direction is selected. Detailed entitlements, pricing, implementation mechanisms and rollout remain subject to explicit approval.