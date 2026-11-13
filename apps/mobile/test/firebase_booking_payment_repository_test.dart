import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctionsException;
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
  test('method selection sends only server code and reviewed token', () async {
    Map<String, dynamic>? sent;
    String? name;
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (n, d) async {
          name = n;
          sent = d;
          return payment;
        });
    await repo.createWithPaymentMethod('booking',
        gatewayCode: 'BCBB0235', quoteToken: 'a' * 64);
    expect(name, 'createBookingPaymentCommand');
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'org',
      'bookingId': 'booking',
      'quoteToken': 'a' * 64,
      'gatewayCode': 'BCBB0235'
    });
  });
  test('method discovery rejects stale account responses', () async {
    var current = true;
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: ready(),
        call: (n, d) async {
          expect(n, 'getBookingPaymentMethodsCommand');
          current = false;
          return {};
        });
    await expectLater(
        repo.loadPaymentMethods('booking'),
        throwsA(isA<BookingException>()
            .having((e) => e.code, 'code', 'permission-denied')));
  });
  test('only explicit no-checkout quote change permits review refresh',
      () async {
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, data) async {
          throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'changed',
              details: const {
                'reason': 'quote_changed',
                'checkoutCreated': false
              });
        });
    await expectLater(
        repo.createReviewed('booking', quoteToken: 'a' * 64),
        throwsA(isA<BookingException>()
            .having((e) => e.code, 'code', 'booking-quote-changed')));
  });
  test('reviewed checkout sends server token and explicit voucher choice',
      () async {
    Map<String, dynamic>? received;
    final repo = FirebaseBookingPaymentRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, data) async {
          received = data;
          return payment;
        });
    await repo.createReviewed('booking',
        quoteToken: 'a' * 64, usePremiumVoucher: true);
    expect(received?['quoteToken'], 'a' * 64);
    expect(received?['usePremiumVoucher'], isTrue);
    expect(received!.containsKey('amountMinor'), isFalse);
  });
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
        'includeQuoteToken': true,
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
