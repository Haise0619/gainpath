# Module 2 Phase 0 Implementation Plan

> Execute inline with test-driven development and a final independent review.

**Goal:** Secure standalone preview and establish a measurable baseline for Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press.

**Spec:** Owner's Phase 0 request and `docs/ux/module-2-performance-voice-ux-audit.md` (A01/A17).

**Architecture:** Reuse account-scoped persistent consent, current Member authorization and the existing camera controller's generation/lifecycle protection. Instrument existing boundaries with opt-in bounded scalar collectors; keep analysis and playback decisions unchanged.

## Constraints and decisions

- User explicitly requests direct implementation; no separate design approval or worktree decision is required. Work in the inspected checkout and stage only Phase 0 deltas; preserve pre-existing dirty content using saved baselines in ignored build output.
- Reverse Lunge, Row and Wall Push-up are retirement candidates, retained unchanged pending catalog/routine/enrollment/history assessment. Timed/manual execution and history remain supported.
- No tracking algorithms/thresholds, voice policy, backend/schema, cloud data, device installation or Phase 1/2 fixes.
- No frames, raw pose histories or personal identities in baseline diagnostics; bounded numeric samples, fixed event names, ephemeral correlation keys only.

## Review focus

Consent withdrawn while preferences/model/camera initialization waits; same-scope role revocation; A→B→A switching; background/foreground during launch; native speech clocks and disabled instrumentation behavior.

## Tasks

### 1. Preview privacy and consent fixture baseline

- [ ] Add regression tests for current/absent consent, withdrawal/logout/account/role changes, pending model/camera/preferences, stale callbacks, permission denial and safe reopening.
- [ ] Run the new tests and four existing consent failures before changing production behavior.
- [ ] Pin preview scope/consent and lifecycle launch lease; reuse `WorkoutAiConsentGuard`; inject controller/viewport for hardware-free regression tests.
- [ ] Restore four consent fixtures with authenticated preferences, testing accepted and first-use consent without bypassing checks.
- [ ] Run preview, consent, continuity and controller tests.

### 2. Shared performance baseline

- [ ] Test bounded samples/counters, fixed vocabulary, audio correlation/clock separation, disposal and six-exercise scope before implementation.
- [ ] Add opt-in recorder/binding for startup, worker/accepted deliveries, drops/stale, voice/TTS, transitions, RSS and resource lifecycle.
- [ ] Wire six retained routes to existing camera/detector/preview/audio boundaries. No sensor-exposure or audible-latency claim.
- [ ] Run collector/binding and existing camera/audio/session tests; instrumentation off must preserve defaults and policies.

### 3. Validation, documentation and commit

- [ ] Document six-exercise optimization scope, deferred safe retirement and exact physical baseline procedure.
- [ ] Run relevant Flutter tests, complete pose suite, scoped static analysis and Android Debug APK build. Retain logs; no installation.
- [ ] Obtain independent review and resolve important findings with regression tests.
- [ ] Update operational references with scoped facts; verify selective staged diff excludes unrelated dirty work; commit Phase 0 and report hash/results/limitations.

## Execution ledger

- Baseline: checkout `codex/hybrid-workouts`, HEAD1082e12; existing audit records750 pose passes and four missing-AuthBloc consent fixtures. Initial dirty status and affected file snapshots retained under `build/module2-phase0-20261110/`.
- Task 1 complete: nine route privacy cases (including revoke→restore variants), eight launcher cases including navigation handoff, and both first-use/accepted fixtures. New tests failed before implementation; review handoff probe reproduced then passed after launch-validity handoff.
- Task 2 complete: bounded collector and six-route integration; native/Dart clocks separate. Muted/failure denominator probe failed then passed after observation-only hooks; delayed TTS initialization cannot leave a diagnostic live engine.
- Task 3 verification:314 Mobile passes/13 optional skips across48 compilable files;750 pose passes;26-file scoped analysis no issues; arm64 Android Debug APK build passes. Extended49-file run records an unchanged EquipmentImage.extension compile error in one backup integration fixture; it is not a fresh pass claim. Independent review's two Important findings fixed with RED→GREEN probes; richer state-transition counters deferred as minor. No device/cloud action.
- Owner steering: after Phase 0 commit, proceed directly through Phase 1 and Phase 2 with separate verification/commits. Retirement remains documentation-only until separately assessed.
