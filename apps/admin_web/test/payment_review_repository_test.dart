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
  Map<String, dynamic> detailResponse(String id) => {
        'schemaVersion': 1,
        'payment': {
          'bookingId': id,
          'memberId': 'member',
          'amountMinor': 100,
          'currency': 'MYR',
          'paymentStatus': 'cleared',
          'fulfilmentStatus': 'confirmed'
        },
        'events': <Map<String, dynamic>>[],
        'refundExecutionAvailable': false,
      };
  test(
      'shares only overlapping payment page reads and preserves cursor isolation',
      () async {
    var calls = 0;
    final pending = Completer<Map<String, dynamic>>();
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (_, input) async {
          calls++;
          return input['afterId'] == null && calls == 1
              ? pending.future
              : {'schemaVersion': 1, 'records': []};
        });
    final first = repo.load(), duplicate = repo.load();
    expect(calls, 1);
    await repo.load(afterId: 'other-page');
    expect(calls, 2);
    pending.complete({'schemaVersion': 1, 'records': []});
    await Future.wait([first, duplicate]);
    await repo.load();
    expect(calls, 3); // Completed pages are never reused.
  });
  test('shares overlapping detail reads but never coalesces financial commands',
      () async {
    var reads = 0, mutations = 0;
    final pending = Completer<Map<String, dynamic>>();
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => true,
        currentUid: () => 'admin',
        call: (name, input) async {
          if (name == 'manageAdminBookingPaymentCommand') {
            mutations++;
            return detailResponse('booking');
          }
          reads++;
          return reads == 1 ? pending.future : detailResponse('booking');
        });
    final first = repo.detail('booking'), duplicate = repo.detail('booking');
    expect(reads, 1);
    await Future.wait([
      repo.manage('booking', 'verify', requestId: 'one'),
      repo.manage('booking', 'verify', requestId: 'two')
    ]);
    expect(mutations, 2);
    await repo.detail('booking');
    expect(reads, 2); // Post-command detail cannot join a pre-command read.
    pending.complete(detailResponse('booking'));
    await Future.wait([first, duplicate]);
  });
  test(
      'failed shared reads clear for retry and late shared reads retain session checks',
      () async {
    var current = true, calls = 0;
    final pending = Completer<Map<String, dynamic>>();
    final repo = FirebasePaymentReviewRepository(
        session: session,
        isCurrent: () => current,
        currentUid: () => 'admin',
        call: (_, __) {
          calls++;
          return calls == 1
              ? Future.error(const PaymentReviewException('unavailable'))
              : pending.future;
        });
    await expectLater(repo.load(), throwsA(isA<PaymentReviewException>()));
    final first = repo.load(), duplicate = repo.load();
    expect(calls, 2);
    current = false;
    pending.complete({'schemaVersion': 1, 'records': []});
    await expectLater(first, throwsA(isA<PaymentReviewException>()));
    await expectLater(duplicate, throwsA(isA<PaymentReviewException>()));
  });
  test(
      'rejects inconsistent voucher finance instead of displaying invented amounts',
      () {
    expect(
        () => PaymentReviewRecord({
              'bookingId': 'booking',
              'memberId': 'member',
              'amountMinor': 9000,
              'currency': 'MYR',
              'paymentStatus': 'cleared',
              'fulfilmentStatus': 'confirmed',
              'grossAmountMinor': 10000,
              'discountMinor': 1000,
              'premiumVoucher': {
                'schemaVersion': 1,
                'memberId': 'member',
                'amountMinor': 8000
              },
            }),
        throwsFormatException);
  });
  test('membership refund review is separate from provider completion', () {
    final r = PaymentReviewRecord({
      'bookingId': 'membership_test',
      'transactionId': 'membership_test',
      'kind': 'MembershipPurchase',
      'memberId': 'member',
      'amountMinor': 10000,
      'currency': 'MYR',
      'paymentStatus': 'cleared',
      'fulfilmentStatus': 'reconciliation_required',
      'refundStatus': 'pending_review'
    });
    expect(r.isMembership, isTrue);
    expect(r.canDecide, isTrue);
    final approved =
        PaymentReviewRecord({...r.data, 'refundStatus': 'approved'});
    expect(approved.refundExplanation, contains('No money has been returned'));
  });
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
