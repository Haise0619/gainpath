import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/routine_attempt.dart';
import '../../../domain/workout_contracts.dart';
import '../../workout_presentation.dart';
import 'workout_save_indicator.dart';
import 'workout_completion_visuals.dart';
import 'workout_exercise_image.dart';
import '../../../../../presentation/shared/workout_fact.dart';

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
          : const Duration(milliseconds: 280),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: WorkoutCompletionHero(
          title: title, status: status, detail: detail, complete: complete));
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
      CompletionStatGrid(children: [
        WorkoutFact('${a.completedExercises}/${a.entries.length}', 'Exercises',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF166534),
            tint: AppColors.successTint),
        if (a.entries.any((r) => r.sessionIds.isNotEmpty))
          WorkoutFact('${a.fullRepetitions}', 'AI full reps',
              icon: Icons.sensors_rounded),
        if (a.guidedDurationMicros > 0)
          WorkoutFact(
              workoutDurationLabel(a.guidedDurationMicros), 'Video active time',
              icon: Icons.timer_outlined,
              color: AppColors.accentDark,
              tint: AppColors.accentTint),
        if (a.timerCompletedSets > 0)
          WorkoutFact('${a.timerCompletedSets}', 'Timed sets',
              icon: Icons.play_circle_outline_rounded,
              color: AppColors.info,
              tint: AppColors.infoTint),
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
      Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.hairline)),
          child: ExpansionTile(
              leading:
                  const Icon(Icons.schedule_rounded, color: AppColors.primary),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: const Border(),
              collapsedShape: const Border(),
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
                  const Text(
                      'Completion time unavailable for this older workout.'),
              ])),
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
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.hairline)),
        child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            title: LayoutBuilder(builder: (context, bounds) {
              final completed = result.completed;
              final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                                height: 1.2)),
                    const SizedBox(height: 9),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      CompletionChip(mode.label,
                          icon: mode.icon,
                          color: result.isTimed
                              ? AppColors.info
                              : AppColors.primaryDark,
                          background: result.isTimed
                              ? AppColors.infoTint
                              : AppColors.primaryTint),
                      CompletionChip(
                          completed
                              ? 'Completed'
                              : exerciseStatusLabel(result.status),
                          icon: completed
                              ? Icons.check_rounded
                              : Icons.more_horiz_rounded,
                          color: completed
                              ? const Color(0xFF166534)
                              : AppColors.inkSoft,
                          background: completed
                              ? AppColors.successTint
                              : AppColors.surfaceAlt),
                    ]),
                    const SizedBox(height: 9),
                    Text(
                        result.isTimed
                            ? '${result.guided?.completedSets ?? 0} timed sets · ${workoutDurationLabel(result.guided?.totalActiveMicroseconds ?? 0)} active'
                            : result.sessionIds.isNotEmpty
                                ? '${result.fullRepetitions} full reps · ${result.partialRepetitions} partial reps'
                                : '${result.manualSets} sets · Self-reported',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkSoft, height: 1.4)),
                  ]);
              final stacked = bounds.maxWidth < 245 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final cover = ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                      width: stacked ? double.infinity : 76,
                      height: stacked ? 132 : 112,
                      child: WorkoutExerciseImage(
                          url: exercise.imageUrl, fit: BoxFit.cover)));
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              cover,
                              const SizedBox(height: 12),
                              details
                            ])
                      : Row(children: [
                          cover,
                          const SizedBox(width: 12),
                          Expanded(child: details)
                        ]));
            }),
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
