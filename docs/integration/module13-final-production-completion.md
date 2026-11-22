# Module 13 — Production notification, presentation and outreach completion

2026-11-18. Owner-authorized minimum source deployment completed. No new Gemini inference, production Generate/Send, Rules/IAM/Secret/Billing change, deletion, training/Consent modification or Computer Use. Existing dedicated TEST and already-sent Jackson recommendation were reused.

## 1. Actual Notification Center root cause and live result

The original canonical recommendation, delivery receipt and Inbox document all existed. Real TEST-authenticated `module9MemberCommandCallable` returned HTTP 400 / INVALID_ARGUMENT / `Unexpected backup fields.` The deployed notification entrypoint bundled an older canonical recommendation decoder which did not recognize the `admin_outreach` source / `outreach` fields. The service also processed the whole page in one failure path; the incompatible record hid other notices. This was a server deployment compatibility defect, not a missing notification write or a Firestore Rules denial.

Updated that existing entrypoint's decoder/runtime and isolated invalid same-owner records/projections. Cross-owner rows and authorization failures remain denied. Client page parsing also isolates FormatException records; pagination cursor and typed recommendation references are preserved. No second notification system or fallback private-message exposure was introduced.

**Post-deployment real HTTPS check: HTTP 200, 6 notices, exact original Jackson Outreach ID present.** Its typed notice opens the same recommendation ID/target. A local, explicit opt-in Dart probe parsed all six real returned projections, verified the Jackson ID, and verified the two original Jackson records merge into one current group. Member navigation tests exercise the exact-ID detail/target flow; physical tapping remains owner manual acceptance.

Original Jackson: `de4dd23c3cc557f5290730e811d717e2862247ea0dd252f4065877f78746bc41`, source admin_outreach, Gemini / Delivered, model gemini-3.5-flash-lite, 4,574 ms and 338 saved total tokens, original receipt present. No new recommendation was created to manufacture this result.

## 2. Current-card merging, without data deletion

Member Home/full page group available, delivered, unexpired records by organization + kind + canonical target: coachId (ignoring slot/branch), tutorial exerciseId (across placements), routineId. Latest valid record supplies the card. All current pages are read before grouping so older duplicates behind pagination cannot reappear.

Feature Details re-read additional grouped IDs and show other still-valid reasons. Notification navigation retains the original exact ID. Group dismissal rechecks each original ID/current revision/current session and sends its existing dismissal command; no record or receipt is deleted. A partial network failure surfaces a retry, rather than claiming an atomic operation. Automatic seven-day cooldown behavior and manual Outreach independence remain unchanged. History APIs/raw records retain their original identities.

For the saved real production snapshot: 6 original recommendations remain; Jackson automatic and manual deliveries form one group whose newest card is the manual Outreach. No live dismissal/read/acknowledgment was executed during this task.

## 3. Zero-workout explanation and simpler profile matching

All seven TEST workout backups remain stored. Their explicit Module 13 TEST identifiers/payloads are excluded by the existing real-activity decoder. Thus 0 real workouts is an honest reporting result, not loss of backups. Admin analysis now explains this TEST exclusion and retains the distinction from real activity.

Tutorials retain recent-valid-exercise preference. For manual Outreach only, Profile candidates now include suitable published Routines by goal/experience without requiring workout history; Coach qualification/goal/specialty/branch and continuous 60-minute availability checks remain intact. The explicit manual flag is also used for Send revalidation. Automatic profile behavior is unchanged and its regression remains covered.

Read-only production-backed candidate check after deployment: Jackson + Beginner Full Body Foundations, Beginner Lower Body Basics, Beginner Upper Body Basics and Testing. No Tutorial is invented when there is no counted eligible workout context. No Generate/Preview/Send was invoked for this check.

## 4. Real photos and target attributes

Jackson has a real published photoPath. Existing authenticated getCoachPublishedPhotoCommand returns HTTP 200, image/png, 294,144 encoded characters for the TEST member. Admin now uses that existing published-photo callable instead of direct Storage reads. Storage Rules deliberately route Members through the protected callable; Rules were not changed.

Member recommendation avatars reuse the same bounded published-photo loader as the Coach directory, without the extra directory/profile/ratings fetch that could prevent the recommendation image from reaching the loader. Returned current path, content type, size and session are checked; an actual absent/unavailable image gets an avatar fallback. No unrelated image is substituted.

Current recommendation detail HTTP 200 now includes 60-minute session duration, Main Branch, actual published specialty and MYR 100 price (10,000 minor units). The protected photo result is verified live; visual rendering on the physical phone still requires the rebuilt client. Existing AI message/history is preserved, not rewritten to invent new evidence.

