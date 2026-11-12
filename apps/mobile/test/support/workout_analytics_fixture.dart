import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';

/// Coherent synthetic evidence. Never accesses a device or Firebase account.
class WorkoutAnalyticsFixture {
  final scope =
      SessionScope(userId: 'analytics-fixture', organizationId: 'gainpath');
  final start = DateTime.utc(2026, 11, 12, 2);
  DateTime get now => start.add(const Duration(minutes: 10));
  late final routine = PublishedRoutine.fromDocument('analytics-mixed', {
    'schemaVersion': 2,
    'kind': 'routine_v2',
    'status': 'published',
    'sourceBlueprintId': 'analytics-fixture',
    'title': 'Everyday Strength',
    'estimatedMinutes': 15,
    'exercises': [
      {
        'entryId': 'squat',
        'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
        'name': 'Squat',
        'sets': 1,
        'reps': 10,
        'restSeconds': 0,
        'dayNumber': 1,
        'executionMode': 'aiTracked'
      },
      {
        'entryId': 'burpee',
        'exerciseId': 'burpee-video',
        'name': 'Burpee',
        'sets': 2,
        'durationSeconds': 45,
        'restSeconds': 15,
        'dayNumber': 1,
        'executionMode': 'videoGuidedTimed',
        'videoUrl': 'https://example.com/burpee.mp4',
        'mediaRevision': 1,
        'mediaGeneration': '123',
        'mediaValidation': {
          'schemaVersion': 1,
          'videoUrl': 'https://example.com/burpee.mp4',
          'generation': '123',
          'sourceRevision': 1,
          'contentType': 'video/mp4'
        }
      },
      {
        'entryId': 'press',
        'exerciseId': 'dumbbell-shoulder-press-front-v1',
        'name': 'Shoulder Press',
        'sets': 1,
        'reps': 8,
        'restSeconds': 0,
        'dayNumber': 1,
        'executionMode': 'aiTracked'
      },
      {
        'entryId': 'manual',
        'exerciseId': 'manual-core',
        'name': 'Core Exercise',
        'sets': 2,
        'reps': 8,
        'restSeconds': 0,
        'dayNumber': 1,
        'executionMode': 'legacyManual'
      },
    ],
  });
  WorkoutSessionSummary capture(
          String id, int index, int reps, String rule, double? score) =>
      WorkoutSessionSummary(
          sessionId: id,
          userId: scope.userId,
          organizationId: scope.organizationId,
          exerciseId: routine.exercises[index].exerciseId,
          repetitions: reps,
          accuracy: score?.round() ?? 0,
          startedAt: start,
          endedAt: start.add(const Duration(seconds: 30)),
          provenance: WorkoutProvenance.realCamera,
          poseMetrics: WorkoutPoseMetrics(
              partialRepetitions: 0,
              trackedDurationMicros: 20000000,
              rejectedDurationMicros: 2000000,
              formScorePercent: score,
              scoringVersion: rule,
              detectorId: 'blazepose-tflite',
              detectorVersion: 'fixture-model',
              cameraView: score == null ? 'front' : 'side',
              consentVersion: 'pose-local-summary-v1',
              consentedAt: start,
              publishedRoutineId: routine.id));
  late final summaries = [
    capture('analytics-squat', 0, 10, 'bodyweight-squat-side-v1', 84),
    capture('analytics-press', 2, 8, 'dumbbell-shoulder-press-front-v1', null)
  ];
  late final guided = GuidedTimedProgress(
      runId: 'analytics-timer',
      entryId: 'burpee',
      entryIndex: 1,
      exerciseId: 'burpee-video',
      mediaIdentity: 'fixture-video',
      prescription:
          TimedPrescription(sets: 2, durationSeconds: 45, restSeconds: 15),
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 3)),
      updatedAt: start.add(const Duration(minutes: 3)),
      phase: GuidedTimedPhase.completed,
      completedSetActiveMicroseconds: const [45000000, 45000000]);
  late final attempt = RoutineAttempt(
      id: 'analytics-attempt',
      scope: scope,
      routine: routine,
      day: 1,
      finished: true,
      startedAtMicros: start.microsecondsSinceEpoch,
      finishedAtMicros:
          now.subtract(const Duration(minutes: 2)).microsecondsSinceEpoch,
      updatedAtMicros:
          now.subtract(const Duration(minutes: 2)).microsecondsSinceEpoch,
      entries: [
        RoutineExerciseResult(
            index: 0,
            status: RoutineExerciseStatus.completed,
            sessionIds: [summaries[0].sessionId],
            fullRepetitions: 10,
            partialRepetitions: 0,
            trackedDurationMicros: 20000000,
            manualSets: 0),
        RoutineExerciseResult.timed(
            index: 1,
            status: RoutineExerciseStatus.timerCompleted,
            guided: guided),
        RoutineExerciseResult(
            index: 2,
            status: RoutineExerciseStatus.completed,
            sessionIds: [summaries[1].sessionId],
            fullRepetitions: 8,
            partialRepetitions: 0,
            trackedDurationMicros: 20000000,
            manualSets: 0),
        RoutineExerciseResult(
            index: 3,
            status: RoutineExerciseStatus.selfReportedCompleted,
            sessionIds: const [],
            fullRepetitions: 0,
            partialRepetitions: 0,
            trackedDurationMicros: 0,
            manualSets: 2),
      ]);
  late final snapshot = LocalMemberProgressSnapshot(records: [
    for (final s in summaries)
      LocalWorkoutProgressRecord(
          scope: s.scope,
          sessionId: s.sessionId,
          exerciseId: s.exerciseId,
          startedAt: s.startedAt,
          endedAt: s.endedAt,
          repetitions: s.repetitions,
          partialRepetitions: s.partialRepetitions,
          trackedDurationMicros: s.trackedDurationMicros,
          rejectedDurationMicros: s.rejectedDurationMicros,
          formScorePercent: s.formScorePercent,
          scoringVersion: s.poseMetrics!.scoringVersion,
          detectorId: s.poseMetrics!.detectorId,
          detectorVersion: s.poseMetrics!.detectorVersion,
          cameraView: s.poseMetrics!.cameraView,
          status: LocalWorkoutRecordStatus.localOnly),
  ], summaries: {
    for (final s in summaries) s.sessionId: s
  }, attempts: [
    attempt
  ], routineHistoryAvailable: true);
}
