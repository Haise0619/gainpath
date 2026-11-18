# Module 13 — AI Content Planner & AI Member Outreach

2026-11-18 · Local implementation accepted; subsequently the owner approved and deployed the three existing production entrypoints. **Code deployment and private Admin activation are verified; real Gemini/user-flow acceptance is pending the Admin login and test-recipient decision described below.** Earlier request budgets remain unchanged.

## Approved production deployment checkpoint

Only `module13AdminCommand`, `module13MemberCommand` and `fypDatasetCommand` were updated. Existing `GEMINI_API_KEY` was bound to the Admin callable; no Secret was created or changed. Exact deployed source, service settings, existing IAM/App Check, Rules/indexes and the other **76 Functions** were verified preserved. The apparent Admin baseline mismatch was reconciled to the previously verified 15-second-timeout release archive (`d49f4618…`), before deployment. Rollback archives/configurations are retained under `build/module13-admin-ai/release`.

The original private Admin URL **http://localhost:7359/** now serves the new bundle with registered existing App Check configuration and a verified served SHA256 `2bb2501781dfbb7f05b93fe1f6cd615666daa823333632849c9dc362df67cc6e`. Previous bundle is retained in `release/admin-before`. No public Hosting was changed.

Post-deployment checks: dedicated Member HTTPS access 200; current four-purpose consent read 200; the Member is correctly denied Admin AI access (403). Normal Admin service reads against live Firestore pass and return one legitimate ranked member; signed-in normal Admin HTTPS/browser acceptance remains pending. CLI-based temporary Admin token signing was denied `iam.serviceAccounts.signBlob`; no IAM permission change was attempted.

The user stopped Computer Use with physical Escape. Browser control was stopped and not resumed in that turn. The user was asked to log in to the ordinary Admin directly and confirm whether browser acceptance may resume; no password was requested.

The existing dedicated member `m13-e2e-20261117` has all four current permissions. All seven existing test session sources have no candidates outside the seven-day cooldown. A provider-free production preflight therefore abstains. No cooldown was cleared, no records overwritten and no training/profile/Consent data was changed. A separate pending request asks whether one additional clearly marked TEST member with no Workout data may be created, to test initial-profile Coach Outreach without consuming extra automatic-generation requests. Until that approval, no new recipient is created and no Outreach inference is attempted.

The newly approved **3-request budget remains 0/3 used**, with no Generate request issued. The post-deployment backend regression passes **199 tests**. Planner live generation, Apply using real model results, Outreach Send, actual production receipts and screenshots are **not yet accepted**. Existing screenshots below remain labeled local fixtures/emulator captures.

[Deployment verification](../../build/module13-admin-ai/release/release-verified.json) · [Read-only compatibility](../../build/module13-admin-ai/release/compatibility-readonly.json) · [Admin activation](../../build/module13-admin-ai/release/admin-activated.json) · [Request budget](../../build/module13-admin-ai/release/request-budget.json) · [Acceptance checkpoint](../../build/module13-admin-ai/release/acceptance-checkpoint.json) · [Post-deployment regressions](../../build/module13-admin-ai/release/backend-regression.log).

## Delivered behavior

Recommendations now groups Overview, AI Content Planner, AI Member Outreach, Delivery Issues and Exercise Guidance Insights. The existing `/console/recommendations` destination remains valid. No new History or Earlier Records entry was added.

### AI Content Planner

- Exercise, Routine and Program are supported. Existing Program management was found and reused.
- Admin chooses 7/30 days (30 by default), optional instructions, then explicitly selects Generate. Page opening performs no Gemini call.
- Backend reads active Exercise Catalog, published Routine compositions, current Program draft names, and validated synced workout summaries. Aggregates include muscle/category coverage, exercise/routine usage and goals within the analyzed consenting active-member population.
- Training-derived provider contributions require both Exercise Insights and External AI Inference permissions, using the stricter history boundary. Fictional cohorts, synthetic observations, dedicated Module 13 TEST identities and marked test backups do not enter activity statistics. Top-active ranking itself uses the existing Insights permission; sending additionally requires all recommendation purposes.
- Gemini has a separate structured-draft contract. Default prompt asks for three concise suggestions; output must contain 3–5. Existing and duplicate normalized names, unknown Exercise/Routine IDs, unsupported difficulty/category, invalid prescriptions and invented evidence keys are rejected. Real evidence text is joined on the server.
- Cards show name, description, difficulty, muscles, equipment, duration, AI rationale and actual catalog/usage evidence. Admin can expand details, dismiss, regenerate, or Apply.
- Apply passes an in-memory create seed to the original Exercise, Routine or Program screen. It does not save or publish. Exercise receives name, description, ordered instructions, category, equipment and difficulty; unsupported new tracking is never enabled. Routine receives real catalog IDs, current execution modes/revisions and sets/reps-or-seconds/rest, description/goal and duration. Program receives a four-week editable schedule using actual published Routine IDs.
- Admin retains normal media selection, edits, Save and Publish. Image/video creation is not performed by AI.

