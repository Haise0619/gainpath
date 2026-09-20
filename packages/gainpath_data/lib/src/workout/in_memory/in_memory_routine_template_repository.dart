import '../../fakes/mock_data_session.dart';
import 'workout_seed.dart';
import 'package:gainpath_domain/workout.dart';

/// Session-scoped in-memory [RoutineTemplateRepository] backed by [WorkoutSeed].
class InMemoryRoutineTemplateRepository implements RoutineTemplateRepository {
  InMemoryRoutineTemplateRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).workout;

  final WorkoutSeed _seed;

  @override
  List<RoutineBlueprint> get routineTemplates => _seed.routineTemplates;
}
