# AI Content Planner — Content Type Correction

2026-11-18. **Deployed after owner approval.** Only module13AdminCommand was source-updated, and the matching ordinary private Admin is active at localhost:7359. No real Gemini call, business-data write, Save/Publish, Secret/config change or Computer Use occurred. Existing GLbg binding and registered App Check inputs are preserved.

## Production deployment verification

The approved source-only deployment replaces exactly four files (two Planner modules and source maps) in the captured live baseline archive. Deployed source hash is fdbefeb40269902ddd14919472cb50834e18291492fee33439cea32e6d645766. Exact source, service settings, Secret binding, IAM, Rules/indexes and all 78 other Functions were verified. Rollback archive/configuration and previous Admin files are retained under build/planner-types-fix/release.

The matching Admin release was rebuilt using existing registered private App Check/Firebase configuration. The old localhost service was no longer running; the existing tools/admin_web/serve.cjs was restarted hidden. HTTP-served main.dart.js SHA256 is 7147dfe5321220db4f1a11e9284fa318a90573fc074c6485c4cd01688ab56dbe. No public Hosting deployment occurred. Reload the ordinary Admin to discard old in-memory drafts. Signed-in page acceptance and real Gemini validation remain for the owner to perform manually; no inference budget was consumed during deployment.

[Backend verification](../../build/planner-types-fix/release/release-verified.json) · [Exact package delta](../../build/planner-types-fix/release/package-verification.json) · [Client activation](../../build/planner-types-fix/release/admin-activated.json)

## Root cause

1. Exercise, Routine and Program shared one required-field schema, including durationMinutes, exercises and routineIds. The validator checked these IDs but did not prohibit those fields inside Exercise.
2. Duplicate checking normalized complete names only. “Beginner Squat Flow” differed from “Squat” and passed. Provider input truncated catalog examples to 24, weakening novelty analysis.
3. One generic card rendered all fields, exposing Routine prescriptions and IDs inside Exercise.
4. whyRecommended was preserved by the server, but its prompt allowed restating statistics; the UI then rendered those statistics again. There was no actual backend overwrite of the AI explanation.
5. Program Apply hardcoded Mon/Wed/Fri for four weeks rather than preserving an explicit generated weekly schedule.

## Corrected contracts

| Type | Provider output and validation | Apply |
|---|---|---|
| Exercise | 3–5 independent movement definitions; canonical name/aliases, optional declared variant and mechanical distinction, category, primary muscle, equipment, difficulty, ordered instructions, contentGap, rationale and valid evidence references. Rejects Routine duration, sets/reps/rest, exercise lists and Routine IDs. | Original Add Exercise; non-AI videoGuidedTimed seed. Name/category/equipment/difficulty/instructions prefill. Existing form has no dedicated muscle field: primary muscle is retained in description. No invented media or tracking capability. |
| Routine | At least 2 distinct real catalog IDs; current revisions/execution modes joined server-side; bounded sets, reps-or-seconds, rest and plausible duration. | Original Add Routine; preserves actual IDs, execution modes, revisions and prescriptions; manual cover remains available. |
| Program | Exactly 4 weeks to match existing creation form; weekly template of unique weekdays, valid published Routine IDs, routineDay=1 for current flattened published sessions, supported category. Other days are rest. | Original Program editor; repeats chosen weekly template, preserves weekdays/routine IDs and existing category/muscle semantics. No automatic progression of prescriptions is claimed. |

Each type now has a separate Prompt, Structured Output Schema and details widget, while keeping the same bounded Gemini transport and authorized data services. The Outreach schema/prompt and automatic ranking contract are preserved.

The complete active catalog, saved aliases, muscle/category/difficulty coverage, real active gymEquipment names, authorized member goals and validated workout usage are supplied. Catalog equipment requirements are not treated as proof of gym inventory. Empty inventory is explicitly unknown. Oversized complete input fails before inference instead of silently truncating. Existing scan/input bounds remain.

Known alias normalization and cosmetic-name removal reject Squat / Bodyweight Squats / Air Squat / Beginner Squat Flow and Upper Press / Dumbbell Shoulder Press collisions. Existing aliases and within-batch movement identities are also checked. A distinct variant must identify its actual base and provide a meaningful distinction. This is a conservative lexical/known-alias guard, not a universal semantic-equivalence classifier; Admin review is still required for unknown synonyms and exercise safety.

