import 'dart:math' as math;

/// A low-latency adaptive low-pass filter for noisy landmark values.
///
/// The filter is stateful and must be owned by one landmark stream. Its
/// timestamp is monotonic capture time, not a UI timer tick.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1,
    this.beta = 0,
    this.dCutoff = 1,
  })  : assert(minCutoff > 0),
        assert(dCutoff > 0),
        assert(beta >= 0);

  final double minCutoff;
  final double beta;
  final double dCutoff;
  double? _lastValue;
  double? _lastDerivative;
  double? _lastTimestamp;

  double filter(double value, {required double timestampSeconds}) {
    final previousValue = _lastValue;
    final previousTimestamp = _lastTimestamp;
    if (previousValue == null || previousTimestamp == null) {
      _lastValue = value;
      _lastDerivative = 0;
      _lastTimestamp = timestampSeconds;
      return value;
    }

    final dt = math.max(timestampSeconds - previousTimestamp, 1e-6);
    final rawDerivative = (value - previousValue) / dt;
    final derivativeAlpha = _alpha(dCutoff, dt);
    final derivative = _exponential(
        previousDerivative: _lastDerivative ?? 0,
        value: rawDerivative,
        alpha: derivativeAlpha);
    final cutoff = minCutoff + beta * derivative.abs();
    final alpha = _alpha(cutoff, dt);
    final filtered = _exponential(
        previousDerivative: previousValue, value: value, alpha: alpha);

    _lastValue = filtered;
    _lastDerivative = derivative;
    _lastTimestamp = timestampSeconds;
    return filtered;
  }

  double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  double _exponential({
    required double previousDerivative,
    required double value,
    required double alpha,
  }) =>
      alpha * value + (1 - alpha) * previousDerivative;
}
