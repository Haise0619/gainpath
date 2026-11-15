# AI Coach Voice V1 implementation

Spec: `docs/integration/module2-ai-voice-feedback-plan.md`, with owner's V1 selection of70 base clips plus7 encouragement variants (77 total). Reuse its scripts/strategy without a new design cycle.

- [x] Extract and validate77 exact manifest entries; generate female American English Kokoro preview locally; get the owner's sound confirmation before bulk generation.
- [x] Implement/test semantic policy, accepted-rep inputs for9 trackers, freshness/latest-wins and sparse rotating milestone encouragement. Preserve analyzer/count/form rules and existing legacy test-port behavior.
- [x] Add local native asset playback under existing MethodChannel/AudioFocus/epoch, with offline TTS fallback and no concurrent backend playback.
- [x] Generate approved77 clips, normalize/trim, retain hashes/licenses, declare only selected assets.
- [x] Run affected tests,9 tracker coverage, native tests, Android Debug build and baseline APK comparison. Preserve original device APK/data and check safe idle before in-place install; record physical playback evidence separately from real camera FPS/voice-quality acceptance.
- [x] Fresh scoped review, resolve findings, commit only this feature's changes, preserving unrelated work (including pre-existing pubspec/UI edits).

Execution: in existing `codex/hybrid-workouts` checkout. Large model/environment and baseline APK are under ignored `build/coach-voice-v1-20261115/`, never shipped. No Firebase changes. Default voice remains muted; owner approval of voice is a required quality choice, not inferred from elapsed time.

Owner selection: af_heart, using the previously auditioned faster1.15 setting; actual phone playback acknowledged. Ruling: return asset readiness immediately and silently warm offline TTS in the enabled session, preserving low-latency31 fallback without delaying assets. Charge encouragement dispatch budgets conservatively under the unchanged port completion contract. Known broader Curl UI baseline failure is independently reproduced; physical camera FPS and all9 physical performances are not claimed. See `docs/integration/module2-ai-coach-voice-v1-implementation.md` for counts, review fixes, evidence and limits.
