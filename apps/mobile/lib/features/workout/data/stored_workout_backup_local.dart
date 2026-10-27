import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/workout_backup.dart';
import '../domain/workout_contracts.dart';
import '../domain/routine_journey.dart';

class StoredWorkoutBackupLocal implements WorkoutBackupLocal {
  StoredWorkoutBackupLocal(
      {required this.scope,
      required this.activeScope,
      required this.workouts,
      required this.routines}) {
    if (workouts.scope != scope || routines.scope != scope) {
      throw ArgumentError('Backup stores belong to another account');
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutSessionStore workouts;
  final RoutineJourneyStore routines;
  void _check() {
    if (activeScope() != scope) throw StateError('Backup account changed');
  }

  @override
  Future<List<WorkoutBackupRecord>> read() async {
    _check();
    final saved = await workouts.exclusive(() => workouts.read());
    _check();
    final checkpoints = await routines.load();
    _check();
    if (saved.any((s) => s.summary.scope != scope) ||
        checkpoints.any((c) => c.scope != scope)) {
      throw StateError('Backup account mismatch');
    }
    return [
      for (final r in saved)
        if (r.summary.provenance == WorkoutProvenance.realCamera &&
            r.summary.poseMetrics != null)
          WorkoutBackupRecord.session(r.summary),
      for (final c in checkpoints)
        if (c.attempt != null) WorkoutBackupRecord.routine(c)
    ];
  }

  @override
  Future<bool> restore(
      WorkoutBackupRecord record, String? expectedDigest) async {
    _check();
    final validated = WorkoutBackupRecord.parse(
        record.kind, record.id, record.payload, scope);
    if (record.kind == 'session') {
      return workouts.exclusive(() async {
        _check();
        final saved = await workouts.read();
        _check();
        final matches = saved.where((s) => s.summary.sessionId == record.id);
        if (matches.isNotEmpty) {
          return matches.length == 1 &&
              WorkoutBackupRecord.session(matches.single.summary).digest ==
                  record.digest;
        }
        if (expectedDigest != null) return false;
        final summary = WorkoutSessionSummary.fromJson(validated.payload);
        _check();
        await workouts.write([
          ...saved,
          WorkoutSessionRecord(
              summary: summary, status: WorkoutSyncStatus.pending)
        ]);
        _check();
        return true;
      });
    }
    final existing =
        (await routines.load()).where((c) => c.id == record.id).toList();
    _check();
    if (existing.length > 1 ||
        (existing.isEmpty
                ? null
                : WorkoutBackupRecord.routine(existing.single).digest) !=
            expectedDigest) {
      return false;
    }
    if (routines case final RevisionedRoutineJourneyStore store) {
      try {
        _check();
        await store.saveRevision(RoutineCheckpoint.fromJson(validated.payload),
            expectedUpdatedAtMicros:
                existing.isEmpty ? null : existing.single.updatedAtMicros);
        _check();
        return true;
      } on StateError {
        return false;
      }
    }
    return false;
  }
}
