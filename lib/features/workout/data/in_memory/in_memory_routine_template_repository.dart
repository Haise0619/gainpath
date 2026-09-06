import 'package:gainpath/features/workout/data/in_memory/workout_seed.dart';
import 'package:gainpath/features/workout/domain/entities/routine_blueprint.dart';
import 'package:gainpath/features/workout/domain/repositories/routine_template_repository.dart';

/// Session-scoped in-memory [RoutineTemplateRepository] backed by [WorkoutSeed].
class InMemoryRoutineTemplateRepository implements RoutineTemplateRepository {
  @override
  List<RoutineBlueprint> get routineTemplates => WorkoutSeed.routineTemplates;
}