AI rationale, interpreted Content Gap and server-derived Supporting Evidence are separate. Evidence keys must exist and repeated evidence text is deduplicated. Reference validation does not prove every model-written factual claim; the UI presents a reviewable draft.

## UI

Compact purple/neutral cards; two columns at >=1000px available content width, one column on narrower screens or enlarged text. Soft tags replace heavy black chip borders. Exercise shows movement definition/instructions, Routine shows workout composition, Program shows weekly schedule using readable Routine names. No internal IDs are displayed in the details. Instructions are numbered; Preview details is collapsed. Apply only opens existing create forms.

## Grounding

No Search tool is configured in the current provider. Google's current pricing table lists Gemini 3.5 Flash-Lite Free Tier API Google Search Grounding as unavailable (AI Studio testing is a separate footnote). No paid service was enabled. Sources remain empty and the page states web research is disabled. [Official pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.5-flash-lite).

## Verification

- **210 Backend tests / 9 files passed**, including all prior 201 cases plus type/alias/schema/full-catalog cases. Existing Gemini timeout/fallback, automatic backup recommendation, Outreach/Send/cooldown, exercise and Program regressions pass. Fetchers are mocked; no real Gemini usage.
- Source and test TypeScript checks pass.
- **8 Flutter tests passed**: three existing Add forms/Apply, chosen Program weekdays and 4-week mapping, Exercise non-AI execution, local Routine cover/save (in-memory only), Outreach fixture workflow, wide two-column geometry, hidden cross-type fields, numbered instructions, 420px width / 1.5 text scale, provider error exit.
- Scoped Flutter analysis passes.
- Admin Web release build passes into `build/planner-types-fix/admin-web`. Existing CupertinoIcons font warning remains; build succeeds. The initial fixture build preceded deployment; signed-in browser/Gemini acceptance is still pending.
- Screenshots were captured from actual Flutter widgets with synthetic fixtures and offline Barlow font substitution for test font families. They are **local render evidence, not production Gemini results**.

[Backend log](../../build/planner-types-fix/backend-tests.log) · [Flutter log](../../build/planner-types-fix/flutter-tests.log) · [Build log](../../build/planner-types-fix/admin-build.log)

[Exercise two columns](../../build/planner-types-fix/screenshots/exercise-grid.png) · [Ordered instructions](../../build/planner-types-fix/screenshots/exercise-expanded.png) · [Routine](../../build/planner-types-fix/screenshots/planner-routine.png) · [Program](../../build/planner-types-fix/screenshots/planner-program.png) · [Narrow / enlarged text](../../build/planner-types-fix/screenshots/planner-narrow-cards.png)

[Exercise prefill](../../build/planner-types-fix/screenshots/exercise-prefill.png) · [Routine prefill](../../build/planner-types-fix/screenshots/routine-prefill.png) · [Program prefill](../../build/planner-types-fix/screenshots/program-prefill.png)

## Modified source and minimum deployment

- `functions/src/modules/recommendation/admin-ai-assistance.ts`: three contracts/provider compositions and validators; existing shared transport retained.
- `functions/src/modules/recommendation/admin-ai-service.ts`: complete catalog/aliases, coverage and equipment input, no truncated examples.
- `apps/admin_web/lib/features/recommendation/application/admin_ai_drafts.dart`: type-correct seeds.
- `apps/admin_web/lib/features/recommendation/presentation/admin/admin_ai_pages.dart`: compact responsive cards and independent details.
- Existing Backend/Flutter fixture tests plus `functions/test/admin-planner-types.test.ts`.

For the ordinary Admin path the minimum production change is **source-only update of module13AdminCommand plus the matching Admin Web bundle**. Its current AdminAiRepository directly uses module13AdminCommand. No automatic triggers, member callable, Rules, indexes, IAM, Secret, membership or data migration is necessary. This one-function scope was subsequently approved and deployed against the freshly verified live baseline above. Any desire to synchronize the separately routed FYP-cohort callable would need its own explicit release scope.

After matching backend and client release, the owner can manually Generate Exercise once, inspect independent movement novelty and apply without saving; repeat Routine/Program only within a newly reconciled authorized request budget. Old in-memory results should be discarded by reloading. No live request budget was consumed by this fix and no failed production request was automatically retried.
