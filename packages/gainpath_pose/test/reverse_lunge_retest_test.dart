import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/reverse_lunge_trajectory.dart';

PoseFrame withPoints(PoseFrame f, Map<PoseLandmark, PosePoint> points) =>
    PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        posePresence: f.posePresence,
        landmarks: points);

PoseFrame alter(PoseFrame f, PoseLandmark id, String mode) {
  final points = Map.of(f.landmarks);
  final p = points[id]!;
  if (mode == 'missing') {
    points.remove(id);
  } else {
    points[id] = PosePoint(
        x: mode == 'invalid' ? double.nan : p.x,
        y: p.y,
        z: p.z,
        visibility: mode == 'weak' ? .69 : p.visibility,
        presence: mode == 'presence' ? .69 : p.presence);
  }
  return withPoints(f, points);
}

void main() {
  for (final side in LungeSide.values) {
    final rearKnee =
        side == LungeSide.left ? PoseLandmark.rightKnee : PoseLandmark.leftKnee;
    final frontKnee =
        side == LungeSide.left ? PoseLandmark.leftKnee : PoseLandmark.rightKnee;
    final rearHip =
        side == LungeSide.left ? PoseLandmark.rightHip : PoseLandmark.leftHip;
    final rearAnkle = side == LungeSide.left
        ? PoseLandmark.rightAnkle
        : PoseLandmark.leftAnkle;
    test('unlevel rear hip cannot replace standing setup $side', () {
      final f = reverseLungeFrame(0, 0, 0, side: side);
      final p = f.landmarks[rearHip]!;
      final changed = withPoints(
          f,
          Map.of(f.landmarks)
            ..[rearHip] = PosePoint(
                x: p.x, y: p.y + .05, z: p.z, visibility: .99, presence: .99));
      expect(ReverseLungeGeometry.canSetup(changed, side), isFalse);
      expect(
          ReverseLungeGeometry.setupCue(changed, side), contains('hips level'));
      final a = ReverseLungeAnalyzer(side: side)..update(changed, nowMicros: 0);
      expect(a.snapshot.rejectionReason, 'neutral_hips_unlevel');
    });
    for (final id in [frontKnee, rearHip, rearAnkle]) {
      test('weak measured $id interrupts full-depth cycle $side', () {
        final a = ReverseLungeAnalyzer(side: side);
        for (final f in reverseLungeTrajectory(side: side)) {
          a.update(f.capturedAtMicros == 2500000 ? alter(f, id, 'weak') : f,
              nowMicros: f.capturedAtMicros);
        }
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
      });
    }
    for (final kind in ['forward', 'wrong leg', 'squat', 'static split']) {
      test('hidden rear knee does not admit $kind $side', () {
        final a = ReverseLungeAnalyzer(side: side);
        final frames = kind == 'static split'
            ? [
                for (var t = 0; t <= 4300000; t += 50000)
                  reverseLungeFrame(t, 1, .7, side: side)
              ]
            : reverseLungeTrajectory(
                side: side,
                forward: kind == 'forward',
                wrongLeg: kind == 'wrong leg',
                squat: kind == 'squat');
        for (final f in frames) {
          a.update(alter(f, rearKnee, 'missing'),
              nowMicros: f.capturedAtMicros);
        }
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
      });
    }
    for (final facing in [false, true]) {
      for (final mode in ['missing', 'weak', 'presence', 'invalid']) {
        test('unmeasured rear knee $mode allows observed cycle $side $facing',
            () {
          final a = ReverseLungeAnalyzer(side: side);
          for (final f
              in reverseLungeTrajectory(side: side, facingLeft: facing)) {
            a.update(alter(f, rearKnee, mode), nowMicros: f.capturedAtMicros);
          }
          expect(a.snapshot.needsCalibration, isFalse);
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
          expect(a.snapshot.diagnostics, isNot(contains('rearKneeDegrees')));
        });
        test('selected knee $mode still blocks setup and count $side $facing',
            () {
          final a = ReverseLungeAnalyzer(side: side);
          for (final f
              in reverseLungeTrajectory(side: side, facingLeft: facing)) {
            a.update(alter(f, frontKnee, mode), nowMicros: f.capturedAtMicros);
          }
          expect(a.snapshot.needsCalibration, isTrue);
          expect(a.snapshot.repetitions, 0);
          expect(a.snapshot.trackedDurationMicros, 0);
          expect(a.snapshot.rejectionReason, contains(frontKnee.name));
        });
      }
    }
  }
}
