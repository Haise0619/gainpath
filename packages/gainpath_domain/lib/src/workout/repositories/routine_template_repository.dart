import '../entities/routine_blueprint.dart';

class RoutineEditConflict implements Exception {
  const RoutineEditConflict();
  @override
  String toString() =>
      'This routine changed. Discard and reload before saving.';
}

class RoutineEditAuthorizationChanged implements Exception {
  const RoutineEditAuthorizationChanged();
  @override
  String toString() => 'Your authorization changed. Sign in again.';
}

class RoutineSaveFailed implements Exception {
  const RoutineSaveFailed();
  @override
  String toString() =>
      'Could not verify the routine save. Reload before retrying.';
}

class RoutinePublishFailed implements Exception {
  const RoutinePublishFailed();
  @override
  String toString() => 'Publication was not verified. Refresh before retrying.';
}

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class RoutineTemplateRepository {
  List<RoutineBlueprint> get routineTemplates;

  Future<List<RoutineBlueprint>> load() async => routineTemplates;

  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    throw UnsupportedError('This repository does not support saving routines.');
  }

  Future<void> publish(String blueprintId) async {
    throw UnsupportedError(
        'This repository does not support publishing routines.');
  }
}

/// Archives a blueprint without modifying published Member snapshots.
abstract interface class RoutineArchivingRepository {
  Future<void> archive(RoutineBlueprint blueprint);
}
