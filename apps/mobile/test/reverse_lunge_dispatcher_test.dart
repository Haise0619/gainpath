import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';

void main() {
  test(
      'reverse lunge dispatches exactly and unavailable implementation stays guided',
      () {
    const installed = ExerciseTrackerDispatcher();
    final result = installed.resolve(
        organizationId: 'gainpath',
        exerciseId: 'bodyweight-reverse-lunge-side-v1');
    expect(result.tracker?.name, 'sideViewReverseLunge');
    expect(result.capability.hasPoseTracking, true);
    final unavailable = const ExerciseTrackerDispatcher(availableTrackers: {})
        .resolve(
            organizationId: 'gainpath',
            exerciseId: 'bodyweight-reverse-lunge-side-v1');
    expect(unavailable.tracker, isNull);
    expect(unavailable.unavailable, true);
    expect(unavailable.capability.hasPoseTracking, false);
    for (final identity in [
      ('other', 'bodyweight-reverse-lunge-side-v1'),
      ('gainpath', 'Reverse Lunge')
    ]) {
      expect(
          installed
              .resolve(organizationId: identity.$1, exerciseId: identity.$2)
              .tracker,
          isNull);
    }
  });
}
