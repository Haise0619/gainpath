import 'dart:collection';

/// Optimization scope only. This does not change tracker/catalog eligibility.
enum WorkoutBaselineExercise {
  squat,
  bicepsCurl,
  calfRaise,
  floorPushUp,
  lateralRaise,
  shoulderPress
}

enum WorkoutMetric {
  cameraStartupMicros,
  modelStartupMicros,
  inferenceMicros,
  workerMicros,
  hostProcessingMicros,
  deliveryAgeMicros,
  acceptedDeliveryGapMicros,
  ttsInitMicros,
  eventToStartCallbackMicros,
  repToStartCallbackMicros,
  nativeRequestToStartMicros,
  routeToCameraMicros,
  routeToReadyMicros,
  rssBytes
}

enum WorkoutResource { camera, detector, tts }

enum WorkoutSignal {
  cameraFrame,
  processedFrame,
  deliveredFrame,
  replacedPending,
  staleBeforeProcessing,
  staleResult,
  invalidatedPending,
  invalidatedResult,
  audioEvent,
  outcomeEvent,
  outcomeStarted,
  audioSelected,
  audioStarted,
  audioDropped,
  audioCancelled,
  audioUnavailable,
  cameraFailure,
  modelFailure
}

class _Samples {
  int count = 0, total = 0;
  final recent = Queue<int>();
  void add(int value, int capacity) {
    count++;
    total += value;
    recent.add(value);
    if (recent.length > capacity) recent.removeFirst();
  }

  Map<String, Object> snapshot() {
    final sorted = recent.toList()..sort();
    return {
      'count': count,
      'retained': sorted.length,
      'mean': total / count,
      'recentP50': sorted[((sorted.length - 1) * .5).round()],
      'recentP95': sorted[((sorted.length - 1) * .95).round()]
    };
  }
}

class _AudioObservation {
  _AudioObservation(this.observed, this.outcome);
  final int observed;
  final bool outcome;
  int? nativeRequest;
  bool started = false;
}

/// Fixed vocabulary and bounded scalar retention. No images, pose objects,
/// user IDs, exercise document IDs, text or external keys enter snapshots.
/// All Dart values use the route clock; native deltas use only native values.
class WorkoutPerformanceDiagnostics {
  WorkoutPerformanceDiagnostics(
      {required this.exercise,
      required this.clockMicros,
      this.capacity = 300,
      this.onReport,
      this.maximumReports = 1000})
      : _started = clockMicros() {
    if (capacity < 1 || capacity > 1000 || maximumReports < 1) {
      throw ArgumentError('Invalid bounded diagnostics configuration');
    }
  }
  final WorkoutBaselineExercise exercise;
  final int Function() clockMicros;
  final int capacity, maximumReports;
  final void Function(Map<String, Object>)? onReport;
  final int _started;
  final _metrics = <WorkoutMetric, _Samples>{};
  final _signals = <WorkoutSignal, int>{};
  final _resources = <WorkoutResource, int>{};
  final _audio = <String, _AudioObservation>{};
  int? _workingSince, _lastAccepted, _prepareSince, _lastReport;
  int _workingMicros = 0, _accepted = 0, _reports = 0;
  bool _finished = false, _ready = false;
  int get pendingAudioCount => _audio.length;

  void sample(WorkoutMetric metric, int value) {
    if (_finished || value < 0) return;
    (_metrics[metric] ??= _Samples()).add(value, capacity);
  }

  void count(WorkoutSignal signal) {
    if (!_finished) _signals.update(signal, (v) => v + 1, ifAbsent: () => 1);
  }

  void setWorking(bool working) {
    if (_finished) return;
    final now = clockMicros();
    if (working) {
      _workingSince ??= now;
    } else if (_workingSince != null) {
      _workingMicros += (now - _workingSince!).clamp(0, 1 << 62);
      _workingSince = null;
      _lastAccepted = null;
    }
  }

  void accepted(int captureMicros) {
    if (_finished ||
        _workingSince == null ||
        (_lastAccepted != null && captureMicros <= _lastAccepted!)) {
      return;
    }
    final now = clockMicros();
    if (_lastAccepted != null) {
      sample(WorkoutMetric.acceptedDeliveryGapMicros,
          now - _lastAcceptedDelivery!);
    }
    _lastAccepted = captureMicros;
    _lastAcceptedDelivery = now;
    _accepted++;
    if (!_ready) {
      _ready = true;
      sample(WorkoutMetric.routeToReadyMicros, now - _started);
    }
  }

  int? _lastAcceptedDelivery;
  void resourceOpened(WorkoutResource resource) {
    if (_finished) return;
    _resources.update(resource, (v) => v + 1, ifAbsent: () => 1);
    if (resource == WorkoutResource.camera) {
      sample(WorkoutMetric.routeToCameraMicros, clockMicros() - _started);
    }
  }

  void resourceClosed(WorkoutResource resource) {
    if (_finished) return;
    _resources[resource] = ((_resources[resource] ?? 0) - 1).clamp(0, 1 << 30);
    report(force: true);
  }

