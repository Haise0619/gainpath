import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'package:gainpath_pose/src/floor_push_up/floor_push_up_top_evidence.dart';
import 'support/floor_push_up_dwell_fixture.dart';
import 'support/floor_push_up_projection_fixture.dart';

void main() {
  test(
      'exact observed triple satisfies120ms without a smoothed duration estimate',
      () {
    final e = FloorPushUpTopEvidence();
    bool sample(int t, double raw, double smooth) => e.observe(t,
        rawAngle: raw,
        smoothedAngle: smooth,
        confidence: .97,
        topAngle: 155,
        dwellMicros: 120000,
        maximumGapMicros: 250000);
    expect(sample(34481982, 157.30, 151.98), false);
    expect(sample(34562043, 158, 156.40), false);
    expect(sample(34680746, 160.35, 159.46), true);
    expect(e.spanMicros, 198764);
  });
  for (final scenario in [
    'short',
    'below',
    'duplicate',
    'gap',
    'weak',
    'smoothedBelow'
  ]) {
    test('$scenario cannot supply observed TOP dwell', () {
      final e = FloorPushUpTopEvidence();
      bool sample(int t,
              {double raw = 158, double smooth = 158, double q = .97}) =>
          e.observe(t,
              rawAngle: raw,
              smoothedAngle: smooth,
              confidence: q,
              topAngle: 155,
              dwellMicros: 120000,
              maximumGapMicros: 250000);
      sample(1000000);
      sample(1060000);
      final result = switch (scenario) {
        'short' => sample(1118703),
        'below' => sample(1120000, raw: 154.99),
        'duplicate' => sample(1060000),
        'gap' => sample(1400000),
        'weak' => sample(1120000, q: .849),
        _ => sample(1120000, smooth: 154.99),
      };
      expect(result, false);
    });
  }
  test('actual120ms boundary with three observed samples qualifies', () {
    final e = FloorPushUpTopEvidence();
    for (final t in [1000000, 1060000]) {
      expect(
          e.observe(t,
              rawAngle: 155,
              smoothedAngle: 155,
              confidence: .85,
              topAngle: 155,
              dwellMicros: 120000,
              maximumGapMicros: 250000),
          false);
    }
    expect(
        e.observe(1120000,
            rawAngle: 155,
            smoothedAngle: 155,
            confidence: .85,
            topAngle: 155,
            dwellMicros: 120000,
            maximumGapMicros: 250000),
        true);
  });
  for (final right in [false, true]) {
    test(
        'observed raw TOP for198764us confirms despite smoothed118703us boundary side=$right',
        () {
      final r = DwellReplay(right: right)
        ..prepare()
        ..approach();
      expect(r.a.snapshot.phase, FloorPushUpPhase.ascending);
      expect(r.a.diagnostics['bottomCredit'], true);
      expect(r.a.snapshot.repetitions, 0);
      r.at(34680746, 160.35);
      expect(r.a.snapshot.repetitions, 1);
      expect(r.a.snapshot.phase, FloorPushUpPhase.top);
      expect(r.a.snapshot.formScorePercent, isNull);
      expect(r.a.diagnostics['lastTopEvidenceSpanMicros'], 198764);
      expect(r.a.diagnostics['lastTopConfirmation'], 'observed_raw_dwell');
      r.hold(170, 12);
      expect(r.a.snapshot.repetitions, 1);
    });
  }
  test('two TOP observations spanning118703us alone cannot satisfy120ms', () {
    final r = DwellReplay()
      ..prepare()
      ..approach(firstRawTop: 154.5);
    r.at(34680746, 160.35);
    r.reverse();
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test(
      'genuinely sustained smoothed extension still uses the unchanged strict path',
      () {
    final r = DwellReplay()
      ..prepare()
      ..approach(firstRawTop: 154.5);
    r.at(34680746, 160.35);
    r.at(34810000, 170);
    r.at(34940000, 170);
    expect(r.a.snapshot.repetitions, 1);
  });
  test('below-threshold extension cannot be invented from near TOP samples',
      () {
    final r = DwellReplay()..prepare();
    r.hold(145, 6);
    r.hold(154.5, 6);
    r.hold(130, 6);
    r.hold(110, 6);
    expect(r.a.snapshot.repetitions, 0);
    expect(r.a.snapshot.partialRepetitions, 1);
  });
  test('duplicate captures cannot provide the third observed TOP sample', () {
    final r = DwellReplay()
      ..prepare()
      ..approach();
    final f = projectionFrame(r.t, 158);
    for (var i = 0; i < 8; i++) {
      r.a.update(f, nowMicros: r.t + 1000 * i);
    }
    expect(r.a.snapshot.repetitions, 0);
  });
  test('a confidence rejection breaks the additional raw TOP evidence', () {
    final r = DwellReplay()
      ..prepare()
      ..approach();
    r.at(34620000, 160, confidence: .1);
    r.at(34680746, 160.35);
    r.reverse();
    expect(r.a.snapshot.repetitions, 0);
  });
  test('accepted incomplete reversal is a phase reset, not a geometry failure',
      () {
    final r = DwellReplay();
    r.a.update(bentKneeFrame(1000), nowMicros: 1000);
    expect(r.a.diagnostics['resetReason'], 'kneeSupport');
    r.prepare();
    r.hold(140, 6);
    r.feed(120);
    r.feed(110);
    r.feed(105);
    expect(r.a.snapshot.partialRepetitions, 1);
    expect(r.a.diagnostics['geometryAcceptance'], 'accepted');
    expect(r.a.diagnostics['resetReason'], 'incomplete_extension_reversal');
    expect(r.a.diagnostics['geometryRejection'], 'none');
  });
  test('preserved observed TOP enables the following measured cycle', () {
    final r = DwellReplay()
      ..prepare()
      ..approach();
    r.at(34680746, 160.35);
    r.reverse();
    r.hold(65, 10);
    r.finishCycle();
    expect(r.a.snapshot.repetitions, 2);
    expect(r.a.snapshot.partialRepetitions, 0);
    expect(r.a.snapshot.formScorePercent, isNull);
  });
  test('source-gap reset reports the interrupted phase and triggering capture',
      () {
    final r = DwellReplay()..prepare();
    expect(r.a.snapshot.phase, FloorPushUpPhase.ascending);
    r.feed(130, delta: 251000);
    expect(r.a.diagnostics['resetFromPhase'], 'ascending');
    expect(r.a.diagnostics['resetCaptureMicros'], r.t);
    expect(r.a.snapshot.repetitions, 0);
  });
  for (final right in [false, true]) {
    test(
        'knee diagnostics retain angle confidence side and candidate persistence side=$right',
        () {
      final a = FloorPushUpAnalyzer();
      a.update(bentKneeFrame(1000, right: right), nowMicros: 1000);
      a.update(bentKneeFrame(101000, right: right), nowMicros: 101000);
      expect(a.snapshot.rejection, FloorPushUpRejection.kneeSupport);
      final d = a.diagnostics, m = d['measurements'] as Map;
      expect(m['kneeAngle'], closeTo(90, 1e-6));
      expect(m['kneeVisibility'], .99);
      expect(m['kneeSupportThreshold'], 125);
      expect(d['kneeCandidateSamples'], 2);
      expect(d['kneeCandidateSpanMicros'], 100000);
      a.update(bentKneeFrame(201000, right: right, confidence: .4),
          nowMicros: 201000);
      expect((a.diagnostics['measurements'] as Map)['kneeAngle'], isNull);
      expect(a.diagnostics['kneeCandidateSamples'], 0);
      expect(a.snapshot.rejection, isNot(FloorPushUpRejection.kneeSupport));
    });
  }
}
