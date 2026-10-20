import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';

void main() {
  final fixture = Map<String, Object?>.from(jsonDecode(
    File('../../contracts/fixtures/submit-workout-session.v2.json')
        .readAsStringSync(),
  ) as Map);

  test(
      'Dart submission DTO preserves the shared bounded contract including nullable score',
      () {
    final payload = {...fixture, 'formScorePercent': null};
    final submission = RealWorkoutSubmission.fromJson(payload);
    expect(submission.toJson(), payload);
    expect(submission.scope.userId, 'member-1');
    expect(submission.scope.organizationId, 'gainpath');
    payload['memberId'] = 'tampered';
    expect(submission.scope.userId, 'member-1');
    expect(() => submission.toJson()['memberId'] = 'tampered',
        throwsUnsupportedError);
  });

  test('Dart submission rejects demo, legacy, raw media and unsupported views',
      () {
    for (final change in <Map<String, Object?>>[
      {'schemaVersion': 1},
      {'provenance': 'simulated'},
      {'provenance': 'recorded_fixture'},
      {'cameraView': 'front'},
      {'memberId': 'demo-user'},
      {'organizationId': 'demo-org'},
      {'rawFrames': []},
      {'landmarks': []},
      {'detectorId': 'simulated'},
      {'detectorId': 'recorded_fixture'},
      {'consentVersion': 'old'},
      {'consentAcknowledgementId': ''},
      {'repetitions': -1},
      {'formScorePercent': double.nan},
      {'trackedDurationMillis': 600001},
      {'trackedDurationMillis': 540000, 'rejectedDurationMillis': 60001},
      {'endedAtMillis': 1790906300000},
      {'trackedDurationMillis': 0, 'formScorePercent': 80},
    ]) {
      expect(() => RealWorkoutSubmission.fromJson({...fixture, ...change}),
          throwsFormatException,
          reason: '$change');
    }
  });

  test(
      'candidate binding is exact by organization and catalog ID, retaining row targets',
      () {
    final binding = DevelopmentSquatBinding.resolve(
      organizationId: 'gainpath',
      exerciseId: 'F3b8xIr8ynBDd3gEICKX',
      sets: 3,
      reps: 8,
    );
    expect(binding?.scoringVersion, 'bodyweight-squat-side-v1');
    expect(binding?.cameraView, 'side');
    expect(binding?.sets, 3);
    expect(binding?.reps, 8);
    expect(
        DevelopmentSquatBinding.resolve(
          organizationId: 'another-org',
          exerciseId: 'F3b8xIr8ynBDd3gEICKX',
          sets: 3,
          reps: 8,
        ),
        isNull);
    expect(
        DevelopmentSquatBinding.resolve(
          organizationId: 'gainpath',
          exerciseId: 'bodyweight_squat',
          sets: 3,
          reps: 8,
        ),
        isNull);
  });

  test(
      'consent DTO binds the server acknowledgement to the account and current version',
      () {
    final consent = <String, Object?>{
      'schemaVersion': 1,
      'requestId': 'consent-request-1',
      'organizationId': 'gainpath',
      'memberId': 'member-1',
      'consentVersion': 'pose-local-summary-v1',
      'acknowledgementId': 'consent-ack-1',
      'acknowledgedAtMillis': 1790906000000,
    };
    final acknowledgement = WorkoutConsentAcknowledgement.fromJson(consent);
    expect(acknowledgement.toJson(), consent);
    expect(acknowledgement.authorizes(RealWorkoutSubmission.fromJson(fixture)),
        isTrue);
    expect(
        WorkoutConsentAcknowledgement.fromJson(
                {...consent, 'memberId': 'other'})
            .authorizes(RealWorkoutSubmission.fromJson(fixture)),
        isFalse);
    expect(
        WorkoutConsentAcknowledgement.fromJson(
                {...consent, 'acknowledgedAtMillis': 1790906500000})
            .authorizes(RealWorkoutSubmission.fromJson(fixture)),
        isFalse);
    expect(
        () => WorkoutConsentAcknowledgement.fromJson(
            {...consent, 'consentVersion': 'old'}),
        throwsFormatException);
  });
}
