// Frozen pre-Step-2C kernel, retained only for differential tests/benchmarks.
// Do not update this oracle alongside the production optimization.
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart'
    show TensorImageTransform, PoseImageBorder;

(double, double) _baselineProject(
    TensorImageTransform transform, double x, double y) {
  final dx = (x - 0.5) * transform.side, dy = (y - 0.5) * transform.side;
  final c = math.cos(transform.rotation), s = math.sin(transform.rotation);
  return (
    transform.centerX + c * dx - s * dy,
    transform.centerY + s * dx + c * dy
  );
}

Float32List preprocessBaseline(
    PoseCameraImage image, TensorImageTransform transform, int size,
    {required double minimum,
    required double maximum,
    PoseImageBorder border = PoseImageBorder.zero}) {
  if (size <= 0 ||
      !minimum.isFinite ||
      !maximum.isFinite ||
      maximum <= minimum) {
    throw ArgumentError('Invalid tensor size/range.');
  }
  final result = Float32List(size * size * 3);
  final scale = (maximum - minimum) / 255;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final source =
          _baselineProject(transform, (x + 0.5) / size, (y + 0.5) / size);
      final rgb = _bilinear(image, source.$1 - 0.5, source.$2 - 0.5, border);
      final offset = (y * size + x) * 3;
      result[offset] = rgb.$1 * scale + minimum;
      result[offset + 1] = rgb.$2 * scale + minimum;
      result[offset + 2] = rgb.$3 * scale + minimum;
    }
  }
  return result;
}

(double, double, double) _bilinear(
    PoseCameraImage image, double x, double y, PoseImageBorder border) {
  final x0 = x.floor(), y0 = y.floor(), fx = x - x.floor(), fy = y - y.floor();
  final a = _pixel(image, x0, y0, border),
      b = _pixel(image, x0 + 1, y0, border);
  final c = _pixel(image, x0, y0 + 1, border),
      d = _pixel(image, x0 + 1, y0 + 1, border);
  double blend(double a, double b, double c, double d) =>
      (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy;
  return (
    blend(a.$1, b.$1, c.$1, d.$1),
    blend(a.$2, b.$2, c.$2, d.$2),
    blend(a.$3, b.$3, c.$3, d.$3)
  );
}

(double, double, double) _pixel(
    PoseCameraImage image, int x, int y, PoseImageBorder border) {
  if (border == PoseImageBorder.replicate) {
    x = x.clamp(0, image.uprightWidth - 1);
    y = y.clamp(0, image.uprightHeight - 1);
  }
  if (x < 0 || y < 0 || x >= image.uprightWidth || y >= image.uprightHeight) {
    return (0, 0, 0);
  }
  final raw = switch (image.rotationDegrees) {
    90 => (y, image.height - 1 - x),
    180 => (image.width - 1 - x, image.height - 1 - y),
    270 => (image.width - 1 - y, x),
    _ => (x, y),
  };
  final p = image.planes[0];
  final index = raw.$2 * p.rowStride + raw.$1 * p.pixelStride;
  if (image.format == PosePixelFormat.rgb888) {
    return (
      p.bytes[index].toDouble(),
      p.bytes[index + 1].toDouble(),
      p.bytes[index + 2].toDouble()
    );
  }
  if (image.format == PosePixelFormat.bgra8888) {
    return (
      p.bytes[index + 2].toDouble(),
      p.bytes[index + 1].toDouble(),
      p.bytes[index].toDouble()
    );
  }
  final u = image.planes[1], v = image.planes[2];
  final yy = p.bytes[index] - 16;
  final uu =
      u.bytes[(raw.$2 ~/ 2) * u.rowStride + (raw.$1 ~/ 2) * u.pixelStride] -
          128;
  final vv =
      v.bytes[(raw.$2 ~/ 2) * v.rowStride + (raw.$1 ~/ 2) * v.pixelStride] -
          128;
  return (
    (1.164383 * yy + 1.596027 * vv).clamp(0, 255),
    (1.164383 * yy - 0.391762 * uu - 0.812968 * vv).clamp(0, 255),
    (1.164383 * yy + 2.017232 * uu).clamp(0, 255)
  );
}