  void discarded(String reason) {
    final signal = switch (reason) {
      'replaced_pending' => WorkoutSignal.replacedPending,
      'stale_before_processing' => WorkoutSignal.staleBeforeProcessing,
      'stale_result' => WorkoutSignal.staleResult,
      'generation_invalidated_pending' => WorkoutSignal.invalidatedPending,
      'generation_invalidated_result' => WorkoutSignal.invalidatedResult,
      _ => null,
    };
    if (signal != null) count(signal);
  }

  /// Consumes the existing bounded trace. Request IDs are transient correlation
  /// keys only, never reported. Unknown stage names/data are ignored.
  void audio(Map<String, Object?> row) {
    if (_finished) return;
    final stage = row['stage'], at = row['dartElapsedMicros'];
    if (at is! int || at < 0) return;
    if (stage == 'tts_prepare_requested') {
      _prepareSince = at;
      return;
    }
    if (stage == 'tts_prepare_completed') {
      if (_prepareSince != null) {
        sample(WorkoutMetric.ttsInitMicros, at - _prepareSince!);
      }
      _prepareSince = null;
      return;
    }
    final id = row['requestId'];
    if (id is! String || id.length > 160) return;
    if (stage == 'exercise_event_generated') {
      final observed = row['observedAtMicros'];
      if (observed is! int || observed < 0 || observed > at) return;
      if (_audio.containsKey(id)) return;
      if (_audio.length >= 64) _audio.remove(_audio.keys.first);
      final outcome = const {
        'squat_rep',
        'squat_depth',
        'curl_rep',
        'curl_partial',
        'calf_rep',
        'calf_partial',
        'floor_good',
        'floor_depth',
        'floor_extension',
        'lateral_raise_rep',
        'lateral_raise_partial',
        'shoulder_press_rep',
        'shoulder_press_partial',
        'workout_set_complete'
      }.contains(row['cueId']);
      _audio[id] = _AudioObservation(observed, outcome);
      count(WorkoutSignal.audioEvent);
      if (outcome) count(WorkoutSignal.outcomeEvent);
      return;
    }
    final event = _audio[id];
    if (event == null) return;
    if (stage == 'arbitration_selected') count(WorkoutSignal.audioSelected);
    if (stage == 'native_tts_request' && row['nativeElapsedMicros'] is int) {
      event.nativeRequest = row['nativeElapsedMicros'] as int;
    }
    if (stage == 'playback_start' && !event.started) {
      event.started = true;
      count(WorkoutSignal.audioStarted);
      sample(WorkoutMetric.eventToStartCallbackMicros, at - event.observed);
      if (event.outcome) {
        count(WorkoutSignal.outcomeStarted);
        sample(WorkoutMetric.repToStartCallbackMicros, at - event.observed);
      }
      final native = row['nativeElapsedMicros'];
      if (native is int && event.nativeRequest != null) {
        sample(WorkoutMetric.nativeRequestToStartMicros,
            native - event.nativeRequest!);
      }
    }
    final outcome = switch (stage) {
      'dropped' when row['reason'] == 'tts_unavailable' =>
        WorkoutSignal.audioUnavailable,
      'dropped' || 'expired_before_start' => WorkoutSignal.audioDropped,
      'cancelled' || 'playback_cancelled' => WorkoutSignal.audioCancelled,
      'playback_unavailable' => WorkoutSignal.audioUnavailable,
      'playback_result' when row['reason'] == 'unavailable' =>
        WorkoutSignal.audioUnavailable,
      'playback_result' when row['reason'] == 'cancelled' =>
        WorkoutSignal.audioCancelled,
      _ => null,
    };
    if (outcome != null) {
      count(outcome);
      _audio.remove(id);
    }
    if (stage == 'playback_completed' || stage == 'playback_result') {
      _audio.remove(id);
    }
  }

  Map<String, Object> snapshot() {
    final working = _workingMicros +
        (_workingSince == null
            ? 0
            : (clockMicros() - _workingSince!).clamp(0, 1 << 62));
    return {
      'schemaVersion': 1,
      'exercise': exercise.name,
      'acceptedFrames': _accepted,
      'workingMicros': working,
      'acceptedFps': working == 0 ? 0.0 : _accepted * 1000000 / working,
      'metrics': {
        for (final e in _metrics.entries) e.key.name: e.value.snapshot()
      },
      'counters': {for (final e in _signals.entries) e.key.name: e.value},
      'resources': {
        for (final r in WorkoutResource.values) r.name: _resources[r] ?? 0
      }
    };
  }

  void report({bool force = false}) {
    if (_finished || onReport == null || _reports >= maximumReports) return;
    final now = clockMicros();
    if (!force && _lastReport != null && now - _lastReport! < 5000000) return;
    _lastReport = now;
    _reports++;
    // Observation must not cause a workout failure even when its sink fails.
    try {
      onReport!(snapshot());
    } catch (_) {/* Local diagnostics only. */}
  }

  void finish() {
    if (_finished) return;
    setWorking(false);
    report(force: true);
    _audio.clear();
    _finished = true;
  }
}