Routine and Tutorial image ownership paths are preserved: Routine own cover loader; Tutorial own exercise/tutorial media. Existing cover regressions remain covered.

## 5. Admin UI

Responsive Outreach workspace: compact Search/Top Active/Selected Member rail, analysis/summary/Generate/results on the right, selected-count Send footer; narrow view stacks into one column. Goal/experience labels are readable; no-candidate messages and model metrics are subdued. Search still finds TEST accounts without adding synthetic activity to Top 10.

Overview uses sidebar navigation, removes duplicate internal tabs/Insights links, adds Automatic/Admin Outreach source filter and column, keeps View Details inside the responsive table/card layout. Details show source/sender, AI method, Message, dates, state and available delivery information.

Offline Flutter screenshots, labeled synthetic fixtures and substitute typography; not signed-in production screenshots:
- [Desktop Outreach](../../build/module13-completion-20261118/screenshots/workspace-preview-1400.0.png)
- [Narrow Outreach](../../build/module13-completion-20261118/screenshots/workspace-preview-420.0.png)
- [Overview](../../build/module13-completion-20261118/screenshots/overview-fixture.png)

## 6. Verification, deployment and client artifacts

| Check | Result |
|---|---|
| Backend | 228 tests / 12 files pass; includes original automatic/Planner/Outreach plus notice isolation and manual profile-Routine regression |
| Emulator | 8 Auth/Firestore tests pass, including already-delivered Outreach via existing Notification Center projection and original Send/receipts/cooldown checks; demo project only |
| Admin Flutter | 68 tests pass; desktop/narrow/source filter/Details/Planner preservation |
| Member Flutter | 52 focused tests pass; merge, reasons, dismiss/session drift, notifications and navigation |
| Real response Dart probe | 1 explicit offline probe passes against saved TEST production responses; no network or mutation |
| Analysis/types | Changed Member files clean; primary Admin files clean; source/test TypeScript clean |
| Builds | Matching private Admin Web release + normal arm64 Android debug APK pass |

Only these existing Functions were source-updated:
1. module13AdminCommand — profile-based manual Routine candidates, honest activity note and compatible Send revalidation.
2. module13MemberCommand — current target metadata.
3. module9MemberCommandCallable — compatible canonical decoder/runtime and per-record notification isolation.

Exact deployed archives/settings/IAM verified. All 76 other Functions, Rules/indexes and Secret bindings retained. Rollback archives/configuration and prior Admin bundle are under build/module13-completion-20261118/release. Existing GLbg remains in use. No public Hosting change.

Private Admin is active at http://localhost:7359/; served main.dart.js SHA256 `b2433bdcc3c5e39a594ea4ce1fb14f1d4f4894646700c57d865aede54bd864f6`. The existing local serve helper was restarted hidden because the old listener was not running; browser control was not used.

[Deployment evidence](../../build/module13-completion-20261118/release/release-verified.json) · [Actual read-only post-check](../../build/module13-completion-20261118/acceptance-after.private.json) · [Profile candidates](../../build/module13-completion-20261118/profile-candidates-after.json) · [Backend](../../build/module13-completion-20261118/backend.log) · [Emulator](../../build/module13-completion-20261118/emulator.log) · [Admin](../../build/module13-completion-20261118/admin.log) · [Member](../../build/module13-completion-20261118/member.log) · [Production parse](../../build/module13-completion-20261118/production-projection-parse.log).

Android artifact: [gainpath-member-debug.apk](../../build/module13-completion-20261118/gainpath-member-debug.apk); checksum/build details in [android-artifact.json](../../build/module13-completion-20261118/android-artifact.json). Source is updated in C:/Users/Ngzhe/StudioProjects/gainpath. Existing named Android run configuration and main.dart run configuration now retain GAINPATH_RECOMMENDATIONS_ENABLED=true. Phone was not controlled or installed automatically; this is not physical-device UI acceptance.

## 7. Owner manual acceptance (no new Gemini request needed)

1. Admin: Ctrl+F5 at localhost:7359; confirm two-column Outreach, readable labels and Source filter/visible View Details. Use the existing Jackson row/preview history; do not Generate again for this acceptance.
2. Stop the old mobile run and run the updated main.dart from the ordinary GainPath project, or install the supplied debug APK as an update.
3. With the existing TEST login, refresh Notifications → All / Recommendations. Open the existing Jackson notice; confirm its correct detail and Coach destination/photo/price/Main Branch/60 min. No payment/booking is needed.
4. Open Home and Recommended for You; confirm one current Jackson card, latest manual message, and other valid reasons in Details via View all.
5. Optional Dismiss is a real user action on the original records. If testing it, expect the grouped card to disappear; Admin/Inbox/history records and receipts remain. This task did not execute Dismiss or alter your original acceptance records.
