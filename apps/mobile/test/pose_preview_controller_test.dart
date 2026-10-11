import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';

class _Camera implements PoseCameraSource {
  int starts = 0, stops = 0, invalidations = 0;
  void Function(PoseInput)? receive;
  Completer<void>? opening;
  bool deny = false;
  @override
  Future<void> start(void Function(PoseInput) callback) async {
    if (deny) throw PoseCameraPermissionDenied();
    starts++;
    receive = callback;
    await opening?.future;
  }

  @override
  void invalidate() {
    invalidations++;
  }

  @override
  Future<void> stop() async {
    stops++;
    receive = null;
  }
}

class _Detector implements ManagedPoseDetector {
  int closes = 0, resets = 0, calls = 0;
  Completer<PoseFrame>? pending;
  @override
  Future<PoseFrame> detect(PoseInput input) {
    calls++;
    return pending?.future ??
        Future.value(PoseFrame(
            capturedAtMicros: input.timestampMicros,
            detectorId: 'fixture',
            modelVersion: '1',
            landmarks: {}));
  }

  @override
  Future<void> reset() async {
    resets++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  final scope = SessionScope(userId: 'user', organizationId: 'gainpath');
  testWidgets(
      'refined callback receives delivery once and excludes late pause results',
      (tester) async {
    final camera = _Camera();
    final detector = _Detector();
    final received = <PoseFrame>[];
    var now = 100;
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => now,
        onRefined: received.add);
    await controller.start(consented: true);
    camera.receive!(const PoseInput(timestampMicros: 100));
    await tester.pump();
    expect(received, hasLength(1));
    expect(received.single.capturedAtMicros, 100);
    detector.pending = Completer<PoseFrame>();
    now = 200;
    camera.receive!(const PoseInput(timestampMicros: 200));
    await tester.pump();
    final pausing = controller.pause();
    detector.pending!.complete(PoseFrame(
        capturedAtMicros: 200,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {}));
    await pausing;
    expect(received, hasLength(1));
    await controller.close();
    controller.dispose();
  });
  testWidgets('stalled lag capture completes on the existing preview tick',
      (tester) async {
    var now = 100;
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: _Camera(),
        detectorFactory: () async => _Detector(),
        clockMicros: () => now);
    await c.start(consented: true);
    c.startLagPhase('still');
    expect(c.quality.lag.phase, 'still');
    now += 20000000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.quality.lag.phase, isNull);
    expect(c.quality.lag.retainedFrames, 0);
    await c.close();
  },
      skip: !const bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG') ||
          !const bool.fromEnvironment('GAINPATH_POSE_JOINT_LAG_DEBUG'));
  testWidgets('quality separates delivery age, filtering and visible expiry',
      (tester) async {
    final camera = _Camera(), detector = _Detector();
    var now = 100;
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => now);
    await c.start(consented: true);
    detector.pending = Completer<PoseFrame>();
    camera.receive!(const PoseInput(timestampMicros: 100));
    now = 200;
    detector.pending!.complete(PoseFrame(
        capturedAtMicros: 100,
        detectorId: 'fixture',
        modelVersion: '1',
        posePresence: .9,
        landmarks: {
          PoseLandmark.leftShoulder:
              const PosePoint(x: .2, y: .3, z: 0, visibility: .9, presence: .9)
        }));
    await tester.pump();
    final quality = c.diagnostics['quality'] as Map?;
    expect(quality, isNotNull);
    expect((quality!['timings'] as Map)['uiDeliveryAgeMicros'],
        containsPair('meanMillis', .1));
    expect(
        (quality['timings'] as Map)['filterMicros'], containsPair('count', 1));
    now = 500000;
    await tester.pump(const Duration(milliseconds: 150));
    final after = c.diagnostics['quality'] as Map;
    expect((after['counters'] as Map)['expiredOverlay'], 1);
    expect(after['state'], 'freshness_expiry');
    expect(c.frame, isNull);
    await c.close();
  }, skip: !const bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG'));
  testWidgets('quality distinguishes queued stale inputs from empty inference',
      (tester) async {
    final camera = _Camera(), detector = _Detector();
    var now = 1000000;
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => now);
    await c.start(consented: true);
    camera.receive!(const PoseInput(timestampMicros: 100));
    await tester.pump();
    camera.receive!(const PoseInput(timestampMicros: 1000000));
    await tester.pump();
    final quality = c.diagnostics['quality'] as Map?;
    expect(quality, isNotNull);
    expect((quality!['counters'] as Map)['stale_before_processing'], 1);
    expect((quality['counters'] as Map)['emptyPose'], 1);
    expect(detector.calls, 1);
    await c.pause();
    expect(
        (c.diagnostics['quality'] as Map)['state'], 'lifecycle_manual_pause');
    await c.close();
  }, skip: !const bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG'));
  testWidgets(
      'expired overlays clear even when no further camera result arrives',
      (tester) async {
    final camera = _Camera(), detector = _Detector();
    var now = 100;
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => now);
    await c.start(consented: true);
    camera.receive!(const PoseInput(timestampMicros: 100));
    await tester.pump();
    expect(c.frame, isNotNull);
    now = 500000;
    await tester.pump(const Duration(milliseconds: 150));
    expect(c.frame, isNull);
    await c.close();
  });
  test(
      'permission denial stops the camera and provides retry without fabricated pose data',
      () async {
    final camera = _Camera()..deny = true, detector = _Detector();
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => 100);
    await c.start(consented: true);
    expect(c.phase, PosePreviewPhase.failure);
    expect(c.errorMessage, contains('permission'));
    expect(c.frame, isNull);
    expect(camera.stops, 1);
    camera.deny = false;
    await c.resume();
    expect(c.phase, PosePreviewPhase.tracking);
    await c.close();
    expect(detector.closes, 1);
  });
  test(
      'dispose during model loading closes its late interpreter without opening the camera',
      () async {
    final camera = _Camera(),
        detector = _Detector(),
        ready = Completer<ManagedPoseDetector>();
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () => ready.future,
        clockMicros: () => 100);
    final opening = c.start(consented: true);
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    ready.complete(detector);
    await opening;
    await c.close();
    expect(camera.starts, 0);
    expect(detector.closes, 1);
  });
  test('a 180 degree orientation change rejects the old in-flight skeleton',
      () async {
    final camera = _Camera(), detector = _Detector();
    final c = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => 100);
    PoseInput input(int time, int rotation) => PoseInput(
        timestampMicros: time,
        image: PoseCameraImage(
            width: 1,
            height: 1,
            rotationDegrees: rotation,
            format: PosePixelFormat.rgb888,
            planes: [
              PoseImagePlane(bytes: Uint8List(3), rowStride: 3, pixelStride: 3)
            ]));
    await c.start(consented: true);
    detector.pending = Completer<PoseFrame>();
    camera.receive!(input(1, 0));
    camera.receive!(input(2, 180));
    detector.pending!.complete(PoseFrame(
        capturedAtMicros: 1,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {}));
    detector.pending = null;
    await Future<void>.delayed(Duration.zero);
    expect(c.frame?.capturedAtMicros, 2);
    expect(c.displayedFrames, 1);
    await c.close();
  });
  test(
      'decline opens neither camera nor interpreter; consent precedes camera initialization',
      () async {
    final camera = _Camera(), detector = _Detector();
    var creates = 0;
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async {
          creates++;
          return detector;
        },
        clockMicros: () => 100);
    await controller.start(consented: false);
    expect(camera.starts, 0);
    expect(creates, 0);
    await controller.start(consented: true);
    expect(camera.starts, 1);
    expect(controller.phase, PosePreviewPhase.tracking);
    await controller.close();
    expect(detector.closes, 1);
  });
  test(
      'pause and background suppress in-flight landmarks and release camera; user pause survives foreground',
      () async {
    final camera = _Camera(), detector = _Detector();
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => 100);
    await controller.start(consented: true);
    detector.pending = Completer<PoseFrame>();
    camera.receive!(const PoseInput(timestampMicros: 1));
    final pausing = controller.pause();
    detector.pending!.complete(PoseFrame(
        capturedAtMicros: 1,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {}));
    await pausing;
    expect(controller.frame, isNull);
    expect(camera.stops, 1);
    expect(detector.resets, 1);
    await controller.foreground();
    expect(camera.starts, 1);
    await controller.resume();
    expect(camera.starts, 2);
    await controller.background();
    expect(camera.stops, 2);
    await controller.foreground();
    expect(camera.starts, 3);
    await controller.close();
  });
  test(
      'logout during camera opening invalidates the start and closes exactly once',
      () async {
    SessionScope? active = scope;
    final camera = _Camera(), detector = _Detector();
    camera.opening = Completer<void>();
    final controller = PosePreviewController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        detectorFactory: () async => detector,
        clockMicros: () => 100);
    final opening = controller.start(consented: true);
    await Future<void>.delayed(Duration.zero);
    active = null;
    final closing = controller.accountChanged();
    camera.opening!.complete();
    await Future.wait([opening, closing]);
    expect(controller.phase, PosePreviewPhase.closed);
    expect(camera.stops, greaterThanOrEqualTo(1));
    expect(detector.closes, 1);
    await controller.close();
    expect(detector.closes, 1);
  });
}
