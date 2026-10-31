import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/local/reward_goal_store.dart';

void main() {
  test(
      'goal selection persists per organization and account with no reservation',
      () async {
    final dir = await Directory.systemTemp.createTemp('goal-test');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalRewardGoalStore(directory: () async => dir);
    final a = SessionScope(userId: 'a', organizationId: 'gym');
    final b = SessionScope(userId: 'b', organizationId: 'gym');
    expect(await store.load(a), isNull);
    await store.save(a, 'towel', isCurrent: () => true);
    expect(await store.load(a), 'towel');
    expect(await store.load(b), isNull);
    await expectLater(
        store.save(a, 'other', isCurrent: () => false), throwsStateError);
    expect(await store.load(a), 'towel');
    await store.save(a, null, isCurrent: () => true);
    expect(await store.load(a), isNull);
  });
  test(
      'invalid and foreign goal files cannot change another account preference',
      () async {
    final dir = await Directory.systemTemp.createTemp('goal-private');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalRewardGoalStore(directory: () async => dir);
    final a = SessionScope(userId: 'a', organizationId: 'gym');
    final other = SessionScope(userId: 'a', organizationId: 'other');
    await store.save(a, 'towel', isCurrent: () => true);
    expect(await store.load(other), isNull);
    await expectLater(
        store.save(a, '../unsafe', isCurrent: () => true), throwsArgumentError);
    final file = dir.listSync().whereType<File>().single;
    await file.writeAsString(
        '{"schemaVersion":1,"organizationId":"other","memberId":"a","itemId":"towel"}');
    await expectLater(store.load(a), throwsFormatException);
  });
}
