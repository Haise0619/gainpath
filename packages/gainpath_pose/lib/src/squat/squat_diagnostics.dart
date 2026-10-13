import 'dart:collection';
import 'dart:math' as math;
import 'squat_geometry.dart';
import 'squat_rule_set.dart';

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
  Map<String, Object?> toJson() => Map.of(_values);
}

class _Sample {
  _Sample(this.time, this.side, this.angle, this.confidence);
  final int time;
  final SquatSide side;
  final double angle, confidence;
}

class _Attempt {
  _Attempt(this.start, this.side);
  final int start;
  final SquatSide side;
  double minimumAngle = 180, minConfidence = 1, maxConfidence = 0;
  int validFrames = 0, rejectedFrames = 0, interruptions = 0, longestDepth = 0;
  int? depthSince;
  bool interrupted = false;
  void sample(_Sample s, double depth) {
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
  SquatDiagnosticRecorder({this.capacity = 64}) {
    if (capacity < 1 || capacity > 128) {
      throw ArgumentError('Diagnostic capacity must be 1..128');
    }
  }
  final int capacity;
  final _records = Queue<SquatDiagnosticRecord>();
  SquatRuleSet _rules = SquatRuleSet();
  _Attempt? _active;
  _Sample? _last;
  double? _sessionScore;
  int totalRecords = 0, retentionEvictions = 0, rejectedObservations = 0;
  List<SquatDiagnosticRecord> get records => List.unmodifiable(_records);
  void configure(SquatRuleSet rules) => _rules = rules;
  void observe(
      {required int time,
      required SquatSide side,
      required double filtered2d,
      required double confidence}) {
    final s = _last = _Sample(time, side, filtered2d, confidence);
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
    _active = _Attempt(time, side);
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

  void abort(SquatDiagnosticReason reason, int time) =>
      _record(time, 'aborted', reason);
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
  }
}
