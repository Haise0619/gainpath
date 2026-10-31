import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('reverse lunge requires the exact organization and variant identity',
      () {
    final capability = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath',
        exerciseId: 'bodyweight-reverse-lunge-side-v1');
    expect(capability.hasPoseTracking, true);
    expect(capability.trackerId, 'bodyweight_reverse_lunge_side_v1');
    expect(capability.cameraView, 'side');
    expect(capability.description, contains('front leg'));
    for (final identity in [
      ('other', 'bodyweight-reverse-lunge-side-v1'),
      ('gainpath', 'Reverse Lunge'),
      ('gainpath', 'bodyweight-reverse-lunge-side-v2'),
      ('gainpath', 'bodyweight-reverse-lunge-side-v1 '),
    ]) {
      expect(
          ExerciseTrackingRegistry.resolve(
                  organizationId: identity.$1, exerciseId: identity.$2)
              .hasPoseTracking,
          false);
    }
  });
}
