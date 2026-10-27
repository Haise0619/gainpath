import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/infrastructure/local/file_routine_journey_store.dart';
import 'routine_journey_controller_test.dart' as support;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late support.MemoryJourneyStore store;
  late WorkoutSessionRepository workouts;
  var sequence = 0;
  RoutineJourneyController controller() => RoutineJourneyController(
      scope: scope,
      activeScope: () => scope,
      routine: support.routineFixture(),
      store: store,
      workouts: workouts,
      newId: () => 'result-${sequence++}');
  setUp(() {
    store = support.MemoryJourneyStore(scope);
    workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => scope);
  });
  Future<RoutineJourneyController> complete() async {
    final c = controller();
    await c.openDay(1);
    final id = await c.prepareCapture(0);
    await workouts.saveLocal(support.measured(scope, id));
    await c.refresh();
    await c.markManualSet(1);
    await c.markManualSet(1);
    await c.finish();
    return c;
  }

  test(
      'known difficulty survives routine snapshot attempt and checkpoint roundtrips; legacy stays absent',
      () async {
    final legacy = routinePlanSnapshot(support.routineFixture());
    expect(legacy.containsKey('difficulty'), isFalse);
    for (final difficulty in ['Beginner', 'Intermediate', 'Advanced']) {
      final routine = PublishedRoutine.fromDocument(
          'routine', {...legacy, 'difficulty': difficulty});
      expect(routinePlanSnapshot(routine)['difficulty'], difficulty);
      final c = RoutineJourneyController(
          scope: scope,
          activeScope: () => scope,
          routine: routine,
          store: support.MemoryJourneyStore(scope),
          workouts: workouts,
          newId: () => 'difficulty-$difficulty');
      await c.openDay(1);
      final restored = RoutineCheckpoint.fromJson(
          jsonDecode(jsonEncode(c.checkpoint!.toJson()))
              as Map<String, dynamic>);
      expect(restored.attempt!.toJson()['routine']['difficulty'], difficulty);
      c.dispose();
    }
    final c = controller();
    await c.openDay(1);
    expect(c.checkpoint!.attempt!.toJson()['routine'].containsKey('difficulty'),
        isFalse);
    c.dispose();
  });
  test('published difficulty rejects unknown or fabricated levels', () {
    final legacy = routinePlanSnapshot(support.routineFixture());
    for (final value in ['Easy', 'beginner', '', 1]) {
      expect(
          () => PublishedRoutine.fromDocument(
              'routine', {...legacy, 'difficulty': value}),
          throwsFormatException);
    }
  });

  test('completed snapshot preserves measured and manual evidence on disk',
      () async {
    final c = await complete(), a = c.checkpoint!.attempt!;
    expect(a.isComplete, true);
    expect(a.completedExercises, 2);
    expect(a.fullRepetitions, 2);
    expect(a.selfReportedSets, 2);
    expect(a.trackedDurationMicros, 8000000);
    expect(a.entries[1].fullRepetitions, 0);
    expect(a.routine.title, 'Strength days');
    final dir = await Directory.systemTemp.createTemp('routine-result-');
    addTearDown(() => dir.delete(recursive: true));
    final disk = FileRoutineJourneyStore(directory: dir, scope: scope);
    await disk.save(c.checkpoint!);
    final restored = (await disk.load()).single.attempt!;
    expect(restored.toJson(), a.toJson());
    expect(restored.finishedAtMicros, isNotNull);
    c.dispose();
  });
  test('reopen preserves date and repeat retains old attempt', () async {
    final c = await complete(), old = c.checkpoint!;
    await c.openLatest();
    expect(
        c.checkpoint!.attempt!.finishedAtMicros, old.attempt!.finishedAtMicros);
    await c.startNewAttempt();
    expect(c.checkpoint!.id, isNot(old.id));
    expect(store.records[old.id]!.attempt!.isComplete, true);
    expect(c.checkpoint!.attempt!.fullRepetitions, 0);
    await c.openAttempt(old.id);
    expect(c.checkpoint!.id, old.id);
    c.dispose();
  });
  test('skipped finish is partial and resume restores skipped exercises',
      () async {
    final c = controller();
    await c.openDay(1);
    await c.skip(0);
    await c.skip(1);
    await c.finish();
    expect(c.checkpoint!.attempt!.isComplete, false);
    expect(c.checkpoint!.attempt!.statusLabel, 'Partially completed');
    await c.resume();
    expect(c.unfinishedIndices, [0, 1]);
    expect(c.checkpoint!.finished, false);
    expect(c.checkpoint!.attempt!.finishedAtMicros, isNull);
    c.dispose();
  });
  test('next day creates a separate attempt preserving completed day',
      () async {
    final c = await complete(), first = c.checkpoint!.id;
    expect(c.nextDay, 2);
    await c.startNextDay();
    expect(c.day, 2);
    expect(c.checkpoint!.id, isNot(first));
    expect(store.records[first]!.attempt!.isComplete, true);
    expect(c.nextDay, isNull);
    c.dispose();
  });
  test('legacy checkpoint never invents old start and completion dates',
      () async {
    final c = controller();
    await c.openDay(1);
    final json =
        jsonDecode(jsonEncode(c.checkpoint!.toJson())) as Map<String, dynamic>;
    json.remove('attempt');
    json.remove('startedAtMicros');
    json['finished'] = true;
    final legacy = RoutineCheckpoint.fromJson(json);
    store.records[legacy.id] = legacy;
    await c.openLatest();
    expect(c.checkpoint!.attempt!.startedAtMicros, isNull);
    expect(c.checkpoint!.attempt!.finishedAtMicros, isNull);
    c.dispose();
  });
  test('weekly progress deduplicates and uses Malaysia Monday boundary',
      () async {
    final c = await complete(), a = c.checkpoint!.attempt!;
    final data = a.toJson();
    final boundary = DateTime.utc(2026, 10, 25, 16).microsecondsSinceEpoch;
    data['finishedAtMicros'] = boundary;
    data['startedAtMicros'] = boundary - 10000000;
    final current = RoutineAttempt.fromJson(data);
    final totals = RoutineProgress(
        scope: scope,
        attempts: [current, current],
        asOf: DateTime.utc(2026, 10, 26));
    expect(totals.weeklyCompleted, 1);
    final previous = RoutineAttempt.fromJson({
      ...data,
      'id': 'prior',
      'finishedAtMicros': boundary - 1,
      'startedAtMicros': boundary - 10000000
    });
    final all = RoutineProgress(
        scope: scope,
        attempts: [current, previous],
        asOf: DateTime.utc(2026, 10, 26));
    expect(all.weeklyCompleted, 1);
    expect(all.completed, 2);
    final conflicting = RoutineAttempt.fromJson(
        {...data, 'finished': false, 'finishedAtMicros': null});
    expect(
        () => RoutineProgress(
            scope: scope,
            attempts: [current, conflicting],
            asOf: DateTime.utc(2026, 10, 26)),
        throwsStateError);
    c.dispose();
  });
  test('stale controller cannot overwrite progress saved by a second view',
      () async {
    final dir = await Directory.systemTemp.createTemp('routine-concurrent-');
    addTearDown(() => dir.delete(recursive: true));
    final disk = FileRoutineJourneyStore(directory: dir, scope: scope);
    RoutineJourneyController view() => RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: support.routineFixture(),
        store: disk,
        workouts: workouts,
        newId: () => 'concurrent-${sequence++}');
    final first = view();
    await first.openDay(1);
    final id = first.checkpoint!.id;
    final second = view();
    await second.openAttempt(id);
    await second.markManualSet(1);
    await expectLater(first.markManualSet(1), throwsStateError);
    expect((await disk.load()).single.manualSets[1], 1);
    await first.openAttempt(id);
    await first.markManualSet(1);
    expect((await disk.load()).single.manualSets[1], 2);
    first.dispose();
    second.dispose();
  });
}
