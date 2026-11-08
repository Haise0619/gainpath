# Shared Member–Coach chat implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline; one final fresh-context review.

**Goal:** Replace per-booking chat interaction with an authorized ongoing pair conversation and pinned session context.
**Architecture:** Add a v2 branch to bookingCommunicationCommand. Dedicated transactional query adapter reads authorized pair bookings, federates immutable legacy history and persists new pair messages with idempotent receipts. Flutter uses typed v2 repository/pages, shared inbox and thread; legacy v1 history/accepted receipt reads remain compatible, while new sends require v2.
**Tech Stack:** Flutter/Dart, TypeScript, Firebase callable/Admin Firestore.
**Spec:** docs/superpowers/specs/2026-11-08-shared-coach-chat.md

## Constraints

Preserve unrelated work, App Check, current membership/organization/branch guards, server-owned eligibility and payment/booking records. 48-hour follow-up is measured from absolute endAt, not manual completion. No bulk migration. Pagination must not lose history. No invented read/delivery/response-time claims.

- [x] Task 1: Add backend pair policy, bounded transactional pair/inbox/timeline queries, idempotent sends and authorization; regression tests RED then GREEN. Keep v1 history/receipt compatibility; reject new v1 sends to prevent eligibility bypass. Verify read-only states, cross-booking continuity, boundary/time/branch/role/scope, receipts and legacy pagination.
- [x] Task 2: Add typed Dart v2 contracts/adapter and shared chat UI. Pinned current/next/follow-up session, read-only composer, independent loading/sending, stable merge, date dividers, safe retry, scroll behavior and counterpart identity. Tests RED then GREEN.
- [x] Task 3: Route Member/Coach messaging to shared inbox/thread, remove expired/pending entry, rename historical entry, preserve booking navigation. Group all loaded inbox pages by peer rather than booking/date. Add small/large-text fixture renders.
- [x] Task 4: Run affected mobile/backend/contracts/types/emulator checks; final scoped review, isolated APK/build/source validation, documentation and scoped commit. Deploy only reviewed matching backend with rollback/source verification under standing authorization if operational preconditions can be established; report actual device/release limits.

Review focus: transaction read-before-write, simultaneous booking revocation/send, account changes while requests pending, equal timestamp pagination, no mutation of legacy messages, uncertain retry after permission window closes.

Completion: 77 affected mobile, 34 backend/contract and 6 emulator tests pass; source/test types pass; scoped analysis has zero errors/warnings and eight baseline infos. Both source-only backend releases are source/config/IAM verified with rollback archives; APK source allowlist and lock match. Phone installation was skipped because the connected device exposes only its always-on lock screen. See the spec verification record and ignored build/pair-chat-20261108/ evidence.
