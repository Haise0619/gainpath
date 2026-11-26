# 5.2.9 and 5.5.6 User acceptance testing

## Existing acceptance evidence

The dated records include bounded owner checks, operator observations, fixture tests and separately approved sandbox activities. A complete anonymized Member/Coach/Admin participant roster, consent record, individual task sheets, questionnaires and scored study were not located for this code snapshot. Dates use Asia/Kuala_Lumpur where the associated report supplies that context.

| Date / role in evidence | Actual result | Acceptance boundary and reference |
| --- | --- | --- |
| 19 Oct 2026, project owner | Manual PASS for the corrected Member chat title, visible Coach name and truthful loading state after a dated Android install | Narrow retest for identified UI defects. `docs/architecture/module-9-uat.md:95-105` |
| 19–24 Oct, owner-authorized Member and Admin operator flows | Three distinct hosted Billplz Sandbox bills cleared through signed callbacks, totaling RM307. Verified Basic purchase, early renewal extending existing expiry by exactly 30 days and separate Premium purchase. Read-only Admin displayed expected scope and settlement labels | Provider simulator and actual Firebase callbacks for the three approved samples. Android PDF with paid fixtures, refund execution, forged/late callbacks and recurring payments were not exercised. `docs/integration/module4-sandbox-purchase-renewal-uat-results-2026-10-24.md:5-41` |
| 30 Oct, owner-assisted Member on Xiaomi | Reviewed empty/populated Progress, Program links, a real partial workout showing 8 full and 7 partial reps in 47.8 elapsed seconds, Android PDF Save/Open, observed offline report and backup receipts. Multiple UI issues were reported | Prior artifact observation. Follow-on fixes and 50 Flutter/6 native checks are dated separately. Reconnect retry, populated comparison taps, broader accessibility and final artifact retest remain pending. `docs/integration/module5-xiaomi-final-uat.md:1-36` |
| 4–5 Nov, authorized Admin and synthetic FYP cohort | Controlled live Admin/API and browser cases recorded shared fixture reads, queue/inbox/delivery and branch reporting behavior | Evidence from one permission-bound cohort and dated Admin bundle. Native mobile verification and wider real-user consent/compliance remain open. `docs/integration/gainpath-fyp-live-integration.md` and `gainpath-unified-admin-integration.md` |
| 12–13 Nov, operator and test harness | Member/Coach/Admin demo flows exercised through widget fixtures and Firestore emulator, with two application builds and known suite failures documented | Local integration acceptance, separate from participant UAT. `docs/qa/fyp-demo-integration-acceptance.md:37-71` and `progress-checkpoint-2026-11-13.md:13-41` |
| 18 Nov, provider acceptance checkpoint | Restricted Gemini recommendation acceptance recorded for the approved evaluation/release path | System-level AI evidence for the recorded configuration. Usability and suitability for broader Member populations need separate evidence. `docs/integration/module13-final-gemini-acceptance-20261118.md` |
| Mixed dates, role-based procedure | `docs/architecture/module-1-uat.md`, `module-8-uat.md` and `module-10-uat.md` provide procedural gates and some deployment/local verification evidence | A checklist alone establishes expected operations. Role-based manual acceptance requires a recorded outcome for each actual attempt |

## Proposed final UAT package — not executed

Recruit a small purposive sample, aiming for 4–6 adult gym Members across novice and experienced users, 2–3 fitness Coaches and 1–2 Admin operators. Record role and relevant experience by participant pseudonym. A given person may serve multiple roles only when disclosed. Obtain informed participation and separately request movement recording consent. A participant may stop any session. Use synthetic identities and staged data. Task sheets must not contain passwords, payment credentials or personal records. Leave history/account changes and provider side effects to sandbox and disposable accounts, and restrict physical movement tasks to exercises participants can safely perform. Device recordings should be permission-scoped and deleted according to the consent retention period.

### Session procedure

