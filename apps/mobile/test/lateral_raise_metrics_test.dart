import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'row_pose_metrics_test.dart' show rowMetrics;

Map<String, Object?> lateralRaiseMetrics() => {
      ...rowMetrics(),
      'schemaVersion': 6,
      'scoringVersion': 'standing-lateral-raise-front-v1',
      'cameraView': 'front'
    }..remove('rowSide');
WorkoutSessionSummary lateralSummary(
    {String exercise = 'standing-lateral-raise-front-v1',
    String organization = 'gainpath',
    int accuracy = 0}) {
  final at = DateTime.utc(2026, 10, 28, 1);
  return WorkoutSessionSummary(
      sessionId: 'lateral-local',
      userId: 'member',
      organizationId: organization,
      exerciseId: exercise,
      repetitions: 2,
      accuracy: accuracy,
      startedAt: at,
      endedAt: at.add(const Duration(seconds: 20)),
      provenance: WorkoutProvenance.recordedFixture,
      poseMetrics: WorkoutPoseMetrics.fromJson(lateralRaiseMetrics()));
}

void main() {
  test('schema-six front-view metrics round trip without a score', () {
    final m = WorkoutPoseMetrics.fromJson(lateralRaiseMetrics());
    expect(m.toJson(), lateralRaiseMetrics());
    expect(WorkoutPoseMetrics.fromJson(m.toJson()), m);
    expect(m.formScorePercent, isNull);
    final s = lateralSummary();
    expect(WorkoutSessionSummary.fromJson(s.toJson()), s);
    expect(s.isEligibleForRealUpload, false);
    final record =
        WorkoutSessionRecord(summary: s, status: WorkoutSyncStatus.pending);
    expect(WorkoutSessionRecord.fromJson(record.toJson()).summary, s);
    expect(
        () => WorkoutSessionRecord.fromJson(
            {...record.toJson(), 'status': 'accepted'}),
        throwsFormatException);
  });
  test('front-view schema rejects legacy versions, scores and arm metadata',
      () {
    for (final change in <Map<String, Object?>>[
      {'schemaVersion': 1},
      {'schemaVersion': 2},
      {'schemaVersion': 3},
      {'schemaVersion': 4},
      {'schemaVersion': 5},
      {'schemaVersion': 7},
      {'schemaVersion': '6'},
      {'scoringVersion': 'dumbbell-shoulder-press-front-v1'},
      {'lungeSide': 'left'},
      {'loadVerified': true},
      {'standingVerified': true},
      {'scoringVersion': 'single-arm-row-side-v1'},
      {'scoringVersion': 'wall-push-up-side-v1'},
      {'cameraView': 'side'},
      {'rowSide': 'left'},
      {'curlArms': {}},
      {'formScorePercent': 0},
      {
        'deviations': {
          'trunkLean': {'count': 1, 'maximumDegrees': 10}
        }
      },
    ]) {
      expect(
          () => WorkoutPoseMetrics.fromJson(
              {...lateralRaiseMetrics(), ...change}),
          throwsFormatException,
          reason: change.toString());
    }
  });
  test(
      'lateral raise summaries bind exact organization/exercise with zero legacy accuracy',
      () {
    expect(() => lateralSummary(accuracy: 90).toJson(), throwsFormatException);
    expect(() => lateralSummary(exercise: 'squat').toJson(),
        throwsFormatException);
    expect(() => lateralSummary(organization: 'other').toJson(),
        throwsFormatException);
    final forged = lateralSummary().toJson();
    forged['poseMetrics'] = rowMetrics();
    expect(() => WorkoutSessionSummary.fromJson(forged), throwsFormatException);
    expect(
        () => WorkoutSessionSummary.fromJson(
            {...lateralSummary().toJson(), 'rewardPoints': 100}),
        throwsFormatException);
  });
}
