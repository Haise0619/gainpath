import 'package:gainpath/features/workout/data/in_memory/workout_seed.dart';
import 'package:gainpath/features/workout/domain/entities/exercise.dart';
import 'package:gainpath/features/workout/domain/entities/workout_record.dart';
import 'package:gainpath/features/workout/domain/repositories/workout_repository.dart';

/// Session-scoped in-memory [WorkoutRepository] backed by [WorkoutSeed].
class InMemoryWorkoutRepository implements WorkoutRepository {
  @override
  List<Exercise> get routine => WorkoutSeed.routine;

  @override
  List<String> get voiceCues => WorkoutSeed.voiceCues;

  @override
  List<WorkoutRecord> get history => WorkoutSeed.history;

  @override
  int get heightCm => WorkoutSeed.heightCm;
}
