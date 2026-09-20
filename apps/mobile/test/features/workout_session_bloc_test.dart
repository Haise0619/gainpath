import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/workout_session_bloc.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';

void main() {
  test('late pose inference cannot replace the saved state', () async {
    final detector = _DelayedDetector();
    final repository = InMemoryWorkoutSessionRepository();
    final bloc = WorkoutSessionBloc(repository: repository, detector: detector);
    bloc.add(const WorkoutStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(
        const WorkoutPoseTicked(timestampMicros: 1000, movementMetric: .8));
    await detector.started.future;
    final saved = bloc.stream
        .firstWhere((state) => state.status == WorkoutSessionStatus.saved);
    bloc.add(const WorkoutEnded());
    await saved;
    detector.result.complete(await SimulatedPoseDetector()
        .detect(const PoseInput(timestampMicros: 1000)));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, WorkoutSessionStatus.saved);
    expect((await repository.loadHistory()).single.summary, bloc.state.summary);
    await bloc.close();
  });

  test('failed local save remains retryable with the same frozen summary',
      () async {
    final store = _FailOnceStore();
    final repository = WorkoutSessionRepository(
        scope: store.scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => store.scope);
    final bloc = WorkoutSessionBloc(
        repository: repository, detector: SimulatedPoseDetector());
    bloc.add(const WorkoutStarted());
    await Future<void>.delayed(Duration.zero);
    final failed =
        bloc.stream.firstWhere((state) => state.errorMessage != null);
    final endedAt = DateTime.utc(2027);
    bloc.add(WorkoutEnded(endedAt: endedAt));
    expect((await failed).status, WorkoutSessionStatus.paused);
    expect(await repository.loadHistory(), isEmpty);
    final saved = bloc.stream
        .firstWhere((state) => state.status == WorkoutSessionStatus.saved);
    bloc.add(WorkoutEnded(endedAt: DateTime.utc(2028)));
    await saved;
    expect((await repository.loadHistory()).single.summary.endedAt, endedAt);
    await bloc.close();
  });
  test('tracking recovers after pose loss and repeated finish saves once',
      () async {
    final detector = _RecoveringDetector();
    final repository = InMemoryWorkoutSessionRepository();
    final bloc = WorkoutSessionBloc(repository: repository, detector: detector);
    bloc.add(const WorkoutStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WorkoutPoseTicked(timestampMicros: 0, movementMetric: .8));
    await Future<void>.delayed(Duration.zero);
    bloc.add(
        const WorkoutPoseTicked(timestampMicros: 2000000, movementMetric: .8));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, WorkoutSessionStatus.paused);
    detector.healthy = true;
    bloc.add(
        const WorkoutPoseTicked(timestampMicros: 3000000, movementMetric: .2));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, WorkoutSessionStatus.tracking);
    final saved = bloc.stream
        .firstWhere((state) => state.status == WorkoutSessionStatus.saved);
    bloc.add(const WorkoutEnded());
    bloc.add(const WorkoutEnded());
    await saved;
    final firstSummary = (await repository.loadHistory()).single.summary;
    bloc.add(WorkoutEnded(endedAt: DateTime.utc(2030)));
    await Future<void>.delayed(Duration.zero);
    expect((await repository.loadHistory()).single.summary, firstSummary);
    await bloc.close();
  });
  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'starts a pose session, counts a rep, and saves its summary locally',
    build: () {
      final repository = InMemoryWorkoutSessionRepository();
      return WorkoutSessionBloc(
        repository: repository,
        detector: SimulatedPoseDetector(),
        clock: () => DateTime.utc(2026, 9, 18, 12),
      );
    },
    act: (bloc) async {
      bloc.add(const WorkoutStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const WorkoutPoseTicked(
          timestampMicros: 1000000, movementMetric: 0.8));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const WorkoutPoseTicked(
          timestampMicros: 2000000, movementMetric: 0.2));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const WorkoutEnded());
    },
    expect: () => [
      isA<WorkoutSessionState>().having(
        (state) => state.status,
        'status',
        WorkoutSessionStatus.tracking,
      ),
      isA<WorkoutSessionState>()
          .having((state) => state.repetitions, 'repetitions', 0),
      isA<WorkoutSessionState>()
          .having((state) => state.repetitions, 'repetitions', 1),
      isA<WorkoutSessionState>()
          .having((state) => state.status, 'status', WorkoutSessionStatus.saved)
          .having(
              (state) => state.summary?.repetitions, 'saved repetitions', 1),
    ],
  );

  test('local repository retains completed summaries for later upload',
      () async {
    final repository = InMemoryWorkoutSessionRepository();
    final summary = WorkoutSessionSummary(
      sessionId: 'session-1',
      exerciseId: 'bodyweight_squat',
      repetitions: 8,
      accuracy: 91,
      startedAt: DateTime.utc(2026, 9, 18),
      endedAt: DateTime.utc(2026, 9, 18, 0, 5),
    );

    await repository.saveLocal(summary);

    final history = await repository.loadHistory();
    expect(history.single.summary, summary);
    expect(history.single.status, WorkoutSyncStatus.pending);
  });
}

class _RecoveringDetector implements PoseDetector {
  bool healthy = false;
  @override
  Future<PoseFrame> detect(PoseInput input) async => healthy
      ? SimulatedPoseDetector().detect(input)
      : PoseFrame(
          capturedAtMicros: input.timestampMicros,
          detectorId: 'test',
          modelVersion: '1',
          landmarks: {});
}

class _DelayedDetector implements PoseDetector {
  final started = Completer<void>();
  final result = Completer<PoseFrame>();
  @override
  Future<PoseFrame> detect(PoseInput input) {
    started.complete();
    return result.future;
  }
}

class _FailOnceStore extends InMemoryWorkoutSessionStore {
  bool _failed = false;
  @override
  Future<void> write(List<WorkoutSessionRecord> records) async {
    if (!_failed) {
      _failed = true;
      throw StateError('disk unavailable');
    }
    await super.write(records);
  }
}
