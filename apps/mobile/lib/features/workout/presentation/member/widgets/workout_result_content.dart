import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/routine_attempt.dart';
import '../../../domain/workout_contracts.dart';
import '../../workout_presentation.dart';
import 'workout_save_indicator.dart';

const supportedFormRules = {
  'bodyweight-squat-side-v1', 'single-arm-curl-side-v1',
  'standing-calf-raise-side-v1', 'standard-floor-push-up-side-v1',
  // Historical assessed records remain inspectable after catalog retirement.
  'wall-push-up-side-v1',
};
bool hasSupportedForm(WorkoutSessionSummary summary) =>
    supportedFormRules.contains(summary.poseMetrics?.scoringVersion) &&
    summary.formScorePercent != null;

String measuredExerciseTitle(WorkoutSessionSummary s) =>
    switch (s.poseMetrics?.scoringVersion) {
      'bodyweight-squat-side-v1' => 'Squat',
      'single-arm-curl-side-v1' => 'Biceps Curl',
      'standing-calf-raise-side-v1' => 'Calf Raise',
      'standard-floor-push-up-side-v1' => 'Floor Push-up',
      'standing-lateral-raise-front-v1' => 'Lateral Raise',
      'dumbbell-shoulder-press-front-v1' => 'Shoulder Press',
      'wall-push-up-side-v1' => 'Wall Push-up',
      'single-arm-row-side-v1' => 'Dumbbell Row',
      'reverse-lunge-side-v1' => 'Reverse Lunge',
      _ => 'Saved exercise',
    };

String savedFormLabel(WorkoutSessionSummary summary) =>
    hasSupportedForm(summary)
        ? '${summary.formScorePercent!.toStringAsFixed(0)}% estimated form'
        : !supportedFormRules.contains(summary.poseMetrics?.scoringVersion)
            ? 'Form assessment not available for this exercise.'
            : summary.repetitions + summary.partialRepetitions == 0
                ? 'No movements assessed yet'
                : 'Not enough evidence for a form assessment';

String workoutSavedDate(int micros) {
  final d = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
      .add(const Duration(hours: 8));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year} · '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} MYT';
}

class WorkoutCompletionHeader extends StatelessWidget {
  const WorkoutCompletionHeader(
      {super.key,
      required this.title,
      required this.status,
      required this.detail,
      this.complete = false});
  final String title, status, detail;
  final bool complete;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  complete
                      ? Icons.task_alt_rounded
                      : Icons.fitness_center_rounded,
                  color: AppColors.primary,
                  size: 28),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(status,
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)))
            ]),
            const SizedBox(height: 14),
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(color: AppColors.inkSoft)),
          ])));
}

class WorkoutFact extends StatelessWidget {
  const WorkoutFact(this.value, this.label, {super.key});
  final String value, label;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minWidth: 110),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.inkSoft)),
          ])));
}

class RoutineCompletionContent extends StatelessWidget {
  const RoutineCompletionContent(
      {super.key,
      required this.attempt,
      this.summaries = const [],
      this.saveStatus,
      this.onOpenSession,
      this.availableSessionIds});
  final RoutineAttempt attempt;
  final List<WorkoutSessionSummary> summaries;
  final Widget? saveStatus;
  final ValueChanged<String>? onOpenSession;
  final Set<String>? availableSessionIds;
  @override
  Widget build(BuildContext context) {
    final a = attempt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WorkoutCompletionHeader(
          title: routineDayTitle(a.routine, a.day),
          status: a.isComplete
              ? 'Workout complete'
              : a.finished
                  ? 'Workout partially completed'
                  : 'Workout in progress',
          complete: a.isComplete,
          detail:
              '${a.completedExercises}/${a.entries.length} exercises completed'
              '${a.finishedAtMicros == null ? '' : '\n${workoutSavedDate(a.finishedAtMicros!)}'}'),
      saveStatus ?? const WorkoutSaveIndicator(),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        WorkoutFact('${a.completedExercises}/${a.entries.length}', 'Exercises'),
        if (a.entries.any((r) => r.sessionIds.isNotEmpty))
          WorkoutFact('${a.fullRepetitions}', 'AI full reps'),
        if (a.guidedDurationMicros > 0)
          WorkoutFact(workoutDurationLabel(a.guidedDurationMicros),
              'Video active time'),
        if (a.timerCompletedSets > 0)
          WorkoutFact('${a.timerCompletedSets}', 'Timed sets'),
        if (a.selfReportedSets > 0)
          WorkoutFact('${a.selfReportedSets}', 'self-reported sets'),
      ]),
      const SizedBox(height: 24),
      Text('Your exercises', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final result in a.entries)
        WorkoutExerciseResultCard(
            attempt: a,
            result: result,
            summaries: summaries,
            onOpenSession: onOpenSession,
            availableSessionIds: availableSessionIds),
      const SizedBox(height: 12),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Workout timing'),
          children: [
            if (a.startedAtMicros != null)
              Text('Started ${workoutSavedDate(a.startedAtMicros!)}'),
            if (a.finishedAtMicros != null)
              Text('Ended ${workoutSavedDate(a.finishedAtMicros!)}'),
            if (a.elapsedDurationMicros != null)
              Text(
                  '${workoutDurationLabel(a.elapsedDurationMicros!)} elapsed · includes breaks and time away'),
            if (a.finished && a.finishedAtMicros == null)
              const Text('Completion time unavailable for this older workout.'),
          ]),
    ]);
  }
}

class WorkoutExerciseResultCard extends StatelessWidget {
  const WorkoutExerciseResultCard(
      {super.key,
      required this.attempt,
      required this.result,
      this.summaries = const [],
      this.onOpenSession,
      this.availableSessionIds});
  final RoutineAttempt attempt;
  final RoutineExerciseResult result;
  final List<WorkoutSessionSummary> summaries;
  final ValueChanged<String>? onOpenSession;
  final Set<String>? availableSessionIds;
  @override
  Widget build(BuildContext context) {
    final exercise = attempt.routine.exercises[result.index];
    final mode = ExercisePresentation.forExercise(exercise,
        organizationId: attempt.scope.organizationId);
    final records = summaries.where((s) =>
        s.scope == attempt.scope &&
        s.exerciseId == exercise.exerciseId &&
        result.sessionIds.contains(s.sessionId));
    return Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(mode.icon, color: AppColors.primary),
            title: Text(exercise.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mode.label),
              Text(exerciseStatusLabel(result.status)),
              Text(result.isTimed
                  ? '${result.guided?.completedSets ?? 0} timed sets · ${workoutDurationLabel(result.guided?.totalActiveMicroseconds ?? 0)} active'
                  : result.sessionIds.isNotEmpty
                      ? '${result.fullRepetitions} full reps · ${result.partialRepetitions} partial reps'
                      : '${result.manualSets} sets · Self-reported'),
            ]),
            children: [
              Align(alignment: Alignment.centerLeft, child: Text(mode.label)),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(exerciseResultSummary(result))),
              if (result.isTimed)
                const Text(
                    'Timer recorded. Repetitions and form were not assessed.'),
              for (final record in records) ...[
                const SizedBox(height: 10),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(savedFormLabel(record),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if (record.poseMetrics?.curlArms case final arms?)
                  Text('${arms.mode.label} · ${arms.countLabel}'),
              ],
              if (onOpenSession != null)
                for (final id in result.sessionIds.where((id) =>
                    availableSessionIds == null ||
                    availableSessionIds!.contains(id)))
                  TextButton.icon(
                      onPressed: () => onOpenSession!(id),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('View exercise details')),
            ]));
  }
}
