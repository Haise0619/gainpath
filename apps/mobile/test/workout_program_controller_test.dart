import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;

WorkoutProgram programFixture() {
  final json = WorkoutProgram.templates().first.toJson();
  json['version'] = 1;
  json['days'] = (json['days'] as List).map((raw) {
    final day = Map<String, dynamic>.from(raw as Map);
    if (day['kind'] == 'workout') {
      day['routineId'] = 'routine_full';
      day['routineSnapshot'] = {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': 'full',
        'title': 'Full body',
        'estimatedMinutes': 20,
        'exercises': [
          {
            'exerciseId': 'manual',
            'name': 'Manual exercise',
            'sets': 2,
            'reps': 8,
            'dayNumber': 1,
            'restSeconds': 90
          }
        ]
      };
    }
    return day;
  }).toList();
  return WorkoutProgram.fromJson(json);
}

class MemoryProgramStore implements ProgramEnrollmentStore {
  MemoryProgramStore(this.scope);
  @override
  final SessionScope scope;
  ProgramJournal journal = ProgramJournal.empty();
  @override
  Future<ProgramJournal> load() async => journal;
  @override
  Future<void> save(ProgramJournal next,
      {required int expectedRevision}) async {
    if (journal.revision != expectedRevision) throw StateError('Conflict');
    journal = next;
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  late SessionScope? active;
  late MemoryProgramStore store;
  late MemoryJourneyStore routines;
  late WorkoutProgramController c;
  setUp(() {
    active = scope;
    store = MemoryProgramStore(scope);
    routines = MemoryJourneyStore(scope);
    var id = 0;
    c = WorkoutProgramController(
        scope: scope,
        activeScope: () => active,
        store: store,
        routineStore: routines,
        newId: () => 'id_${++id}');
  });
  tearDown(() => c.dispose());
  test('enrollment preserves version, schedule and one durable attempt per day',
      () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final day = c.enrollment!.schedule
        .firstWhere((d) => d.definition.kind == 'workout');
    final first = await c.begin(day.key);
    final again = await c.begin(day.key);
    expect(first.attemptId, again.attemptId);
    expect(first.routine.id, 'routine_full');
    expect(first.routine.exercises.single.restSeconds, 90);
    expect(c.completedDays(1), 0);
    final restored = ProgramJournal.fromJson(store.journal.toJson());
    expect(restored.enrollments.single.program.version, 1);
    expect(restored.enrollments.single.progress[day.key]!.attemptId,
        first.attemptId);
  });
  test(
      'skip and overdue days do not fabricate completion; resume keeps attempt',
      () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final key = c.enrollment!.schedule.first.key;
    final first = await c.begin(key);
    await c.skip(key);
    expect(c.status(key, DateTime.utc(2026, 12, 1)), 'Skipped');
    expect(c.completedDays(1), 0);
    final resumed = await c.begin(key);
    expect(resumed.attemptId, first.attemptId);
    expect(c.status(key, DateTime.utc(2026, 12, 1)), 'In progress');
  });
  test(
      'switching programs preserves previous enrollments and account data hides immediately',
      () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final old = c.enrollment!.id;
    await c.enroll(programFixture(), DateTime.utc(2026, 12, 7), {1, 3, 5});
    expect(c.journal!.enrollments.length, 2);
    await c.selectEnrollment(old);
    expect(c.enrollment!.id, old);
    active = null;
    expect(c.enrollment, isNull);
    await expectLater(c.begin('w1-d1'), throwsStateError);
  });
  test('journal rejects foreign schedule keys and forged completion fields',
      () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final json = store.journal.toJson();
    final enrollment = (json['enrollments'] as List).single as Map;
    enrollment['progress'] = {
      'foreign': {'skipped': false, 'attemptId': null}
    };
    expect(() => ProgramJournal.fromJson(json), throwsFormatException);
  });
  test(
      'typed manual completion counts only for matching immutable routine targets',
      () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final key = c.enrollment!.schedule.first.key;
    final launch = await c.begin(key);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        activeScope: () => active,
        uploadGateway: UnavailableWorkoutUploadGateway());
    final routine = RoutineJourneyController(
        scope: scope,
        activeScope: () => active,
        routine: launch.routine,
        store: routines,
        workouts: workouts,
        newId: () => 'unused');
    await routine.openProgramAttempt(launch.attemptId, 1);
    await routine.markManualSet(0);
    await routine.markManualSet(0);
    await routine.finish();
    await expectLater(routine.startNewAttempt(), throwsStateError);
    await c.open();
    expect(c.completedDays(1), 1);
    expect(c.attempt(key)!.fullRepetitions, 0);
    expect(c.attempt(key)!.selfReportedSets, 2);
    final altered =
        Map<String, dynamic>.from(routines.records[launch.attemptId]!.toJson());
    altered['planSignature'] = 'different-targets';
    routines.records[launch.attemptId] = RoutineCheckpoint.fromJson(altered);
    await c.open();
    expect(c.completedDays(1), 0);
    routine.dispose();
    workouts.dispose();
  });
  test('journal rejects duplicate dates in a stored schedule', () async {
    await c.open();
    await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final json = store.journal.toJson();
    final enrollment = (json['enrollments'] as List).single as Map;
    final schedule = enrollment['schedule'] as List;
    (schedule[1] as Map)['date'] = (schedule.first as Map)['date'];
    expect(() => ProgramJournal.fromJson(json), throwsFormatException);
  });
  test(
      'scheduled same-day retry remains pinned when another slot uses same routine',
      () async {
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        activeScope: () => active,
        uploadGateway: UnavailableWorkoutUploadGateway());
    final program = programFixture();
    await c.open();
    await c.enroll(program, DateTime.utc(2026, 11, 2), {1, 3, 5});
    final launch = await c.begin(c.enrollment!.schedule.first.key);
    RoutineJourneyController make() => RoutineJourneyController(
        scope: scope,
        activeScope: () => active,
        routine: launch.routine,
        store: routines,
        workouts: workouts,
        newId: () => 'unused');
    final first = make(), second = make();
    await first.openProgramAttempt('slot_first', 1);
    await second.openProgramAttempt('slot_second', 1);
    await first.openDay(1);
    expect(first.checkpoint!.id, 'slot_first');
    await expectLater(first.openAttempt('slot_second'), throwsStateError);
    first.dispose();
    second.dispose();
    workouts.dispose();
  });
}
