# Remaining source integration — 20 October 2026

Owner authorized proceeding with all source integration after merging PR 1. This authorization is not a deployment, provider mutation, APK installation or acceptance of pending manual UAT.

## Preserved and prepared

- PR 1: https://github.com/Haise0619/gainpath/pull/1 merged at `8814a53abb791d3e7f7f65b7274459a4a96eeb77`.
- All 28 previously local commits were fast-forward pushed to `codex/real-squat-flow` at `34fced1f5f0ef71fd5d702189e618c1c3a982fce`. A separate remote `codex/roster-chat-payments-integration` points at the same commit.
- PR 2: https://github.com/Haise0619/gainpath/pull/2, source-only roster, private chat and Sandbox payment/refund review integration.
- The current workspace was moved to new branch `codex/coach-admin-refinements`, retaining local files. Only reviewed runtime source, contracts, tests and the presentation guard were staged. Commit `ed2c02d4141ddecd8137dea8c4dbaf877e3475fb` contains 29 files and was pushed normally.
- PR 3: https://github.com/Haise0619/gainpath/pull/3, dependent on PR 2; its review diff narrows to the refinements after PR 2 merges.

Historical documents, README edits, run configuration, devtools settings and Python caches were deliberately left local. They were not discarded, reset or bulk-staged. Some old documents contain obsolete launch/deployment instructions and are not current activation authority. No force-push, branch overwrite or branch deletion was performed.

## Integration repairs included in PR 3

Independent review found three P2 regressions in the uncommitted work: loss of navigation through the writable availability horizon, returning stale Mock roster data after save, and reporting successful Mock date saves without retaining overrides. Repairs restore bounded week navigation in the specific-date editor, saved roster readback, and repository-scoped in-memory date override persistence, including empty days and adapter recreation. Mock times/boundaries now use Kuala Lumpur wall time and preserve exact exception instants.

Conflict discard/reload and guarded close were restored to the date editor. A second focused review found bottom-sheet drag dismissal could bypass the dirty-edit guard via direct Navigator.pop; dragging is disabled for this editor. New regression tests were observed failing before fixes and passing afterward. The presentation checker now validates the actual indirect composition chain `LiveCoachAvailabilityView -> AvailabilityScreen -> AvailabilityPage` and checks constructor calls rather than simple substrings.

No new business module, Firebase schema/rule mutation, payment activation or acceptance-policy change was introduced by these repairs.

## Verification evidence

- PR 2 exact-ref static review: no actionable P1/P2 identified in inspected checkout/callback verification, refunds authorization/replay/recovery, roster reservation preservation, participant-only messaging, name projection and Mobile payment lifecycle. Targeted, not a comprehensive audit of all 111 changed files.
- Focused Mobile suite: 30 passed before final drag repair; final affected date-sheet/Mock/availability rerun: 13 passed, including the new drag configuration regression.
- Focused Admin certification/publication/shared-people suites: 14 passed.
- Shared Coach contracts: 3 passed.
- Targeted analysis: no errors/warnings, 11 style infos in existing dirty Admin refinements. Analysis completed before the final one-line drag setting; CI covers the committed candidate.
- Mobile/Admin/Module 8 presentation checks pass. Added-line credential-pattern scan of the new commit found no matches; this is not a comprehensive secret audit.
- Exact PR 2 CI: https://github.com/Haise0619/gainpath/actions/runs/39356366081.
- Exact PR 3 CI: https://github.com/Haise0619/gainpath/actions/runs/39357139779.

At report creation both PR runs remain in progress. Merge only after their required Flutter/backend jobs succeed and recheck exact head/base. Final merge results will be appended after verification.

PR 2 subsequently passed both CI jobs and merged at `df91e31a10518f797102d13471b45fcc4096b215`. Git remote read-back independently confirms that main tip. PR 3's recalculated merge commit has parents main `df91e31` and refinement `ed2c02d`; its tree is `c7e4dfd4019236272efbd84dd38e347b5e3d0deb`, exactly matching the pushed refinement tree. Thus the stale original-base SHA exposed in PR metadata does not represent an untested file-tree change. PR 3 still awaits final CI completion at this update.

## Final result

PR 3 subsequently passed both Flutter/backend CI jobs and merged at `f91d995d2f22db444294261a4a16e1a67d06d4d9`. GitHub read-back confirms it is merged and remote main points at that exact commit. All three PRs are merged with merge commits; original branches are retained. The original 28 commits and the 29-file refinement commit are now integrated into main. The local main ref is fast-forwarded separately without checking out or replacing working files.

No deployment, provider call, live-data write, APK installation, reset, deletion or force-push occurred. Manual acceptance gaps above remain unresolved. Historical documents/settings/caches and these local review reports remain preserved and uncommitted; they are not part of the source integration.

## Acceptance and operational boundaries

Sandbox refund payout and independent completion remain unverified; provider capacity/simulator setup is unresolved. Payment owner UI acceptance, Module 10 real CRUD/manual acceptance and broader Module 9 UAT remain open. Passing source CI does not close these gaps or establish full FYP completion or real-money readiness.

Preserve deployed Firestore/Storage Rules, indexes, selective Functions, secrets, App Check/Scheduler configuration, booking/payment/audit/lock data and native workout/outbox data. A merged source checkpoint is not permission to blanket-deploy firebase.json or downgrade the currently running clients/backend.
