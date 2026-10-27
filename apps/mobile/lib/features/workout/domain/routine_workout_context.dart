/// Immutable display context. Progress remains in the account-scoped checkpoint.
class RoutineWorkoutContext {
  const RoutineWorkoutContext(
      {required this.routineTitle,
      required this.day,
      required this.exerciseNumber,
      required this.totalExercises,
      this.nextExerciseName});
  final String routineTitle;
  final int day, exerciseNumber, totalExercises;
  final String? nextExerciseName;
}
