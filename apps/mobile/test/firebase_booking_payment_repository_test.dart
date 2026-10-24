import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_booking_payment_repository.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'synthetic-unit-token');
  final payment = <String, dynamic>{
    'schemaVersion': 1,
    'bookingId': 'booking',
    'status': 'awaiting_payment',
    'amountMinor': 12500,
    'currency': 'MYR',
    'coachName': 'Coach',
    'branchName': 'Studio',
    'durationMinutes': 30,
    'startLabel': '09:00',
    'endLabel': '09:30',
    'localDate': '2026-10-20',
    'holdExpiresAtMillis': 123,
    'checkoutUrl': 'https://www.billplz-sandbox.com/bills/abc'
  };
  test('create sends booking reference only and validates hosted URL',
      () async {
    Map<String, dynamic>? received;
    String? name;
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (n, input) async {
          name = n;
          received = input;
          return payment;
        });
    expect((await repo.create('booking')).confirmed, isFalse);
    expect(name, 'createBookingPaymentCommand');
    expect(received,
        {'schemaVersion': 1, 'organizationId': 'org', 'bookingId': 'booking'});
    payment['checkoutUrl'] = 'https://billplz-sandbox.com.evil.test/bills/abc';
    await expectLater(repo.create('booking'), throwsA(isA<BookingException>()));
    payment['checkoutUrl'] = 'https://www.billplz-sandbox.com/bills/abc';
  });
  test(
      'voucher operations send only the explicit choice and trusted booking references',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (name, input) async {
          calls.add(input);
          return payment;
        });
    await repo.loadVoucherQuote(
        coachId: 'coach',
        branchId: 'branch',
        durationMinutes: 30,
        usePremiumVoucher: false);
    await repo.createWithPremiumVoucher('booking');
    expect(calls, [
      {
        'schemaVersion': 1,
        'organizationId': 'org',
        'coachId': 'coach',
        'branchId': 'branch',
        'durationMinutes': 30,
        'includePremiumVoucher': true
      },
      {
        'schemaVersion': 1,
        'organizationId': 'org',
        'bookingId': 'booking',
        'usePremiumVoucher': true
      },
    ]);
  });
  test('response after account switch is discarded', () async {
    var current = true;
    final response = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) {
          started.complete();
          return response.future;
        });
    final future = repo.get('booking');
    await started.future;
    current = false;
    response.complete(payment);
    await expectLater(future, throwsA(isA<BookingException>()));
  });
}
