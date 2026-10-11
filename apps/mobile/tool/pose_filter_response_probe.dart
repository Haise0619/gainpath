// Offline diagnostic only. Synthetic coordinates; no camera, workout, storage,
// submission or production configuration changes. Prints aggregates, not streams.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

const _joints = [PoseLandmark.leftElbow, PoseLandmark.leftWrist];
const _holds = [(6.0, 8.0), (11.0, 13.0), (13.6, 16.0), (16.6, 20.0)];

double _progress(double t) => switch (t) {
      < 3 => 0,
      < 6 => (t - 3) / 3,
      < 8 => 1,
      < 11 => 1 - (t - 8) / 3,
      < 13 => 0,
      < 13.6 => (t - 13) / .6,
      < 16 => 1,
      < 16.6 => 1 - (t - 16) / .6,
      _ => 0,
    };

PoseFrame _frame(int micros, double progress, {double offset = 0}) => PoseFrame(
      capturedAtMicros: micros,
      detectorId: 'offline-coordinate-probe',
      modelVersion: 'synthetic-only',
      imageWidth: 480,
      imageHeight: 720,
      landmarks: {
        PoseLandmark.leftShoulder:
            PosePoint(x: .4, y: .35 + offset, z: 0, visibility: 1, presence: 1),
        PoseLandmark.leftElbow: PosePoint(
            x: .5,
            y: .70 - .55 * progress + offset,
            z: 0,
            visibility: 1,
            presence: 1),
        PoseLandmark.leftWrist: PosePoint(
            x: .6,
            y: .85 - .75 * progress + offset,
            z: 0,
            visibility: 1,
            presence: 1),
      },
    );

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

Map<String, double> _distribution(List<double> values) {
  final sorted = values.toList()..sort();
  double percentile(double p) => sorted[((sorted.length - 1) * p).ceil()];
  return {
    'mean': values.reduce((a, b) => a + b) / values.length,
    'p50': percentile(.5),
    'p95': percentile(.95),
    'max': sorted.last,
  };
}

