import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

const maximumFixtureBytes = 16 * 1024 * 1024;
const maximumFixtureFrames = 20000;
const _maximumClock = 9007199254740991;
const _maximumDurationMicros = 86400000000;
const _countKeys = {
  'fullRepetitions',
  'partialRepetitions',
  'trunkLean',
  'incompleteDepth'
};

class SquatFixtureFrame {
  const SquatFixtureFrame(this.pose, this.deliveredAtMicros);
  final PoseFrame pose;
  final int deliveredAtMicros;
}

/// Evaluation data only. This utility has no persistence/upload dependency.
class SquatFixture {
  SquatFixture._(
      this.caseId,
      this.provenance,
      this.detectorId,
      this.detectorVersion,
      Map<String, int> expected,
      List<SquatFixtureFrame> frames)
      : expected = Map.unmodifiable(expected),
        frames = List.unmodifiable(frames);
  final String caseId, provenance, detectorId, detectorVersion;
  final Map<String, int> expected;
  final List<SquatFixtureFrame> frames;
  factory SquatFixture.fromJson(Map<String, Object?> json) {
    _exact(json, {
      'schemaVersion',
      'caseId',
      'provenance',
      'detectorId',
      'detectorVersion',
      'expected',
      'frames'
    });
    if (json['schemaVersion'] != 1 ||
        !{'recorded_fixture', 'synthetic_fixture'}
            .contains(json['provenance'])) {
      _invalid();
    }
    final caseId = _id(json['caseId']),
        detectorId = _id(json['detectorId']),
        version = _id(json['detectorVersion']);
    final labelled = _map(json['expected']);
    _exact(labelled, {'fullRepetitions', 'partialRepetitions', 'deviations'});
    final deviations = _map(labelled['deviations']);
    _exact(deviations, {'trunkLean', 'incompleteDepth'});
    final expected = <String, int>{
      'fullRepetitions': _integer(labelled['fullRepetitions'], 0, 10000),
      'partialRepetitions': _integer(labelled['partialRepetitions'], 0, 10000),
      'trunkLean': _integer(deviations['trunkLean'], 0, 10000),
      'incompleteDepth': _integer(deviations['incompleteDepth'], 0, 10000)
    };
    final raw = json['frames'];
    if (raw is! List || raw.isEmpty || raw.length > maximumFixtureFrames) {
      _invalid();
    }
    final frames = <SquatFixtureFrame>[];
    int? previousCapture, previousDelivery, firstCapture;
    for (final item in raw) {
      final frame = _map(item);
      _exact(frame, {
        'capturedAtMicros',
        'deliveredAtMicros',
        'imageWidth',
        'imageHeight',
        'isMirrored',
        'posePresence',
        'landmarks'
      });
      final capture = _integer(frame['capturedAtMicros'], 0, _maximumClock);
      final delivery =
          _integer(frame['deliveredAtMicros'], capture, _maximumClock);
      firstCapture ??= capture;
      if (previousCapture != null && capture <= previousCapture ||
          previousDelivery != null && delivery < previousDelivery ||
          delivery - firstCapture > _maximumDurationMicros) {
        _invalid();
      }
      previousCapture = capture;
      previousDelivery = delivery;
      final width = _integer(frame['imageWidth'], 1, 16384),
          height = _integer(frame['imageHeight'], 1, 16384);
      final mirrored = frame['isMirrored'];
      if (mirrored is! bool) _invalid();
      final presence = frame['posePresence'] == null
          ? null
          : _number(frame['posePresence'], 0, 1);
      final joints = _map(frame['landmarks']);
      if (joints.length > PoseLandmark.values.length) _invalid();
      final points = <PoseLandmark, PosePoint>{};
      for (final entry in joints.entries) {
        final id =
            PoseLandmark.values.where((id) => id.name == entry.key).firstOrNull;
        if (id == null) _invalid();
        final point = _map(entry.value);
        _exact(point, {'x', 'y', 'z', 'visibility', 'presence'});
        points[id] = PosePoint(
            x: _number(point['x'], -10, 10),
            y: _number(point['y'], -10, 10),
            z: _number(point['z'], -10, 10),
            visibility: _number(point['visibility'], 0, 1),
            presence: point['presence'] == null
                ? null
                : _number(point['presence'], 0, 1));
      }
      frames.add(SquatFixtureFrame(
          PoseFrame(
              capturedAtMicros: capture,
              detectorId: detectorId,
              modelVersion: version,
              imageWidth: width,
              imageHeight: height,
              isMirrored: mirrored,
              posePresence: presence,
              landmarks: points),
          delivery));
    }
    return SquatFixture._(caseId, json['provenance'] as String, detectorId,
        version, expected, frames);
  }
}

