import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('templates contain four complete weeks with 3/4/5 real workout slots',
      () {
    final templates = WorkoutProgram.templates();
    expect(templates.map((p) => p.level),
        ['Beginner', 'Intermediate', 'Advanced']);
    for (var i = 0; i < templates.length; i++) {
      final p = templates[i];
      p.validate();
      expect(p.days.length, 28);
      expect(p.days.where((d) => d.kind == 'workout').length, (i + 3) * 4);
      expect(p.days.every((d) => d.routineSnapshot == null), isTrue);
      expect(() => p.validate(published: true), throwsFormatException);
      expect(WorkoutProgram.fromJson(p.toJson()).toJson(), p.toJson());
    }
  });
  test('missing days and unknown categories fail closed', () {
    final json = WorkoutProgram.templates().first.toJson();
    (json['days'] as List).removeLast();
    expect(() => WorkoutProgram.fromJson(json), throwsFormatException);
    final day = WorkoutProgram.templates().first.days.first.toJson();
    day['category'] = 'Fake AI';
    expect(() => ProgramDay.fromJson(day), throwsFormatException);
  });
  test('invalid targets and hidden muscle groups cannot bypass recovery', () {
    final day = WorkoutProgram.templates().first.days.first.toJson();
    day['restSeconds'] = 601;
    expect(() => ProgramDay.fromJson(day), throwsFormatException);
    day['restSeconds'] = 60;
    day['muscleGroups'] = <String>[];
    expect(() => ProgramDay.fromJson(day), throwsFormatException);
  });
  test('calendar starts on chosen date and uses available weekdays', () {
    final entries = ProgramSchedule.create(WorkoutProgram.templates().first,
        DateTime.utc(2026, 10, 28), {1, 3, 5});
    expect(entries.length, 28);
    expect(entries.first.date, DateTime.utc(2026, 10, 28));
    expect(entries.map((e) => e.key).toSet().length, 28);
    expect(
        entries
            .where((e) => e.definition.kind == 'workout')
            .every((e) => {1, 3, 5}.contains(e.date.weekday)),
        isTrue);
  });
  test('insufficient availability and consecutive full body days reject', () {
    final p = WorkoutProgram.templates().first;
    expect(() => ProgramSchedule.create(p, DateTime.utc(2026, 10, 26), {1, 3}),
        throwsFormatException);
    expect(
        () => ProgramSchedule.create(p, DateTime.utc(2026, 10, 26), {1, 2, 3}),
        throwsFormatException);
  });
  test('reschedule swaps a rest day and retains every original day identity',
      () {
    final entries = ProgramSchedule.create(WorkoutProgram.templates().first,
        DateTime.utc(2026, 10, 26), {1, 3, 5});
    final workout = entries.first;
    final moved = ProgramSchedule.reschedule(
        entries, workout.key, DateTime.utc(2026, 11, 22));
    expect(moved.singleWhere((e) => e.key == workout.key).date,
        DateTime.utc(2026, 11, 22));
    expect(moved.map((e) => e.key).toSet(), entries.map((e) => e.key).toSet());
    expect(moved.map((e) => e.date).toSet().length, 28);
    expect(
        () => ProgramSchedule.reschedule(
            entries, workout.key, DateTime.utc(2026, 10, 28)),
        throwsFormatException);
    expect(
        () => ProgramSchedule.reschedule(
            entries, workout.key, DateTime.utc(2026, 10, 27)),
        throwsFormatException);
  });
  test('recovery checks cross week boundaries', () {
    final entries = ProgramSchedule.create(WorkoutProgram.templates().first,
        DateTime.utc(2026, 10, 26), {1, 3, 5});
    expect(
        () => ProgramSchedule.reschedule(
            entries, entries.first.key, DateTime.utc(2026, 11, 2)),
        throwsFormatException);
  });
  test('published weeks require a consistent nonzero training frequency', () {
    final p = WorkoutProgram.templates().first.toJson();
    p['version'] = 1;
    for (final day in p['days'] as List) {
      if (day['kind'] == 'workout') {
        day['routineId'] = 'routine-real';
        day['routineSnapshot'] = _snapshot();
      }
      if (day['week'] == 4 && day['weekday'] == 5) {
        day['kind'] = 'rest';
        day['category'] = 'Rest';
        day['muscleGroups'] = <String>[];
        day.remove('routineId');
        day.remove('routineSnapshot');
      }
    }
    expect(() => WorkoutProgram.fromJson(p), throwsFormatException);
  });
  test('published snapshots and targets cannot mutate through caller maps', () {
    final source = _snapshot();
    final day = ProgramDay(
        week: 1,
        weekday: 1,
        kind: 'workout',
        category: 'Full Body',
        routineId: 'routine-real',
        routineSnapshot: source);
    (source['exercises'] as List).clear();
    expect(day.routineSnapshot!['exercises'], hasLength(1));
    expect(() => (day.routineSnapshot!['exercises'] as List).clear(),
        throwsUnsupportedError);
    final json = day.toJson();
    (json['routineSnapshot']['exercises'] as List).clear();
    expect(day.routineSnapshot!['exercises'], hasLength(1));
  });
  test(
      'different split labels cannot schedule identical exercises consecutively',
      () {
    final push = ProgramDay(
        week: 1,
        weekday: 1,
        kind: 'workout',
        category: 'Push',
        routineId: 'routine',
        routineSnapshot: _snapshot());
    final pull = ProgramDay(
        week: 1,
        weekday: 3,
        kind: 'workout',
        category: 'Pull',
        routineId: 'routine',
        routineSnapshot: _snapshot());
    final entries = [
      ScheduledProgramDay(
          key: push.key, definition: push, date: DateTime.utc(2026, 11, 2)),
      ScheduledProgramDay(
          key: pull.key, definition: pull, date: DateTime.utc(2026, 11, 4))
    ];
    expect(
        () => ProgramSchedule.reschedule(
            entries, pull.key, DateTime.utc(2026, 11, 3)),
        throwsFormatException);
  });
  test('published lower body routine cannot masquerade as a Push day', () {
    final s = _snapshot();
    (s['exercises'] as List).first['category'] = 'Compound Lower-Body';
    final d = ProgramDay(
        week: 1,
        weekday: 1,
        kind: 'workout',
        category: 'Push',
        routineId: 'routine',
        routineSnapshot: s);
    expect(() => d.validate(published: true), throwsFormatException);
  });
}

Map<String, dynamic> _snapshot() => {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'real',
      'title': 'Published Routine',
      'estimatedMinutes': 20,
      'exercises': [
        {
          'exerciseId': 'squat',
          'dayNumber': 1,
          'name': 'Squat',
          'sets': 2,
          'reps': 8
        }
      ],
    };
