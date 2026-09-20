import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/workout_history_bloc.dart';
import '../domain/workout_contracts.dart';

class MobileWorkoutHistoryScreen extends StatelessWidget {
  const MobileWorkoutHistoryScreen({
    required this.repository,
    super.key,
  });

  final WorkoutRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          WorkoutHistoryBloc(repository)..add(const WorkoutHistoryRequested()),
      child: BlocBuilder<WorkoutHistoryBloc, WorkoutHistoryState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Workout history')),
            body: _HistoryBody(state: state),
            floatingActionButton: state.status == WorkoutHistoryStatus.loaded
                ? FloatingActionButton.extended(
                    onPressed: () => context
                        .read<WorkoutHistoryBloc>()
                        .add(const WorkoutHistorySyncRequested()),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync pending'),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.state});

  final WorkoutHistoryState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == WorkoutHistoryStatus.loading ||
        state.status == WorkoutHistoryStatus.syncing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == WorkoutHistoryStatus.failure) {
      return Center(
          child: Text(state.errorMessage ?? 'Unable to load history.'));
    }
    if (state.records.isEmpty) {
      return const Center(child: Text('No completed workouts yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: state.records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = state.records[index];
        return Card(
          child: ListTile(
            title: Text(record.summary.exerciseId),
            subtitle: Text(
              '${record.summary.repetitions} reps · '
              '${record.summary.accuracy}% form · '
              '${record.summary.endedAt.toLocal()}',
            ),
            trailing: Text(
              record.status == WorkoutSyncStatus.accepted
                  ? 'Accepted'
                  : 'Pending',
            ),
          ),
        );
      },
    );
  }
}
