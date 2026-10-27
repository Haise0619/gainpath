import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
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
