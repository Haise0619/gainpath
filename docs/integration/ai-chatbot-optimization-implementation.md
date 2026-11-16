# GainPath AI Chatbot optimization — local implementation

Date: 2026-11-16, Asia/Kuala_Lumpur. Implements the three phases requested after [the audit](ai-chatbot-comprehensive-audit.md). The local implementation evidence below predates the separately approved deployment recorded here.

## 2026-11-16 approved deployment and acceptance

The owner approved deployment of implementation commit `7847de3`. The two existing Singapore Functions in `gainpath-0619` were updated through `buildConfig.source`:

| Function | Verified active revision |
|---|---|
| `fypDatasetCommand` | `fypdatasetcommand-00011-tuz` |
| `fitnessAssistantCommand` | `fitnessassistantcommand-00003-naw` |

Both downloaded deployment archives match the prepared SHA-256 hashes. The release overlays the committed Chatbot modules and required dependencies on the captured deployed sources. Existing runtime, environment, secret binding, service configuration, IAM, Firestore Rules, indexes and 77 other Functions passed comparison. The prior source archives and release evidence are retained privately in `build/chatbot-release-7847de3/`.

Nine authenticated and negative live checks passed. Ordinary and FYP Members loaded the current Assistant disclaimer in public mode. Missing Auth or App Check and foreign organization access were rejected. The FYP-scoped Assistant rejected an ordinary Member, and the FYP test Member read existing recommendations and membership overview. These checks made zero Gemini calls. A fresh offline rerun passed 76 backend tests.

The Xiaomi Debug APK was updated in place and launched successfully. Its installed SHA-256 matches the reviewed artifact. The signer, package user ID, data directory and first-install timestamp matched the pre-update values. The prior APK is retained privately. Interactive Android acceptance requires an unlocked device. Live model response quality and checkout completion were outside these read-only probes.

## Phase 1 — reliability and performance

- New coaching suggestions use the authoritative fixed60 contract. Existing booking/payment authorization, pricing and checkout revalidation remain.
- Failed questions remain visible and can be edited or retried. Input is bounded to 2,000 characters. Retry tracks the current operation; older pending save failures cannot steal a later question retry.
- Saved Advice exposes pending, errors and retry. Waiting can be stopped; late responses are ignored and context invalidated. Stopping UI waiting cannot promise cancellation of server execution or provider charges.
- Generic questions no longer load workout records or send unused public-mode history. Deterministic context questions use existing authorized repositories and make no Gemini request.
- Coach candidate reads use bounded concurrency, preserve ordering and recheck authorization. Trusted terminal tool results avoid a discarded model continuation.
- Provider/tool deadlines and bounded response parsing distinguish configuration, timeout and incomplete output. Metadata-only response timing, provider/tool count and token usage are exposed; logs contain no prompt, reply, identity or tool arguments. Missing usage is not represented as verified zero.

## Phase 2 — actual fitness context

- Last workout and progress cards reuse local progress/report snapshots, including exercise captures and separate routine attempts, actual reps/partial reps/duration, nullable estimated Form Score, tracking observations and limited same-group score change.
- Explicit source labels distinguish device/synced summaries from server-accepted evidence and FYP recorded fixtures from physical measurements. Unavailable data stays unknown. Individual capture sets are not fabricated.
- Published tutorial/routine options reuse current catalog, stated profile goals/experience and recent exercise context. Selection is a bounded educational suggestion, not a new recommendation engine or automatic plan write.
- Existing Module13 recommendations supply actual explanations and current-target navigation. Chat does not trigger new generation or Send.
- Membership cards read authoritative overview, effective entitlement and published plan benefits. Digital fitness does not gain an invented Premium restriction.
- Ordinary and FYP routing reuse existing scoped services. The FYP Assistant adapter limits persistence to its current Member chatbot state and reads the shared approved notice; scope assignment/revocation and target checks remain enforced.
- Workout report, tutorial, routine, recommendation, Coach and Membership actions use controlled existing Flutter destinations. Tutorials/routines are reloaded before navigation; recommendation navigation resolves the target afresh.
- Personal context remains in GainPath. Default Gemini mode remains public/free. Local factual summaries use the already acknowledged session notice; external generation continues server-side current revision enforcement.

## Phase 3 — native Flutter UI

