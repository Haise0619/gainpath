import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'blazepose_geometry.dart';
import 'pose_joint_lag_diagnostics.dart';

// Temporary, explicitly enabled development tracing. No joint coordinates are
// logged in normal builds, and these snapshots are never persisted by the app.
const poseRenderDebugEnabled =
    kDebugMode && bool.fromEnvironment('GAINPATH_POSE_RENDER_DEBUG');
void printPoseRenderingTrace(
    Map<String, Object> session, PoseRenderDiagnostics renderer) {
  if (!poseRenderDebugEnabled) return;
  final ui = session['renderUi'] as Map? ?? {},
      model = session['renderDecoder'] as Map? ?? {},
      render = renderer.snapshot;
  Object? concise(Object? value) {
    if (value is double) {
      return value.isFinite ? double.parse(value.toStringAsFixed(4)) : null;
    }
    if (value is Map) return value.map((k, v) => MapEntry(k, concise(v)));
    if (value is Iterable) return value.map(concise).toList();
    return value;
  }

  void line(String stage, Object? data) =>
      debugPrint('POSE_RENDER_$stage ${jsonEncode(concise(data))}');
  // Separate stages keep individual Android log lines below the logcat limit.
  line('MODEL', {
    'timestampMicros': model['timestampMicros'],
    'rawTensorLandmarkCount': model['rawTensorLandmarkCount'],
    'rawAnatomicalLandmarkCount': model['rawAnatomicalLandmarkCount'],
    'projectedImageCount': model['projectedImageCount'],
    'roi': model['roi']
  });
  Map summary(Object? data) =>
      data is Map ? (Map.of(data)..remove('representatives')) : {};
  line('IMAGE', summary(ui['decoded']));
  line('FILTERED', summary(ui['filtered']));
  line('HEALTH', {
    'emptyPoseFrames': ui['emptyPoseFrames'],
    'expiredOverlays': ui['expiredOverlays'],
    'overlayAgeMillis': ui['overlayAgeMillis']
  });
  line('VIEWPORT', {
    'viewportBuilds': render['viewportBuilds'],
    'painterInvocationCount': render['painterInvocationCount'],
    'shouldRepaintChecks': render['shouldRepaintChecks'],
    'shouldRepaintTrue': render['shouldRepaintTrue'],
    'viewport': render['viewport']
  });
  line('PAINTER', summary(render['paint']));
  if (poseJointLagDebugEnabled) return;
  final raw = model['rawRepresentatives'] as Map? ?? {},
      decoded = ui['decoded'] as Map? ?? {},
      filtered = ui['filtered'] as Map? ?? {},
      paint = render['paint'] as Map? ?? {};
  for (final joint in _representatives) {
    final r = raw[joint.name] as Map? ?? {},
        d = (decoded['representatives'] as Map? ?? {})[joint.name] as Map? ??
            {},
        f = (filtered['representatives'] as Map? ?? {})[joint.name] as Map? ??
            {},
        p = (paint['representatives'] as Map? ?? {})[joint.name] as Map? ?? {};
    line('JOINT', {
      'joint': joint.name,
      'rawTimestamp': model['timestampMicros'],
      'filteredTimestamp': filtered['timestampMicros'],
      'paintedTimestamp': paint['paintedFrameTimestampMicros'],
      'modelPixels': r['modelPixels'],
      'roiNormalized': r['roiNormalized'],
      'imageNormalizedBeforeFilter': d['imageNormalized'],
      'imagePixelsBeforeFilter': d['imagePixels'],
      'imageNormalizedAfterFilter': f['imageNormalized'],
      'imagePixelsAfterFilter': f['imagePixels'],
      'previewPixels': p['previewPixels'],
      'visibility': f['visibility'],
      'presence': f['presence'],
      'accepted': p['accepted'],
      'insideCanvas': p['insideCanvas']
    });
  }
}

const _baseRepresentatives = [
  PoseLandmark.leftShoulder,
  PoseLandmark.rightShoulder,
  PoseLandmark.leftHip,
  PoseLandmark.rightHip,
  PoseLandmark.leftKnee,
  PoseLandmark.rightKnee,
  PoseLandmark.leftAnkle,
  PoseLandmark.rightAnkle
];
final _representatives = <PoseLandmark>{
  ..._baseRepresentatives,
  if (poseJointLagDebugEnabled) ...lagJoints
};
bool _finite(PosePoint p) =>
    [p.x, p.y, p.z, p.visibility, p.presence ?? 1].every((v) => v.isFinite);
bool _accepted(PosePoint p) =>
    _finite(p) && p.visibility >= .5 && (p.presence ?? 1) >= .5;
Map<String, Object?> poseImageRenderingSummary(PoseFrame? frame) => {
      'timestampMicros': frame?.capturedAtMicros,
      'count': frame?.landmarks.length ?? 0,
      'visibleAcceptedCount':
          frame?.landmarks.values.where(_accepted).length ?? 0,
      'imageWidth': frame?.imageWidth,
      'imageHeight': frame?.imageHeight,
      'representatives': {
        if (frame != null)
          for (final joint in _representatives)
            if (frame.landmarks[joint] case final PosePoint p)
              joint.name: {
                'imageNormalized': [p.x, p.y, p.z],
                'imagePixels': [
                  p.x * frame.imageWidth,
                  p.y * frame.imageHeight,
                  p.z * frame.imageWidth
                ],
                'visibility': p.visibility,
                'presence': p.presence
              }
      },
    };
