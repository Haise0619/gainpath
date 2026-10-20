import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

void main() {
  test('YUV channels saturate per source pixel before bilinear interpolation',
      () {
    // Neutral chroma gives RGB below0 at Y=0 and above255 at Y=255.
    // Clamp each corner first: [0,255,0,255] at the midpoint is127.5.
    // Clamping after interpolation would produce a different model input.
    final image = PoseCameraImage(
        width: 2,
        height: 2,
        rotationDegrees: 0,
        format: PosePixelFormat.yuv420,
        planes: [
          PoseImagePlane(
              bytes: Uint8List.fromList([0, 255, 0, 255]),
              rowStride: 2,
              pixelStride: 1),
          for (var i = 0; i < 2; i++)
            PoseImagePlane(
                bytes: Uint8List.fromList([128]), rowStride: 1, pixelStride: 1)
        ]);
    expect(
        preprocessImage(image, TensorImageTransform.fullFrame(2, 2), 1,
            minimum: 0, maximum: 1),
        [0.5, 0.5, 0.5]);
    expect(
        preprocessImage(image, TensorImageTransform.fullFrame(2, 2), 1,
            minimum: -1, maximum: 1),
        [0, 0, 0]);
  });
  test(
      'expanded landmark ROI replicates edge pixels while detector padding remains black',
      () {
    final image = PoseCameraImage(
        width: 1,
        height: 1,
        rotationDegrees: 0,
        format: PosePixelFormat.rgb888,
        planes: [
          PoseImagePlane(
              bytes: Uint8List.fromList([255, 0, 0]),
              rowStride: 3,
              pixelStride: 3)
        ]);
    final outside = TensorImageTransform(centerX: -10, centerY: -10, side: 1);
    expect(
        preprocessImage(image, outside, 1, minimum: 0, maximum: 1), [0, 0, 0]);
    expect(
        preprocessImage(image, outside, 1,
            minimum: 0, maximum: 1, border: PoseImageBorder.replicate),
        [1, 0, 0]);
  });
  test(
      'letterbox inverse mapping restores camera coordinates without stretching',
      () {
    final box = TensorImageTransform.fullFrame(640, 480);
    expect(box.project(0, 0), (0.0, -80.0));
    expect(box.project(0.5, 0.5), (320.0, 240.0));
    expect(box.project(1, 1), (640.0, 560.0));
    final roi = TensorImageTransform(
        centerX: 100, centerY: 200, side: 80, rotation: math.pi / 2);
    final point = roi.project(1, 0.5);
    expect(point.$1, closeTo(100, 1e-8));
    expect(point.$2, closeTo(240, 1e-8));
  });
  test(
      'BGRA strides, rotation, detector and landmark normalization match pixel values',
      () {
    final image = PoseCameraImage(
        width: 2,
        height: 2,
        rotationDegrees: 90,
        format: PosePixelFormat.bgra8888,
        planes: [
          PoseImagePlane(
              bytes: Uint8List.fromList([
                0,
                0,
                255,
                255,
                0,
                255,
                0,
                255,
                99,
                99,
                99,
                99,
                255,
                0,
                0,
                255,
                255,
                255,
                255,
                255,
              ]),
              rowStride: 12,
              pixelStride: 4)
        ]);
    final tensor = preprocessImage(
        image, TensorImageTransform.fullFrame(2, 2), 2,
        minimum: 0, maximum: 1);
    expect(tensor.sublist(0, 3), [0, 0, 1]);
    expect(tensor.sublist(3, 6), [1, 0, 0]);
    final normalized = preprocessImage(
        image, TensorImageTransform.fullFrame(2, 2), 2,
        minimum: -1, maximum: 1);
    expect(normalized.sublist(0, 3), [-1, -1, 1]);
  });
  test(
      'YUV420 chroma pixel/row strides decode correctly and malformed buffers fail',
      () {
    final image = PoseCameraImage(
        width: 2,
        height: 2,
        rotationDegrees: 0,
        format: PosePixelFormat.yuv420,
        planes: [
          PoseImagePlane(
              bytes: Uint8List.fromList([16, 235, 0, 16, 235]),
              rowStride: 3,
              pixelStride: 1),
          PoseImagePlane(
              bytes: Uint8List.fromList([128]), rowStride: 1, pixelStride: 2),
          PoseImagePlane(
              bytes: Uint8List.fromList([128]), rowStride: 1, pixelStride: 2),
        ]);
    final tensor = preprocessImage(
        image, TensorImageTransform.fullFrame(2, 2), 2,
        minimum: 0, maximum: 1);
    expect(tensor.sublist(0, 3), [0, 0, 0]);
    expect(tensor[3], closeTo(1, 0.001));
    expect(
        () => PoseCameraImage(
            width: 2,
            height: 2,
            rotationDegrees: 0,
            format: PosePixelFormat.yuv420,
            planes: []),
        throwsArgumentError);
  });
  test(
      'all Android orientation cases and front mirroring transform exactly once',
      () {
    expect(
        cameraRotation(sensorOrientation: 90, deviceDegrees: 0, front: false),
        90);
    expect(
        cameraRotation(sensorOrientation: 90, deviceDegrees: 90, front: false),
        0);
    expect(
        cameraRotation(sensorOrientation: 270, deviceDegrees: 90, front: true),
        0);
    final projection = PreviewProjection(
        imageWidth: 640,
        imageHeight: 480,
        viewportWidth: 320,
        viewportHeight: 640,
        mirrored: true);
    expect(projection.project(0.25, 0.5).$1, closeTo(373.333333, 1e-5));
    expect(projection.project(0.25, 0.5).$2, 320);
  });
}
