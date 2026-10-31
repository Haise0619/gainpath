import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('corrected calf identity describes provisional visible-leg tracking',
      () {
    final calf = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath', exerciseId: 'standing-calf-raise-side-v1');
    expect(calf.hasPoseTracking, true);
    expect(calf.displayLabel, 'AI tracking · Side view');
    expect(calf.description, contains('visible leg only · provisional'));
    expect(ExerciseTrackingCapability.sideViewSquat.displayLabel,
        'AI tracking · Side view');
    expect(ExerciseTrackingCapability.guidedOnly.displayLabel, 'Guided only');
  });
  test('exact dumbbell shoulder press identity registers bilateral front view',
      () {
    final press = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath',
        exerciseId: 'dumbbell-shoulder-press-front-v1');
    expect(press.hasPoseTracking, true);
    expect(press.trackerId, 'dumbbell_shoulder_press_front_v1');
    expect(press.cameraView, 'front');
    expect(press.displayLabel, 'AI tracking · Front view');
    expect(press.description, contains('both arms'));
    for (final identity in [
      ('other', 'dumbbell-shoulder-press-front-v1'),
      ('gainpath', 'Dumbbell Shoulder Press'),
      ('gainpath', 'dumbbell-shoulder-press-side-v1')
    ]) {
      expect(
          ExerciseTrackingRegistry.resolve(
                  organizationId: identity.$1, exerciseId: identity.$2)
              .hasPoseTracking,
          false);
    }
  });
  test('only the exact single-arm row variant enables selected-arm tracking',
      () {
    final row = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath',
        exerciseId: 'single-arm-dumbbell-row-side-v1');
    expect(row.hasPoseTracking, true);
    expect(row.trackerId, 'single_arm_row_side_v1');
    expect(row.cameraView, 'side');
    expect(row.description, contains('selected-arm'));
    expect(row.description, contains('provisional'));
    for (final identity in [
      ('other', 'single-arm-dumbbell-row-side-v1'),
      ('gainpath', 'single-arm-dumbbell-row-side-v2'),
      ('gainpath', 'Single-arm dumbbell row'),
      ('gainpath', 'single-arm-dumbbell-row-side-v1 '),
    ]) {
      expect(
          ExerciseTrackingRegistry.resolve(
                  organizationId: identity.$1, exerciseId: identity.$2)
              .hasPoseTracking,
          false);
    }
  });
  test('wall push-up binding is exact and describes the visible-arm limit', () {
    final wall = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath', exerciseId: 'wall-push-up-side-v1');
    expect(wall, ExerciseTrackingCapability.sideViewWallPushUp);
    expect(wall.description, contains('visible arm'));
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'other', exerciseId: 'wall-push-up-side-v1')
            .hasPoseTracking,
        false);
  });
  test('calf raise binding is exact and names the visible-leg limitation', () {
    final calf = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath', exerciseId: 'standing-calf-raise-side-v1');
    expect(calf, ExerciseTrackingCapability.sideViewCalfRaise);
    expect(calf.description, contains('visible leg only'));
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'other',
                exerciseId: 'standing-calf-raise-side-v1')
            .hasPoseTracking,
        false);
  });
  test(
      'tracker availability binds exact organization and exercise variant, not a name',
      () {
    final squat = ExerciseTrackingRegistry.resolve(
        organizationId: 'gainpath', exerciseId: 'F3b8xIr8ynBDd3gEICKX');
    expect(squat.hasPoseTracking, true);
    expect(squat.cameraView, 'side');
    expect(squat.displayLabel, 'AI tracking · Side view');
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'other', exerciseId: 'F3b8xIr8ynBDd3gEICKX')
            .hasPoseTracking,
        false);
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'gainpath', exerciseId: 'new-squat')
            .hasPoseTracking,
        false);
  });
}
