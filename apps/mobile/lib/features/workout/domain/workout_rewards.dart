import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'routine_attempt.dart';

/// A reference for a future server status read, never client earning evidence.
class WorkoutRewardAttemptReference {
  WorkoutRewardAttemptReference(
      {required this.scope,
      required this.attemptId,
      required this.routineId,
      required this.day}) {
    // Local history predates the future transport's stricter identifier format.
    if (attemptId.isEmpty ||
        routineId.isEmpty ||
        scope.organizationId.isEmpty ||
        scope.userId.isEmpty ||
        day < 1 ||
        day > 9007199254740991) {
      throw ArgumentError('Invalid workout reward attempt reference.');
    }
  }
  factory WorkoutRewardAttemptReference.fromAttempt(RoutineAttempt attempt) =>
      WorkoutRewardAttemptReference(
          scope: attempt.scope,
          attemptId: attempt.id,
          routineId: attempt.routine.id,
          day: attempt.day);
  final SessionScope scope;
  final String attemptId, routineId;
  final int day;
  Map<String, dynamic> toStatusFields() => {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'action': 'status',
        'attemptId': attemptId,
        'routineId': routineId,
        'day': day,
      };
}

abstract interface class WorkoutRewardStatusRepository {
  bool get current;
  Future<WorkoutRewardStatus> status(WorkoutRewardAttemptReference attempt);
}

const workoutRewardsPhysicalHold = WorkoutRewardStatus(
    status: 'disabled', reason: 'physical_validation_required');

/// Normal completion uses this local hold. It has no transport or award method.
class DisabledWorkoutRewardsRepository
    implements WorkoutRewardStatusRepository {
  const DisabledWorkoutRewardsRepository(
      {required this.scope, required this.isCurrent});
  final SessionScope scope;
  final bool Function() isCurrent;
  @override
  bool get current => isCurrent();
  @override
  Future<WorkoutRewardStatus> status(
      WorkoutRewardAttemptReference attempt) async {
    if (!current || attempt.scope != scope) {
      throw StateError('Workout account changed.');
    }
    return workoutRewardsPhysicalHold;
  }
}
