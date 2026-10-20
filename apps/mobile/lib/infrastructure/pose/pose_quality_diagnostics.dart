import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'pose_joint_lag_diagnostics.dart';
import 'pose_overlay_blank_diagnostics.dart';

// Observation only: this define changes no inference/scheduling parameters.
const poseQualityDebugEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG');
const poseBlankDebugEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_POSE_BLANK_DEBUG');

class _Samples {
  int count = 0, total = 0;
  final recent = Queue<int>();
  void add(int micros) {
    count++;
    total += micros;
    recent.add(micros);
    if (recent.length > 300) recent.removeFirst();
  }

  Map<String, Object> get summary {
    final sorted = recent.toList()..sort();
    double percentile(double p) =>
        sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()] / 1000;
    return {
      ...meanSummary,
      'recentP50Millis': percentile(.5),
      'recentP95Millis': percentile(.95)
    };
  }

  Map<String, Object> get meanSummary =>
      {'count': count, 'meanMillis': count == 0 ? 0.0 : total / count / 1000};
}

/// Bounded local development telemetry. All ages use the same route clock.
/// The camera plugin supplies no exposure timestamp or display-present fence.
class PoseQualityDiagnostics {
  PoseQualityDiagnostics(
      {required this.clockMicros,
      this.enabled = poseQualityDebugEnabled,
      bool blankEnabled = poseBlankDebugEnabled})
      : _blankEnabled = blankEnabled {
    if (enabled) transition('session_created');
  }
  final int Function() clockMicros;
  final bool _blankEnabled;
  late final blanks = PoseOverlayBlankDiagnostics(
      enabled: enabled && _blankEnabled,
      clockMicros: clockMicros,
      onReport: printOverlayBlankReport);
  late final lag = PoseJointLagDiagnostics(
      enabled: enabled && poseJointLagDebugEnabled,
      clockMicros: clockMicros,
      onReport: (report) {
        blanks.finish();
        printJointLagReport(report);
      });
  final bool enabled;
  final sessionId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final _samples = <String, _Samples>{};
  final _counters = <String, int>{};
  final _cameraCallbacks = <int, int>{};
  final _frameTraces = <int, Map<String, Object?>>{};
  String state = 'uninitialized';
  Map<String, Object?> lastFrame = {};
  Map<String, Object?> lastPaint = {};
  Map<String, Object?> lastDiscard = {};
  Map<String, Object?> viewport = {};
  int? _lastPaintTimestamp;
  final _deliveryContexts = <int, Map<String, Object?>>{};
  Map<String, Object?> _lastOverlayContext = {};
  Map<String, Object?>? _clearPaintContext;
  int? _lastValidInput, _lastValidDelivery, _lastValidPaint;
  String _blankCause = 'initial_no_pose';

  Map<String, Object?> traceFor(int timestamp) =>
      Map.of(_frameTraces[timestamp] ?? const <String, Object?>{});

  void startCapture(String name) {
    blanks.start(name, sessionId: sessionId);
    lag.start(name);
  }

  Map<String, Object?> _ageContext() => {
        'lastValidInputMicros': _lastValidInput,
        'lastValidDeliveryMicros': _lastValidDelivery,
        'lastValidPaintMicros': _lastValidPaint,
        'lastValidPoseAgeMicros':
            _lastValidInput == null ? null : clockMicros() - _lastValidInput!,
        'latestDiscardReason': lastDiscard['reason'],
        'latestDiscardInputMicros': lastDiscard['timestampMicros'],
        'latestDiscardObservedMicros': lastDiscard['observedAtMicros'],
      };

