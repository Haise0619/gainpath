import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../workout/domain/workout_contracts.dart';
import '../../workout/domain/routine_attempt.dart';

/// Read model only. Loading progress never opts in, queues, or uploads activity.
class LocalMemberProgressSnapshot {
  LocalMemberProgressSnapshot(
      {required Iterable<LocalWorkoutProgressRecord> records,
      Map<String, WorkoutSessionSummary> summaries = const {},
      Iterable<String> warnings = const [],
      Iterable<RoutineAttempt> attempts = const [],
      this.routineHistoryAvailable = false})
      : attempts = List.unmodifiable(attempts),
        records = List.unmodifiable(records),
        summaries = Map.unmodifiable(summaries),
        warnings = List.unmodifiable(warnings);
  final List<LocalWorkoutProgressRecord> records;
  final Map<String, WorkoutSessionSummary> summaries;
  final List<String> warnings;
  final List<RoutineAttempt> attempts;
  final bool routineHistoryAvailable;
}

abstract interface class LocalMemberProgressRepository {
  SessionScope get scope;
  Future<LocalMemberProgressSnapshot> load();
}

typedef LocalMemberProgressRepositoryFactory
    = Future<LocalMemberProgressRepository> Function(
        SessionScope scope, SessionScope? Function() activeScope);
