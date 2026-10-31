import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/reverse_lunge_trajectory.dart';

// Synthetic observed projections only; these are not native recording replay.
PoseFrame standing(int t, LungeSide side, bool facing, double gap) =>
    reverseLungeFrame(t, 0, 0,
        side: side,
        facingLeft: facing,
        neutralGapRatio: gap,
        translateX: .15,
        width: 800,
        height: 800);

Iterable<PoseFrame> cycle(LungeSide side, bool facing, double gap,
        {double depth = 1,
        bool forward = false,
        bool wrongLeg = false,
        bool squat = false}) =>
    reverseLungeTrajectory(
        side: side,
        facingLeft: facing,
        neutralGapRatio: gap,
        translateX: .15,
        width: 800,
        height: 800,
        amplitude: depth,
        forward: forward,
        wrongLeg: wrongLeg,
        squat: squat);

PoseFrame changeRear(PoseFrame f, LungeSide side,
    {double x = 0, double y = 0, double confidence = .99}) {
  final id =
      side == LungeSide.left ? PoseLandmark.rightAnkle : PoseLandmark.leftAnkle;
  final p = f.landmarks[id]!;
  return PoseFrame(
      capturedAtMicros: f.capturedAtMicros,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: f.imageWidth,
      imageHeight: f.imageHeight,
      landmarks: Map.of(f.landmarks)
        ..[id] = PosePoint(
            x: p.x + x,
            y: p.y + y,
            z: p.z,
            visibility: confidence,
            presence: confidence));
}

