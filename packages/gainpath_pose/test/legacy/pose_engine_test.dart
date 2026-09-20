import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

PoseFrame frame(int micros, {double visibility = 1}) => PoseFrame(
      capturedAtMicros: micros,
      detectorId: 'test-detector',
      modelVersion: '1',
      landmarks: {
        for (final landmark in PoseLandmark.values)
          landmark: PosePoint(x: 0.5, y: 0.5, z: 0, visibility: visibility),
      },
    );

void main() {
  test('canonical pose frames retain detector metadata and immutable landmarks',
      () {
    final pose = frame(1000);

    expect(pose.capturedAtMicros, 1000);
    expect(pose.detectorId, 'test-detector');
    expect(pose.landmark(PoseLandmark.leftKnee)?.visibility, 1);
    expect(
        () => pose.landmarks[PoseLandmark.nose] =
            const PosePoint(x: 0, y: 0, z: 0, visibility: 0),
        throwsUnsupportedError);
  });

  test('one euro filter keeps the first value and smooths a sudden change', () {
    final filter = OneEuroFilter(minCutoff: 1, beta: 0, dCutoff: 1);

    expect(filter.filter(0, timestampSeconds: 0), 0);
    final smoothed = filter.filter(10, timestampSeconds: 1);

    expect(smoothed, greaterThan(0));
    expect(smoothed, lessThan(10));
  });

  test('tracking health distinguishes degraded tracking from sustained loss',
      () {
    final monitor = TrackingHealthMonitor(
      minimumVisibleLandmarks: 3,
      minimumVisibility: 0.5,
      lostAfterMicros: 1000000,
    );

    expect(monitor.update(frame(0, visibility: 0.2)).status,
        TrackingStatus.degraded);
    expect(monitor.update(frame(500000, visibility: 0.2)).status,
        TrackingStatus.degraded);
    final lost = monitor.update(frame(1100000, visibility: 0.2));

    expect(lost.status, TrackingStatus.lost);
    expect(lost.lostDurationMicros, 1100000);
    expect(monitor.update(frame(1200000)).status, TrackingStatus.healthy);
  });

  test('repetition FSM counts only a complete down-up cycle', () {
    final fsm = RepetitionFsm(downThreshold: 0.7, upThreshold: 0.3);

    expect(fsm.update(0.4).completed, isFalse);
    expect(fsm.update(0.8).completed, isFalse);
    expect(fsm.update(0.5).completed, isFalse);
    final completed = fsm.update(0.2);

    expect(completed.completed, isTrue);
    expect(completed.count, 1);
  });

  test('form score separates tracking confidence from geometric accuracy', () {
    final score = FormScore.calculate(
      confidence: 0.45,
      deviation: 0.1,
      trackedDurationMicros: 4000000,
    );

    expect(score.trackingConfidence, 45);
    expect(score.accuracy, greaterThan(80));
    expect(score.isValidInterval, isTrue);
  });

  test(
      'cue arbiter returns the highest priority cue and suppresses duplicate cooldowns',
      () {
    final arbiter = AudioCueArbiter(cooldownMicros: 2000000);

    arbiter.submit(const CueRequest(
        id: 'encourage',
        text: 'Keep going',
        priority: CuePriority.encouragement));
    arbiter.submit(const CueRequest(
        id: 'warning', text: 'Step back', priority: CuePriority.warning));

    expect(arbiter.takeNext(nowMicros: 1)?.id, 'warning');
    arbiter.submit(const CueRequest(
        id: 'warning', text: 'Step back', priority: CuePriority.warning));
    expect(arbiter.takeNext(nowMicros: 2), isNull);
    expect(arbiter.takeNext(nowMicros: 2000001)?.id, 'warning');
  });

  test('simulated detector emits bounded canonical frames', () async {
    final detector = SimulatedPoseDetector();
    final result = await detector.detect(const PoseInput(timestampMicros: 42));

    expect(result.capturedAtMicros, 42);
    expect(result.landmarks.length, PoseLandmark.values.length);
    expect(result.detectorId, 'simulated');
  });

  test(
      'session coordinator combines detector, tracking, repetition and scoring',
      () async {
    final coordinator = PoseSessionCoordinator(
      detector: SimulatedPoseDetector(),
      healthMonitor: TrackingHealthMonitor(),
      repetition: RepetitionFsm(downThreshold: 0.7, upThreshold: 0.3),
    );

    await coordinator.process(const PoseInput(timestampMicros: 0),
        movementMetric: 0.8);
    final result = await coordinator.process(
      const PoseInput(timestampMicros: 1000000),
      movementMetric: 0.2,
      deviation: 0.1,
    );

    expect(result.health.status, TrackingStatus.healthy);
    expect(result.repetition.completed, isTrue);
    expect(result.repetition.count, 1);
    expect(result.score.isValidInterval, isTrue);
  });
}
