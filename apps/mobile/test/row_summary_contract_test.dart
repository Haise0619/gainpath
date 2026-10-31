import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'row_pose_metrics_test.dart' show rowMetrics;

WorkoutSessionSummary rowSummary(
    {String exercise = 'single-arm-dumbbell-row-side-v1',
    String organization = 'gainpath',
    int accuracy = 0}) {
  final at = DateTime.utc(2026, 10, 28, 1);
  return WorkoutSessionSummary(
      sessionId: 'row-local',
      userId: 'row-member',
      organizationId: organization,
      exerciseId: exercise,
      repetitions: 2,
      accuracy: accuracy,
      startedAt: at,
      endedAt: at.add(const Duration(seconds: 20)),
      provenance: WorkoutProvenance.recordedFixture,
      poseMetrics: WorkoutPoseMetrics.fromJson(rowMetrics()));
}

void main() {
  test('row identity cannot carry a legacy analyser result', () {
    final json = rowSummary().toJson();
    final metrics = Map<String, Object?>.from(json['poseMetrics'] as Map);
    metrics.remove('rowSide');
    metrics['schemaVersion'] = 1;
    metrics['scoringVersion'] = 'bodyweight-squat-side-v1';
    json['poseMetrics'] = metrics;
    expect(() => WorkoutSessionSummary.fromJson(json), throwsFormatException);
  });
  test('local row summaries reject invented legacy accuracy', () {
    expect(() => rowSummary(accuracy: 80).toJson(), throwsFormatException);
  });
  test('local row evidence binds exact registered organization and exercise',
      () {
    expect(
        () => rowSummary(exercise: 'standing-single-arm-curl-side-v1').toJson(),
        throwsFormatException);
    expect(() => rowSummary(organization: 'another-gym').toJson(),
        throwsFormatException);
    expect(WorkoutSessionSummary.fromJson(rowSummary().toJson()), rowSummary());
  });
}