  Map<String, Object?> _poseCounts(PoseFrame frame) {
    var visible = 0,
        accepted = 0,
        visibilityRejected = 0,
        presenceRejected = 0,
        nonfinite = 0;
    for (final p in frame.landmarks.values) {
      if (![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
          .every((v) => v.isFinite)) {
        nonfinite++;
      } else if (p.visibility < .5) {
        visibilityRejected++;
      } else {
        visible++;
        if ((p.presence ?? 1) < .5) {
          presenceRejected++;
        } else {
          accepted++;
        }
      }
    }
    return {
      'filteredCount': frame.landmarks.length,
      'visibleCount': visible,
      'acceptedCount': accepted,
      'visibilityRejectedCount': visibilityRejected,
      'presenceRejectedCount': presenceRejected,
      'nonfiniteCount': nonfinite
    };
  }

  String _reasonFor(PoseFrame frame, Map trace, Map counts) =>
      frame.landmarks.isEmpty
          ? trace['outcome'] as String? ?? 'adapter_empty_unspecified'
          : (counts['nonfiniteCount'] as int) == frame.landmarks.length
              ? 'nonfinite_landmarks'
              : counts['visibleCount'] == 0
                  ? 'landmark_visibility_rejection'
                  : counts['acceptedCount'] == 0
                      ? 'landmark_joint_presence_rejection'
                      : 'pose';

  void overlayCleared(String reason, PoseFrame? previous,
      {bool watchdog = false, int? inputTimestamp}) {
    if (!blanks.enabled) return;
    // Removing an already empty/rejected result is not a new visible loss.
    if (watchdog &&
        (previous == null || _poseCounts(previous)['acceptedCount'] == 0)) {
      return;
    }
    _blankCause = reason;
    final previousContext = previous == null
        ? _lastOverlayContext
        : _deliveryContexts[previous.capturedAtMicros] ?? <String, Object?>{};
    final trace = inputTimestamp == null
        ? const <String, Object?>{}
        : traceFor(inputTimestamp);
    final context = inputTimestamp == null
        ? previousContext
        : <String, Object?>{
            'inputMicros': inputTimestamp,
            'deliveryMicros': null,
            'resultReceivedMicros': trace['resultReceivedMicros'],
            'traceMatched': trace.isNotEmpty,
            'refinedCount': trace['landmarkCount'],
            for (final key in [
              'outcome',
              'posePresence',
              'roiSource',
              'detectorRan',
              'detectorPersonConfidence',
              'lastDetectorConfidence',
              'lastDetectorTimestampMicros'
            ])
              key: trace[key]
          };
    _clearPaintContext = context;
    blanks.reportState(visible: false, reason: reason, context: {
      ...context,
      ..._ageContext(),
      'watchdogClearedValidPose': watchdog &&
          previous != null &&
          _poseCounts(previous)['acceptedCount'] != 0
    });
  }

  void overlayPainted(PoseFrame? frame,
      {String? reason,
      PoseFrame? sourceFrame,
      required int primitivesIssued,
      required int viewportIntersectingPrimitives}) {
    if (!blanks.enabled) return;
    final diagnosticTimer = Stopwatch()..start();
    final source = sourceFrame ?? frame;
    final context = source == null
        ? _clearPaintContext ?? _lastOverlayContext
        : _deliveryContexts[source.capturedAtMicros] ??
            <String, Object?>{
              'inputMicros': source.capturedAtMicros,
              'traceMatched': false,
              ..._poseCounts(source)
            };
    final visible = frame != null && viewportIntersectingPrimitives > 0;
    final counts =
        source == null ? const <String, Object?>{} : _poseCounts(source);
    final paintReason = reason ??
        (frame == null
            ? _blankCause
            : frame.landmarks.isEmpty
                ? _blankCause
                : counts['acceptedCount'] == 0
                    ? _reasonFor(
                        frame, traceFor(frame.capturedAtMicros), counts)
                    : 'renderer_off_viewport');
    blanks.painted(
        visible: visible,
        reason: visible ? 'pose' : paintReason,
        context: {
          ...context,
          ...counts,
          ..._ageContext(),
          'rendererRejectedAll': frame != null &&
              frame.landmarks.isNotEmpty &&
              counts['acceptedCount'] == 0,
          'primitivesIssued': primitivesIssued,
          'viewportIntersectingPrimitives': viewportIntersectingPrimitives,
          'aspectCompatible': viewport['aspectCompatible'],
          'canvasWidth': lastPaint['canvasWidth'],
          'canvasHeight': lastPaint['canvasHeight']
        });
    if (visible && frame.capturedAtMicros == _lastValidInput) {
      _lastValidPaint = clockMicros();
    }
    sample('blankPaintObservationMicros', diagnosticTimer.elapsedMicroseconds);
  }

  int _previousReceived = 0,
      _previousProcessed = 0,
      _previousDelivered = 0,
      _previousDrawable = 0,
      _previousActiveMicros = 0;

  void sample(String name, int micros) {
    if (enabled) (_samples[name] ??= _Samples()).add(micros);
  }

  void count(String reason) {
    if (enabled) _counters.update(reason, (v) => v + 1, ifAbsent: () => 1);
  }

  void cameraCallback(int frameTimestamp, int callbackTimestamp) {
    if (!enabled) return;
    _cameraCallbacks[frameTimestamp] = callbackTimestamp;
    if (_cameraCallbacks.length > 240) {
      _cameraCallbacks.remove(_cameraCallbacks.keys.first);
    }
    sample('cameraCopyMicros', frameTimestamp - callbackTimestamp);
  }

  int callbackAge(int frameTimestamp) =>
      clockMicros() - (_cameraCallbacks[frameTimestamp] ?? frameTimestamp);

  void workerFrame(Map<String, Object?> trace) {
    if (!enabled) return;
    if (lag.enabled || blanks.enabled) {
      trace['resultReceivedMicros'] = clockMicros();
    }
    lastFrame = trace;
    _frameTraces[trace['frameTimestampMicros'] as int] = trace;
    if (_frameTraces.length > 64) {
      _frameTraces.remove(_frameTraces.keys.first);
    }
    count('worker_${trace['outcome']}');
    for (final entry in (trace['timings'] as Map).entries) {
      sample(entry.key as String, entry.value as int);
    }
  }

  void discard(int timestamp, String reason) {
    if (!enabled) return;
    count(reason);
    lastDiscard = {
      'timestampMicros': timestamp,
      'reason': reason,
      'observedAtMicros': clockMicros()
    };
    if (reason != 'replaced_pending') {
      final trace = traceFor(timestamp);
      blanks.recordDiscard(reason, context: {
        'inputMicros': timestamp,
        'resultReceivedMicros': trace['resultReceivedMicros'],
        'outcome': trace['outcome'],
        'traceMatched': trace.isNotEmpty,
        ..._ageContext()
      });
    }
  }

  void transition(String reason,
      {int? timestamp, Map<String, Object?> details = const {}}) {
    if (!enabled || reason == state) return;
    final previous = state;
    state = reason;
    debugPrint('POSE_QUALITY_EVENT ${jsonEncode({
          'sessionId': sessionId,
          'atMicros': clockMicros(),
          'frameTimestampMicros': timestamp,
          'from': previous,
          'to': reason,
          ...details
        })}');
  }

  void delivered(PoseFrame frame, int filterMicros, {PoseFrame? refined}) {
    if (!enabled) return;
    sample('filterMicros', filterMicros);
    sample('uiDeliveryAgeMicros', clockMicros() - frame.capturedAtMicros);
    sample('callbackToUiMicros', callbackAge(frame.capturedAtMicros));
    final matchedTrace = traceFor(frame.capturedAtMicros);
    if (blanks.enabled) {
      final diagnosticTimer = Stopwatch()..start();
      final counts = _poseCounts(frame);
      final context = <String, Object?>{
        'inputMicros': frame.capturedAtMicros,
        'deliveryMicros': clockMicros(),
        'resultReceivedMicros': matchedTrace['resultReceivedMicros'],
        'traceMatched': matchedTrace.isNotEmpty,
        'refinedCount': refined?.landmarks.length,
        'validRefinedFrameExisted': refined?.landmarks.isNotEmpty == true,
        'posePresence': frame.posePresence,
        ...counts,
        for (final key in [
          'outcome',
          'detectorRan',
          'roiSource',
          'nextRoiState',
          'detectorPersonConfidence',
          'lastDetectorConfidence',
          'lastDetectorTimestampMicros'
        ])
          key: matchedTrace[key]
      };
      _deliveryContexts[frame.capturedAtMicros] = context;
      if (_deliveryContexts.length > 64) {
        _deliveryContexts.remove(_deliveryContexts.keys.first);
      }
      _lastOverlayContext = context;
      _clearPaintContext = null;
      final visible = (counts['acceptedCount'] as int) > 0;
      _blankCause = _reasonFor(frame, matchedTrace, counts);
      blanks.reportState(
          visible: visible,
          reason: _blankCause,
          context: {...context, ..._ageContext()});
      if (visible) {
        _lastValidInput = frame.capturedAtMicros;
        _lastValidDelivery = clockMicros();
      }
      sample('blankDeliveryObservationMicros',
          diagnosticTimer.elapsedMicroseconds);
    }
    if (frame.landmarks.isEmpty) {
      count('emptyPose');
      final reason = matchedTrace.isNotEmpty
          ? matchedTrace['outcome'] as String
          : 'adapter_empty_unspecified';
      transition(reason,
          timestamp: frame.capturedAtMicros,
          details: {'posePresence': frame.posePresence});
    } else {
      final visible =
          frame.landmarks.values.where((p) => p.visibility >= .5).length;
      final accepted = frame.landmarks.values
          .where((p) => p.visibility >= .5 && (p.presence ?? 1) >= .5)
          .length;
      final reason = visible == 0
          ? 'landmark_visibility_rejection'
          : accepted == 0
              ? 'landmark_joint_presence_rejection'
              : 'pose';
      count('nonEmptyDelivered');
      if (accepted > 0) count('drawableDelivered');
      transition(reason, timestamp: frame.capturedAtMicros, details: {
        'accepted': accepted,
        'count': frame.landmarks.length,
        'posePresence': frame.posePresence
      });
    }
  }

  void painted(PoseFrame? frame, double width, double height, bool mirrored) {
    if (!enabled) return;
    lastPaint = {
      'timestampMicros': frame?.capturedAtMicros,
      'canvasWidth': width,
      'canvasHeight': height,
      'mirrored': mirrored,
      'ageMillis':
          frame == null ? null : callbackAge(frame.capturedAtMicros) / 1000
    };
    if (frame == null || frame.capturedAtMicros == _lastPaintTimestamp) return;
    _lastPaintTimestamp = frame.capturedAtMicros;
    count('uniquePaintedFrames');
    sample('poseAgeWhenPaintedMicros', clockMicros() - frame.capturedAtMicros);
    sample('callbackToPaintMicros', callbackAge(frame.capturedAtMicros));
  }

  Map<String, Object?> snapshot(
      {required int activeMicros,
      required int received,
      required int processed,
      required int delivered}) {
    final delta = activeMicros - _previousActiveMicros;
    double rate(int n) => delta <= 0 ? 0 : n * 1000000 / delta;
    final result = <String, Object?>{
      'sessionId': sessionId,
      'state': state,
      'timings': {for (final e in _samples.entries) e.key: e.value.summary},
      'counters': Map<String, int>.of(_counters),
      'intervalFps': {
        'cameraReceived': rate(received - _previousReceived),
        'processed': rate(processed - _previousProcessed),
        'deliveredOverlay': rate(delivered - _previousDelivered),
        'drawableOverlay':
            rate((_counters['drawableDelivered'] ?? 0) - _previousDrawable)
      },
      'lastFrame': lastFrame,
      'lastPaint': lastPaint,
      'lastDiscard': lastDiscard,
      'sensorExposureTimestampAvailable': false,
      'displayPresentTimestampAvailable': false,
      'cameraToDisplayMillis': null
    };
    _previousActiveMicros = activeMicros;
    _previousReceived = received;
    _previousProcessed = processed;
    _previousDelivered = delivered;
    _previousDrawable = _counters['drawableDelivered'] ?? 0;
    return result;
  }

  Map<String, Object?> get countersSnapshot => {
        'sessionId': sessionId,
        'state': state,
        'timings': {
          for (final e in _samples.entries) e.key: e.value.meanSummary
        },
        'counters': Map<String, int>.of(_counters)
      };
  void clearCoordinates() {
    blanks.finish();
    lag.clear();
    lastFrame = {};
    lastPaint = {};
    viewport = {};
    _cameraCallbacks.clear();
    _frameTraces.clear();
    _deliveryContexts.clear();
    _lastOverlayContext = {};
    _clearPaintContext = null;
  }
}