Purple branded welcome with existing mascot, supported suggested questions, clearer selectable/copyable bubbles, factual cards and source labels; compact header with Saved/overflow actions. Multiline composer retains draft recovery, supports keyboard submission and accessible controls. Loading uses lightweight animation; scroll follows new content only when appropriate. Actions wrap for large text, and the welcome state scrolls with the keyboard. No cloud history, RAG, streaming, autonomous payment or new global FAB was introduced.

## Measured comparison

These measurements are **offline**, not production/network/physical-device latency. Seven samples inject a fixed 15ms provider delay and fixed usage metadata; exclude Auth/Firestore/device paint. Raw artifact: `build/chatbot-optimization/backend-benchmark.json`.

| Terminal Coach list scenario | Before | After |
|---|---:|---:|
| Provider requests | 2 | 1 |
| Median observed duration | 39.55ms | 25.56ms |
| Injected input/output tokens | 240 / 40 | 120 / 20 |

The token values are test-fixture values, not measured Gemini consumption or a price claim. The result demonstrates removal of one unnecessary round trip. Actual provider timings/tokens require a future explicitly budgeted run. No real AI calls were made for these results.

Generic Q&A now performs zero progress loads; context answers perform zero provider requests. Tests pin these call-count properties. Real Firestore billed-read totals, cold start and live p95 remain unmeasured; no percentage cost saving is claimed.

## Verification and artifacts

- Root rerun: **76 backend tests passed across nine files**: chatbot, callable, booking tools/callable, optimization, FYP Assistant/module services/scope/runtime release. Injected provider and stores; no cloud inference.
- Final integrated mobile log: **54 tests passed across seven files**, including recovery, context, repository, existing chat flow/Bloc and recommendation navigation; `build/chatbot-optimization/mobile-focused.log`. Final review added regressions for unsafe local workout requests and both failure-order retry races. Card copy/save preserves bounded factual contents.
- **Four actual widget renders passed**: 390dp welcome/workout card, 320dp at 200% text and 360dp with keyboard. Controlled fixtures, not signed-in production or physical-device screenshots. Member Barlow fonts/assets loaded; the offline font helper substitutes unrelated unavailable font families.
- Android arm64 Debug build passed; final rebuild after review fixes took 11.5s (initial build 41.4s). APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `753581CF0C7B0CCBEBF55047CA6D87C1A8647C8A6998449B2045006F5B94ED0D`. Build log: `build/chatbot-optimization/android-debug-build.log`. The APK includes the preserved current working tree, including unrelated existing local changes; it is not a task-only release artifact. Not installed.
- Previous silent Flutter startup was SDK cache lockfile access denial at `C:/flutter/bin/cache/lockfile`. Direct Dart Flutter snapshot execution with approved SDK-cache access produced normal test output; no SDK repair/dependency upgrade was needed. Earlier interrupted runs are not counted as passes.
- Static analysis/typecheck and final review results are recorded in the plan ledger as completed. Focused checks do not establish full-app regression or real provider acceptance.

Screenshots (local artifacts):

![Welcome](../../build/chatbot-optimization/screenshots/welcome.png)

![Workout card](../../build/chatbot-optimization/screenshots/workout-card.png)

Additional captures: `build/chatbot-optimization/screenshots/large-text.png` and `keyboard.png`.

## Required future deployment inventory — not executed

| Existing Function | Reason |
|---|---|
| `fitnessAssistantCommand` | Fixed60, terminal reply optimization, bounded provider work, telemetry and trusted FYP dispatch |
| `fypDatasetCommand` | Scoped Assistant state/read adapter and membership overview reuse |

No new Function, collection, Rules/index, OAuth connection or paid AI service is required. Preserve current region, secret binding, App Check, service settings and IAM; source-only packaging must include the shared dependency closure. Local mobile behavior needs the paired backend update before claiming full live readiness, particularly FYP dispatch. Deployment requires a later authorized release and current metadata/source verification.

Remaining acceptance: real Android touch/TalkBack and keyboard behavior, authenticated ordinary/FYP end-to-end UI, real provider quality/latency/quota and booking proposal-through-checkout acceptance. No booking/payment/consent mutations were used to simulate success. Runtime privacy/language heuristics remain limited; unsupported personal claims must not be inferred.
