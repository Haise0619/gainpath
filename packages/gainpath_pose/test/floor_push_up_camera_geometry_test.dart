import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'dart:math' as math;
import 'support/floor_push_up_camera_fixture.dart';

void main() {
  test('stale observations cannot qualify world reliability', () {
    final a = FloorPushUpAnalyzer();
    for (var t = 50000; t <= 450000; t += 50000) {
      a.update(floorCameraFrame(t, 90, conflict: true), nowMicros: t + 300000);
      expect(a.snapshot.rejection, FloorPushUpRejection.staleFrame);
      expect(a.diagnostics['worldConflictSamples'], 0);
    }
  });
  test('gradually drifting world scale is not temporally reliable', () {
    final evidence = FloorPushUpWorldEvidence();
    for (var i = 0; i < 9; i++) {
      final t = 50000 * (i + 1),
          f = floorCameraFrame(50000 * (i + 1), 90, conflict: true);
      final scale = math.pow(1.1, i).toDouble();
      final changing = PoseFrame(
          capturedAtMicros: t,
          detectorId: f.detectorId,
          modelVersion: f.modelVersion,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          posePresence: f.posePresence,
          landmarks: f.landmarks,
          worldLandmarks: f.worldLandmarks.map((k, p) => MapEntry(
              k,
              PosePoint(
                  x: p.x * scale,
                  y: p.y * scale,
                  z: p.z * scale,
                  visibility: p.visibility,
                  presence: p.presence))));
      final g = FloorPushUpGeometry.fromFrame(changing, FloorPushUpSide.left)!;
      expect(evidence.observe(g, t, maximumGapMicros: 250000),
          isNot(FloorPushUpWorldDecision.confirmedContradiction));
    }
  });
  test('short-side ratio is also independent of camera resolution', () {
    final a = FloorPushUpGeometry.fromFrame(
        floorCameraFrame(1, 170), FloorPushUpSide.left)!;
    final b = FloorPushUpGeometry.fromFrame(
        floorCameraFrame(1, 170, width: 1920, height: 2560, scale: 1000),
        FloorPushUpSide.left)!;
    expect(a.bodyLengthShortSide, closeTo(.3770290646, 1e-9));
    expect(b.bodyLengthShortSide, closeTo(a.bodyLengthShortSide, 1e-9));
    expect(a.legacyScoreCompatible, false);
  });
  test('legacy-compatible landscape cycle retains its unchanged v1 score', () {
    final a = FloorPushUpAnalyzer();
    var t = 0;
    void hold(double angle, int n) {
      for (var i = 0; i < n; i++) {
        t += 50000;
        a.update(floorCameraFrame(t, angle, width: 640, height: 480),
            nowMicros: t);
      }
    }

    hold(170, 14);
    for (final angle in [
      150.0,
      130.0,
      110.0,
      90.0,
      90.0,
      90.0,
      110.0,
      130.0,
      150.0,
      170.0,
      170.0
    ]) {
      hold(angle, 4);
    }
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.formScorePercent, greaterThan(85));
  });
  test('low world confidence cannot qualify a strong contradiction', () {
    final e = FloorPushUpWorldEvidence();
    for (var t = 50000; t < 1000000; t += 100000) {
      final f = floorCameraFrame(t, 90, conflict: true);
      final weak = PoseFrame(
          capturedAtMicros: t,
          detectorId: f.detectorId,
          modelVersion: f.modelVersion,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          posePresence: f.posePresence,
          landmarks: f.landmarks,
          worldLandmarks: f.worldLandmarks.map((k, p) => MapEntry(
              k,
              PosePoint(
                  x: p.x, y: p.y, z: p.z, visibility: .7, presence: .7))));
      final g = FloorPushUpGeometry.fromFrame(weak, FloorPushUpSide.left)!;
      expect(e.observe(g, t, maximumGapMicros: 250000),
          FloorPushUpWorldDecision.fallback2d);
    }
  });
  test('one transient bottom world conflict does not discard observed depth',
      () {
    final a = FloorPushUpAnalyzer();
    var t = 0;
    void hold(double angle, int n, {bool conflict = false}) {
      for (var i = 0; i < n; i++) {
        t += 50000;
        a.update(floorCameraFrame(t, angle, conflict: conflict), nowMicros: t);
      }
    }

    hold(170, 14);
    hold(140, 5);
    hold(110, 5);
    hold(90, 2);
    hold(90, 1, conflict: true);
    hold(90, 5);
    hold(120, 6);
    hold(170, 8);
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.formScorePercent, isNull);
  });
  test(
      'persistent reliable disagreement still rejects the bottom and invalidates credit',
      () {
    final a = FloorPushUpAnalyzer();
    var t = 0;
    void hold(double angle, int n, {bool conflict = false}) {
      for (var i = 0; i < n; i++) {
        t += 50000;
        a.update(floorCameraFrame(t, angle, conflict: conflict), nowMicros: t);
      }
    }

    hold(170, 14);
    hold(140, 5);
    hold(90, 12, conflict: true);
    expect(a.snapshot.rejection, FloorPushUpRejection.contradictoryWorld);
    expect(a.snapshot.needsCalibration, true);
    hold(170, 8);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
  for (final right in [false, true]) {
    test('same physical body size accepted in portrait/landscape side=$right',
        () {
      final side = right ? FloorPushUpSide.right : FloorPushUpSide.left;
      final portrait = FloorPushUpGeometry.fromFrame(
          floorCameraFrame(1, 170, right: right), side);
      final landscape = FloorPushUpGeometry.fromFrame(
          floorCameraFrame(1, 170, right: right, width: 640, height: 480),
          side);
      expect(portrait, isNotNull);
      expect(landscape, isNotNull);
      expect(portrait!.elbowAngleDegrees, closeTo(170, .001));
      expect(landscape!.elbowAngleDegrees, closeTo(170, .001));
      expect(portrait.usableView(FloorPushUpRules()), true);
      expect(landscape.usableView(FloorPushUpRules()), true);
    });
    test(
        'fully observed portrait TOP BOTTOM TOP with unstable depth counts side=$right',
        () {
      final a = FloorPushUpAnalyzer();
      var t = 0;
      void hold(double angle, int n, {double depth = 0}) {
        for (var i = 0; i < n; i++) {
          t += 50000;
          a.update(floorCameraFrame(t, angle, right: right, worldDepth: depth),
              nowMicros: t);
        }
      }

      hold(170, 14);
      for (final v in [
        (150.0, 0.0),
        (130.0, .1),
        (110.0, .3),
        (90.0, .4),
        (90.0, .3),
        (90.0, .4),
        (110.0, .2),
        (130.0, .1),
        (150.0, 0.0),
        (170.0, 0.0),
        (170.0, 0.0)
      ]) {
        hold(v.$1, 4, depth: v.$2);
      }
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.partialRepetitions, 0);
      expect(a.snapshot.formScorePercent, isNull);
      hold(170, 10);
      expect(a.snapshot.repetitions, 1);
    });
  }
  test(
      'depth-only world disagreement permits unscored 2D rather than a false contradiction',
      () {
    final g = FloorPushUpGeometry.fromFrame(
        floorCameraFrame(1, 90, width: 640, height: 480, worldDepth: .4),
        FloorPushUpSide.left)!;
    expect(g.elbowAngleDegrees, closeTo(90, .001));
    expect(g.worldConsistent, false);
    expect(g.worldStatus, FloorPushUpWorldStatus.unreliable);
    expect(g.usableView(FloorPushUpRules()), true);
  });
  test('genuinely small body rejected in both orientations', () {
    for (final dimensions in [(480, 640), (640, 480)]) {
      final o = FloorPushUpGeometryObservation();
      final g = FloorPushUpGeometry.fromFrame(
          floorCameraFrame(1, 170,
              width: dimensions.$1, height: dimensions.$2, scale: 100),
          FloorPushUpSide.left,
          observation: o);
      expect(g, isNull);
      expect(o.rejection, FloorPushUpRejection.bodyTooSmall);
    }
  });
  test('shallow portrait cycle stays partial despite unreliable world depth',
      () {
    final a = FloorPushUpAnalyzer();
    var t = 0;
    void hold(double angle, int n) {
      for (var i = 0; i < n; i++) {
        t += 50000;
        a.update(floorCameraFrame(t, angle, worldDepth: .4), nowMicros: t);
      }
    }

    hold(170, 14);
    for (final angle in [150.0, 130.0, 125.0, 130.0, 150.0, 170.0, 170.0]) {
      hold(angle, 6);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
}