void printPoseQualitySnapshot(
    PoseQualityDiagnostics quality, Map<String, Object?> snapshot) {
  if (!quality.enabled) return;
  Object? concise(Object? value) {
    if (value is double) {
      return value.isFinite ? double.parse(value.toStringAsFixed(4)) : null;
    }
    if (value is Map) return value.map((k, v) => MapEntry(k, concise(v)));
    if (value is Iterable) return value.map(concise).toList();
    return value;
  }

  void line(String stage, Object? value) =>
      debugPrint('POSE_QUALITY_$stage ${jsonEncode(concise(value))}');
  final frame = snapshot['lastFrame'] as Map;
  line('RATE',
      {'sessionId': quality.sessionId, 'intervalFps': snapshot['intervalFps']});
  for (final e in (snapshot['timings'] as Map).entries) {
    line('TIMING',
        {'sessionId': quality.sessionId, 'stage': e.key, 'summary': e.value});
  }
  line('HEALTH', {
    'sessionId': quality.sessionId,
    'state': snapshot['state'],
    'frameTimestampMicros': frame['frameTimestampMicros'],
    'detectorRan': frame['detectorRan'],
    'roiSource': frame['roiSource'],
    'detectorPersonConfidence': frame['detectorPersonConfidence'],
    'lastDetectorConfidence': frame['lastDetectorConfidence'],
    'lastDetectorTimestampMicros': frame['lastDetectorTimestampMicros'],
    'posePresence': frame['posePresence'],
    'outcome': frame['outcome'],
    'nextRoiState': frame['nextRoiState']
  });
  line('COUNT',
      {'sessionId': quality.sessionId, 'counters': snapshot['counters']});
  line('DISCARD', {'sessionId': quality.sessionId, ...quality.lastDiscard});
  line('PAINT', {
    'sessionId': quality.sessionId,
    ...Map.of(quality.lastPaint)..remove('joints')
  });
  line('VIEWPORT', {'sessionId': quality.sessionId, ...quality.viewport});
  // Step 2D uses fixed representative snapshots after bounded phases instead
  // of a periodic landmark-coordinate log.
  if (poseJointLagDebugEnabled) return;
  // Compare coordinates from the exact frame actually sent to paint.
  final paintTimestamp = quality.lastPaint['timestampMicros'];
  final paintedTrace = quality._frameTraces[paintTimestamp] ?? {};
  final projection = paintedTrace['projection'] as Map? ?? {};
  line('ROI', {
    'sessionId': quality.sessionId,
    'timestampMicros': projection['timestampMicros'],
    'roi': projection['roi']
  });
  final raw = projection['rawRepresentatives'] as Map? ?? {},
      image = (projection['imageBeforeFilter'] as Map? ?? {})['representatives']
              as Map? ??
          {},
      painted = quality.lastPaint['joints'] as Map? ?? {};
  for (final joint in raw.keys) {
    line('JOINT', {
      'sessionId': quality.sessionId,
      'joint': joint,
      'modelTimestamp': paintedTrace['frameTimestampMicros'],
      'paintTimestamp': quality.lastPaint['timestampMicros'],
      'raw': raw[joint],
      'imageBeforeFilter': image[joint],
      'painted': painted[joint]
    });
  }
}