1. Record build/commit, app version, OS/browser, viewport, timezone, device orientation and whether the fixture is emulator, simulator or another approved environment. Verify the required accounts and stage test data. Give only task goals and any exercise safety/setup instructions.
2. Start an unaided attempt. The facilitator records time, success, help, error, retry, recovery and blocker severity. If the participant requests help, record it and let them continue. Retain elapsed time separately for assisted attempts.
3. Run the role's checklist. Repeat a failed case only after logging the original observation. Document outcome per attempt, with a separately labelled retest.
4. Collect the five-point questionnaire and qualitative feedback. Redact screenshots. Log limitations and any deviations from the planned exercise, permission or hardware conditions.

| ID | Role and task | Observed completion checklist |
| --- | --- | --- |
| U-M01 | Member signs in, completes or reviews fitness/profile and legal preferences | Can identify current account, save and reopen within own scope, and explain visible privacy/consent choice |
| U-M02 | Member starts approved AI exercise/routine and completes or safely pauses a set | Can follow positioning cue, identify rep and correction state, save once, resume staged interruption and find consistent totals in History |
| U-M03 | Member checks points and opens an eligible reward or plays a motion game | Can distinguish tracked attempts, earned points, eligibility, locked rewards and clearly labelled test redemption, and explain result once |
| U-M04 | Member compares plan terms and walks through permitted Sandbox checkout | Can explain payable amount/expiry before action, distinguishes redirect and pending from cleared, reaches updated entitlement only after confirmed clearance |
| U-M05 | Member asks a routine question, checks a recommendation and discovers a Coach | Finds actionable fitness response or recovery state, distinguishes advice and recommendation source, selects an available slot, recognizes checkout and confirmation state |
| U-C01 | Coach opens shared account, edits profile or reviews certification status | Saves/reopens fields and explains visibility/pending authorization |
| U-C02 | Coach reviews weekly availability, creates a disposable exception, opens roster | Understands branch/date and blocked interval, avoids overlap, sees corresponding staged Member booking effect |
| U-C03 | Coach opens assigned confirmed booking, answers a question and follows permitted consultation action | Sees only relevant booking, finds actual state and notes/completion status, understands retries/pending state |
| U-A01 | Admin filters Member/Coach, reviews profile/publication and edits/publishes one test entity | Can navigate correct role/scope, confirms change with other-role visibility and leaves unrelated records intact |
| U-A02 | Admin opens financial transaction and operational reporting | Distinguishes finance/refund/provider status, reconciles report scope and exported totals |
| U-A03 | Admin opens AI review queue and tests an authorized fixture decision | Can explain source and limitations, identify destination and scope, preview a decision without initiating real generation or deliveries |

### Five-point questionnaire

Use 1 Strongly disagree, 2 Disagree, 3 Neither, 4 Agree, 5 Strongly agree and an explicit Not applicable option. Ask each applicable participant to rate these statements:

- I found the tools needed for my role.
- I understood whether each requested change had completed.
- I understood how to recover when a task did not complete.
- The timing and language of workout feedback helped me identify the next movement. Member exercise only.
- I could tell which membership, payment, schedule or approval terms applied to my task. Applicable roles only.
- I could identify when information came from a measurement, automated suggestion or manual entry. Applicable roles only.
- Text, controls and navigation were readable and usable in my tested environment.

Ask what was most confusing, what they expected to happen, where they needed help, and what change would have made a measurable difference. Record issues in the fields below. Ask for positive and negative feedback without prompting for a particular score.

### Recording, acceptance and analysis

Issue template fields: participant code; role; date; task ID; build/device; synthetic fixture ID; attempt number; preconditions; action; expected and observed outcome; latency; assistance level; severity; masked evidence; retest outcome.

Proposed acceptance requires every priority-1 role task to complete without a blocking defect in the tested environment and no observed authorization or data consistency failure. Report unaided and assisted task completion separately. Record planned, attempted, completed, assisted, failed, skipped and blocked counts, with exact denominators. For elapsed tasks report median and range among completed attempts and present failures separately. Present Likert counts by item and role with median and spread for small groups, and list Not applicable/missing value counts. Summarize recurring qualitative themes with anonymized excerpts only when permitted. A small purposive sample supports usability findings in those conditions; it does not estimate population-wide satisfaction.

[Blank participant task-result template](evidence/datasets/UAT_TASK_RESULT_TEMPLATE.csv).
