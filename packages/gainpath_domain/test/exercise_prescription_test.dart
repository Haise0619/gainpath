import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('timed targets round trip without invented repetitions', () {
    final target =
        TimedPrescription(sets: 3, durationSeconds: 45, restSeconds: 30);
    expect(
        target.toJson(), {'sets': 3, 'durationSeconds': 45, 'restSeconds': 30});
    final decoded = ExercisePrescription.fromJson(target.toJson());
    expect(decoded, isA<TimedPrescription>());
    expect(decoded.toJson(), target.toJson());
  });
  test('bounds and mixed target variants fail closed', () {
    for (final change in [
      {'sets': 0},
      {'sets': 51},
      {'durationSeconds': 0},
      {'durationSeconds': 3601},
      {'restSeconds': -1},
      {'restSeconds': 601},
      {'sets': 50, 'durationSeconds': 1800},
      {'reps': 8},
    ]) {
      expect(
          () => ExercisePrescription.fromJson({
                'sets': 3,
                'durationSeconds': 45,
                'restSeconds': 30,
                ...change,
              }),
          throwsFormatException);
    }
  });
  test(
      'repetition target retains its wire field and validates authoring limits',
      () {
    final target =
        RepetitionPrescription(sets: 3, repetitions: 8, restSeconds: 60);
    expect(target.toJson(), {'sets': 3, 'reps': 8, 'restSeconds': 60});
    expect(
        () => RepetitionPrescription(sets: 3, repetitions: 101, restSeconds: 60)
            .validate(),
        throwsFormatException);
    expect(() => ExerciseExecutionMode.fromJson('copiedTracker'),
        throwsFormatException);
  });
}