/// Bounded phase summaries and blank episodes only; no coordinate stream.
void printOverlayBlankReport(Map<String, Object?> report) {
  void line(String stage, Map<String, Object?> payload, int record) {
    final encoded = jsonEncode(payload);
    final direct = 'POSE_BLANK_$stage $encoded';
    if (utf8.encode(direct).length <= 900) {
      debugPrint(direct);
      return;
    }
    // JSON transport chunks remain below Android profile's 1023-byte limit.
    // Sanitized recorder metadata is scalar; rune-wise split avoids UTF-8 cuts.
    final parts = <String>[];
    var text = StringBuffer(), bytes = 0;
    for (final rune in encoded.runes) {
      final char = String.fromCharCode(rune);
      final cost = utf8.encode(jsonEncode(char)).length - 2;
      if (bytes + cost > 450) {
        parts.add(text.toString());
        text = StringBuffer();
        bytes = 0;
      }
      text.write(char);
      bytes += cost;
    }
    if (text.isNotEmpty) parts.add(text.toString());
    for (var i = 0; i < parts.length; i++) {
      debugPrint('POSE_BLANK_CHUNK ${jsonEncode({
            'captureToken': report['captureToken'],
            'stage': stage,
            'record': record,
            'part': i,
            'parts': parts.length,
            'data': parts[i]
          })}');
    }
  }

  final header = Map<String, Object?>.of(report)..remove('events');
  line('SUMMARY', header, 0);
  var record = 1;
  for (final event in report['events'] as List? ?? []) {
    line(
        'EVENT',
        {
          'captureToken': report['captureToken'],
          'sessionId': report['sessionId'],
          'phase': report['phase'],
          ...Map<String, Object?>.from(event as Map)
        },
        record++);
  }
}
