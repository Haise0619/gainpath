import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/infrastructure/pose/real_squat_performance.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_quality_diagnostics.dart';

const _responsiveAllowed =
    !bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG') &&
        !bool.fromEnvironment('GAINPATH_POSE_JOINT_LAG_DEBUG') &&
        !bool.fromEnvironment('GAINPATH_POSE_RENDER_DEBUG') &&
        !bool.fromEnvironment('GAINPATH_POSE_BLANK_DEBUG');

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
          detectorId: 'synthetic',
          modelVersion: '1',
          imageWidth: 480,
          imageHeight: 720,
          landmarks: {
            PoseLandmark.leftWrist: PosePoint(
                x: .5,
                y: input.timestampMicros == 1 ? .85 : .1,
                z: 0,
                visibility: .9,
                presence: .95)
          });
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}

void main() {
  for (final (observed, legacy, responsive) in [
    (true, false, true),
    (false, false, true),
    (true, true, true),
    (false, false, false)
  ]) {
    testWidgets(
        'preview source selection preserves analysis: observer=$observed legacy=$legacy responsive=$responsive',
        (tester) async {
      final scope = SessionScope(userId: 'fixture', organizationId: 'fixture');
      var now = 1;
      final camera = _Camera();
      final metrics =
          observed ? RealSquatPerformance(clockMicros: () => now) : null;
      final delivered = <PoseFrame>[];
      final controller = PosePreviewController(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => _Detector(),
          clockMicros: () => now,
          quality: PoseQualityDiagnostics(
              clockMicros: () => now,
              enabled: legacy ||
                  bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG')),
          performance: metrics,
          responsivePreview: responsive,
          onRefined: delivered.add);
      await controller.start(consented: true);
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
      now = 100001;
      camera.receive!(PoseInput(timestampMicros: now));
      await tester.pump();
      expect(delivered, hasLength(2));
      expect(delivered.last.landmarks[PoseLandmark.leftWrist]!.y, .1);
      final direct = responsive && _responsiveAllowed && !legacy;
      expect(controller.frame!.landmarks[PoseLandmark.leftWrist]!.y,
          direct ? .1 : inExclusiveRange(.4, .5));
      expect(
          controller.frame!.capturedAtMicros, delivered.last.capturedAtMicros);
      expect(
          controller.frame!.landmarks[PoseLandmark.leftWrist]!.visibility, .9);
      expect(
          controller.frame!.landmarks[PoseLandmark.leftWrist]!.presence, .95);
      if (metrics != null) {
        expect(metrics.snapshot(controller.diagnostics)['previewSource'],
            direct ? 'refined' : 'filtered');
      }
      await controller.pause();
      expect(controller.frame, isNull);
      await controller.close();
      controller.dispose();
    });
  }
}
