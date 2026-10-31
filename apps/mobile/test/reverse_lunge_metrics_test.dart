import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'row_pose_metrics_test.dart' show rowMetrics;

Map<String, Object?> lungeMetrics({String side = 'left'}) => {
      ...rowMetrics(),
      'schemaVersion': 5,
      'scoringVersion': 'reverse-lunge-side-v1',
      'lungeSide': side,
    }..remove('rowSide');
WorkoutSessionSummary lungeSummary(
    {String exercise = 'bodyweight-reverse-lunge-side-v1',
    String organization = 'gainpath',
    int accuracy = 0}) {
  final at = DateTime.utc(2026, 10, 28, 1);
  return WorkoutSessionSummary(
      sessionId: 'lunge-local',
      userId: 'member',
      organizationId: organization,
      exerciseId: exercise,
      repetitions: 2,
      accuracy: accuracy,
      startedAt: at,
      endedAt: at.add(const Duration(seconds: 20)),
      provenance: WorkoutProvenance.realCamera,
      poseMetrics: WorkoutPoseMetrics.fromJson(lungeMetrics()));
}

void main() {
  test('schema five preserves front planted working leg through local history',
      () {
    final left = WorkoutPoseMetrics.fromJson(lungeMetrics());
    final right = WorkoutPoseMetrics.fromJson(lungeMetrics(side: 'right'));
    expect(left.toJson(), lungeMetrics());
    expect(WorkoutPoseMetrics.fromJson(left.toJson()), left);
    expect(right, isNot(left));
    final summary = lungeSummary();
    final record = WorkoutSessionRecord(
        summary: summary, status: WorkoutSyncStatus.pending);
    expect(WorkoutSessionRecord.fromJson(record.toJson()).summary, summary);
    expect(summary.isEligibleForRealUpload, false);
  });
  test(
      'lunge schema rejects downgrade, unknown side, forged score and acceptance fields',
      () {
    for (final change in <Map<String, Object?>>[
      {'schemaVersion': 1},
      {'schemaVersion': 2},
      {'schemaVersion': 3},
      {'schemaVersion': 4},
      {'schemaVersion': 6},
      {'schemaVersion': '5'},
      {'lungeSide': null},
      {'lungeSide': 'both'},
      {'scoringVersion': 'bodyweight-squat-side-v1'},
      {'cameraView': 'front'},
      {'rowSide': 'left'},
      {'curlArms': {}},
      {'formScorePercent': 0},
      {'loadVerified': true},
      {
        'deviations': {
          'trunkLean': {'count': 1, 'maximumDegrees': 10}
        }
      },
    ]) {
      expect(() => WorkoutPoseMetrics.fromJson({...lungeMetrics(), ...change}),
          throwsFormatException,
          reason: change.toString());
    }
    expect(
        () => WorkoutPoseMetrics.fromJson(lungeMetrics()..remove('lungeSide')),
        throwsFormatException);
    final json = WorkoutSessionRecord(
            summary: lungeSummary(), status: WorkoutSyncStatus.pending)
        .toJson();
    for (final change in <Map<String, Object?>>[
      {'status': 'accepted'},
      {'acceptedAt': '2026-10-28T01:01:00Z'},
      {'serverReference': 'forged'},
    ]) {
      expect(() => WorkoutSessionRecord.fromJson({...json, ...change}),
          throwsFormatException);
    }
  });
  test(
      'lunge summary binds exact registered organization and zero legacy accuracy',
      () {
    expect(() => lungeSummary(accuracy: 1).toJson(), throwsFormatException);
    expect(
        () => lungeSummary(exercise: 'squat').toJson(), throwsFormatException);
    expect(() => lungeSummary(organization: 'other').toJson(),
        throwsFormatException);
    final json = lungeSummary().toJson();
    json['poseMetrics'] = rowMetrics();
    expect(() => WorkoutSessionSummary.fromJson(json), throwsFormatException);
    expect(
        () => WorkoutSessionSummary.fromJson(
            {...lungeSummary().toJson(), 'acceptedWorkout': true}),
        throwsFormatException);
  });
  testWidgets(
      'result labels front planted leg and holds form score and rewards',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WorkoutResultScreen.measured(summary: lungeSummary())));
    await tester.pumpAndSettle();
    expect(find.text('MEASURED REVERSE LUNGE RESULT'), findsOneWidget);
    expect(find.text('Form score is not assessed for reverse lunges'),
        findsOneWidget);
    expect(
        find.textContaining('Front planted working leg: Left'), findsOneWidget);
    expect(
        find.textContaining('No rewards have been awarded.'), findsOneWidget);
    expect(find.textContaining('estimated form'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
