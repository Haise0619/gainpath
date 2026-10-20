import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'blazepose_geometry.dart';

const poseJointLagDebugEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_POSE_JOINT_LAG_DEBUG');
// Separate diagnostic artifact only. Default and release builds keep filtering.
const poseRefinedSkeletonDebugEnabled = poseJointLagDebugEnabled &&
    bool.fromEnvironment('GAINPATH_POSE_REFINED_SKELETON');
const lagJoints = [
  PoseLandmark.leftShoulder,
  PoseLandmark.rightShoulder,
  PoseLandmark.leftElbow,
  PoseLandmark.rightElbow,
  PoseLandmark.leftWrist,
  PoseLandmark.rightWrist
];
const lagConnections = [(11, 13), (13, 15), (12, 14), (14, 16)];

/// Observation only. At most one pending join and 300 phase samples in RAM.
/// Emit aggregates and four representative frames, never a per-frame stream.
class PoseJointLagDiagnostics {
  PoseJointLagDiagnostics(
      {required this.enabled,
      required this.clockMicros,
      this.maxFrames = 300,
      this.onReport});
  final bool enabled;
  final int Function() clockMicros;
  final int maxFrames;
  final void Function(Map<String, Object?> report)? onReport;
  final _frames = <Map<String, Object?>>[];
  final _outcomes = <String, int>{};
  final _filterResets = <String, int>{};
  int _filterGeneration = 0;
  (PoseFrame, PoseFrame, Map, int)? _pending;
  // One immutable coordinate frame for this diagnostic display. Starting a
  // capture clears its sample join, not the still-current displayed inference.
  PoseFrame? _displayRefined;
  int mismatches = 0, _started = 0, _lastPaint = -1;
  int _ignoredPaintsWithoutDelivery = 0;
  bool _capacityReached = false;
  String? phase;
  Map<String, Object?> lastReport = {};
  int get retainedFrames => _frames.length;
  double get remainingSeconds =>
      math.max(0, 20 - (clockMicros() - _started) / 1e6);

  /// Called by the existing preview timer even when camera delivery stalls.
  bool finishIfExpired() {
    if (!enabled || phase == null || clockMicros() - _started < 20000000) {
      return false;
    }
    finish();
    return true;
  }

