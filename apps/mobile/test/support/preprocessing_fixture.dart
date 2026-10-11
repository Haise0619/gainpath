import 'dart:typed_data';
import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic, saturated/nonuniform pixels with poisoned row/pixel padding.
/// No camera frames or person images are stored by the benchmark or tests.
PoseCameraImage preprocessingFixture(PosePixelFormat format, int rotation,
    {int width = 27, int height = 19, int? chromaPixelStride}) {
  final channels = switch (format) {
    PosePixelFormat.rgb888 => 3,
    PosePixelFormat.bgra8888 => 4,
    PosePixelFormat.yuv420 => 1,
  };
  final stride = channels == 1 ? 1 : channels + 2;
  final row = width * stride + 9;
  final bytes = Uint8List(row * height)..fillRange(0, row * height, 211);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = y * row + x * stride;
      for (var c = 0; c < channels; c++) {
        bytes[offset + c] = (x * 17 + y * 31 + c * 61 + (x ~/ 8) * 73) & 255;
      }
    }
  }
  final planes = [
    PoseImagePlane(bytes: bytes, rowStride: row, pixelStride: stride),
  ];
  if (format == PosePixelFormat.yuv420) {
    final w = (width + 1) ~/ 2, h = (height + 1) ~/ 2;
    // Different U/V row/pixel strides catch accidental shared chroma indexing.
    for (var plane = 0; plane < 2; plane++) {
      final step = chromaPixelStride ?? plane + 1,
          chromaRow = w * step + 7 + plane;
      final chroma = Uint8List(chromaRow * h)..fillRange(0, chromaRow * h, 211);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          chroma[y * chromaRow + x * step] =
              (x * (19 + plane * 10) + y * (3 + plane * 4) + 43 + plane * 108) &
                  255;
        }
      }
      planes.add(PoseImagePlane(
          bytes: chroma, rowStride: chromaRow, pixelStride: step));
    }
  }
  return PoseCameraImage(
      width: width,
      height: height,
      rotationDegrees: rotation,
      format: format,
      planes: planes);
}
