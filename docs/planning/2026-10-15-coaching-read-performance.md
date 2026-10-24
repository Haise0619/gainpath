# Bounded coaching save/load performance repair

User request: saves and retrieval feel slow after the successful live Availability CRUD smoke. Baseline source588c7ab; existing live integration evidence remains in the [execution report](../architecture/2026-10-15-firebase-demo-execution.md).

## Diagnosis and scope

Cloud Run HTTP durations from genuine owner requests: Availability save12.917–17.237s (n4), load3.468–7.183s (n10), Member options15.124–17.832s (n6), hold create17.186–17.833s (n2). These include server request handling, not device/network/UI timing. Cold-start contribution is not isolated. Database is asia-southeast1; current Functions remain us-central1. Region migration is outside this patch.

Both saveCoachAvailabilityDayService and bookingDaySnapshot await one transaction read per UTC half-hour slot (normally48, DST46/50). Weekly availability also awaits each date separately. Smallest repair: optional transaction getAll port, native Firestore transaction.getAll implementation, bounded grouped reads of exactly the same day/lock documents. Existing single-get adapters remain compatible through a concurrent fallback. Do not cache authorization, skip any lock, reduce checks, change timestamps, alter receipt/retry rules or remove the post-save authoritative refresh.

## Execution steps and acceptance

1. Add focused RED regressions for native batch ordering/missing documents/empty input and for the availability/booking paths reading all expected locks in one group, with malformed locks still denied. Existing security/concurrency suites remain authoritative.
2. Extend only functions/src/platform/firestore/store.ts and firestore-store.ts; reuse that optional operation from coach-availability-service.ts and booking-validation.ts. Preserve every validation branch and transaction boundary. Batch seven requested day records; batch the entire date grid for lock checks. No Rules/schema/client/pose/workout changes.
3. Run backend full tests/build/typecheck and focused Java21 Firestore emulator CRUD/concurrency/lifecycle suites, architecture and maintained analysis. Verify adapter RPC group count deterministically; emulator speed is not live latency evidence.
4. Review exact diff and preservation snapshot, locally commit only this bounded repair and this plan. Stop for source/deployment review before pushing or redeploying changed security-sensitive business commands. Proposed subsequent selective deployment: getCoachAvailabilityCommand, saveCoachAvailabilityDayCommand, getMemberBookingOptionsCommand, createBookingHold, after exact-head CI. No Scheduler/Rules/index deployment required.

Proposed acceptance: one native transaction batch per date's full lock set; same returned options, rejection semantics, receipts, booking accounting and one-winner contention outcomes. Live performance improvement is **unmeasured until the reviewed patch is deployed and owner trials repeat**. Proposed warm save/options server-duration target under5s is a target, not an achieved result. Remaining profile/list latency, cold starts, phone RTT and region placement require separate evidence if still material after this fix.

## Source verification at commit time

- Four focused regressions failed before the patch and passed afterwards. All307 backend tests/16files, build and test typecheck pass (local Node24; deployment runtime remains22).
- Java21 isolated Firestore emulator: availability4/4, booking readers5/5 pass. Lifecycle2/3 initially passed; the existing concurrent expiry test returned INVALID_ARGUMENT/Transaction is invalid or closed, with emulator lock-timeout logs. One isolated unchanged lifecycle rerun passed3/3. No test skip or application retry workaround; retain both logs and this intermittent limitation.
- Architecture boundaries OK; maintained-source analysis reports no issues. Flutter source/build inputs are unchanged; new Flutter tests/builds were not repeated for this backend-only patch. Previous exact-head CI at588c7ab remains green and does not cover this later patch.
- Independent read-only reviewer found no Critical/Important issue. Installed Firestore7.11.6 getAll preserves input ordering, missing-document positions, transactional locking and read-before-write rules. Existing single-get adapters retain compatibility via concurrent fallback.
- No live writes, deployment, region move, Rules/index edit, APK rebuild or pose/workout change was made for this optimization. Source changes are four runtime files plus one focused test file and this plan; keep them separate from the completed live integration artifact.

## Subsequent delivery and live evidence

After independent review, current optimization/integration authorization was used to fast-forward push6dd91d90980dcd351b9f3aec297f0e885aa60b30 and complete [exact-head CI](https://github.com/Haise0619/gainpath/actions/runs/38666339474). All307 backend unit/61 emulator tests, Flutter/package/tooling suites, architecture/analysis and both mock app builds passed. Only the four listed Functions were then updated; other ten revisions/config update times, protected records and existing client APK were preserved. No new region, IAM policy, Rules/index/Scheduler release or warm-instance billing setting.

Live owner edit/restore succeeded (availability revisions5/6) and owner reports faster saves. New server save durations2.174–4.960s (n2), versus12.917–17.237s (n4) before. Availability reads2.116–4.866s (n4, first post-release read4.866s) versus3.468–7.183s (n10). New Member options call8.324s (n1), versus15.124–17.832s (n6); owner reports a small improvement, permitted times load. New hold creation was not repeated live. These are nonrandom Cloud Run HTTP durations, not client roundtrip/P95 or cold-start-isolated measurements. The under5s target is met only by these Availability samples; it is not achieved for the first Member-options sample. Remaining sequential authorization work and region separation warrant a later measured pass if needed; no authorization cache or speculative region migration was added. Full revisions, evidence boundaries and rollback are in the [execution report](../architecture/2026-10-15-firebase-demo-execution.md).
