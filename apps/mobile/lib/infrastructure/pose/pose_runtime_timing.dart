/// Bounded scalar-only runtime observations. Never changes pose admission.
class PoseRuntimeTiming {
  PoseRuntimeTiming({required this.onReport, this.maximumReports = 60});
  final void Function(Map<String, Object>) onReport;
  final int maximumReports;
  int _reports = 0, _deliveries = 0, _stale = 0;
  int _maxProcessing = 0, _maxGap = 0, _maxAge = 0;
  int? _lastDelivery, _lastReport;
  void processed(int micros) {
    if (micros > _maxProcessing) _maxProcessing = micros;
  }

  void discarded(String reason) {
    if (reason == 'stale_result') _stale++;
  }

  void delivered(int now, int age) {
    final previous = _lastDelivery;
    if (previous != null && now - previous > _maxGap) _maxGap = now - previous;
    _lastDelivery = now;
    if (age > _maxAge) _maxAge = age;
    _deliveries++;
    report(now);
  }

  void report(int now) {
    if (_reports >= maximumReports ||
        (_lastReport != null && now - _lastReport! < 1000000)) {
      return;
    }
    _lastReport = now;
    _reports++;
    onReport({
      'delivered': _deliveries,
      'staleResults': _stale,
      'maximumProcessingMicros': _maxProcessing,
      'maximumDeliveryGapMicros': _maxGap,
      'maximumDeliveredAgeMicros': _maxAge,
      'deliverySilenceMicros': _lastDelivery == null ? 0 : now - _lastDelivery!,
    });
  }
}