void feed(ReverseLungeAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

void main() {
  for (final side in LungeSide.values) {
    for (final facing in [false, true]) {
      for (final gap in [.20, .24, .28]) {
        test('visible neutral gap $gap calibrates $side facing=$facing', () {
          final a = ReverseLungeAnalyzer(side: side);
          final f = standing(0, side, facing, gap);
          expect(ReverseLungeGeometry.canSetup(f, side), isTrue);
          expect(ReverseLungeGeometry.setupCue(f, side), isNull);
          feed(a, [
            for (var t = 0; t <= 800000; t += 50000)
              standing(t, side, facing, gap)
          ]);
          expect(a.snapshot.needsCalibration, isFalse);
          expect(a.snapshot.repetitions, 0);
          expect(a.snapshot.partialRepetitions, 0);
        });
        test('visible gap $gap counts observed return $side facing=$facing',
            () {
          final a = ReverseLungeAnalyzer(side: side);
          feed(a, cycle(side, facing, gap));
          expect(a.snapshot.needsCalibration, isFalse);
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
          expect(a.snapshot.formScorePercent, isNull);
        });
      }
      for (final gap in [.31, .35, .45]) {
        test('large neutral split $gap blocks Ready $side facing=$facing', () {
          final a = ReverseLungeAnalyzer(side: side);
          feed(a, [
            for (var t = 0; t <= 1100000; t += 50000)
              standing(t, side, facing, gap)
          ]);
          expect(a.snapshot.needsCalibration, isTrue);
          expect(a.snapshot.trackedDurationMicros, 0);
          expect(a.snapshot.repetitions, 0);
        });
      }
      test('unequal ankle height blocks neutral $side facing=$facing', () {
        final f = changeRear(standing(0, side, facing, .02), side, y: .044);
        expect(ReverseLungeGeometry.canSetup(f, side), isFalse);
        expect(ReverseLungeGeometry.setupCue(f, side), isNotNull);
      });
      test('visible stance still requires measured rear ankle $side $facing',
          () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(
            a,
            cycle(side, facing, .24)
                .map((f) => changeRear(f, side, confidence: .69)));
        expect(a.snapshot.needsCalibration, isTrue);
        expect(a.snapshot.trackedDurationMicros, 0);
        expect(a.snapshot.repetitions, 0);
      });
      test('visible stance preserves partial depth $side facing=$facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(a, cycle(side, facing, .24, depth: .4));
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 1);
      });
      test('visible stance needs fresh held setup $side facing=$facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(a, [
          for (var t = 0; t <= 750000; t += 50000)
            standing(t, side, facing, .24)
        ]);
        expect(a.snapshot.needsCalibration, isTrue);
        a.update(standing(800000, side, facing, .24), nowMicros: 800000);
        expect(a.snapshot.needsCalibration, isFalse);
        a.tick(nowMicros: 1100000);
        expect(a.snapshot.needsCalibration, isTrue);
      });
      test('visible stance requires held baseline return $side $facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(
            a,
            cycle(side, facing, .28)
                .where((f) => f.capturedAtMicros <= 3900000));
        expect(a.snapshot.repetitions, 0);
        feed(a, [
          standing(3950000, side, facing, .28),
          standing(4000000, side, facing, .28)
        ]);
        expect(a.snapshot.repetitions, 0);
        a.update(standing(4050000, side, facing, .28), nowMicros: 4050000);
        expect(a.snapshot.repetitions, 1);
      });
      test('descent before backstep cannot count $side facing=$facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(a, [
          for (var t = 0; t <= 1000000; t += 50000)
            standing(t, side, facing, .24)
        ]);
        feed(a, [
          for (var t = 1050000; t <= 3000000; t += 50000)
            reverseLungeFrame(t, t < 1800000 ? 0 : 1, 1,
                side: side,
                facingLeft: facing,
                neutralGapRatio: .24,
                translateX: .15,
                width: 800,
                height: 800)
        ]);
        feed(a, [
          for (var t = 3050000; t <= 4000000; t += 50000)
            standing(t, side, facing, .24)
        ]);
        expect(a.snapshot.needsCalibration, isFalse);
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
      });
      for (final kind in ['forward', 'wrong leg', 'squat', 'walking', 'jump']) {
        test('visible stance cannot admit $kind $side facing=$facing', () {
          final a = ReverseLungeAnalyzer(side: side);
          final frames = cycle(side, facing, .24,
              forward: kind == 'forward',
              wrongLeg: kind == 'wrong leg',
              squat: kind == 'squat');
          feed(a, frames.map((f) {
            if (f.capturedAtMicros < 1150000 ||
                (kind != 'walking' && kind != 'jump')) {
              return f;
            }
            return PoseFrame(
                capturedAtMicros: f.capturedAtMicros,
                detectorId: f.detectorId,
                modelVersion: f.modelVersion,
                imageWidth: f.imageWidth,
                imageHeight: f.imageHeight,
                landmarks: {
                  for (final e in f.landmarks.entries)
                    e.key: PosePoint(
                        x: e.value.x + (kind == 'walking' ? .12 : 0),
                        y: e.value.y - (kind == 'jump' ? .03 : 0),
                        z: 0,
                        visibility: .99,
                        presence: .99)
                });
          }));
          expect(a.snapshot.repetitions, 0);
          expect(a.snapshot.partialRepetitions, 0);
        });
      }
      test('return must reach calibrated gap $side facing=$facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(
            a,
            cycle(side, facing, .28).map((f) => f.capturedAtMicros < 3900000
                ? f
                : standing(f.capturedAtMicros, side, facing, .05)));
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
      });
      test('absolute split cannot replace relative backstep $side $facing', () {
        final a = ReverseLungeAnalyzer(side: side);
        final direction = facing ? -1.0 : 1.0;
        // Full apparent separation is mostly the authored neutral gap. Only
        // .10 leg of new backward travel occurs, below the .28 step gate.
        feed(
            a,
            cycle(side, facing, .28).map((f) {
              if (f.capturedAtMicros <= 1100000 ||
                  f.capturedAtMicros >= 3900000) {
                return f;
              }
              final initial = standing(f.capturedAtMicros, side, facing, .28);
              final rearId = side == LungeSide.left
                  ? PoseLandmark.rightAnkle
                  : PoseLandmark.leftAnkle;
              final x = (initial.landmarks[rearId]!.x - .044 * direction) -
                  f.landmarks[rearId]!.x;
              return changeRear(f, side, x: x);
            }));
        expect(a.snapshot.needsCalibration, isFalse);
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
      });
    }
  }
}
