import 'dart:convert';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'squat_analyzer_test.dart' as fixture;

class DiagnosticRig {
  DiagnosticRig(this.recorder, {this.withWorld = false})
      : analyzer = SquatAnalyzer(diagnostics: recorder);
  final bool withWorld;
  final SquatDiagnosticRecorder recorder;
  final SquatAnalyzer analyzer;
  final baseline = SquatAnalyzer();
  int time = 0;
  SquatUpdate? last;
  void step(double angle,
      {double lean = 0, bool missing = false, int delta = 100000}) {
    time += delta;
    final image = fixture.sample(time, angle, lean: lean, missingKnee: missing);
    final frame = !withWorld
        ? image
        : PoseFrame(
            capturedAtMicros: image.capturedAtMicros,
            detectorId: image.detectorId,
            modelVersion: image.modelVersion,
            imageWidth: image.imageWidth,
            imageHeight: image.imageHeight,
            posePresence: image.posePresence,
            landmarks: image.landmarks,
            worldLandmarks: {
                for (final e in image.landmarks.entries)
                  e.key: PosePoint(
                      x: (e.value.x - .5) * .640,
                      y: (e.value.y - .5) * .720,
                      z: .12 * ((time ~/ 100000 + e.key.index) % 3 - 1),
                      visibility: e.value.visibility,
                      presence: e.value.presence)
              });
    final expected = baseline.update(frame, nowMicros: time);
    last = analyzer.update(frame, nowMicros: time);
    expect(facts(last!), facts(expected));
  }

  void hold(double angle, int count, {double lean = 0}) {
    for (var i = 0; i < count; i++) {
      step(angle, lean: lean);
    }
  }

  void ramp(double from, double to, {double lean = 0}) {
    for (var i = 1; i <= 20; i++) {
      step(from + (to - from) * i / 20, lean: lean);
    }
  }

  void cycle({double bottom = 75, double lean = 0}) {
    ramp(175, bottom, lean: lean);
    hold(bottom, 8, lean: lean);
    ramp(bottom, 175, lean: lean);
    hold(175, 12);
  }
}

Object facts(SquatUpdate u) => [
      u.health.name,
      u.needsCalibration,
      u.phase.name,
      u.selectedSide?.name,
      u.geometry?.kneeAngleDegrees,
      u.geometry?.trunkLeanDegrees,
      u.angularVelocityDegreesPerSecond,
      u.repetitions,
      u.partialRepetitions,
      u.trackedDurationMicros,
      u.rejectedDurationMicros,
      u.formScorePercent,
      u.trackingConfidence,
      [
        for (final c in u.cues) [c.id, c.text, c.priority.name]
      ],
      if (u.completedAttempt case final a?)
        [
          a.number,
          a.complete,
          a.minimumKneeAngleDegrees,
          a.durationMicros,
          a.scorePercent,
          [
            for (final d in a.deviations) [d.kind.name, d.degrees]
          ]
        ]
    ];

