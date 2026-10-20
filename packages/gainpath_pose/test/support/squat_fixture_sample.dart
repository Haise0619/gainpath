import 'package:gainpath_pose/gainpath_pose.dart';
import '../squat_analyzer_test.dart' show sample;

Map<String, Object?> fixtureDocument(
    {bool cycle = true,
    double bottom = 75,
    double lean = 0,
    int expectedFull = 1,
    int expectedPartial = 0,
    int expectedLean = 0,
    int expectedDepth = 0,
    int deliveryAgeMicros = 0}) {
  var time = 0;
  final frames = <Map<String, Object?>>[];
  void send(double angle, {double trunkLean = 0}) {
    time += 100000;
    final pose = sample(time, angle, lean: trunkLean);
    frames
        .add(frameDocument(pose, deliveredAtMicros: time + deliveryAgeMicros));
  }

  for (var i = 0; i < 12; i++) {
    send(175);
  }
  if (cycle) {
    for (var i = 1; i <= 20; i++) {
      send(175 + (bottom - 175) * i / 20, trunkLean: lean);
    }
    for (var i = 0; i < 8; i++) {
      send(bottom, trunkLean: lean);
    }
    for (var i = 1; i <= 20; i++) {
      send(bottom + (175 - bottom) * i / 20, trunkLean: lean);
    }
    for (var i = 0; i < 12; i++) {
      send(175);
    }
  }
  return {
    'schemaVersion': 1,
    'caseId': 'analytic-squat',
    'provenance': 'synthetic_fixture',
    'detectorId': 'fixture',
    'detectorVersion': 'analytic-v1',
    'expected': {
      'fullRepetitions': expectedFull,
      'partialRepetitions': expectedPartial,
      'deviations': {
        'trunkLean': expectedLean,
        'incompleteDepth': expectedDepth
      }
    },
    'frames': frames
  };
}

Map<String, Object?> frameDocument(PoseFrame pose,
        {required int deliveredAtMicros}) =>
    {
      'capturedAtMicros': pose.capturedAtMicros,
      'deliveredAtMicros': deliveredAtMicros,
      'imageWidth': pose.imageWidth,
      'imageHeight': pose.imageHeight,
      'isMirrored': pose.isMirrored,
      'posePresence': pose.posePresence,
      'landmarks': pose.landmarks.map((id, p) => MapEntry(
              id.name, <String, Object?>{
            'x': p.x,
            'y': p.y,
            'z': p.z,
            'visibility': p.visibility,
            'presence': p.presence
          }))
    };
