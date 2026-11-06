import 'package:gainpath_pose/gainpath_pose.dart';

const maximumFloorFixtureBytes = 16 * 1024 * 1024;
Never _invalid() =>
    throw const FormatException('Invalid floor push-up fixture.');
Map<String, Object?> _map(Object? v) {
  if (v is! Map || v.keys.any((k) => k is! String)) _invalid();
  return Map<String, Object?>.from(v);
}

void _fields(Map<String, Object?> m, Set<String> keys) {
  if (m.length != keys.length || !keys.every(m.containsKey)) _invalid();
}

int _integer(Object? v, [int max = 9007199254740991]) {
  if (v is! int || v < 0 || v > max) _invalid();
  return v;
}

double _number(Object? v, double min, double max) {
  if (v is! num || !v.isFinite || v < min || v > max) _invalid();
  return v.toDouble();
}

Map<PoseLandmark, PosePoint> _points(Object? raw) {
  final points = <PoseLandmark, PosePoint>{};
  for (final e in _map(raw).entries) {
    final id = PoseLandmark.values.where((id) => id.name == e.key).firstOrNull;
    if (id == null) _invalid();
    final p = _map(e.value);
    _fields(p, {'x', 'y', 'z', 'visibility', 'presence'});
    points[id] = PosePoint(
        x: _number(p['x'], -10, 10),
        y: _number(p['y'], -10, 10),
        z: _number(p['z'], -10, 10),
        visibility: _number(p['visibility'], 0, 1),
        presence: p['presence'] == null ? null : _number(p['presence'], 0, 1));
  }
  return points;
}

/// Replay against supplied reference annotations. It does not establish capture
/// trust or a population accuracy estimate, even when video metadata is supplied.
Map<String, Object?> evaluateFloorPushUpFixture(Map<String, Object?> json) {
  _fields(json, {
    'schemaVersion',
    'caseId',
    'evidenceKind',
    'videoId',
    'annotator',
    'detectorId',
    'detectorVersion',
    'reference',
    'frames'
  });
  if (json['schemaVersion'] != 1 ||
      !{'synthetic_landmarks', 'annotated_video'}
          .contains(json['evidenceKind'])) {
    _invalid();
  }
  for (final key in ['caseId', 'detectorId', 'detectorVersion']) {
    if (json[key] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(json[key] as String)) {
      _invalid();
    }
  }
  if (json['evidenceKind'] == 'annotated_video') {
    for (final key in ['videoId', 'annotator']) {
      if (json[key] is! String ||
          (json[key] as String).trim().isEmpty ||
          (json[key] as String).length > 128) {
        _invalid();
      }
    }
  } else if (json['videoId'] != null || json['annotator'] != null) {
    _invalid();
  }
  final ref = _map(json['reference']);
  _fields(ref, {'repetitions', 'partialRepetitions', 'issueCounts'});
  final expectedReps = _integer(ref['repetitions'], 10000),
      expectedPartial = _integer(ref['partialRepetitions'], 10000);
  final expectedIssues = _map(ref['issueCounts']);
  for (final e in expectedIssues.entries) {
    if (!FloorPushUpIssue.values.any((i) => i.name == e.key)) _invalid();
    _integer(e.value, 10000);
  }
  final rawFrames = json['frames'];
  if (rawFrames is! List || rawFrames.isEmpty || rawFrames.length > 20000) {
    _invalid();
  }
  final analyzer = FloorPushUpAnalyzer();
  int? previousCapture, previousDelivery, firstCapture;
  for (final raw in rawFrames) {
    final f = _map(raw);
    _fields(f, {
      'capturedAtMicros',
      'deliveredAtMicros',
      'imageWidth',
      'imageHeight',
      'isMirrored',
      'posePresence',
      'landmarks',
      'worldLandmarks'
    });
    final capture = _integer(f['capturedAtMicros']),
        delivery = _integer(f['deliveredAtMicros']);
    firstCapture ??= capture;
    if ((previousCapture != null && capture <= previousCapture) ||
        (previousDelivery != null && delivery < previousDelivery) ||
        delivery < capture ||
        delivery - firstCapture > 86400000000 ||
        f['isMirrored'] is! bool) {
      _invalid();
    }
    previousCapture = capture;
    previousDelivery = delivery;
    final width = _integer(f['imageWidth'], 16384),
        height = _integer(f['imageHeight'], 16384);
    if (width == 0 || height == 0) _invalid();
    analyzer.update(
        PoseFrame(
            capturedAtMicros: capture,
            detectorId: json['detectorId'] as String,
            modelVersion: json['detectorVersion'] as String,
            imageWidth: width,
            imageHeight: height,
            isMirrored: f['isMirrored'] as bool,
            posePresence: f['posePresence'] == null
                ? null
                : _number(f['posePresence'], 0, 1),
            landmarks: _points(f['landmarks']),
            worldLandmarks: _points(f['worldLandmarks'])),
        nowMicros: delivery);
  }
  analyzer.finish();
  final u = analyzer.snapshot;
  final disagreements = <String, Object>{};
  for (final issue in FloorPushUpIssue.values) {
    final expected = expectedIssues[issue.name] ?? 0,
        actual = u.issueCounts[issue] ?? 0;
    if (expected != actual) {
      disagreements[issue.name] = {'expected': expected, 'observed': actual};
    }
  }
  final repError = u.repetitions - expectedReps,
      partialError = u.partialRepetitions - expectedPartial;
  return {
    'schemaVersion': 1,
    'caseId': json['caseId'],
    'evidenceKind': json['evidenceKind'],
    'videoId': json['videoId'],
    'annotator': json['annotator'],
    'scoringVersion': analyzer.rules.version,
    'sourceVersion': FloorPushUpRules.sourceVersion,
    'configuration': analyzer.rules.toJson(),
    'frameCount': rawFrames.length,
    'repetitionCountError': repError,
    'partialCountError': partialError,
    'absoluteRepetitionCountError': repError.abs(),
    'formRuleDisagreements': disagreements,
    'matchesReference':
        repError == 0 && partialError == 0 && disagreements.isEmpty,
    'observed': {
      'repetitions': u.repetitions,
      'partialRepetitions': u.partialRepetitions,
      'issueCounts': u.issueCounts.map((k, v) => MapEntry(k.name, v)),
      'estimatedFormScorePercent': u.formScorePercent
    },
    'realVideoAccuracyEstablished': false,
    'recommendationEligible': false
  };
}
