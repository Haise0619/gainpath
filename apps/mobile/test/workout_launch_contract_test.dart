import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

void main() {
  test(
      'measured launch exposes validated repetition targets and rejects timers',
      () {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    RealWorkoutLaunch launch(int? reps, {int? seconds}) => RealWorkoutLaunch(
        scope: scope,
        routineId: 'routine',
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        exercise: PublishedRoutineExercise(
            exerciseId: 'F3b8xIr8ynBDd3gEICKX',
            dayNumber: 1,
            name: 'Squat',
            category: '',
            sets: 3,
            reps: reps,
            durationSeconds: seconds,
            cue: '',
            imageUrl: '',
            muscleGroup: ''));
    expect(launch(8).repetitionTarget.repetitions, 8);
    expect(() => launch(null, seconds: 45).repetitionTarget, throwsStateError);
    expect(() => launch(0).repetitionTarget, throwsFormatException);
    expect(launch(8).repetitionTarget, isA<RepetitionPrescription>());
  });
}