void main() {
  test('first descent observation does not overstate the decision dwell timer',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder())..hold(175, 12);
    for (final angle in [45.0, 45.0, 175.0, 175.0]) {
      r.step(angle, delta: 200000);
    }
    r.hold(175, 12);
    expect(r.last!.partialRepetitions, 1);
    final event = r.recorder.records.single.toJson();
    expect(event['reason'], 'depth_dwell_not_confirmed');
    expect(event['longestContinuousDepthMicros'], 200000);
    expect(event['maximumDecisionDepthDwellMicros'], 0);
    expect(event['decisionDepthDwellAtConfirmationMicros'], isNull);
  });
  test('brief below-threshold excursion explains partial by unconfirmed dwell',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder())..hold(175, 12);
    r.ramp(175, 100);
    r.step(60);
    r.step(175);
    r.hold(175, 12);
    expect(r.last!.partialRepetitions, 1);
    final event = r.recorder.records.single.toJson();
    expect(event['reason'], 'depth_dwell_not_confirmed');
    expect(event['minimumFiltered2dDegrees'], lessThanOrEqualTo(90));
    expect(event['longestContinuousDepthMicros'], lessThan(150000));
  });
  test('recorder refuses a different side or capture time in a comparison', () {
    for (final wrongSide in [true, false]) {
      final recorder = SquatDiagnosticRecorder(compareWorldAngles: true);
      final frame = fixture.sample(wrongSide ? 100 : 99, 175);
      final pair = SquatAngleComparison.fromFrames(
          frame, frame, wrongSide ? SquatSide.right : SquatSide.left);
      recorder.observe(
          time: 100,
          side: SquatSide.left,
          filtered2d: 175,
          confidence: .95,
          comparison: pair);
      final summary = recorder.sessionSummary()['comparison'] as Map;
      expect(summary['mismatchedFrames'], 1);
      expect((summary['raw3d'] as Map)['count'], 0);
      expect((summary['raw2d'] as Map)['count'], 0);
    }
  });
  test(
      'world comparison is bounded and raw/filtered values never affect baseline attempts',
      () {
    final r = DiagnosticRig(
        SquatDiagnosticRecorder(compareWorldAngles: true, capacity: 2),
        withWorld: true)
      ..hold(175, 12);
    r.cycle();
    r.cycle(bottom: 125);
    final event = r.recorder.records.last.toJson();
    final comparison = event['comparison'] as Map;
    expect((comparison['raw3d'] as Map)['count'], greaterThan(0));
    expect((comparison['filtered3d'] as Map)['count'], greaterThan(0));
    expect(comparison['mismatchedFrames'], 0);
    final summary = r.recorder.sessionSummary();
    expect(summary['comparisonPopulation'],
        'usable_2d_frames_including_calibration');
    expect(summary['rejected2dObservations'], 0);
    expect((summary['comparison'] as Map)['matchedFrames'],
        greaterThan(comparison['matchedFrames'] as int));
    (event['comparison'] as Map)['matchedFrames'] = -1;
    expect(
        (r.recorder.records.last.toJson()['comparison']
            as Map)['matchedFrames'],
        greaterThan(0));
    r.analyzer.reset();
    expect(
        (r.recorder.sessionSummary()['comparison'] as Map)['matchedFrames'], 0);
  });
  test(
      'missing world data reports unavailable, while 2D decisions continue unchanged',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder(compareWorldAngles: true))
      ..hold(175, 12);
    r.cycle();
    final c = r.recorder.records.single.toJson()['comparison'] as Map;
    expect((c['raw3d'] as Map)['count'], 0);
    expect((c['raw3dUnavailable'] as Map)['missing_landmark'], greaterThan(0));
    expect(r.last!.repetitions, 1);
  });
  test(
      'attempt explanations preserve every baseline decision and expose actual penalties',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder())..hold(175, 12);
    r.cycle(lean: 60);
    final full = r.recorder.records.single.toJson();
    expect(full['outcome'], 'full');
    expect(full['reason'], 'confirmed_depth');
    expect(full['side'], 'left');
    expect(full['minimumFiltered2dDegrees'], lessThanOrEqualTo(90));
    expect(full['longestContinuousDepthMicros'], greaterThanOrEqualTo(150000));
    expect(full['maximumDecisionDepthDwellMicros'],
        full['decisionDepthDwellAtConfirmationMicros']);
    expect(full['decisionDepthDwellAtConfirmationMicros'],
        greaterThanOrEqualTo(150000));
    expect(full['depthPenalty'], 0);
    expect(full['trunkPenalty'], greaterThan(0));
    expect(full['scorePercent'], r.last!.formScorePercent);
    r.cycle(bottom: 125);
    final partial = r.recorder.records.last.toJson();
    expect(partial['outcome'], 'partial');
    expect(partial['reason'], 'depth_angle_not_reached');
    expect(partial['longestContinuousDepthMicros'], 0);
    expect(partial['depthPenalty'], inInclusiveRange(10, 50));
    expect(partial['sessionScorePercent'], r.last!.formScorePercent);
    expect(r.last!.repetitions, 1);
    expect(r.last!.partialRepetitions, 1);
  });
  test(
      'interruption breaks depth continuity and pause records an unscored abort',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder())..hold(175, 12);
    r.ramp(175, 75);
    r.step(75, missing: true);
    r.step(75, missing: true);
    r.hold(75, 3);
    r.analyzer.pause();
    r.baseline.pause();
    final event = r.recorder.records.single.toJson();
    expect(event['outcome'], 'aborted');
    expect(event['reason'], 'paused');
    expect(event['trackingInterruptions'], 1);
    expect(event['rejectedFrames'], 2);
    expect(event['scorePercent'], isNull);
    expect(event['depthPenalty'], isNull);
    expect(r.last!.repetitions, 0);
    r.analyzer.resume();
    r.baseline.resume();
    r.hold(175, 12);
    r.cycle();
    expect(r.recorder.records.last.toJson()['outcome'], 'full');
  });
  test(
      'watchdog/gap aborts are bounded and unavailable movement never becomes a partial',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder())..hold(175, 12);
    r.ramp(175, 100);
    r.time += 600000;
    expect(facts(r.analyzer.tick(nowMicros: r.time)),
        facts(r.baseline.tick(nowMicros: r.time)));
    expect(r.recorder.records.single.toJson()['reason'], 'watchdog_stale');
    expect(r.recorder.records.single.toJson()['outcome'], 'aborted');
    r.hold(175, 12);
    r.ramp(175, 100);
    r.step(100, delta: 300000);
    expect(r.recorder.records.last.toJson()['reason'], 'frame_gap');
    expect(r.last!.partialRepetitions, 0);
  });
  test('retention caps summaries and contains no poses or identity strings',
      () {
    final r = DiagnosticRig(SquatDiagnosticRecorder(capacity: 2))
      ..hold(175, 12);
    for (var i = 0; i < 5; i++) {
      r.cycle();
    }
    expect(r.recorder.records.length, 2);
    expect(r.recorder.totalRecords, 5);
    expect(r.recorder.retentionEvictions, 3);
    final json = jsonEncode(r.recorder.records.map((e) => e.toJson()).toList());
    for (final text in [
      'landmarks',
      'worldLandmarks',
      'analytic-v1',
      'fixture',
      'capturedAt',
      'userId',
      'sessionId'
    ]) {
      expect(json, isNot(contains(text)));
    }
    expect(() => r.recorder.records.clear(), throwsUnsupportedError);
    r.analyzer.reset();
    r.baseline.reset();
    expect(r.recorder.records, isEmpty);
    expect(r.recorder.totalRecords, 0);
    expect(() => SquatDiagnosticRecorder(capacity: 0), throwsArgumentError);
    expect(() => SquatDiagnosticRecorder(capacity: 129), throwsArgumentError);
  });
}
