# Module2 AI Coach Voice V1 —15 November2026

Implemented the existing [voice plan](module2-ai-voice-feedback-plan.md), with the owner-selected Kokoro **af_heart**, American English female, speed**1.15**. The owner auditioned both af_heart speeds and af_bella, selected af_heart, and confirmed hearing the actual phone playback. No HeyGen/cloud voice API or Firebase change was used.

## Shipped assets

| Category | Independent audio files |
|---|---:|
| Numbers1–30 |30|
| Ready/start/set/rest/transition/completion |8|
| Left/right arm switch |2|
| Setup |7|
| Tracking |4|
| Evidence-based correction |16|
| Encouragement: effort4, halfway3, finish3 |10|
| **Total** |**77**|

This is exactly the report's70 V1 entries plus7 additional encouragement variants. Manifest, notices and licenses are metadata, not extra audio. Thirty numbers use PCM16 WAV;47 phrases use OGG Vorbis. All are24kHz mono, normalized to an RMS target0.12 with peak cap0.89, with25/65ms leading/trailing padding. Actual files total**1,507,905 bytes**,84.781s; individual duration446–2,455ms. All77 decode, hash, rate/channel, duration, peak and silence checks pass. Numbers are446–799ms. Automated waveform checks do not prove every word's pronunciation.

Assets: `apps/mobile/assets/audio/coach_en/default_v1/`. Per-clip script/hash/bytes/duration are in `manifest.json`; source-driven Flutter lookup is `coach_voice_catalog.dart`. Reproduction, pinned development dependencies and model hashes are in `tools/workouts/voice_pack/README.md`. Apache-2.0 Kokoro and MIT kokoro-onnx notices are retained. The325.5MB model,28.2MB voices, Python environment and audition masters stay in ignored `build/coach-voice-v1-20261115/` and are absent from the APK.

## Runtime behavior

- The Android coach capability activates the new policy through the existing `WorkoutAudioController`. Custom legacy ports retain their prior policy. Default muted/Alerts Only preferences remain respected.
- All9 real Session owners supply accepted cumulative full-rep totals plus a read-only current-set projection. Partial counts cannot create a full-rep number. Curl uses the current anatomical arm's baseline; a both-arms replay verifies**1,2,1,2**, not the averaged whole-set total.
- Numbers bypass the old2/6s general cooldown, have a250ms start budget and replace older numbers. Numbers above30 use the installed offline English Android voice. A warning/correction may suppress a number; missing/late speech never changes the UI count or retries an expired number.
- Priority: tracking warning5, grounded correction4, accepted number3, phase2, encouragement1. One current cue is selected; there is no speech FIFO. Corrections use a semantic8s cooldown, global4s correction spacing, then15s for the third repeated reason. Real joint/framing detail without a packaged equivalent remains specific TTS text.
- Encouragement uses true accepted progress: halfway for targets≥6, two remaining for targets≥8, otherwise eligible multiples of5. It requires an idle natural gap, expires after2.5s, uses12s global/60s same-phrase spacing, excludes the last2 variants and allows at most2 per set/arm. No evidence-free Good Form/recovery claim was added.
- Ready/Start reuse existing ready/camera-check phases; no new blocking countdown gate is introduced. Rest/next/completion reuse short shared clips. Curl switches are announced only at the existing deliberate arm boundary. Entering a new phase drops pending rest announcements.
- Final accepted numbers can finish before one short phase continuation. Results persist before the existing bounded1.5s settlement. Pause/source loss/background cancel obsolete speech. Save failure and unauthorized return paths also close the coach owner.
- Native `WorkoutAudioPlugin` uses asynchronous `MediaPlayer` asset preparation under the existing generation/deadline/AudioFocus owner. TTS and assets cannot play concurrently. Late asset errors cannot restart a word through TTS after it already began. A second native session retires the previous active owner.

V1 rulings: asset readiness returns immediately; an enabled session silently warms its offline TTS fallback in parallel so the first31 is less likely to face cold initialization. Assets do not wait for TTS availability. Encouragement budget is conservatively charged at selected dispatch under the existing AudioPort contract; a failed/cancelled dispatch can consume a slot, reducing encouragement rather than causing retries. This is not a native-start-confirmed budget refund mechanism.

## Verification and physical limits

- **96 focused voice/lifecycle/rest tests pass.** The9 Session trajectories additionally cover held final numbers, durable save before teardown,3 throwing-save cleanup cases and both-arm Curl switching.
- **208 broader affected tests pass;1 pre-existing UI assertion fails.** `curl_workout_session_test.dart:318` expects visible `Left arm: 2 full` on the result page. It fails identically with the HEAD Curl Session restored while retaining the existing shared-workspace summary UI. No unrelated UI/test change is included to conceal that baseline failure.
- **22 native deadline/epoch assertions pass.** Changed Dart files pass scoped analysis after the final test-brace correction. Normal arm64 Android Debug build passes.
- On the authorized Xiaomi, a separate explicit debug-only probe exercised the actual MethodChannel/native backend:9 representative WAV/OGG assets, dynamic31 and unknown-script offline fallback completed; rapid old number, pause, expired request and closed owner were cancelled. The owner replied“已听到”. The earlier locked-screen attempt correctly returned unavailable and is not counted as a playback pass.
- Latest foreground probe's10 asset starts: native prepare-request→`MediaPlayer.start` call median**12.6905ms**, maximum**31.257ms**. These are native preparation measurements, **not end-to-end speaker latency or camera FPS**. Probe APK SHA256:`2e9511d4e674f39e7aa3976fa0951229a12eaa308a5f2034682dbd4824ba4e8e`. The final normal build additionally contains the later silent TTS warm-up and Session cleanup/Curl-boundary fixes verified by tests/build.
- The normal app was restored in place. Installed/local APK hashes match; package identity, signer, UID/data directory and first-install identity are preserved. All46 protected files matched after the first restore; the later normal launch refreshed membership cache and backup-state metadata, while the other44 workout/routine/preference/reward files remain hash-identical. No workout records were edited by the probe.
- All9 **physical** exercise performances, camera FPS with/without voice, sustained long-session thermal behavior and hearing every clip on the phone remain unmeasured. The probe opens no camera/account/workout repository. Synthetic trajectories and native playback do not establish physical tracking accuracy or a camera performance claim.

## APK size

Current normal arm64 Debug APK:**197,549,439 bytes**; retained pre-voice installed baseline:**197,539,137 bytes**. Observed net change:**+10,302 bytes**. Do not interpret that as the voice feature's general size cost: the81 new audio/metadata ZIP entries contribute**1,523,119 compressed bytes** (1,567,189 uncompressed), while non-entry ZIP/packaging bytes decreased and offset most payload growth. `compare_apk.py` reports both components. Existing unrelated workspace UI is retained in the local application build; the commit itself is scoped to this voice feature.

Final installed APK SHA256:`667fb7213e7fa33883ca0d51a652bfa7d87eb6813813b3fee5b20ba632cf1159`.

Private logs, APKs, model/environment, protected-file hashes and comparisons are retained under ignored `build/coach-voice-v1-20261115/`: `audio-verification.json`, `voice-core-final.log`, `affected-tests-final.log`, `curl-baseline.log`, `analysis-final.log`/`analysis-corrections.log`, `device-probe-summary.json`, `apk-comparison.json` and device integrity evidence. No private device evidence is committed.