  void start(String name) {
    if (!enabled) return;
    _frames.clear();
    _outcomes.clear();
    _filterResets.clear();
    _pending = null;
    _ignoredPaintsWithoutDelivery = 0;
    mismatches = 0;
    _lastPaint = -1;
    _capacityReached = false;
    _started = clockMicros();
    phase = name;
    if (onReport != null) {
      debugPrint('POSE_LAG_PHASE ${jsonEncode({
            'phase': name,
            'startedMicros': _started,
            'durationMicros': 20000000
          })}');
    }
  }

  void filterReset(String reason) {
    if (!enabled) return;
    _pending = null;
    _displayRefined = null;
    _filterGeneration++;
    if (phase != null) {
      _filterResets.update(reason, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  void delivered(PoseFrame refined, PoseFrame filtered,
      Map<String, Object?> trace, int deliveryMicros) {
    if (!enabled) return;
    finishIfExpired();
    _pending = null;
    _displayRefined = null;
    final projection = trace['projection'] as Map?;
    if (refined.capturedAtMicros != filtered.capturedAtMicros ||
        trace['frameTimestampMicros'] != refined.capturedAtMicros ||
        (refined.landmarks.isNotEmpty &&
            projection?['timestampMicros'] != refined.capturedAtMicros)) {
      mismatches++;
      return;
    }
    if (phase != null) {
      final outcome = trace['outcome'] as String? ??
          (refined.landmarks.isEmpty ? 'empty' : 'pose');
      _outcomes.update(outcome, (v) => v + 1, ifAbsent: () => 1);
    }
    _pending = (
      refined,
      filtered,
      {
        ...?projection,
        'resultReceivedMicros': trace['resultReceivedMicros'],
        'roiSource': trace['roiSource'],
        'detectorRan': trace['detectorRan']
      },
      deliveryMicros
    );
    if (poseRefinedSkeletonDebugEnabled) _displayRefined = refined;
  }

  PoseFrame? refinedFor(int timestamp) =>
      _pending?.$1.capturedAtMicros == timestamp ? _pending!.$1 : null;
  PoseFrame? refinedForDisplay(int timestamp) =>
      _displayRefined?.capturedAtMicros == timestamp ? _displayRefined : null;
  void painted(PoseFrame frame, Size size,
      {required bool mirrored,
      required Map<PoseLandmark, Offset?> points,
      required Set<(int, int)> drawn,
      required bool connections,
      String primarySkeletonSource = 'filtered',
      Map<String, Object?> viewport = const {}}) {
    if (!enabled || phase == null || frame.capturedAtMicros == _lastPaint) {
      return;
    }
    final pending = _pending;
    if (pending == null) {
      _ignoredPaintsWithoutDelivery++;
      return;
    }
    if (pending.$2.capturedAtMicros != frame.capturedAtMicros) {
      mismatches++;
      return;
    }
    _lastPaint = frame.capturedAtMicros;
    if (_frames.length >= maxFrames) {
      _capacityReached = true;
      return;
    }
    final projection = PreviewProjection(
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight,
        viewportWidth: size.width,
        viewportHeight: size.height,
        mirrored: mirrored);
    final joints = <String, Object?>{};
    final raw = pending.$3['rawRepresentatives'] as Map? ?? {};
    for (final joint in lagJoints) {
      final a = pending.$1.landmarks[joint], b = frame.landmarks[joint];
      if (a == null || b == null) continue;
      final xy = projection.project(b.x, b.y), actual = points[joint];
      final scale = (viewport['coverScale'] as num?)?.toDouble() ?? 1;
      final vx = (actual?.dx ?? xy.$1) * scale +
          ((viewport['coverOffsetX'] as num?) ?? 0);
      final vy = (actual?.dy ?? xy.$2) * scale +
          ((viewport['coverOffsetY'] as num?) ?? 0);
      final dx = (b.x - a.x) * frame.imageWidth,
          dy = (b.y - a.y) * frame.imageHeight;
      final unrefined =
          (raw[joint.name] as Map?)?['unrefinedImagePixels'] as List?;
      final refinement = unrefined == null
          ? null
          : math.sqrt(
              math.pow(a.x * frame.imageWidth - (unrefined[0] as num), 2) +
                  math.pow(a.y * frame.imageHeight - (unrefined[1] as num), 2));
      joints[joint.name] = {
        'rawModel': raw[joint.name],
        'refinedImageNormalized': [a.x, a.y, a.z],
        'refinedImagePixels': [a.x * frame.imageWidth, a.y * frame.imageHeight],
        'filteredImageNormalized': [b.x, b.y, b.z],
        'filteredImagePixels': [
          b.x * frame.imageWidth,
          b.y * frame.imageHeight
        ],
        'previewPixels':
            actual == null ? [xy.$1, xy.$2] : [actual.dx, actual.dy],
        'viewportPixels': [vx, vy],
        'insideViewport': vx >= 0 &&
            vx <= ((viewport['width'] as num?) ?? size.width) &&
            vy >= 0 &&
            vy <= ((viewport['height'] as num?) ?? size.height),
        'projectionResidualPixels': actual == null
            ? null
            : math.sqrt(math.pow(actual.dx - xy.$1, 2) +
                math.pow(actual.dy - xy.$2, 2)),
        'deltaPixels': [dx, dy],
        'displacementPixels': math.sqrt(dx * dx + dy * dy),
        'refinementDisplacementPixels': refinement,
        'visibility': b.visibility,
        'presence': b.presence,
        'accepted': actual != null,
        'finiteCoordinates': [
          a.x,
          a.y,
          a.z,
          b.x,
          b.y,
          b.z,
          b.visibility,
          b.presence ?? 1,
          vx,
          vy,
          dx,
          dy,
          actual?.dx ?? xy.$1,
          actual?.dy ?? xy.$2
        ].every((v) => v.isFinite),
        'insideCanvas': xy.$1 >= 0 &&
            xy.$1 <= size.width &&
            xy.$2 >= 0 &&
            xy.$2 <= size.height,
      };
    }
    _frames.add({
      'inputMicros': frame.capturedAtMicros,
      'primarySkeletonSource': primarySkeletonSource,
      'previewCoordinateSource': primarySkeletonSource == 'refined_diagnostic'
          ? 'filtered_markers'
          : 'filtered_skeleton',
      'filterGeneration': _filterGeneration,
      'deliveryMicros': pending.$4,
      'resultReceivedMicros': pending.$3['resultReceivedMicros'],
      'roiSource': pending.$3['roiSource'],
      'detectorRan': pending.$3['detectorRan'],
      'paintMicros': clockMicros(),
      'imageSize': [frame.imageWidth, frame.imageHeight],
      'canvasSize': [size.width, size.height],
      'mirrored': mirrored,
      'joints': joints,
      'viewport': Map.of(viewport),
      'links': {
        for (final edge in lagConnections)
          '${PoseLandmark.values[edge.$1].name}-${PoseLandmark.values[edge.$2].name}':
              !connections
                  ? 'connections_disabled'
                  : drawn.contains(edge)
                      ? 'draw_issued'
                      : '${points[PoseLandmark.values[edge.$1]] == null ? PoseLandmark.values[edge.$1].name : PoseLandmark.values[edge.$2].name}_rejected'
      }
    });
  }

  Map<String, Object?> finish() {
    if (!enabled || phase == null) return {};
    final stats = <String, Object?>{};
    for (final name in lagJoints.map((j) => j.name)) {
      final samples = _frames
          .map((f) => (f['joints'] as Map)[name])
          .whereType<Map>()
          .toList();
      final accepted = samples.where((s) => s['accepted'] == true).toList();
      final d = accepted
          .where((s) => s['finiteCoordinates'] == true)
          .map((s) => (s['displacementPixels'] as num).toDouble())
          .toList()
        ..sort();
      double? percentile(double p) =>
          d.isEmpty ? null : d[((d.length - 1) * p).round()];
      final refinement = samples
          .map((s) => s['refinementDisplacementPixels'])
          .whereType<num>()
          .where((v) => v.isFinite)
          .toList()
        ..sort();
      final residual = samples
          .map((s) => s['projectionResidualPixels'])
          .whereType<num>()
          .where((v) => v.isFinite)
          .toList();
      stats[name] = {
        'observed': samples.length,
        'accepted': accepted.length,
        'invalidCoordinates':
            samples.where((s) => s['finiteCoordinates'] != true).length,
        'missing': _frames.length - samples.length,
        'rejected': samples.length - accepted.length,
        'visibilityRejected':
            samples.where((s) => (s['visibility'] as num) < .5).length,
        'presenceRejected':
            samples.where((s) => ((s['presence'] as num?) ?? 1) < .5).length,
        'offCanvas': samples.where((s) => s['insideCanvas'] == false).length,
        'offViewport':
            samples.where((s) => s['insideViewport'] == false).length,
        'displacementMeanPixels':
            d.isEmpty ? null : d.reduce((a, b) => a + b) / d.length,
        'displacementP50Pixels': percentile(.5),
        'displacementP95Pixels': percentile(.95),
        'displacementMaxPixels': d.isEmpty ? null : d.last,
        'refinementMeanPixels': refinement.isEmpty
            ? null
            : refinement.reduce((a, b) => a + b) / refinement.length,
        'refinementP95Pixels': refinement.isEmpty
            ? null
            : refinement[((refinement.length - 1) * .95).round()],
        'projectionResidualMaxPixels':
            residual.isEmpty ? null : residual.reduce(math.max),
      };
    }
    final links = <String, Map<String, int>>{};
    for (final f in _frames) {
      for (final e in (f['links'] as Map).entries) {
        links
            .putIfAbsent(e.key as String, () => {})
            .update(e.value as String, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    // Same relative shoulder-level event; no interpolation or lag fitting.
    final responses = <String, Object?>{};
    for (final joint in [
      PoseLandmark.leftElbow,
      PoseLandmark.rightElbow,
      PoseLandmark.leftWrist,
      PoseLandmark.rightWrist
    ]) {
      final shoulder =
          joint.name.startsWith('left') ? 'leftShoulder' : 'rightShoulder';
      final crossings = <String, List<Map<String, Object?>>>{};
      Map<String, Object?>? previous;
      for (final f in _frames) {
        final js = f['joints'] as Map,
            j = js[joint.name] as Map?,
            s = js[shoulder] as Map?;
        if (j == null ||
            s == null ||
            j['accepted'] != true ||
            s['accepted'] != true ||
            j['finiteCoordinates'] != true ||
            s['finiteCoordinates'] != true) {
          previous = null;
          continue;
        }
        if (previous != null &&
            previous['filterGeneration'] == f['filterGeneration'] &&
            (f['inputMicros'] as int) - (previous['inputMicros'] as int) <=
                250000) {
          final pjs = previous['joints'] as Map;
          for (final space in [
            'refinedImageNormalized',
            'filteredImageNormalized'
          ]) {
            final before =
                ((pjs[joint.name] as Map)[space] as List)[1] as double;
            final bs = ((pjs[shoulder] as Map)[space] as List)[1] as double;
            final after = (j[space] as List)[1] as double,
                ss = (s[space] as List)[1] as double;
            final direction = before > bs && after <= ss
                ? 'raise'
                : before < bs && after >= ss
                    ? 'lower'
                    : null;
            if (direction != null) {
              final list = crossings.putIfAbsent('$space/$direction', () => []);
              if (list.length < 12) {
                list.add({
                  'inputBracketMicros': [
                    previous['inputMicros'],
                    f['inputMicros']
                  ]
                });
              }
            }
          }
        }
        previous = f;
      }
      responses[joint.name] = crossings;
    }
    // Four distinct snapshots at most: first, mid, peak arm displacement, last.
    var peak = 0;
    double maxD = -1;
    for (var i = 0; i < _frames.length; i++) {
      final values = (_frames[i]['joints'] as Map).entries.where((e) =>
          e.key.toString().contains('Wrist') ||
          e.key.toString().contains('Elbow'));
      final d = values.fold<double>(
          0,
          (sum, e) =>
              sum +
              (((e.value as Map)['displacementPixels'] as num).isFinite
                  ? ((e.value as Map)['displacementPixels'] as num).toDouble()
                  : 0));
      if (d > maxD) {
        maxD = d;
        peak = i;
      }
    }
    final indices = _frames.isEmpty
        ? <int>{}
        : <int>{0, _frames.length ~/ 2, peak, _frames.length - 1};
    final report = <String, Object?>{
      'phase': phase,
      'startedMicros': _started,
      'durationMicros': clockMicros() - _started,
      'paintedFrames': _frames.length,
      'capacityReached': _capacityReached,
      'timestampMismatches': mismatches,
      'ignoredPaintsWithoutDelivery': _ignoredPaintsWithoutDelivery,
      'outcomes': Map.of(_outcomes),
      'filterResets': Map.of(_filterResets),
      'jointStats': stats,
      'linkStats': links,
      'crossings': responses,
      'representatives': [for (final i in indices) _frames[i]],
      'spaces':
          'model: ROI pixels/256 and raw logits; image: upright unmirrored normalized; displacement: image XY pixels; preview: mirrored cover/crop canvas pixels',
      'boundary':
          'input ownership timestamp; delivery and CPU paint; no exposure/display-present'
    };
    phase = null;
    _frames.clear();
    _outcomes.clear();
    _filterResets.clear();
    lastReport = report;
    onReport?.call(report);
    return report;
  }

  void clear() {
    phase = null;
    _pending = null;
    _displayRefined = null;
    _frames.clear();
    _outcomes.clear();
    _filterResets.clear();
    lastReport = {};
    _lastPaint = -1;
  }
}

void printJointLagReport(Map<String, Object?> report) {
  Object? safe(Object? value) {
    if (value is double) return value.isFinite ? value : null;
    if (value is Map) return value.map((key, v) => MapEntry(key, safe(v)));
    if (value is Iterable) return value.map(safe).toList();
    return value;
  }

  var record = 0;
  void line(String stage, Map data) {
    final payload = {
      ...data,
      'captureStartedMicros': report['startedMicros'],
    };
    final encoded = jsonEncode(safe(payload));
    final direct = 'POSE_LAG_$stage $encoded';
    if (utf8.encode(direct).length <= 900) {
      debugPrint(direct);
      record++;
      return;
    }
    // Flutter's Android profile log path truncates at 1023 bytes. Emit the
    // same bounded record as independently valid, numbered transport chunks.
    final envelope = {
      'phase': report['phase'],
      'captureStartedMicros': report['startedMicros'],
      'record': record++,
      'stage': stage,
      'part': 9999,
      'parts': 9999,
      'data': '',
    };
    final budget =
        900 - utf8.encode('POSE_LAG_CHUNK ${jsonEncode(envelope)}').length;
    final parts = <String>[];
    var text = StringBuffer(), bytes = 0;
    for (final rune in encoded.runes) {
      final char = String.fromCharCode(rune);
      final cost = utf8.encode(jsonEncode(char)).length - 2;
      if (bytes + cost > budget) {
        parts.add(text.toString());
        text = StringBuffer();
        bytes = 0;
      }
      text.write(char);
      bytes += cost;
    }
    if (text.isNotEmpty) parts.add(text.toString());
    for (var i = 0; i < parts.length; i++) {
      debugPrint('POSE_LAG_CHUNK ${jsonEncode({
            ...envelope,
            'part': i,
            'parts': parts.length,
            'data': parts[i]
          })}');
    }
  }

  line(
      'SUMMARY',
      Map.of(report)
        ..remove('jointStats')
        ..remove('crossings')
        ..remove('representatives'));
  for (final e in (report['jointStats'] as Map).entries) {
    line('STAT', {'phase': report['phase'], 'joint': e.key, ...e.value as Map});
  }
  for (final e in (report['crossings'] as Map).entries) {
    for (final crossing in (e.value as Map).entries) {
      line('CROSSING', {
        'phase': report['phase'],
        'joint': e.key,
        'spaceDirection': crossing.key,
        'events': crossing.value,
        'limit': 12,
        'pairing': 'manual same-direction events; ambiguity/censoring retained'
      });
    }
  }
  for (final frame in report['representatives'] as List) {
    final base = Map.of(frame as Map)..remove('joints');
    for (final e in (frame['joints'] as Map).entries) {
      line('SAMPLE', {
        'phase': report['phase'],
        ...base,
        'joint': e.key,
        ...e.value as Map
      });
    }
  }
}
