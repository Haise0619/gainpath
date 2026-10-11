# Step 4 persistence slice: interface and verification

The direct user request in “Review pose estimation progress” is to proceed to
Step 4, continuing the authorized parallel implementation. This chat owns only
the existing mobile workout contracts/repository/store and focused persistence
tests. The coordinating chat owns camera/session/routes/live/results integration.
No backend/upload enablement, installation, commit or pose tuning.

## Concrete interface (implemented and stable)

Import existing `features/workout/domain/workout_contracts.dart` or its existing
repository re-export; the new `workout_pose_metrics.dart` types are exported there.

Keep the existing const `WorkoutSessionSummary` constructor and required legacy
`accuracy`/`repetitions` fields. Add optional `WorkoutPoseMetrics? poseMetrics`.
`repetitions` remains the complete rep count. Convenience getters on summary:
`formScorePercent` nullable double, `partialRepetitions`, `trackedDurationMicros`,
`rejectedDurationMicros` (integer getters default 0 when metrics absent).
Use `poseMetrics != null` to distinguish measured time/counts from old unknowns.
Real results must display nullable measured score, not legacy integer `accuracy`.
For compatibility construct `accuracy: formScorePercent?.round() ?? 0`, but use
`formScorePercent` for real results so null does not appear as a measured zero.

`WorkoutPoseMetrics` constructor:

```dart
WorkoutPoseMetrics({
  required int partialRepetitions,
  required int trackedDurationMicros,
  required int rejectedDurationMicros,
  required double? formScorePercent,
  required String scoringVersion,
  required String detectorId,
  required String detectorVersion,
  required String cameraView,
  required String consentVersion,
  required DateTime consentedAt,
  String? publishedRoutineId,
  Map<String, WorkoutDeviationAggregate> deviations = const {},
});
WorkoutDeviationAggregate({required int count, required double maximumDegrees});
```

Supported deviation keys are exactly `trunkLean`, `incompleteDepth`; values count
assessable attempts exhibiting that deviation and retain their maximum degree
deviation. At most two aggregates, no attempt/landmark/frame history. Zero-count
entries must have zero maximum. Copy and freeze caller maps.

Rule version `bodyweight-squat-side-v1`, cameraView `side`, consentVersion
`pose-local-summary-v1` align with existing real contract. `consentedAt` is the
local acknowledgement time, before capture/start. This is **not** a server consent
acknowledgement and must not manufacture an acknowledgement ID or trusted grant.
Detector values come from actual processed poses (`detectorId`, `modelVersion` as
detectorVersion); publishedRoutineId is optional local context when available.
Measured summary IDs (session/user/org/exercise) use the existing wire identifier
shape, 1..128 ASCII letters/numbers/underscore/hyphen. Full repetitions and each
duration are bounded independently before summing, preventing native int overflow.

Schema: measured summaries write summarySchemaVersion 3 with nested poseMetrics
schemaVersion 1; summaries without metrics keep current v2 output. Decode legacy
unversioned/v2 unchanged; do not infer measured metrics from appended old fields.
v3 requires bounded metrics/provenance/time/consent consistency. Full+partial
attempts <=10000, aggregate counts <= attempts, duration <=24h, accepted+rejected
time <= elapsed, scores finite 0..100 and null when no assessed attempt exists.
Keep `isEligibleForRealUpload == false` for every local summary.

Existing saveLocal deduplicates by stable sessionId and compares full immutable
summary including metrics; conflicting retry payloads fail without overwrite.
Caller must retain the exact same summary/sessionId/end time when retrying a
failed save. Real-camera/recorded-fixture metrics never pass demo sync acceptance.
The built-in demo gateway also rejects direct real/fixture calls. Real/fixture
records (including v2 labels without metrics) cannot contain accepted status or
an acceptance receipt. Legacy/simulated demo acceptance remains compatible.

`WorkoutSessionSummary.validateForLocalStorage()` and record validation run at
serialization/deserialization, repository, and both store boundaries. v3 has exact
top-level fields and exact metric/aggregate fields. Current immutable constructors
do not silently repair inconsistent metrics or attach server acknowledgement IDs.
No changes to the future RealWorkoutSubmission v2 wire contract were made.

## Validation

Completed 2026-10-08:

- New measured persistence suite: **14 tests passed**, including JSON/restart,
  null score, immutable aggregates, legacy/v2 compatibility, malformed metrics,
  int-overflow regressions, both write-failure outcomes, stable-ID conflicts,
  account isolation/switch and real/fixture upload/acceptance blocking.
- Affected persistence + mock/session/history/route suites: **33 tests passed**.
- Focused `dart analyze` on all persistence-owned source/tests: **no issues**.
- Independent read-only review found overflow bounds and alternate acceptance
  paths; each was reproduced by a failing regression then corrected.

The coordinating chat owns full-app final integration verification. This slice
does not claim UI/camera/physical-person accuracy accepted, upload eligibility,
on-device restart acceptance or trusted server consent. No installation, backend
change, commit, raw frames, video or landmark-stream storage.
