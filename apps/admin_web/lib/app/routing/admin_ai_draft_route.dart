import 'package:flutter/material.dart';

import '../../features/recommendation/application/admin_ai_drafts.dart';
import '../../features/workout/presentation/admin/exercise_tutorials_screen.dart';
import '../../features/workout/presentation/admin/routine_templates_screen.dart';
import '../../features/workout/presentation/admin/workout_programs_screen.dart';

Future<void> openAdminAiDraft(
    BuildContext context, Map<String, dynamic> draft) async {
  final Widget form = switch (draft['type']) {
    'exercise' => ExerciseTutorialsScreen(initialDraft: aiExerciseSeed(draft)),
    'routine' => RoutineTemplatesScreen(initialDraft: aiRoutineSeed(draft)),
    _ => WorkoutProgramsScreen(
        buildInitialDraft: (id) => aiProgramSeed(draft, id)),
  };
  await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Review AI draft')), body: form)));
}
