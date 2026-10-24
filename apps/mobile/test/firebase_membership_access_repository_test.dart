import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_membership_access_repository.dart';

Map<String, dynamic> _response() => {
      'schemaVersion': 1,
      'policyVersion': 'gainpath-membership-access-v1',
      'organizationId': 'o',
      'memberId': 'm',
      'resolvedAtMillis': 1800000000000,
      'feature': 'exercise',
      'resourceId': 'supported',
      'effectiveTier': 'free',
      'requiredTier': 'free',
      'decision': 'allowed',
      'reason': 'tier_access'
    };
void main() {
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'fixture');
  test(
      'sends resource references only and validates account-owned fresh response',
      () async {
    final repo = FirebaseMembershipAccessRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => true,
        currentUid: () => 'm',
        readiness: ready(),
        call: (name, data) async {
          expect(name, 'getMembershipAccessCommand');
          expect(data, {
            'schemaVersion': 1,
            'organizationId': 'o',
            'feature': 'exercise',
            'resourceId': 'supported'
          });
          return _response();
        });
    expect(
        (await repo.check(MembershipAccessFeature.exercise, 'supported'))
            .permitsEntry,
        isTrue);
  });
  test('rejects cached and cross-account responses without fallback', () async {
    for (final patch in [
      {'cached': true},
      {'memberId': 'other'},
      {'organizationId': 'other'}
    ]) {
      final repo = FirebaseMembershipAccessRepository(
          scope: SessionScope(userId: 'm', organizationId: 'o'),
          isCurrent: () => true,
          currentUid: () => 'm',
          readiness: ready(),
          call: (_, __) async => {..._response(), ...patch});
      await expectLater(
          repo.check(MembershipAccessFeature.exercise, 'supported'),
          throwsA(isA<BookingException>()));
    }
  });
  test('discards a result arriving after account invalidation', () async {
    var current = true;
    final result = Completer<Map<String, dynamic>>(),
        entered = Completer<void>();
    final repo = FirebaseMembershipAccessRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => current,
        currentUid: () => 'm',
        readiness: ready(),
        call: (_, __) {
          entered.complete();
          return result.future;
        });
    final pending = repo.check(MembershipAccessFeature.exercise, 'supported');
    await entered.future;
    current = false;
    result.complete(_response());
    await expectLater(pending, throwsA(isA<BookingException>()));
  });
}
