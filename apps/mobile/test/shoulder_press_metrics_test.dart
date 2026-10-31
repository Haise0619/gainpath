import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'row_pose_metrics_test.dart' show rowMetrics;

Map<String, Object?> shoulderPressMetrics() => {
      ...rowMetrics(),
      'schemaVersion': 4,
      'scoringVersion': 'dumbbell-shoulder-press-front-v1',
      'cameraView': 'front'
    }..remove('rowSide');
WorkoutSessionSummary pressSummary(
    {String exercise = 'dumbbell-shoulder-press-front-v1',
    String organization = 'gainpath',
    int accuracy = 0}) {
  final at = DateTime.utc(2026, 10, 28, 1);
  return WorkoutSessionSummary(
      sessionId: 'press-local',
      userId: 'member',
      organizationId: organization,
      exerciseId: exercise,
      repetitions: 2,
      accuracy: accuracy,
      startedAt: at,
      endedAt: at.add(const Duration(seconds: 20)),
      provenance: WorkoutProvenance.recordedFixture,
      poseMetrics: WorkoutPoseMetrics.fromJson(shoulderPressMetrics()));
}

void main() {
  test('schema-four front-view metrics round trip without a score', () {
    final m = WorkoutPoseMetrics.fromJson(shoulderPressMetrics());
    expect(m.toJson(), shoulderPressMetrics());
    expect(WorkoutPoseMetrics.fromJson(m.toJson()), m);
    expect(m.formScorePercent, isNull);
    final s = pressSummary();
    expect(WorkoutSessionSummary.fromJson(s.toJson()), s);
    expect(s.isEligibleForRealUpload, false);
  });
  test('front-view schema rejects legacy versions, scores and arm metadata',
      () {
    for (final change in <Map<String, Object?>>[
      {'schemaVersion': 1},
      {'schemaVersion': 2},
      {'schemaVersion': 3},
      {'schemaVersion': '4'},
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
              {...shoulderPressMetrics(), ...change}),
          throwsFormatException,
          reason: change.toString());
    }
  });
  test(
      'press summaries bind exact organization/exercise with zero legacy accuracy',
      () {
    expect(() => pressSummary(accuracy: 90).toJson(), throwsFormatException);
    expect(
        () => pressSummary(exercise: 'squat').toJson(), throwsFormatException);
    expect(() => pressSummary(organization: 'other').toJson(),
        throwsFormatException);
  });
}
