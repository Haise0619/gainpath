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

  @override
  Future<List<RoutineBlueprint>> load() async => routineTemplates;

  @override
  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    final index =
        _seed.routineTemplates.indexWhere((item) => item.id == blueprint.id);
    if (index < 0) {
      _seed.routineTemplates.add(blueprint);
    } else {
      _seed.routineTemplates[index] = blueprint;
    }
    return blueprint;
  }

  @override
  Future<void> publish(String blueprintId) async {
    if (!_seed.routineTemplates.any((item) => item.id == blueprintId)) {
      throw StateError('Routine blueprint not found.');
    }
  }
}
