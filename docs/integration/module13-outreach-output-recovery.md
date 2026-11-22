# Module 13 — Outreach Output Recovery and Member Search

2026-11-18. **Deployed after owner approval; exact source/configuration and matching private Admin activation verified.** No new Gemini inference request, production Generate/Send, production account/data/config mutation or Computer Use. The existing GLbg key, 15-second transport, automatic recommendations and Planner contracts are preserved. Read-only production checks used the existing approved CLI identity.

## Deployment checkpoint

Only module13AdminCommand was source-updated, revision `module13admincommand-00010-rus`, source SHA256 `d0060d9581120013b2b4098d884b680a843d603ce21a62cb95709f69447dc8bf`. The captured baseline archive was changed only in admin-ai-assistance, admin-ai-service and canonical-recommendation-admin (plus source maps). Exact deployed source, all service settings/Secret bindings, IAM, Rules/indexes and all 78 other Functions were verified unchanged. Existing GLbg and registered App Check inputs are preserved. Mock transport comparison confirms all three Planner request bodies are byte-equivalent as parsed JSON to the captured live baseline.

Matching ordinary private Admin is active at http://localhost:7359/, served main.dart.js SHA256 `3db0725b8e93663b4b02a05fa2cf1be9c9271f44d5eb11e2d524ca73fd1eada2`. Old source/config and client rollback copies are retained in build/outreach-fix-20261118/release. No public Hosting deployment, real Gemini request, production Send/data mutation or Computer Use occurred. Production-backed service read confirms m13-e2e-20261117 is searchable, TEST-labeled and currently canAnalyze=true. Actual signed-in page/Generate acceptance remains for the owner to perform manually.

[Deployment verification](../../build/outreach-fix-20261118/release/release-verified.json) · [Client verification](../../build/outreach-fix-20261118/release/admin-activated.json) · [Read-only TEST readiness](../../build/outreach-fix-20261118/release/search-readiness.json) · [Planner preservation](../../build/outreach-fix-20261118/release/planner-preservation.json)

## What actually happened

| Question | Evidence / finding |
|---|---|
| Request | 18 November 16:09:37 MYT: module13AdminCommand returned HTTP 400; Function total latency 3.259691 seconds. This is not a measured Gemini-only latency. |
| Did Gemini run? | Yes: the displayed error is emitted after the Outreach provider returns and JSON parsing succeeds. A matching time window in the actual GLbg project contains one GenerateContent HTTP 200. |
| Model / project | gemini-3.5-flash-lite / gen-lang-client-0108079145. Credential resource matches the previously fingerprint-verified GLbg key. |
| Tokens | In 16:08–16:11 MYT, model metrics show 80 text-output tokens; Free Tier input-quota usage is 876 tokens. The same input usage appears in minute/day quota series and must not be added twice. These are window-level metrics, not a recovered per-request usageMetadata record; total/thinking tokens and exact Gemini-only latency remain unavailable. |
| Candidate reconstruction | Current read-only reconstruction at 16:22 MYT: 14 workouts, intermediate, increaseFlexibility/generalFitness; 3 Squat Tutorial candidates (C1–C3), 4 Routine candidates (C4 Testing, C5 Beginner Full Body Foundations, C6 Beginner Lower Body Basics, C7 Beginner Upper Body Basics); no eligible Coach. This is current eligibility, not proof of a historical immutable snapshot. |
| Saved Preview / Send | No successful production adminAiPreviews were present at diagnosis. The failed generation did not reach its preview commit. No Send was executed by this task. |
| Which exact old field? | **Not recoverable from retained evidence.** The function retained neither rejected output nor a reason code; its logs contain HTTP status only. The actual Gemini project's logs contain zero entries for this request window. It would be dishonest to name one historical field as proven. |

The error is specifically a downstream application-validation rejection, rather than Gemini billing rejection, transport timeout or invalid JSON. The old validator's single generic fail combined invalid/duplicate candidate selection, unsupported evidence references, message constraints and response structure. It also rejected all independent recommendations when any one failed and required nonessential evidenceKeys. The anonymous production candidate set has several candidates of the same type, exposing that all-or-nothing design. Tests reproduce these exact code branches with hand-authored responses; these are not the lost production response.

This is the same **class** of failure as automatic invalid_provider_output—provider response obtained, GainPath contract rejects it—but uses a different output contract/validator. Automatic rankedCandidateIds and its fallback logic were not changed.

Evidence: [Function logs](../../build/outreach-output-diagnostic/read-only.json), [current anonymous candidates](../../build/outreach-fix-20261118/current-candidates.json), [provider HTTP metrics](../../build/outreach-fix-20261118/historical-provider-metrics.json), [token metrics](../../build/outreach-fix-20261118/historical-tokens.json), [provider log coverage](../../build/outreach-fix-20261118/provider-log-coverage.json).

## Minimal correction

