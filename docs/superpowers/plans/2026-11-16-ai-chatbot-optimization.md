# GainPath AI Chatbot Optimization Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development and test-driven-development for implementation and verification.

**Goal:** Deliver the user's three-phase upgrade with reliable recovery, authorized fitness context and polished native Flutter UI.

**Architecture:** Preserve Flutter repositories, protected Firebase callable and Gemini public/free mode. Personal context stays in deterministic GainPath summaries and controlled navigation. Reuse Module13, membership and published tutorial services.

**Tech Stack:** Flutter/Dart, Firebase Auth/App Check/Functions, TypeScript, Gemini.

**Spec:** `docs/integration/ai-chatbot-comprehensive-audit.md` and user's 2026-11-16 implementation request.

## Global constraints

- No deployments, live Rules/config/data changes, paid AI calls, new recommendation engine, cloud chat history or unnecessary collections.
- Preserve unrelated dirty files and frozen workout/scoring/payment behavior. Selectively stage only owned changes.
- Public/free mode must not automatically send personal history to Gemini. Distinguish measured, unscored, synced and fictional sources.
- Existing declaration, saves, feedback, authenticated scope and checkout revalidation remain.

## Review focus

- Retry sends the selected failed operation and retains editable questions after network/length failures.
- Account/cohort changes discard late results and never reuse another identity's facts.
- Missing or unscored records never become zero scores or invented achievements.
- Suggested targets resolve to real published and currently authorized destinations.
- Small screens, keyboard, large text and long replies remain usable.

## Task 1 — Backend reliability and cost

Files: `functions/src/modules/chatbot/*.ts`, focused chatbot/booking tests.

- [x] Add regressions for fixed60 new bookings, error handling, tool-call budget and metadata-only telemetry.
- [x] Run failing cases, implement minimal fixes without changing business policy.
- [x] Reduce unnecessary continuation/provider calls and redundant request reads while retaining authorization freshness.
- [x] Run existing and new focused backend suites; record synthetic timings/calls/tokens separately from live measurements.

## Task 2 — Deterministic authorized fitness context

Files: mobile chatbot context service, factory, repository and domain attachments; focused tests.

- [x] Build bounded snapshot projections with existing local progress/report, published routine, recommendation and membership repositories.
- [x] Cover ordinary/FYP scopes, unavailable data, unscored/form compatibility and no private provider payload.
- [x] Add real typed workout/tutorial/recommendation/membership cards and controlled existing route callbacks.
- [x] Make generic Q&A skip progress load; bound explicit context requests and cancellation/late delivery.

## Task 3 — State recovery and Premium Flutter UI

Files: chatbot Bloc/state/events/screens and focused widget/render tests.

- [x] Test editable failed questions, typed retry, Saved Advice errors and pending state.
- [x] Implement welcome mascot, honest quick actions, selectable/copyable bubbles, structured cards and multiline composer.
- [x] Implement scroll-follow only when appropriate, accessible actions, keyboard and large-text behavior.
- [x] Render actual widget screenshots for ordinary width and narrow/large-text cases.

## Task 4 — Integration verification and delivery

- [x] Diagnose prior Flutter startup hang; distinguish SDK startup failure from assertion failure.
- [x] Run focused Dart/backend tests and scoped analysis, then Android Debug build.
- [x] Review complete owned changes against all three phases and fix substantive issues.
- [x] Write actual implementation/results report with measured before/after values and limitations, screenshots and required deployment inventory.
- [ ] Selectively commit owned files; do not push or deploy.

## Progress ledger

- Source baseline: `c6ab900fbec58b39b3cb82d2f96727918924662c`, branch `codex/hybrid-workouts`; existing unrelated dirty work retained.
- Prior audit backend baseline: 31 offline tests passed. This is prior-turn evidence, not current implementation verification.
- 2026-11-16: lead implementation delegated backend and intelligence tasks; lead owns Bloc/UI.
- Flutter startup diagnosis: SDK cache lockfile permission denial under restricted execution; same bounded command approved for SDK cache access and now emits test loading output. Await actual result.

- Final local verification: 54 focused Flutter tests pass across seven files; five UI checks include four actual renders and a 200-message scroll/save regression. Scoped Dart analysis: no issues.
- Backend verification: lead agent69 focused tests pass; root independently ran76 tests including scope/release. TypeScript source/test checks pass.
- Review corrections: deterministic local health-safety gate; both pending-save/message failure interleavings; pending state visibility; retries exclude failed tail; timeout clears context; Copy/Save retains bounded card facts.
- Final Android arm64 Debug build passes (11.5s incremental after41.4s initial), no install. Artifact and hash in build/chatbot-optimization/.
- Ordinary/FYP data remain explicitly scoped and personal context is not sent to Gemini in public mode. No cloud/Rules/billing/provider changes.
- Independent backend/client cross-review completed; root final selective commit remains delivery step.
