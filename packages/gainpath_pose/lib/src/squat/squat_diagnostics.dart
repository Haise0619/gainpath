import 'dart:collection';
import 'dart:math' as math;
import 'squat_geometry.dart';
import 'squat_rule_set.dart';
import 'squat_world_geometry.dart';
import '../pose/pose_stream.dart';
import '../pose/one_euro_filter.dart';

enum SquatDiagnosticReason {
  confirmedDepth,
  depthAngleNotReached,
  depthDwellNotConfirmed,
  paused,
  backgrounded,
  sessionClosed,
  frameGap,
  geometryChanged,
  watchdogStale,
  trackingLost,
  recoveryDiscontinuity,
  cycleTimeout,
  tooShortCycle,
  recalibration,
  sideChanged;

  String get wire =>
      name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

final class SquatDiagnosticRecord {
  SquatDiagnosticRecord._(this.sequence, Map<String, Object?> values)
      : _values = Map.unmodifiable(values);
  final int sequence;
  final Map<String, Object?> _values;
  Map<String, Object?> toJson() => _copyScalars(_values);
}

Map<String, Object?> _copyScalars(Map<String, Object?> values) =>
    values.map((key, value) => MapEntry(
        key, value is Map<String, Object?> ? _copyScalars(value) : value));

class _AngleTotals {
  int count = 0;
  double sum = 0, min = 180, max = 0;
  void add(double? angle) {
    if (angle == null || !angle.isFinite || angle < 0 || angle > 180) return;
    count++;
    sum += angle;
    min = math.min(min, angle);
    max = math.max(max, angle);
  }

  Map<String, Object?> get summary => {
        'count': count,
        'minimumDegrees': count == 0 ? null : min,
        'maximumDegrees': count == 0 ? null : max,
        'meanDegrees': count == 0 ? null : sum / count
      };
}

class _ComparisonTotals {
  int matched = 0, mismatched = 0;
  final raw2d = _AngleTotals(),
      filtered2d = _AngleTotals(),
      raw3d = _AngleTotals(),
      filtered3d = _AngleTotals();
  final rawUnavailable = <WorldKneeStatus, int>{},
      filteredUnavailable = <WorldKneeStatus, int>{};
  void add(_Sample s) {
    final c = s.comparison;
    if (c == null || !c.matches(s.time, s.side)) {
      mismatched++;
      return;
    }
    matched++;
    raw2d.add(c.raw2dDegrees);
    filtered2d.add(c.filtered2dDegrees);
    raw3d.add(c.raw3d.angleDegrees);
    filtered3d.add(c.filtered3d.angleDegrees);
    if (c.raw3d.status != WorldKneeStatus.available) {
      rawUnavailable.update(c.raw3d.status, (n) => n + 1, ifAbsent: () => 1);
    }
    if (c.filtered3d.status != WorldKneeStatus.available) {
      filteredUnavailable.update(c.filtered3d.status, (n) => n + 1,
          ifAbsent: () => 1);
    }
  }

  Map<String, Object?> get summary => {
        'matchedFrames': matched,
        'mismatchedFrames': mismatched,
        'raw2d': raw2d.summary,
        'filtered2d': filtered2d.summary,
        'raw3d': raw3d.summary,
        'filtered3d': filtered3d.summary,
        'raw3dUnavailable': {
          for (final e in rawUnavailable.entries) e.key.wire: e.value
        },
        'filtered3dUnavailable': {
          for (final e in filteredUnavailable.entries) e.key.wire: e.value
        },
        'worldUnits': 'estimated_metres',
        'imageUnits': 'normalized_xy_restored_to_pixels',
        'angleUnits': 'degrees',
        'filterOrder': 'coordinate_filter_then_angle',
        'anatomicalAccuracyValidated': false,
      };
}

class _Sample {
  _Sample(this.time, this.side, this.angle, this.confidence, this.comparison);
  final int time;
  final SquatSide side;
  final double angle, confidence;
  final SquatAngleComparison? comparison;
}

class _Attempt {
  _Attempt(this.start, this.side, bool compareWorld)
      : comparison = compareWorld ? _ComparisonTotals() : null;
  final _ComparisonTotals? comparison;
  final int start;
  final SquatSide side;
  double minimumAngle = 180, minConfidence = 1, maxConfidence = 0;
  int validFrames = 0, rejectedFrames = 0, interruptions = 0, longestDepth = 0;
  int maximumDecisionDepthDwell = 0;
  int? decisionDepthDwellAtConfirmation;
  int? depthSince;
  bool interrupted = false;
  void sample(_Sample s, double depth) {
    comparison?.add(s);
    validFrames++;
    minimumAngle = math.min(minimumAngle, s.angle);
    confidence(s.confidence);
    interrupted = false;
    if (s.angle <= depth) {
      depthSince ??= s.time;
      longestDepth = math.max(longestDepth, s.time - depthSince!);
    } else {
      depthSince = null;
    }
  }

