# Membership Commercial Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or executing-plans. Preserve unrelated dirty work; commit only owned files.

**Goal:** Implement the user-approved commercial membership matrix while preserving all free digital fitness and historical records.

**Architecture:** Reuse current Firebase commerce, effective entitlement, reward wallet and Flutter design system. Central capability policy authorizes new paid actions; no new digital paywalls. Keep unknown paid states closed, histories independently authorized.

**Tech Stack:** Flutter/Dart, Firebase Functions TypeScript, Firestore, Vitest, Flutter tests.

**Spec:** User attachment `C:/Users/Ngzhe/.codex/attachments/120e0d8d-2510-4e39-92d8-d0f1c8a92ec0/Pasted text.txt`.

## Constraints

Sandbox only; no deployment, provider operations, real data writes or phone installation. Free full digital fitness; Basic RM89 and Premium RM129 per exactly 30 days. No recurring billing or active tier conversion. Premium bonus and coach discount configuration remain disabled without approved values. Preserve wallet, commitments and history at expiry. Existing unrelated working changes remain intact.

## Tasks

- [x] Phase 1: Shared supported-plan and capability contract in membership domain and commerce backend; regression for Free/Basic/Premium/expired/unknown and no digital paywalls.
- [x] Phase 2: Check-in configured Premium bonus, regular/premiumOnly reward authorization and Free wallet UX; deterministic issuance and retention tests.
- [x] Phase 3: Paid coach discovery/new booking and Mini Game boundaries, gym verification; existing management/history preserved; negative and expiry regressions.
- [x] Phase 4: Fresh lifecycle/session authorization across commerce commands; supported plans before charging; classified quote failures and safe checkout recovery. Retain settlement idempotency and renewal arithmetic.
- [x] Phase 5: Membership overview, comparison, checkout, results, billing/refund UX using purple member theme, Malaysia timestamps, actual support navigation, readable Sandbox notice. Capture baseline and final screenshots.
- [x] Phase 6: Focused integration/emulator regression, scoped analysis, Android Debug build, clean-source checks and documentation. Full backend suite limits and live acceptance are documented in `docs/ux/membership-commercial-entitlements-optimization.md`.

## Review focus

Old-session alternate command paths; quote rejection versus uncertain bill creation; expiry during paid actions; histories after expiry/unknown; duplicate base/bonus/redemption writes. Test these at each owning phase.

## Execution ledger

Ruling: Reuse current checkout and narrowly stage owned files, because existing uncommitted consumer UI work is the required visual reference. Do not reset/stash unrelated changes.
Ruling: User explicitly requests implementation without another approval or plan-only stop; supplied matrix is the approved design.
