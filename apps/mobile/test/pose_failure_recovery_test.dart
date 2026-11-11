import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'pose_preview_authorization_test.dart' show PreviewCamera;

class ExclusiveCamera extends PreviewCamera
    implements ExclusivePoseCameraSource {
  @override
  Object get ownershipKey => 'test-physical-camera';
}

class FaultDetector implements ManagedPoseDetector {
  bool fail = false;
  int closes = 0;
  Completer<void>? closing;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    if (fail) throw StateError('terminal worker');
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {});
  }

  @override
  Future<void> reset() async {
    if (fail) throw StateError('dead worker');
  }

  @override
  Future<void> close() async {
    closes++;
    await closing?.future;
  }
}

void main() {
  final scope = SessionScope(userId: 'fixture', organizationId: 'gainpath');
  testWidgets('hung camera startup fails, then allows retry after cleanup',
      (tester) async {
    final opening = Completer<void>();
    final camera = ExclusiveCamera()..opening = opening;
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => FaultDetector(),
        clockMicros: () => 1,
        startupTimeout: const Duration(milliseconds: 20));
    final starting = controller.start(consented: true);
    await tester.pump();
    expect(camera.starts, 1);
    final staleCallback = camera.receive!;
    await tester.pump(const Duration(milliseconds: 21));
    await starting;
    expect(controller.phase, PosePreviewPhase.failure);
    expect(controller.errorMessage, contains('startup timed out'));
    await controller.resume();
    expect(camera.starts, 1);
    staleCallback(PoseInput(timestampMicros: 1));
    expect(controller.receivedFrames, 0);
    camera.opening = null;
    opening.complete();
    await tester.pump();
    expect(camera.stops, 1);
    expect(controller.phase, PosePreviewPhase.failure);
    await controller.resume();
    expect(camera.starts, 2);
    expect(controller.phase, PosePreviewPhase.tracking);
    await controller.close();
    controller.dispose();
  });

  testWidgets(
      'new route cannot acquire a physical camera until previous native retirement confirms',
      (tester) async {
    final firstCamera = ExclusiveCamera(), secondCamera = ExclusiveCamera();
    final firstDetector = FaultDetector()..closing = Completer<void>();
    final first = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: firstCamera,
        detectorFactory: () async => firstDetector,
        clockMicros: () => 1,
        cleanupTimeout: const Duration(milliseconds: 20));
    var creations = 0;
    final second = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: secondCamera,
        detectorFactory: () async {
          creations++;
          return FaultDetector();
        },
        clockMicros: () => 1);
    await first.start(consented: true);
    final closing = first.close();
    await tester.pump(const Duration(milliseconds: 21));
    await closing;
    await second.start(consented: true);
    expect(creations, 0);
    expect(secondCamera.starts, 0);
    firstDetector.closing!.complete();
    await tester.pump();
    await tester.pump();
    await second.resume();
    expect(creations, 1);
    expect(secondCamera.starts, 1);
    await second.close();
    first.dispose();
    second.dispose();
  });
  testWidgets(
      'failed detector is retired before deliberate retry creates a replacement',
      (tester) async {
    final camera = PreviewCamera(),
        failed = FaultDetector()..fail = true,
        next = FaultDetector();
    var created = 0, now = 1;
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => ++created == 1 ? failed : next,
        clockMicros: () => now);
    await c.start(consented: true);
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    await tester.pump();
    expect(c.phase, PosePreviewPhase.failure);
    await c.resume();
    expect(created, 2);
    expect(failed.closes, 1);
    now = 2;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(c.phase, PosePreviewPhase.tracking);
    await c.close();
    c.dispose();
  });

  testWidgets(
      'close wait is bounded while unfinished resource retirement blocks a new owner',
      (tester) async {
    final camera = PreviewCamera(),
        detector = FaultDetector()..closing = Completer<void>();
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => 1,
        cleanupTimeout: const Duration(milliseconds: 20));
    await c.start(consented: true);
    var finished = false;
    c.close().then((_) => finished = true);
    await tester.pump(const Duration(milliseconds: 21));
    expect(finished, isTrue);
    expect(c.phase, PosePreviewPhase.closed);
    await c.resume();
    expect(camera.starts, 1);
    detector.closing!.complete();
    await tester.pump();
    c.dispose();
  });
}
