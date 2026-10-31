import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/calf_raise_trajectory.dart';
import 'support/calf_raise_foot_arc.dart';

void feed(CalfRaiseAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

void main() {
  test('large stance movement still invalidates and names the foot reset', () {
    final a = CalfRaiseAnalyzer();
    feed(a, calfTrajectory().where((f) => f.capturedAtMicros <= 1000000));
    a.update(calfPose(1050000, .12, toeJitter: .05), nowMicros: 1050000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.decision, 'forefoot_moved');
    a.update(calfPose(1100000, 0), nowMicros: 1100000);
    expect(a.snapshot.calibrationCue, contains('Foot position changed'));
  });
  test('camera scale change is rejected using stable thigh evidence', () {
    final a = CalfRaiseAnalyzer();
    feed(a, calfTrajectory().where((f) => f.capturedAtMicros <= 1000000));
    a.update(calfPose(1050000, 0, scale: .8), nowMicros: 1050000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.decision, 'leg_view_changed');
    expect(a.snapshot.repetitions, 0);
  });
  test('toe motion without ankle rise does not fabricate a rep', () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 3500000; t += 50000) {
      final v = calfLiftAt(t);
      a.update(calfPose(t, 0, toeShift: v * .2), nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('accepted coherent neutral noise cannot create movement attempts', () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 6000000; t += 50000) {
      final sign = (t ~/ 50000).isEven ? 1.0 : -1.0;
      a.update(
          calfPose(t, 0, heelJitter: -sign * .007, ankleJitter: -sign * .007),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  for (final side in CalfSide.values) {
    for (final facingLeft in [false, true]) {
      for (final step in [50000, 125000]) {
        test('$side facingLeft=$facingLeft bounded foot arc completes at $step',
            () {
          final a = CalfRaiseAnalyzer();
          feed(
              a,
              calfArcTrajectory(
                  side: side, facingLeft: facingLeft, step: step));
          expect(a.snapshot.needsCalibration, false);
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
        });
      }
    }
  }
  test('a bounded toe arc alone must not restart an otherwise visible raise',
      () {
    final a = CalfRaiseAnalyzer();
    feed(a, calfArcTrajectory(shinProjection: false));
    expect(a.snapshot.repetitions, 1);
  });
  test('projected shin change alone keeps a stable thigh and valid heel cycle',
      () {
    final a = CalfRaiseAnalyzer();
    feed(a, calfArcTrajectory(toeArc: false));
    expect(a.snapshot.repetitions, 1);
  });
  for (final step in [50000, 125000]) {
    test('accepted neutral heel jitter can return and count at $step', () {
      final a = CalfRaiseAnalyzer();
      feed(
          a,
          calfArcTrajectory(
              toeArc: false,
              shinProjection: false,
              heelNoise: .008,
              step: step));
      expect(a.snapshot.needsCalibration, false);
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test(
      'independent foot jitter while standing never makes full or partial reps',
      () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 6000000; t += 50000) {
      final sign = (t ~/ 50000).isEven ? 1.0 : -1.0;
      a.update(
          calfPose(t, 0, heelJitter: sign * .008, ankleJitter: -sign * .006),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
}
