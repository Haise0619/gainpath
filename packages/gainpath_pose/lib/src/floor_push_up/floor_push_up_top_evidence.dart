/// Supplementary counting evidence for low-rate capture plus filter latency.
/// All samples must already have passed geometry/source checks. This requires
/// observed raw TOP for the full configured dwell, three distinct samples and
/// a smoothed TOP endpoint. It never estimates a crossing or shortens the dwell.
class FloorPushUpTopEvidence {
  static const revision = 'floor-observed-top-dwell-v1';
  static const minimumConfidence = .85;
  static const minimumSamples = 3;
  int? _since, _last;
  int _samples = 0;
  int get spanMicros => _since == null || _last == null ? 0 : _last! - _since!;
  Map<String, Object?> get diagnostics => {
        'topEvidenceVersion': revision,
        'topRawHoldSinceMicros': _since,
        'topRawLastCaptureMicros': _last,
        'topRawSamples': _samples,
        'topRawSpanMicros': spanMicros,
        'topRawMinimumConfidence': minimumConfidence,
        'topRawMinimumSamples': minimumSamples,
      };
  void reset() {
    _since = null;
    _last = null;
    _samples = 0;
  }

  bool observe(int capture,
      {required double rawAngle,
      required double smoothedAngle,
      required double confidence,
      required double topAngle,
      required int dwellMicros,
      required int maximumGapMicros}) {
    if (_last != null && capture <= _last!) return false;
    if (!rawAngle.isFinite ||
        !smoothedAngle.isFinite ||
        !confidence.isFinite ||
        rawAngle < topAngle ||
        confidence < minimumConfidence) {
      reset();
      return false;
    }
    if (_last != null && capture - _last! > maximumGapMicros) reset();
    _since ??= capture;
    _last = capture;
    _samples++;
    return _samples >= minimumSamples &&
        spanMicros >= dwellMicros &&
        smoothedAngle >= topAngle;
  }
}
