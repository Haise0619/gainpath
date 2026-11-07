# One-time AI consent and workout continuity

Implement the owner-supplied specification in the existing Flutter architecture, including UI. Existing branch `codex/hybrid-workouts` is retained; unrelated Admin/pose edits remain excluded. No backend deployment or tracking algorithm changes.

## Design decisions

- Persist versioned consent and workout preferences in an app-private account/organization-scoped local store, separate from workout history and upload permission. Fail closed on unreadable consent. A shared observable controller makes withdrawal invalidate active capture immediately.
- Separate privacy acknowledgement from exercise-specific setup. Never skip a required side/arm/angle confirmation; reuse persistent privacy consent only. Upload opt-in stays separate and defaults off.
- Reuse RoutineJourneyController completion and checkpoint reconciliation. Only a durably saved target-complete result can trigger a rest route. Keep one launch/transition in flight, recheck attempt/day/selection/account/foreground after every asynchronous boundary.
- Use a full-screen purple rest view: saved confirmation, distance-readable countdown, upcoming mode/targets and sticky safe-area Pause/Resume, Skip Rest and View routine. Suggested rest defaults to 30 seconds; optional explicit published between-exercise rest overrides it. Per-set rest is never repurposed.
- Lifecycle interruption/route obscuring cancels automatic launch until explicit resume. Reopening a killed app uses existing checkpoints and explicit Member entry rather than resuming camera/rest automatically. Manual exercise navigation awards no sets. Existing AI setup/readiness still applies; timed auto-entry starts only after media readiness and never resumes interrupted work implicitly.

## Implementation and verification

1. Consent/preferences service, local storage and factory; version/account/withdrawal/write-failure tests. Integrate Settings privacy status/review/withdraw/re-enable, Auto-Continue and suggested rest controls.
2. Monotonic rest controller and full-screen route; single-flight, pause/resume/background/occlusion/skip and 200% text/small-screen tests.
3. Integrate persisted consent into the existing capture acknowledgement. Wrap measured entrypoints with live consent guard. Preserve Android permissions and all setup/calibration stages.
4. Integrate rest/automatic mode dispatch in journey; manual logging callback, save-failure gates and same-attempt navigation tests. Add timed auto-start/completion options with production timing engine unchanged.
5. Run affected regression tests, strict analysis, Android debug build and scoped independent review. Document exact files, UI decisions, safety exceptions and unperformed physical acceptance. Commit only owned files.

## Completion

Implemented with the existing journey and engines. Final verification: 181 tests passed across 36 affected files; analysis clean across 40 changed Dart files; Android debug APK built. Rest/UI render and focused integration review completed, with async launch/consent/manual-save interruption gates fixed and regression-tested. See `docs/ux/workout-continuity-implementation.md` for exact files, UI behavior, setup/interruption exceptions and physical-device requirements. No backend deployment or device-data change.
