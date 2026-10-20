# Step 4 implementation evidence

The explicitly bound gainpath published squat now opens the real camera,
calibrated analyzer and optional offline voice flow after local consent and
side-view camera setup confirmation. End freezes measured full/partial reps,
nullable estimated form, tracked/rejected time and bounded supported deviations.
The account-scoped application-support store must complete before the result
claims local save. Local history can reopen measured sessions after restart.
Legacy mock sessions remain separate and measured summaries cannot use the
legacy upload/demo acceptance path.

Pause, background, rotation, stale frames and account changes interrupt counting
and require calibration. Background startup waits for foreground. Concurrent end
calls share one future; failed save retains the same result and session ID.
Camera disposal failures invalidate capture and cannot prevent saving a frozen
result. Account changes during save cannot publish results to the next account;
both history and pushed result routes retain explicit account guards.

## Verification on 2026-10-12

- Pure pose suite: 46 passed. Shared domain/data suites: 26/77 passed.
- Mobile full suite: 221 passed, 15 optional diagnostics skipped.
- Final focused coordinator suite: 11 passed, including camera-stop failure
  during background, close during freshness publication and deferred startup.
- Identity suite: 19 passed; admin suite: 9 passed.
- Mobile and admin source/test analysis: no issues.
- Profile APK built successfully. This verifies packaging, not a person's squat.
- Independent review findings reproduced and fixed with regressions: reentrant
  save reservation, terminal close preservation, 180-degree geometry invalidation,
  background initialization, recoverable camera shutdown and local-save retry.

The integration commit also captures previously uncommitted Firebase member,
profile, preferences and published-catalog prerequisites plus camera/model/audio
adapters required to build and reach this flow. Experimental source remains
behind debug controls; CPU/default beta behavior remains unchanged.

## Remaining boundary

Server consent and upload are Step 5. Local save does not assert server acceptance
or award rewards. Labeled human movement, camera-to-feedback timing and spoken
cue timing are still required for physical acceptance; production's server model
and rule enablement list remains empty until that evidence is reviewed.
