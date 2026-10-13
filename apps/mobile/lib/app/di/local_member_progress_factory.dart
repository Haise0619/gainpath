import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/analytics/data/local_member_progress_repository.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/workout/domain/workout_contracts.dart';
import '../../features/workout/domain/real_workout_sync.dart';
import 'workout_store_factory.dart';
import 'real_workout_sync_store_factory.dart';

Future<LocalMemberProgressRepository> createLocalMemberProgressRepository(
    SessionScope scope, SessionScope? Function() activeScope,
    {Future<WorkoutSessionStore> Function(SessionScope) storeFactory =
        createWorkoutStore,
    Future<RealWorkoutSyncStore> Function(SessionScope) syncStoreFactory =
        createRealWorkoutSyncStore}) async {
  final workoutStore = await storeFactory(scope);
  RealWorkoutSyncStore syncStore;
  try {
    syncStore = await syncStoreFactory(scope);
  } catch (_) {
    syncStore = _UnreadableSyncStore(scope);
  }
  return StoredLocalMemberProgressRepository(
      scope: scope,
      workoutStore: workoutStore,
      syncStore: syncStore,
      activeScope: activeScope);
}

/// Missing status storage is unknown, never an invented empty upload queue.
class _UnreadableSyncStore implements RealWorkoutSyncStore {
  _UnreadableSyncStore(this.scope);
  @override
  final SessionScope scope;
  @override
  Future<T> exclusive<T>(Future<T> Function() action) => action();
  @override
  Future<RealWorkoutSyncState> read() =>
      Future.error(StateError('Upload status storage unavailable'));
  @override
  Future<void> write(RealWorkoutSyncState state) =>
      Future.error(UnsupportedError('Read-only progress'));
}
