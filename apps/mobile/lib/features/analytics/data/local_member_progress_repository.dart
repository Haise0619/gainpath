import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/local_member_progress_repository.dart';
import '../../workout/domain/workout_contracts.dart';
import '../../workout/domain/real_workout_sync.dart';

/// Maps the existing account-owned summary and outbox snapshots without writes.
class StoredLocalMemberProgressRepository
    implements LocalMemberProgressRepository {
  StoredLocalMemberProgressRepository(
      {required this.scope,
      required this.workoutStore,
      required this.syncStore,
      required this.activeScope}) {
    if (workoutStore.scope != scope || syncStore.scope != scope) {
      throw ArgumentError(
          'Progress stores must belong to the current account.');
    }
  }
  @override
  final SessionScope scope;
  final WorkoutSessionStore workoutStore;
  final RealWorkoutSyncStore syncStore;
  final SessionScope? Function() activeScope;
  void _checkActive() {
    if (activeScope() != scope) throw StateError('Progress account changed.');
  }

  @override
  Future<LocalMemberProgressSnapshot> load() async {
    _checkActive();
    final local = await workoutStore.exclusive(() => workoutStore.read());
    _checkActive();
    if (local.any((r) => r.summary.scope != scope)) {
      throw StateError('Stored progress belongs to another account.');
    }
    RealWorkoutSyncState? sync;
    final warnings = <String>[];
    try {
      final snapshot = await syncStore.exclusive(() => syncStore.read());
      snapshot.validateScope(scope);
      sync = snapshot;
    } catch (_) {
      _checkActive();
      warnings.add(
          'Upload status could not be read. Local measurements are still shown.');
    }
    _checkActive();
    final records = <LocalWorkoutProgressRecord>[];
    final summaries = <String, WorkoutSessionSummary>{};
    for (final record in local) {
      final s = record.summary, m = s.poseMetrics;
      if (s.provenance != WorkoutProvenance.realCamera || m == null) continue;
      try {
        record.validateForLocalStorage();
        if (!s.endedAt.isAfter(s.startedAt)) {
          throw const FormatException('Incomplete local session.');
        }
        final existing = summaries[s.sessionId];
        if (existing != null && existing != s) {
          throw StateError('Conflicting local session identity.');
        }
        if (existing != null) continue;
        final entry = sync?.entries
            .where((e) => e.submission.sessionId == s.sessionId)
            .firstOrNull;
        var status = sync == null
            ? LocalWorkoutRecordStatus.unknown
            : LocalWorkoutRecordStatus.localOnly;
        String? failure;
        DateTime? acceptedAt;
        if (entry != null) {
          if (!_matches(s, entry)) {
            status = LocalWorkoutRecordStatus.unknown;
            warnings.add(
                'A saved result has conflicting upload metadata. Its acceptance is unavailable.');
          } else {
            status = switch (entry.status) {
              RealWorkoutSyncStatus.pending => LocalWorkoutRecordStatus.pending,
              RealWorkoutSyncStatus.retryable =>
                LocalWorkoutRecordStatus.retryable,
              RealWorkoutSyncStatus.rejected =>
                LocalWorkoutRecordStatus.rejected,
              RealWorkoutSyncStatus.accepted =>
                LocalWorkoutRecordStatus.accepted,
            };
            failure = entry.failureCode;
            acceptedAt = entry.acceptance == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    entry.acceptance!.acceptedAtMillis,
                    isUtc: true);
          }
        } else if (sync?.captureIntents[s.sessionId] case final ack?) {
          final grant = ack.toJson();
          status = grant['consentVersion'] == m.consentVersion &&
                  ack.acknowledgedAtMillis <= s.startedAt.millisecondsSinceEpoch
              ? LocalWorkoutRecordStatus.pending
              : LocalWorkoutRecordStatus.unknown;
        }
        final mapped = LocalWorkoutProgressRecord(
            scope: scope,
            sessionId: s.sessionId,
            exerciseId: s.exerciseId,
            startedAt: s.startedAt,
            endedAt: s.endedAt,
            repetitions: s.repetitions,
            partialRepetitions: s.partialRepetitions,
            formScorePercent: s.formScorePercent,
            trackedDurationMicros: s.trackedDurationMicros,
            rejectedDurationMicros: s.rejectedDurationMicros,
            scoringVersion: m.scoringVersion,
            detectorId: m.detectorId,
            detectorVersion: m.detectorVersion,
            cameraView: m.cameraView,
            status: status,
            failureCode: failure,
            acceptedAt: acceptedAt);
        records.add(mapped);
        summaries[s.sessionId] = s;
      } on FormatException {
        warnings
            .add('An incomplete measured record was excluded from progress.');
      } on ArgumentError {
        warnings
            .add('An incomplete measured record was excluded from progress.');
      }
    }
    _checkActive();
    return LocalMemberProgressSnapshot(
        records: records, summaries: summaries, warnings: warnings.toSet());
  }

  bool _matches(WorkoutSessionSummary s, RealWorkoutSyncEntry entry) {
    final m = s.poseMetrics!, p = entry.submission.toJson();
    final expected = <String, Object?>{
      'organizationId': s.organizationId,
      'memberId': s.userId,
      'sessionId': s.sessionId,
      'exerciseId': s.exerciseId,
      'publishedRoutineId': m.publishedRoutineId,
      'startedAtMillis': s.startedAt.millisecondsSinceEpoch,
      'endedAtMillis': s.endedAt.millisecondsSinceEpoch,
      'repetitions': s.repetitions,
      'formScorePercent': s.formScorePercent,
      'trackedDurationMillis': s.trackedDurationMicros ~/ 1000,
      'rejectedDurationMillis': s.rejectedDurationMicros ~/ 1000,
      'scoringVersion': m.scoringVersion,
      'detectorId': m.detectorId,
      'detectorVersion': m.detectorVersion,
      'cameraView': m.cameraView,
      'consentVersion': m.consentVersion,
      'provenance': 'real_camera'
    };
    return expected.entries.every((e) => p[e.key] == e.value) &&
        (entry.status != RealWorkoutSyncStatus.accepted ||
            entry.acceptance != null &&
                entry.acceptance!.matches(entry.submission));
  }
}
