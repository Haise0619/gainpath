import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../application/workout_session_bloc.dart';
import '../domain/workout_contracts.dart';
import 'workout_history_screen.dart';

class MobileWorkoutScreen extends StatelessWidget {
  const MobileWorkoutScreen(
      {required this.repository,
      required this.detector,
      this.simulated = false,
      super.key});

  final WorkoutRepository repository;
  final PoseDetector detector;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WorkoutSessionBloc(
        repository: repository,
        detector: detector,
      )..add(const WorkoutStarted()),
      child: _WorkoutView(simulated: simulated),
    );
  }
}

class _WorkoutView extends StatefulWidget {
  const _WorkoutView({required this.simulated});
  final bool simulated;

  @override
  State<_WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<_WorkoutView> {
  bool _downPhase = false;

  void _simulatePoseTick() {
    setState(() => _downPhase = !_downPhase);
    context.read<WorkoutSessionBloc>().add(
          WorkoutPoseTicked(
            timestampMicros: DateTime.now().microsecondsSinceEpoch,
            movementMetric: _downPhase ? 0.8 : 0.2,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      builder: (context, state) {
        final exercise = state.plan.exercises.first;
        final saved = state.status == WorkoutSessionStatus.saved;
        return Scaffold(
          appBar: AppBar(title: const Text('Guided workout')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(exercise.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (widget.simulated)
                      const Text('Simulation only — no camera or real pose inference is active.'),
                    const SizedBox(height: 8),
                    Text(
                        '${exercise.sets} sets · ${exercise.repetitions} reps'),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('${state.repetitions}',
                                style:
                                    Theme.of(context).textTheme.displayMedium),
                            const Text('repetitions'),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                                value: state.accuracy == 0
                                    ? null
                                    : state.accuracy / 100),
                            const SizedBox(height: 8),
                            Text(
                                'Tracking ${state.trackingConfidence}% · Form ${state.accuracy}%'),
                          ],
                        ),
                      ),
                    ),
                    if (state.status == WorkoutSessionStatus.paused) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Tracking paused because the pose could not be confirmed.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (saved) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Saved locally. It will be uploaded when workout sync is connected.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (state.errorMessage != null) Text(state.errorMessage!),
                    if (!saved && widget.simulated)
                      FilledButton(
                        onPressed: _simulatePoseTick,
                        child: Text(
                            _downPhase ? 'Move up' : 'Simulate rep movement'),
                      ),
                    if (!saved) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context
                            .read<WorkoutSessionBloc>()
                            .add(const WorkoutEnded()),
                        child: const Text('Finish and save locally'),
                      ),
                    ] else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MobileWorkoutHistoryScreen(
                                  repository: context
                                      .read<WorkoutSessionBloc>()
                                      .repository,
                                ),
                              ),
                            ),
                            child: const Text('View workout history'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to session home'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
