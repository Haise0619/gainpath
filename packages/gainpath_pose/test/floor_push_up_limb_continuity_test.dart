import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/floor_push_up_camera_fixture.dart';

// Analytic landmarks reproducing the visible event order, not recovered video
// landmarks. Triangle construction independently sets the rejected elbow angle
// and a 30% upper-arm projection change; world points remain unchanged.
PoseFrame changeElbow(PoseFrame f, double angle, {bool swap = false}) {
  final right = f.landmarks.containsKey(PoseLandmark.rightElbow);
  final sId = right ? PoseLandmark.rightShoulder : PoseLandmark.leftShoulder;
  final eId = right ? PoseLandmark.rightElbow : PoseLandmark.leftElbow;
  final wId = right ? PoseLandmark.rightWrist : PoseLandmark.leftWrist;
  final s = f.landmarks[sId]!, e = f.landmarks[eId]!, w = f.landmarks[wId]!;
  final sx = s.x * f.imageWidth, sy = s.y * f.imageHeight;
  final wx = w.x * f.imageWidth, wy = w.y * f.imageHeight;
  final d = math.sqrt(math.pow(wx - sx, 2) + math.pow(wy - sy, 2));
  final upper = 1.30 *
      math.sqrt(math.pow(e.x * f.imageWidth - sx, 2) +
          math.pow(e.y * f.imageHeight - sy, 2));
  final rad = angle * math.pi / 180;
  final fore = upper * math.cos(rad) +
      math.sqrt(d * d - upper * upper * math.pow(math.sin(rad), 2));
  final along = (upper * upper + d * d - fore * fore) / (2 * d);
  final across = math.sqrt(upper * upper - along * along);
  final changed = PosePoint(
      x: (sx + along * (wx - sx) / d + across * (wy - sy) / d) / f.imageWidth,
      y: (sy + along * (wy - sy) / d - across * (wx - sx) / d) / f.imageHeight,
      z: 0,
      visibility: .99,
      presence: .99);
  return PoseFrame(
      capturedAtMicros: f.capturedAtMicros,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: f.imageWidth,
      imageHeight: f.imageHeight,
      posePresence: f.posePresence,
      landmarks: {...f.landmarks, eId: swap ? w : changed, if (swap) wId: e},
      worldLandmarks: f.worldLandmarks);
}

class LimbReplay {
  LimbReplay({this.right = false});
  final bool right;
  final a = FloorPushUpAnalyzer();
  int t = 0;
  FloorPushUpUpdate feed(double angle,
      {int delta = 60000,
      double? glitch,
      bool swap = false,
      bool occluded = false,
      String? model}) {
    t += delta;
    var f = floorCameraFrame(t, angle, right: right, width: 640, height: 480);
    if (glitch != null || swap) f = changeElbow(f, glitch ?? 55, swap: swap);
    if (occluded || model != null) {
      final e = right ? PoseLandmark.rightElbow : PoseLandmark.leftElbow;
      f = PoseFrame(
          capturedAtMicros: t,
          detectorId: f.detectorId,
          modelVersion: model ?? f.modelVersion,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          posePresence: f.posePresence,
          landmarks: f.landmarks.map((k, p) => MapEntry(
              k,
              k != e || !occluded
                  ? p
                  : PosePoint(
                      x: p.x, y: p.y, z: p.z, visibility: .1, presence: .1))),
          worldLandmarks: f.worldLandmarks);
    }
    return a.update(f, nowMicros: t);
  }

  void hold(double angle, [int n = 6]) {
    for (var i = 0; i < n; i++) {
      feed(angle);
    }
  }

  void bottom(double angle) {
    hold(170, 14);
    for (final v in [150.0, 130.0, 110.0, 90.0, angle]) {
      hold(v);
    }
    expect(a.snapshot.phase, FloorPushUpPhase.bottom);
    expect(a.diagnostics['bottomCredit'], true);
  }

  void returnTop() {
    for (final v in [90.0, 110.0, 130.0, 150.0, 170.0]) {
      hold(v);
    }
  }
}

