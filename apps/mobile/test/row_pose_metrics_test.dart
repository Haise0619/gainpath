import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_pose_metrics.dart';

Map<String, Object?> rowMetrics({String side = 'left'}) => {
      'schemaVersion': 3,
      'rowSide': side,
      'partialRepetitions': 1,
      'trackedDurationMicros': 8000000,
      'rejectedDurationMicros': 1000000,
      'formScorePercent': null,
      'scoringVersion': 'single-arm-row-side-v1',
      'detectorId': 'blazepose-tflite',
      'detectorVersion': 'v1',
      'cameraView': 'side',
      'consentVersion': 'pose-local-summary-v1',
      'consentedAt': '2026-10-28T01:00:00.000Z',
      'publishedRoutineId': 'routine',
      'deviations': <String, Object?>{},
    };

void main() {
  test('selected row side survives serialization and affects value identity',
      () {
    final left = WorkoutPoseMetrics.fromJson(rowMetrics());
    final restored = WorkoutPoseMetrics.fromJson(left.toJson());
    final right = WorkoutPoseMetrics.fromJson(rowMetrics(side: 'right'));
    expect(left.toJson(), rowMetrics());
    expect(restored, left);
    expect(restored.hashCode, left.hashCode);
    expect(right.toJson()['rowSide'], 'right');
    expect(right, isNot(left));
    expect(left.formScorePercent, isNull);
  });

  test('row metrics reject missing side, legacy schema, scores and curl data',
      () {
    final invalid = <Map<String, Object?>>[
      rowMetrics()..remove('rowSide'),
      {...rowMetrics(), 'rowSide': null},
      {...rowMetrics(), 'rowSide': 'both'},
      {...rowMetrics(), 'rowSide': 'LEFT'},
      {...rowMetrics(), 'schemaVersion': 1},
      {...rowMetrics(), 'schemaVersion': 2},
      {...rowMetrics(), 'schemaVersion': '3'},
      {...rowMetrics(), 'scoringVersion': 'single-arm-row-side-v2'},
      {...rowMetrics(), 'formScorePercent': 0},
      {...rowMetrics(), 'formScorePercent': 90},
      {...rowMetrics(), 'cameraView': 'front'},
      {...rowMetrics(), 'curlArms': <String, Object?>{}},
      {
        ...rowMetrics(),
        'deviations': {
          'trunkLean': {'count': 1, 'maximumDegrees': 5}
        }
      },
    ];
    for (final value in invalid) {
      expect(() => WorkoutPoseMetrics.fromJson(value), throwsFormatException,
          reason: value.toString());
    }
  });

  test('all old scoring versions forbid row metadata and schema three', () {
    for (final version in [
      'bodyweight-squat-side-v1',
      'single-arm-curl-side-v1',
      'standing-calf-raise-side-v1',
      'wall-push-up-side-v1',
    ]) {
      final old = {
        ...rowMetrics(),
        'schemaVersion': 1,
        'scoringVersion': version
      }..remove('rowSide');
      expect(WorkoutPoseMetrics.fromJson(old).toJson(), old);
      for (final value in [
        {...old, 'rowSide': 'left'},
        {...old, 'schemaVersion': 3, 'rowSide': 'right'},
      ]) {
        expect(() => WorkoutPoseMetrics.fromJson(value), throwsFormatException);
      }
    }
  });

  test('legacy curl schema keeps its exact shape and arm aggregates', () {
    final old = {
      ...rowMetrics(),
      'schemaVersion': 2,
      'scoringVersion': 'single-arm-curl-side-v1',
      'partialRepetitions': 0,
      'formScorePercent': 80,
      'curlArms': {
        'mode': 'leftOnly',
        'targetSets': 1,
        'repetitionsPerArm': 2,
        'completedSets': 1,
        'left': {
          'repetitions': 2,
          'partialRepetitions': 0,
          'formScorePercent': 80
        },
        'right': {
          'repetitions': 0,
          'partialRepetitions': 0,
          'formScorePercent': null
        },
      }
    }..remove('rowSide');
    final metrics = WorkoutPoseMetrics.fromJson(old);
    expect(metrics.toJson(), old);
    expect(WorkoutPoseMetrics.fromJson(metrics.toJson()), metrics);
    expect(() => WorkoutPoseMetrics.fromJson({...old, 'rowSide': 'left'}),
        throwsFormatException);
  });
}
