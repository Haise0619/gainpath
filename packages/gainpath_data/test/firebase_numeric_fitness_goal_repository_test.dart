import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

class GoalGatewayFake implements NumericFitnessGoalGateway {
  final records = <SessionScope, Map<String, Map<String, Object?>>>{};
  final history = <String, List<Map<String, Object?>>>{};
  int allocated = 0;
  int writes = 0;
  int? requestedLimit;
  bool current = true;
  final now = DateTime.utc(2026, 10, 17);
  void check() {
    if (!current) {
      throw const NumericGoalException('Session changed.',
          reloadRequired: true);
    }
  }

  @override
  String allocateId(SessionScope scope) {
    check();
    return 'goal-${++allocated}';
  }

  @override
  Future<Map<String, Map<String, Object?>>> readActive(SessionScope scope,
      {required int limit}) async {
    check();
    requestedLimit = limit;
    return {
      for (final entry in (records[scope] ?? {})
          .entries
          .where((entry) => entry.value['status'] == 'active')
          .take(limit))
        entry.key: {...entry.value}
    };
  }

  @override
  Future<void> commit(
      SessionScope scope, String id, Map<String, Object?> fields,
      {required int? expectedRevision}) async {
    check();
    final collection = records.putIfAbsent(scope, () => {});
    final old = collection[id];
    if (expectedRevision == null &&
        old != null &&
        old['revision'] == 1 &&
        fields.entries.every((e) => old[e.key] == e.value)) {
      return;
    }
    if ((expectedRevision == null && old != null) ||
        (expectedRevision != null &&
            (old == null ||
                old['revision'] != expectedRevision ||
                old['status'] != 'active'))) {
      throw const NumericGoalException('Conflict.', reloadRequired: true);
    }
    final data = <String, Object?>{
      ...?old,
      ...fields,
      'revision': (expectedRevision ?? 0) + 1,
      if (old == null) 'createdAt': now,
      'updatedAt': now.add(Duration(seconds: writes++))
    };
    collection[id] = data;
    history
        .putIfAbsent('${scope.organizationId}/${scope.userId}/$id', () => [])
        .add({...data});
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  late GoalGatewayFake gateway;
  late FirebaseNumericFitnessGoalRepository repository;
  setUp(() {
    gateway = GoalGatewayFake();
    repository =
        FirebaseNumericFitnessGoalRepository(scope: scope, gateway: gateway);
  });
  Future<String> create(
      [NumericGoalCategory category = NumericGoalCategory.trainingFrequency,
      double value = 4]) async {
    final id = repository.allocateId();
    await repository.create(id: id, category: category, targetValue: value);
    return id;
  }

  test(
      'creates explicit numeric meaning, bounded server read, stable retry identity',
      () async {
    final id = await create();
    await repository.create(
        id: id,
        category: NumericGoalCategory.trainingFrequency,
        targetValue: 4);
    expect(gateway.records[scope], hasLength(1));
    expect(gateway.writes, 1);
    final goal = (await repository.loadActive()).single;
    expect(gateway.requestedLimit, 21);
    expect(goal.id, id);
    expect(goal.unit, 'sessions');
    expect(goal.evaluationPeriod, 'calendarWeek');
    expect(goal.revision, 1);
    expect(goal.createdAt.isUtc, true);
    expect(
        gateway.records[scope]![id]!.keys,
        unorderedEquals([
          'schemaVersion',
          'category',
          'targetValue',
          'unit',
          'evaluationPeriod',
          'status',
          'revision',
          'createdAt',
          'updatedAt'
        ]));
  });
  test(
      'update and archive preserve stable ID, creation metadata and historical meaning',
      () async {
    final id = await create();
    var goal = (await repository.loadActive()).single;
    await repository.update(goal, targetValue: 5);
    goal = (await repository.loadActive()).single;
    expect(goal.id, id);
    expect(goal.revision, 2);
    expect(goal.targetValue, 5);
    await repository.archive(goal);
    expect(await repository.loadActive(), isEmpty);
    final versions = gateway.history['org/member/$id']!;
    expect(versions.map((v) => v['targetValue']), [4, 5, 5]);
    expect(versions.map((v) => v['revision']), [1, 2, 3]);
    expect(versions.map((v) => v['createdAt']).toSet(), {gateway.now});
    expect(versions.last['status'], 'archived');
  });
  test('stale update or archive cannot overwrite later edits', () async {
    await create();
    final stale = (await repository.loadActive()).single;
    await repository.update(stale, targetValue: 6);
    await expectLater(repository.update(stale, targetValue: 7),
        throwsA(isA<NumericGoalException>()));
    await expectLater(
        repository.archive(stale), throwsA(isA<NumericGoalException>()));
    expect((await repository.loadActive()).single.targetValue, 6);
  });
  test(
      'foreign repository baselines, sessions and document escape IDs are rejected',
      () async {
    final id = await create();
    final goal = (await repository.loadActive()).single;
    final other = FirebaseNumericFitnessGoalRepository(
        scope: SessionScope(userId: 'other', organizationId: 'org'),
        gateway: gateway);
    expect(await other.loadActive(), isEmpty);
    await expectLater(other.update(goal, targetValue: 5),
        throwsA(isA<NumericGoalException>()));
    await expectLater(
        other.create(id: id, category: goal.category, targetValue: 5),
        throwsA(isA<NumericGoalException>()));
    gateway.current = false;
    await expectLater(repository.update(goal, targetValue: 5),
        throwsA(isA<NumericGoalException>()));
    expect(
        () => FirebaseNumericFitnessGoalRepository(
            scope: SessionScope(userId: 'a/b', organizationId: 'org'),
            gateway: gateway),
        throwsArgumentError);
    expect(() => validateGoalId('../goal'), throwsArgumentError);
  });
  test(
      'rejects nonfinite, zero, negative, fractional count and unsupported precision',
      () async {
    final id = repository.allocateId();
    for (final value in [double.nan, double.infinity, -1.0, 0.0, 1.5, 15.0]) {
      await expectLater(
          repository.create(
              id: id,
              category: NumericGoalCategory.trainingFrequency,
              targetValue: value),
          throwsA(isA<NumericGoalException>()));
    }
    for (final value in [34.9, 160.1, 65.55, double.negativeInfinity]) {
      await expectLater(
          repository.create(
              id: id,
              category: NumericGoalCategory.bodyWeight,
              targetValue: value),
          throwsA(isA<NumericGoalException>()));
    }
    for (final value in [0.0, 1001.0, 8.5]) {
      await expectLater(
          repository.create(
              id: id,
              category: NumericGoalCategory.repetitions,
              targetValue: value),
          throwsA(isA<NumericGoalException>()));
    }
    expect(gateway.writes, 0);
  });
  test(
      'supports body-weight and repetition semantics without calculated actuals',
      () async {
    await create(NumericGoalCategory.bodyWeight, 65.5);
    await create(NumericGoalCategory.repetitions, 20);
    final goals = await repository.loadActive();
    expect(goals.map((g) => g.unit), containsAll(['kg', 'repetitions']));
    expect(goals.map((g) => g.evaluationPeriod),
        containsAll(['latestMeasurement', 'perSession']));
  });
  test(
      'count targets serialize as Firestore integers, body weight stays double, and unchanged edits do not write',
      () async {
    for (final category in NumericGoalCategory.values) {
      final value = category == NumericGoalCategory.bodyWeight ? 65.5 : 4.0;
      final id = await create(category, value);
      expect(
          gateway.records[scope]![id]!['targetValue'],
          category == NumericGoalCategory.bodyWeight
              ? isA<double>()
              : isA<int>());
      final original =
          (await repository.loadActive()).firstWhere((g) => g.id == id);
      final writes = gateway.writes;
      await repository.update(original, targetValue: value);
      expect(gateway.writes, writes);
      await repository.update(original, targetValue: value + 1);
      expect(
          gateway.records[scope]![id]!['targetValue'],
          category == NumericGoalCategory.bodyWeight
              ? isA<double>()
              : isA<int>());
    }
  });
  test(
      'malformed saved units, timestamp, category and unsupported values fail closed',
      () async {
    final id = await create();
    final original = {...gateway.records[scope]![id]!};
    for (final patch in <Map<String, Object?>>[
      {'unit': 'kg'},
      {'evaluationPeriod': 'forever'},
      {'category': 'consistency'},
      {'targetValue': double.nan},
      {'revision': 0},
      {'createdAt': null},
      {'updatedAt': 'yesterday'}
    ]) {
      gateway.records[scope]![id] = {...original, ...patch};
      await expectLater(
          repository.loadActive(), throwsA(isA<NumericGoalException>()));
    }
  });
}
