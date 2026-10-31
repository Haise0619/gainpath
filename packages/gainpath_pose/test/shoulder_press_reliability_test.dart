import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/shoulder_press_trajectory.dart';
import 'support/shoulder_press_projection.dart';

void feed(ShoulderPressAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

double movement(int t) => t < 900000
    ? 0
    : t < 1700000
        ? (t - 900000) / 800000
        : t < 2100000
            ? 1
            : t < 2900000
                ? 1 - (t - 2100000) / 800000
                : 0;
ShoulderPressAnalyzer ready() {
  final a = ShoulderPressAnalyzer();
  feed(a, shoulderPressTrajectory().where((f) => f.capturedAtMicros <= 800000));
  return a;
}

void main() {
  test(
      'watchdog and recovery do not credit rejected frame intervals as tracked time',
      () {
    final a = ready();
    a.update(pressProjection(shoulderPressFrame(850000, 0), confidence: .4),
        nowMicros: 850000);
    final tracked = a.snapshot.trackedDurationMicros,
        rejected = a.snapshot.rejectedDurationMicros;
    a.tick(nowMicros: 950000);
    expect(a.snapshot.trackedDurationMicros, tracked);
    expect(a.snapshot.rejectedDurationMicros, rejected + 100000);
    a.update(shoulderPressFrame(1000000, 0), nowMicros: 1000000);
    expect(a.snapshot.trackedDurationMicros, tracked);
    expect(a.snapshot.rejectedDurationMicros, rejected + 150000);
  });
  test(
      'combined elevation narrowing and shortened projection counts one bilateral cycle',
      () {
    final a = ShoulderPressAnalyzer();
    feed(
        a,
        shoulderPressTrajectory().map((f) {
          final v = movement(f.capturedAtMicros);
          return pressProjection(f,
              elevation: .045 * v,
              spanScale: 1 - .27 * v,
              upperScale: 1 - .30 * v,
              forearmScale: 1 - .30 * v);
        }));
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test(
      'detector identity change discards an unfinished cycle just like geometry change',
      () {
    final a = ready();
    feed(
        a,
        shoulderPressTrajectory().where((f) =>
            f.capturedAtMicros > 800000 && f.capturedAtMicros <= 2000000));
    final f = shoulderPressFrame(2050000, 1);
    a.update(
        PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: 'changed',
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: f.landmarks),
        nowMicros: 2050000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test('scalar decision reason identifies rejected body movement and recovery',
      () {
    final a = ready();
    a.update(pressProjection(shoulderPressFrame(850000, 0), confidence: .4),
        nowMicros: 850000);
    expect(a.snapshot.decision, 'brief_tracking_loss');
    a.update(shoulderPressFrame(900000, 1), nowMicros: 900000);
    expect(a.snapshot.decision, 'awaiting_bottom_reset');
    expect(a.snapshot.requiresBottomReset, true);
    a.update(pressProjection(shoulderPressFrame(950000, 0), hipShift: .15),
        nowMicros: 950000);
    expect(a.snapshot.decision, 'body_displacement');
  });
  for (final step in [16667, 50000, 125000]) {
    for (final scale in [.68, 1.32]) {
      test(
          'projected arm length $scale varies during press at $step without losing calibration',
          () {
        final a = ShoulderPressAnalyzer();
        feed(
            a,
            shoulderPressTrajectory(stepMicros: step).map((f) {
              final v = movement(f.capturedAtMicros);
              return pressProjection(f,
                  upperScale: 1 + (scale - 1) * v,
                  forearmScale: 1 + (scale - 1) * v);
            }));
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.needsCalibration, false);
      });
    }
    test(
        'shoulder elevation and narrowing during bilateral reach at $step are not camera movement',
        () {
      final a = ShoulderPressAnalyzer();
      feed(
          a,
          shoulderPressTrajectory(stepMicros: step).map((f) {
            final v = movement(f.capturedAtMicros);
            return pressProjection(f,
                elevation: .045 * v,
                spanScale: 1 - .27 * v,
                jitter: (f.capturedAtMicros ~/ step).isEven ? .0008 : -.0008);
          }));
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.needsCalibration, false);
    });
  }
  test(
      'brief unclear frame keeps setup but discards peak and requires observed bottom before new rep',
      () {
    final a = ready();
    feed(
        a,
        shoulderPressTrajectory().where((f) =>
            f.capturedAtMicros > 800000 && f.capturedAtMicros <= 2000000));
    a.update(pressProjection(shoulderPressFrame(2050000, 1), confidence: .4),
        nowMicros: 2050000);
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.health, TrackingStatus.degraded);
    feed(a,
        shoulderPressTrajectory().where((f) => f.capturedAtMicros > 2050000));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
    feed(a, shoulderPressTrajectory(startMicros: 3450000));
    expect(a.snapshot.repetitions, 1);
  });
  test(
      'short repeated confidence dips at bottom do not force full recalibration',
      () {
    final a = ready();
    for (var t = 850000; t < 1600000; t += 50000) {
      a.update(
          pressProjection(shoulderPressFrame(t, 0),
              confidence: t % 200000 == 0 ? .4 : .99),
          nowMicros: t);
      expect(a.snapshot.needsCalibration, false);
    }
    feed(a, shoulderPressTrajectory(startMicros: 1650000));
    expect(a.snapshot.repetitions, 1);
  });
  test('prolonged unreliable frames force calibration, no hidden return counts',
      () {
    final a = ready();
    for (var t = 850000; t <= 1500000; t += 50000) {
      a.update(pressProjection(shoulderPressFrame(t, 1), confidence: .4),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test('large hip/camera translation does force a fresh setup', () {
    final a = ready();
    a.update(pressProjection(shoulderPressFrame(850000, .5), hipShift: .15),
        nowMicros: 850000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test('projected length variance does not turn a lateral raise into a press',
      () {
    final a = ready();
    for (var t = 850000; t <= 3300000; t += 50000) {
      final v = movement(t);
      a.update(
          pressProjection(shoulderPressFrame(t, v, lateralRaise: true),
              upperScale: 1 + .3 * v),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('overhead sample after short loss cannot reuse previous peak dwell', () {
    final a = ready();
    feed(
        a,
        shoulderPressTrajectory().where((f) =>
            f.capturedAtMicros > 800000 && f.capturedAtMicros < 1750000));
    a.update(pressProjection(shoulderPressFrame(1750000, 1), confidence: .4),
        nowMicros: 1750000);
    for (var t = 1800000; t <= 2500000; t += 50000) {
      a.update(shoulderPressFrame(t, t < 2100000 ? 1 : 0), nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
}
