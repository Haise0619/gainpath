/// One prescribed catalog exercise within a `RoutineDay`. The blueprint
/// persists [exerciseId], sets, and reps; [exerciseName] is joined from the
/// catalog for display and is never copied into the Firebase blueprint.
class RoutineExerciseRef {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;
  const RoutineExerciseRef(this.exerciseName, this.sets, this.reps,
      {this.exerciseId = ''});
}

class RoutineDay {
  final int dayNumber;
  final List<RoutineExerciseRef> exercises;
  const RoutineDay(this.dayNumber, this.exercises);
}

/// AD-M11.4 — an admin-authored `RoutineBlueprint` a coach or member can
/// be assigned. [assignedMembers] is illustrative — no assignment flow
/// is modelled yet — kept purely to give the admin catalogue a sense of
/// which templates are actually in use. [name], [level], and [days] are
/// mutable so the admin Edit form can replace them wholesale on save —
/// simpler than mutating the nested day/exercise structure in place.
class RoutineBlueprint {
  final String id;
  String name;
  String level;
  final int assignedMembers;
  List<RoutineDay> days;
  String goal;
  List<String> tags;
  int sessionDurationMin;
  List<String> equipmentNeeded;
  String imageUrl;
  RoutineBlueprint({
    required this.id,
    required this.name,
    required this.level,
    required this.assignedMembers,
    required this.days,
    this.goal = '',
    this.tags = const [],
    this.sessionDurationMin = 45,
    this.equipmentNeeded = const [],
    this.imageUrl = '',
  });
}
