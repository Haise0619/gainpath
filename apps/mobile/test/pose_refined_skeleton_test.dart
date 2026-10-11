import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_joint_lag_diagnostics.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_quality_diagnostics.dart';

const _candidate = bool.fromEnvironment('GAINPATH_POSE_REFINED_SKELETON') &&
    bool.fromEnvironment('GAINPATH_POSE_JOINT_LAG_DEBUG');

PoseFrame _frame(
        {double offset = 0,
        int timestamp = 100,
        int width = 480,
        String model = 'fixture',
        double elbowX = .3,
        double confidence = 1}) =>
    PoseFrame(
        capturedAtMicros: timestamp,
        detectorId: 'test',
        modelVersion: model,
        imageWidth: width,
        imageHeight: 720,
        landmarks: {
          PoseLandmark.leftShoulder: PosePoint(
              x: .2 + offset, y: .3, z: 0, visibility: 1, presence: 1),
          PoseLandmark.leftElbow: PosePoint(
              x: elbowX + offset,
              y: .4,
              z: 0,
              visibility: confidence,
              presence: confidence),
          PoseLandmark.leftWrist: PosePoint(
              x: .4 + offset, y: .5, z: 0, visibility: 1, presence: 1),
        });

void _deliver(
    PoseJointLagDiagnostics lag, PoseFrame refined, PoseFrame filtered) {
  lag.delivered(
      refined,
      filtered,
      {
        'frameTimestampMicros': filtered.capturedAtMicros,
        'projection': {'timestampMicros': filtered.capturedAtMicros},
      },
      150);
}

Future<ByteData> _pixels(PoseFrame? frame, PoseJointLagDiagnostics lag,
    {bool mirrored = false, PoseQualityDiagnostics? quality}) async {
  final recorder = ui.PictureRecorder();
  PoseLandmarkPainter(
          frame: frame, mirrored: mirrored, lag: lag, quality: quality)
      .paint(Canvas(recorder), const Size(480, 720));
  final picture = recorder.endRecording(),
      image = await picture.toImage(480, 720);
  picture.dispose();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return bytes;
}

int _green(ByteData bytes, {int? centerX, int centerY = 252}) {
  var count = 0;
  for (var y = 0; y < 720; y++) {
    for (var x = 0; x < 480; x++) {
      if (centerX != null &&
          ((x - centerX).abs() > 6 || (y - centerY).abs() > 6)) {
        continue;
      }
      final i = (y * 480 + x) * 4;
      if (bytes.getUint8(i) == 0x67 &&
          bytes.getUint8(i + 1) == 0xE8 &&
          bytes.getUint8(i + 2) == 0xAB &&
          bytes.getUint8(i + 3) > 0) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  test(
      'starting capture keeps display owner but excludes previous delivery from report',
      () async {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    final filtered = _frame(offset: .3);
    _deliver(lag, _frame(), filtered);
    lag.start('still');
    expect(_green(await _pixels(filtered, lag), centerX: 120), greaterThan(0));
    expect(lag.finish()['paintedFrames'], 0);
  }, skip: !_candidate);
  for (final mirrored in [false, true]) {
    test('primary skeleton uses selected source with mirror=$mirrored',
        () async {
      final lag =
          PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
      final refined = _frame(), filtered = _frame(offset: .3);
      _deliver(lag, refined, filtered);
      final bytes = await _pixels(filtered, lag, mirrored: mirrored);
      final refinedX = mirrored ? 360 : 120, filteredX = mirrored ? 216 : 264;
      expect(_green(bytes, centerX: _candidate ? refinedX : filteredX),
          greaterThan(0));
      expect(_green(bytes, centerX: _candidate ? filteredX : refinedX), 0);
    });
  }
  test(
      'refined primary keeps filtered marker projection and displacement ledger',
      () async {
    final quality =
        PoseQualityDiagnostics(clockMicros: () => 200, enabled: true);
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    lag.start('fast');
    final refined = _frame(), filtered = _frame(offset: .3);
    _deliver(lag, refined, filtered);
    await _pixels(filtered, lag, quality: quality);
    final report = lag.finish(),
        stat = (report['jointStats'] as Map)['leftElbow'] as Map;
    expect(stat['displacementP50Pixels'], closeTo(144, 1e-8));
    expect(stat['projectionResidualMaxPixels'], closeTo(0, 1e-8));
    if (_candidate) {
      expect(quality.lastPaint['primarySkeletonSource'], 'refined_diagnostic');
      final representative = (report['representatives'] as List).first as Map;
      expect(representative['primarySkeletonSource'], 'refined_diagnostic');
      expect(representative['previewCoordinateSource'], 'filtered_markers');
    }
  });
  for (final invalid in [
    'missing',
    'timestamp',
    'model',
    'dimensions',
    'nonfinite',
    'confidence'
  ]) {
    test('candidate refuses $invalid refined source without filtered fallback',
        () async {
      final lag =
          PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
      final filtered = _frame(offset: .3);
      if (invalid != 'missing') {
        final refined = _frame(
            timestamp: invalid == 'timestamp' ? 99 : 100,
            model: invalid == 'model' ? 'other' : 'fixture',
            width: invalid == 'dimensions' ? 481 : 480,
            elbowX: invalid == 'nonfinite' ? double.nan : .3,
            confidence: invalid == 'confidence' ? .4 : 1);
        _deliver(lag, refined, filtered);
      }
      expect(_green(await _pixels(filtered, lag)), 0);
    }, skip: !_candidate);
  }
  test(
      'null filtered owner or cleared generation never resurrects refined skeleton',
      () async {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    final filtered = _frame(offset: .3);
    _deliver(lag, _frame(), filtered);
    expect(_green(await _pixels(null, lag)), 0);
    lag.clear();
    expect(_green(await _pixels(filtered, lag)), 0);
    _deliver(lag, _frame(), filtered);
    lag.filterReset('freshness_expiry');
    expect(_green(await _pixels(filtered, lag)), 0);
  }, skip: !_candidate);
  test('candidate preserves per-joint confidence rejection', () async {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    _deliver(lag, _frame(confidence: .4), _frame(offset: .3, confidence: .4));
    final bytes = await _pixels(_frame(offset: .3, confidence: .4), lag);
    expect(_green(bytes, centerX: 120), 0);
    expect(_green(bytes, centerX: 168, centerY: 324), 0);
  }, skip: !_candidate);
  test(
      'clearing refined ownership repaints even when filtered frame is unchanged',
      () {
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 200);
    final filtered = _frame(offset: .3);
    _deliver(lag, _frame(), filtered);
    final before =
        PoseLandmarkPainter(frame: filtered, mirrored: false, lag: lag);
    lag.clear();
    final after =
        PoseLandmarkPainter(frame: filtered, mirrored: false, lag: lag);
    expect(after.shouldRepaint(before), true);
  }, skip: !_candidate);
}
