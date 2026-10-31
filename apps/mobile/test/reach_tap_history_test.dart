import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/infrastructure/local/reach_tap_history.dart';

void main() {
  late Directory directory;
  late LocalReachTapHistory store;
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  ReachTapRound round(String id, {int hits = 3, int second = 0}) =>
      ReachTapRound(
          id: id,
          completedAt: DateTime.utc(2026, 10, 29, 12, 0, second),
          hits: hits,
          score: hits * 10);
  Future<File> savedFile() async =>
      (await directory.list().toList()).whereType<File>().single;
  Future<void> mutate(void Function(Map<String, dynamic>) update) async {
    final file = await savedFile();
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    update(data);
    await file.writeAsString(jsonEncode(data));
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reach-tap-history-');
    store = LocalReachTapHistory(directory: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('completed aggregates survive reload without sharing accounts or orgs',
      () async {
    expect((await store.load(scope)).rounds, isEmpty);
    final result =
        await store.record(scope, round('round_a'), isCurrent: () => true);
    expect(result.bestScore, 30);
    expect(result.rounds.single.id, 'round_a');
    expect(result.rounds.single.activeMicros, 40000000);
    final reloaded =
        await LocalReachTapHistory(directory: () async => directory)
            .load(scope);
    expect(reloaded.rounds.single.completedAt, DateTime.utc(2026, 10, 29, 12));
    expect(reloaded.rounds.single.score, 30);
    expect(
        (await store.load(SessionScope(userId: 'other', organizationId: 'org')))
            .rounds,
        isEmpty);
    expect(
        (await store
                .load(SessionScope(userId: 'member', organizationId: 'other')))
            .rounds,
        isEmpty);
    expect(() => result.rounds.clear(), throwsUnsupportedError);
  });

  test('retry is idempotent and rejects conflicting stable-round metrics',
      () async {
    await store.record(scope, round('same'), isCurrent: () => true);
    expect(
        (await store.record(scope, round('same'), isCurrent: () => true))
            .rounds
            .length,
        1);
    await expectLater(
        store.record(scope, round('same', hits: 4), isCurrent: () => true),
        throwsStateError);
    await expectLater(
        store.record(scope, round('same', second: 1), isCurrent: () => true),
        throwsStateError);
    expect((await store.load(scope)).bestScore, 30);
  });

  test('separate instances serialize concurrent writes without losing rounds',
      () async {
    final other = LocalReachTapHistory(directory: () async => directory);
    await Future.wait(List.generate(
        20,
        (index) => (index.isEven ? store : other).record(
            scope, round('round_$index', hits: index, second: index),
            isCurrent: () => true)));
    final history = await store.load(scope);
    expect(history.rounds.length, 20);
    expect(history.bestScore, 190);
    expect(history.rounds.first.id, 'round_19');
    expect(history.rounds.last.id, 'round_0');
  });

  test('100 newest rounds are bounded and best outlives the retained round',
      () async {
    await store.record(scope, round('best', hits: 100), isCurrent: () => true);
    for (var index = 1; index <= 101; index++) {
      await store.record(scope, round('r_$index', hits: 1, second: index),
          isCurrent: () => true);
    }
    final history = await store.load(scope);
    expect(history.rounds.length, 100);
    expect(history.rounds.first.id, 'r_101');
    expect(history.rounds.last.id, 'r_2');
    expect(history.bestScore, 1000);
    expect((await savedFile()).lengthSync(), lessThan(65536));
  });

  test('stale scope cannot write and queued account change blocks publication',
      () async {
    await expectLater(
        store.record(scope, round('stale'), isCurrent: () => false),
        throwsStateError);
    final gate = Completer<Directory>();
    final entered = Completer<void>();
    var current = true;
    final waiting = LocalReachTapHistory(directory: () {
      entered.complete();
      return gate.future;
    });
    final write =
        waiting.record(scope, round('late'), isCurrent: () => current);
    final assertion = expectLater(write, throwsStateError);
    await entered.future;
    current = false;
    gate.complete(directory);
    await assertion;
    expect((await store.load(scope)).rounds, isEmpty);
    expect(await directory.list().toList(), isEmpty);
  });

  test('guard is fresh after staging and pending files never become history',
      () async {
    var checks = 0;
    await expectLater(
        store.record(scope, round('staged'), isCurrent: () => ++checks < 3),
        throwsStateError);
    expect((await store.load(scope)).rounds, isEmpty);
    expect(await directory.list().toList(), isEmpty);
  });

  test('failed write can retry same round without poisoning serialized queue',
      () async {
    final blocker = File('${directory.path}/blocked');
    await blocker.writeAsString('occupied');
    final broken = LocalReachTapHistory(
        directory: () async => Directory('${blocker.path}/child'));
    await expectLater(
        broken.record(scope, round('retry'), isCurrent: () => true),
        throwsA(isA<FileSystemException>()));
    await blocker.delete();
    final saved =
        await store.record(scope, round('retry'), isCurrent: () => true);
    expect(saved.rounds.single.id, 'retry');
  });

  for (final field in [
    'schemaVersion',
    'organizationId',
    'memberId',
    'gameVersion'
  ]) {
    test('rejects mismatched $field without replacing protected history',
        () async {
      await store.record(scope, round('owned'), isCurrent: () => true);
      await mutate(
          (data) => data[field] = field == 'schemaVersion' ? 2 : 'foreign');
      final before = await (await savedFile()).readAsString();
      await expectLater(store.load(scope), throwsFormatException);
      await expectLater(
          store.record(scope, round('new'), isCurrent: () => true),
          throwsFormatException);
      expect(await (await savedFile()).readAsString(), before);
    });
  }

  test('rejects malformed JSON and oversized files before decoding history',
      () async {
    await store.record(scope, round('owned'), isCurrent: () => true);
    final file = await savedFile();
    await file.writeAsString('{malformed');
    await expectLater(store.load(scope), throwsFormatException);
    await file.writeAsString(' ' * 65537);
    await expectLater(store.load(scope), throwsFormatException);
  });

  test('schema version requires integer type rather than numeric equality',
      () async {
    await store.record(scope, round('owned'), isCurrent: () => true);
    await mutate((data) => data['schemaVersion'] = 1.0);
    await expectLater(store.load(scope), throwsFormatException);
  });

  test('failed replacement preserves previous rounds and safely retries',
      () async {
    await store.record(scope, round('previous'), isCurrent: () => true);
    final file = await savedFile();
    final blocker = Directory('${file.path}.pending');
    await blocker.create();
    await expectLater(
        store.record(scope, round('retry', second: 1), isCurrent: () => true),
        throwsA(isA<FileSystemException>()));
    expect((await store.load(scope)).rounds.single.id, 'previous');
    await blocker.delete();
    expect(
        (await store.record(scope, round('retry', second: 1),
                isCurrent: () => true))
            .rounds
            .map((r) => r.id),
        ['retry', 'previous']);
  });

  test('ambiguous owner components never collide in local storage', () async {
    final left = SessionScope(userId: 'b/c', organizationId: 'a');
    final right = SessionScope(userId: 'c', organizationId: 'a/b');
    await store.record(left, round('left'), isCurrent: () => true);
    await store.record(right, round('right'), isCurrent: () => true);
    expect((await store.load(left)).rounds.single.id, 'left');
    expect((await store.load(right)).rounds.single.id, 'right');
  });

  test('rejects oversized rows, duplicate IDs, unknown fields and false best',
      () async {
    await store.record(scope, round('owned'), isCurrent: () => true);
    final file = await savedFile();
    final original = await file.readAsString();
    for (final update in <void Function(Map<String, dynamic>)>[
      (data) =>
          data['rounds'] = List.filled(101, (data['rounds'] as List).single),
      (data) => (data['rounds'] as List).add((data['rounds'] as List).single),
      (data) => data['landmarks'] = [],
      (data) => data['bestScore'] = 20,
      (data) => (data['rounds'] as List).single['score'] = 31,
      (data) => (data['rounds'] as List).single['activeMicros'] = 39999999,
      (data) => (data['rounds'] as List).single['completedAt'] =
          '2026-10-29T12:00:00',
    ]) {
      await file.writeAsString(original);
      await mutate(update);
      await expectLater(store.load(scope), throwsFormatException);
    }
  });

  test('invalid/incomplete round aggregates cannot be constructed', () {
    for (final make in <ReachTapRound Function()>[
      () => ReachTapRound(
          id: '', completedAt: DateTime.utc(2026), hits: 0, score: 0),
      () => ReachTapRound(
          id: '../escape', completedAt: DateTime.utc(2026), hits: 0, score: 0),
      () => ReachTapRound(
          id: 'r', completedAt: DateTime(2026), hits: 0, score: 0),
      () => ReachTapRound(
          id: 'r', completedAt: DateTime.utc(2026), hits: -1, score: -10),
      () => ReachTapRound(
          id: 'r', completedAt: DateTime.utc(2026), hits: 2, score: 21),
      () => ReachTapRound(
          id: 'r',
          completedAt: DateTime.utc(2026),
          hits: 2,
          score: 20,
          activeMicros: 39999999),
    ]) {
      expect(make, throwsArgumentError);
    }
  });
}