Map<String, Object?> _probe(double fps) {
  final raw = <PoseFrame>[], filtered = <PoseFrame>[];
  final filter = PoseFrameFilter(), shiftedFilter = PoseFrameFilter();
  var time = 1000000, index = 0;
  var translationResidual = 0.0, projectionResidual = 0.0;
  // Same continuous motion at both cadences, not the same frame-index motion.
  // Rounded integer timestamps and fixed +/-3% cadence variation are synthetic.
  while ((time - 1000000) / 1e6 <= 20) {
    final t = (time - 1000000) / 1e6;
    final f = _frame(time, _progress(t));
    final result = filter.filter(f);
    final shifted =
        shiftedFilter.filter(_frame(time, _progress(t), offset: .04));
    raw.add(f);
    filtered.add(result);
    for (final j in _joints) {
      final r = f.landmarks[j]!, s = result.landmarks[j]!;
      translationResidual = math.max(
          translationResidual, (shifted.landmarks[j]!.y - s.y - .04).abs());
      for (final mirror in [false, true]) {
        final projection = PreviewProjection(
            imageWidth: 480,
            imageHeight: 720,
            viewportWidth: 360,
            viewportHeight: 640,
            mirrored: mirror);
        final a = projection.project(r.x, r.y),
            b = projection.project(s.x, s.y);
        final origin = projection.project(0, 0),
            unit = projection.project(0, 1);
        projectionResidual = math.max(projectionResidual,
            ((b.$2 - a.$2) - (s.y - r.y) * (unit.$2 - origin.$2)).abs());
      }
    }
    time += (1e6 / fps * [1.0, .97, 1.03][index++ % 3]).round();
  }
  _check(translationResidual < 1e-12, 'Filter translation invariance failed');
  _check(projectionResidual < 1e-9, 'Affine preview displacement check failed');
  final jointResults = <String, Object?>{};
  for (final j in _joints) {
    final errors = [
      for (var i = 0; i < raw.length; i++)
        (filtered[i].landmarks[j]!.y - raw[i].landmarks[j]!.y).abs() * 720
    ];
    _check(
        errors.every((v) => v.isFinite), '${j.name}: nonfinite displacement');
    final motion = <String, Object?>{};
    for (final phase in [
      ('slowRaise', 3.0, 6.0),
      ('slowLower', 8.0, 11.0),
      ('fastRaise', 13.0, 13.6),
      ('fastLower', 16.0, 16.6)
    ]) {
      motion[phase.$1] = _distribution([
        for (var i = 0; i < raw.length; i++)
          if ((raw[i].capturedAtMicros - 1000000) / 1e6 > phase.$2 &&
              (raw[i].capturedAtMicros - 1000000) / 1e6 <= phase.$3)
            errors[i]
      ]);
    }
    final crossings = <Map<String, Object?>>[];
    for (final pair in [('refined', raw), ('filtered', filtered)]) {
      for (var i = 1; i < pair.$2.length; i++) {
        final a = pair.$2[i - 1].landmarks[j]!.y - .35;
        final b = pair.$2[i].landmarks[j]!.y - .35;
        if (a > 0 && b <= 0 || a < 0 && b >= 0) {
          crossings.add({
            'stage': pair.$1,
            'direction': a > 0 ? 'raise' : 'lower',
            'inputBracketMicros': [
              raw[i - 1].capturedAtMicros,
              raw[i].capturedAtMicros
            ]
          });
        }
      }
    }
    _check(
        crossings.length == 8, '${j.name}: expected four crossings per stage');
    final holds = <Map<String, Object?>>[];
    for (final hold in _holds) {
      final indices = [
        for (var i = 0; i < raw.length; i++)
          if ((raw[i].capturedAtMicros - 1000000) / 1e6 >= hold.$1 &&
              (raw[i].capturedAtMicros - 1000000) / 1e6 < hold.$2)
            i
      ];
      final stable = indices.firstWhere((i) =>
          errors[i] < 1 &&
          indices.where((k) => k >= i).every((k) => errors[k] < 1));
      final lower =
          (raw[stable - 1].capturedAtMicros - 1000000) / 1e6 - hold.$1;
      final upper = (raw[stable].capturedAtMicros - 1000000) / 1e6 - hold.$1;
      _check(errors[indices.last] < .02, '${j.name}: hold failed to converge');
      holds.add({
        'holdStartSeconds': hold.$1,
        'firstSustainedBelow1PixelBracketMs': [
          math.max(0, lower * 1000),
          upper * 1000
        ],
        'finalErrorPixels': errors[indices.last]
      });
    }
    jointResults[j.name] = {
      'motionDisplacementImagePixels': motion,
      'crossings': crossings,
      'holds': holds
    };
  }
  return {
    'syntheticNominalFps': fps,
    'frames': raw.length,
    'translationResidualNormalized': translationResidual,
    'previewAffineResidualPixels': projectionResidual,
    'joints': jointResults
  };
}

void main() {
  final filter = PoseFrameFilter();
  _check(
      filter.beta == .3 &&
          filter.minCutoff == 1 &&
          OneEuroFilter().dCutoff == 1,
      'Frozen filter defaults changed');
  var staticError = 0.0;
  // A deliberately biased constant signal is preserved, not corrected or moved
  // by the filter. Its artificial 28.8 px bias is not an observed human error.
  for (var i = 0; i < 60; i++) {
    final raw = _frame(1000000 + i * 73000, 1, offset: .04);
    final result = filter.filter(raw);
    for (final j in _joints) {
      staticError = math.max(
          staticError, (result.landmarks[j]!.y - raw.landmarks[j]!.y).abs());
    }
  }
  _check(staticError < 1e-12, 'Constant signal changed');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'scope':
        'Synthetic offline coordinates only; not phone or physical latency',
    'parameters': {'beta': .3, 'minCutoff': 1, 'derivativeCutoff': 1},
    'constantInputResidualNormalized': staticError,
    'runs': [_probe(11.08), _probe(13.68)],
    'checks':
        'constant preservation, translation invariance, affine preview displacement, four crossings per stage, hold convergence',
  }));
}
