# Admin Coach Directory and Profile Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Admin coach discovery, information accuracy and publication review usability.

**Status:** Saved at owner request on 8 November 2026. Deferred; no implementation requested. The owner's immediate inspection request concerns the MOBILE MEMBER coach list and profile instead. Do not confuse this Admin plan with the mobile review.

**Architecture:** Preserve Flutter, the existing purple design system, canonical/FYP source isolation and authorized server reads. Reuse the actual UnifiedAdminCoachDirectory composition and existing profile/certification workflows. Introduce additional data only through authorized contracts.

**Tech Stack:** Flutter/Dart, Firebase Auth/App Check/Firestore/Functions.

**Spec:** Admin inspection and proposed design in this chat, summarized below; final layout and implementation scope require owner selection before execution.

## Design and approaches

Recommended: improve existing compact coach cards and use a complete coach profile as the main destination. Keep a quick-view dialog only if it adds useful information. Alternative: desktop table for comparing a larger roster, with mobile cards; defer this added complexity until needed. The owner requested saving the proposal, not implementing or selecting every detail.

List: compact square avatar, name, specialty once, actual specialization tags, branch labels, publication/verification status, consistent rating and review count, fee, one primary Open profile action. Show Review changes only when relevant. One record per coach rather than repeated branch groups.

Profile: compact identity/status/rating header; bookings, schedule and member preview near the top; Overview, Profile changes, Certifications, Reviews (authorized data required) and Profile history. Clearly distinguish published and draft content. Emphasize blockers/next action; retain technical details collapsed.

## Global constraints

- Preserve unrelated dirty work, existing artifacts, member data and permissions.
- No fabricated ratings, session counts, durations, response times or verification.
- Keep existing/FYP authorization and read-only restrictions separate.
- Do not expand account provisioning, review access or audit claims without supported contracts.
- No application changes or deployment as part of saving this plan.

## Review focus

- Long names/tags, narrow windows and enlarged text must not overflow.
- Unrated, unpublished and inactive coaches must have truthful distinct states.
- Pending draft content must not be described as published member content.
- Mixed-source pagination/counts must preserve order, scope and access.
- Keyboard focus, disabled actions and destructive-action placement must be understandable.

## Task 1: Correct information and responsive list behavior

**Files:** apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart; relevant coach directory/widget tests.

- [ ] Add regression cases for long labels, narrow widths, unrated preview and actual saved specialization tags.
- [ ] Confirm failing behavior; fix card sizing, remove 5.0 fallback from quick-view, use actual tags and consistent rating/count formatting.
- [ ] Replace inferred tags and duplicate specialty chips; preserve self-reported experience qualifiers where needed.
- [ ] Replace decorative pagination and separate draft/public load controls with one honest navigation model; counts remain loaded counts unless server totals exist.
- [ ] Run affected tests/analysis and inspect normal/large-text renders.

## Task 2: Simplify list actions and filters

**Files:** coaches_screen.dart; coach_directory_admin_cubit.dart; unified_admin_directories.dart only if query contracts require changes; corresponding tests.

- [ ] Pin behavior for data-derived filters, clear filters, ordering and retained search/scroll on returning from profile.
- [ ] Implement clear reset labeling, useful sorting and one primary profile action; make pending review contextual.
- [ ] Hide unsupported Add Coach or provide an accurate onboarding explanation.
- [ ] Avoid duplicate coach cards across branches; verify mixed-source pagination and current-session guards.

## Task 3: Consolidate profile and review workflow

**Files:** coaches_screen.dart; profile domain/read adapters only when necessary; coach_directory_publication_flow_test.dart and relevant certification/discard tests.

- [ ] Test published-versus-draft labeling, missing data, eligibility blockers and action state.
- [ ] Add consistent rating/count header; move bookings/schedule to prominent secondary actions.
- [ ] Reduce repeated identity/eligibility copy; collapse raw IDs/revisions and replace BR-5 jargon with plain wording.
- [ ] Place publication action contextually and deactivation in a secondary action area; retain existing guards.
- [ ] Rename timestamp-derived Activity to Profile history. Do not imply a complete audit trail.
- [ ] Scope member preview explicitly to published fields.

## Task 4: Optional authorized data and final acceptance

- [ ] Separately assess authorized review-detail reads and genuine audit event data; do not invent these from aggregates/current timestamps.
- [ ] Test keyboard navigation, focus return, responsive layout, long content, empty/error/loading states and enlarged text.
- [ ] Complete focused tests, analysis, build and scoped review before activation under applicable standing authorization.
- [ ] Preserve previous bundle, verify served assets and conduct signed-in ordinary Admin acceptance.

## Current inspection evidence

Live Admin at localhost:7360 showed card overflow when tags wrap; quick-view fee truncation and missing review count; full review header exposes coach ID; overview prefers draft while claiming member-visible content. Source confirms inferred tags, fixed specialty filters, reset icon mismatch, disabled live Add Coach, decorative pagination and timestamp-derived history. The verified rating fix remains separate and active; Jackson showed 4.0 (1 review).
