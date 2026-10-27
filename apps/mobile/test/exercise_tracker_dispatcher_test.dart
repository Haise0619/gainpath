import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';

void main() {
  const installed = ExerciseTrackerDispatcher();
  test('calf tracking is on hold and defaults to guided-only on this app', () {
    final result = installed.resolve(
        organizationId: 'gainpath', exerciseId: 'standing-calf-raise-side-v1');
    expect(result.tracker, isNull);
    expect(result.capability.hasPoseTracking, false);
    expect(result.unavailable, true);
    expect(
        installed
            .resolve(
                organizationId: 'other',
                exerciseId: 'standing-calf-raise-side-v1')
            .tracker,
        isNull);
    expect(
        installed
            .resolve(organizationId: 'gainpath', exerciseId: 'Calf raise')
            .tracker,
        isNull);
  });
  test('wall push-up uses only its exact supported organization and variant',
      () {
    final wall = installed.resolve(
        organizationId: 'gainpath', exerciseId: 'wall-push-up-side-v1');
    expect(wall.tracker, ExerciseTracker.sideViewWallPushUp);
    expect(wall.description, contains('wall push-up'));
    expect(
        installed
            .resolve(
                organizationId: 'other', exerciseId: 'wall-push-up-side-v1')
            .tracker,
        isNull);
    expect(
        installed
            .resolve(organizationId: 'gainpath', exerciseId: 'Wall push-up')
            .tracker,
        isNull);
  });
  test('single-arm curl resolves only its exact catalog identity', () {
    final result = installed.resolve(
        organizationId: 'gainpath',
        exerciseId: 'standing-single-arm-curl-side-v1');
    expect(result.tracker, ExerciseTracker.sideViewCurl);
    expect(result.description, contains('single-arm'));
    expect(
        installed
            .resolve(
                organizationId: 'other',
                exerciseId: 'standing-single-arm-curl-side-v1')
            .tracker,
        isNull);
    expect(
        installed
            .resolve(organizationId: 'gainpath', exerciseId: 'Biceps curl')
            .tracker,
        isNull);
  });
  test('registered squat selects its installed route and required camera view',
      () {
    final result = installed.resolve(
        organizationId: 'gainpath', exerciseId: 'F3b8xIr8ynBDd3gEICKX');
    expect(result.tracker, ExerciseTracker.sideViewSquat);
    expect(result.capability.displayLabel, 'AI tracking · Side view');
    expect(result.unavailable, false);
  });

  test('unknown IDs and other organizations cannot select a camera tracker',
      () {
    for (final identity in [
      ('gainpath', 'Squat'),
      ('gainpath', 'new-squat'),
      ('another-org', 'F3b8xIr8ynBDd3gEICKX'),
    ]) {
      final result = installed.resolve(
          organizationId: identity.$1, exerciseId: identity.$2);
      expect(result.tracker, isNull);
      expect(result.capability.displayLabel, 'Guided only');
      expect(result.unavailable, false);
    }
  });

  test(
      'a known exercise without an installed tracker falls back to instructions',
      () {
    const app = ExerciseTrackerDispatcher(availableTrackers: {});
    final result = app.resolve(
        organizationId: 'gainpath', exerciseId: 'F3b8xIr8ynBDd3gEICKX');
    expect(result.tracker, isNull);
    expect(result.capability.hasPoseTracking, false);
    expect(result.unavailable, true);
    expect(result.description, contains('mark sets'));
  });
}
