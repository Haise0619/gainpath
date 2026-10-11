import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';

class _Camera implements PoseCameraSource {
  void Function(PoseInput)? receive;
  @override
  Future<void> start(void Function(PoseInput) onFrame) async =>
      receive = onFrame;
  @override
  void invalidate() {}
  @override
  Future<void> stop() async => receive = null;
}

class _Detector implements ManagedPoseDetector {
  @override
  Future<PoseFrame> detect(PoseInput input) async => PoseFrame(
          capturedAtMicros: input.timestampMicros,
          detectorId: 'synthetic-only',
          modelVersion: 'test',
          imageWidth: 480,
          imageHeight: 720,
          landmarks: {
            PoseLandmark.leftWrist: PosePoint(
                x: .5,
                y: input.timestampMicros == 1 ? .85 : .1,
                z: -.1,
                visibility: .9,
                presence: .95)
          });
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  const experiment = !kReleaseMode &&
      bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG') &&
      bool.fromEnvironment('GAINPATH_POSE_BETA12_EXPERIMENT');
  testWidgets('preview arm-step response selects isolated diagnostic beta only',
      (tester) async {
    final camera = _Camera();
    var time = 1;
    final scope = SessionScope(userId: 'test', organizationId: 'test');
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => _Detector(),
        clockMicros: () => time);
    await c.start(consented: true);
    camera.receive!(PoseInput(timestampMicros: time));
    await tester.pump();
    expect(c.frame!.landmarks[PoseLandmark.leftWrist]!.y, .85);
    time = 100001;
    camera.receive!(PoseInput(timestampMicros: time));
    await tester.pump();
    final point = c.frame!.landmarks[PoseLandmark.leftWrist]!;
    // A single step, not a physical-latency assertion. Candidate must move
    // farther toward the target while continuing to smooth; default is control.
    expect(point.y,
        experiment ? inExclusiveRange(.1, .33) : inExclusiveRange(.4, .5));
    expect(point.x, .5);
    expect(point.z, closeTo(-.1, 1e-12));
    expect(point.visibility, .9);
    expect(point.presence, .95);
    expect(c.frame!.capturedAtMicros, time);
    expect(c.frame!.imageWidth, 480);
    expect(c.frame!.imageHeight, 720);
    await c.close();
  });
  test('bounded provenance identifies actual preview filter settings', () {
    final scope = SessionScope(userId: 'test', organizationId: 'test');
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: _Camera(),
        detectorFactory: () async => _Detector(),
        clockMicros: () => 1);
    final settings = c.diagnostics['filterConfiguration'] as Map?;
    if (const bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG')) {
      expect(settings, isNotNull);
      expect(settings!['beta'], experiment ? 1.2 : .3);
      expect(settings['minCutoff'], 1);
      expect(settings['derivativeCutoff'], 1);
      expect(settings['minimumVisibility'], .5);
      expect(settings['resetAfterMicros'], 500000);
    } else {
      expect(settings, isNull);
    }
    c.dispose();
  });
}
