import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';

const session = AuthSession(
    userId: 'admin',
    organizationId: 'org',
    email: 'a@example.test',
    role: AppRole.admin);
void main() {
  test('denies before transport when identity is stale', () async {
    var calls = 0;
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => true,
        currentUid: () => 'other',
        call: (name, data) async {
          calls++;
          return {};
        });
    await expectLater(repo.load(), throwsA(isA<PaymentReviewException>()));
    expect(calls, 0);
  });
  test('rejects late response after session drift', () async {
    var active = true;
    final response = Completer<Map<String, dynamic>>();
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => active,
        currentUid: () => 'admin',
        call: (name, data) => response.future);
    final pending = repo.load();
    active = false;
    response.complete({'schemaVersion': 1, 'records': []});
    await expectLater(pending, throwsA(isA<PaymentReviewException>()));
  });
  test('scopes list to captured organization and cursor', () async {
    final requests = <Map<String, dynamic>>[];
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (name, data) async {
          requests.add(data);
          return {'schemaVersion': 1, 'records': [], 'nextAfterId': 'next'};
        });
    expect((await repo.load(afterId: 'cursor')).nextAfterId, 'next');
    expect(requests.single,
        {'schemaVersion': 1, 'organizationId': 'org', 'afterId': 'cursor'});
  });
  test('rejects detail and action response for another booking', () async {
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (name, data) async => {
              'schemaVersion': 1,
              'payment': {
                'bookingId': 'other-booking',
                'memberId': 'member',
                'amountMinor': 1000,
                'currency': 'MYR',
                'paymentStatus': 'cleared',
                'fulfilmentStatus': 'confirmed'
              },
              'events': [],
              'refundExecutionAvailable': false,
            });
    await expectLater(
        repo.detail('requested-booking'), throwsA(isA<FormatException>()));
    await expectLater(
        repo.manage('requested-booking', 'verify', requestId: 'request'),
        throwsA(isA<FormatException>()));
  });
  test('rejects zero amounts and unknown payment states', () {
    final valid = {
      'bookingId': 'booking',
      'memberId': 'member',
      'amountMinor': 1000,
      'currency': 'MYR',
      'paymentStatus': 'cleared',
      'fulfilmentStatus': 'confirmed'
    };
    for (final invalid in [
      {'amountMinor': 0},
      {'paymentStatus': 'unknown'},
      {'fulfilmentStatus': 'unknown'},
      {'refundStatus': 'unknown'}
    ]) {
      expect(() => PaymentReviewRecord({...valid, ...invalid}),
          throwsFormatException);
    }
  });
}