Map<String, Object?> blazePoseRenderingSummary(
        Float32List raw, PoseFrame frame, TensorImageTransform roi) =>
    {
      'timestampMicros': frame.capturedAtMicros,
      'rawTensorLandmarkCount': raw.length ~/ 5,
      'rawAnatomicalLandmarkCount': math.min(33, raw.length ~/ 5),
      'projectedImageCount': frame.landmarks.length,
      'posePresence': frame.posePresence,
      'roi': {
        'centerX': roi.centerX,
        'centerY': roi.centerY,
        'sidePixels': roi.side,
        'rotationRadians': roi.rotation
      },
      'rawRepresentatives': {
        for (final joint in _representatives)
          joint.name: {
            'modelPixels': raw.sublist(joint.index * 5, joint.index * 5 + 3),
            if (poseJointLagDebugEnabled)
              'confidenceLogits':
                  raw.sublist(joint.index * 5 + 3, joint.index * 5 + 5),
            if (poseJointLagDebugEnabled)
              'unrefinedImagePixels': [
                roi
                    .project(raw[joint.index * 5] / 256,
                        raw[joint.index * 5 + 1] / 256)
                    .$1,
                roi
                    .project(raw[joint.index * 5] / 256,
                        raw[joint.index * 5 + 1] / 256)
                    .$2
              ],
            'roiNormalized': [
              raw[joint.index * 5] / 256,
              raw[joint.index * 5 + 1] / 256,
              raw[joint.index * 5 + 2] / 256
            ]
          }
      },
      'imageBeforeFilter': poseImageRenderingSummary(frame),
    };

class PoseRenderDiagnostics {
  PoseRenderDiagnostics({this.enabled = poseRenderDebugEnabled});
  final bool enabled;
  int viewportBuilds = 0,
      paintInvocations = 0,
      repaintChecks = 0,
      repaintAccepted = 0;
  Map<String, Object?> _viewport = {}, _paint = {};
  void viewport(PoseFrame? frame,
      {required double width,
      required double height,
      required bool aspectCompatible}) {
    if (!enabled) return;
    viewportBuilds++;
    _viewport = {
      'boundFrameTimestampMicros': frame?.capturedAtMicros,
      'boundLandmarkCount': frame?.landmarks.length ?? 0,
      'aspectCompatible': aspectCompatible,
      'previewWidth': width,
      'previewHeight': height,
      'layeredAboveCameraPreview': true,
      'opacity': 1.0,
      'clip': 'preview bounds / BoxFit.cover',
      'painter': 'PoseLandmarkPainter (mock SkeletonPainter is not used)'
    };
  }

  void repaint(bool changed) {
    if (enabled) {
      repaintChecks++;
      if (changed) repaintAccepted++;
    }
  }

  void paint(PoseFrame? frame, Size size,
      {required bool mirrored, required bool connections}) {
    if (!enabled) return;
    paintInvocations++;
    final projected = <(double, double)>[], accepted = <(double, double)>[];
    final joints = <String, Object?>{};
    if (frame != null) {
      final projection = PreviewProjection(
          imageWidth: frame.imageWidth,
          imageHeight: frame.imageHeight,
          viewportWidth: size.width,
          viewportHeight: size.height,
          mirrored: mirrored);
      for (final entry in frame.landmarks.entries) {
        final p = entry.value;
        if (!_finite(p)) continue;
        final xy = projection.project(p.x, p.y);
        projected.add(xy);
        if (_accepted(p)) accepted.add(xy);
        if (_representatives.contains(entry.key)) {
          joints[entry.key.name] = {
            'imageNormalized': [p.x, p.y, p.z],
            'imagePixels': [p.x * frame.imageWidth, p.y * frame.imageHeight],
            'previewPixels': [xy.$1, xy.$2],
            'accepted': _accepted(p),
            'insideCanvas': xy.$1 >= 0 &&
                xy.$1 <= size.width &&
                xy.$2 >= 0 &&
                xy.$2 <= size.height
          };
        }
      }
    }
    _paint = {
      'paintedFrameTimestampMicros': frame?.capturedAtMicros,
      'canvasWidth': size.width,
      'canvasHeight': size.height,
      'painterLandmarkCount': frame?.landmarks.length ?? 0,
      'visibleAcceptedCount': accepted.length,
      'projectedLandmarkCount': projected.length,
      'insideCanvasCount': projected
          .where((p) =>
              p.$1 >= 0 &&
              p.$1 <= size.width &&
              p.$2 >= 0 &&
              p.$2 <= size.height)
          .length,
      'minProjectedX': projected.isEmpty
          ? null
          : projected.map((p) => p.$1).reduce(math.min),
      'maxProjectedX': projected.isEmpty
          ? null
          : projected.map((p) => p.$1).reduce(math.max),
      'minProjectedY': projected.isEmpty
          ? null
          : projected.map((p) => p.$2).reduce(math.min),
      'maxProjectedY': projected.isEmpty
          ? null
          : projected.map((p) => p.$2).reduce(math.max),
      'mirrored': mirrored,
      'visibilityThreshold': .5,
      'presenceThreshold': .5,
      'connectionsEnabled': connections,
      'debugCirclesIgnoreConfidence': true,
      'representatives': joints
    };
  }

  Map<String, Object?> get snapshot => {
        'viewportBuilds': viewportBuilds,
        'painterInvocationCount': paintInvocations,
        'shouldRepaintChecks': repaintChecks,
        'shouldRepaintTrue': repaintAccepted,
        'viewport': _viewport,
        'paint': _paint
      };
}
