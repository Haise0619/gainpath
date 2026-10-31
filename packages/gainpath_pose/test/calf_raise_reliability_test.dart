import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/calf_raise_trajectory.dart';

void feed(CalfRaiseAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

CalfRaiseAnalyzer ready() {
  final a = CalfRaiseAnalyzer();
  feed(a, calfTrajectory().where((f) => f.capturedAtMicros <= 1000000));
  expect(a.snapshot.needsCalibration, false);
  return a;
}

void main() {
  test('sustained weak tracking loses setup and fresh neutral hold recovers',
      () {
    final a = ready();
    for (var t = 1050000; t <= 1600000; t += 50000) {
      a.update(calfPose(t, .12, confidence: .4), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.health, TrackingStatus.lost);
    expect(a.snapshot.repetitions, 0);
    feed(a, calfTrajectory(start: 1650000));
    expect(a.snapshot.repetitions, 1);
  });
  test('watchdog and rejected duplicate never double-credit elapsed time', () {
    final a = ready();
    final initial =
        a.snapshot.trackedDurationMicros + a.snapshot.rejectedDurationMicros;
    a.tick(nowMicros: 1050000);
    a.update(calfPose(1100000, 0), nowMicros: 1100000);
    a.tick(nowMicros: 1150000);
    a.update(calfPose(1100000, 0), nowMicros: 1200000);
    expect(
        a.snapshot.trackedDurationMicros +
            a.snapshot.rejectedDurationMicros -
            initial,
        200000);
    final tracked = a.snapshot.trackedDurationMicros;
    a.tick(nowMicros: 1250000);
    expect(a.snapshot.trackedDurationMicros, tracked);
    expect(
        a.snapshot.trackedDurationMicros +
            a.snapshot.rejectedDurationMicros -
            initial,
        250000);
  });
  test('slow coherent heel and ankle rise cannot unlock a moving baseline', () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1600000; t += 50000) {
      a.update(calfPose(t, .06 * t / 800000), nowMicros: t);
      expect(a.snapshot.needsCalibration, true, reason: 'moving at $t');
    }
    expect(a.snapshot.repetitions, 0);
    // A fresh, stationary heels-down hold is still sufficient after movement.
    for (var t = 1650000; t <= 3200000; t += 50000) {
      a.update(calfPose(t, 0), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
  });
  for (final side in CalfSide.values) {
    for (final step in [16667, 50000, 125000]) {
      test('$side smaller full-body framing counts at $step', () {
        final a = CalfRaiseAnalyzer();
        feed(a, calfTrajectory(side: side, step: step, scale: .4));
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.partialRepetitions, 0);
      });
      test('$side independent foot jitter calibrates and counts at $step', () {
        final a = CalfRaiseAnalyzer();
        feed(a, calfTrajectory(side: side, step: step, jitter: true));
        expect(a.snapshot.needsCalibration, false);
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.partialRepetitions, 0);
      });
    }
  }
  test('sub-resolution feet cannot calibrate merely by waiting', () {
    final a = CalfRaiseAnalyzer();
    feed(a, calfTrajectory(scale: .12));
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.calibrationCue, contains('closer'));
  });
  test(
      'neutral heel jitter larger than one starting-frame threshold can settle',
      () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1600000; t += 50000) {
      a.update(calfPose(t, 0, heelJitter: (t ~/ 50000).isEven ? .008 : -.008),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
  });
  test('brief foot confidence loss keeps setup but discards interrupted raise',
      () {
    final a = ready();
    feed(
        a,
        calfTrajectory().where((f) =>
            f.capturedAtMicros > 1000000 && f.capturedAtMicros <= 2200000));
    a.update(calfPose(2250000, .12, confidence: .4), nowMicros: 2250000);
    expect(a.snapshot.needsCalibration, false);
    feed(a, calfTrajectory().where((f) => f.capturedAtMicros > 2250000));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
    feed(a, calfTrajectory(start: 3550000));
    expect(a.snapshot.repetitions, 1);
  });
  test('one bottom spike after peak cannot complete before sustained return',
      () {
    final a = ready();
    feed(
        a,
        calfTrajectory().where((f) =>
            f.capturedAtMicros > 1000000 && f.capturedAtMicros <= 2250000));
    a.update(calfPose(2300000, 0), nowMicros: 2300000);
    expect(a.snapshot.repetitions, 0);
    a.update(calfPose(2350000, .12), nowMicros: 2350000);
    expect(a.snapshot.repetitions, 0);
  });
  test('model change and invalid timestamp cannot bridge an unfinished raise',
      () {
    for (final kind in ['model', 'duplicate']) {
      final a = ready();
      feed(
          a,
          calfTrajectory().where((f) =>
              f.capturedAtMicros > 1000000 && f.capturedAtMicros <= 2200000));
      final f = calfPose(kind == 'duplicate' ? 2200000 : 2250000, 0);
      a.update(
          PoseFrame(
              capturedAtMicros: f.capturedAtMicros,
              detectorId: f.detectorId,
              modelVersion: kind == 'model' ? 'changed' : f.modelVersion,
              imageWidth: f.imageWidth,
              imageHeight: f.imageHeight,
              landmarks: f.landmarks),
          nowMicros: 2250000);
      expect(a.snapshot.needsCalibration, true, reason: kind);
      expect(a.snapshot.repetitions, 0);
    }
  });
  test('recovered frame cannot turn unassessable time into tracked duration',
      () {
    final a = ready();
    a.update(calfPose(1050000, 0, confidence: .4), nowMicros: 1050000);
    final tracked = a.snapshot.trackedDurationMicros;
    a.tick(nowMicros: 1100000);
    a.update(calfPose(1150000, 0), nowMicros: 1150000);
    expect(a.snapshot.trackedDurationMicros, tracked);
  });
  test('moving calibrated toes or jumping never completes a rep', () {
    final a = ready();
    a.update(calfPose(1050000, .12, toeShift: -.035), nowMicros: 1050000);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.needsCalibration, true);
  });
}
