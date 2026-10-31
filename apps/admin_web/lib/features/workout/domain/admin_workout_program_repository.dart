import 'package:gainpath_domain/workout.dart';

class AdminProgramDraft {
  const AdminProgramDraft(this.program, this.revision);
  final WorkoutProgram program;
  final int revision;
}

class ProgramRoutineChoice {
  ProgramRoutineChoice(
      {required this.id, required this.title, required this.snapshot});
  final String id;
  final String title;
  final Map<String, dynamic> snapshot;
  List<int> get days => ((snapshot['exercises'] as List)
      .map((e) => (e as Map)['dayNumber'] as int? ?? 1)
      .toSet()
      .toList()
    ..sort());
}

class AdminProgramCatalog {
  const AdminProgramCatalog(
      {required this.programs, required this.drafts, required this.routines});
  final List<WorkoutProgram> programs;
  final List<AdminProgramDraft> drafts;
  final List<ProgramRoutineChoice> routines;
}

abstract interface class AdminWorkoutProgramRepository {
  bool get current;
  Future<AdminProgramCatalog> load();
  Future<int> saveDraft(WorkoutProgram program,
      {required int expectedRevision, required String requestId});
  Future<AdminProgramDraft> publish(String programId,
      {required int expectedRevision, required String requestId});
}
