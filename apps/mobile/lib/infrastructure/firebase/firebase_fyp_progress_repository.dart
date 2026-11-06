import 'dart:convert';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/workout/domain/workout_contracts.dart';

/// Read-only fictional projection. This class never opens or writes local
/// workout, SQLite, outbox, backup or accepted-workout repositories.
class FirebaseFypProgressRepository implements LocalMemberProgressRepository {
  FirebaseFypProgressRepository(this.transport);
  final ScopedCommandTransport transport;
  @override
  SessionScope get scope => transport.scope;
  @override
  Future<LocalMemberProgressSnapshot> load() async {
    if (scope.datasetScope == null) throw StateError('Dataset scope required.');
    final records = <LocalWorkoutProgressRecord>[];
    final summaries = <String, WorkoutSessionSummary>{};
    final serialized = <String, String>{};
    String? cursor;
    for (var page = 0; page < 40; page++) {
      final raw = await transport.map('member.history', {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        if (cursor != null) 'afterKey': cursor
      });
      if (raw['schemaVersion'] != 1 ||
          raw['fictional'] != true ||
          raw['provenance'] != 'recordedFixture' ||
          raw['records'] is! List ||
          (raw['records'] as List).length > 100) {
        throw const FormatException('Invalid fictional history.');
      }
      for (final entry in raw['records'] as List) {
        if (entry is! Map ||
            entry['kind'] != 'session' ||
            entry['payload'] is! Map) {
          throw const FormatException('Invalid fictional observation.');
        }
        final s = WorkoutSessionSummary.fromJson(
            Map<String, Object?>.from(entry['payload'] as Map));
        final m = s.poseMetrics;
        if (s.userId != scope.userId ||
            s.organizationId != scope.organizationId ||
            s.provenance != WorkoutProvenance.recordedFixture ||
            m == null ||
            !s.endedAt.isAfter(s.startedAt)) {
          throw const FormatException(
              'Invalid fictional observation ownership.');
        }
        final json = jsonEncode(s.toJson());
        if (serialized.containsKey(s.sessionId)) {
          if (serialized[s.sessionId] != json) {
            throw const FormatException('Conflicting observations.');
          }
          continue;
        }
        serialized[s.sessionId] = json;
        summaries[s.sessionId] = s;
        records.add(LocalWorkoutProgressRecord(
            scope: scope,
            sessionId: s.sessionId,
            exerciseId: s.exerciseId,
            startedAt: s.startedAt,
            endedAt: s.endedAt,
            repetitions: s.repetitions,
            partialRepetitions: s.partialRepetitions,
            trackedDurationMicros: s.trackedDurationMicros,
            rejectedDurationMicros: s.rejectedDurationMicros,
            formScorePercent: s.formScorePercent,
            scoringVersion: m.scoringVersion,
            detectorId: m.detectorId,
            detectorVersion: m.detectorVersion,
            cameraView: m.cameraView,
            status: LocalWorkoutRecordStatus.unknown));
      }
      final next = raw['nextCursor'];
      if (next == null) {
        return LocalMemberProgressSnapshot(
            records: records,
            summaries: summaries,
            warnings: const [
              'Fictional dataset observations · recorded fixtures, not physical camera workouts. Read-only; device history is unchanged.'
            ]);
      }
      if (next is! String ||
          next == cursor ||
          next.isEmpty ||
          next.length > 256) {
        throw const FormatException('Invalid fictional history cursor.');
      }
      cursor = next;
    }
    throw StateError('Fictional history exceeds its bound.');
  }
}
