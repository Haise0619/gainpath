# Shared Member–Coach conversation design

Owner approved the preceding chat proposal on 8 November 2026 and requested implementation.

One organization-scoped member/coach pair has one conversation. Confirmed future/current bookings allow sending; a confirmed/completed session allows follow-up until exactly endAt + 48 hours. Pending-only, expired and cancelled sessions do not grant sending. Existing participant and current Coach branch authorization remain mandatory. Historical conversation remains readable to currently authorized participants. Expired bookings do not offer a chat entry; closed successful bookings offer View conversation.

Pinned responsive context card selects current confirmed session, then nearest future confirmed session, then latest eligible follow-up. Read-only mode explains the reason. Both roles use the same thread UI; inbox groups by counterpart, independent of the booking screen's current date range. Current styling is retained. Background loading never locks typing/back. Timeline merges stable message identities, retains older pages and scroll anchor, supports dates/new-message affordances and explicit retry.

Additive schema-v2 callable requests coexist with v1 historical reads and exact accepted-send reconciliation. New v1 sends require an app update so they cannot bypass the relationship policy. New pair messages persist separately; legacy messages are federated read-only with original booking context, without destructive migration. Queries and authorization execute transactionally; scans/pages are bounded and honest about pagination. No financial or booking state changes. Final affected tests, fixture renders, scoped review, isolated APK and release evidence are required.


## Verification and release record

Implemented shared pair identity, current/next/follow-up header, read-only composer, grouped inbox with new-message unread counters, historical booking source labels, independent background refresh, safe retry and gap-preserving pagination. Pending/expired/cancelled booking detail entries are suppressed; successful historical entries read View conversation. Member Coaches has a Messages entry.

77 affected mobile tests across 14 files,34 backend/contract tests and 6 emulator checks pass. Source/test TypeScript checks pass. Scoped Dart analysis has zero errors/warnings and 8 unchanged style infos. 16 shared-chat fixture renders cover both roles, inbox and read-only mode at 320/360px and 100%/200% text. They are fixture renders, not real-account screenshots. Final source/package review has no actionable findings.

The isolated Android debug APK excludes unrelated Admin/workout changes and preserves the dependency lock. Artifact: build/pair-chat-20261108/gainpath-shared-chat-debug.apk. The authorized Xiaomi is connected but on its always-on lock screen; no idle/unsaved-activity assurance is available, so no installation or launch was performed. Physical two-account acceptance remains pending.

Source-only Asia bookingCommunicationCommand v2 deployment is hash/config/IAM verified; 72 unrelated Functions and Rules/indexes are preserved. The minimal v1 history/reconciliation guard update is also deployed and hash/config/IAM verified; new v1 sends cannot bypass the new policy. Both previous source archives and configuration baselines are retained. No production booking, payment, attendance or message records were rewritten. Evidence: build/pair-chat-20261108/release/ and release-v1-guard/.

## Operational limits

The legacy history federation fails closed above 100 bookings per pair instead of silently dropping sessions; larger archives need an indexed history adapter. Inbox scans 50 booking documents per page and visibly offers more pages, deduplicating counterparts across pages. Unread counts cover new pair messages; no invented unread count is assigned to historical legacy messages. Conversation refresh polls every 5 seconds only while foreground/current; background push delivery is not part of this change. Existing server-marked Coach cancellation notices are rendered as system notices; other historical text keeps its original attribution.
