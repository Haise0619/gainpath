# Module 9 completion — 20 October 2026

## Implemented

- Member Home → **Coaching updates and privacy**: explicit posture-history grant/revoke, revision-safe saves, honest failure states, notification inbox with pagination, read state and booking navigation. Sharing is separate from workout-upload consent and defaults off.
- Coach posture reads require the booking relationship, current active Coach and Member membership, both branch assignments, an active branch, valid upload consent and the independent Member grant. Only accepted, scored workout summaries are returned; missing scores are omitted.
- Cancellation events have an explicit pending-delivery marker. A cursor-based scheduled sweep also handles older events missing that marker. Delivery is transactional and idempotent, uses the existing organization notification collection, and adds a bounded automated conversation notice.
- Booking and notification lists have Firestore live-change signals with fallback refresh. Conversation screens refresh every five seconds while current, without replacing pending send intent.
- Coach Performance uses server-authorized canonical bookings, actual reviews and verified cleared Sandbox payments for completed sessions with consultation notes. MYR calculations use integer minor units. The selected initial Sandbox agreement is **80% Coach / 20% platform**, version `sandbox-coach-80-v1`; per-booking earning snapshots prevent duplicate recognition. Refunded, unpaid and reconciliation cases do not contribute current earnings. No provider transfer is issued and calculated earnings are never called paid out.
- PDF export includes every completed session, with amounts to cents. Android's document picker lets the user choose the destination; native PdfDocument wraps text and creates multiple pages. Cancellation/failure does not show success.

## Verification

- 32 focused backend tests passed across Member controls/inbox, posture privacy, report authorization/calculations/refunds/idempotency, review submission, notifications and cancellation lock reuse.
- Nine focused Mobile UI tests passed; export captures all 25 supplied sessions, including entries beyond the former 20-session cap. Member UI covers grant, failed save and booking navigation.
- TypeScript source and test checks passed. Focused Flutter analysis has no errors/warnings; informational style lints remain. Architecture guard and diff whitespace check passed.
- Android Firebase debug APK compiled in both an isolated Module 9 snapshot and the actual workspace. The isolated compile snapshot used the stable equipment catalog at two pre-existing broken HEAD scanner-factory references. It was not installed.
- The actual workspace APK was installed in place on Xiaomi `xiaomi-device-serial-redacted` and launched. Signing certificate and installed APK hash matched. Existing private app data was backed up and the before/after archives were byte-identical. This APK includes the unrelated equipment work already present in the workspace; none of that work was discarded or committed by this task.
- APK: `build/module9-completion/gainpath-module9-firebase-debug.apk`, SHA256 `c68220e082bef3805106c6a4a46cf44ad048c881b27e362bcbe1095b2a9ba183`.
- Six Firebase functions are ACTIVE: `module9MemberCommandCallable`, `getCoachPerformanceCommand`, `getClientPostureHistoryCommand`, `submitBookingReviewCommand`, `deliverBookingNotifications`, `cancelAssignedBookingCommand`. Revision comparison confirms the other 36 existing functions were unchanged. Firestore Rules, Storage Rules, hosting and Billplz configuration were not deployed or changed.
- Added the posture query index without deleting or changing existing indexes. Check `build/module9-completion/posture-index.json` for current readiness.
- Ignored deployment/readback, source manifest and installer evidence are under `build/module9-completion/`. Private phone backups must not be committed or shared.

## Owner UAT — still required

1. Member → Home → **Coaching updates and privacy**. Sharing starts off. Turn it on, leave/reopen, verify it remains on; turn it off and verify Coach access is denied on a fresh read.
2. Coach → Roster: use a legitimate upcoming confirmed session to cancel with a reason. Verify the Member update appears within the worker sweep interval (normally about one minute for a small queue), opens bookings, and the released slot can be booked again. Do not cancel a real appointment solely to fabricate test evidence.
3. Coach → past session → publish multiline notes; Member reads them and submits one review. Coach Performance should show the real review. Repeated submission must not create duplicate reviews.
4. Coach → Performance: verify 80/20 amounts against an existing cleared Sandbox transaction and completed/noted booking. Pending, refunded and review cases must contribute no current earnings. Payout status remains unavailable because Module 9 does not transfer money.
5. Export the statement, choose a folder in Android's picker, then open the saved PDF in a reader. Verify the last session and totals; cancelling the picker must not claim success.
6. Log out/switch accounts while a Module 9 screen is open; previous-account data/actions must become unavailable.

Physical model activation remains blocked by the existing real-device validation gate. Production's enabled workout tuples stay unchanged. No synthetic workout or financial records were written for UAT. Cloud deployment and app launch are verified; owner acceptance and physical-model validation are not claimed.

## Integration state

All changes remain reviewable in the current working tree. No force-push, reset, branch overwrite, main merge or automatic payout was performed. Preserve the unrelated dirty equipment changes and historical documents. A source-only main integration must also resolve the pre-existing HEAD equipment factory dependency; the current working tree already supplies that separate work.

Firebase CLI reported successful deployment plus its existing build-image cleanup warning. No images were deleted automatically.

Privacy note: Personal and live fixture identifiers are redacted; exact originals remain in private local evidence.
