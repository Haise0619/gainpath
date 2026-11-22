import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/between_exercise_rest_controller.dart';
import '../../domain/published_routine_view.dart';
import '../workout_presentation.dart';
import 'widgets/rest_countdown_dial.dart';
import 'widgets/workout_exercise_image.dart';

class BetweenExerciseRestScreen extends StatefulWidget {
  const BetweenExerciseRestScreen(
      {super.key,
      required this.controller,
      required this.previousExercise,
      required this.upcomingExercise,
      required this.organizationId,
      required this.onViewRoutine,
      this.prescribed = false,
      this.preparationOnly = false,
      this.canContinue = true});
  final BetweenExerciseRestController controller;
  final String previousExercise, organizationId;
  final PublishedRoutineExercise upcomingExercise;
  final VoidCallback onViewRoutine;
  final bool prescribed, preparationOnly, canContinue;
  @override
  State<BetweenExerciseRestScreen> createState() =>
      _BetweenExerciseRestScreenState();
}

class _BetweenExerciseRestScreenState extends State<BetweenExerciseRestScreen> {
  late int _totalSeconds = widget.controller.remainingSeconds;
  @override
  void didUpdateWidget(covariant BetweenExerciseRestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _totalSeconds = widget.controller.remainingSeconds;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final presentation = ExercisePresentation.forExercise(
            widget.upcomingExercise,
            organizationId: widget.organizationId);
        final preparing = c.phase == BetweenExerciseRestPhase.preparing;
        final failed = c.phase == BetweenExerciseRestPhase.failed;
        final theme = Theme.of(context);
        final compact = MediaQuery.sizeOf(context).height < 740 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final headline = !widget.canContinue
            ? 'Workout interrupted'
            : preparing
                ? 'Preparing next exercise'
                : failed
                    ? 'Let’s try again'
                    : c.paused
                        ? 'Workout paused'
                        : 'Take a breath';
        final explanation = !widget.canContinue
            ? 'This workout context is no longer available. Return to your routine to continue safely. Your completed exercise is saved.'
            : failed
                ? 'Could not prepare the next exercise. Resume to try again, or view your routine. Your completed exercise is saved.'
                : c.paused
                    ? 'Resume when you are ready. Tracking will not restart while paused.'
                    : presentation.nextActionDescription;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Workout rest'),
              actions: [
                IconButton(
                    tooltip: 'View routine',
                    onPressed: widget.onViewRoutine,
                    icon: const Icon(Icons.list_alt_rounded))
              ]),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(
                              color: AppColors.successTint,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${widget.previousExercise} complete',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('Progress saved on this device',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ])),
                    ]),
                    SizedBox(height: compact ? 20 : 30),
                    Text(headline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Center(
                        child: RestCountdownDial(
                            seconds: c.remainingSeconds,
                            totalSeconds: _totalSeconds,
                            diameter: compact ? 204 : 248,
                            running: widget.canContinue &&
                                c.phase == BetweenExerciseRestPhase.resting)),
                    const SizedBox(height: 10),
                    Text(
                        widget.preparationOnly
                            ? 'Get ready for the next exercise'
                            : widget.prescribed
                                ? 'Prescribed between-exercise rest'
                                : 'Suggested rest',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    SizedBox(height: compact ? 22 : 30),
                    _UpNextCard(
                        exercise: widget.upcomingExercise,
                        presentation: presentation),
                    const SizedBox(height: 14),
                    Text(explanation,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: failed || !widget.canContinue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant)),
                  ]),
            )),
          ),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14)),
                                onPressed: preparing || !widget.canContinue
                                    ? null
                                    : c.paused || failed
                                        ? c.resume
                                        : c.pause,
                                icon: Icon(c.paused || failed
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded),
                                label: Text(c.paused || failed
                                    ? 'Resume Workout'
                                    : 'Pause Workout')),
                            const SizedBox(height: 10),
                            OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12)),
                                onPressed: preparing || !widget.canContinue
                                    ? null
                                    : () => c.skip(),
                                child: Text(widget.preparationOnly
                                    ? 'Start next exercise now'
                                    : 'Skip Rest')),
                          ]),
                    )),
              )),
        );
      });
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.exercise, required this.presentation});
  final PublishedRoutineExercise exercise;
  final ExercisePresentation presentation;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('UP NEXT',
          style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(exercise.name,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
          spacing: 5,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(presentation.icon, color: AppColors.primary, size: 17),
            Text(presentation.label,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
      const SizedBox(height: 5),
      Text(presentation.targetLabel, style: theme.textTheme.bodyMedium),
    ]);
    Widget cover(double width, double height) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
            width: width,
            height: height,
            child: WorkoutExerciseImage(
                url: exercise.imageUrl, fit: BoxFit.cover)));
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.hairline)),
        child: LayoutBuilder(builder: (context, bounds) {
          final stacked = bounds.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      cover(double.infinity, 132),
                      const SizedBox(height: 14),
                      details
                    ])
              : Row(children: [
                  cover(100, 124),
                  const SizedBox(width: 16),
                  Expanded(child: details)
                ]);
        }));
  }
}
