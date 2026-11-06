import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_execution_resolver.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';

PublishedRoutineExercise row(
        {String id = 'mobility',
        ExerciseExecutionMode? mode,
        int? reps = 8,
        int? duration,
        String? video,
        String? generation}) =>
    PublishedRoutineExercise(
        exerciseId: id,
        dayNumber: 1,
        name: 'Copied squat',
        category: '',
        sets: 3,
        reps: reps,
        durationSeconds: duration,
        executionMode: mode,
        entryId: 'entry-1',
        cue: '',
        imageUrl: '',
        muscleGroup: '',
        videoUrl: video,
        mediaGeneration: generation,
        mediaRevision: 1,
        mediaValidation: generation == null
            ? null
            : {
                'schemaVersion': 1,
                'videoUrl': video,
                'generation': generation,
                'sourceRevision': 1,
                'contentType': 'video/mp4',
                'bucket': 'bucket',
                'objectPath': 'video.mp4',
                'sizeBytes': 1000,
                'validatedAtMillis': 1
              });

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  const resolver = ExerciseExecutionResolver();
  test(
      'all nine exact registry identities retain their measured implementation',
      () {
    const identities = {
      'standing-lateral-raise-front-v1': ExerciseTracker.frontViewLateralRaise,
      'dumbbell-shoulder-press-front-v1':
          ExerciseTracker.frontViewShoulderPress,
      'F3b8xIr8ynBDd3gEICKX': ExerciseTracker.sideViewSquat,
      'standing-single-arm-curl-side-v1': ExerciseTracker.sideViewCurl,
      'standing-calf-raise-side-v1': ExerciseTracker.sideViewCalfRaise,
      'wall-push-up-side-v1': ExerciseTracker.sideViewWallPushUp,
      'standard-floor-push-up-side-v1': ExerciseTracker.sideViewFloorPushUp,
      'single-arm-dumbbell-row-side-v1': ExerciseTracker.sideViewRow,
      'bodyweight-reverse-lunge-side-v1': ExerciseTracker.sideViewReverseLunge,
    };
    for (final pair in identities.entries) {
      final result =
          resolver.resolve(scope: scope, exercise: row(id: pair.key));
      expect(result.kind, ExerciseExecutionKind.measured);
      expect(result.tracker, pair.value);
      expect(
          resolver
              .resolve(
                  scope: scope,
                  exercise: row(
                      id: pair.key,
                      mode: ExerciseExecutionMode.videoGuidedTimed,
                      reps: null,
                      duration: 45,
                      video: 'https://storage.example/video.mp4',
                      generation: '123'))
              .kind,
          ExerciseExecutionKind.unavailable);
    }
  });
  test('timed validated publication resolves separately from camera tracking',
      () {
    final timed = row(
        mode: ExerciseExecutionMode.videoGuidedTimed,
        reps: null,
        duration: 45,
        video: 'https://storage.example/video.mp4',
        generation: '123');
    expect(resolver.resolve(scope: scope, exercise: timed).kind,
        ExerciseExecutionKind.timed);
    expect(timed.prescription, isA<TimedPrescription>());
    expect(timed.reps, isNull);
  });
  test(
      'explicit AI claim on unknown identity is unavailable while legacy remains manual',
      () {
    expect(
        resolver
            .resolve(
                scope: scope,
                exercise: row(mode: ExerciseExecutionMode.aiTracked))
            .kind,
        ExerciseExecutionKind.unavailable);
    expect(resolver.resolve(scope: scope, exercise: row()).kind,
        ExerciseExecutionKind.legacyManual);
    expect(
        resolver
            .resolve(
                scope: scope,
                exercise: row(
                    mode: ExerciseExecutionMode.videoGuidedTimed,
                    reps: null,
                    duration: 45))
            .kind,
        ExerciseExecutionKind.unavailable);
  });
  test(
      'media identity without a matching authoritative stamp stays unavailable',
      () {
    const unstamped = PublishedRoutineExercise(
        exerciseId: 'mobility',
        dayNumber: 1,
        name: 'Mobility',
        category: '',
        sets: 3,
        reps: null,
        durationSeconds: 45,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        cue: '',
        imageUrl: '',
        muscleGroup: '',
        videoUrl: 'https://storage.example/video.mp4',
        mediaGeneration: '123',
        mediaRevision: 1);
    expect(resolver.resolve(scope: scope, exercise: unstamped).kind,
        ExerciseExecutionKind.unavailable);
  });
  test(
      'registered identity preserves installed route and absent implementation explanation',
      () {
    final squat = row(id: 'F3b8xIr8ynBDd3gEICKX');
    final tracked = resolver.resolve(scope: scope, exercise: squat);
    expect(tracked.kind, ExerciseExecutionKind.measured);
    expect(tracked.tracker, ExerciseTracker.sideViewSquat);
    expect(
        const ExerciseExecutionResolver(
                dispatcher: ExerciseTrackerDispatcher(availableTrackers: {}))
            .resolve(scope: scope, exercise: squat)
            .kind,
        ExerciseExecutionKind.unavailable);
  });
}
