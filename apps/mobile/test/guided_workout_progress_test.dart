import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';

void main() {
  test('full reps finish sets, rest blocks counting, final set completes plan',
      () {
    final flow =
        GuidedWorkoutProgress(sets: 2, repetitions: 3, restSeconds: 30);
    flow.observe(2, nowMicros: 0);
    expect(flow.setRepetitions, 2);
    flow.observe(3, nowMicros: 1);
    expect(flow.stage, GuidedWorkoutStage.resting);
    flow.observe(8, nowMicros: 2);
    expect(flow.setRepetitions, 3);
    expect(flow.startNextSet(nowMicros: 2), false);
    flow.tick(30000001);
    expect(flow.remainingRestSeconds, 0);
    expect(flow.startNextSet(nowMicros: 30000001), true);
    flow.observe(11, nowMicros: 30000002);
    expect(flow.stage, GuidedWorkoutStage.complete);
    expect(flow.completedSets, 2);
    expect(flow.startNextSet(nowMicros: 30000003), false);
  });

  test(
      'background and manual pause freeze rest, skipping rest starts explicitly',
      () {
    final flow =
        GuidedWorkoutProgress(sets: 3, repetitions: 1, restSeconds: 60);
    flow.observe(1, nowMicros: 0);
    flow.suspend(10000000);
    flow.tick(90000000);
    expect(flow.remainingRestSeconds, 50);
    flow.resumeClock(90000000);
    flow.tick(95000000);
    expect(flow.remainingRestSeconds, 45);
    expect(flow.startNextSet(nowMicros: 95000000, skipRest: true), true);
    expect(flow.currentSet, 2);
    expect(flow.setRepetitions, 0);
  });
}
