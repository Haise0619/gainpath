import 'dart:convert';
import 'dart:io';
import 'package:gainpath_mobile/infrastructure/local/file_routine_journey_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'routine_journey_controller_test.dart' as support;

PublishedRoutine hybridFixture() =>
    PublishedRoutine.fromDocument('routine_v2_mixed', {
      'schemaVersion': 2,
      'kind': 'routine_v2',
      'status': 'published',
      'sourceBlueprintId': 'mixed',
      'title': 'Mixed workout',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'entryId': 'squat',
          'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
          'name': 'Squat',
          'sets': 1,
          'reps': 2,
          'restSeconds': 0,
          'dayNumber': 1,
          'executionMode': 'aiTracked'
        },
        {
          'entryId': 'mobility',
          'exerciseId': 'mobility',
          'name': 'Mobility',
          'sets': 2,
          'durationSeconds': 45,
          'restSeconds': 10,
          'dayNumber': 1,
          'executionMode': 'videoGuidedTimed',
          'videoUrl': 'https://example.com/tutorial.mp4',
          'mediaRevision': 1,
          'mediaGeneration': '123',
          'mediaValidation': {
            'schemaVersion': 1,
            'videoUrl': 'https://example.com/tutorial.mp4',
            'generation': '123',
            'sourceRevision': 1,
            'contentType': 'video/mp4'
          }
        },
        {
          'entryId': 'mobility-again',
          'exerciseId': 'mobility',
          'name': 'Mobility again',
          'sets': 1,
          'durationSeconds': 30,
          'restSeconds': 0,
          'dayNumber': 1,
          'executionMode': 'videoGuidedTimed',
          'videoUrl': 'https://example.com/tutorial.mp4',
          'mediaRevision': 1,
          'mediaGeneration': '123',
          'mediaValidation': {
            'schemaVersion': 1,
            'videoUrl': 'https://example.com/tutorial.mp4',
            'generation': '123',
            'sourceRevision': 1,
            'contentType': 'video/mp4'
          }
        },
      ],
    });

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test(
      'timed evidence retains run identity and omits measured fields in checkpoint projection',
      () async {
    final store = support.MemoryJourneyStore(scope);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
    var id = 0;
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: hybridFixture(),
        store: store,
        workouts: workouts,
        newId: () => 'hybrid-${id++}');
    await c.openDay(1);
    final initial = await c.prepareGuidedSession(1);
    expect((await c.prepareGuidedSession(1)).runId, initial.runId);
    final start = DateTime.now().toUtc().subtract(const Duration(seconds: 100));
    final end = DateTime.now().toUtc();
    final complete = initial.copyWith(
        startedAt: start,
        updatedAt: end,
        endedAt: end,
        phase: GuidedTimedPhase.completed,
        completedSetActiveMicroseconds: [45000000, 45000000]);
    await c.saveGuidedProgress(1, complete);
    expect(c.statusFor(1), RoutineExerciseStatus.timerCompleted);
    expect(c.statusFor(2), RoutineExerciseStatus.notStarted);
    final checkpoint = RoutineCheckpoint.fromJson(
        jsonDecode(jsonEncode(c.checkpoint!.toJson())) as Map<String, dynamic>);
    final directory =
        await Directory.systemTemp.createTemp('hybrid-checkpoints-');
    addTearDown(() => directory.delete(recursive: true));
    final files = FileRoutineJourneyStore(directory: directory, scope: scope);
    await files.save(checkpoint);
    final written = await directory
        .list(recursive: true)
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(written.single.path, contains('routine-journeys-v2'));
    expect((await files.load()).single.guidedProgress[1]!.completedSets, 2);
    final timer = (checkpoint.attempt!.toJson()['entries'] as List)[1] as Map;
    for (final key in [
      'fullRepetitions',
      'partialRepetitions',
      'trackedDurationMicros',
      'manualSets',
      'poseMetrics',
      'formScorePercent',
      'sessionIds'
    ]) {
      expect(timer.containsKey(key), isFalse, reason: key);
    }
    expect((await workouts.loadHistory()), isEmpty);
    final corrupted =
        jsonDecode(jsonEncode(checkpoint.toJson())) as Map<String, dynamic>;
    corrupted['attempt']['entries'][1]['guided']['runId'] = 'different';
    expect(() => RoutineCheckpoint.fromJson(corrupted), throwsFormatException);
    final duplicated =
        jsonDecode(jsonEncode(checkpoint.toJson())) as Map<String, dynamic>;
    final other = {
      ...duplicated['guidedProgress']['1'] as Map<String, dynamic>,
      'entryId': 'mobility-again',
      'entryIndex': 2,
      'prescription': {'sets': 1, 'durationSeconds': 30, 'restSeconds': 0},
      'completedSetActiveMicroseconds': [30000000]
    };
    duplicated['guidedProgress']['2'] = other;
    duplicated['attempt']['entries'][2] = {
      'kind': 'timed',
      'index': 2,
      'status': 'timerCompleted',
      'guided': other
    };
    expect(() => RoutineCheckpoint.fromJson(duplicated), throwsFormatException);
    c.dispose();
    workouts.dispose();
  });
}
