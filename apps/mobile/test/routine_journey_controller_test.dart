import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';

class MemoryJourneyStore implements RoutineJourneyStore {
  MemoryJourneyStore(this.scope);
  @override
  final SessionScope scope;
  final records = <String, RoutineCheckpoint>{};
  @override
  Future<List<RoutineCheckpoint>> load() async => records.values.toList();
  @override
  Future<void> save(RoutineCheckpoint value) async {
    records[value.id] = value;
  }
}

PublishedRoutine routineFixture({int reps = 2}) =>
    PublishedRoutine.fromDocument('routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Strength days',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
          'name': 'Squat',
          'sets': 1,
          'reps': reps,
          'dayNumber': 1
        },
        {
          'exerciseId': 'press',
          'name': 'Press',
          'sets': 2,
          'reps': 8,
          'dayNumber': 1
        },
        {
          'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
          'name': 'Squat day two',
          'sets': 1,
          'reps': 3,
          'dayNumber': 2
        },
      ]
    });

WorkoutSessionSummary measured(SessionScope scope, String id, {int reps = 2}) {
  final started = DateTime.utc(2026, 10, 25);
  return WorkoutSessionSummary(
      sessionId: id,
      userId: scope.userId,
      organizationId: scope.organizationId,
      exerciseId: 'F3b8xIr8ynBDd3gEICKX',
      repetitions: reps,
      accuracy: 90,
      startedAt: started,
      endedAt: started.add(const Duration(seconds: 10)),
      provenance: WorkoutProvenance.realCamera,
      poseMetrics: WorkoutPoseMetrics(
          partialRepetitions: 1,
          trackedDurationMicros: 8000000,
          rejectedDurationMicros: 2000000,
          formScorePercent: 90,
          scoringVersion: 'bodyweight-squat-side-v1',
          detectorId: 'blazepose-tflite',
          detectorVersion: 'same-model',
          cameraView: 'side',
          consentVersion: 'pose-local-summary-v1',
          consentedAt: started,
          publishedRoutineId: 'routine'));
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late MemoryJourneyStore store;
  late WorkoutSessionRepository workouts;
  SessionScope? active;
  var sequence = 0;
  RoutineJourneyController controller({PublishedRoutine? routine}) =>
      RoutineJourneyController(
          scope: scope,
          activeScope: () => active,
          routine: routine ?? routineFixture(),
          store: store,
          workouts: workouts,
          newId: () => 'id-${sequence++}');
  setUp(() {
    active = scope;
    store = MemoryJourneyStore(scope);
    workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
  });

  test(
      'routine completion reconciles a saved exercise and finishes only after every target',
      () async {
    final c = controller();
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await workouts.saveLocal(measured(scope, capture));
    await c.refresh(completeRoutine: true);
    expect(c.selectedIndex, 1);
    expect(c.completedExercises, 1);
    expect(c.checkpoint!.finished, false);
    await c.markManualSet(1);
    await c.markManualSet(1);
    await c.refresh(completeRoutine: true);
    expect(c.allTargetsCompleted, true);
    expect(c.checkpoint!.finished, true);
    expect(c.fullRepetitions, 2);
    expect(c.selfReportedSets, 2);
    c.dispose();
  });
  test('one completed arm stays partial when a both-arm curl is saved early',
      () async {
    final routine = PublishedRoutine.fromDocument('routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Curl day',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'standing-single-arm-curl-side-v1',
          'name': 'Curl',
          'sets': 1,
          'reps': 5,
          'dayNumber': 1
        }
      ]
    });
    final c = controller(routine: routine);
    await c.openDay(1);
    final id = await c.prepareCapture(0);
    final start = DateTime.utc(2026, 10, 25);
    final arms = CurlArmMetrics(
        mode: CurlArmMode.both,
        targetSets: 1,
        repetitionsPerArm: 5,
        completedSets: 0,
        left: CurlArmResult(
            repetitions: 5, partialRepetitions: 0, formScorePercent: 90),
        right: CurlArmResult(
            repetitions: 0, partialRepetitions: 0, formScorePercent: null));
    await workouts.saveLocal(WorkoutSessionSummary(
        sessionId: id,
        userId: scope.userId,
        organizationId: scope.organizationId,
        exerciseId: 'standing-single-arm-curl-side-v1',
        repetitions: 5,
        accuracy: 90,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 10)),
        provenance: WorkoutProvenance.realCamera,
        poseMetrics: WorkoutPoseMetrics(
            curlArms: arms,
            partialRepetitions: 0,
            trackedDurationMicros: 8000000,
            rejectedDurationMicros: 0,
            formScorePercent: 90,
            scoringVersion: 'single-arm-curl-side-v1',
            detectorId: 'blazepose-tflite',
            detectorVersion: '1',
            cameraView: 'side',
            consentVersion: 'pose-local-summary-v1',
            consentedAt: start,
            publishedRoutineId: 'routine')));
    await c.refresh(completeRoutine: true);
    expect(c.statusFor(0), RoutineExerciseStatus.partial);
    expect(c.checkpoint!.finished, false);
    c.dispose();
  });

  test('partial and skipped targets never trigger automatic routine completion',
      () async {
    final c = controller();
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await workouts.saveLocal(measured(scope, capture, reps: 1));
    await c.refresh(completeRoutine: true);
    expect(c.statusFor(0), RoutineExerciseStatus.partial);
    expect(c.selectedIndex, 0);
    expect(c.checkpoint!.finished, false);
    await c.skip(0);
    expect(c.selectedIndex, 1);
    await c.markManualSet(1);
    await c.markManualSet(1);
    await c.refresh(completeRoutine: true);
    expect(c.allTargetsCompleted, false);
    expect(c.checkpoint!.finished, false);
    c.dispose();
  });

  test(
      'checkpoint recovers exact saved capture once after restart and advances exercise',
      () async {
    final first = controller();
    await first.openDay(1);
    final capture = await first.prepareCapture(0);
    await workouts.saveLocal(measured(scope, capture));
    first.dispose();
    final resumed = controller();
    await resumed.openDay(1);
    expect(resumed.fullRepetitions, 2);
    expect(resumed.partialRepetitions, 1);
    expect(resumed.trackedDurationMicros, 8000000);
    expect(resumed.selectedIndex, 1);
    await resumed.refresh();
    expect(resumed.fullRepetitions, 2);
    expect(resumed.statusFor(0), RoutineExerciseStatus.completed);
    expect(resumed.statusFor(1), RoutineExerciseStatus.notStarted);
    resumed.dispose();
  });

  test(
      'unsupported exercise is instructional and cannot create measured capture',
      () async {
    final c = controller();
    await c.openDay(1);
    await expectLater(c.prepareCapture(1), throwsStateError);
    await c.reviewInstructions(1);
    expect(c.statusFor(1), RoutineExerciseStatus.instructionsReviewed);
    expect(c.fullRepetitions, 0);
    expect(c.measuredSessions, isEmpty);
    expect(c.unfinishedIndices, [0, 1]);
    c.dispose();
  });

  test(
      'days, changed targets and new attempts do not reuse incompatible completion',
      () async {
    final c = controller();
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await workouts.saveLocal(measured(scope, capture));
    await c.refresh();
    await c.openDay(2);
    expect(c.fullRepetitions, 0);
    expect(c.dayIndices, [2]);
    final changed = controller(routine: routineFixture(reps: 4));
    await changed.openDay(1);
    expect(changed.fullRepetitions, 0);
    expect(store.records.length, 3);
    await changed.startNewAttempt();
    expect(store.records.length, 4);
    c.dispose();
    changed.dispose();
  });

  test('account loss hides results and rejects further checkpoint mutation',
      () async {
    final c = controller();
    await c.openDay(1);
    active = SessionScope(userId: 'different', organizationId: 'gainpath');
    c.accountChanged();
    expect(c.measuredSessions, isEmpty);
    await expectLater(c.skip(0), throwsStateError);
    c.dispose();
  });

  test('reopening restores the most recently selected routine day', () async {
    final c = controller();
    await c.openDay(2);
    await c.select(2);
    c.dispose();
    final resumed = controller();
    await resumed.openLatest();
    expect(resumed.day, 2);
    expect(resumed.selectedIndex, 2);
    resumed.dispose();
  });

  test('returning to an existing day makes it the resumed day', () async {
    final c = controller();
    await c.openDay(1);
    await c.openDay(2);
    await c.openDay(1);
    c.dispose();
    final resumed = controller();
    await resumed.openLatest();
    expect(resumed.day, 1);
    resumed.dispose();
  });

  test(
      'manual sets resume and complete independently from measured reps and form',
      () async {
    final c = controller();
    await c.openDay(1);
    await c.markManualSet(1);
    expect(c.manualSetsFor(1), 1);
    expect(c.statusFor(1), RoutineExerciseStatus.selfReportedPartial);
    c.dispose();
    final resumed = controller();
    await resumed.openLatest();
    expect(resumed.manualSetsFor(1), 1);
    await resumed.markManualSet(1);
    await resumed.markManualSet(1);
    expect(resumed.manualSetsFor(1), 2);
    expect(resumed.statusFor(1), RoutineExerciseStatus.selfReportedCompleted);
    expect(resumed.fullRepetitions, 0);
    expect(resumed.trackedDurationMicros, 0);
    expect(resumed.measuredSessions, isEmpty);
    await expectLater(resumed.markManualSet(0), throwsStateError);
    await resumed.undoManualSet(1);
    expect(resumed.manualSetsFor(1), 1);
    resumed.dispose();
  });

  test('older checkpoints without manual completion fields remain readable',
      () async {
    final c = controller();
    await c.openDay(1);
    final older = c.checkpoint!.toJson()..remove('manualSets');
    final restored =
        RoutineCheckpoint.fromJson(Map<String, dynamic>.from(older));
    expect(restored.manualSets, isEmpty);
    expect(restored.selectedIndex, c.selectedIndex);
    c.dispose();
  });
}
