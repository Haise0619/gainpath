import 'dart:convert';
import 'package:test/test.dart';
import '../tool/squat_fixture_evaluator.dart';
import 'support/squat_fixture_sample.dart';

void main() {
  test(
      'parsed fixtures detach from mutable input and expose immutable collections',
      () {
    final doc = fixtureDocument();
    final fixture = SquatFixture.fromJson(doc);
    final originalX = fixture.frames.first.pose.landmarks.values.first.x;
    (doc['expected'] as Map)['fullRepetitions'] = 99;
    final inputFrames = doc['frames'] as List;
    ((inputFrames.first as Map)['landmarks'] as Map)['leftShoulder']['x'] = 9;
    inputFrames.clear();
    doc['detectorId'] = 'changed';
    expect(fixture.frames.length, 72);
    expect(fixture.expected['fullRepetitions'], 1);
    expect(fixture.detectorId, 'fixture');
    expect(fixture.frames.first.pose.landmarks.values.first.x, originalX);
    expect(() => fixture.frames.clear(), throwsUnsupportedError);
    expect(
        () => fixture.expected['fullRepetitions'] = 2, throwsUnsupportedError);
    expect(() => fixture.frames.first.pose.landmarks.clear(),
        throwsUnsupportedError);
    expect(evaluateSquatFixture(fixture)['countMatch'], true);
  });
  test(
      'delivery order is validated independently from strictly ordered capture time',
      () {
    final doc = fixtureDocument();
    final frames = (doc['frames'] as List).take(2).toList();
    doc['frames'] = frames;
    (frames.first as Map)['deliveredAtMicros'] = 400000;
    (frames.last as Map)['deliveredAtMicros'] = 300000;
    expect(() => SquatFixture.fromJson(doc), throwsFormatException);
    (frames.last as Map)['deliveredAtMicros'] = 400000;
    expect(SquatFixture.fromJson(doc).frames.length, 2);
  });
  test('case capacity and total timing span have explicit upper bounds', () {
    Map<String, Object?> empty(int timestamp) => {
          'capturedAtMicros': timestamp,
          'deliveredAtMicros': timestamp,
          'imageWidth': 640,
          'imageHeight': 720,
          'isMirrored': false,
          'posePresence': null,
          'landmarks': <String, Object?>{}
        };
    final atLimit = {
      ...fixtureDocument(),
      'frames': List.generate(maximumFixtureFrames, (i) => empty(i))
    };
    expect(SquatFixture.fromJson(atLimit).frames.length, maximumFixtureFrames);
    final overLimit = {
      ...atLimit,
      'frames': List.generate(maximumFixtureFrames + 1, (i) => empty(i))
    };
    expect(() => SquatFixture.fromJson(overLimit), throwsFormatException);
    final longSpan = {
      ...fixtureDocument(),
      'frames': [empty(0), empty(86400000001)]
    };
    expect(() => SquatFixture.fromJson(longSpan), throwsFormatException);
  });
  test(
      'labelled synthetic full squat reports counts and aggregate timing without raw coordinates',
      () {
    final report = evaluateSquatFixture(
        SquatFixture.fromJson(fixtureDocument(deliveryAgeMicros: 20000)));
    expect(report['countMatch'], true);
    expect(report['provenance'], 'synthetic_fixture');
    expect(report['serverEligible'], false);
    final observed = report['observed'] as Map;
    expect(observed['fullRepetitions'], 1);
    expect(observed['partialRepetitions'], 0);
    final timing = report['timing'] as Map;
    expect((timing['captureToDeliveryMicros'] as Map)['p95'], 20000);
    expect((timing['analyzerProcessingMicros'] as Map)['samples'], 72);
    expect(timing['physicalCameraLatencyMeasured'], false);
    final output = jsonEncode(report);
    for (final raw in [
      'landmarks',
      'leftShoulder',
      'visibility',
      'frames',
      'worldLandmarks'
    ]) {
      expect(output.contains('"$raw"'), false);
    }
  });
  test('partial attempt and supported deviation counts compare independently',
      () {
    final report = evaluateSquatFixture(SquatFixture.fromJson(fixtureDocument(
        bottom: 120,
        lean: 60,
        expectedFull: 0,
        expectedPartial: 1,
        expectedLean: 1,
        expectedDepth: 1)));
    expect(report['countMatch'], true, reason: jsonEncode(report));
    expect((report['observed'] as Map)['partialRepetitions'], 1);
  });
  test(
      'wrong labels report signed and absolute count errors rather than invented percentage accuracy',
      () {
    final report = evaluateSquatFixture(
        SquatFixture.fromJson(fixtureDocument(expectedFull: 3)));
    expect(report['countMatch'], false);
    expect((report['countErrors'] as Map)['fullRepetitions'],
        {'signed': -2, 'absolute': 2});
    expect(report.containsKey('accuracyPercent'), false);
  });
  test(
      'standing-only and stale-delivery fixtures cannot fabricate counts or form',
      () {
    for (final doc in [
      fixtureDocument(cycle: false, expectedFull: 0),
      fixtureDocument(deliveryAgeMicros: 300000, expectedFull: 0)
    ]) {
      final report = evaluateSquatFixture(SquatFixture.fromJson(doc));
      expect(report['countMatch'], true);
      expect((report['observed'] as Map)['estimatedFormScorePercent'], isNull);
    }
  });
  test(
      'parser requires exact metadata, independent expected counts and fixture provenance',
      () {
    final base = fixtureDocument();
    for (final changed in <Map<String, Object?>>[
      {...base}..remove('expected'),
      {...base, 'provenance': 'real_camera'},
      {...base, 'schemaVersion': 2},
      {...base, 'rawVideo': []},
      {...base, 'caseId': '../private'},
      {...base, 'frames': []},
      {
        ...base,
        'expected': {'fullRepetitions': 1}
      },
    ]) {
      expect(() => SquatFixture.fromJson(changed), throwsFormatException);
    }
  });
  test(
      'parser refuses invalid timing, unknown joints and nonfinite confidence values',
      () {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (f) => f['deliveredAtMicros'] = 0,
      (f) => f['imageWidth'] = 0,
      (f) => f['posePresence'] = double.nan,
      (f) => f['capturedAtMicros'] = -1,
      (f) => (f['landmarks'] as Map)['inventedJoint'] = {
            'x': 0,
            'y': 0,
            'z': 0,
            'visibility': 1,
            'presence': 1
          },
      (f) => (f['landmarks'] as Map)['leftShoulder']['visibility'] = 2,
    ]) {
      final doc = fixtureDocument();
      final f = (doc['frames'] as List).first as Map<String, Object?>;
      mutation(f);
      expect(() => SquatFixture.fromJson(doc), throwsFormatException);
    }
    final doc = fixtureDocument();
    final frames = doc['frames'] as List;
    frames[1] = frames[0];
    expect(() => SquatFixture.fromJson(doc), throwsFormatException);
  });
}
