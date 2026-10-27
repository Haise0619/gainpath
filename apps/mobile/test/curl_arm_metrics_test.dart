import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';

void main() {
  CurlArmResult arm(int reps, {double? score}) => CurlArmResult(
      repetitions: reps,
      partialRepetitions: 0,
      formScorePercent: reps == 0 ? null : score ?? 90);
  CurlArmMetrics metrics({int completed = 0}) => CurlArmMetrics(
      mode: CurlArmMode.both,
      targetSets: 1,
      repetitionsPerArm: 5,
      completedSets: completed,
      left: arm(5),
      right: arm(0));
  WorkoutPoseMetrics pose(CurlArmMetrics? arms) => WorkoutPoseMetrics(
      curlArms: arms,
      partialRepetitions: 0,
      trackedDurationMicros: 1000000,
      rejectedDurationMicros: 0,
      formScorePercent: 90,
      scoringVersion: 'single-arm-curl-side-v1',
      detectorId: 'fixture',
      detectorVersion: '1',
      cameraView: 'side',
      consentVersion: 'pose-local-summary-v1',
      consentedAt: DateTime.utc(2026, 10, 25));
  test('completed-set evidence cannot exceed either selected arm', () {
    expect(() => metrics(completed: 1), throwsFormatException);
    expect(metrics().completes(1, 5), false);
  });
  test('unselected arm cannot contain invented repetitions', () {
    expect(
        () => CurlArmMetrics(
            mode: CurlArmMode.rightOnly,
            targetSets: 1,
            repetitionsPerArm: 5,
            completedSets: 0,
            left: arm(1),
            right: arm(0)),
        throwsFormatException);
  });
  test(
      'versioned arm metrics round trip while legacy curl metrics remain readable',
      () {
    final value = pose(metrics());
    expect(value.toJson()['schemaVersion'], 2);
    expect(WorkoutPoseMetrics.fromJson(value.toJson()), value);
    final legacy = pose(null);
    expect(legacy.toJson()['schemaVersion'], 1);
    expect(WorkoutPoseMetrics.fromJson(legacy.toJson()), legacy);
  });
  test('local summary rejects counts inconsistent with its arm breakdown', () {
    final start = DateTime.utc(2026, 10, 25);
    final summary = WorkoutSessionSummary(
        sessionId: 'arms',
        userId: 'member',
        organizationId: 'gainpath',
        exerciseId: 'standing-single-arm-curl-side-v1',
        repetitions: 6,
        accuracy: 90,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 2)),
        provenance: WorkoutProvenance.recordedFixture,
        poseMetrics: pose(metrics()));
    expect(summary.toJson, throwsFormatException);
  });
}
