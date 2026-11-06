import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/floor_push_up_projection_fixture.dart';

void main() {
  test('limb suspension before departure makes the completed attempt unscored',
      () {
    final r = ProjectionReplay()..hold(170, 10);
    r.feed(150);
    r.feed(140);
    r.feed(140, upper: 1.4);
    r.feed(140);
    r.hold(140, 4);
    r.hold(90, 8);
    r.finishCycle();
    expect(r.a.snapshot.repetitions, 1);
    expect(r.a.snapshot.formScorePercent, isNull);
  });
  test('abrupt return inside TOP baseline cannot bypass trajectory validation',
      () {
    final r = ProjectionReplay()..start();
    r.feed(85, upper: .80, forearm: .80);
    r.feed(85, upper: .64, forearm: .64);
    expect(r.a.snapshot.geometry, isNotNull);
    r.feed(85); // 56.25% adjacent expansion despite matching initial TOP limbs.
    expect(r.a.snapshot.geometry, isNull);
    expect(r.a.snapshot.rejection, FloorPushUpRejection.limbChange);
  });
  for (final right in [false, true]) {
    for (final caseId in ['A', 'B', 'B2', 'C']) {
      test(
          'measured projection sequence $caseId counts with independent trajectory validation side=$right',
          () {
        final r = ProjectionReplay(right: right);
        if (caseId == 'C') {
          r.hold(170, 10);
        } else {
          r.start();
        }
        switch (caseId) {
          case 'A':
            r.feed(85, forearm: .90);
            r.feed(82.26, forearm: .815);
            r.feed(90.13, upper: .789, forearm: .733);
            r.feed(91.18, upper: .743, forearm: .727);
            expect(r.a.snapshot.geometry, isNotNull);
            expect(r.a.snapshot.phase, FloorPushUpPhase.bottom);
            r.feed(98.13, upper: .85, forearm: .82);
          case 'B':
            r.feed(85.14, upper: .785, forearm: .885);
            r.feed(77.73, upper: .671, forearm: .753);
            expect(r.a.snapshot.geometry, isNotNull);
            r.feed(62.93, upper: .80, forearm: .88);
          case 'B2':
            r.feed(83.94, upper: .869, forearm: .765);
            r.feed(76.42, upper: .822, forearm: .788);
            r.feed(69.33, upper: .821, forearm: .640);
            expect(r.a.snapshot.geometry, isNotNull);
            r.feed(70.41, upper: .814, forearm: .615);
            r.feed(67.17, upper: .90, forearm: .75);
            r.feed(67.17, upper: .95, forearm: .85);
          case 'C':
            r.feed(126.42, forearm: .83);
            r.feed(104.56, forearm: .71);
            expect(r.a.snapshot.geometry, isNotNull);
            r.hold(84.18, 6, forearm: .80);
        }
        r.finishCycle();
        expect(r.a.snapshot.repetitions, 1);
        expect(r.a.snapshot.partialRepetitions, 0);
        expect(r.a.snapshot.formScorePercent, isNull);
        r.hold(170, 15);
        expect(r.a.snapshot.repetitions, 1);
      });
    }
  }
  test(
      'a short rejected interval during descent restarts observed bottom dwell',
      () {
    final r = ProjectionReplay()..start(bottom: false);
    expect(r.a.snapshot.phase, FloorPushUpPhase.descending);
    r.feed(100, upper: 1.4);
    expect(r.a.snapshot.geometry, isNull);
    expect(r.a.snapshot.phase, FloorPushUpPhase.descending);
    expect(r.a.diagnostics['bottomCredit'], false);
    r.feed(90, upper: 1.4);
    expect(r.a.diagnostics['bottomCredit'], false);
    r.feed(90);
    expect(r.a.diagnostics['bottomCredit'], false);
    r.hold(90, 6);
    r.finishCycle();
    expect(r.a.snapshot.repetitions, 1);
    expect(r.a.snapshot.formScorePercent, isNull);
  });
  for (final fault in [
    'noWorld',
    'lowConfidence',
    'swap',
    'persistentJump',
    'missingBottom',
    'missingExtension',
    'longGap'
  ]) {
    test('$fault never fabricates a complete cycle', () {
      final r = ProjectionReplay()..start(bottom: false);
      switch (fault) {
        case 'noWorld':
          r.feed(90, forearm: .70, world: false);
          r.feed(90, forearm: .70, world: false);
          r.feed(90, forearm: .70, world: false);
          r.feed(90, forearm: .70, world: false);
          r.feed(90, forearm: .70, world: false);
        case 'lowConfidence':
          for (var i = 0; i < 6; i++) {
            r.feed(90, forearm: .70, confidence: .70);
          }
        case 'swap':
          r.feed(85, swapped: true);
        case 'persistentJump':
          for (var i = 0; i < 7; i++) {
            r.feed(90, upper: 1.4);
          }
        case 'missingBottom':
          r.feed(90, upper: 1.4);
          r.feed(90, upper: 1.4);
          r.feed(130);
        case 'missingExtension':
          r.hold(90, 7);
          r.hold(130, 8);
          r.a.finish();
        case 'longGap':
          r.feed(90, upper: 1.4);
          r.feed(90, delta: 251000);
      }
      if (fault != 'missingExtension') {
        for (final v in [130.0, 150.0, 170.0]) {
          r.hold(v, 6);
        }
      }
      expect(r.a.snapshot.repetitions, 0);
    });
  }
  test('rejected depth cannot supply bottom dwell even over several frames',
      () {
    final r = ProjectionReplay()..start(bottom: false);
    r.feed(90, upper: 1.4);
    r.feed(90, upper: 1.4);
    r.feed(130);
    for (final angle in [150.0, 170.0]) {
      r.hold(angle, 6);
    }
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test('world XY joint-motion disagreement cannot revalidate projected depth',
      () {
    final r = ProjectionReplay()..start(bottom: false);
    r.feed(85, forearm: .82); // Not enough observed bottom dwell yet.
    for (var i = 0; i < 6; i++) {
      r.t += 60000;
      final f = projectionFrame(r.t, 85, forearm: .70);
      final rotated = f.worldLandmarks.map((k, p) => MapEntry(
          k,
          PosePoint(
              x: -p.y,
              y: p.x,
              z: p.z,
              visibility: p.visibility,
              presence: p.presence)));
      final changed = PoseFrame(
          capturedAtMicros: r.t,
          detectorId: f.detectorId,
          modelVersion: f.modelVersion,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          posePresence: f.posePresence,
          landmarks: f.landmarks,
          worldLandmarks: rotated);
      r.a.update(changed, nowMicros: r.t);
    }
    for (final angle in [130.0, 150.0, 170.0]) {
      r.hold(angle, 6);
    }
    expect(r.a.snapshot.repetitions, 0);
  });
  test('fresh stable held projections remain observed, not an extended dropout',
      () {
    final r = ProjectionReplay()..start();
    r.feed(85, forearm: .82);
    r.feed(85, forearm: .70);
    r.hold(85, 30, forearm: .70);
    expect(r.a.snapshot.phase, FloorPushUpPhase.bottom);
    expect(r.a.snapshot.geometry, isNotNull);
    r.feed(85, forearm: .82);
    r.feed(85, forearm: 1);
    r.finishCycle();
    expect(r.a.snapshot.repetitions, 1);
    expect(r.a.snapshot.formScorePercent, isNull);
  });
  test('several repeated projection-supported cycles count without duplicates',
      () {
    final r = ProjectionReplay();
    for (var i = 0; i < 3; i++) {
      r.start();
      r.feed(85, forearm: .82);
      r.feed(85, forearm: .70);
      r.feed(85, forearm: .82);
      r.feed(85);
      r.finishCycle();
      expect(r.a.snapshot.repetitions, i + 1);
    }
    expect(r.a.snapshot.formScorePercent, isNull);
  });
}
