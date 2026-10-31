import 'dart:math';

/// One centered cover transform for already upright pose and camera preview.
class ReachTapProjection {
  const ReachTapProjection(
      {required this.imageWidth,
      required this.imageHeight,
      required this.viewportWidth,
      required this.viewportHeight,
      required this.mirrored});
  final double imageWidth, imageHeight, viewportWidth, viewportHeight;
  final bool mirrored;
  bool get compatible => [
        imageWidth,
        imageHeight,
        viewportWidth,
        viewportHeight
      ].every((value) => value.isFinite && value > 0);

  /// Cropped points remain outside [0,1]; callers must reject rather than clamp.
  Point<double> map(Point<double> point) {
    if (!compatible || !point.x.isFinite || !point.y.isFinite) {
      return const Point(double.nan, double.nan);
    }
    final scale = max(viewportWidth / imageWidth, viewportHeight / imageHeight);
    final x = mirrored ? 1 - point.x : point.x;
    return Point(
        (x * imageWidth * scale - (imageWidth * scale - viewportWidth) / 2) /
            viewportWidth,
        (point.y * imageHeight * scale -
                (imageHeight * scale - viewportHeight) / 2) /
            viewportHeight);
  }
}