- Outreach schema now requires only anonymous candidateId and a short message. IDs are offered as C1…C18, mapped to real destinations only by the backend. The existing transport intentionally sends a basic structural schema; its full prompt schema includes the current ID allowlist. **The server validates the allowlist regardless of model compliance.** No shared Gemini transport change was needed.
- One good candidate is sufficient. Zero to three types are allowed; no invented Coach or forced quota. Empty recommendations is an explicit abstention.
- Validate each item independently; retain the first valid item per type. Drop unknown IDs, malformed/missing messages, medical-claim text or duplicates. Optional legacy evidenceKeys are ignored/filtered if unsupported, rather than rejecting valid core content. Unknown evidence never becomes saved supporting evidence.
- All-invalid responses retain a precise reason code (invalid_candidate_id, missing_message, invalid_message, medical_claim, duplicate_kind, invalid_structure, missing_recommendations, too_many_items). Non-JSON has invalid_json. Partial results report accepted/rejected counts.
- Target availability is checked independently before preview commit. Surviving suggestions are reindexed consistently with saved preview selections. If all targets disappear, return a clear empty state without writing a Preview.
- Consent, identity, Admin authority, target resolution and Send revalidation remain mandatory. No automatic Rules-generated message is represented as Gemini text. Existing runtime already permits general Routine candidates without an exact goal match; new prompt requires honest general-training/recent-practice wording when goal_match is absent. No eligibility threshold or coach qualification was relaxed.
- No-candidate/abstention responses show available type counts, honest availability notes and practical next steps. They do not invent why a particular coach failed an unspecified individual check.
- Internal diagnostics record requestTag (preview hash), type counts, provider result/method/model, tokens, latency, cache state and rejection reason counts. They never log member names/profiles, prompt, messages, candidate titles or raw outputs. This makes future failures diagnosable without another speculative retry.

## UI and Search Members

- New Admin-authorized admin.ai.member.search searches active members by case-insensitive name, email or member ID (2–80 characters). Current bounded organization scan remains 250; maximum 25 matches with hasMore. Search does not call Gemini.
- Search includes clearly labeled TEST identities without adding them to Top 10 or treating test workouts as real activity. Analysis remains subject to current permission/scope; Generate still requires all four purposes. No new account or training history is created.
- Goals display Improve Flexibility / General Fitness, with readable labels for the other supported goals in both ranking and analysis.
- Generate errors appear next to Generate, not at page top. Loaded analysis remains present after generation fails. Search/load errors retain their own context.
- Opening/searching/analyzing does not trigger Gemini. Send remains explicit and selected-only.

Local Flutter screenshots (synthetic fixtures, offline font substitution; not real production Gemini acceptance): [search + retained analysis/error](../../build/outreach-fix-20261118/screenshots/outreach-fix-search-error.png), [single Tutorial preview without Coach](../../build/outreach-fix-20261118/screenshots/outreach-fix-single-preview.png).

## Verification

| Check | Result |
|---|---|
| Backend | 220 tests / 11 files pass, including Planner, automatic ranking/backup, existing Outreach/cooldown and new recovery/search cases |
| TypeScript | Source and test configurations pass |
| Flutter | 10 tests pass; includes real existing forms, new search outside Top 10, readable goal labels, retained analysis, error position and single-result Preview (all mocked providers) |
| Flutter analysis | Changed UI/test files: no issues |
| Auth/Firestore Emulator | 7 tests pass on demo-gainpath-admin-ai, fresh dedicated ports; real emulator transactions verify authorized TEST search, partial valid Preview, existing Send/receipts/exact retries, consent denial and preserved automatic cooldown. Emulator Send is not a production send. Existing occupied emulator ports/data were not cleared. |
| Admin Web | Release build passes into build/outreach-fix-20261118/admin-web; existing CupertinoIcons font warning remains. Initial standalone build was not activated; the later matching private release above is now active. |

[Backend log](../../build/outreach-fix-20261118/backend.log) · [Flutter log](../../build/outreach-fix-20261118/flutter.log) · [Emulator log](../../build/outreach-fix-20261118/emulator.log) · [Analysis](../../build/outreach-fix-20261118/flutter-analysis.log) · [Build](../../build/outreach-fix-20261118/admin-build.log).

Regression fixtures cover the anonymous 7-candidate scene, single Tutorial/no Routine/no Coach, multiple/duplicate kinds, missing nonessential fields, unknown IDs, missing messages, valid target disappearance, empty candidates/abstention, unmatched fitness goals, authorization and partial-preview index mapping. No failed response was manufactured as a successful production recommendation.

## Files and smallest release scope

Production code:
- functions/src/modules/recommendation/admin-ai-assistance.ts — Outreach schema/prompt and per-item validation only; Planner contract remains as already deployed.
- functions/src/modules/recommendation/admin-ai-service.ts — authorized member search, safe diagnostics, availability explanations and consistent partial preview.
- functions/src/modules/recommendation/canonical-recommendation-admin.ts — allowlist the search operation on the existing Admin entrypoint.
- apps/admin_web/lib/features/recommendation/presentation/admin/admin_ai_pages.dart — search, labels and error context.

Tests: existing admin-ai contract/flow, Flutter page and emulator tests; new functions/test/outreach-output-recovery.test.ts and functions/test/outreach-search-flow.test.ts.

For the ordinary Admin workflow the minimum release is **source-only module13AdminCommand + matching Admin Web**, with fresh baseline/rollback verification and existing private App Check build inputs. No new function, automatic trigger, member callable, Rules, indexes, IAM, Secret, paid service or database migration is required. The owner subsequently approved and deployed exactly this one-function/client scope, as recorded above. Real Gemini retry and sending remain for separately authorized manual acceptance, using only the existing TEST recipient. First search m13-e2e-20261117, confirm identity/current consent, Generate once and review; do not Send to the ordinary member used in the error screenshot for test acceptance.
