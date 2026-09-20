class FormScore {
  const FormScore({
    required this.trackingConfidence,
    required this.accuracy,
    required this.trackedDurationMicros,
  });

  final int trackingConfidence;
  final int accuracy;
  final int trackedDurationMicros;

  bool get isValidInterval => trackedDurationMicros > 0;

  static FormScore calculate({
    required double confidence,
    required double deviation,
    required int trackedDurationMicros,
  }) {
    final boundedConfidence = confidence.clamp(0, 1).toDouble();
    final boundedDeviation = deviation.clamp(0, 1).toDouble();
    return FormScore(
      trackingConfidence: (boundedConfidence * 100).round(),
      accuracy: ((1 - boundedDeviation) * 100).round(),
      trackedDurationMicros: trackedDurationMicros,
    );
  }
}
