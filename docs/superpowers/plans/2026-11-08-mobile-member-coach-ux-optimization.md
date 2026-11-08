# Mobile Member Coach Discovery and Profile Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Help members compare coaches, understand trust/price information and reach the existing booking flow with fewer distractions.

**Status:** Owner approved complete implementation on 8 November 2026. Member UI and focused checks implemented; see docs/ux/mobile-member-coach-ux-implementation.md for fresh evidence and explicit device/deferred-data limits. Admin plan remains deferred.

**Architecture:** Retain the existing Flutter coach directory/profile composition, actual published profiles and authorized rating aggregate. Use present data truthfully and hide unsupported metrics. Preserve booking, cancellation, payment, verification and session guards.

**Tech Stack:** Flutter/Dart; existing gainpath_ui components; Firebase-backed directory and booking repositories.

**Spec:** Member-focused findings and proposed design below. Layout approved by the owner's complete implementation request.

## Findings

- BrowseCoachesScreen already has search across names/specialties/tags, data-derived specialty chips, rating/price/experience sorts and My bookings.
- CoachCard shows avatar, verification icon, specialty, two actual tags, rating/count and fee. It omits branch and uses a fixed row for rating/count/fee, creating a narrow-width/large-text risk (not visually reproduced).
- Price sorting treats missing fees as zero, putting unavailable prices ahead of actual low prices. Unknown experience also becomes zero.
- Filtering/sorting only uses loaded pages. Load more appears above the results. Live filtered-empty copy always says no coaches available rather than distinguishing no matches; initial loading can also show the empty state.
- Live CoachProfileScreen has repeated name/review count, a tall centered hero, Sessions run '-', response-time panel '-', duration '-', and What members say '-' because publishedCoachPresentation always supplies no testimonial details.
- Header says '1 reviews' without singular handling. Missing fee/biography use dashes.
- Actual specializations and biography exist. Verified status is an icon without explanatory credential details. Branch display uses IDs rather than human-readable venue information.
- View schedule and Book a session sit after all content, outside a persistent bottom action area. No profile-level unavailable-fee explanation accompanies the booking action.

## Recommended design

Keep purple branding and the existing vertical list. Cards prioritize photo/name, specialty, explanatory verification, rating with explicit review count, branch and price. Avoid repeating specialty as an identical tag. Use wraps or separate rows for long values.

Profile: compact identity header; rating/count; actual experience when provided; specialties; readable biography; session price/location; clear verification meaning. Remove unsupported session count/response time/duration panels rather than adding data calls merely to fill them. Use a safe-area bottom bar for real price and the existing booking action; retain schedule as secondary. Review details and next available slot are optional later features requiring authorized reads, not assumed existing data.

## Global constraints

- Preserve published-only discovery, canonical/FYP scope and account isolation.
- No invented availability, online status, session totals, response speed, duration or credential claims.
- Do not reveal private certificate files, reviewer identities or contact details.
- Existing booking options remain authoritative for duration, availability, eligibility and payable price.
- No new messaging, favorites or recommendation feature in the initial cleanup.
- Source findings are not physical-device visual acceptance.

## Review focus

- Long names/tags, narrow screens and enlarged text must remain legible without clipped price/actions.
- Unrated differs from failed rating load; missing fee is not a free session.
- No matches differs from no published coaches, initial loading and read failure.
- Local sorts must disclose loaded scope or use a separately designed server query.
- Bottom CTA respects safe areas, screen-reader focus and existing booking eligibility.

## Task 1: Truthful profile information

**Files:** apps/mobile/lib/features/coaching/presentation/shared/coach_profile_screen.dart; published_coach_presentation.dart; apps/mobile/test/coach_directory_flow_test.dart; coach_rating_card_test.dart.

- [x] Pin missing-metric, one-review, unrated, missing-price and empty-biography behavior in focused tests.
- [x] Hide unsupported Sessions run/response-time/duration UI; remove duplicate review metric; use clear empty copy.
- [x] Label verification according to approved-certification semantics; do not imply endorsement or guaranteed results.
- [x] Run affected tests and scoped analysis.

## Task 2: Improve member comparison and discovery

**Files:** apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart; member/widgets/coach_card.dart; application/coach_directory_cubit.dart if needed; related directory tests.

- [x] Pin price sort with null/zero fee, stable ties, loading/error/no-match states and large text.
- [x] Sort unavailable prices after real prices; handle unknown experience explicitly.
- [x] Add branch information using current data, clarify review-count wording and make fee layout flexible.
- [x] Show active sorting/filter context and Clear filters; retain existing useful search and My bookings.
- [x] Move Load more below results; make loaded-page scope clear. Defer global server filtering unless needed.
- [x] Verify return navigation retains list state.

## Task 3: Improve profile hierarchy and booking access

**Files:** coach_profile_screen.dart; live_coach_directory_views.dart; app/di/coach_profile_factory.dart only if callback wiring changes; related booking/profile UI tests.

- [x] Test sticky bottom CTA at narrow widths, large text, safe area and missing fee.
- [x] Compact header; put meaningful facts near top; keep About and all actual specializations readable.
- [x] Add bottom price/Book a session bar and secondary schedule action, preserving existing booking validation.
- [x] Explain unavailable booking prerequisites accurately rather than inventing new restrictions.

## Task 4: Optional richer information and acceptance

- [x] Assess privacy-safe authorized review-detail reads; until supported do not show an empty testimonials placeholder beneath a nonzero aggregate.
- [x] Assess branch-name mapping and verified public credential summaries; do not expose private certificates.
- [x] Assess next availability: deferred; no new reads or fabricated slot labels. Existing schedule/booking options remain authoritative.
- [x] Render normal/large-text light/dark states; verify contrast, semantics, focus, scrolling and unknown/loading/error states.
- [x] Run affected tests, analysis, build and scoped review. Follow standing installation rules only when implementing, preserving prior APK/data and avoiding active workouts.
- [x] Record the actual-phone acceptance checklist; physical acceptance deferred and not claimed. Widget renders inspected; no installation performed.
