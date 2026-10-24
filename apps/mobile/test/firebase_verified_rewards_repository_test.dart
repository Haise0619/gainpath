import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_verified_rewards_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/reward_redemption_intents.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('gainpath-reward-repository-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  RewardRedemptionIntents intents() =>
      RewardRedemptionIntents(scope, directory: () async => directory);
  Map<String, dynamic> overview() => {
        'schemaVersion': 1,
        'organizationId': 'gainpath',
        'memberId': 'member',
        'available': false,
        'balance': null,
        'effectiveTier': 'free',
        'canRedeem': false,
        'policyVersion': null,
        'items': [],
        'redemptions': [],
        'resolvedAtMillis': 1800000000000,
      };
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'synthetic-token');
  test(
      'unconfigured overview retains unknown balance and no synthetic catalogue',
      () async {
    final repo = FirebaseVerifiedRewardsRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async => overview());
    final result = await repo.overview();
    expect(result.available, isFalse);
    expect(result.balance, isNull);
    expect(result.items, isEmpty);
  });
  test('rejects an in-flight overview from a logged-out or switched account',
      () async {
    var current = true;
    final entered = Completer<void>(),
        response = Completer<Map<String, dynamic>>();
    final repo = FirebaseVerifiedRewardsRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) {
          entered.complete();
          return response.future;
        });
    final pending = repo.overview();
    await entered.future;
    current = false;
    response.complete(overview());
    await expectLater(pending, throwsA(isA<BookingException>()));
    expect(repo.current, isFalse);
  });
  test('rejects foreign ownership inside a redemption response', () async {
    final repo = FirebaseVerifiedRewardsRepository(
        intents: intents(),
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async => {
              'schemaVersion': 1,
              'redemption': {
                'schemaVersion': 1,
                'organizationId': 'gainpath',
                'memberId': 'other',
                'redemptionId': 'r',
                'requestId': 'request',
                'itemId': 'item',
                'title': 'Synthetic',
                'points': 5,
                'status': 'issued',
                'issuedAtMillis': 1800000000000,
                'policyVersion': 'test',
                'exchangeRateVersion': 'test',
              }
            });
    await expectLater(repo.redeem(itemId: 'item', requestId: 'request'),
        throwsA(isA<BookingException>()));
  });
  test('only sends item and idempotency references when redeeming', () async {
    Map<String, dynamic>? sent;
    final repo = FirebaseVerifiedRewardsRepository(
        intents: intents(),
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (name, data) async {
          sent = data;
          return {
            'schemaVersion': 1,
            'redemption': {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'memberId': 'member',
              'redemptionId': 'r',
              'requestId': 'retry',
              'itemId': 'item',
              'title': 'Synthetic',
              'points': 5,
              'status': 'issued',
              'issuedAtMillis': 1800000000000,
              'policyVersion': 'test',
              'exchangeRateVersion': 'test',
            }
          };
        });
    expect((await repo.redeem(itemId: 'item', requestId: 'retry')).redemptionId,
        'r');
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'redeem',
      'itemId': 'item',
      'requestId': 'retry'
    });
  });
  test('new repository retries uncertain redemption with the persisted request',
      () async {
    final first = FirebaseVerifiedRewardsRepository(
      scope: scope,
      isCurrent: () => true,
      currentUid: () => 'member',
      readiness: ready(),
      intents: intents(),
      call: (_, __) async => throw const BookingException('unavailable'),
    );
    await expectLater(first.redeem(itemId: 'item', requestId: 'original'),
        throwsA(isA<BookingException>()));
    final resumed = FirebaseVerifiedRewardsRepository(
      scope: scope,
      isCurrent: () => true,
      currentUid: () => 'member',
      readiness: ready(),
      intents: intents(),
      call: (_, data) async {
        expect(data['requestId'], 'original');
        return {
          'schemaVersion': 1,
          'redemption': {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'memberId': 'member',
            'redemptionId': 'r',
            'requestId': 'original',
            'itemId': 'item',
            'title': 'Synthetic',
            'points': 5,
            'status': 'issued',
            'issuedAtMillis': 1800000000000,
            'policyVersion': 'test',
            'exchangeRateVersion': 'test',
          }
        };
      },
    );
    expect(
        (await resumed.redeem(itemId: 'item', requestId: 'new')).redemptionId,
        'r');
    expect(await intents().reserve('item', 'after-confirmation'),
        'after-confirmation');
  });
  test(
      'malformed available tier or cross-account history cannot enable redemption',
      () async {
    for (final patch in [
      {'effectiveTier': 'elite'},
      {'balance': -1},
      {'available': true, 'canRedeem': true, 'policyVersion': 'test'}
    ]) {
      final repo = FirebaseVerifiedRewardsRepository(
          scope: scope,
          isCurrent: () => true,
          currentUid: () => 'member',
          readiness: ready(),
          call: (_, __) async => {...overview(), ...patch});
      await expectLater(repo.overview(), throwsA(isA<BookingException>()));
    }
  });
  test('fails closed when App Check readiness is unavailable', () async {
    final repo = FirebaseVerifiedRewardsRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: FirebaseAppCheckReadiness(supported: false),
        call: (_, __) async => throw StateError('Must not send'));
    await expectLater(
        repo.overview(),
        throwsA(isA<BookingException>()
            .having((e) => e.code, 'code', 'app-check-unavailable')));
  });
}
