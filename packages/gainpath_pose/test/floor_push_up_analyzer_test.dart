import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/floor_push_up_trajectory.dart';

void main() {
  for (final right in [false, true]) {
    for (final facingLeft in [false, true]) {
      test('side=$right facingLeft=$facingLeft completes only full cycles', () {
        final r = FloorReplay(right: right, facingLeft: facingLeft)
          ..hold(170, 700);
        r.cycle();
        expect(r.analyzer.snapshot.repetitions, 1);
        expect(r.analyzer.snapshot.partialRepetitions, 0);
        expect(r.phases, containsAll(FloorPushUpPhase.values));
        expect(r.analyzer.snapshot.formScorePercent, greaterThan(85));
        r.hold(170, 1500);
        expect(r.analyzer.snapshot.repetitions, 1);
        r.cycle();
        expect(r.analyzer.snapshot.repetitions, 2);
      });
    }
  }
  test('shallow return is one partial and issues descent feedback', () {
    final r = FloorReplay()..hold(170, 700);
    r.cycle(bottom: 125);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    expect(r.issues, contains(FloorPushUpIssue.insufficientDescent));
    expect(r.cues, contains('Lower your chest a little more.'));
  });
  test('incomplete extension cannot lend bottom credit to the next dip', () {
    final r = FloorReplay()..hold(170, 700);
    r.cycle(top: 145);
    r.hold(125, 400);
    r.hold(90, 400);
    r.hold(170, 600);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    expect(r.issues, contains(FloorPushUpIssue.incompleteExtension));
    r.cycle();
    expect(r.analyzer.snapshot.repetitions, 1);
  });
  test('a short ascent reversed below 130 cannot retain bottom credit', () {
    final r = FloorReplay()..hold(170, 700)..hold(130, 400)..hold(90, 500);
    r.hold(120, 500); r.hold(90, 500); r.hold(170, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    expect(r.analyzer.snapshot.issueCounts[FloorPushUpIssue.incompleteExtension], 1);
  });
  for (final (offset, issue, cue) in [
    (.08, FloorPushUpIssue.hipSagging, 'Keep your hips aligned.'),
    (-.08, FloorPushUpIssue.hipPiking, 'Lower your hips slightly.'),
  ]) {
    test('$issue changes quality independently of counting', () {
      final r = FloorReplay()..hold(170, 700);
      r.cycle(hipOffset: offset);
      expect(r.analyzer.snapshot.repetitions, 1);
      expect(r.issues, contains(issue));
      expect(r.cues, contains(cue));
      expect(r.analyzer.snapshot.components!.bodyAlignment, lessThan(80));
    });
  }
  test('slow repetition and prolonged bottom hold remain valid', () {
    final r = FloorReplay()..hold(170, 700);
    r.cycle(stepMillis: 800, bottomMillis: 5000);
    expect(r.analyzer.snapshot.repetitions, 1);
    expect(r.analyzer.snapshot.partialRepetitions, 0);
  });
  test('fast transient flexion and threshold jitter cannot complete a rep', () {
    final r = FloorReplay()..hold(170, 700);
    r.hold(90, 50);
    r.hold(170, 500);
    for (var i = 0; i < 12; i++) {
      r.hold(i.isEven ? 153 : 157, 50);
    }
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 0);
  });
  test('occluded elbow aborts once, no score and no completion across gap', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400)
      ..hold(90, 400);
    r.hold(90, 400, visibility: .1);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
    expect(r.analyzer.snapshot.health, isNot(TrackingStatus.healthy));
    expect(r.cues, contains('Adjust your camera position.'));
    r.hold(170, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    r.cycle();
    expect(r.analyzer.snapshot.repetitions, 1);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
  });
  test('camera loss tick and resume at bottom require a new TOP', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400)
      ..hold(90, 400);
    r.t += 1000000;
    final lost = r.analyzer.tick(nowMicros: r.t);
    expect(lost.health, TrackingStatus.lost);
    r.hold(90, 500);
    r.hold(170, 600);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    r.cycle();
    expect(r.analyzer.snapshot.repetitions, 1);
    expect(
        r.analyzer.snapshot.trackedDurationMicros +
            r.analyzer.snapshot.rejectedDurationMicros,
        lessThanOrEqualTo(r.t));
  });
  test('wrong camera view cannot arm or produce a form score', () {
    final r = FloorReplay()..hold(170, 800, wrongView: true);
    r.hold(90, 800, wrongView: true);
    r.hold(170, 800, wrongView: true);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
    expect(r.analyzer.snapshot.needsCalibration, true);
  });
  test('starting at bottom and pause midway never counts an orphan return', () {
    final r = FloorReplay()
      ..hold(90, 800)
      ..hold(170, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    r.hold(130, 400);
    r.analyzer.pause();
    r.hold(90, 500);
    r.hold(170, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
  });
  test('2D and consistent world angles agree; poor world data cannot rescue 2D',
      () {
    final f = floorFrame(1, 90, world: true);
    final g = FloorPushUpGeometry.fromFrame(f, FloorPushUpSide.left)!;
    expect(g.elbowAngleDegrees, closeTo(90, .001));
    expect(g.worldElbowAngleDegrees, closeTo(90, .001));
    expect(g.worldConsistent, true);
    final bad = FloorPushUpGeometry.fromFrame(
        floorFrame(2, 90, world: true, worldElbowOffset: .5),
        FloorPushUpSide.left)!;
    expect(bad.worldConsistent, false);
    final r = FloorReplay()..hold(170, 700);
    r.hold(90, 500, world: true, worldElbowOffset: .5);
    expect(r.analyzer.snapshot.health, isNot(TrackingStatus.healthy));
  });
  test('geometry is aspect-correct, normalized and knee is supplementary', () {
    final a = FloorPushUpGeometry.fromFrame(
        floorFrame(1, 100, hipOffset: .06, omitKnee: true),
        FloorPushUpSide.left)!;
    final b = FloorPushUpGeometry.fromFrame(
        floorFrame(1, 100, hipOffset: .06, width: 1600, height: 900),
        FloorPushUpSide.left)!;
    expect(a.elbowAngleDegrees, closeTo(b.elbowAngleDegrees, .001));
    expect(a.signedHipDisplacement, closeTo(b.signedHipDisplacement, .001));
    expect(a.signedHipDisplacement, greaterThan(0));
    expect(a.kneeAngleDegrees, isNull);
  });
  test('out-of-order, stale frames and duplicate captures cannot advance', () {
    final r = FloorReplay()..hold(170, 700);
    final before = r.analyzer.snapshot;
    r.analyzer.update(floorFrame(r.t, 90), nowMicros: r.t);
    r.analyzer.update(floorFrame(r.t - 1, 90), nowMicros: r.t);
    expect(r.analyzer.snapshot.phase, before.phase);
    r.t += 1000000;
    r.analyzer.update(floorFrame(r.t - 500000, 90), nowMicros: r.t);
    expect(r.analyzer.snapshot.needsCalibration, true);
    expect(r.analyzer.snapshot.repetitions, 0);
  });
  test('a small departure from a barely extended top is not a partial rep', () {
    final r = FloorReplay()
      ..hold(156, 700)
      ..hold(140, 500)
      ..hold(156, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 0);
  });
  test('interruption of a small departure cannot manufacture an attempt', () {
    for (final interruption in ['pause', 'finish', 'occlusion']) {
      final r = FloorReplay()..hold(156, 700)..hold(140, 500);
      if (interruption == 'pause') r.analyzer.pause();
      if (interruption == 'finish') r.analyzer.finish();
      if (interruption == 'occlusion') r.hold(140, 300, visibility: .1);
      expect(r.analyzer.snapshot.partialRepetitions, 0, reason: interruption);
    }
  });
  test(
      'ending an unfinished ascent retains incomplete extension and missing score',
      () {
    final r = FloorReplay()..hold(170, 700);
    r.cycle(top: 145);
    r.analyzer.finish();
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    expect(
        r.analyzer.snapshot.issueCounts[FloorPushUpIssue.incompleteExtension],
        1);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
    r.analyzer.finish();
    expect(r.analyzer.snapshot.partialRepetitions, 1);
  });
  test(
      'changed thresholds need a separate version and actually alter depth eligibility',
      () {
    expect(() => FloorPushUpRules(bottomAngle: 125), throwsArgumentError);
    expect(() => FloorPushUpRules(romWeight: .5), throwsArgumentError);
    final r = FloorReplay(
        rules: FloorPushUpRules(version: 'test-depth-v2', bottomAngle: 125))
      ..hold(170, 700);
    r.cycle(bottom: 120);
    expect(r.analyzer.snapshot.repetitions, 1);
  });
  test('dimension and model changes interrupt attempts once', () {
    for (final modelChange in [false, true]) {
      final r = FloorReplay()
        ..hold(170, 700)
        ..hold(130, 400)
        ..hold(90, 400);
      r.t += 50000;
      r.analyzer.update(
          floorFrame(r.t, 90,
              width: modelChange ? 1000 : 1600,
              detector: modelChange ? 'other-model' : 'fixture'),
          nowMicros: r.t);
      expect(r.analyzer.snapshot.repetitions, 0);
      expect(r.analyzer.snapshot.partialRepetitions, 1);
      expect(r.analyzer.snapshot.needsCalibration, true);
    }
  });
  test('voice arbiter prioritizes tracking warnings and enforces cooldown', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400);
    r.hold(90, 400, visibility: .1);
    final arbiter = AudioCueArbiter();
    arbiter.submit(const CueRequest(
        id: 'floor_good',
        text: 'Good repetition.',
        priority: CuePriority.encouragement));
    for (final cue in r.analyzer.snapshot.cues) {
      arbiter.submit(cue);
    }
    expect(arbiter.takeNext(nowMicros: 0)!.priority, CuePriority.warning);
    for (final cue in r.analyzer.snapshot.cues) {
      arbiter.submit(cue);
    }
    expect(arbiter.takeNext(nowMicros: 1999999), isNull);
    expect(arbiter.takeNext(nowMicros: 2000000)!.text,
        'Adjust your camera position.');
  });
}