### AI Member Outreach

- Top 10 is ranked by valid completed workout summaries within 7/30 days; routine days with a known completion timestamp are an auxiliary count. These are descriptive synced observations, not verified physical performance. No login tracking was added.
- Analysis shows current goal/experience, workout count, recent/frequent exercises, completed routine days, muscle-group usage and existing recommendations. Missing measurements are omitted; there is no invented form/risk score.
- Generate checks fresh Admin authority, member state/identity and four purpose permissions. It reuses existing qualified Tutorial/Routine/Coach candidates and anonymous contextual features. Gemini returns up to one candidate per type and a short editable message. There is no forced quota of three results and no Rules-generated prose represented as Gemini output.
- Unknown IDs, duplicate kinds and unsupported evidence references are rejected. Medical claims are disallowed by prompt and a bounded output check. Model prose remains a draft for Admin review; reference validation is not a general factual-verification model.
- Server-owned previews expire after 30 minutes and are bound to the requesting Admin, recipient and consent snapshot. Only selected messages are submitted to Send; the browser cannot substitute a target.
- Send rechecks member identity, Admin access, current permissions, selected period, exact candidate context and destination, plus the existing seven-day fatigue/cooldown. Changed profile/features or targets require a new preview. Exact retry does not duplicate delivery.
- Recommendation, existing Inbox notification, receipt and fatigue update commit atomically through the existing canonical lifecycle. Saved source is `suggestion.source.kind=admin_outreach`, sender is `suggestion.outreach.sentBy`, editable message is `suggestion.summary`, and method is `suggestion.ai.method=gemini`. Created/sent/delivery times use existing canonical fields.
- Member uses the same For You cards, detail sheet, Notification Center and target navigation. Admin Overview reads the same canonical collection, and Details displays source/sender/method/status.
- Coach candidates retain current verification, specialty, shared branch and continuous **60-minute** availability checks. No booking/payment is created. Admin preview explains Basic/Premium booking requirements; existing Member upgrade restrictions remain in place.

The deployed automatic `rankedCandidateIds` ranking contract and automatic approval-free behavior were not changed.

## Grounding

The current Gemini transport has no Google Search tool or grounding-metadata parser. Google documents separate Search Grounding behavior and billing; this task did not enable paid tools or change the configured model. Planner currently uses GainPath catalog/authorized aggregates and Gemini's generation capabilities. Its UI states that web research is not enabled; Sources remain empty instead of presenting invented references.

