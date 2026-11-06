import 'package:test/test.dart';
import 'dart:convert';
import 'dart:io';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../tool/floor_push_up_fixture_evaluator.dart';
import 'support/floor_push_up_trajectory.dart';

Map<String, Object?> fixture(
    {String source = 'synthetic_landmarks', int expected = 1}) {
  final frames = <Map<String, Object?>>[];
  var t = 0;
  for (final (angle, samples) in [
    (170.0, 14),
    (150.0, 4),
    (130.0, 4),
    (110.0, 4),
    (90.0, 12),
    (110.0, 4),
    (130.0, 4),
    (150.0, 4),
    (170.0, 12)
  ]) {
    for (var i = 0; i < samples; i++) {
      t += 50000;
      final f = floorFrame(t, angle, world: true);
      Map<String, Object> points(Map<PoseLandmark, PosePoint> values) => {
            for (final e in values.entries)
              e.key.name: <String, Object?>{
                'x': e.value.x,
                'y': e.value.y,
                'z': e.value.z,
                'visibility': e.value.visibility,
                'presence': e.value.presence
              },
          };
      frames.add({
        'capturedAtMicros': t,
        'deliveredAtMicros': t,
        'imageWidth': f.imageWidth,
        'imageHeight': f.imageHeight,
        'isMirrored': false,
        'posePresence': f.posePresence,
        'landmarks': points(f.landmarks),
        'worldLandmarks': points(f.worldLandmarks)
      });
    }
  }
  return {
    'schemaVersion': 1,
    'caseId': 'correct',
    'evidenceKind': source,
    'videoId': null,
    'annotator': null,
    'detectorId': 'fixture',
    'detectorVersion': '1',
    'reference': {
      'repetitions': expected,
      'partialRepetitions': 0,
      'issueCounts': {}
    },
    'frames': frames
  };
}

void main() {
  test('CLI reports count errors and rejects invalid inputs with bounded output', () async {
    final directory = Directory.systemTemp.createTempSync('floor-fixture-');
    try {
      final input = File('${directory.path}/fixture.json');
      Future<ProcessResult> run(List<String> arguments) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'tool/evaluate_floor_push_up_fixture.dart', ...arguments]);
      await input.writeAsString(jsonEncode(fixture()));
      final good = await run([input.path]);
      expect(good.exitCode, 0);
      expect((jsonDecode(good.stdout as String) as Map)['repetitionCountError'], 0);
      await input.writeAsString(jsonEncode(fixture(expected: 2)));
      expect((await run([input.path])).exitCode, 2);
      await input.writeAsString('{private raw video');
      final bad = await run([input.path]);
      expect(bad.exitCode, 65);
      expect(bad.stdout, isEmpty); expect(bad.stderr.toString(), isNot(contains('private')));
      expect((await run([])).exitCode, 64);
      expect((await run(['${directory.path}/missing.json'])).exitCode, 66);
    } finally { directory.deleteSync(recursive: true); }
  });
  test(
      'timestamped replay reports literal reference errors and synthetic limits',
      () {
    final result = evaluateFloorPushUpFixture(fixture());
    expect(result['repetitionCountError'], 0);
    expect(result['partialCountError'], 0);
    expect(result['formRuleDisagreements'], isEmpty);
    expect(result['matchesReference'], true);
    expect(result['realVideoAccuracyEstablished'], false);
    expect(
        evaluateFloorPushUpFixture(
            fixture(expected: 2))['repetitionCountError'],
        -1);
  });
  test('recorded annotation requires traceable video and annotator metadata',
      () {
    expect(() => evaluateFloorPushUpFixture(fixture(source: 'annotated_video')),
        throwsFormatException);
  });
  test('replay rejects duplicated clocks and unknown form labels', () {
    final f = fixture(), frames = f['frames'] as List;
    frames[1] = frames.first;
    expect(() => evaluateFloorPushUpFixture(f), throwsFormatException);
    final bad = fixture();
    (bad['reference'] as Map)['issueCounts'] = {'elbowFlare': 1};
    expect(() => evaluateFloorPushUpFixture(bad), throwsFormatException);
  });
}
