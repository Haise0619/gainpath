import 'dart:math' as math;

/// Bounded, observation-only metadata for logical and CPU-painted blank episodes.
///
/// Valid delivery alone never proves recovery. Only a matching visible paint
/// closes an episode. A discarded inference result never clears an overlay here.
/// This class retains neither images nor landmark coordinates and emits no
/// per-frame stream. All state and reports belong to a single bounded capture.
class PoseOverlayBlankDiagnostics {
  PoseOverlayBlankDiagnostics({
    required this.enabled,
    required this.clockMicros,
    int maxEvents = 128,
    this.onReport,
  }) : maxEvents = maxEvents.clamp(0, 128);

  final bool enabled;
  final int Function() clockMicros;
  final int maxEvents;
  final void Function(Map<String, Object?> report)? onReport;
  String? phase;
  String? sessionId;
  String? captureToken;
  int? latestEpisodeId;
  String? latestReason;
  bool overlayBlank = false;
  final _events = <Map<String, Object?>>[];
  final _reasonCounts = <String, int>{};
  Map<String, Object?> _causeContext = {};
  bool _latestStateVisible = false;
  int? _latestStateInputMicros;
  int _started = 0, _duration = 0, _captureSequence = 0;
  int _blankStarted = 0;
  int? _firstBlankPaint;
  int _episodes = 0, _confirmed = 0, _recovered = 0, _discards = 0;
  int _dropped = 0, _ignoredVisiblePaints = 0;
  int _stateObservations = 0, _paintObservations = 0;
  int get retainedEvents => _events.length;
  Map<String, Object?> lastReport = {};
  double get remainingSeconds => phase == null
      ? 0
      : math.max(0, (_duration - (clockMicros() - _started)) / 1e6);

  void start(String name,
      {required String sessionId, int durationMicros = 20000000}) {
    if (!enabled) return;
    clear();
    _started = clockMicros();
    _duration = durationMicros.clamp(1, 20000000);
    phase = _boundedText(name);
    this.sessionId = _boundedText(sessionId);
    captureToken = '${this.sessionId}:$_started:${++_captureSequence}';
  }

  /// Observe a delivery/clear decision, independently from actual CPU paint.
  void reportState(
      {required bool visible,
      required String reason,
      Map<String, Object?> context = const {}}) {
    if (!_active()) return;
    _stateObservations++;
    _latestStateVisible = visible;
    _latestStateInputMicros = _input(context);
    if (!visible) _blank(reason, context);
  }

  /// Observe whether the painter issued any accepted, viewport-visible primitive.
  /// A lifecycle clear or obsolete paint cannot falsely recover a newer blank.
  void painted(
      {required bool visible,
      required String reason,
      Map<String, Object?> context = const {}}) {
    if (!_active()) return;
    _paintObservations++;
    if (!visible) {
      _blank(reason, context);
      if (_firstBlankPaint == null) {
        _firstBlankPaint = clockMicros();
        _confirmed++;
        _event('blank_paint', latestReason!, {
          ..._causeContext,
          ..._metadata(context),
          'causeInputMicros': _causeContext['inputMicros'],
          'causeDeliveryMicros': _causeContext['deliveryMicros'],
          'firstBlankPaintMicros': _firstBlankPaint,
        });
      }
      return;
    }
    final paintedInput = _input(context);
    if (!_latestStateVisible ||
        (_latestStateInputMicros != null &&
            paintedInput != null &&
            _latestStateInputMicros != paintedInput)) {
      _ignoredVisiblePaints++;
      return;
    }
    if (!overlayBlank) return;
    _recovered++;
    _event('recovery', latestReason!, {
      ..._metadata(context),
      'recoveryReason': _boundedText(reason),
      'blankBeganMicros': _blankStarted,
      'firstBlankPaintMicros': _firstBlankPaint,
      'blankDurationMicros': math.max(0, clockMicros() - _blankStarted),
      'blankWasPainted': _firstBlankPaint != null,
    });
    overlayBlank = false;
    _firstBlankPaint = null;
    _causeContext = {};
  }

  /// Noncausal observation. Does not open, confirm, or recover an episode.
  void recordDiscard(String reason, {Map<String, Object?> context = const {}}) {
    if (!_active()) return;
    _discards++;
    _event('discard', _boundedText(reason), {
      ..._metadata(context),
      'causalOverlayClear': false,
    });
  }

  bool finishIfExpired() {
    if (!enabled || phase == null || clockMicros() - _started < _duration) {
      return false;
    }
    finish();
    return true;
  }

