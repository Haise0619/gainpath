import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/local/move_catch_best_scores.dart';

void main() {
  late Directory dir;
  late LocalMoveCatchBestScores store;
  final a = SessionScope(userId: 'a', organizationId: 'org'),
      b = SessionScope(userId: 'b', organizationId: 'org');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('move-catch-test-');
    store = LocalMoveCatchBestScores(directory: () async => dir);
  });
  tearDown(() async => dir.delete(recursive: true));
  test('personal best is scoped, persistent, monotonic and concurrent-safe',
      () async {
    expect(await store.load(a), 0);
    await Future.wait([
      store.record(a, 30, isCurrent: () => true),
      store.record(a, 10, isCurrent: () => true)
    ]);
    expect(await store.load(a), 30);
    expect(await store.load(b), 0);
    expect(
        await LocalMoveCatchBestScores(directory: () async => dir).load(a), 30);
  });
  test(
      'stale session cannot write and corrupt personal best never becomes invented score',
      () async {
    await expectLater(
        store.record(a, 99, isCurrent: () => false), throwsStateError);
    expect(await store.load(a), 0);
    await expectLater(
        store.record(a, -1, isCurrent: () => true), throwsArgumentError);
    await store.record(a, 10, isCurrent: () => true);
    final file = (await dir.list().toList()).whereType<File>().single;
    await file.writeAsString('{invalid json');
    await expectLater(store.load(a), throwsFormatException);
    await expectLater(
        store.record(a, 20, isCurrent: () => true), throwsFormatException);
  });
}
