import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/infrastructure/pose/real_squat_performance.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import 'real_squat_session_test.dart' as support;
import 'squat_processing_controller_test.dart' as fixtures;

void main() {
  test(
      'performance-only painter observes visible paint once and excludes cover-cropped joints',
      () {
    var now = 100000;
    final metrics = RealSquatPerformance(clockMicros: () => now)..resume();
    metrics.delivered(100000);
    now = 120000;
    final frame = fixtures.frame(100000, 175);
    void paint(Rect crop) {
      final picture = ui.PictureRecorder();
      PoseLandmarkPainter(
              frame: frame,
              mirrored: false,
              performance: metrics,
              performanceViewport: crop)
          .paint(Canvas(picture), const Size(640, 720));
      picture.endRecording().dispose();
    }

    paint(const Rect.fromLTWH(0, 0, 100, 100));
    expect(
        (metrics.snapshot({})['timings'] as Map)
            .containsKey('inputToFirstCpuPaintMicros'),
        false);
    paint(const Rect.fromLTWH(0, 0, 640, 720));
    paint(const Rect.fromLTWH(0, 0, 640, 720));
    expect(
        ((metrics.snapshot({})['timings'] as Map)['inputToFirstCpuPaintMicros']
            as Map)['count'],
        1);
  });
  test(
      'scalar observer measures first paint once, bounds retention and excludes private diagnostics',
      () {
    var now = 1000;
    final metrics = RealSquatPerformance(clockMicros: () => now, capacity: 3);
    metrics.resume();
    now = 3000;
    metrics.delivered(2000);
    now = 4000;
    metrics.painted(2000);
    now = 5000;
    metrics.painted(2000);
    metrics.painted(1500);
    final first = metrics.snapshot({
      'inferenceBackend': 'cpu_2_threads',
      'averageInferenceMillis': 50.0,
      'averagePipelineMillis': 80.0,
      'rawLandmarks': [
        {
          'leftHip': [.2, .3]
        }
      ],
      'userId': 'private-user'
    });
    final paint =
        (first['timings'] as Map)['inputToFirstCpuPaintMicros'] as Map;
    expect(paint['count'], 1);
    expect(paint['p50Millis'], 2.0);
    expect(first['physicalCameraLatencyMeasured'], false);
    expect(jsonEncode(first), isNot(contains('leftHip')));
    expect(jsonEncode(first), isNot(contains('private-user')));
    for (var i = 0; i < 8; i++) {
      now += 100;
      metrics.delivered(now);
    }
    expect(
        ((metrics.snapshot({})['timings'] as Map)['inputToDeliveryMicros']
            as Map)['retainedSamples'],
        3);
  });
  test(
      'pause time and stale/unknown paints do not become fresh timing evidence',
      () {
    var now = 0;
    final metrics = RealSquatPerformance(clockMicros: () => now);
    metrics.resume();
    now = 100000;
    metrics.delivered(50000);
    metrics.pause();
    now = 1000000;
    metrics.delivered(900000);
    metrics.painted(50000);
    metrics.resume();
    now = 1100000;
    metrics.delivered(800000);
    final report = metrics.snapshot({});
    expect(report['activeDurationMicros'], 200000);
    expect(report['measuredDeliveries'], 1);
    expect(report['staleObservations'], 1);
    expect((report['timings'] as Map).containsKey('inputToFirstCpuPaintMicros'),
        false);
  });
  testWidgets(
      'real coordinator shares observer with preview and records analyzer runtime',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    var now = 0;
    final metrics = RealSquatPerformance(clockMicros: () => now);
    final camera = support.Camera(), detector = support.Detector();
    final session = RealSquatSessionController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        detectorFactory: () async => detector,
        audioPort: fixtures.AudioSink(),
        repository: WorkoutSessionRepository(
            scope: scope,
            store: InMemoryWorkoutSessionStore(scope: scope),
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => scope),
        clockMicros: () => now,
        sessionId: 'fixture-session',
        exerciseId: 'squat',
        publishedRoutineId: 'routine',
        detectorId: 'fixture',
        detectorVersion: '1',
        performance: metrics,
        provenance: WorkoutProvenance.recordedFixture);
    expect(session.preview.performance, same(metrics));
    await session.start(consented: true, setupConfirmed: true);
    now = 100000;
    camera.receive!(PoseInput(timestampMicros: now));
    await tester.pump();
    expect(
        ((metrics.snapshot({})['timings'] as Map)['squatAnalysisMicros']
            as Map)['count'],
        1);
    await session.close();
    session.dispose();
  });
}
