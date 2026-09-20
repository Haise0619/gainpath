import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/workout_history_bloc.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';

void main() {
  final summary = WorkoutSessionSummary(
    sessionId: 'session-1',
    exerciseId: 'bodyweight_squat',
    repetitions: 8,
    accuracy: 91,
    startedAt: DateTime.utc(2026, 9, 18),
    endedAt: DateTime.utc(2026, 9, 18, 0, 5),
  );

  test('loads local history without requiring a network connection', () async {
    final repository = InMemoryWorkoutSessionRepository();
    await repository.saveLocal(summary);
    final bloc = WorkoutHistoryBloc(repository);
    final loaded = bloc.stream.firstWhere(
      (state) => state.status == WorkoutHistoryStatus.loaded,
    );

    bloc.add(const WorkoutHistoryRequested());

    expect((await loaded).records.single.summary, summary);
    await bloc.close();
  });

  test('sync event exposes an accepted record to the history state', () async {
    final repository = InMemoryWorkoutSessionRepository(
      uploadGateway: InMemoryWorkoutUploadGateway(),
    );
    await repository.saveLocal(summary);
    final bloc = WorkoutHistoryBloc(repository);

    bloc.add(const WorkoutHistorySyncRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.records.single.status, WorkoutSyncStatus.accepted);
    await bloc.close();
  });
}
