# GainPath Module 2 — Workout Programs and Weekly Schedule

**Android Studio launch update (28 October):** select **Admin Web** (apps/admin_web/lib/main.dart), choose Chrome and Run. Exercise Catalog status/Delete/Restore now appear in normal source launches without EXERCISE_CATALOG_STATUS_ENABLED or any replacement feature setting. Stop/restart an older running instance. Existing Firebase/App Check setup remains unchanged; Routine removal remains held. Historical release evidence below records the previous flagged bundle.

Feature report and user manual · **27 October release; acceptance preparation updated 28 October 2026, Malaysia time**

## 1. Overview and release status

The Workout Program system gives Members a four-week training plan with a clear workout category for each scheduled day. It connects Admin-authored Programs and published Routines to the existing camera/guided workout journey, routine summaries and history.

The feature is released. The private local Admin is active at [localhost:7359](http://localhost:7359/), and the reviewed Mobile APK is installed on the approved Xiaomi. Five reusable starter Routines and three Program version 1 publications are live. Read-only discovery through the authenticated Member callable returned all three Programs successfully.

Read-only signed-in Admin observation passed on 28 October. Live Member enrollment, exercise completion, additional authoring mutations and physical workout acceptance still require UAT. Publication did not enroll Members or generate workout results.

Related references: [current progress](../PROGRESS_REPORT.md#module-2-programs-active-release), [capability status](../STATUS.md), [architecture](../ARCHITECTURE.md), and [operations](../OPERATIONS.md).

## 2. What was implemented

| Requirement | Delivered behavior |
|---|---|
| Level-based Programs | Beginner, Intermediate and Advanced Programs; each publication has its own version. |
| Weekly schedules | Four weeks of seven days, containing Workout Days, Active Recovery and Rest Days. |
| Reusable Routines | Each workout slot references a published Routine and a selected Routine day. Publication retains its exercise order, targets and tutorial snapshot. |
| Initial templates | Three published four-week starter Programs using the requested 3-, 4- and 5-day weekly splits. |
| Member onboarding | Selection of Program, start date and available training weekdays. |
| Today's Workout | Scheduled day/category, exercise list, targets, tracking capability, summaries and weekly completion counts. |
| Complete journey | Program → Week → Day → Routine → AI/Guided exercises → Summary → next scheduled day. |
| Flexible attendance | Exact-attempt resume, explicit skip and date rescheduling; missed days remain incomplete. |
| Recovery checks | Rejects workout-date collisions, adjacent overlapping authored muscle groups, repeated exercises on adjacent workout dates and clear upper/lower category mismatches. |
| Structured progress | Program/week/day views link to typed exercise results, preserving measured repetitions and self-reported sets separately. |

Existing Exercise Catalog, Routine Builder, tracker dispatcher, camera consent, exercise analyzers, routine checkpoints, history and opt-in provisional backup are reused. No new recognition algorithm or supported exercise was fabricated.

### Published four-week schedules

The following weekly patterns repeat for all four weeks. They describe the default template weekdays. A Member's chosen start date and available weekdays determine the actual calendar dates.

| Day | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Monday | Full Body | Upper Body | Push |
| Tuesday | Active Recovery | Lower Body | Pull |
| Wednesday | Full Body | Active Recovery | Legs |
| Thursday | Active Recovery | Upper Body | Active Recovery |
| Friday | Full Body | Lower Body | Upper Body |
| Saturday | Active Recovery | Active Recovery | Lower Body |
| Sunday | Rest | Rest | Rest |
| Workout days/week | **3** | **4** | **5** |
| Workout days over four weeks | **12** | **16** | **20** |

These are starter Programs. Levels currently change the weekly split and frequency while sharing the owner-approved exercise targets. They do not introduce new exercises, automatic load progression or different AI scoring algorithms.

### Published reusable Routines

| Routine | Exercise order |
|---|---|
| Full Body Starter | Squat → Wall push-up → Standing single-arm dumbbell curl |
| Upper Body Starter | Wall push-up → Standing single-arm dumbbell curl |
| Lower Body Starter | Squat |
| Push Starter | Wall push-up |
| Pull Starter | Standing single-arm dumbbell curl |

Legs days reuse **Lower Body Starter**. All listed exercises use **3 sets × 8 repetitions**, with **60 seconds of Program rest between sets**. Curl repetitions are **per selected arm**; selecting both arms requires each arm's target. These targets were explicitly selected by the owner.

The starter Routines have a configurable 20-minute planning estimate. This estimate is not a measured session duration or a time limit.

## 3. How the implementation works

### Content and versioning

1. Admin authors catalog-based exercise targets in Routine Builder and publishes the Routine.
2. Admin assigns published Routine days to a Program's weekly slots.
3. Program publication validates all four weeks and creates an immutable version containing the assigned Routine snapshots.
4. Member enrollment saves a copy of that Program version and its dated schedule.
5. A scheduled workout retains its own routine-attempt ID. Reopening it resumes that attempt.
6. Typed routine results determine exercise and day completion.

Editing a Routine does not rewrite an existing Program publication. Publishing a new Program version does not change an existing Member enrollment. To use revised targets, publish the revised Routine, publish a new Program version and start a new enrollment using that version. Earlier enrollment/history records remain retained.

### Main components

| Component | Responsibility |
|---|---|
| Shared [`WorkoutProgram`, `ProgramDay`, `ProgramSchedule`](../../packages/gainpath_domain/lib/src/workout/workout_program.dart) | Program validation, four-week templates, calendar assignment and recovery checks. |
| [Admin Program screen](../../apps/admin_web/lib/features/workout/presentation/admin/workout_programs_screen.dart) and repository | Draft editing, Routine assignment, revision-aware saving and publication. |
| [`workoutProgramCommand` service](../../functions/src/modules/content/workout-programs.ts) | Scoped discovery, trusted draft/publication operations, immutable versions and idempotent command receipts. |
| [Member Program controller](../../apps/mobile/lib/features/workout/application/workout_program_controller.dart) and [local journal](../../apps/mobile/lib/infrastructure/local/file_program_enrollment_store.dart) | Account-private enrollment, schedule changes and exact routine-attempt linkage. |
| Existing [routine journey](../../apps/mobile/lib/features/workout/application/routine_journey_controller.dart) and [tracker dispatcher](../../apps/mobile/lib/features/workout/domain/exercise_tracker_dispatcher.dart) | Exercise tutorials, registered AI routes, manual guidance, sets/rest and typed results. |
| Existing backup/reporting services | Provisional workout/routine evidence, including compatible optional rest targets. |

Routine Builder defines exercise order, sets and reps. Program days define rest targets. Pose analyzers do not hardcode these prescriptions, and Admin configuration cannot register a new AI recognition algorithm.

### Security and data boundaries

- Normal Program requests require verified Auth, App Check, the correct organization and canonical active membership, with lifecycle/session checks. Admin/eligible Staff authority is required for authoring.
- Canonical organization membership determines the role. An explicit global user role must agree when present; legacy accounts without that optional field remain supported.
- Draft revisions reject stale edits. Published versions and retry receipts prevent accidental replacement or duplicate publication.
- Program publications are cloud content. Enrollment, selected dates, skips and attempt links are stored in an account-private local journal.
- Existing explicit opt-in backup stores provisional workout/routine evidence. It does **not** back up or reconstruct Program enrollment metadata.
- Workout reward issuance and verified cloud-workout acceptance remain disabled. Completing a scheduled day does not establish either eligibility.

## 4. Admin user manual

### A. Open and inspect Programs

1. Sign in with an authorized, verified Admin account for the correct organization.
2. Open the normal Admin at [localhost:7359](http://localhost:7359/). Refresh an already-open page after a release.
3. In the sidebar, select **Content → Workout Programs**.
4. Use **Reload** to obtain confirmed server data.
5. Review **Saved drafts** and **Published Programs**. The three starter Programs should appear with version 1.

Navigation uses the sidebar; a separate `/programs` URL route is not provided.

### B. Create or change a reusable Routine

1. Open **Content → Routine Templates**, or use **Routine Builder** on the Program screen.
2. Select **New template**, or edit an existing template.
3. Enter its name, level and planning information.
4. Add a Routine day and select existing catalog exercises.
5. Set each exercise's sets and reps. Use **Move up** and **Move down** to set the exercise order.
6. Save the template, then use its publication control to publish it for Members.
7. Return to **Workout Programs** and **Reload** before assigning the published Routine.

Selecting a catalog exercise does not make it AI-supported. Recognition follows the developer registry and the installed client. An unsupported or held tracker uses the existing instructional/manual path.

### C. Create a new Program

1. Under **Start a Program**, choose the Beginner, Intermediate or Advanced starter. This creates a separate draft for editing.
2. Enter **Program title** and **Training level**.
3. Select **Week 1**, then **Edit day** for each slot that needs adjustment.
4. In **Schedule day**, choose **Day type**:
   - **Workout Day:** select its workout category, **Published Routine**, **Routine day**, and **Rest between sets (seconds)**.
   - **Active Recovery:** a recovery day without a prescribed Routine.
   - **Rest Day:** a rest day without a prescribed Routine.
5. Press **Apply** for the day.
6. Review **Week 2**, **Week 3** and **Week 4** individually. Editing one week does not automatically copy changes to the others.
7. Press **Save draft**.
8. After the save is confirmed, press **Publish version**.
9. Confirm the published version and reload the catalog if needed.

Rest accepts whole seconds from 0 to 600. Publication requires all 28 slots, real published Routine assignments for workout days, and the same nonzero number of workout days in each week. Recovery checks also apply. The initial templates use 3/4/5 workout days per week respectively.

**Publish version** is unavailable while a draft is unsaved or has unsaved changes. Saving alone does not expose a new Program version to Members.

### D. Update an existing Program

1. Find its entry under **Saved drafts** and select **Edit**.
2. If changing exercise targets/order, first update and publish the Routine in Routine Builder.
3. Update the relevant Program day assignments/rest targets and review all four weeks.
4. **Save draft**, then **Publish version**.
5. Verify the new version under **Published Programs**.

Existing enrolled Members retain their original version. A Member must choose the revised Program as a new enrollment to use the new publication. The feature does not automatically migrate previous progress or provide a Program delete/purge workflow.

### E. Resolve save/publication errors

- **Another editor changed the draft:** reload, review the latest revision and reapply the intended edits. Reloading can discard unsaved work.
- **Missing Routine assignment:** assign a published Routine and valid Routine day to every workout slot.
- **Recovery/category conflict:** inspect adjacent days, including the boundary between weeks. Correct the category, Routine or spacing.
- **Network/verification failure:** retry the unchanged operation after connectivity/session verification recovers. Do not assume publication succeeded until confirmed.
- **Published Routine missing from the selector:** publish it in Routine Builder and reload Programs.

## 5. Member user manual

### A. Choose a Program

1. Sign in as an active, verified Member in the correct organization.
2. Open **Workout → Today's Workout**.
3. Use the refresh icon (**Reload program and progress**) if the catalog is stale.
4. Under **Choose your program**, select **Program and level**.
5. Select **Start date**. The picker accepts today or a future date within its available range.
6. Choose exactly the requested number of available training weekdays: 3 for the published Beginner Program, 4 for Intermediate or 5 for Advanced.
7. Press **Start program**.

The scheduler keeps workout categories in their prescribed order and maps them to the selected training weekdays. Each Program week is a seven-day block from the chosen start date. For a Monday start with default weekdays, dates follow the schedule table above. Other start dates can produce different calendar arrangements.

If a weekday combination fails recovery checks, choose a more spaced arrangement. The system does not silently remove exercises or mark days complete to make a schedule fit.

### B. Read Today's Workout and the weekly schedule

The screen shows the Program title, level and enrolled version. A day card shows its date, category, status, exercises, sets/reps/rest and tracking capability. Expand a **Week 1–4** row to inspect its seven scheduled entries and select a day.

Weekly progress is displayed as completed workout days over planned workout days, for example **0/3 workouts completed**. Active Recovery and Rest Days do not increase that workout-completion count.

### C. Complete a scheduled workout

1. Select the scheduled workout day and press **Start scheduled routine**.
2. Review the Routine's exercises and targets. Use **Watch exercise tutorial** where needed.
3. For a registered supported exercise, select **Start guided exercise**, complete the existing camera consent/setup/calibration, and follow its sets/rest flow.
4. For a Guided-only exercise, follow its instructions and explicitly use **Mark set … done**. These sets remain self-reported; the app does not invent measured reps or form scores.
5. Continue through the Routine's exercise list.
6. Use **Finish routine** when appropriate, or review the summary when the existing flow finishes automatically.
7. Review **Routine completion**, including measured full/partial reps and self-reported sets.
8. Select **Back to weekly schedule**. The Program reloads its linked result.
9. Use **Next scheduled day** to inspect the next pending workout.

Start from the scheduled day to link progress correctly. A separate workout launched elsewhere is not automatically matched to a Program day just because it uses the same Routine.

### D. Understand progress states

| State | Meaning |
|---|---|
| Scheduled | Workout has not yet been started and is not overdue. |
| Missed · not completed | Its scheduled date passed without a linked completed result. |
| In progress | The scheduled attempt has begun or has been linked but is unfinished. |
| Partially completed | The Routine was finished with incomplete/skipped targets. |
| Skipped | The Member explicitly skipped the scheduled workout. |
| Completed | The linked Routine attempt is finished and every exercise has a typed completed result. |
| Active recovery / Rest day | No prescribed workout is required for that slot. |

A valid explicit self-reported completion can contribute to a completed Guided-only Routine, while remaining labelled self-reported. Viewing instructions, skipping an exercise or saving a partial session does not satisfy all exercise targets. A started unfinished day can retain **In progress** or **Partially completed** rather than switching to the missed label.

### E. Resume an interrupted or partial day

1. Open the same enrollment and scheduled day.
2. Press **Resume scheduled routine**.
3. If a partial summary is shown, select **Resume unfinished exercises**.
4. Continue the unfinished targets, then finish/review the Routine.

The scheduled attempt ID stays pinned across retries and reopening. Earlier evidence is retained. Scheduled mode does not offer the ordinary standalone repeat/new-attempt shortcut that could replace the day's linked attempt.

### F. Skip a day

1. Select an unfinished workout day.
2. Press **Skip day** and confirm the skip.
3. Its status becomes **Skipped**, without completion credit.

Skipping retains existing partial evidence. The day can be resumed later using its start/resume control. A completed day cannot be skipped, and skipping does not automatically move subsequent workouts.

### G. Reschedule a missed or unfinished day

1. Select the day and press **Reschedule**.
2. Choose today or a future date allowed by the picker.
3. Review the new date and surrounding workouts after the save.

The rules are:

- Completed workouts cannot move.
- A destination already containing a workout is rejected.
- If the destination is a Rest/Active Recovery slot, the two dates swap.
- Adjacent overlapping muscle groups or repeated selected exercise IDs are rejected, including across weeks.
- A day retains its original Program/week/day identity and linked evidence after moving.

Rescheduling is explicit, one workout at a time. It does not automatically shift the remaining calendar. Moving a workout beyond the original end date can extend its calendar while its progress remains attached to the original logical Program week.

### H. Change Programs or return to an earlier enrollment

Use **Choose another program** to start another enrollment. Previous enrollments and workout history are retained. When more than one enrollment exists, use **Saved program enrollment** to switch between them.

Choosing another Program does not reset previous completion or upgrade an old enrollment to a newer publication.

## 6. History, backup and practical limits

Program progress follows the existing typed Routine/exercise results. Measured repetitions, partial repetitions and tracked time remain distinct from manual set counts. A scheduled-day summary is evidence of the saved local attempt; it is not a verified cloud-workout receipt.

Program enrollment is **local to the account and device**. Do not assume that changing phones, restoring routine backups, reinstalling after data removal or clearing app data will restore the Program's dates, enrollment or attempt links. Existing opt-in provisional workout/routine backup remains useful for its supported evidence, but it does not reconstruct the Program journal.

Other current limits:

- All Programs are currently four weeks long.
- The published starters contain only Squat, Wall push-up and Curl; there is no automatic exercise-generation or progressive-overload feature.
- Recovery checks use authored split categories, repeated exercise identities and clear catalog upper/lower metadata. They are conservative scheduling checks, not individual physiological or clinical validation.
- Rest/recovery slots provide schedule guidance; there is no separate recovery-activity recording or reward claim.
- Completing a Program does not issue workout points or enable accepted cloud workouts.
- Workout accuracy, calibration, camera latency and the complete physical journey still need their existing acceptance work.
- Read-only signed-in Admin content observation passed on 28 October using the now-available in-app browser. Earlier native URL verification and disabled-browser blockers remain historical. Live Member/physical UAT and new authoring mutations remain unaccepted; publication/callable readback alone does not establish them.

## 7. Troubleshooting

| Symptom | Action |
|---|---|
| Programs are unavailable | Check connectivity and verified account/organization, then use **Retry programs** or refresh. A saved local enrollment is retained when catalog loading fails. |
| New publication is not shown | Reload the catalog. An existing enrollment intentionally retains its enrolled version. |
| Start program is disabled | Select exactly the requested number of training weekdays. |
| Schedule/recovery validation fails | Space the affected workouts, inspect categories and repeated exercises, and review week boundaries. |
| Weekly completion did not increase | Open the scheduled day; finish its linked Routine and resolve unfinished exercises. Instructions/partial results alone do not complete a day. |
| Wrong or stale local schedule view | Use the reload control and confirm **Saved program enrollment**. Do not erase history as a recovery step. |
| No AI tracking for an exercise | Follow its displayed Guided/manual path. Admin publication cannot add recognition support. |
| Old Program is absent on another phone | Program enrollment metadata is not currently restored across devices. Do not manufacture replacement completion. |

## 8. Verification and acceptance evidence

The following are retained implementation/release results from 27 October. Writing this manual did not rerun the application suites or perform new live operations.

| Verification | Recorded result and scope |
|---|---|
| Initial integration checkpoint | 431 passed: domain 172, affected backend 135, Mobile 87 and Admin 37. |
| Authority compatibility correction | 141 affected backend tests passed, including six added role-contract regressions. This overlaps the earlier backend selection; it is not an additional 141 unique tests. |
| Independent focused correction review | No actionable findings; 68 focused tests passed, overlapping the correction selection. |
| Extracted release-package checks | 30 initial checks and 10 corrective-package checks passed. |
| Exact starter content through Member code | 174 model/scheduler/dispatcher checks passed on the reviewed publication payloads. |
| Builds and static checks | Mobile profile APK and Admin release Web builds passed; affected Dart analysis, architecture and backend source/test TypeScript checks passed at their recorded checkpoints. |
| Deployment | Source hashes and runtime/environment/IAM verified; the corrective release preserved the other 69 Functions and existing Rules/indexes. |
| Publication | 18 create-only documents committed: five blueprints, five published Routines, three Program drafts, three immutable Program v1s, catalog index and audit. Exact readback passed. |
| Preservation | Existing catalog/Routine/canonical Admin documents unchanged; no Member enrollment/progress/reward or AI-registry writes. |
| Live Member discovery | Existing verified test Member with registered App Check received all three Programs with HTTP 200. |
| Full UI/physical acceptance | Pending; no full browser/device/physical PASS is claimed. |

Private evidence remains under `build/workout-programs-20261027/`, including `starter-program-closeout.json`, `starter-publication-verification.json`, `member-program-discovery.json`, `role-fix-production-verification.json` and the earlier `release-verification.json`. Credentials, personal identifiers and private screenshots are excluded from this manual.

### Suggested owner acceptance rehearsal

1. Refresh Admin and verify the five starter Routines and three Program v1s.
2. Enroll a permitted test Member with a start date and valid training weekdays.
3. Inspect a workout, recovery and rest day, then navigate the four weeks.
4. Complete a supported exercise/Routine and confirm its measured summary and weekly count.
5. Interrupt/resume a scheduled attempt and verify that earlier evidence remains linked.
6. Test partial finish, skip/resume, an allowed reschedule and a rejected collision/recovery conflict.
7. Switch enrollments/accounts and confirm isolation and retained versions/history.
8. Separately verify normal opt-in routine/workout backup behavior without claiming Program enrollment restore or workout rewards.

Use authorized test records and preserve their history. Any additional deployment, device change, account/role change or destructive data operation retains its existing approval boundary.

### 28 October local acceptance checkpoint

Fresh focused verification passed **181 tests**: 111 backend, 11 shared scheduling, 40 Mobile, 16 Admin and three complete four-week offline Program rehearsals. These are this selection's results; they neither replace the earlier broader counts nor establish live UI or physical acceptance. No new application build was needed because production source was unchanged.

The three additional rehearsals parsed the retained 27 October authenticated Member discovery payload and used the real Program/Routine controllers and file stores with synthetic local accounts. Across 48 scheduled workout days, they checked invalid availability rejection, incomplete missed days, recovery/rest launch rejection, skip/resume with the same attempt, rejected workout collisions, an allowed rest-date swap, reviewed-only and partial results, checkpoint reopening, all four weekly totals, the final absence of a next workout, retained version/progress after enrollment switching and account isolation. Trackers were deliberately unavailable: completion came from explicitly self-reported test sets, with zero measured repetitions or tracked duration. Camera dispatch/return has separate fixture-based coverage in the focused Mobile selection; no physical result was created.

Two rapid-write runs in the workspace evidence directory encountered intermittent Windows `Access is denied` while renaming a Routine `.pending` checkpoint (two failures, then one, across three journeys per run). The same assertions passed all three journeys using the normal Windows test temporary directory. The precise locking cause is unresolved; no production persistence workaround was introduced. Keep this as a Windows host stress-test finding before claiming equivalent desktop persistence acceptance. It establishes neither an Android failure nor an Android pass.

Evidence, the authored rehearsal, initial failures and passing logs are retained privately in `build/workout-programs-20261027/acceptance-20261028/`, summarized by `checkpoint.json`. This pass made no cloud writes, live enrollments, device changes, content publication or reward-policy changes. Member callable discovery evidence remains dated 27 October.

The in-app browser was available during the 28 October check. The stopped private Admin server was restarted on loopback port 7359 with its existing index/bootstrap/main assets verified against retained release hashes; no files were replaced. The existing signed-in Admin session displayed all three Program v1s and revision-2 drafts. Read-only saved-draft inspection confirmed Beginner Week 1/4 and Intermediate/Advanced Week 1 splits, targets, order and recovery/rest. Routine Templates displayed all five starters; Full Body's editor showed Squat → Wall push-up → Curl and reorder controls. No save/publish/remove action was performed, and the tab was returned to the Program list. Sanitized evidence is `admin-browser-observation.json`; private account identifiers are excluded. This closes UAT-01 only.

### Hands-on acceptance record

Use an authorized test Member and retain its history. Mark a case PASS only after observing the expected result; record date, app/build, observer and evidence location. In-app browser access is now available; the read-only Admin case below was observed. Automated tests do not close the remaining cases.

| Case | Action and expected result | Current status |
|---|---|---|
| UAT-01 Admin content | Open Content → Workout Programs and Routine Templates. Observe three Program v1s, five Routines and approved order/3×8/60s targets. | PASS, 28 October; bounded read-only browser observation above |
| UAT-02 Enrollment | Choose Beginner, a start date and three valid weekdays; inspect all four weeks and workout/recovery/rest days. Invalid weekday counts reject without creating an enrollment. | Pending phone observation |
| UAT-03 Supported camera workout | Launch from the scheduled day, complete consent/setup and a supported exercise, save and return. Observe the linked summary, truthful measured values and next exercise/day. | Pending physical observation |
| UAT-04 Manual distinction | When tracking is unavailable, inspect guidance and explicitly record manual sets. Summary labels self-reported completion without AI reps/form metrics. | Pending phone observation |
| UAT-05 Interrupted/partial | Save a partial attempt, leave/reopen and resume. Earlier evidence stays linked; incomplete attempts do not increase weekly completion. Unsaved camera movement is not recovered as saved results. | Pending phone observation |
| UAT-06 Missed/skip | Inspect an overdue day, skip and resume it. Neither missed nor skipped status counts as complete; resume retains the linked attempt. | Pending phone observation |
| UAT-07 Reschedule | Move an unfinished workout to an allowed date, then try an occupied workout date and a recovery conflict. Observe the move/swap and rejected conflicts with progress retained. | Pending phone observation |
| UAT-08 Persistence/isolation | Restart, revisit an earlier enrollment, then use a separately authorized account switch. Verify retained version/history and no foreign progress. | Pending phone observation |
| UAT-09 Backup boundary | If already opted into supported backup, inspect its normal status. Program enrollment/calendar restoration across devices is unavailable; backup is not accepted workout or reward evidence. | Pending authorized observation |
| UAT-10 Owner sign-off | Record findings, fix reproducible defects locally, rerun affected checks and close observed cases. Physical accuracy/calibration and reward enablement remain separate gates. | Pending preceding cases |

Admin save/publication of new content is unnecessary for read-only content observation. A new live authoring/version-preservation mutation needs its own exact content scope; local repository/service tests cover those contracts. Do not republish starter v1s merely to run UAT.

## 9. Single-arm row

**28 October: RELEASED after the owner authorized “direct implement all until deploy.”** Both source-only backup/reporting compatibility Functions are active, the private local Admin is activated and the matching-signer APK is installed/launched on Xiaomi7c4cbff with identity/data preserved. The row catalog entry and **Single-arm Row Validation** Routine are published at **3 sets × 8 reps per selected arm, 60s rest**. This extends the existing Program → Routine → registered exercise infrastructure; current starter Programs were preserved and do not automatically acquire the new Routine. The developer identity is `gainpath/single-arm-dumbbell-row-side-v1`, tracker `single_arm_row_side_v1`, evidence version `single-arm-row-side-v1`. Matching a title or another organization cannot enable tracking. Physical accuracy/latency/thermal acceptance remains pending.

### Implementation and responsiveness

The isolated row analyser combines selected-arm elbow bend with upper-arm travel relative to a calibrated torso. A stationary-elbow curl cannot satisfy the row cycle. Stable hanging-arm calibration, sustained start/peak/return evidence, separate full/partial counts and raw-plus-filtered agreement prevent static jitter or one deep spike from becoming a full repetition. Missing/weak joints, stale/nonmonotonic frames, gaps, pause, camera geometry changes and excessive projected torso movement invalidate unfinished cycles. Only shoulder, elbow, wrist and hip are required; an occluded knee cannot unnecessarily block tracking.

| Mechanism | Purpose and scope |
|---|---|
| Existing latest-frame processor and 250 ms freshness limit | Reused to bound queued work and reject delayed evidence; no capture/inference pipeline rewrite. |
| Existing GPU initialization/CPU fallback and responsive/smooth preview | Reused; the row defaults to the existing responsive setting and analyses the fresh pose before overlay smoothing. |
| New adaptive scalar filtering | Existing One Euro implementation applied only to row angle/travel, with time-based dwell/hysteresis and reset on invalid evidence. Other analysers/filter settings stay unchanged. |
| Coalesced row notifications | Combined pose/result UI notifications share a microtask update; fixture tests bound notifications per delivered frame after explicit UI actions. |
| Bounded row state | Constant-size calibration/cycle/filter state, without frame/video history or an additional model. |

This is projected movement counting with provisional cues. It does **not** assess bench contact, dumbbell weight, spinal shape or three-dimensional rotation. A row form score is deliberately unavailable. Selected-side metadata uses additive local metrics schema 3; legacy schema 1/2 results are preserved. New row summaries reject nonzero legacy accuracy and mismatched exercise/analyser identities. Backend source validates schema 3 only as provisional backup, and reporting excludes null row scores from form means. Accepted workout tuples and workout rewards remain disabled.

### Member instructions

1. Refresh/browse Member Workout Routines and open **Single-arm Row Validation**. Existing Program v1s are unchanged; a standalone test Routine does not automatically complete a scheduled Program day. Future approved Program versions can assign this Routine while preserving earlier enrollments.
2. Review the tutorial and consent/setup acknowledgement. Select **Left arm** or **Right arm** before **Start camera**; targets/rest come from the Routine, without analyser-defined sets/reps.
3. Support the other hand and knee on a stable bench. Position the camera side-on with the selected shoulder, elbow, wrist and hip visible. Hold the torso nearly horizontal with the selected arm hanging until calibration completes.
4. Pull the selected elbow toward the hip, then lower with control to the hanging position. The camera header names the selected arm. A full repetition requires the complete observed cycle; partial movements remain separate.
5. Follow the normal explicit next-set/rest, pause/resume, recalibration and End/save controls. Resume after tracking loss starts from calibration; unsaved or missing movement is not reconstructed.
6. Inspect **Measured row result**, selected arm, full/partial reps and tracked/unassessable time. Form score is shown as unassessed. Return to the pinned Routine; targets apply only to the selected arm in this session. Train the other arm in a separate session when required by the authored plan.

### Verification and remaining release gates

Initial implementation verification passed **621 tests** — 151 pose (46 row cases), 173 shared-domain, 135 affected Mobile, 66 affected Admin and 96 affected backend. Changed-file analysis, architecture, backend typechecks and both client builds passed. Review findings for manual-pause/background resume and reverse identity binding were reproduced and fixed. Intermediate test-helper issues were corrected; final affected runs passed. This checkpoint is retained in `verification.json` and predates the later compatibility/release work below.

Release verification passed **114 affected backend and 29 affected Mobile tests**, **22 checks against the exact extracted Function ZIPs**, and **six publication-payload checks through Member models/dispatcher**. These overlap the initial selection; do not add them as unique totals. The final compatibility APK was rebuilt, signer-checked and installed in place; the private Admin was cache-versioned/activated with served hashes checked. Both source-only deployments preserve runtime/environment/IAM; the other 68 Functions, Rules/indexes and earning configuration match the baseline. Anonymous calls reject401. A create-only transaction wrote the row catalog, Routine blueprint/publication and audit; all 31 protected existing documents and exact new readbacks pass. No existing Program/Routine overwrite or fabricated Member workout was performed.

Read-only verification with the existing verified synthetic Member and registered App Check confirms the published Routine is readable under client Rules and both default-2/new-3 backup listing return HTTP200. No test backup/workout was uploaded. Signed-in Admin browser observation confirms the active row catalog identity with AI tracking/Side view, the validation Routine and its resolved exercise; the editor was cancelled without saving. CLI publication itself does not establish a client authoring/write test. Closeout: `release-verification.json`, with `production-verification.json`, `installation-verification.json`, `content-verification.json`, `member-live-read-verification.json` and `admin-release-observation.json` under the retained evidence directory.

The host-only benchmark warmed 50 cycles and sampled 39,600 analyser calls: median 0.5 µs and p95 0.6 µs in the recorded run, excluding frame construction, model inference, camera capture and rendering. It counted 250 repeated synthetic cycles at approximately 60 Hz correctly; separate 60/20/8 Hz single-cycle replays counted within approximately 0–100 ms after the fixture's fully returned position. These measurements establish neither phone FPS nor physical rep accuracy. Commands and evidence are retained under `build/single-arm-row-20261028/`, including `verification.json`, final build/test logs and `analyzer-benchmark.json`; `tool/benchmark_row_analyzer.dart` reproduces the benchmark.

Backup compatibility is now deployed: old requests omit `maxPoseMetricsSchemaVersion` and default to 2; the new app sends 3. Only integer negotiated maxima 2/3 are accepted. Full scanned pages are integrity-validated before unsupported row sessions/dependent Routine snapshots are withheld from older clients; cursors use scanned documents so empty compatible pages still advance. Existing schema-1/2 payloads and remote records are retained. This is provisional backup compatibility, not accepted workout evidence or a data migration.

Recovery retains the previous source ZIPs, Admin bundle and installed APK under the ignored release directory. Do not replay completed mutation scripts or restore older validators/clients after schema-3 data exists without reviewing that compatibility boundary. Further deployment, content overwrite, account/role change or device action needs its own scope. Starter Program v1s and existing enrollments remain unchanged. Physical UAT must still measure camera positioning/occlusion, wrong motions, partial/full counts, loss/recovery, frame latency, stability and sustained thermal behavior on the Xiaomi. Accepted cloud workout tuples and workout rewards remain disabled; release does not establish accuracy acceptance.

Research and design choices: [ACE single-arm row technique](https://www.acefitness.org/resources/everyone/exercise-library/126/single-arm-row/), [MediaPipe pose outputs](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker), [One Euro filter authors and tuning](https://gery.casiez.net/1euro/), and the [local implementation plan](../superpowers/plans/2026-10-28-single-arm-row.md). These inform the implementation; provisional thresholds are engineering choices pending physical validation.

## 10. Exercise Catalog status and Delete

**ACTIVE after owner approval, 28 October.** The exact v2 Firestore Rules overlay is deployed and the reviewed private Admin is activated at `http://localhost:7359/`. Refresh Admin to see **Active**, **Inactive**, **Archived**, filters and per-exercise lifecycle controls. Routine removal remains held; only exercise lifecycle controls are enabled using `EXERCISE_CATALOG_STATUS_ENABLED=true`.

| Status | Meaning | Available lifecycle action |
|---|---|---|
| Active | Available for new Routine selections. Existing system registry still determines AI support. | Deactivate or Delete |
| Inactive | Retained catalog entry, unavailable for new Routine selections. Existing internal draft value is preserved. | Activate or Delete |
| Archived | Removed from new selections and normal editing; stable ID, media references and content remain stored. | Restore as inactive |

### Admin instructions

1. Open **Content → Exercise Catalog**. Use **All / Active / Inactive / Archived** to filter; counts describe the full loaded catalog.
2. Choose **Deactivate** to stop new selection, or **Activate** to make an inactive entry available again.
3. Choose **Delete** and review the confirmation. Confirming archives the entry and makes it inactive; it does not permanently erase documents or media. **Cancel** makes no change.
4. Open **Archived**, then choose **Restore**. The entry returns as **Inactive**. Select **Inactive** or **All** to find it, and explicitly **Activate** if required. Normal editing is available after restoration.
5. If a status change cannot be verified, use **Reload catalog** before retrying. If authorization changed, reopen after signing in. Conflicting actions and editing are locked while a request is pending or an uncertain change requires reload.

Published Routine/Program snapshots, earlier Member enrollments and workout history remain unchanged. Changing catalog status does not rewrite existing publications or delete previously uploaded media. Archived content cannot be edited through the normal save/media path until explicitly restored. Permanent deletion remains denied.

### Verification and release boundary

The status repository uses the loaded opaque revision baseline, canonical author scope and transaction checks before patching only `archived`/`isActive`; the store supplies the update timestamp. It verifies status and fresh authority on readback, preserving unknown/author/tracker fields. The exact live-Rules candidate retains production's existing `exerciseCatalogAuthor` guard, allows only status/timestamp field changes in its compatibility path, requires archived entries to be inactive and leaves hard delete denied. All unrelated deployed Rules bytes are preserved. An initial overlay copied the local helper name incorrectly; its foreign-organization test failed, and the corrected **v2** overlay passes. The rejected candidate is retained and must never be deployed.

Preparation verification passed **112 affected Admin tests**, **173 shared-domain tests** and **52 tests against the exact v2 Rules overlay**, including ordinary rich 12-step catalog edits, metadata preservation, denied foreign/Member writes, cancellation, Restore/Activate, reload recovery and 320px/double-text layout. Static analysis, test typechecking and architecture checks pass. A broader source-Rules core emulator run recorded 218 passes, two skips and one booking transaction-closed contention failure; that unchanged booking file passed all three tests on a fresh isolated emulator. This is a bounded rerun, not a fresh full-core pass.

Review artifacts/logs, previous Rules/Admin, exact owner approval, operation state and release readbacks are retained under `build/exercise-catalog-status-20261028/`. `verification.json`/`release-review.json` record preparation; `release-verification.json` confirms the approved exact **firestore-candidate-v2.rules** overlay and cache-versioned private **admin-ready/** activation. Release readback verifies the exact Rules hash and served index/bootstrap/main hashes, all 70 Functions, other Rules releases, indexes, catalog records and captured reward configuration unchanged. No live catalog write, device action, account/role change or migration occurred. Signed-in browser smoke remains pending because browser access is disabled in Work settings. No Function/APK/Hosting deployment was included. Signed-in status-mutation acceptance has not been performed; preparation tests cover those transitions without live data changes.

## 11. Dumbbell Shoulder Press

**RELEASED after owner approval, 28 October.** The new exact exercise identity is `gainpath/dumbbell-shoulder-press-front-v1`. It tracks both arms together from the front; a title-only or arbitrary Admin-created ID remains guided/manual. Admin edits instruction media and Routine targets. Recognition is developer code.

### Admin and Member use

1. Admin Content → Exercise Catalog now contains the exact registered exercise, labelled **AI tracking · Front view**. The published **Shoulder Press Validation** Routine uses **3 sets × 8 reps / 60s rest**. One rep means both arms together; targets are stored in the Routine, never the analyzer. No existing Program/Routine version is overwritten.
2. Member opens the published Routine, or a future Program version containing it, and starts Dumbbell Shoulder Press. Accept camera consent and confirm front-view framing. The dedicated setup page shows the exact authored sets/reps/rest; press **Start camera**.
3. Face a stationary phone with both shoulders, elbows, wrists and hips visible and enough space above both hands. Hold both hands above bent elbows at shoulder height until calibration completes.
4. Press both arms overhead together, then lower with control to the starting position. Only the complete observed bilateral cycle counts. Partial movement is displayed separately. One arm, alternating arms or a held overhead position cannot complete a rep. Follow the rest and next-set controls.
5. Pause/background/repositioning or tracking loss interrupts the unfinished cycle and requires starting-position calibration. Recalibration guidance faces front; compact/large-text layout scrolls. Missing movement is not reconstructed.
6. Save the result and continue the Routine. Full/partial reps and tracked/unassessable time remain measured local evidence; manual sets remain separately self-reported. Program progress advances only when matching saved targets are completed. A failed save retries the same result.

### Limits, verification and release scope

The camera does not verify dumbbell load, spinal alignment or three-dimensional shoulder mechanics. **No form score is produced.** Zero in the legacy accuracy field is a storage sentinel, not an assessed score. Front-view metric schema 4 requires the exact registered exercise/organization, null form score and no curl/row metadata. Existing schemas 1–3 retain their wire formats. New backup list requests negotiate schema 4; older clients filter unsupported press sessions and dependent Routine checkpoints while advancing over scanned pages. Backup remains provisional and never accepted workout/reward evidence.

Verification: 765 passing tests (180 pose, 174 domain, 136 Mobile, 102 Admin, 173 backend), five existing Mobile skips, clean changed-code analysis, TypeScript checks, architecture and both app builds. Review-driven compact recalibration overflow was reproduced and fixed. Synthetic host replay: 250 reps, 1.7µs analyzer p95; this excludes phone inference/rendering and is not physical accuracy evidence. The first broad analysis included eight existing info lints; final changed-code analysis is clean. The initial cross-package fixture import failed architecture and was replaced with an app-local fixture. Earlier failed/initial evidence is retained.

Artifacts: `build/shoulder-press-20261028/verification.json`, `release-review.json`, `content-review.json`, `gainpath-shoulder-press-profile.apk`, private `web/` and compiled `server-ready/`. The owner-approved release is active. Both source-only backup/reporting Functions are ACTIVE with deployed source/runtime/environment/IAM verified; the other 68 Functions, Rules/indexes and earning configuration are unchanged. Private Admin served hashes and installed APK hash/signer pass; Xiaomi app UID/data directory/first-install identity and previous artifacts are preserved. One exact catalog entry plus Shoulder Press Validation blueprint/publication/audit were created once at 3×8 bilateral reps/60s; existing content, Programs and canonical Admin documents are unchanged. Verified synthetic Member + registered App Check discovery and schema-2/3/4 backup reads return HTTP200. No Member enrollment/progress/backup writes or workout acceptance/reward enablement were performed. The private Admin is at `http://localhost:7359/`; the exact new APK is installed/launched in place on the previously approved Xiaomi. Existing Program v1s were not edited to add the press. Backend compatibility was verified before client activation. Exact release readbacks and 49 extracted-package checks are recorded in `build/shoulder-press-20261028/release-verification.json`. Physical count/framing/latency/thermal acceptance remains pending. Signed-in browser smoke is blocked by disabled Work browser access; no live status-mutation test is claimed. Physical repetition accuracy, framing, latency and thermal acceptance are still pending; no phone performance claim is made.

### 28 October physical feedback: calibration/counting failure

**Shoulder Press framing fix — INSTALLED after owner request (28 October):** replaced the fixed 12%-image torso cutoff with a 24-pixel resolution guard and 4% degeneracy floor, preserving relative geometry, confidence, bilateral/dwell and interruption checks. Rejection feedback now distinguishes camera distance, unclear joints, delayed frames and positioning. Fresh verification: 196 pose + 136 Mobile tests pass (332 total; five existing Mobile skips), clean analysis, architecture, independent review and APK build. The exact corrected APK is installed/launched in place on Xiaomi7c4cbff with hash/signer, UID/data directory/first-install identity and previous APK preservation verified. Private Admin is unchanged; no backend, Rules/indexes/IAM, catalog/Program, account or reward change occurred. Physical counting needs owner retest; the original recording had no raw confidence/timing data, so this patch fixes the confirmed scale failure without claiming every recorded rejection is resolved. Evidence: build/shoulder-press-framing-fix-20261028/release-verification.json. Completed installation grants no additional mutation authority.
### Retest after the framing fix

Open the installed app and retry the same Dumbbell Shoulder Press Routine. Keep both hips and the full overhead hand path visible, hold the bent-elbow starting position until calibration finishes, then perform a controlled bilateral overhead-and-return cycle. A tiny body now asks you to move closer; an unclear joint names that joint; delayed frames report delay. Missing motion is still not reconstructed. Physical accuracy remains unaccepted until this phone retest; if counting still fails, record the new cue so the remaining gate can be identified.

### 11:53 retest and reliability correction (installed after owner approval)

**Shoulder Press reliability correction — INSTALLED after owner approval (28 October):** the exact prepared APK is installed/launched in place on Xiaomi7c4cbff. Installed hash/signer, UID/data directory/first-install identity and previous APK preservation are verified. The 11:53 recording showed calibration succeeded then reset during movement; the correction separates moving-arm projection from hip/torso stability, uses limb-relative overhead reach and bounded short-loss recovery with an observed bottom reset. Unfinished reps are discarded and rejected time stays unassessable. Squat behavior is unchanged. Preparation passed 215 pose +138 Mobile tests (353 pass; five existing skips), clean analysis, architecture, independent review and APK build. No backend/Admin/Rules/indexes/IAM, catalog/Program/account/reward mutation occurred. Physical count/framing/latency/thermal retest remains pending; approximate screen geometry is not raw per-frame confidence/time evidence. Release evidence: build/shoulder-press-reliability-20261028/release-verification.json. This completed approval grants no additional mutation authority.

| Pipeline stage | Comparison with squat |
|---|---|
| Capture and model | Same Android camera, latest-frame queue and BlazePose decoder. No new model or parallel queue. |
| Analysis input | Both receive fresh inverse-ROI landmarks before preview smoothing. |
| Calibration and movement | Press needs bilateral front-view geometry; squat uses one side. Press now allows natural shoulder elevation and changing arm projections. |
| Brief uncertainty | Press discards the incomplete cycle immediately, retains setup for at most500ms and requires100ms of observed bottom before rearming. It never reuses a hidden peak/return. |
| Hard interruption | Pause, stale/gapped frames, large body movement or model/camera changes require fresh calibration. Squat code is unchanged. |
| Save and progress | Authored targets/rest and measured-vs-manual history remain separate. No form score, reward or verified acceptance is added. |

The new app-level regression feeds changing projected arm lengths, shoulder elevation/narrowing and40ms delivery delay with watchdog ticks through the real session pipeline, then checks authored completion and one durable unscored result. Negative tests cover unilateral/alternating movement, hidden peak/return, long loss, body displacement and model changes. Review found a tracked-time accounting issue; a failing timer-interleaved test reproduced it, and both tick/recovery paths now reject that unavailable interval.

The approved reliability APK is now installed. Retry the same Routine and framing. Hold the starting position until Ready, press both arms overhead together and return with control. If a frame is briefly uncertain, return to the bottom and follow the restart cue. The recording cannot prove raw per-frame confidence or latency, so further phone validation remains required. Evidence and private frame review remain in ignored build paths; no camera data is uploaded.

### Standing calf raise reliability — installed 28 October

**Standing calf raise reliability — INSTALLED / private Admin ACTIVE after owner approval (28 October):** the exact repaired APK is installed/launched in place on Xiaomi7c4cbff and the matching private Admin is active at localhost:7359. Installed/served hashes, signer, UID/data directory/first-install identity and prior APK/Admin preservation are verified. The correction adds pixel-based framing, bounded foot-jitter calibration with coherent-drift rejection, filtered start/peak/held-return counting, interrupted-rep discard and heels-down rearm, responsive setup and camera resume. Preparation passed 237 pose + 175 domain + 149 Mobile + 103 Admin tests (664 total; five existing skips), clean analysis, architecture, review and both builds. Release evidence: `build/calf-reliability-20261028/release-verification.json`. Physical accuracy/framing/latency/thermal and browser visual acceptance remain pending. No backend/Rules/indexes/IAM, catalog/Program/account/reward mutation occurred; history and acceptance/reward holds are preserved. This completed approval grants no additional mutation authority.

The earlier local Admin label-only candidate (`build/calf-admin-label-20261028/`) is superseded by this repaired tracker candidate. Active catalog status controls Routine availability; Admin cannot create AI recognition by editing status. The exact developer-registered `gainpath/standing-calf-raise-side-v1` binding is unchanged. The exact repaired APK and matching private Admin are now active after separate owner approval; existing app data and browser Auth/storage are preserved. Refresh the private Admin page to load the new assets.

Use a published Routine containing Standing calf raise in the updated app:

1. Open the exercise and accept camera consent. The setup shows the Routine's exact sets, reps and rest; the analyzer contains no targets.
2. Put the phone securely side-on. Frame hips to floor, including the entire camera-facing knee, ankle, heel and toe outline in even light. Start on level ground with both heels down and straight knees; acknowledge this before Start camera.
3. Hold still until Ready. Raise both heels with control, hold briefly, then lower fully and hold briefly. Only the visible leg is measured; floor contact, bilateral effort, balance and load are not inferred.
4. Follow specific distance, foot-visibility, knee, toe/phone-motion or delayed-frame feedback. A brief loss discards the current movement and asks for heels-down rearm. Long loss, pause or changed camera/model input requires a new neutral hold; hidden movement never earns a rep.
5. Authored set completion starts the existing rest/next-set flow. End/Save writes the measured provisional local result; save retry preserves the same result. Manual/tutorial sets remain self-reported. Cloud workout acceptance and rewards remain disabled.

Retest on the updated approved phone: neutral hold with normal foot jitter, controlled full and partial cycles on each visible side, brief foot occlusion, stepping/camera movement, pause/background/resume, authored multi-set/rest and saved history. Check count accuracy, framing, latency and sustained-use temperature. Synthetic tests and the host scalar benchmark do not establish these physical outcomes. The exact installed profile APK and served private Web assets are retained alongside source hashes, the previous installed APK and the previous Admin bundle; no backend deployment or content publication occurred.

### 15:00 recording: repeated reset and zero count — local correction

**Calf recording reset correction — INSTALLED after owner approval (28 October):** the 15:00 recording reaches Ready/Raising/Lowering, then repeatedly recalibrates with zero reps; the toe-or-camera reset cue appears near 10.75s. Tests reproduce an overly narrow foot/leg projection guard and return gates that reject neutral jitter already accepted by calibration. The candidate bounds forefoot motion by axis, uses stable thigh plus bounded shin scale evidence, derives bounded start/return hysteresis from calibration noise, and retains specific reset feedback. Fresh 254 pose + 175 domain + 155 Mobile tests pass (584 total; five existing skips), with clean analysis/architecture, review and signed APK build. Release evidence: `build/calf-recording-fix-20261028/release-verification.json`; original local checks: `build/calf-recording-fix-20261028/verification.json`. Private video samples remain ignored; this is synthetic reproduction, not native raw replay or physical accuracy acceptance. The exact corrected APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install identity and prior APK preservation verified. Private Admin is unchanged; physical retest remains pending. This completed approval grants no further mutation authority. No cloud/content/reward change.

The recording proves the tracker reaches Ready and recognizes the beginning of movement, then discards the cycle. Around 10.75s it displays the old combined toe/scale reset instruction; the smoothed skeleton does not establish raw foot confidence, exact chosen side or input timing. New synthetic tests separately reproduce a bounded foot-index arc, projected shin shortening with a stable thigh, and a valid return obscured by neutral heel jitter. Twelve of 13 initial cases fail on the installed implementation; all 17 new pose and six new camera-session cases pass on the correction, alongside existing regressions. Neither the recording nor these tests establishes validated native phone accuracy.

The owner-approved exact `build/calf-recording-fix-20261028/gainpath-calf-recording-fix-profile.apk` is installed. Repeat the same Routine and framing. Start heels-down on level ground, hold until Ready, raise with control, briefly hold, then lower fully and briefly hold. Small bounded forefoot/leg projection changes should preserve the observed cycle. Larger movement reports Foot position changed or Leg view changed through the next setup hold. Brief weak tracking still discards the interrupted rep and requires heels-down rearm; hidden motion never earns completion. Test both visible sides/facing directions, stationary jitter, steps/occlusion, partial/full movements, pause/background/resume, authored sets/rest and saved history. Check physical counts, latency and sustained-use temperature. Published Programs and Member progress are preserved; manual sets remain self-reported and measured results remain provisional/local. Admin needs no further activation for this APK-only correction.

## 12. Bodyweight Reverse Lunge

**Reverse Lunge — RELEASED after owner instruction (28 October):** exact `gainpath/bodyweight-reverse-lunge-side-v1` tracking, schema 5 with selected front working leg, is active through the private Admin, in-place Xiaomi APK and create-only Reverse Lunge Validation Routine. Select the planted front leg before camera; the other leg steps backwards, lowers, and returns to feet-together standing for one observed rep. Targets are authored 3×8 per selected front leg/60s rest. Results are unscored provisional measurements; manual results stay self-reported. Fresh 956 tests (five existing skips), clean analysis/typechecks/architecture, review, both builds and 74 extracted-package checks passed. Two source-only compatibility Functions preserve runtime/environment/IAM; all 68 other Functions, Rules/indexes/config and existing content/Programs/Member progress are verified unchanged. Installed/served hashes, signer, UID/data directory/first-install identity and prior artifacts are verified. Member discovery and backup maximum 2/3/4/5 reads pass. Physical accuracy/framing/latency/thermal and browser visual UAT remain pending. Workout acceptance and rewards remain disabled. Evidence: `build/reverse-lunge-20261028/release-verification.json`. Completed release grants no further mutation authority.

Open Member Workout → refresh Routines → Reverse Lunge Validation → consent → select the FRONT working leg → Start camera. Keep that selected front foot planted and both legs/heels/toes visible to the side camera, on level ground with room behind. Start upright, feet together, until Ready. Step the other leg backwards, lower with control, then return upright with both feet together. Complete the selected leg’s authored sets; change leg in a separate session. The same measured session never merges left/right results. Pause/rest and tracking interruption discard unfinished movement and require a new neutral hold. Walking, a squat, forward steps and static split-squat bending are not intended to earn a reverse-lunge rep.

Review measured full/partial counts and tracked time, then continue the existing Routine/Program journey. No form score, balance/load verification, trusted acceptance or points are produced. Unsupported exercises keep tutorial/manual fallback. Existing Program publications are not edited to add this exercise; Admin can include the published Routine in future Program versions through normal authoring.

Release checks verify compatibility and synthetic counting, not physical accuracy. Owner UAT must cover both selected legs/facing directions, framing and occlusion, full/partial motion, steps/squats/wrong-leg rejection, pause/background/resume, multi-set/rest/save retry/history, latency and sustained-use temperature. Browser visual UAT remains pending because Work browser access is disabled. Previous client bundles, exact deployed source archives and private readbacks are retained in the ignored release directory; never replay completed mutation helpers.

### 18:31 recording: readiness correction — installed

**Reverse Lunge readiness correction — INSTALLED after owner approval (28 October):** the 18:31 recording never reaches Ready and keeps zero reps. Tests reproduce redundant hidden rear-foot/shoulder prerequisites, a reset-prone first-frame hold and staged-only backstep/descent assumptions. The candidate measures nine required joints, retains strict 0.7 confidence and 160° neutral knees, uses a bounded robust 800 ms fresh neutral hold with weak-frame pause and no rejected-time credit, and recognizes observed overlapping backstep/descent. Specific joint/view/neutral cues and selected-front-leg camera guidance replace generic feedback. Fresh 421 pose + 176 domain + 174 Mobile tests pass (771 total; five existing skips), clean analysis/architecture, review and signed APK build. Release evidence: `build/reverse-lunge-feedback-20261028/release-verification.json`; original preparation: `build/reverse-lunge-feedback-20261028/verification.json`. The exact corrected APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install identity and prior APK preservation verified. Admin/backend/content remain unchanged; physical readiness/count/framing/latency/thermal retest remains pending. Completed approval grants no additional mutation authority. Video samples are private; synthetic tests are not native raw replay. Schema 5, published Programs/progress and acceptance/reward holds are preserved.

The19.12s recording shows side-on standing and overlapping backward step/descent while cues alternate geometry and neutral rejection. The smoothed overlay does not reveal native visibility, chosen-side confidence or capture timing. The old geometry unnecessarily required the far heel/toe/shoulder; the corrected geometry requires the selected front shoulder/hip/knee/ankle/heel/toe and opposite hip/knee/ankle, and derives facing only from the selected foot. Missing required joints still reject measurement; optional hidden joints are not reconstructed. The neutral baseline is an actual observed inlier selected near the robust window center. Weak setup evidence pauses without adding time; weak working evidence still discards the unfinished cycle. A review-found between-bucket motion pulse that could falsely unlock Ready was reproduced and fixed before final verification.

The owner-approved correction is installed. Choose the same Routine and front leg. Put the camera on that selected front-leg side, keeping its heel-to-toe outline and both hips/knees/ankles visible. Stand upright with feet together until Ready. Follow specific joint, camera-distance, foot-outline or knee/stance feedback if blocked. Step the other leg backwards and lower with control, then return fully upright with feet together; the backstep and descent may overlap. A squat, forward/wrong-leg step, static split squat, missing evidence or interruption must not earn a reverse-lunge rep. Retest both sides/facing directions, neutral jitter, occlusion, full/partial movement, pause/background/resume, authored sets/rest/save/history and sustained-use latency/temperature. No new Admin/backend/content activation is needed. Scalar diagnostics can retain older values after a lifecycle reset; user-facing lifecycle feedback is correct. Physical accuracy remains unaccepted.

### 20:41 recording: selected-leg camera check — installed

**Reverse Lunge camera-check correction — INSTALLED after owner approval (28 October):** the 20:41 recording repeatedly reports left knee unclear and never reaches Ready. The side-on tracker incorrectly required the hidden far knee even though it measures the selected front-leg cycle. The candidate uses eight observed joints, removes all rear-knee angle/segment inference, and retains strict 0.7 required-joint confidence, selected-knee 160° neutral/depth, planted-foot/backstep/descent/return/timing/interruption guards. A portrait live camera check verifies the explicitly selected planted leg before counting; changing that choice resets setup and is locked after confirmation. Counts, guidance and saving are blocked before fresh Ready plus confirmation. Camera errors/retry and persistent selected-leg labels are tested. Fresh 462 pose + 176 domain + 178 Mobile tests pass (816 total; five existing skips), clean analysis/architecture, independent review and signed APK build. Release evidence: `build/reverse-lunge-retest-20261028/release-verification.json`; original checks: `build/reverse-lunge-retest-20261028/verification.json`. The exact corrected APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install identity and prior APK preservation verified. Admin/backend/content remain unchanged; physical readiness/count/framing/latency/thermal retest remains pending. Completed approval grants no further mutation authority. Private screen samples are not raw native landmark/confidence replay. Schema 5, existing Programs/progress and acceptance/reward holds are preserved.

The23.08s recording repeatedly names an unclear left knee, briefly starts a hold, then returns to rejection withzero reps. It cannot establish which anatomical leg was selected or raw landmark confidence. The painter uses0.5 confidence while measurement requires0.7, so green lines do not establish readiness. Requiring both knees from a side camera created an avoidable occlusion dependency; switching legs alone could not cure it. The corrected measurement uses selected front shoulder/hip/knee/ankle/heel/toe plus opposite hip/ankle. The far knee geometry/bend is unassessed and no missing joint is fabricated. Measured results remain provisional projected selected-front-leg cycles, not clinical two-knee form assessment.

The owner-approved APK is installed. Choose the intended front working leg, place that leg nearest the side camera, and open the live camera check. Keep its knee/ankle/heel/toe outline plus both hips and both ankles visible. Stand upright with feet together until the check says Ready, then press Confirm planted leg and begin. If the selected knee is unclear, adjust your angle/phone; choose the other front leg only if that is the leg you intend to train. Selection changes erase calibration; the chosen leg locks after confirmation. Moving during the camera check never earns a rep. The portrait preview shows the full body; camera errors are visible and Retry does not bypass neutral setup. Return from background/model changes still require fresh evidence or a new session. After confirmation, step the other foot backwards, lower with control and return fully to standing with feet together; the header and saved side match the confirmed choice.

Retest both legs/facings, selected-knee occlusion versus hidden far knee, side changes before start, full/partial and wrong-leg/squat/static/forward/jump rejection, pause/background/resume, retry, authored sets/rest and saved history. Phone accuracy/framing/latency/thermal remain unvalidated; tests are synthetic, not replayed raw video. No Admin/backend/catalog/Program activation is needed for this correction.

### 21:09 recording: hands-free start and visible stance — installed

**Reverse Lunge hands-free correction — INSTALLED after owner approval (28 October):** the 21:09 recording repeatedly rejects an overlapped rear ankle or asks for feet together; post-Ready touch confirmation was impractical away from the phone. The candidate removes that button and starts automatically after a verified neutral hold plus 3 seconds of continuous fresh neutral frames. Tracking loss, movement, stale/model/lifecycle or selected-side change cancels the countdown; timer-only waiting cannot start or fabricate reps. Small visible neutral ankle gaps up to 0.30 leg horizontally/0.08 vertically replace the narrow overlapping stance, with eight actual joints at 0.7 confidence and selected-leg depth/backstep/dwell/return guards preserved. Countdown/current feedback is visible over the portrait preview; voice respects existing mute settings. Fresh 550 pose + 176 domain + 184 Mobile tests pass (910 total; five existing skips), clean analysis/architecture, independent review and signed APK build. Release evidence: `build/lunge-handsfree-20261028/release-verification.json`; original checks: `build/lunge-handsfree-20261028/verification.json`. The exact hands-free APK is installed/launched in place on Xiaomi7c4cbff with installed hash/signer, UID/data directory/first-install identity and previous APK preservation verified. Admin/backend/catalog/Programs remain unchanged; physical readiness/count/framing/latency/thermal retest is pending. Completed approval grants no additional mutation authority. Private screen samples are not raw native confidence/landmark replay; no hidden ankle is inferred. Schema 5/history/Member progress and acceptance/reward holds are preserved.

This correction supersedes the earlier Confirm planted leg and begin step. That button forced the Member to return to the phone after achieving camera readiness. The21.81s recording also alternates unclear left rear ankle and feet-together cues while Right front leg is selected, with one brief59%hold. This supports an occlusion/setup conflict but does not reveal raw native visibility or timing. A green skeleton alone does not establish the0.7 measurement confidence gate. Both ankles remain essential for observed backward travel and selected-side identity; missing coordinates are never substituted or inferred.

The owner-approved hands-free APK is installed. Select your intended camera-facing front working leg before stepping away. Put the phone at your side but turn slightly toward it, and leave a small comfortable gap between your feet so both ankles can be seen. Keep the selected knee/ankle/heel/toe outline and both hips visible. Avoid a long split stance or raised foot. Stand still; the over-preview feedback shows the blocking joint or the3-second starting countdown. The app then starts automatically: no second tap is required. Enabled voice may announce countdown/Begin; mute remains respected. Movement, lost visibility or backgrounding resets setup/countdown. Changing front-leg selection before automatic start clears setup; after start it is locked for that session.

Perform the reverse lunge and return to the same calibrated starting stance with the small gap between reps. Fixed-baseline rear-ankle travel, selected-front-knee bend, hip descent and sustained observed return are still needed; widening neutral stance does not itself earn a rep. Test both selected legs/facings, small gaps versus split stances, occlusion/countdown reset, timer-only/model/lifecycle/side changes, wrong-leg/forward/squat/walking/jump rejection, full/partial movement and multi-set/rest/save/history. Phone readiness/count accuracy, framing, latency and sustained-use temperature remain unvalidated. No new Admin/backend/catalog/Program activation is needed.


## Standing Lateral Raise — released, 28 October

The new developer-registered variant is `gainpath/standing-lateral-raise-front-v1`. Both arms move together in the front view. A fresh arms-down hold calibrates automatically; raising out to shoulder height and returning fully to the sides counts one repetition. Slight elbow bend and bounded inward resting arms are supported. Bilateral start/peak/return dwell, raw/filtered agreement, torso/limb projection, frame freshness, confidence and interrupted-repetition guards reject missing evidence. This measures projected movement; dumbbell load, standing posture and three-dimensional shoulder mechanics are not verified, and no form score is produced.

Member use: open the exercise through a published Routine or scheduled Program day, accept the front-view camera notice, review the authored sets/reps/rest and select **Start camera** while near the phone. Step into view with both shoulders, elbows, wrists and hips visible and room for both arms at shoulder height. Hold arms by your sides until **Ready**; no touch confirmation is needed after taking position. Raise both arms out to shoulder height with a slight bend, then lower fully with control. Both arms together count as one rep. If tracking is interrupted, return both arms down and hold to rearm; the unfinished repetition is discarded. Existing Pause/Resume, rest, next set, save retry, summary and next scheduled day flow are reused. Voice remains controlled by existing preferences.

Admin use: use the exact catalog variant and assign it to reusable published Routines using the existing authoring flow. Configure order, sets, reps and rest there. Admin cannot create a detector by changing a title or tracking flag. Existing Program versions and Member progress remain preserved; creating a new version is separate from changing an enrollment's saved snapshot.

Schema 6 preserves unscored measured results and distinguishes them from self-reported sets. Local persistence, Routine reconciliation and provisional cloud validation support the exact variant. Older backup readers retain negotiated compatibility and default schema maximum 2; the new client requests 6. Verified cloud workout acceptance and rewards remain disabled.

Release status: approved release is complete. **Standing Lateral Raise — RELEASED after owner approval (28 October):** exact `gainpath/standing-lateral-raise-front-v1`, front-view bilateral arms-down → shoulder-height → arms-down tracking and schema 6 are active through the matching private Admin, exact in-place Xiaomi7c4cbff APK and create-only Standing Lateral Raise Validation Routine at 3×8 bilateral reps/60s rest. Readiness is automatic; bounded inward resting arms and interruption discard/neutral rearm are supported. Targets remain Routine-authored; measured results are unscored provisional evidence. Preparation passed 1,340 checks (five existing Mobile skips), analysis/typechecks/architecture, independent review and both builds; 117 exact-package checks passed. Two source-only compatibility Functions preserve runtime/environment/IAM; all 68 other Functions, Rules/indexes/reward config and existing catalog/Routines/Programs/Member progress are verified unchanged. Served/installed hashes, signer, UID/data directory/first-install identity and prior artifacts are verified. Member discovery under Rules/App Check and backup maxima 2/3/4/5/6 reads pass. Physical count/framing/latency/thermal and browser acceptance remain pending. Load/standing/form score, verified workout acceptance and rewards are not enabled. Evidence: `build/lateral-raise-20261028/release-verification.json`. Completed approval grants no further mutation authority.

Open **Member → Workout → refresh Routines → Standing Lateral Raise Validation**. Accept the front-view camera notice, review the 3×8 bilateral targets and 60s rest, and select **Start camera**. Hold arms by your sides until Ready, then raise both arms out to shoulder height and lower fully. Existing published Programs were preserved; Admin can add this Routine through a new Program version. Previous source archives, Admin bundle and installed APK are retained for recovery; never replay completed mutation scripts.

Local verification: 1,340 checks pass (622 pose, 177 domain, 200 Mobile, 103 Admin, 238 backend; five existing skips), clean analysis/typechecks/architecture, independent review and both candidate builds. The host-only analyzer benchmark measured median 1.0 µs/p95 1.6 µs over 43,200 sampled frames; it does not measure phone camera, inference, rendering or thermal performance.
