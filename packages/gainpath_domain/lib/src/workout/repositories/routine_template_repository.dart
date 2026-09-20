import '../entities/routine_blueprint.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class RoutineTemplateRepository {
  List<RoutineBlueprint> get routineTemplates;
}