  void confidence(double c) {
    if (c.isFinite && c >= 0 && c <= 1) {
      minConfidence = math.min(minConfidence, c);
      maxConfidence = math.max(maxConfidence, c);
    }
  }
}

/// Optional scalar observation. Owns no PoseFrame, coordinates or callbacks.
/// Retains terminal summaries only; never drives the analyzer's decisions.
final class SquatDiagnosticRecorder {
  SquatDiagnosticRecorder(
      {this.capacity = 64, this.compareWorldAngles = false}) {
    if (capacity < 1 || capacity > 128) {
      throw ArgumentError('Diagnostic capacity must be 1..128');
    }
  }
  final int capacity;
  final bool compareWorldAngles;
  _ComparisonTotals _sessionComparison = _ComparisonTotals();
  Map<String, Object?> _filterSettings = const {};
  final _records = Queue<SquatDiagnosticRecord>();
  SquatRuleSet _rules = SquatRuleSet();
  _Attempt? _active;
  _Sample? _last;
  double? _sessionScore;
  int totalRecords = 0, retentionEvictions = 0, rejectedObservations = 0;
  List<SquatDiagnosticRecord> get records => List.unmodifiable(_records);
  void configure(SquatRuleSet rules, {PoseFrameFilter? filter}) {
    _rules = rules;
    if (filter != null) {
      _filterSettings = {
        'minCutoff': filter.minCutoff,
        'beta': filter.beta,
        'derivativeCutoff': OneEuroFilter().dCutoff,
        'minimumVisibility': filter.minimumVisibility,
        'resetAfterMicros': filter.resetAfterMicros,
        'imageAndWorldBetaResponseEquivalent': false
      };
    }
  }

  void observe(
      {required int time,
      required SquatSide side,
      required double filtered2d,
      required double confidence,
      SquatAngleComparison? comparison}) {
    final s = _last = _Sample(time, side, filtered2d, confidence, comparison);
    if (compareWorldAngles) _sessionComparison.add(s);
    final a = _active;
    if (a != null) {
      if (a.side != side) {
        abort(SquatDiagnosticReason.sideChanged, time);
        return;
      }
      a.sample(s, _rules.depthAngleDegrees);
    }
  }

  void begin({required int time, required SquatSide side}) {
    _active = _Attempt(time, side, compareWorldAngles);
    final s = _last;
    if (s != null && s.time == time && s.side == side) {
      _active!.sample(s, _rules.depthAngleDegrees);
    }
  }

  void unavailable(double confidence) {
    rejectedObservations++;
    _last = null;
    final a = _active;
    if (a == null) return;
    a.rejectedFrames++;
    if (!a.interrupted) a.interruptions++;
    a.interrupted = true;
    a.depthSince = null;
    a.confidence(confidence);
  }

