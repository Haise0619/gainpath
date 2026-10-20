// Frozen retained Step 2C sampler for the Step 2I performance comparison.
// Do not update this reference alongside an optimized production sampler.
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart'
    show TensorImageTransform, PoseImageBorder;

Float32List preprocessStep2c(
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
  final sampler = _PixelSampler(image, border);
  final cosine = math.cos(transform.rotation),
      sine = math.sin(transform.rotation);
  final cosineDx = Float64List(size), sineDx = Float64List(size);
  for (var x = 0; x < size; x++) {
    final dx = ((x + 0.5) / size - 0.5) * transform.side;
    cosineDx[x] = cosine * dx;
    sineDx[x] = sine * dx;
  }
  for (var y = 0; y < size; y++) {
    final dy = ((y + 0.5) / size - 0.5) * transform.side;
    final sineDy = sine * dy, cosineDy = cosine * dy;
    for (var x = 0; x < size; x++) {
      final sourceX = transform.centerX + cosineDx[x] - sineDy;
      final sourceY = transform.centerY + sineDx[x] + cosineDy;
      final rgb = _bilinear(sampler, sourceX - 0.5, sourceY - 0.5);
      final offset = (y * size + x) * 3;
      result[offset] = rgb.$1 * scale + minimum;
      result[offset + 1] = rgb.$2 * scale + minimum;
      result[offset + 2] = rgb.$3 * scale + minimum;
    }
  }
  return result;
}

(double, double, double) _bilinear(_PixelSampler image, double x, double y) {
  final x0 = x.floor(), y0 = y.floor();
  final fx = x - x0, fy = y - y0;
  final inverseFx = 1 - fx, inverseFy = 1 - fy;
  final a = image.pixel(x0, y0), b = image.pixel(x0 + 1, y0);
  final c = image.pixel(x0, y0 + 1), d = image.pixel(x0 + 1, y0 + 1);
  double blend(double a, double b, double c, double d) =>
      (a * inverseFx + b * fx) * inverseFy + (c * inverseFx + d * fx) * fy;
  return (
    blend(a.$1, b.$1, c.$1, d.$1),
    blend(a.$2, b.$2, c.$2, d.$2),
    blend(a.$3, b.$3, c.$3, d.$3)
  );
}

class _PixelSampler {
  _PixelSampler(PoseCameraImage image, PoseImageBorder border)
      : width = image.uprightWidth,
        height = image.uprightHeight,
        rawWidth = image.width,
        rawHeight = image.height,
        rotation = image.rotationDegrees,
        format = image.format,
        replicate = border == PoseImageBorder.replicate,
        primary = image.planes[0],
        u = image.format == PosePixelFormat.yuv420 ? image.planes[1] : null,
        v = image.format == PosePixelFormat.yuv420 ? image.planes[2] : null;
  final int width, height, rawWidth, rawHeight, rotation;
  final PosePixelFormat format;
  final bool replicate;
  final PoseImagePlane primary;
  final PoseImagePlane? u, v;

  (double, double, double) pixel(int x, int y) {
    if (replicate) {
      x = x < 0 ? 0 : (x >= width ? width - 1 : x);
      y = y < 0 ? 0 : (y >= height ? height - 1 : y);
    } else if (x < 0 || y < 0 || x >= width || y >= height) {
      return (0, 0, 0);
    }
    final raw = switch (rotation) {
      90 => (y, rawHeight - 1 - x),
      180 => (rawWidth - 1 - x, rawHeight - 1 - y),
      270 => (rawWidth - 1 - y, x),
      _ => (x, y),
    };
    final p = primary;
    final index = raw.$2 * p.rowStride + raw.$1 * p.pixelStride;
    if (format == PosePixelFormat.rgb888) {
      return (
        p.bytes[index].toDouble(),
        p.bytes[index + 1].toDouble(),
        p.bytes[index + 2].toDouble()
      );
    }
    if (format == PosePixelFormat.bgra8888) {
      return (
        p.bytes[index + 2].toDouble(),
        p.bytes[index + 1].toDouble(),
        p.bytes[index].toDouble()
      );
    }
    final u = this.u!, v = this.v!;
    final yy = p.bytes[index] - 16;
    final chromaX = raw.$1 ~/ 2, chromaY = raw.$2 ~/ 2;
    final uu = u.bytes[chromaY * u.rowStride + chromaX * u.pixelStride] - 128;
    final vv = v.bytes[chromaY * v.rowStride + chromaX * v.pixelStride] - 128;
    return (
      (1.164383 * yy + 1.596027 * vv).clamp(0, 255),
      (1.164383 * yy - 0.391762 * uu - 0.812968 * vv).clamp(0, 255),
      (1.164383 * yy + 2.017232 * uu).clamp(0, 255)
    );
  }
}
