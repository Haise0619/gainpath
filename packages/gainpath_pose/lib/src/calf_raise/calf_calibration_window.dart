import 'dart:math' as math;
import 'calf_raise_geometry.dart';

/// Bounded session-memory geometry only. No pose frames, playback or timer-only
/// readiness: calibration requires fresh, mostly consistent neutral samples.
class CalfCalibrationWindow {
  static const requiredMicros = 800000;
  final _samples = <(int, CalfRaiseGeometry)>[];
  int? _lastValid;
  double progress = 0;
  bool get isEmpty => _samples.isEmpty;

  void reset() {
    _samples.clear();
    _lastValid = null;
    progress = 0;
  }

  /// A brief weak frame pauses the hold; it never advances progress or counts.
  bool keepAcrossBadSample(int time) {
    if (_lastValid != null && time - _lastValid! <= 180000) return true;
    reset();
    return false;
  }

  CalfRaiseGeometry? add(int time, CalfRaiseGeometry g) {
    if (_lastValid != null && time - _lastValid! > 250000) reset();
    _samples.removeWhere((s) => time - s.$1 > 1200000);
    // Uniform time buckets keep a fast camera from filling the bounded sample
    // limit before the required hold duration. Every current sample must still
    // be a valid inlier before readiness can be returned.
    if (_samples.isEmpty || time - _samples.last.$1 >= 40000) {
      _samples.add((time, g));
    }
    if (_samples.length > 32) _samples.removeAt(0);
    _lastValid = time;
    double median(double Function(CalfRaiseGeometry) value) {
      final values = _samples.map((s) => value(s.$2)).toList()..sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }

    final center = CalfRaiseGeometry(
        shinLength: median((g) => g.shinLength),
        kneeAngleDegrees: median((g) => g.kneeAngleDegrees),
        heelHeight: median((g) => g.heelHeight),
        ankleY: median((g) => g.ankleY),
        toeX: median((g) => g.toeX),
        toeY: median((g) => g.toeY));
    bool inlier(CalfRaiseGeometry g) =>
        (g.shinLength / center.shinLength - 1).abs() <= .12 &&
        (g.heelHeight - center.heelHeight).abs() / center.shinLength <= .035 &&
        (g.ankleY - center.ankleY).abs() / center.shinLength <= .04 &&
        math.sqrt(math.pow(g.toeX - center.toeX, 2) +
                    math.pow(g.toeY - center.toeY, 2)) /
                center.shinLength <=
            .04;
    final stable = _samples.where((s) => inlier(s.$2)).toList();
    double spread(double Function(CalfRaiseGeometry) value) {
      final values = stable.map((s) => value(s.$2)).toList()..sort();
      if (values.length < 2) return 0;
      return (values[((values.length - 1) * .9).ceil()] -
              values[((values.length - 1) * .1).floor()]) /
          center.shinLength;
    }

    if (stable.isEmpty ||
        stable.length / _samples.length < .8 ||
        spread((g) => g.heelHeight) > .055 ||
        spread((g) => g.ankleY) > .06 ||
        spread((g) => g.toeX) > .06 ||
        spread((g) => g.toeY) > .04 ||
        spread((g) => g.shinLength) > .15) {
      progress = 0;
      return null;
    }
    // Gaps/outlier frames do not earn extra time. Normal lower-rate fresh
    // streams can still settle without demanding a particular camera FPS.
    var freshMicros = 0;
    for (var i = 1; i < stable.length; i++) {
      freshMicros += math.min(stable[i].$1 - stable[i - 1].$1, 150000);
    }
    final ready =
        stable.length >= 6 && freshMicros >= requiredMicros && inlier(g);
    progress = ready ? 1 : (freshMicros / requiredMicros).clamp(0.0, .95);
    return ready ? center : null;
  }
}
