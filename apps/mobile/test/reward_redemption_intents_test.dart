import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/local/reward_redemption_intents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('gainpath-reward-intents-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  RewardRedemptionIntents store([SessionScope? owner]) =>
      RewardRedemptionIntents(owner ?? scope, directory: () async => directory);
  test(
      'recreated stores reuse uncertain request and clear only confirmed intent',
      () async {
    expect(await store().reserve('item', 'first'), 'first');
    final resumed = store();
    expect(await resumed.reserve('item', 'second'), 'first');
    await resumed.complete('item', 'different');
    expect(await resumed.reserve('item', 'third'), 'first');
    await resumed.complete('item', 'first');
    expect(await resumed.reserve('item', 'fourth'), 'fourth');
  });
  test('different owners and items never reuse private request keys', () async {
    await store().reserve('item', 'private');
    expect(
        await store(SessionScope(userId: 'other', organizationId: 'gainpath'))
            .reserve('item', 'other'),
        'other');
    expect(await store().reserve('another', 'another'), 'another');
  });
  test('concurrent same-item attempts retain a single request key', () async {
    final requests = await Future.wait(
        [store().reserve('item', 'one'), store().reserve('item', 'two')]);
    expect(requests.toSet(), {'one'});
  });
}
