import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_quality_diagnostics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/app/routing/pose_preview_route.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/live_workout_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import 'package:gainpath_mobile/infrastructure/pose/android_pose_camera.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_render_diagnostics.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_joint_lag_diagnostics.dart';

// Only the external camera texture/native inference are replaced. The real
// viewport, session scheduling/filter, projection, painter and canvas execute.
class _Texture extends CameraController {
  _Texture()
      : super(
            const CameraDescription(
                name: 'test',
                lensDirection: CameraLensDirection.front,
                sensorOrientation: 270),
            ResolutionPreset.medium) {
    value =
        value.copyWith(isInitialized: true, previewSize: const Size(720, 480));
  }
  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
}

class _Camera extends AndroidPoseCamera {
  _Camera() : super(clockMicros: () => 100) {
    controller = _Texture();
  }
  void Function(PoseInput)? receive;
  @override
  Future<void> start(void Function(PoseInput) callback) async {
    receive = callback;
  }

  @override
  Future<void> stop() async {
    receive = null;
  }
}

class _Detector implements ManagedPoseDetector {
  _Detector(this.quality);
  final PoseQualityDiagnostics quality;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    // Mirror the adapter's timestamp ownership trace; no native inference is
    // needed to exercise diagnostic refined/filtered binding in the real UI.
    quality.workerFrame({
      'frameTimestampMicros': input.timestampMicros,
      'outcome': 'pose',
      'landmarkCount': 33,
      'timings': <String, Object?>{},
      'projection': {'timestampMicros': input.timestampMicros},
    });
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'render-fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          for (final joint in PoseLandmark.values)
            joint: PosePoint(
                x: .3 + (joint.index % 5) * .08,
                y: .15 + (joint.index ~/ 5) * .1,
                z: 0,
                visibility: 1,
                presence: 1)
        });
  }

  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  test('off-viewport draw commands are distinguished from confidence rejection',
      () {
    final q = PoseQualityDiagnostics(
        clockMicros: () => 100, enabled: true, blankEnabled: true);
    q.blanks.start('still', sessionId: q.sessionId);
    final f = PoseFrame(
        capturedAtMicros: 1,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          for (final j in PoseLandmark.values)
            j: const PosePoint(x: 2, y: .5, z: 0, visibility: 1, presence: 1)
        });
    q.delivered(f, 0, refined: f);
    q.lag.delivered(
        f,
        f,
        {
          'frameTimestampMicros': f.capturedAtMicros,
          'projection': {'timestampMicros': f.capturedAtMicros},
        },
        100);
    final recorder = ui.PictureRecorder();
    PoseLandmarkPainter(frame: f, mirrored: false, quality: q)
        .paint(Canvas(recorder), const Size(480, 720));
    recorder.endRecording().dispose();
    final events = q.blanks.finish()['events'] as List;
    final cause = events.firstWhere((e) => e['kind'] == 'blank_begin') as Map;
    expect(cause['reason'], 'renderer_off_viewport');
    expect(cause['acceptedCount'], 33);
    expect(cause['rendererRejectedAll'], false);
    expect(cause['primitivesIssued'], greaterThan(0));
    expect(cause['viewportIntersectingPrimitives'], 0);
  });

  test(
      'debug markers reveal projected joints even when confidence suppresses skeleton links',
      () async {
    final frame = PoseFrame(
        capturedAtMicros: 1,
        detectorId: 'fixture',
        modelVersion: '1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          for (final joint in PoseLandmark.values)
            joint:
                const PosePoint(x: .25, y: .5, z: 0, visibility: 0, presence: 0)
        });
    final diagnostics = PoseRenderDiagnostics(enabled: true),
        recorder = ui.PictureRecorder();
    final lag = PoseJointLagDiagnostics(enabled: true, clockMicros: () => 100);
    lag.delivered(
        frame,
        frame,
        {
          'frameTimestampMicros': frame.capturedAtMicros,
          'projection': {'timestampMicros': frame.capturedAtMicros},
        },
        100);
    PoseLandmarkPainter(
            frame: frame, mirrored: true, diagnostics: diagnostics, lag: lag)
        .paint(Canvas(recorder), const Size(480, 720));
    final report = diagnostics.snapshot['paint'] as Map;
    expect(report['visibleAcceptedCount'], 0);
    expect(report['projectedLandmarkCount'], 33);
    expect(report['canvasWidth'], 480);
    expect(report['canvasHeight'], 720);
    expect(report['minProjectedX'], 360);
    expect(report['maxProjectedY'], 360);
    final picture = recorder.endRecording(),
        image = await picture.toImage(480, 720);
    picture.dispose();
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    var pink = 0;
    for (var i = 0; i < pixels!.lengthInBytes; i += 4) {
      if (pixels.getUint8(i) == 255 &&
          pixels.getUint8(i + 1) == 0 &&
          pixels.getUint8(i + 2) == 255) {
        pink++;
      }
    }
    expect(pink, greaterThan(0));
  });
  testWidgets(
      'successful pose output repaints pixels over a stationary camera without camera notifications',
      (tester) async {
    final scope = SessionScope(userId: 'u', organizationId: 'gainpath'),
        camera = _Camera();
    final quality =
        PoseQualityDiagnostics(clockMicros: () => 100, enabled: true);
    final session = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => _Detector(quality),
        quality: quality,
        clockMicros: () => 100);
    addTearDown(session.dispose);
    await session.start(consented: true);
    const boundaryKey = ValueKey('viewport-pixels');
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: boundaryKey,
            child: LiveWorkoutScreen(
                cameraSession: session,
                cameraViewport:
                    PoseCameraViewport(camera: camera, session: session)))));
    await tester.pump();
    camera.receive!(const PoseInput(timestampMicros: 100));
    await tester.pump();
    await tester.pump();
    expect(session.frame!.landmarks.length, 33);
    final canvas = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .singleWhere((p) => p.painter is PoseLandmarkPainter);
    expect(
        (canvas.painter! as PoseLandmarkPainter).frame?.capturedAtMicros, 100,
        reason:
            'new session frame must reach the painter even when camera state stays unchanged');
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    var green = 0;
    for (var i = 0; i < pixels!.lengthInBytes; i += 4) {
      if (pixels.getUint8(i) == 0x67 &&
          pixels.getUint8(i + 1) == 0xE8 &&
          pixels.getUint8(i + 2) == 0xAB) {
        green++;
      }
    }
    expect(green, greaterThan(0),
        reason:
            'landmark paint must produce visible green pixels above the camera');
    await session.pause();
    await tester.pump();
    expect(find.byType(PoseCameraViewport), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.close();
  });
}
