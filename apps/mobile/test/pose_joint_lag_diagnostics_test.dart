import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_joint_lag_diagnostics.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/pose_landmark_painter.dart';

PoseFrame fixture(int t, double x, {double confidence = 1}) => PoseFrame(
        capturedAtMicros: t,
        detectorId: 'diagnostic-fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          PoseLandmark.leftElbow: PosePoint(
              x: x, y: .5, z: 0, visibility: confidence, presence: confidence)
        });
Map<String, Object?> trace(int t) => {
      'frameTimestampMicros': t,
      'projection': {
        'timestampMicros': t,
        'rawRepresentatives': {
          'leftElbow': {
            'modelPixels': [64.0, 128.0, 0.0],
            'roiNormalized': [.25, .5, 0.0],
            'unrefinedImagePixels': [120.0, 360.0]
          }
        }
      }
    };
void main() {
  test('starting a capture cannot count the previous delivery as a new sample',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 1000);
    final f = fixture(100, .25);
    lag.delivered(f, f, trace(100), 200);
    lag.start('still');
    lag.painted(f, const Size(480, 720),
        mirrored: false,
        points: {PoseLandmark.leftElbow: const Offset(120, 360)},
        drawn: {},
        connections: true);
    expect(lag.retainedFrames, 0);
    expect(lag.mismatches, 0);
    expect(lag.finish()['ignoredPaintsWithoutDelivery'], 1);
  });
  test('bounded representative logging survives the Android 1023-byte limit',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 1000);
    lag.start('still');
    final f = fixture(100, .25);
    lag.delivered(f, f, trace(100), 200);
    lag.painted(f, const Size(480, 720),
        mirrored: true,
        points: {PoseLandmark.leftElbow: const Offset(360, 360)},
        drawn: {},
        connections: true,
        viewport: {
          'width': 411.42857142857144,
          'height': 728.0,
          'coverScale': 1.011111111111111,
          'coverOffsetX': -36.952380952380935
        });
    final report = lag.finish();
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    try {
      printJointLagReport(report);
    } finally {
      debugPrint = original;
    }
    expect(lines.every((line) => utf8.encode(line).length <= 900), true);
    final chunks = lines
        .where((line) => line.startsWith('POSE_LAG_CHUNK '))
        .map((line) =>
            jsonDecode(line.substring('POSE_LAG_CHUNK '.length)) as Map)
        .toList();
    expect(chunks, isNotEmpty);
    final sampleChunks = chunks.where((c) => c['stage'] == 'SAMPLE').toList()
      ..sort((a, b) => (a['part'] as int).compareTo(b['part'] as int));
    final restored =
        jsonDecode(sampleChunks.map((c) => c['data']).join()) as Map;
    expect(restored['joint'], 'leftElbow');
    expect(restored['filteredImagePixels'], [120.0, 360.0]);
    expect(restored['captureStartedMicros'], 1000);
  });
  test('deadline ends a stalled capture without a subsequent delivery', () {
    var now = 100;
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => now);
    lag.start('still');
    now += 20000000;
    expect(lag.finishIfExpired(), true);
    expect(lag.phase, isNull);
    expect(lag.retainedFrames, 0);
    expect(lag.lastReport['paintedFrames'], 0);
  });
  test('nonfinite observations do not poison valid displacement statistics',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 1000);
    lag.start('slow');
    for (final t in [100, 200]) {
      final f = fixture(t, t == 100 ? .3 : double.nan);
      lag.delivered(fixture(t, .25), f, trace(t), 300);
      lag.painted(f, const Size(480, 720),
          mirrored: false,
          points: {
            PoseLandmark.leftElbow:
                Offset(f.landmarks.values.single.x * 480, 360)
          },
          drawn: {},
          connections: true);
    }
    final stats = (lag.finish()['jointStats'] as Map)['leftElbow'] as Map;
    expect(stats['accepted'], 2);
    expect(stats['invalidCoordinates'], 1);
    expect(stats['displacementMeanPixels'], closeTo(24, 1e-10));
  });
  test('observes real painter upper-arm draw and forearm presence rejection',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    lag.start('still');
    final f = PoseFrame(
        capturedAtMicros: 100,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          PoseLandmark.leftShoulder:
              const PosePoint(x: .2, y: .3, z: 0, visibility: 1, presence: 1),
          PoseLandmark.leftElbow:
              const PosePoint(x: .2, y: .5, z: 0, visibility: 1, presence: 1),
          PoseLandmark.leftWrist:
              const PosePoint(x: .2, y: .7, z: 0, visibility: 1, presence: .4),
        });
    lag.delivered(f, f, trace(100), 150);
    final recorder = PictureRecorder();
    PoseLandmarkPainter(frame: f, mirrored: true, lag: lag)
        .paint(Canvas(recorder), const Size(480, 720));
    recorder.endRecording().dispose();
    final report = lag.finish();
    final links = report['linkStats'] as Map;
    expect(links['leftShoulder-leftElbow'], {'draw_issued': 1});
    expect(links['leftElbow-leftWrist'], {'leftWrist_rejected': 1});
    expect(
        ((report['jointStats'] as Map)['leftWrist'] as Map)['presenceRejected'],
        1);
  });
  test(
      'refuses worker or filtered timestamp mismatches instead of joining latest',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 300);
    lag.start('still');
    lag.delivered(fixture(100, .25), fixture(101, .3), trace(100), 200);
    lag.delivered(fixture(100, .25), fixture(100, .3), trace(99), 200);
    expect(lag.mismatches, 2);
    expect(lag.refinedFor(100), isNull);
  });
  test(
      'reports same-space displacement and the actual mirrored cover painter result',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 300);
    lag.start('slow');
    final rawTrace = trace(100);
    ((rawTrace['projection'] as Map)['rawRepresentatives'] as Map)['leftElbow']
        ['unrefinedImagePixels'] = [100.0, 360.0];
    lag.delivered(fixture(100, .25), fixture(100, .30), rawTrace, 200);
    // 480x720 image cover into 300x300: scale=.625, cropY=75.
    lag.painted(fixture(100, .30), const Size(300, 300),
        mirrored: true,
        points: {PoseLandmark.leftElbow: const Offset(210, 150)},
        drawn: {},
        connections: true);
    final report = lag.finish();
    final samples = report['representatives'] as List;
    final joint = (samples.single as Map)['joints'] as Map;
    final elbow = joint['leftElbow'] as Map;
    expect(elbow['refinedImagePixels'], [120.0, 360.0]);
    expect(elbow['filteredImagePixels'], [144.0, 360.0]);
    expect(elbow['previewPixels'], [210.0, 150.0]);
    expect(elbow['projectionResidualPixels'], closeTo(0, 1e-10));
    expect(elbow['displacementPixels'], closeTo(24, 1e-10));
    expect(elbow['refinementDisplacementPixels'], closeTo(20, 1e-10));
    expect(elbow['accepted'], true);
    expect((samples.single as Map)['deliveryMicros'], 200);
    expect((samples.single as Map)['inputMicros'], 100);
  });
  test(
      'keeps confidence rejection distinct from whole-pose loss and duplicate repaints',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 1000);
    lag.start('fast');
    final f = fixture(100, .25, confidence: .2);
    lag.delivered(f, f, trace(100), 200);
    for (var i = 0; i < 2; i++) {
      lag.painted(f, const Size(480, 720),
          mirrored: false,
          points: {PoseLandmark.leftElbow: null},
          drawn: {},
          connections: true);
    }
    final report = lag.finish();
    expect(report['paintedFrames'], 1);
    final stats = (report['jointStats'] as Map)['leftElbow'] as Map;
    expect(stats['rejected'], 1);
    expect(stats['visibilityRejected'], 1);
    expect(stats['presenceRejected'], 1);
  });
  test(
      'bounded capture clears on lifecycle and disabled diagnostics retain nothing',
      () {
    final lag = PoseJointLagDiagnostics(
        enabled: true, clockMicros: () => 1000, maxFrames: 2);
    lag.start('slow');
    for (var t = 1; t <= 4; t++) {
      final f = fixture(t, .25);
      lag.delivered(f, f, trace(t), t);
      lag.painted(f, const Size(480, 720),
          mirrored: false,
          points: {PoseLandmark.leftElbow: const Offset(120, 360)},
          drawn: {},
          connections: true);
    }
    expect(lag.retainedFrames, 2);
    expect(lag.finish()['capacityReached'], true);
    lag.clear();
    expect(lag.refinedFor(4), isNull);
    final off =
        PoseJointLagDiagnostics(enabled: false, clockMicros: () => 1000);
    off.start('slow');
    off.delivered(fixture(1, .25), fixture(1, .25), trace(1), 2);
    expect(off.refinedFor(1), isNull);
    expect(off.retainedFrames, 0);
  });
}
