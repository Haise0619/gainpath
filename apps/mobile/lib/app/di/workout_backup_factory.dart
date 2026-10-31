import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/application/workout_backup_scheduler.dart';
import 'workout_backup_wakeups.dart';
import 'workout_backup_network_opportunities.dart';
import '../../features/workout/application/workout_backup_coordinator.dart';
import '../../features/workout/data/stored_workout_backup_local.dart';
import '../../infrastructure/firebase/firebase_workout_backup_gateway.dart';
import 'workout_store_factory.dart';
import 'workout_backup_store_factory.dart';

const workoutCloudBackupEnabled =
    bool.fromEnvironment('WORKOUT_CLOUD_BACKUP_ENABLED') ||
        bool.fromEnvironment('USE_FIREBASE_EMULATORS');

typedef WorkoutBackupFactory = Future<WorkoutBackupLease> Function(
    SessionScope scope, SessionScope? Function() activeScope);

class WorkoutBackupLease {
  WorkoutBackupLease(this.coordinator, this.release, {this.scheduler});
  final WorkoutBackupCoordinator coordinator;
  final void Function() release;
  final WorkoutBackupScheduler? scheduler;
}

class _SharedBackup {
  _SharedBackup(this.coordinator, this.scopes, this.scheduler, this.wakeups);
  final WorkoutBackupCoordinator coordinator;
  final List<SessionScope? Function()> scopes;
  final WorkoutBackupScheduler scheduler;
  final WorkoutBackupWakeups wakeups;
}

final _shared = <SessionScope, Future<_SharedBackup>>{};
Future<WorkoutBackupLease> acquireWorkoutBackup(
    SessionScope scope, SessionScope? Function() activeScope,
    {Stream<void>? networkOpportunities}) async {
  if (!workoutCloudBackupEnabled) {
    throw UnsupportedError('Cloud backup awaits activation.');
  }
  final future = _shared.putIfAbsent(scope, () async {
    final scopes = <SessionScope? Function()>[];
    SessionScope? current() => scopes.any((s) => s() == scope) ? scope : null;
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: current,
        local: StoredWorkoutBackupLocal(
            scope: scope,
            activeScope: current,
            workouts: await createWorkoutStore(scope),
            routines: await createRoutineJourneyStore(scope)),
        gateway: FirebaseWorkoutBackupGateway(
            scope: scope, activeAccount: () => current() == scope),
        store: await createWorkoutBackupStore(scope));
    final scheduler = WorkoutBackupScheduler(coordinator: c);
    final wakeups = WorkoutBackupWakeups(
        scope: scope,
        activeScope: current,
        scheduler: scheduler,
        networkOpportunities:
            networkOpportunities ?? workoutBackupNetworkOpportunities());
    return _SharedBackup(c, scopes, scheduler, wakeups);
  });
  _SharedBackup shared;
  try {
    shared = await future;
  } catch (_) {
    if (identical(_shared[scope], future)) _shared.remove(scope);
    rethrow;
  }
  shared.scopes.add(activeScope);
  var released = false;
  return WorkoutBackupLease(shared.coordinator, () {
    if (released) return;
    released = true;
    shared.scopes.remove(activeScope);
    if (shared.scopes.isEmpty) {
      if (identical(_shared[scope], future)) _shared.remove(scope);
      shared.wakeups.dispose();
      shared.scheduler.dispose();
      shared.coordinator.dispose();
    } else {
      shared.coordinator.accountChanged();
    }
  }, scheduler: shared.scheduler);
}
