import 'dart:math' as math;
import 'calf_raise_geometry.dart';

/// Bounded session-memory geometry only. No pose frames, playback or timer-only
/// readiness: calibration requires fresh, mostly consistent neutral samples.
class CalfCalibrationWindow {
  static const requiredMicros = 800000;
  final _samples = <(int, CalfRaiseGeometry)>[];
  int? _lastValid;
  double progress = 0;
  double heelNoise = 0, ankleNoise = 0;
  bool get isEmpty => _samples.isEmpty;

  void reset() {
    _samples.clear();
    _lastValid = null;
    progress = 0;
    heelNoise = ankleNoise = 0;
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
        thighLength: median((g) => g.thighLength),
        kneeAngleDegrees: median((g) => g.kneeAngleDegrees),
        heelHeight: median((g) => g.heelHeight),
        ankleY: median((g) => g.ankleY),
        toeX: median((g) => g.toeX),
        toeY: median((g) => g.toeY),
        imageHeight: g.imageHeight);
    bool inlier(CalfRaiseGeometry g) =>
        (g.shinLength / center.shinLength - 1).abs() <= .12 &&
        (g.heelHeight - center.heelHeight).abs() / center.shinLength <= .06 &&
        (g.ankleY - center.ankleY).abs() / center.shinLength <= .05 &&
        math.sqrt(math.pow(g.toeX - center.toeX, 2) +
                    math.pow(g.toeY - center.toeY, 2)) /
                center.shinLength <=
            .06;
    final stable = _samples.where((s) => inlier(s.$2)).toList();
    double spread(double Function(CalfRaiseGeometry) value) {
      final values = stable.map((s) => value(s.$2)).toList()..sort();
      if (values.length < 2) return 0;
      return (values[((values.length - 1) * .9).ceil()] -
              values[((values.length - 1) * .1).floor()]) /
          center.shinLength;
    }

    // A narrow moving range can pass a spread gate. Compare early/late groups
    // in time as well; averaging independent foot jitter avoids a single noisy
    // heel becoming a false motion trend.
    double coherentDrift() {
      if (stable.length < 6) return 0;
      final count = math.max(2, stable.length ~/ 4);
      double mean(Iterable<(int, CalfRaiseGeometry)> samples) =>
          samples
              .map((s) => (s.$2.heelHeight - s.$2.ankleY) / 2)
              .reduce((a, b) => a + b) /
          count;
      return (mean(stable.take(count)) -
                  mean(stable.skip(stable.length - count)))
              .abs() /
          center.shinLength;
    }

    if (stable.isEmpty ||
        stable.length / _samples.length < .8 ||
        spread((g) => g.heelHeight) > .09 ||
        spread((g) => g.ankleY) > .09 ||
        spread((g) => g.toeX) > .10 ||
        spread((g) => g.toeY) > .06 ||
        coherentDrift() > .025 ||
        // Independent heel noise may vary, but a coherent heel+ankle rise
        // must not be mistaken for a stationary heels-down setup.
        spread((g) =>
                ((g.heelHeight - center.heelHeight) +
                    (center.ankleY - g.ankleY)) /
                2) >
            .065 ||
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
    if (ready) {
      double noise(double Function(CalfRaiseGeometry) value, double baseline) {
        final deviations = stable
            .map((s) => (value(s.$2) - baseline).abs() / center.shinLength)
            .toList()
          ..sort();
        return deviations[((deviations.length - 1) * .9).ceil()]
            .clamp(0.0, .05);
      }

      heelNoise = noise((g) => g.heelHeight, center.heelHeight);
      ankleNoise = noise((g) => g.ankleY, center.ankleY);
    }
    return ready ? center : null;
  }
}