  Map<String, Object?> finish() {
    if (!enabled || phase == null) return {};
    final report = <String, Object?>{
      'schemaVersion': 1,
      'phase': phase,
      'sessionId': sessionId,
      'captureToken': captureToken,
      'startedMicros': _started,
      'durationMicros': math.max(0, clockMicros() - _started),
      'captureLimitMicros': _duration,
      'eventLimit': maxEvents,
      'retainedEvents': _events.length,
      'capacityReached': _dropped > 0,
      'droppedEvents': _dropped,
      'blankEpisodes': _episodes,
      'confirmedBlankEpisodes': _confirmed,
      'recoveredEpisodes': _recovered,
      'openEpisodeAtCaptureEnd': overlayBlank ? latestEpisodeId : null,
      'stateObservations': _stateObservations,
      'paintObservations': _paintObservations,
      'ignoredVisiblePaints': _ignoredVisiblePaints,
      'discards': _discards,
      'reasonCounts': Map<String, int>.of(_reasonCounts),
      'events': [for (final event in _events) Map<String, Object?>.of(event)],
      'boundary':
          'logical cause / first blank CPU paint / visible CPU recovery; '
              'no exposure or physical display presentation timing',
    };
    phase = null;
    _events.clear();
    _reasonCounts.clear();
    _causeContext = {};
    lastReport = report;
    onReport?.call(report);
    return report;
  }

  void clear() {
    phase = null;
    sessionId = null;
    captureToken = null;
    latestEpisodeId = null;
    latestReason = null;
    overlayBlank = false;
    _events.clear();
    _reasonCounts.clear();
    _causeContext = {};
    _latestStateVisible = false;
    _latestStateInputMicros = null;
    _started = _duration = _blankStarted = 0;
    _firstBlankPaint = null;
    _episodes = _confirmed = _recovered = _discards = 0;
    _dropped = _ignoredVisiblePaints = 0;
    _stateObservations = _paintObservations = 0;
    lastReport = {};
  }

  bool _active() {
    if (!enabled || phase == null) return false;
    finishIfExpired();
    return phase != null;
  }

  void _blank(String reason, Map<String, Object?> context) {
    final boundedReason = _boundedText(reason);
    if (overlayBlank && boundedReason == latestReason) return;
    final beginning = !overlayBlank;
    if (beginning) {
      overlayBlank = true;
      latestEpisodeId = ++_episodes;
      _blankStarted = clockMicros();
      _firstBlankPaint = null;
    }
    latestReason = boundedReason;
    _causeContext = _metadata(context);
    // Caller reason strings cannot make an unbounded map under malformed input.
    final counterKey =
        _reasonCounts.containsKey(boundedReason) || _reasonCounts.length < 63
            ? boundedReason
            : 'other_reasons';
    _reasonCounts.update(counterKey, (v) => v + 1, ifAbsent: () => 1);
    _event(beginning ? 'blank_begin' : 'cause_change', boundedReason,
        _causeContext);
  }

  void _event(String kind, String reason, Map<String, Object?> context) {
    if (_events.length >= maxEvents) {
      _dropped++;
      return;
    }
    _events.add({
      ...context,
      'kind': kind,
      'episodeId': latestEpisodeId,
      'reason': reason,
      'observedMicros': clockMicros(),
    });
  }

  static int? _input(Map<String, Object?> context) =>
      context['inputMicros'] is int ? context['inputMicros'] as int : null;

  static String _boundedText(String value) =>
      value.length <= 128 ? value : value.substring(0, 128);

  static Map<String, Object?> _metadata(Map<String, Object?> context) => {
        for (final entry in context.entries)
          if (_contextKeys.contains(entry.key) &&
              (entry.value == null ||
                  entry.value is num ||
                  entry.value is bool ||
                  entry.value is String))
            entry.key:
                entry.value is double && !(entry.value as double).isFinite
                    ? null
                    : entry.value is String
                        ? _boundedText(entry.value as String)
                        : entry.value,
      };

  static const _contextKeys = {
    'inputMicros',
    'deliveryMicros',
    'resultReceivedMicros',
    'observedAtMicros',
    'lastValidInputMicros',
    'lastValidDeliveryMicros',
    'lastValidPaintMicros',
    'lastValidPoseAgeMicros',
    'detectorPersonConfidence',
    'lastDetectorConfidence',
    'lastDetectorTimestampMicros',
    'posePresence',
    'roiSource',
    'detectorRan',
    'nextRoiState',
    'outcome',
    'traceMatched',
    'refinedCount',
    'validRefinedFrameExisted',
    'filteredCount',
    'visibleCount',
    'acceptedCount',
    'visibilityRejectedCount',
    'presenceRejectedCount',
    'nonfiniteCount',
    'rendererRejectedAll',
    'primitivesIssued',
    'viewportIntersectingPrimitives',
    'watchdogClearedValidPose',
    'phase',
    'wasEmpty',
    'latestDiscardReason',
    'latestDiscardInputMicros',
    'latestDiscardObservedMicros',
    'canvasWidth',
    'canvasHeight',
    'aspectCompatible',
  };
}
