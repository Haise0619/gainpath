import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/workout/application/pose_preview_controller.dart';
import 'blazepose_geometry.dart';
import 'pose_quality_diagnostics.dart';

class AndroidPoseCamera implements PoseCameraSource, PoseDetectorDiagnostics {
  AndroidPoseCamera(
      {required this.clockMicros, this.preferFront = true, this.quality});
  final PoseQualityDiagnostics? quality;
  final int Function() clockMicros;
  final bool preferFront;
  Map<String, Object> _lastGeometry = {};
  @override
  Map<String, Object> get diagnostics => _lastGeometry;
  CameraController? controller;
  int _revision = 0;
  bool get mirrored =>
      controller?.description.lensDirection == CameraLensDirection.front;

  @override
  void invalidate() {
    _revision++;
  }

  @override
  Future<void> start(void Function(PoseInput) onFrame) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android camera preview required.');
    }
    final revision = ++_revision;
    final cameras = await availableCameras();
    if (revision != _revision) return;
    if (cameras.isEmpty) throw StateError('No camera available.');
    final selected = cameras
            .where((c) =>
                c.lensDirection ==
                (preferFront
                    ? CameraLensDirection.front
                    : CameraLensDirection.back))
            .firstOrNull ??
        cameras.first;
    final next = CameraController(selected, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
    controller = next;
    try {
      await next.initialize();
      if (revision != _revision) {
        await next.dispose();
        if (identical(controller, next)) controller = null;
        return;
      }
      await next.startImageStream((image) {
        if (revision != _revision || !next.value.isInitialized) return;
        final callbackTime = quality?.enabled == true ? clockMicros() : 0;
        final orientation = next.value.deviceOrientation;
        final degrees = switch (orientation) {
          DeviceOrientation.portraitUp => 0,
          DeviceOrientation.landscapeLeft => 90,
          DeviceOrientation.portraitDown => 180,
          DeviceOrientation.landscapeRight => 270,
        };
        try {
          final rotation = cameraRotation(
              sensorOrientation: selected.sensorOrientation,
              deviceDegrees: degrees,
              front: selected.lensDirection == CameraLensDirection.front);
          final format = switch (image.format.group) {
            ImageFormatGroup.yuv420 => PosePixelFormat.yuv420,
            ImageFormatGroup.bgra8888 => PosePixelFormat.bgra8888,
            _ => throw StateError('Unsupported camera pixel format.'),
          };
          final snapshot = PoseCameraImage(
              width: image.width,
              height: image.height,
              rotationDegrees: rotation,
              format: format,
              planes: [
                for (final p in image.planes)
                  PoseImagePlane(
                      bytes: Uint8List.fromList(p.bytes),
                      rowStride: p.bytesPerRow,
                      pixelStride: p.bytesPerPixel ??
                          (format == PosePixelFormat.bgra8888 ? 4 : 1))
              ]);
          final preview = next.value.previewSize!;
          final landscape = degrees == 90 || degrees == 270;
          final previewWidth = landscape ? preview.width : preview.height;
          final previewHeight = landscape ? preview.height : preview.width;
          _lastGeometry = {
            'lens': selected.lensDirection.name,
            'sensorOrientation': selected.sensorOrientation,
            'rotationDegrees': rotation,
            'format': format.name,
            'imageWidth': image.width,
            'imageHeight': image.height,
            'previewWidth': previewWidth,
            'previewHeight': previewHeight,
            'previewAspectCompatible':
                ((snapshot.uprightWidth / snapshot.uprightHeight) -
                            (previewWidth / previewHeight))
                        .abs() <
                    .02,
          };
          // Flutter camera exposes delivery time, not the sensor exposure timestamp.
          final timestamp = clockMicros();
          quality?.cameraCallback(timestamp, callbackTime);
          onFrame(PoseInput(
              timestampMicros: timestamp,
              imageWidth: image.width,
              imageHeight: image.height,
              image: snapshot));
        } catch (_) {
          // Forward an explicitly malformed frame through the guarded pipeline;
          // never keep drawing the previous person's skeleton after conversion failure.
          onFrame(PoseInput(timestampMicros: clockMicros()));
        }
      });
    } on CameraException catch (error) {
      await next.dispose();
      if (identical(controller, next)) controller = null;
      if (error.code.startsWith('CameraAccess')) {
        throw PoseCameraPermissionDenied();
      }
      rethrow;
    } catch (_) {
      await next.dispose();
      if (identical(controller, next)) controller = null;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    invalidate();
    final previous = controller;
    controller = null;
    if (previous != null) await previous.dispose();
  }
}
