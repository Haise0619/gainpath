import '../entities/routine_blueprint.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class RoutineTemplateRepository {
  List<RoutineBlueprint> get routineTemplates;

  Future<List<RoutineBlueprint>> load() async => routineTemplates;

  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    throw UnsupportedError('This repository does not support saving routines.');
  }

  Future<void> publish(String blueprintId) async {
    throw UnsupportedError('This repository does not support publishing routines.');
  }
}
