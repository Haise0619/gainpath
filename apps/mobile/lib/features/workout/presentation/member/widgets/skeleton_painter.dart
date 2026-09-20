import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class SkeletonPainter extends CustomPainter {
  final double t;
  SkeletonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.30;
    final squat = math.sin(t * math.pi) * size.height * 0.10;

    final line = Paint()
      ..color = AppColors.overlay
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = AppColors.overlay;

    final head = Offset(cx, baseY + squat);
    final neck = Offset(cx, baseY + 42 + squat);
    final hip = Offset(cx, baseY + 145 + squat);
    final kneeL = Offset(cx - 30, baseY + 215 + squat * 0.4);
    final kneeR = Offset(cx + 30, baseY + 215 + squat * 0.4);
    final ankleL = Offset(cx - 34, baseY + 290);
    final ankleR = Offset(cx + 34, baseY + 290);
    final shoulderL = Offset(cx - 38, baseY + 52 + squat);
    final shoulderR = Offset(cx + 38, baseY + 52 + squat);
    final elbowL = Offset(cx - 58, baseY + 108 + squat);
    final elbowR = Offset(cx + 58, baseY + 108 + squat);
    final handL = Offset(cx - 50, baseY + 158 + squat);
    final handR = Offset(cx + 50, baseY + 158 + squat);

    canvas.drawCircle(head, 20, Paint()
      ..color = AppColors.overlay
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke);

    for (final seg in [
      [neck, hip],
      [shoulderL, shoulderR],
      [shoulderL, elbowL],
      [elbowL, handL],
      [shoulderR, elbowR],
      [elbowR, handR],
      [hip, kneeL],
      [kneeL, ankleL],
      [hip, kneeR],
      [kneeR, ankleR],
    ]) {
      canvas.drawLine(seg[0], seg[1], line);
    }

    for (final p in [
      neck, hip, kneeL, kneeR, ankleL, ankleR,
      shoulderL, shoulderR, elbowL, elbowR, handL, handR,
    ]) {
      canvas.drawCircle(p, 5, joint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter old) => old.t != t;
}

/// AD-M2.5 — View Workout Result Summary.
