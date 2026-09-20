import '../../fakes/mock_data_session.dart';
import 'workout_seed.dart';
import 'package:gainpath_domain/workout.dart';

/// Session-scoped in-memory [WorkoutRepository] backed by [WorkoutSeed].
class InMemoryWorkoutRepository implements WorkoutRepository {
  InMemoryWorkoutRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).workout;

  final WorkoutSeed _seed;

  @override
  List<Exercise> get routine => _seed.routine;

  @override
  List<String> get voiceCues => _seed.voiceCues;

  @override
  List<WorkoutRecord> get history => _seed.history;

  @override
  int get heightCm => _seed.heightCm;
}
