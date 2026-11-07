import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/between_exercise_rest_controller.dart';
import '../../domain/published_routine_view.dart';
import '../workout_presentation.dart';

class BetweenExerciseRestScreen extends StatelessWidget {
  const BetweenExerciseRestScreen(
      {super.key,
      required this.controller,
      required this.previousExercise,
      required this.upcomingExercise,
      required this.organizationId,
      required this.onViewRoutine,
      this.prescribed = false,
      this.canContinue = true});
  final BetweenExerciseRestController controller;
  final String previousExercise, organizationId;
  final PublishedRoutineExercise upcomingExercise;
  final VoidCallback onViewRoutine;
  final bool prescribed;
  final bool canContinue;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final seconds = controller.remainingSeconds;
        final countdown = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(seconds % 60).toString().padLeft(2, '0')}';
        final presentation = ExercisePresentation.forExercise(upcomingExercise,
            organizationId: organizationId);
        final preparing =
            controller.phase == BetweenExerciseRestPhase.preparing;
        final failed = controller.phase == BetweenExerciseRestPhase.failed;
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
        return Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Workout rest'),
              actions: [
                IconButton(
                    tooltip: 'View routine',
                    onPressed: onViewRoutine,
                    icon: const Icon(Icons.list_alt_rounded))
              ]),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!largeText)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 36),
                    const SizedBox(height: 8),
                    if (!largeText)
                      Text('$previousExercise complete',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                        largeText
                            ? '$previousExercise complete · Saved on this device'
                            : 'Progress saved on this device',
                        textAlign: TextAlign.center,
                        style: largeText
                            ? Theme.of(context).textTheme.bodyMedium
                            : null),
                    SizedBox(height: largeText ? 12 : 28),
                    Text(
                        !canContinue
                            ? 'Workout interrupted'
                            : preparing
                                ? 'Preparing next exercise'
                                : controller.paused
                                    ? 'Workout paused'
                                    : 'Take a breath',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (largeText) ...[
                      const SizedBox(height: 8),
                      Text('Up next: ${upcomingExercise.name}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                    const SizedBox(height: 12),
                    Semantics(
                        label: '$seconds seconds rest remaining',
                        child: ExcludeSemantics(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(countdown,
                                    textScaler: TextScaler.noScaling,
                                    style: const TextStyle(
                                        fontSize: 88,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary))))),
                    Text(
                        prescribed
                            ? 'Prescribed between-exercise rest'
                            : 'Suggested rest · Change in Workout Preferences',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Eyebrow('Up next'),
                          const SizedBox(height: 8),
                          Text(upcomingExercise.name,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(presentation.icon,
                                    color: AppColors.primary),
                                Text(presentation.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary))
                              ]),
                          const SizedBox(height: 8),
                          Text(presentation.targetLabel),
                          const SizedBox(height: 12),
                          Text(presentation.description),
                        ])),
                    const SizedBox(height: 16),
                    Text(
                        !canContinue
                            ? 'This workout context is no longer available. Return to your routine to continue safely. Your completed exercise is saved.'
                            : failed
                                ? 'Could not prepare the next exercise. Resume to try again, or view your routine. Your completed exercise is saved.'
                                : controller.paused
                                    ? 'Resume when you are ready. Tracking will not restart while paused.'
                                    : 'Your next exercise opens after rest. Any required setup still applies.',
                        textAlign: TextAlign.center),
                  ])),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56)),
                            onPressed: preparing || !canContinue
                                ? null
                                : (controller.paused || failed)
                                    ? controller.resume
                                    : controller.pause,
                            icon: Icon(controller.paused || failed
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded),
                            label: Text(controller.paused || failed
                                ? 'Resume Workout'
                                : 'Pause Workout')),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56)),
                            onPressed: preparing || !canContinue
                                ? null
                                : () => controller.skip(),
                            child: const Text('Skip Rest')),
                      ]))),
        );
      });
}
