# Module 9 — implementation and UAT boundary

19 October 2026, Asia/Kuala_Lumpur. Original sources: C3 Table 3.29, UC-9.1–UC-9.8, BR-12/BR-14/BR-15; C4 §4.7.9 and §4.8.9. The owner explicitly authorized starting Module 9 despite the previously pending Module 8/10 acceptance conditions. This is authorization to proceed, not a retroactive manual PASS.

**Deployment update:** the owner approved the exact two-function activation, completed and independently read back at 2026-10-19T06:55:52Z. The separately approved APK installation and launch also succeeded. Authenticated live save/reload and owner manual UAT remain pending.

## Coverage

| Requirement | Current result | Remaining gap |
|---|---|---|
| FR-9.1 | Partially blocked: existing authenticated booking reader reused; original roster/day rail/cards retained; client and status filters, 30-day date picker, reset, related client name projection and pagination. Opt-in names reader deployed. | Manual UAT. Refresh is periodic (30 seconds on the first page), not a Firestore live listener. Additional loaded pages require explicit refresh. No confirmed booking producer exists. |
| FR-9.2 | Unavailable; original form-history action retained disabled. | Requires an authorized confirmed relationship, consent and measured cloud history. Local device workout records are never uploaded by this module. |
| FR-9.3 | Partially blocked: participant-only booking questions/replies, ordered immutable history, pagination, confirmed save/reopen, stable uncertain-send retry, inbox previews and session/discard protection implemented; callable deployed. | Authorized live save/reload and manual UAT. Notification delivery is not implemented. |
| FR-9.4 | Unavailable; Coach cancellation action stays disabled. | B4 only cancels Member pending holds. There is no production settlement-to-confirmed workflow or established confirmed cancellation resolution/lock transition. Do not mutate pending holds into confirmed sessions or reuse Member cancellation as Coach cancellation. Future extension must enforce the original cancellation policy and release confirmed locks atomically. |
| FR-9.5 | Unavailable; live note/completion action stays disabled. The existing note outline contains only headings, never invented observations. | No authoritative confirmed/fulfilled session prerequisite or completion transition. Current booking reader only covers today forward. Notes cannot mark a pending/unpaid session completed. Consultation corrections need a legitimate authorized transition/history contract. |
| FR-9.6 | Unavailable; original Earnings/Performance cards/charts/navigation retained with hyphens, explanation and disabled export. | No authoritative cleared commission ledger, rating records/eligibility or verified export rows. Fees and pending holds never become earnings. |

The payment webhook source injects no supported verifier; payment ingress only acknowledges a durable received event and explicitly does not confirm settlement/entitlement. The workout submit callable's production enabled tuple list remains empty. Neither source is changed. No complete operational coverage is claimed for all six FRs.

## Data and security

- Existing `orgs/{org}/bookings/{booking}` documents and all allocation/cancellation/expiry logic remain unchanged.
- Private messages are immutable `bookings/{booking}/messages/{sequence}` documents. A private `communicationState/current` counter serializes ordering; existing organization `commandReceipts` provide payload-bound idempotency. Reads return 50 rows; a send returns at most 51. Older pages use an exclusive sequence cursor.
- The new App Check enforced callable `bookingCommunicationCommand` requires verified email, current canonical organization membership, booking participant ownership, supported role and current active branch access for Coaches. Admin/Staff have no messaging access. Members cannot impersonate Coaches. Read and write authorization run inside the same Firestore transaction.
- Only current pending holds and confirmed bookings accept new messages. Elapsed pending holds and closed bookings reject new sends; authorized participants retain history access. Exact retry can recover an earlier successful send after closure without another write.
- Messages never contain client-supplied author IDs/roles or timestamps. Private contact fields are not projected. No personal production account/booking is used for tests.
- `getBookingListCommand` adds optional `includeParticipantNames`. Only callers explicitly requesting it receive `memberDisplayName` from the related canonical organization membership. Existing strict clients retain their original response shape. New mobile builds request this extension and require its backend deployment before installation/UAT.
- Member and Coach use the same conversation presentation; the existing Member screen is a thin adapter. Original response-time widget remains and displays `-` when no authoritative value exists.

## Exact live inspection and deployment boundary

Read-only inventory at 2026-10-19T05:49:14Z: project `gainpath-0619`, region `us-central1`, 26 ACTIVE Node 22 functions; timezone Asia/Kuala_Lumpur. No payment webhook or messaging callable is deployed.

- Firestore Rules SHA256: `3b11087f0d21639249374ae17035fbc4d734a0827f1c7390acd118b0c486e2db`.
- Storage Rules SHA256: `50138b9c519882e03005c1f7f5821b306d9d35baf3aca701c716c1feb8b3fc8d`.
- Exact live Rules deny direct client access to message/state subcollections. No Rules, indexes, Storage, Hosting, IAM or Scheduler change is needed or authorized.
- Owner-approved selective deployment completed: **`bookingCommunicationCommand,getBookingListCommand`**. This adds private participant communication and opt-in related-client names. No blanket firebase.json deployment occurred.
- Sanitized read-only evidence and exact Rules are retained under ignored `build/non-core-crud-sprint/module-9-activation/`. Emulator success is not live Firebase save/reload proof.

