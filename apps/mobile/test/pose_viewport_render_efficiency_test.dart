import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/pose_preview_route.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_performance_diagnostics.dart';
import 'package:gainpath_mobile/infrastructure/pose/android_pose_camera.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

class _PreviewCamera extends CameraController {
  _PreviewCamera()
      : super(
            const CameraDescription(
                name: 'fixture',
                lensDirection: CameraLensDirection.front,
                sensorOrientation: 0),
            ResolutionPreset.medium) {
    value =
        value.copyWith(isInitialized: true, previewSize: const Size(640, 480));
  }

  int textureBuilds = 0;

  @override
  Widget buildPreview() {
    textureBuilds++;
    return const ColoredBox(color: Colors.black);
  }
}

class _PoseSession extends PosePreviewController {
  _PoseSession(AndroidPoseCamera camera)
      : super(
            scope: _scope,
            activeScope: () => _scope,
            camera: camera,
            detectorFactory: () => throw StateError('No native fixture'),
            clockMicros: () => 0);

  static final _scope = SessionScope(userId: 'fixture', organizationId: 'test');

  void publish(PoseFrame? pose, {PosePreviewPhase? nextPhase}) {
    if (nextPhase != null) phase = nextPhase;
    frame = pose;
    notifyListeners();
  }
}

PoseFrame _pose(int index) => PoseFrame(
        capturedAtMicros: index * 50000,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 640,
        landmarks: {
          PoseLandmark.leftShoulder:
              PosePoint(x: .25 + index * .002, y: .3, z: 0, visibility: 1),
          PoseLandmark.leftElbow:
              const PosePoint(x: .3, y: .45, z: 0, visibility: 1),
        });

void main() {
  testWidgets('pose deliveries do not rebuild the camera texture widget',
      (tester) async {
    final texture = _PreviewCamera();
    final camera = AndroidPoseCamera(clockMicros: () => 0)
      ..controller = texture;
    final baseline = WorkoutPerformanceDiagnostics(
        exercise: WorkoutBaselineExercise.squat, clockMicros: () => 6000000);
    final session = _PoseSession(camera)..baseline = baseline;
    int paints() {
      final metrics = baseline.snapshot()['metrics'] as Map;
      return (metrics['skeletonPaintMicros'] as Map?)?['count'] as int? ?? 0;
    }

    session.publish(null, nextPhase: PosePreviewPhase.tracking);
    const boundaryKey = ValueKey('viewport-pixels');
    Future<int> greenPixels() async {
      return (await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
        final image = await boundary.toImage();
        final bytes =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
        var count = 0;
        for (var i = 0; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) == 0x67 &&
              bytes.getUint8(i + 1) == 0xE8 &&
              bytes.getUint8(i + 2) == 0xAB) {
            count++;
          }
        }
        return count;
      }))!;
    }

    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: boundaryKey,
            child: PoseCameraViewport(camera: camera, session: session))));
    final initialBuilds = texture.textureBuilds;
    expect(initialBuilds, greaterThan(0));
    for (var i = 0; i < 120; i++) {
      session.publish(_pose(i));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final extraBuilds = texture.textureBuilds - initialBuilds;
    debugPrint(
        'POSE_VIEWPORT_FIXTURE deliveries=120 textureRebuilds=$extraBuilds');
    expect(extraBuilds, 0);
    expect(paints(), 120);
    expect(await greenPixels(), greaterThan(0));
    session.publish(null);
    await tester.pump();
    expect(paints(), 120);
    expect(await greenPixels(), 0);
    session.publish(_pose(120));
    await tester.pump();
    expect(paints(), 121);
    texture.value = texture.value
        .copyWith(deviceOrientation: DeviceOrientation.landscapeLeft);
    await tester.pump();
    expect(texture.textureBuilds, greaterThan(initialBuilds));
    expect(paints(), 121, reason: 'The old portrait pose is not painted.');
    expect(await greenPixels(), 0);
    session.publish(null, nextPhase: PosePreviewPhase.closed);
    await tester.pump();
    expect(find.byType(CameraPreview), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.close();
    session.dispose();
  });
}
