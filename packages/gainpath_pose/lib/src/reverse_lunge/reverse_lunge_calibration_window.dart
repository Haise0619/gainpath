import 'dart:math' as math;
import 'reverse_lunge_geometry.dart';

/// Bounded fresh neutral evidence. Weak observations pause the hold and never
/// earn time; the baseline is an observed inlier, rather than fabricated joints.
class ReverseLungeCalibrationWindow {
  final _samples = <(int, ReverseLungeGeometry, int)>[];
  int? _lastValid;
  bool _previousValid = false;
  int _pendingFresh = 0;
  double progress = 0;
  String reason = 'neutral_hold';
  int get sampleCount => _samples.length;

  void reset() {
    _samples.clear();
    _lastValid = null;
    _previousValid = false;
    _pendingFresh = 0;
    progress = 0;
    reason = 'neutral_hold';
  }

  bool keepAcrossWeakFrame(int time) {
    _previousValid = false;
    if (_lastValid != null && time - _lastValid! <= 180000) return true;
    reset();
    return false;
  }

  ReverseLungeGeometry? add(int time, ReverseLungeGeometry g) {
    if (_lastValid != null && time - _lastValid! > 180000) reset();
    if (_previousValid && _lastValid != null) {
      _pendingFresh += math.min(time - _lastValid!, 150000);
    }
    _lastValid = time;
    _previousValid = true;
    _samples.removeWhere((s) => time - s.$1 > 1600000);
    if (_samples.isEmpty || time ~/ 50000 != _samples.last.$1 ~/ 50000) {
      _samples.add((time, g, _pendingFresh));
      _pendingFresh = 0;
    }
    if (_samples.length > 32) _samples.removeAt(0);
    double median(double Function(ReverseLungeGeometry) value) {
      final values = _samples.map((s) => value(s.$2)).toList()..sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }

    final leg = median((g) => g.legLength);
    final front =
        (median((g) => g.frontAnkle.$1), median((g) => g.frontAnkle.$2));
    final rear = (median((g) => g.rearAnkle.$1), median((g) => g.rearAnkle.$2));
    final hip = (median((g) => g.frontHip.$1), median((g) => g.frontHip.$2));
    final angle = median((g) => g.frontAngle);
    final facing = _samples.first.$2.facing;
    bool inlier(ReverseLungeGeometry sample) =>
        sample.facing == facing &&
        ReverseLungeGeometry.distance(sample.frontAnkle, front) <= leg * .07 &&
        ReverseLungeGeometry.distance(sample.rearAnkle, rear) <= leg * .07 &&
        ReverseLungeGeometry.distance(sample.frontHip, hip) <= leg * .07 &&
        (sample.frontAngle - angle).abs() <= 10 &&
        (sample.legLength / leg - 1).abs() <= .10;
    final stable = _samples.where((s) => inlier(s.$2)).toList();
    double drift(double Function(ReverseLungeGeometry) value) {
      if (stable.length < 8) return 0;
      final count = math.max(2, stable.length ~/ 4);
      double mean(Iterable<(int, ReverseLungeGeometry, int)> samples) =>
          samples.map((s) => value(s.$2)).reduce((a, b) => a + b) / count;
      return (mean(stable.take(count)) -
                  mean(stable.skip(stable.length - count)))
              .abs() /
          leg;
    }

    if (stable.length / _samples.length < .8 ||
        !inlier(g) ||
        [
          drift((g) => g.frontAnkle.$1),
          drift((g) => g.frontAnkle.$2),
          drift((g) => g.rearAnkle.$1),
          drift((g) => g.rearAnkle.$2),
          drift((g) => g.frontHip.$1),
          drift((g) => g.frontHip.$2),
        ].any((d) => d > .035)) {
      // Even an observation between stored time buckets must break temporal
      // credit. Otherwise two stored inliers can hide an intervening outlier.
      _previousValid = false;
      _pendingFresh = 0;
      if (_samples.last.$1 == time) {
        _samples[_samples.length - 1] = (time, g, 0);
      }
      reason = 'neutral_motion';
      progress = 0;
      return null;
    }
    var fresh = 0;
    for (var i = 1; i < _samples.length; i++) {
      // An outlier interval receives no credit at either boundary.
      if (inlier(_samples[i - 1].$2) && inlier(_samples[i].$2)) {
        fresh += _samples[i].$3;
      }
    }
    reason = 'neutral_hold';
    final ready = fresh >= 800000 && stable.length >= 8;
    progress = ready ? 1 : (fresh / 800000).clamp(0, .95);
    if (!ready) return null;
    stable.sort((a, b) {
      double residual(ReverseLungeGeometry v) =>
          ReverseLungeGeometry.distance(v.frontAnkle, front) +
          ReverseLungeGeometry.distance(v.rearAnkle, rear) +
          ReverseLungeGeometry.distance(v.frontHip, hip);
      return residual(a.$2).compareTo(residual(b.$2));
    });
    return stable.first.$2;
  }
}
