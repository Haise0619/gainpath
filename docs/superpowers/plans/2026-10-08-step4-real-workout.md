# Step 4: real squat UI and durable local results

User authorization: proceed to the next handoff step after Step 3. Continue the
previously authorized parallel workflow. This implements the existing Step 4
design; it does not deploy the Step 5 service or assert physical validation.

## Design and ownership

- Coordinating chat: add a refined-pose callback at the existing camera pipeline
  boundary; own a real-session coordinator with stable end/save/retry state;
  integrate camera, analysis and audio lifecycle; route the explicitly bound
  published squat into the existing live/result screen entry points. Preserve
  mock composition. Use existing visual tokens/components and accessible labels.
- Other chat: backward-compatible bounded measured summary fields, scoped durable
  persistence and restart/idempotency tests. No UI/camera edits there.
- Use the existing shared checkout because prerequisite changes are uncommitted.
  The subsequent 2026-10-12 instruction authorizes scoped commits and pushes.
  No physical validation is implied by an APK build.
- Start only the exact supported published exercise/org binding, with explicit
  local camera consent and side-view/upright stationary setup. Explain provisional
  guidance and local-only storage. No invented server consent acknowledgement.
- Reuse the existing result shell with measured reps, partials, valid/rejected
  duration, supported deviations and nullable form score. No fabricated rewards,
  per-exercise random scores or assumed whole-routine completion for real mode.
- End freezes one summary and closes capture/audio before saving. Repeated end
  calls share one future; retry preserves ID, chronology and metrics. Only show
  saved after durable storage returns. Pending local is distinct from accepted.
- Account changes, lifecycle pause/background, camera failure and late frames
  cannot count or leak results into a new account. No route activates real upload.

## Verification

- [x] Refined callback tests (single delivered result, late/lost invalidation).
- [x] Real coordinator tests: consent, measured updates, pause/background, end
  idempotency, save failure/retry, account change, resource cleanup.
- [x] UI tests: real entry binding/setup, measured/null metrics, error/retry,
  save status, no fake rewards; preserve mock/catalog regressions.
- [x] Other chat persistence/restart evidence and cross-boundary review.
- [x] Full mobile/pure suites and source analysis; independent review fixes.

Physical phone validation and labeled squat accuracy/latency remain outstanding
from Steps 2/3. Step 4 can make the local flow testable without claiming those
acceptance criteria or server acceptance have been achieved.
