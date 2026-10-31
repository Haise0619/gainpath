import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_projection.dart';

void main() {
  test('upright portrait coordinates mirror exactly once', () {
    final p = ReachTapProjection(
        imageWidth: 400,
        imageHeight: 800,
        viewportWidth: 400,
        viewportHeight: 800,
        mirrored: true);
    expect(p.compatible, true);
    expect(p.map(const Point(.25, .75)), const Point(.75, .75));
  });
  test('cover landscape source crops horizontally in portrait board', () {
    final p = ReachTapProjection(
        imageWidth: 800,
        imageHeight: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        mirrored: false);
    expect(p.map(const Point(.5, .5)), const Point(.5, .5));
    expect(p.map(const Point(.25, .5)), const Point(-.5, .5));
  });
  test('cover portrait source crops vertically in landscape board', () {
    final p = ReachTapProjection(
        imageWidth: 400,
        imageHeight: 800,
        viewportWidth: 800,
        viewportHeight: 400,
        mirrored: true);
    expect(p.map(const Point(.25, .25)), const Point(.75, -.5));
  });
  test('invalid dimensions cannot yield compatible projection', () {
    for (final d in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          ReachTapProjection(
                  imageWidth: d,
                  imageHeight: 800,
                  viewportWidth: 400,
                  viewportHeight: 800,
                  mirrored: false)
              .compatible,
          false);
    }
  });
}
