import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../../../../infrastructure/pose/blazepose_geometry.dart';
import '../../../../../infrastructure/pose/pose_render_diagnostics.dart';
import '../../../../../infrastructure/pose/pose_quality_diagnostics.dart';
import '../../../../../infrastructure/pose/pose_joint_lag_diagnostics.dart';

/// BlazePose anatomical topology; indices correspond to its published 33 points.
const poseConnections = <(int, int)>[
  (0, 1),
  (1, 2),
  (2, 3),
  (3, 7),
  (0, 4),
  (4, 5),
  (5, 6),
  (6, 8),
  (9, 10),
  (11, 12),
  (11, 13),
  (13, 15),
  (15, 17),
  (15, 19),
  (15, 21),
  (17, 19),
  (12, 14),
  (14, 16),
  (16, 18),
  (16, 20),
  (16, 22),
  (18, 20),
  (11, 23),
  (12, 24),
  (23, 24),
  (23, 25),
  (24, 26),
  (25, 27),
  (26, 28),
  (27, 29),
  (28, 30),
  (29, 31),
  (30, 32),
  (27, 31),
  (28, 32),
];

class PoseLandmarkPainter extends CustomPainter {
  PoseLandmarkPainter(
      {required this.frame,
      required this.mirrored,
      this.diagnostics,
      this.blankReason,
      this.sourceFrame,
      this.lag,
      this.quality})
      : _refinedFrame = !poseRefinedSkeletonDebugEnabled || frame == null
            ? null
            : (lag ?? quality?.lag)?.refinedForDisplay(frame.capturedAtMicros);
  final PoseFrame? _refinedFrame;
  final PoseJointLagDiagnostics? lag;
  final PoseQualityDiagnostics? quality;
  final PoseRenderDiagnostics? diagnostics;
  final PoseFrame? frame;
  final String? blankReason;
  final PoseFrame? sourceFrame;
  final bool mirrored;

