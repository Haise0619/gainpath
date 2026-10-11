import 'dart:typed_data';

enum PosePixelFormat { yuv420, bgra8888, rgb888 }

class PoseImagePlane {
  const PoseImagePlane(
      {required this.bytes,
      required this.rowStride,
      required this.pixelStride});
  final Uint8List bytes;
  final int rowStride, pixelStride;
}

class PoseCameraImage {
  PoseCameraImage(
      {required this.width,
      required this.height,
      required this.rotationDegrees,
      required this.format,
      required List<PoseImagePlane> planes})
      : planes = List.unmodifiable(planes) {
    if (width <= 0 ||
        height <= 0 ||
        width > 4096 ||
        height > 4096 ||
        !{0, 90, 180, 270}.contains(rotationDegrees) ||
        planes.length != (format == PosePixelFormat.yuv420 ? 3 : 1)) {
      throw ArgumentError('Invalid camera image geometry or planes.');
    }
    for (var n = 0; n < planes.length; n++) {
      final plane = planes[n];
      final chroma = format == PosePixelFormat.yuv420 && n > 0;
      final w = chroma ? (width + 1) ~/ 2 : width;
      final h = chroma ? (height + 1) ~/ 2 : height;
      final channels = format == PosePixelFormat.bgra8888
          ? 4
          : format == PosePixelFormat.rgb888
              ? 3
              : 1;
      if (plane.pixelStride < channels ||
          plane.rowStride < (w - 1) * plane.pixelStride + channels ||
          plane.bytes.length <
              (h - 1) * plane.rowStride +
                  (w - 1) * plane.pixelStride +
                  channels) {
        throw ArgumentError('Truncated camera plane or invalid stride.');
      }
    }
  }
  final int width, height, rotationDegrees;
  final PosePixelFormat format;
  final List<PoseImagePlane> planes;
  int get uprightWidth => rotationDegrees % 180 == 0 ? width : height;
  int get uprightHeight => rotationDegrees % 180 == 0 ? height : width;
}
