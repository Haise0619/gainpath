import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_membership_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/membership_cache.dart';

class CachedMembership extends MembershipCache {
  CachedMembership(super.scope, this.value);
  final Map<String, dynamic> value;
  int reads = 0;
  @override
  Future<Map<String, dynamic>?> read() async {
    reads++;
    return {...value, 'cached': true};
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {}
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'fixture-token');
  test('checkout sends references only, never a client price', () async {
    Map<String, dynamic>? sent;
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (name, data) async {
          sent = data;
          return {};
        });
    await repo.checkout('plan', 'CODE', 'retry-id', renewal: true);
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'planId': 'plan',
      'promoCode': 'CODE',
      'requestId': 'retry-id',
      'intent': 'renewal'
    });
  });
  test('rejects stale account before transport', () async {
    var calls = 0;
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => false,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async {
          calls++;
          return {};
        });
    await expectLater(repo.load(), throwsA(isA<BookingException>()));
    expect(calls, 0);
    expect(repo.current, isFalse);
  });
  test('discards in-flight response after logout', () async {
    var current = true;
    final response = Completer<Map<String, dynamic>>(),
        entered = Completer<void>();
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) {
          entered.complete();
          return response.future;
        });
    final pending = repo.load();
    await entered.future;
    current = false;
    response.complete({'organizationId': 'gainpath', 'memberId': 'member'});
    await expectLater(pending, throwsA(isA<BookingException>()));
  });
  test('refuses cross-account overview payload', () async {
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async =>
            {'organizationId': 'gainpath', 'memberId': 'other'});
    await expectLater(repo.load(), throwsA(isA<BookingException>()));
  });
  test('rejects cross-account entitlement inside an otherwise correct overview',
      () async {
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async => {
              'organizationId': 'gainpath',
              'memberId': 'member',
              'entitlement': {
                'schemaVersion': 1,
                'policyVersion': 'gainpath-effective-membership-v1',
                'organizationId': 'gainpath',
                'memberId': 'other',
                'resolvedAtMillis': 1800000000000,
                'status': 'resolved',
                'effectiveTier': 'free',
                'paidTier': null,
                'paidPlanId': null,
                'paidPlanName': null,
                'paidStatus': 'none',
                'paidExpiresAtMillis': null,
                'benefits': [],
                'reason': 'no_paid_membership',
              }
            });
    await expectLater(repo.load(), throwsA(isA<BookingException>()));
  });
  test('authorization denial never falls back to cached Free membership',
      () async {
    final cached = CachedMembership(
        scope, {'organizationId': 'gainpath', 'memberId': 'member'});
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        cache: cached,
        call: (_, __) async =>
            throw const BookingException('permission-denied'));
    await expectLater(repo.load(), throwsA(isA<BookingException>()));
    expect(cached.reads, 0);
  });
  test('cached response is still checked for captured identity', () async {
    final cached = CachedMembership(
        scope, {'organizationId': 'gainpath', 'memberId': 'other'});
    final repo = FirebaseMembershipRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        cache: cached,
        call: (_, __) async => throw const BookingException('unavailable'));
    await expectLater(repo.load(), throwsA(isA<BookingException>()));
  });
}
