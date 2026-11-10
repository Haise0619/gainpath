# Module 2 — Phases 1 and 2 implementation

Primary optimization scope: **Squat, Biceps Curl, Calf Raise, Floor Push-up, Lateral Raise and Shoulder Press**. Reverse Lunge, Dumbbell Row and Wall Push-up remain available to historical sessions, existing references and legacy tests pending a separate retirement assessment. Other execution modes remain intact.

## Phase 1 — verified 11 November 2026

- Curl, Calf Raise and Lateral Raise now measure watchdog silence from accepted result delivery, matching Squat/Shoulder Press. Incoming250ms capture-age/gap gates and all movement, confidence and dwell thresholds remain unchanged. Deterministic steady200ms inference cases reproduce the old reset and pass after the fix; true delivery absence still resets tracking.
- Geometry and watchdog loss invalidate current-source speech across retained sessions. Completed observation semantics are preserved for Phase 2.
- Detector failures retire the failed model before deliberate retry. Inference requests have a5s failure deadline. UI cleanup waits are bounded, but a deadline or isolate-kill request is never treated as proof that native work exited. A shared physical-camera lease survives route replacement until real cleanup and worker exit confirm release. Pending native work can keep capture unavailable; restarting capture concurrently is deliberately prevented.
- Frozen local results are written before optional camera/audio teardown. Save retries reuse the same observation. Generic setup copy no longer contradicts front-view instructions.

Fresh verification: **325 Mobile tests passed,13 optional diagnostic skips** across52 affected files with preview enabled; **759 pose tests passed**; **18-file scoped analysis clean**; arm64 Debug APK built successfully. Retained artifact: `build/module2-phase1-20261110/phase1-app-debug.apk`, SHA256 `875A9BFF5F272F2FDB8130BC6DDC7FD4812CD51562AE8AAC7BDE1AA54F80E293`. The backup integration fixture now compiles because of a separately modified domain file; that change is excluded from this commit. An intermediate run incorrectly enabled the baseline define for a test explicitly asserting ordinary-build defaults; the final run uses the correct preview define.

Independent review identified cross-route ownership and unconfirmed isolate termination gaps. Both have RED→GREEN regression coverage. No physical device was touched. No detector model/backend, movement algorithm, rep threshold, scheduling backend, schema, catalog or historical record changed. Diagnostic metrics remain bounded scalars; Phase 0's physical profiling procedure still applies. Real camera permission/native termination, exercise accuracy, memory/thermal behavior and audible latency require device acceptance.

Modified production areas: retained six sessions, shared preview controller, Android camera and BlazePose worker lifecycle, Curl/Calf/Lateral watchdog timestamps and neutral preparation copy. Added recovery/ownership/session lifecycle/worker-exit and delivery-timing regressions. Documentation includes the execution ledger and operational references. Existing unrelated changes are preserved through partial staging; verification ran against the inspected working tree, not an isolated clean checkout.

## Phase 2

Implementation and verification pending.
