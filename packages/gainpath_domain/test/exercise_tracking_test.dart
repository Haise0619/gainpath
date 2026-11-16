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
  test('retired identities resolve as guided only', () {
    for (final id in [
      'wall-push-up-side-v1',
      'single-arm-dumbbell-row-side-v1',
      'bodyweight-reverse-lunge-side-v1',
    ]) {
      expect(
          ExerciseTrackingRegistry.resolve(
              organizationId: 'gainpath', exerciseId: id),
          ExerciseTrackingCapability.guidedOnly);
      expect(
          ExerciseTrackingRegistry.isRetired(
              organizationId: 'gainpath', exerciseId: id),
          isTrue);
      expect(
          ExerciseTrackingRegistry.isRetired(
              organizationId: 'other', exerciseId: id),
          isFalse);
      expect(
          ExerciseTrackingRegistry.isRetired(
              organizationId: 'gainpath', exerciseId: '$id '),
          isFalse);
    }
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
