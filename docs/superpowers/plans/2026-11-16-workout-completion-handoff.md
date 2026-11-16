# Workout completion handoff

Owner request: after the final accepted movement, show a completed animation and finish the spoken completion before navigating to Routine Summary or Result. The request supplies the interaction; no new product decision is required.

Design: keep durable result saving first. Give recorded-coach final-number plus completion a bounded4s settlement instead of1.5s; explicit pause/source/account cancellation still wins. Make repeated finish-boundary calls idempotent. Show a full-screen purple/mint check celebration for at least1.6s on genuine guided completion; navigate only when both save/audio settlement and visual presentation finish. Single and Routine use the same handoff. Partial exits and rest between sets do not celebrate. Muted/unavailable speech still proceeds after the animation. Respect reduced motion, long exercise names, narrow/landscape/large text and foreground/disposal cancellation. Reuse the existing short asset and do not change pose/count/form/save calculations.

- [x] Reproduce deadline and repeated-boundary issues with failing audio tests.
- [x] Reproduce Single/Routine handoff with real Session trajectories and held audio.
- [x] Implement the bounded audio handoff, idempotency and responsive celebration overlay.
- [x] Verify muted/failure/background, affected navigation/audio/session tests, Flutter renders, analysis and Android Debug build; install safely on the standing authorized device if available.
- [x] Scoped review and evidence, preserve unrelated shared-workspace UI changes.

Verification:140 affected tests pass;10-file analysis clean; arm64 Debug build passes. Eight actual Flutter renders cover portrait, landscape,320px/200% long text and reduced motion; inspected renders use the Member theme and local fonts. Single/Routine tests hold the real Session's final number and completion futures beyond1.5s, require both voice and visual completion before navigation, and verify durable saving first. Muted/unavailable, stalled-audio4s escape, background/resume, disposal and out-of-order routines are covered. Review corrected whole-workout wording to remaining-work context (`nextExerciseName`), not ordinal. Early/partial saves do not celebrate.

The phone was verified idle on Home, with no active capture. Same-signer in-place install/launch, exact installed/local APK SHA256 `54389cf1688553d4c591270fb60894c294daf5fcfb7253f526fd9504f3e0aeab`, UID/data-directory/first-install identity and all47 protected saved-file hashes pass unchanged. Prior APK retained. This is not a claim of newly observed physical final-rep performance or camera FPS. Private evidence: ignored `build/workout-completion-20261116/`; screenshots: `apps/mobile/build/workout-completion-feedback/`. Earlier unrelated Ready/rep visual changes in RealWorkoutView are preserved and excluded from this fix's index patch.
