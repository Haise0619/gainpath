import 'package:test/test.dart';
import 'package:gainpath_data/src/workout/in_memory/in_memory_workout_repository.dart';

void main() {
  test('InMemoryWorkoutRepository serves seed data', () {
    final repo = InMemoryWorkoutRepository();
    expect(repo.routine, isNotEmpty);
    expect(repo.voiceCues, isNotEmpty);
    expect(repo.history, isNotEmpty);
  });
}
