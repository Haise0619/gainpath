import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('lateral raise requires the exact organization and variant identity',
      () {
    final capability = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath',
        exerciseId: 'standing-lateral-raise-front-v1');
    expect(capability.hasPoseTracking, true);
    expect(capability.trackerId, 'standing_lateral_raise_front_v1');
    expect(capability.cameraView, 'front');
    expect(capability.description, contains('both arms'));
    for (final identity in [
      ('other', 'standing-lateral-raise-front-v1'),
      ('gainpath', 'Standing Lateral Raise'),
      ('gainpath', 'standing-lateral-raise-front-v2'),
      ('gainpath', 'standing-lateral-raise-front-v1 '),
    ]) {
      expect(
          ExerciseTrackingRegistry.resolve(
                  organizationId: identity.$1, exerciseId: identity.$2)
              .hasPoseTracking,
          false);
    }
  });
}
