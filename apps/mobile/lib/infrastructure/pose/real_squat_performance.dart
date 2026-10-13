import 'dart:collection';
import 'package:flutter/foundation.dart';

const realSquatPerformanceEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_SQUAT_PERFORMANCE');

class _Timing {
  _Timing(this.capacity);
  final int capacity;
  final recent = Queue<int>();
  int count = 0, total = 0;
  void add(int micros) {
    count++;
    total += micros;
    recent.add(micros);
    if (recent.length > capacity) recent.removeFirst();
  }

  Map<String, Object> get summary {
    final sorted = recent.toList()..sort();
    double percentile(double p) =>
        sorted[((sorted.length - 1) * p).round()] / 1000;
    return {
      'count': count,
      'retainedSamples': sorted.length,
      'meanMillis': total / count / 1000,
      'p50Millis': percentile(.5),
      'p95Millis': percentile(.95)
    };
  }
}

/// Scalar observation only. Input is after plane copy; paint is CPU, not present.
class RealSquatPerformance {
  RealSquatPerformance({required this.clockMicros, this.capacity = 300}) {
    if (capacity < 1 || capacity > 1000) {
      throw ArgumentError('Performance capacity must be 1..1000');
    }
  }
  final int Function() clockMicros;
  final int capacity;
  final _timings = <String, _Timing>{};
  final _painted = <int, bool>{};
  int? _activeSince, _lastDelivery;
  int _activeMicros = 0, _deliveries = 0, _stale = 0, _expiries = 0;
  void resume() {
    _activeSince ??= clockMicros();
  }

  void pause() {
    final since = _activeSince;
    if (since != null) {
      final elapsed = clockMicros() - since;
      if (elapsed > 0) _activeMicros += elapsed;
    }
    _activeSince = null;
    _painted.clear();
  }

  void _sample(String stage, int micros) {
    if (micros >= 0) (_timings[stage] ??= _Timing(capacity)).add(micros);
  }

  void delivered(int timestamp) {
    if (_activeSince == null ||
        _lastDelivery != null && timestamp <= _lastDelivery!) {
      return;
    }
    final age = clockMicros() - timestamp;
    if (timestamp < 0 || age < 0) return;
    _lastDelivery = timestamp;
    if (age > 250000) {
      _stale++;
      return;
    }
    _deliveries++;
    _sample('inputToDeliveryMicros', age);
    _painted[timestamp] = false;
    if (_painted.length > capacity) _painted.remove(_painted.keys.first);
  }

  void painted(int timestamp) {
    if (_activeSince == null || _painted[timestamp] != false) return;
    final age = clockMicros() - timestamp;
    if (age < 0) return;
    _painted[timestamp] = true;
    if (age > 250000) {
      _stale++;
      return;
    }
    _sample('inputToFirstCpuPaintMicros', age);
  }

  void analyzed(int runtimeMicros) {
    if (_activeSince != null) _sample('squatAnalysisMicros', runtimeMicros);
  }

  void frameExpired() {
    if (_activeSince != null) _expiries++;
  }

  Map<String, Object?> snapshot(Map<String, Object> diagnostics) {
    final since = _activeSince;
    final elapsed = since == null ? 0 : clockMicros() - since;
    final active = _activeMicros + (elapsed > 0 ? elapsed : 0);
    Object? finite(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value : null;
    final backend = diagnostics['inferenceBackend'];
    return {
      'schemaVersion': 1,
      'backend': {'cpu_2_threads', 'opencl_required'}.contains(backend)
          ? backend
          : 'unknown',
      'activeDurationMicros': active,
      'measuredDeliveries': _deliveries,
      'deliveredFps': active == 0 ? null : _deliveries * 1000000 / active,
      'staleObservations': _stale,
      'frameExpiries': _expiries,
      'timings': {for (final e in _timings.entries) e.key: e.value.summary},
      'nativeMeanMillis': finite(diagnostics['averageInferenceMillis']),
      'workerMeanMillis': finite(diagnostics['averagePipelineMillis']),
      for (final key in [
        'receivedFrames',
        'processedFrames',
        'droppedFrames',
        'staleFrames',
        'measuredFrames'
      ])
        key: finite(diagnostics[key]),
      'inputTimestampBoundary': 'after_camera_plane_copy',
      'deliveryBoundary': 'refined_callback_after_analysis',
      'paintBoundary': 'first_drawable_cpu_paint',
      'physicalCameraLatencyMeasured': false
    };
  }
}