## Focused verification

- 56 backend unit tests: booking communication + booking reader, including unchanged legacy response shape.
- 7 Firestore SDK emulator tests: participant authorization, concurrent duplicate send, message ordering/read-back, booking/slot-lock preservation and booking-read regressions.
- 1 exact-live Firestore Rules test: provisioned synthetic Member/Coach/Admin cannot directly read/write messages or sequence state.
- 21 focused Flutter tests: conversation previews, repeat-space names, uncertain-send identity, session loss, repository/cubit/composition and booking wire contracts.
- Production and test TypeScript typechecks; targeted Flutter analysis. No full CI repeated.
- Read-only independent review found three UI defects, all corrected and re-reviewed. Existing unrelated owner changes are excluded from Module 9 commits. The relevant pre-existing `coachId` route binding is retained as part of the Coach roster integration.

## Consolidated manual UAT (after approved backend activation and APK installation)

1. Coach: open My schedule; compare real client/date/time/duration/status with Member and Admin booking views. Search client, choose date, switch day-strip, filter supported statuses and reset. Load additional pages when offered. Confirm pending holds remain clearly unpaid; refresh Member cancellation/expiry in Coach/Admin without changing any confirmed state manually.
2. With explicitly authorized disposable booking participants only: Member sends a preparation question; close/reopen; Coach inbox shows its actual preview, opens it and replies. Member reopens and reads the reply in the same booking. No general chat, fabricated response time or delivery notification is claimed.
3. Simulate a failed/uncertain send: text stays visible, Save/Send does not duplicate-submit, retry uses the same request, and reload shows exactly one saved message. Load earlier history where available; closed bookings preserve read access but cannot accept new messages.
4. Sign out or switch accounts while a thread is open/loading: prior protected data disappears and no delayed result restores it. Unrelated Coach/Member and Admin/Staff cannot access private conversations. Verify the existing Module 8 profile/certification and Module 10 availability routes still open in the integrated build.
5. Confirm form-history/cancellation/completion remain unavailable with truthful explanations until real prerequisites exist. Performance widgets remain present with `-`; financial export is disabled. No pending/unpaid booking can become Completed, and no fee is represented as commission.

No live disposable fixture write, canonical account mutation, push or owner Module 9 PASS has occurred in this sprint. The separately approved APK installation is recorded below.

## Local commits and Android artifact

- Backend/domain/contracts: `667484e`.
- Shared mobile integration: `9490b2b`.
- APK: `build/module-9/gainpath-module9-firebase-debug.apk`, debug, Firebase, App Check debug; package `com.zyang.gainpath`, version `0.1.0`/code `1`.
- SHA256: `b1f03021e2f4df9ef32e8beda645d5f7cf77f6350e76ee6e77cdeb155d64fe5b`; 219,484,947 bytes.
- APK signature verifies and matches the retained Module 10 APK previously installed on Xiaomi. The approved installation also verified it against the actual installed APK before updating.
- The artifact includes the preserved existing availability working-tree edits as requested for an integrated build; those unrelated edits remain outside the Module 9 commits. This is not a clean-HEAD-only APK.
- Final Android debug build and Functions build/import check succeeded. Local Functions build used Node 24 and emitted the existing package engine warning; deployment target remains Node 22. No full CI or live backend success is claimed.
- The two-function activation prerequisite is satisfied. The owner separately approved APK installation; the in-place update completed without uninstalling or clearing data.

## Approved production read-back

- `bookingCommunicationCommand`: ACTIVE, Node 22, revision `bookingcommunicationcommand-00001-fuf`.
- `getBookingListCommand`: ACTIVE, Node 22, revision `getbookinglistcommand-00002-xig`.
- 27 live functions; every unrelated function revision remains unchanged. Exact Firestore/Storage Rules hashes remain unchanged from preflight.
- Both live callable endpoints return HTTP 401 / UNAUTHENTICATED to anonymous probes. This verifies the negative authentication boundary, not authenticated message persistence or full App Check UAT.
- Deployment CLI exited successfully. It reported a build-image cleanup warning; no images were deleted or unrelated redeployment attempted.
- Sanitized evidence: ignored `module-9-activation/predeploy-check.json` and `deployment-readback.json`. No canonical or disposable booking records were written for verification.

## Approved Xiaomi installation

19 October 2026, Asia/Kuala_Lumpur: installed and launched the approved SHA256 `b1f03021…` APK on Xiaomi `23013RK75C`. The existing APK and 98,808,832 bytes of private data were backed up first. The signing certificate matched the actual installed APK; installed APK hash matches the approved artifact. Private data was byte-identical immediately after the in-place update and before launch. No uninstall or app-data clear occurred.

Ignored evidence: `build/non-core-crud-sprint/module-9-activation/install-result.json`; private backups: `module-9-activation/private/install-module9/`. Successful installation/launch is not owner manual UI PASS or authenticated Firebase messaging save/reload proof.
