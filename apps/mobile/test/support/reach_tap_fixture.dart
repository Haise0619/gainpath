import 'dart:math';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';

/// Distance from a target to the calibrated shoulder's bounded movement area.
/// Used by target containment checks; actual hit tests still use real wrists.
double distanceToMotionArea(
    Point<double> target, Point<double> shoulder, ReachTapSample setup) {
  final w = setup.boardWidth, h = setup.boardHeight, short = min(w, h);
  final shoulderY = (setup.leftShoulder!.y + setup.rightShoulder!.y) / 2;
  final hipY = (setup.leftHip!.y + setup.rightHip!.y) / 2;
  final torso = (hipY - shoulderY) * h;
  final side = min(short * .32, torso * .50);
  final up = min(short * .35, torso * .55);
  final down = min(short * .40, torso * .55);
  final x = (target.x * w).clamp(shoulder.x * w - side, shoulder.x * w + side);
  final y = (target.y * h).clamp(shoulder.y * h - up, shoulder.y * h + down);
  return sqrt(pow(target.x * w - x, 2) + pow(target.y * h - y, 2));
}

/// Synthetic observations, not physical confidence or native camera replay.
ReachTapSample reachTapSample(
  int timeMicros, {
  Point<double>? leftHand,
  Point<double>? rightHand,
  bool missingLeftHand = false,
  bool missingBothHands = false,
  double boardWidth = 400,
  double boardHeight = 800,
  String geometryKey = 'front',
  double shift = 0,
  double scale = 1,
}) {
  Point<double> p(double x, double y) =>
      Point(.5 + (x - .5) * scale + shift, .5 + (y - .5) * scale);
  return ReachTapSample(
      leftShoulder: p(.38, .30),
      rightShoulder: p(.62, .30),
      leftElbow: p(.30, .43),
      rightElbow: p(.70, .43),
      leftHand:
          missingLeftHand || missingBothHands ? null : leftHand ?? p(.27, .57),
      rightHand: missingBothHands ? null : rightHand ?? p(.73, .57),
      leftHip: p(.42, .65),
      rightHip: p(.58, .65),
      capturedAtMicros: timeMicros,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      geometryKey: geometryKey);
}