  // Ownership remains the filtered frame. A diagnostic source must be its
  // exact inference sibling, never a retained result from a different stream.
  PoseFrame? _matchingRefined(PoseFrame? filtered, PoseFrame? refined) {
    if (filtered == null ||
        refined == null ||
        filtered.capturedAtMicros != refined.capturedAtMicros ||
        filtered.detectorId != refined.detectorId ||
        filtered.modelVersion != refined.modelVersion ||
        filtered.imageWidth != refined.imageWidth ||
        filtered.imageHeight != refined.imageHeight ||
        filtered.isMirrored != refined.isMirrored ||
        filtered.posePresence != refined.posePresence ||
        filtered.landmarks.length != refined.landmarks.length) {
      return null;
    }
    for (final entry in refined.landmarks.entries) {
      final p = entry.value, f = filtered.landmarks[entry.key];
      if (f == null ||
          ![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
              .every((v) => v.isFinite) ||
          p.visibility != f.visibility ||
          p.presence != f.presence) {
        return null;
      }
    }
    return refined;
  }

  @override
  void paint(Canvas canvas, Size size) {
    quality?.painted(frame, size.width, size.height, mirrored);
    final debug = diagnostics?.enabled == true;
    final connections = !debug ||
        const bool.fromEnvironment('GAINPATH_POSE_RENDER_LINKS',
            defaultValue: true);
    diagnostics?.paint(frame, size,
        mirrored: mirrored, connections: connections);
    if (debug) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0xFFFFFF00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
    }
    final lagDiagnostic = lag ?? quality?.lag;
    const refinedPrimary = poseRefinedSkeletonDebugEnabled;
    final selectionTimer = refinedPrimary && quality?.enabled == true
        ? (Stopwatch()..start())
        : null;
    final pose =
        refinedPrimary ? _matchingRefined(frame, _refinedFrame) : frame;
    if (selectionTimer != null) {
      quality!.sample(
          'refinedSkeletonSelectionMicros', selectionTimer.elapsedMicroseconds);
    }
    const skeletonSource = refinedPrimary ? 'refined_diagnostic' : 'filtered';
    if (quality?.enabled == true) {
      quality!.lastPaint['primarySkeletonSource'] = skeletonSource;
      quality!.lastPaint['primarySkeletonAvailable'] = pose != null;
      quality!.lastPaint['previewCoordinateSource'] =
          refinedPrimary ? 'filtered_markers' : 'filtered_skeleton';
    }
    if (pose == null) {
      quality?.overlayPainted(null,
          reason: refinedPrimary && frame != null
              ? 'diagnostic_refined_unavailable'
              : blankReason,
          sourceFrame: sourceFrame ?? frame,
          primitivesIssued: 0,
          viewportIntersectingPrimitives: 0);
      return;
    }
    final transform = PreviewProjection(
        imageWidth: pose.imageWidth,
        imageHeight: pose.imageHeight,
        viewportWidth: size.width,
        viewportHeight: size.height,
        mirrored: mirrored);
    final observeBlanks = quality?.blanks.enabled == true;
    var primitivesIssued = 0, viewportPrimitives = 0;
    // Observation uses the same outer cover/crop as the camera viewport. It
    // does not reject, move, or hide any drawing command.
    final viewport = quality?.viewport ?? const <String, Object?>{};
    final scale = (viewport['coverScale'] as num?)?.toDouble() ?? 1;
    final ox = (viewport['coverOffsetX'] as num?)?.toDouble() ?? 0;
    final oy = (viewport['coverOffsetY'] as num?)?.toDouble() ?? 0;
    final visibleRect = Rect.fromLTWH(
            -ox / scale,
            -oy / scale,
            ((viewport['width'] as num?)?.toDouble() ?? size.width) / scale,
            ((viewport['height'] as num?)?.toDouble() ?? size.height) / scale)
        .intersect(Offset.zero & size);
    bool intersectsLine(Offset a, Offset b) {
      if (![a.dx, a.dy, b.dx, b.dy].every((v) => v.isFinite)) return false;
      final r = visibleRect.inflate(1.25);
      var lo = 0.0, hi = 1.0;
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      for (final edge in [
        (-dx, a.dx - r.left),
        (dx, r.right - a.dx),
        (-dy, a.dy - r.top),
        (dy, r.bottom - a.dy)
      ]) {
        if (edge.$1 == 0) {
          if (edge.$2 < 0) return false;
        } else {
          final t = edge.$2 / edge.$1;
          if (edge.$1 < 0) {
            if (t > lo) lo = t;
          } else {
            if (t < hi) hi = t;
          }
          if (lo > hi) return false;
        }
      }
      return true;
    }

    final lagPoints = <PoseLandmark, Offset?>{}, lagDrawn = <(int, int)>{};
    if (quality?.enabled == true) {
      quality!.lastPaint['joints'] = {
        for (final joint in [
          PoseLandmark.leftShoulder,
          PoseLandmark.rightShoulder,
          PoseLandmark.leftHip,
          PoseLandmark.rightHip,
          PoseLandmark.leftKnee,
          PoseLandmark.rightKnee,
          PoseLandmark.leftAnkle,
          PoseLandmark.rightAnkle
        ])
          if (frame!.landmarks[joint] case final PosePoint p)
            joint.name: {
              'filteredImage': [p.x, p.y],
              'previewPixels': [
                transform.project(p.x, p.y).$1,
                transform.project(p.x, p.y).$2
              ],
              'visibility': p.visibility,
              'presence': p.presence,
              if (refinedPrimary)
                'primaryImage': [
                  pose.landmarks[joint]!.x,
                  pose.landmarks[joint]!.y
                ],
              'accepted': p.visibility >= .5 && (p.presence ?? 1) >= .5,
              'insideCanvas': transform.project(p.x, p.y).$1 >= 0 &&
                  transform.project(p.x, p.y).$1 <= size.width &&
                  transform.project(p.x, p.y).$2 >= 0 &&
                  transform.project(p.x, p.y).$2 <= size.height
            }
      };
    }
    Offset? point(int index) {
      final p = pose.landmarks[PoseLandmark.values[index]];
      if (p == null || p.visibility < .5 || (p.presence ?? 1) < .5) {
        if (lagDiagnostic?.enabled == true) {
          lagPoints[PoseLandmark.values[index]] = null;
        }
        return null;
      }
      final xy = transform.project(p.x, p.y);
      final result = Offset(xy.$1, xy.$2);
      if (lagDiagnostic?.enabled == true) {
        // These are the filtered marker coordinates, even when the primary
        // links draw refined coordinates. Never relabel R as filtered data.
        final f = frame!.landmarks[PoseLandmark.values[index]]!;
        final filteredXY = transform.project(f.x, f.y);
        lagPoints[PoseLandmark.values[index]] =
            Offset(filteredXY.$1, filteredXY.$2);
      }
      return result;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = const Color(0xFF67E8AB)
      ..strokeWidth = 2.5;
    if (connections) {
      for (final edge in poseConnections) {
        final a = point(edge.$1), b = point(edge.$2);
        if (a != null && b != null) {
          canvas.drawLine(a, b, paint);
          if (observeBlanks) {
            primitivesIssued++;
            if (intersectsLine(a, b)) viewportPrimitives++;
          }
          if (lagDiagnostic?.enabled == true && lagConnections.contains(edge)) {
            lagDrawn.add(edge);
          }
        }
      }
    }
    for (var i = 0; i < 33; i++) {
      final p = point(i);
      if (p != null) {
        canvas.drawCircle(p, 3, paint);
        if (observeBlanks) {
          primitivesIssued++;
          if (p.dx.isFinite &&
              p.dy.isFinite &&
              visibleRect.inflate(3).contains(p)) {
            viewportPrimitives++;
          }
        }
      }
    }
    if (debug && pose.landmarks.length == 33) {
      final marker = Paint()
        ..color = const Color(0xFFFF00FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      for (final joint in [
        PoseLandmark.leftShoulder,
        PoseLandmark.rightShoulder,
        PoseLandmark.leftHip,
        PoseLandmark.rightHip,
        PoseLandmark.leftKnee,
        PoseLandmark.rightKnee,
        PoseLandmark.leftAnkle,
        PoseLandmark.rightAnkle
      ]) {
        final p = pose.landmarks[joint];
        if (p == null || !p.x.isFinite || !p.y.isFinite) continue;
        final xy = transform.project(p.x, p.y);
        canvas.drawCircle(Offset(xy.$1, xy.$2), 10, marker);
      }
    }
    if (lagDiagnostic?.enabled == true) {
      final diagnosticTimer = Stopwatch()..start();
      lagDiagnostic!.painted(frame!, size,
          mirrored: mirrored,
          points: lagPoints,
          drawn: lagDrawn,
          connections: connections,
          primarySkeletonSource: skeletonSource,
          viewport: quality?.viewport ?? {});
      // Both marker sets use this exact frame and existing preview transform.
      final refined = refinedPrimary
          ? pose
          : lagDiagnostic.refinedFor(frame!.capturedAtMicros);
      if (refined != null) {
        for (final joint in lagJoints) {
          final a = refined.landmarks[joint], b = frame!.landmarks[joint];
          if (a == null ||
              b == null ||
              ![a.x, a.y, b.x, b.y].every((v) => v.isFinite)) {
            continue;
          }
          final rawXY = transform.project(a.x, a.y),
              filteredXY = transform.project(b.x, b.y);
          canvas.drawCircle(
              Offset(rawXY.$1, rawXY.$2),
              7,
              Paint()
                ..color = const Color(0xFFFFFF00)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
          canvas.drawCircle(Offset(filteredXY.$1, filteredXY.$2), 3,
              Paint()..color = const Color(0xFFFF00FF));
        }
      }
      quality?.sample(
          'jointLagPaintMicros', diagnosticTimer.elapsedMicroseconds);
    }
    canvas.restore();
    quality?.overlayPainted(pose,
        reason: blankReason,
        sourceFrame: sourceFrame,
        primitivesIssued: primitivesIssued,
        viewportIntersectingPrimitives: viewportPrimitives);
  }

  @override
  bool shouldRepaint(PoseLandmarkPainter old) {
    final changed = old.frame != frame ||
        (poseRefinedSkeletonDebugEnabled &&
            old._refinedFrame != _refinedFrame) ||
        old.mirrored != mirrored ||
        old.diagnostics != diagnostics ||
        (quality?.blanks.enabled == true &&
            (old.blankReason != blankReason || old.sourceFrame != sourceFrame));
    diagnostics?.repaint(changed);
    return changed;
  }
}