Primary references: [Google Search Grounding](https://ai.google.dev/gemini-api/docs/google-search?hl=en), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing).

## Implementation

- `functions/src/modules/recommendation/admin-ai-assistance.ts`: draft/outreach contracts, bounded adapter composition, validated activity decoding.
- `functions/src/modules/recommendation/admin-ai-service.ts`: current data aggregation, analysis, previews and Send orchestration.
- Existing `canonical-recommendation-admin.ts` / `canonical-recommendation-callables.ts`: new operations on the existing Admin callable, current Auth/App Check checks retained.
- Existing `canonical-recommendation-lifecycle.ts`: optional outreach provenance and atomic delivery using existing receipt/Inbox/fatigue contracts.
- `apps/admin_web/lib/features/recommendation/application/admin_ai_repository.dart` and `admin_ai_drafts.dart`: authenticated commands and create-only seeds.
- `apps/admin_web/lib/features/recommendation/presentation/admin/admin_ai_pages.dart`: two responsive Admin pages, loading/error/empty/success states, preview selection and messages.
- Existing Admin sidebar, three content screens and canonical Details parser/panel: navigation, prefill and source/sender display.

The backend uses bounded scans (250 member/catalog records, 200 backup heads per member, 300 canonical recommendations for a member analysis). Exceeding a bound reports an error rather than silently showing partial totals. Provider catalog examples are bounded; full catalog names still participate in duplicate checking. No queue worker, new collection for published recommendations, second Inbox, RAG system or analytics platform was introduced. `adminAiPreviews` holds only server-owned transient previews; no TTL policy was deployed.

## Verification evidence

| Check | Result |
| --- | --- |
| Backend focused regressions | 199 passed across 8 files |
| Source and test TypeScript | Passed |
| Auth + Firestore Emulator | 4 passed on dedicated `demo-gainpath-admin-ai` |
| Admin Flutter regressions | 50 passed, including real existing form Apply/edit/Save, manual Routine cover selection, Program prefill, send and details |
| Member Flutter regressions | 44 passed; existing recommendation navigation/consumer and Booking composition |
| Member Emulator-output rendering | 1 passed; three cards/details and actual Notification Center notice-to-details navigation |
| Admin static analysis | Passed; final verification artifacts recorded alongside logs |
| Android Debug APK | Built; not installed |
| Admin Web Release | Built into an independent local output directory; not activated |

Independent read-only review identified external-consent aggregation and seven-day candidate-context gaps. Both were fixed and covered by regressions; follow-up review found no remaining critical findings in its focused scope.

Implementation commit: `c504cbf49e2532a6b192dc01de1023a31b3633ae` (`feat(module13): add AI content planner and member outreach`). Unrelated Mobile, logo and other working-tree edits were preserved; only the task's Sidebar hunks were staged. This integration builds on existing Module 13 work already present in the shared checkout.

The Web build reports a Cupertino font-asset warning; the new pages use Material icons and compilation succeeds. The first relative-output Web attempt failed in the Windows shader compiler; the verified release uses the absolute independent output directory. No current served Admin bundle was replaced.

Emulator acceptance uses actual Auth identities and Firestore transactions with the existing command handler, canonical lifecycle, receipts and Member resolve. Gemini responses and candidate adapter data are explicit fixtures; this is not a deployed HTTPS/production-provider acceptance claim. Existing real-runtime candidate tests separately retain Coach qualification/60-minute and automatic recommendation coverage.

Logs and artifacts (ignored build evidence, retained locally):

- [Backend](../../build/module13-admin-ai/backend.log), [source types](../../build/module13-admin-ai/types-source.log), [test types](../../build/module13-admin-ai/types-test.log)
- [Emulator](../../build/module13-admin-ai/emulator.log), [actual local deliveries](../../build/module13-admin-ai/emulator-delivered.json)
- [Admin regressions](../../build/module13-admin-ai/admin-regression.log), [Member regressions](../../build/module13-admin-ai/member-regression.log), [Member rendering](../../build/module13-admin-ai/member-renders.log)
- [Admin analysis](../../build/module13-admin-ai/admin-analysis.log), [Web build](../../build/module13-admin-ai/admin-web-build.log), [Android build](../../build/module13-admin-ai/android-debug-build.log)
- [Final machine-readable verification and artifact hashes](../../build/module13-admin-ai/verification.json)

### Screenshots

These are actual Flutter widget captures with explicit synthetic fixture data or actual local Emulator delivery exports. They are not production screenshots, real Gemini results or phone UAT. Offline Admin screenshot fonts substitute existing Barlow assets for its Google Fonts families; production typography is unchanged. Missing target imagery shows placeholders.

- [Planner](../../build/module13-admin-ai/screenshots/planner-routine.png)
- [Exercise prefill](../../build/module13-admin-ai/screenshots/exercise-prefill.png)
- [Routine prefill](../../build/module13-admin-ai/screenshots/routine-prefill.png)
- [Narrow screen / 150% text](../../build/module13-admin-ai/screenshots/planner-narrow-large-text.png)
- [Active members](../../build/module13-admin-ai/screenshots/outreach-members.png)
- [Outreach preview](../../build/module13-admin-ai/screenshots/outreach-preview.png)
- [Admin outreach source/details](../../build/module13-admin-ai/screenshots/admin-content-ranking.png)
- [Member Tutorial](../../build/module13-admin-ai/screenshots/member-content-details.png)
- [Member Routine](../../build/module13-admin-ai/screenshots/member-routine-card.png)
- [Member Coach](../../build/module13-admin-ai/screenshots/member-trainer-card.png)
- [Member Inbox](../../build/module13-admin-ai/screenshots/member-inbox.png)

## Original rollout scope and outstanding acceptance

The following was the original proposed scope. The owner has since approved and completed items 1–3; the new three-request budget is approved but unused. Current blockers and precise status are recorded at the top of this report:

1. Update existing `module13AdminCommand` source with the new operations and **bind the existing `GEMINI_API_KEY` Secret**. This is a new Secret binding on this callable, not a new credential. No IAM, Firestore Rules/index or Membership/payment changes are required.
2. Update `module13MemberCommand` and `fypDatasetCommand` readers with the same optional outreach-source validation so production Member and unified Admin can read the new records. Keep the same dataset routing and current service settings. Current automatic backup event functions do not consume the new Admin preview API and need no new inference behavior. If packaging a shared archive, separately verify unchanged ranking sources/registered entrypoints and service configuration before deployment.
3. Serve the prepared Admin Web client only after backend compatibility is present. Existing Mobile cards/destinations require no new native installation for this feature.
4. Obtain a fresh, explicitly bounded real Gemini request budget. Suggested acceptance: one Exercise generation, one Routine generation, one Outreach generation (Program can be an optional fourth). Do not use the exhausted earlier ledgers or claim fixture token values are measured live usage.
5. With approved dedicated test identities/data only, verify true HTTPS callable invocation, real model output/latency/tokens, existing Add forms' media upload/Save/Publish, and one selected Outreach Send. Test-account activity is deliberately excluded from real Top 10; an approved clearly labeled local/emulator activity fixture can demonstrate that table without relabeling artificial workouts as real performance. Normal production Admin can inspect any approved delivered test recommendation.
6. Reconfirm actual availability and expiry-sensitive Coach navigation without payment. Retain all written test paths/receipts and produce an inventory before any cleanup. No cleanup was performed here.

The new features are deployed, but **real Gemini generation and production Outreach delivery remain unverified** pending the above acceptance prerequisites. Local fixture latency/token values are not real model measurements.
