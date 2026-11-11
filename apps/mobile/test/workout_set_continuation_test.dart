import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/workout_set_continuation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

void main() {
  test('required manual arm selection cancels automatic continuation', () {
    final h = _Harness()..rest();
    h.manualChoiceRequired = true;
    h.continuation.setEnabled(true);
    h.frame(3100000);
    expect(h.continuation.status, SetContinuationStatus.cancelled);
    expect(h.flow.stage, GuidedWorkoutStage.resting);
    expect(h.flow.startNextSet(nowMicros: h.now), true);
  });

  test(
      'disabled rest stays manual; enabled continuation requires fresh readiness',
      () {
    final h = _Harness();
    h.rest();
    h.frame(4000000);
    expect(h.flow.stage, GuidedWorkoutStage.resting);
    h.continuation.setEnabled(true);
    h.ready = false;
    h.frame(4100000);
    expect(h.continuation.status, SetContinuationStatus.waiting);
    h.ready = true;
    for (var now = 4200000; now <= 7200000; now += 100000) {
      h.frame(now);
    }
    expect(h.flow.stage, GuidedWorkoutStage.working);
    expect(h.flow.setRepetitions, 0);
    expect(h.flow.completedSets, 1);
  });

  for (final loss in ['pose', 'silence', 'pause', 'scope', 'source']) {
    test('$loss cancels an armed countdown and does not rearm that rest', () {
      final h = _Harness()..rest();
      h.continuation.setEnabled(true);
      h.frame(3100000);
      expect(h.continuation.status, SetContinuationStatus.countdown);
      switch (loss) {
        case 'pose':
          h.ready = false;
          h.frame(3200000);
        case 'silence':
          h.now = 3500000;
          h.continuation.update();
        case 'pause':
        case 'scope':
          h.allowed = false;
          h.continuation.update();
        case 'source':
          h.continuation.cancel();
      }
      expect(h.continuation.status, SetContinuationStatus.cancelled);
      h.allowed = true;
      h.ready = true;
      for (var now = 3600000; now <= 7200000; now += 100000) {
        h.frame(now);
      }
      expect(h.flow.stage, GuidedWorkoutStage.resting);
      expect(h.flow.startNextSet(nowMicros: h.now), isTrue);
    });
  }
}

class _Harness {
  final flow = GuidedWorkoutProgress(sets: 2, repetitions: 1, restSeconds: 3);
  int now = 0;
  bool allowed = true, ready = true;
  bool manualChoiceRequired = false;
  late final continuation = WorkoutSetContinuation(
      guidance: () => flow,
      clockMicros: () => now,
      canContinue: () => allowed,
      detectorId: 'fixture',
      detectorVersion: '1',
      createProbe: () => manualChoiceRequired ? null : (_, __) => ready,
      startNextSet: () => flow.startNextSet(nowMicros: now));
  void rest() => flow.observe(1, nowMicros: now);
  void frame(int at) {
    now = at;
    flow.tick(now);
    continuation.update(
        frame: PoseFrame(
            capturedAtMicros: now,
            detectorId: 'fixture',
            modelVersion: '1',
            landmarks: const {
          PoseLandmark.leftHip: PosePoint(x: .3, y: .5, z: 0, visibility: 1)
        }));
  }
}