void main() {
  for (final right in [false, true]) {
    for (final sequence in [
      (
        name: 'A',
        bottom: 68.24,
        rejected: 54.79,
        recovery: 61.75,
        before: 170335,
        after: 41126
      ),
      // Inspection found an earlier recovery (63.94) before the suggested69.88
      // sample; capture timestamps bound the actual missing interval to183ms.
      (
        name: 'B',
        bottom: 82.68,
        rejected: 78.95,
        recovery: 63.94,
        before: 116848,
        after: 66151
      ),
    ]) {
      test(
          'observed bottom survives isolated projection sequence ${sequence.name} side=$right',
          () {
        final r = LimbReplay(right: right)..bottom(sequence.bottom);
        final u = r.feed(sequence.bottom,
            glitch: sequence.rejected, delta: sequence.before);
        expect(u.rejection, FloorPushUpRejection.limbChange);
        expect(u.geometry, isNull);
        expect(u.phase, FloorPushUpPhase.bottom);
        expect(r.a.diagnostics['bottomCredit'], true);
        expect(u.repetitions, 0);
        r.feed(sequence.recovery, delta: sequence.after);
        expect(r.a.snapshot.phase, FloorPushUpPhase.bottom);
        r.hold(sequence.recovery);
        r.returnTop();
        expect(r.a.snapshot.repetitions, 1);
        expect(r.a.snapshot.partialRepetitions, 0);
        expect(r.a.snapshot.formScorePercent, isNull);
        expect(r.a.snapshot.issueCounts[FloorPushUpIssue.unstableTracking], 1);
        r.hold(170, 20);
        expect(r.a.snapshot.repetitions, 1);
      });
    }
  }

  test('diagnostics identify both changed projections against the TOP baseline',
      () {
    final r = LimbReplay()..bottom(82.68);
    r.feed(82.68, glitch: 78.95);
    final m = r.a.diagnostics['measurements'] as Map;
    expect(m['upperArmRelativeChange'], closeTo(.30, 1e-9));
    expect(m['limbChangeSegments'], contains('shoulder-elbow'));
    expect(m['limbChangeSegments'], contains('elbow-wrist'));
    expect(m['limbChangeThreshold'], .25);
    expect(m['primaryConfidence'], .99);
    expect(m['limbBaselinePhase'], 'top');
  });

  for (final fault in [
    'sustained',
    'mixedOcclusion',
    'longGap',
    'motion',
    'swap',
    'model',
    'pause',
    'finish',
    'watchdog'
  ]) {
    test('$fault cannot bridge an isolated limb rejection', () {
      final r = LimbReplay()..bottom(68.24);
      r.feed(68.24, glitch: 54.79);
      switch (fault) {
        case 'sustained':
          for (var i = 0; i < 5; i++) {
            r.feed(68.24, glitch: 54.79);
          }
        case 'mixedOcclusion':
          r.feed(68.24, occluded: true);
        case 'longGap':
          r.feed(68.24, delta: 251000);
        case 'motion':
          r.feed(130);
        case 'swap':
          r.feed(68.24, swap: true);
        case 'model':
          r.feed(68.24, model: 'changed');
        case 'pause':
          r.a.pause();
        case 'finish':
          r.a.finish();
        case 'watchdog':
          r.a.tick(nowMicros: r.t + 251000);
      }
      expect(r.a.snapshot.phase, FloorPushUpPhase.ready);
      expect(r.a.diagnostics['bottomCredit'], false);
      expect(r.a.snapshot.repetitions, 0);
      expect(r.a.snapshot.partialRepetitions, 1);
      if (fault != 'watchdog') {
        r.returnTop();
      }
      expect(r.a.snapshot.repetitions, 0);
    });
  }
  test('unobserved bottom cannot gain credit from a rejected deep frame', () {
    final r = LimbReplay()..hold(170, 14);
    r.hold(130);
    r.hold(110);
    r.feed(90, glitch: 55);
    expect(r.a.diagnostics['bottomCredit'], false);
    // Return without any accepted deep hold. returnTop() intentionally includes
    // several accepted90-degree frames, which would now provide real depth.
    for (final angle in [130.0, 150.0, 170.0]) {
      r.hold(angle);
    }
    expect(r.a.snapshot.repetitions, 0);
  });
  test('retained bottom still requires a freshly observed full extension', () {
    final r = LimbReplay()..bottom(68.24);
    r.feed(68.24, glitch: 54.79);
    r.feed(61.75);
    r.hold(61.75);
    r.hold(110);
    r.hold(145, 12);
    expect(r.a.snapshot.repetitions, 0);
    r.a.finish();
    expect(r.a.snapshot.partialRepetitions, 1);
    expect(r.a.snapshot.formScorePercent, isNull);
  });
  test('bottom-band recovery with excessive endpoint motion interrupts', () {
    final r = LimbReplay()..bottom(82.68);
    r.feed(82.68, glitch: 78.95);
    r.feed(60); // Both endpoints are deep, but the 22.68-degree jump is unsafe.
    expect(r.a.snapshot.phase, FloorPushUpPhase.ready);
    expect(r.a.diagnostics['resetReason'], 'movement_during_limb_recovery');
    r.returnTop();
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test(
      'late delivery cannot preserve bottom even when capture endpoints are fresh',
      () {
    final r = LimbReplay()..bottom(68.24);
    r.feed(68.24, glitch: 54.79);
    r.t += 60000;
    final recovery = floorCameraFrame(r.t, 61.75, width: 640, height: 480);
    // Capture endpoints120ms apart, delivered300ms after last accepted result.
    // No timer tick is assumed: update itself must enforce the delivery bound.
    r.a.update(recovery, nowMicros: r.t + 180000);
    expect(r.a.snapshot.phase, FloorPushUpPhase.ready);
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test('a rejected extension cannot complete the previously observed bottom',
      () {
    final r = LimbReplay()..bottom(68.24);
    r.hold(110);
    r.hold(140);
    expect(r.a.snapshot.phase, FloorPushUpPhase.ascending);
    r.feed(170, glitch: 120);
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.phase, FloorPushUpPhase.ready);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test('multiple recovered cycles count once each and remain unscored', () {
    final r = LimbReplay();
    for (var i = 0; i < 3; i++) {
      r.bottom(68.24);
      r.feed(68.24, glitch: 54.79);
      r.feed(61.75);
      r.hold(61.75);
      r.returnTop();
      expect(r.a.snapshot.repetitions, i + 1);
      expect(r.a.snapshot.partialRepetitions, 0);
    }
    expect(r.a.snapshot.formScorePercent, isNull);
  });
}