  /// Observe the existing FSM timer, freezing at its first confirmation.
  /// The attempt-start frame is intentionally absent from this timer.
  void decisionDepthDwell(int micros, {required bool confirmed}) {
    final a = _active;
    if (a == null || a.decisionDepthDwellAtConfirmation != null) return;
    a.maximumDecisionDepthDwell = math.max(a.maximumDecisionDepthDwell, micros);
    if (confirmed) a.decisionDepthDwellAtConfirmation = micros;
  }

  void complete(
      {required bool full,
      required int time,
      required int number,
      required double minimumAngle,
      required double trunkPenalty,
      required double depthPenalty,
      required double score,
      required double sessionScore}) {
    _sessionScore = sessionScore;
    final reason = full
        ? SquatDiagnosticReason.confirmedDepth
        : minimumAngle > _rules.depthAngleDegrees
            ? SquatDiagnosticReason.depthAngleNotReached
            : SquatDiagnosticReason.depthDwellNotConfirmed;
    _record(time, full ? 'full' : 'partial', reason,
        minimumAngle: minimumAngle,
        number: number,
        trunkPenalty: trunkPenalty,
        depthPenalty: depthPenalty,
        score: score,
        depthConfirmed: full);
  }

  void abort(SquatDiagnosticReason reason, int time) {
    _record(time, 'aborted', reason);
    _last = null;
  }

  void _record(int time, String outcome, SquatDiagnosticReason reason,
      {double? minimumAngle,
      int? number,
      double? trunkPenalty,
      double? depthPenalty,
      double? score,
      bool? depthConfirmed}) {
    final a = _active;
    _active = null;
    if (a == null) return;
    final sequence = ++totalRecords;
    _records.add(SquatDiagnosticRecord._(sequence, {
      'schemaVersion': 1,
      'sequence': sequence,
      'outcome': outcome,
      'reason': reason.wire,
      'side': a.side.name,
      'completedAttemptNumber': number,
      'observedDurationMicros': math.max(0, time - a.start),
      'minimumFiltered2dDegrees': minimumAngle ?? a.minimumAngle,
      'longestContinuousDepthMicros': a.longestDepth,
      'maximumDecisionDepthDwellMicros': a.maximumDecisionDepthDwell,
      'decisionDepthDwellAtConfirmationMicros':
          a.decisionDepthDwellAtConfirmation,
      'depthConfirmed': depthConfirmed,
      'validFrames': a.validFrames,
      'rejectedFrames': a.rejectedFrames,
      'trackingInterruptions': a.interruptions,
      'minimumConfidence': a.minConfidence,
      'maximumConfidence': a.maxConfidence,
      'trunkPenalty': trunkPenalty,
      'depthPenalty': depthPenalty,
      'scorePercent': score,
      'sessionScorePercent': _sessionScore,
      'depthThresholdDegrees': _rules.depthAngleDegrees,
      'requiredDepthDwellMicros': _rules.reversalMicros,
      'ruleVersion': SquatRuleSet.version,
      'depthDwellBoundary': 'observed_qualifying_capture_streak',
      if (compareWorldAngles) 'comparison': a.comparison!.summary,
      if (compareWorldAngles) 'filterSettings': Map.of(_filterSettings),
    }));
    if (_records.length > capacity) {
      _records.removeFirst();
      retentionEvictions++;
    }
  }

  void clear() {
    _active = null;
    _last = null;
    _sessionScore = null;
    _records.clear();
    totalRecords = retentionEvictions = rejectedObservations = 0;
    _sessionComparison = _ComparisonTotals();
  }

  Map<String, Object?> sessionSummary() => {
        'schemaVersion': 1,
        'kind': 'session_comparison_summary',
        'terminalRecords': totalRecords,
        'retentionEvictions': retentionEvictions,
        'rejected2dObservations': rejectedObservations,
        'comparisonPopulation': 'usable_2d_frames_including_calibration',
        if (compareWorldAngles) 'comparison': _sessionComparison.summary,
        if (compareWorldAngles) 'filterSettings': Map.of(_filterSettings),
        'baselineDecisionSource': 'filtered_2d',
        'ruleVersion': SquatRuleSet.version,
      };
}
