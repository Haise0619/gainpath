# Floor Push-Up Voice Feedback Implementation Plan

**Goal:** Deliver fresh, measured attempt feedback despite phase resets and expose local end-to-end audio timing for physical acceptance.

**Architecture:** Keep pose cues as current-frame guidance; pass terminal attempt cues as identified, timestamped events with a maximum 500 ms start budget. Event lifetime is independent of READY and brief missing frames. Warnings, superseding events, expiry, pause, mute, background, model/account/session loss cancel pending events. Existing exercises retain their current cue semantics. Android uses actual utterance callbacks and a native pre-start deadline; no speech backlog is created.

**Spec:** Owner's voice-fix request in this chat. Explicit implementation authorization supersedes skill approval pauses. Work in the existing checkout because the implementation depends on extensive uncommitted floor infrastructure; preserve unrelated changes and record scoped hashes. No cloud deployment, production distribution, user-data mutation or Module 13 change.

## Constraints

- TOP >=155Â°, BOTTOM <=105Â°, 120 ms dwell and scoring/source contracts unchanged.
- No Admin Dashboard or other exercise implementation changes.
- Trace is bounded, opt-in debug-only; no speech text, video, landmarks, account identifiers, persistence or upload.
- Firebase preparation is offline and limited to two existing compatibility functions. Signing must fail closed for release without an explicitly supplied keystore; never fall back to debug signing.

## Tasks

- [x] Reproduce missing incomplete-extension correction in the regular Mobile suite; retain RED log.
- [x] Add accepted-observation status independently of phase; identify terminal cues from newly completed/partial attempt deltas. Preserve identified events across empty batches/preparation, enforce deadline/deduplication/supersession and lifecycle safety. Test shallow/full/partial/reset, loss, priority/cooldown, delayed/stale and cancelled events.
- [x] Add bounded trace stages: exercise event, queued, arbitration/drop, TTS request, native request/start/completion/cancellation. Correlate per-request IDs, keep Dart/native clock domains explicit, enforce native start expiry only for opted-in floor requests. Test method-channel callbacks/deadlines and callback isolation.
- [x] Prepare exact offline schema-7 source-overlay archives from retained deployed archives, source-only diff inventory, regression tests and a gated release manifest. Prepare fail-closed production signing input template and validate debug build remains independent of credentials.
- [x] Run pose/audio/session/regression/backup checks, full Mobile suite, scoped analysis/types and Android debug build. Retain prior APK and hash new artifact. Document 17th failure separately from voice regression, physical acceptance checklist and held release gates.
- [x] Complete a fresh-context read-only review and address important findings with tests; update operational references and evidence manifest.

## Review focus

Events must not replay from timer snapshots or duplicate captures; true camera/model/account loss must invalidate them. Engine preparation and native queued-but-not-started speech must expire. Late callbacks must not finish newer speech. Final-target encouragement must have an explicit bounded completion policy. Native timing instrumentation is evidence collection, not a claim of physical latency acceptance.

## Execution record

Implemented in the existing checkout as authorized; unrelated dirty/untracked work preserved, no commit/stash/reset. Confirmed missing-extension RED then GREEN. Independent review identified bridge-duration renewal and aggregate-signing bypass; both fixed with RED→GREEN cases.18 native assertions and51 focused Mobile tests pass; full frozen-source suite remains1,488/21skip/17known failures. Intermediate edited-during-compilation result is superseded. One permission-review timeout was retried successfully. No deployment, production artifact/distribution, phone install or physical acceptance.
