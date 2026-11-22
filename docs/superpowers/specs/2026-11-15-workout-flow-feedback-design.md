# Workout flow visual feedback

Implement the owner's detailed Rest Page and AI Tracking UI specification in the existing Flutter Member flow. Preserve camera, pose, rep counting, guidance, audio, consent and persistence behavior.

Use the current purple theme and published exercise cover component. Rest presents a compact completed-exercise receipt, a large circular remaining-time dial with a finite pulse on each of the final three seconds, a cover/name/mode/target next-exercise card, and anchored Pause/Skip controls. Existing blocked, paused, preparing and failed states retain their actions and explanations. Narrow screens and enlarged text scroll naturally.

Use a separate presentation-only session observer for a brief Ready (900ms) and accepted rep (760ms) scale/fade overlay. Show Ready once per set/arm after healthy calibrated tracking; never infer reps from poses. Ignore initial historical counts, resets and repeated notifications. Clear feedback on manual pause, explicit recalibration, tracking loss, lifecycle interruption and session replacement. Preserve the accepted final count through automatic rest/arm-switch calibration invalidation without claiming tracking readiness. Use the existing unilateral current-arm display count. Retain existing truthful lightweight coaching status; rep confirmation is separate from any form-quality claim. Respect reduced motion, isolate repaints and never intercept camera controls.

Approach: reuse existing controllers and image/theme widgets. Additional animation packages and changes to domain/controllers are unnecessary. Execute in the existing checkout to preserve the user's active UI changes. The request already authorizes this concrete UI work.

Validation: focused widget tests for progress/pause/zero, media, Ready/rep event lifecycle, reduced motion, portrait/landscape and large text; real Flutter renderer screenshots, affected regression tests, scoped analysis and Android debug build. Physical camera performance requires a connected Android device; report that limit if unavailable.