Map<String, Object?> evaluateSquatFixture(SquatFixture fixture) {
  final analyzer = SquatAnalyzer();
  final timings = <int>[], deliveryAges = <int>[];
  final health = <String, int>{};
  final deviations = {
    for (final kind in SquatDeviationKind.values) kind.name: 0
  };
  SquatUpdate? latest;
  var lastAttempt = 0;
  for (final frame in fixture.frames) {
    final stopwatch = Stopwatch()..start();
    final update =
        analyzer.update(frame.pose, nowMicros: frame.deliveredAtMicros);
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
    deliveryAges.add(frame.deliveredAtMicros - frame.pose.capturedAtMicros);
    latest = update;
    health.update(update.health.name, (count) => count + 1, ifAbsent: () => 1);
    final attempt = update.completedAttempt;
    if (attempt != null && attempt.number > lastAttempt) {
      lastAttempt = attempt.number;
      for (final deviation in attempt.deviations) {
        deviations[deviation.kind.name] = deviations[deviation.kind.name]! + 1;
      }
    }
  }
  final observedCounts = {
    'fullRepetitions': latest!.repetitions,
    'partialRepetitions': latest.partialRepetitions,
    ...deviations
  };
  final errors = {
    for (final key in _countKeys)
      key: {
        'signed': observedCounts[key]! - fixture.expected[key]!,
        'absolute': (observedCounts[key]! - fixture.expected[key]!).abs()
      }
  };
  return {
    'schemaVersion': 1,
    'caseId': fixture.caseId,
    'provenance': fixture.provenance,
    'detectorId': fixture.detectorId,
    'detectorVersion': fixture.detectorVersion,
    'scoringVersion': SquatRuleSet.version,
    'serverEligible': false,
    'frameCount': fixture.frames.length,
    'countMatch': errors.values.every((e) => e['absolute'] == 0),
    'expected': fixture.expected,
    'observed': {
      ...observedCounts,
      'estimatedFormScorePercent': latest.formScorePercent,
      'trackedDurationMicros': latest.trackedDurationMicros,
      'rejectedDurationMicros': latest.rejectedDurationMicros
    },
    'countErrors': errors,
    'healthSampleCounts': health,
    'timing': {
      'captureToDeliveryMicros': _distribution(deliveryAges),
      'analyzerProcessingMicros': _distribution(timings),
      'physicalCameraLatencyMeasured': false,
      'processingBoundary': 'host_SquatAnalyzer_update_only'
    }
  };
}

Map<String, num> _distribution(List<int> samples) {
  final sorted = List<int>.of(samples)..sort();
  int percentile(double fraction) =>
      sorted[math.max(0, (fraction * sorted.length).ceil() - 1)];
  return {
    'samples': sorted.length,
    'mean': samples.fold<int>(0, (sum, n) => sum + n) / samples.length,
    'p50': percentile(.5),
    'p95': percentile(.95),
    'maximum': sorted.last
  };
}

Never _invalid() => throw const FormatException('Invalid squat fixture.');
Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) _invalid();
  return Map<String, Object?>.from(value);
}

void _exact(Map<String, Object?> json, Set<String> fields) {
  if (json.length != fields.length || !fields.every(json.containsKey)) {
    _invalid();
  }
}

String _id(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    _invalid();
  }
  return value;
}

int _integer(Object? value, int minimum, int maximum) {
  if (value is! int || value < minimum || value > maximum) _invalid();
  return value;
}

double _number(Object? value, double minimum, double maximum) {
  if (value is! num || !value.isFinite || value < minimum || value > maximum) {
    _invalid();
  }
  return (value).toDouble();
}
