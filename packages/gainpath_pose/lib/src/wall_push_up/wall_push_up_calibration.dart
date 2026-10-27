import 'dart:math' as math;
import 'wall_push_up_geometry.dart';

/// Short, time-bucketed neutral window; readiness never comes from a timer alone.
class WallPushUpCalibration {
  final _samples = <(int, WallPushUpGeometry)>[];
  int? _lastValid;
  double progress = 0;
  bool get isEmpty => _samples.isEmpty;
  void reset() {
    _samples.clear();
    _lastValid = null;
    progress = 0;
  }

  bool keepAcrossBadSample(int t) {
    if (_lastValid != null && t - _lastValid! <= 180000) return true;
    reset();
    return false;
  }

  WallPushUpGeometry? add(int t, WallPushUpGeometry g) {
    if (_lastValid != null && t - _lastValid! > 250000) reset();
    _samples.removeWhere((s) => t - s.$1 > 1200000);
    if (_samples.isEmpty || t - _samples.last.$1 >= 40000) _samples.add((t, g));
    if (_samples.length > 32) _samples.removeAt(0);
    _lastValid = t;
    double median(double Function(WallPushUpGeometry) value) {
      final a = _samples.map((s) => value(s.$2)).toList()..sort();
      final m = a.length ~/ 2;
      return a.length.isOdd ? a[m] : (a[m - 1] + a[m]) / 2;
    }

    final center = WallPushUpGeometry(
        elbowAngleDegrees: median((g) => g.elbowAngleDegrees),
        bodyAngleDegrees: median((g) => g.bodyAngleDegrees),
        torsoLength: median((g) => g.torsoLength),
        torsoAngleDegrees: median((g) => g.torsoAngleDegrees),
        wristX: median((g) => g.wristX),
        wristY: median((g) => g.wristY),
        reach: median((g) => g.reach),
        horizontalReach: median((g) => g.horizontalReach),
        handHeight: median((g) => g.handHeight));
    bool inlier(WallPushUpGeometry v) =>
        v.wristDistance(center) <= .08 &&
        (v.torsoLength / center.torsoLength - 1).abs() <= .12 &&
        (v.elbowAngleDegrees - center.elbowAngleDegrees).abs() <= 15 &&
        (v.reach - center.reach).abs() / center.torsoLength <= .10;
    final stable = _samples.where((s) => inlier(s.$2)).toList();
    if (stable.length / _samples.length < .8) {
      progress = 0;
      return null;
    }
    var fresh = 0;
    for (var i = 1; i < stable.length; i++) {
      fresh += math.min(stable[i].$1 - stable[i - 1].$1, 150000);
    }
    final ready = stable.length >= 6 && fresh >= 800000 && inlier(g);
    progress = ready ? 1 : (fresh / 800000).clamp(0.0, .95);
    return ready ? center : null;
  }
}
