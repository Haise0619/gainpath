import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'booking_payment_consumer_test.dart' show ConsumerPayments;

class MethodPayments extends ConsumerPayments
    implements BookingPaymentMethodRepository {
  int discoveries = 0;
  String? selected;
  bool offline = false;
  bool enabledFpx = true;
  bool existing = false;
  Completer<BookingPaymentMethods>? gate;
  @override
  Future<BookingPaymentMethods> loadPaymentMethods(String id) async {
    discoveries++;
    if (gate != null) return gate!.future;
    if (offline) throw StateError('offline');
    if (existing) {
      return BookingPaymentMethods(
          methods: const [],
          serverNowMillis: 1800000000000,
          existingPayment: value);
    }
    return BookingPaymentMethods(
        methods: [
          if (enabledFpx) ...const [
            BookingPaymentMethod(
                code: 'BCBB0235', name: 'CIMB Clicks', category: 'fpx'),
            BookingPaymentMethod(
                code: 'MB2U0227', name: 'Maybank2u', category: 'fpx')
          ],
          const BookingPaymentMethod(
              code: 'BP-FKR01', name: 'Billplz Sandbox', category: 'billplz')
        ],
        serverNowMillis: 1800000000000,
        quote: value.quote,
        localDate: value.localDate,
        startLabel: value.startLabel,
        endLabel: value.endLabel,
        holdExpiresAtMillis: expiry);
  }

  @override
  Future<BookingPaymentView> createWithPaymentMethod(String id,
      {required String gatewayCode,
      String? quoteToken,
      bool usePremiumVoucher = false}) async {
    selected = gatewayCode;
    return createReviewed(id, quoteToken: quoteToken ?? '');
  }
}

void main() {
  Future<void> show(WidgetTester t, MethodPayments r,
      {bool Function()? current,
      bool create = true,
      Future<bool> Function(Uri)? openCheckout}) async {
    t.view.physicalSize = const Size(800, 1500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: r,
            bookingId: 'booking',
            isCurrent: current ?? () => true,
            create: create,
            openCheckout: openCheckout,
            reviewedQuoteToken: 'a' * 64,
            now: () => DateTime.fromMillisecondsSinceEpoch(1800000000000))));
    await t.pump();
  }

  testWidgets('select bank before bill creation, sends selected code once',
      (t) async {
    final r = MethodPayments();
    await show(t, r);
    expect(find.text('Choose a payment method'), findsOneWidget);
    expect(r.creates, 0);
    await t.tap(find.text('CIMB Clicks'));
    await t.pump();
    await t.tap(find.text('Continue to Payment'));
    await t.pump();
    expect(r.selected, 'BCBB0235');
    expect(r.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('does not advertise global FPX banks for Billplz-only collection',
      (t) async {
    final r = MethodPayments()..enabledFpx = false;
    await show(t, r);
    expect(find.text('Maybank2u'), findsNothing);
    expect(find.text('Billplz Sandbox'), findsOneWidget);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('discovery failure can retry without creating a bill', (t) async {
    final r = MethodPayments()..offline = true;
    await show(t, r);
    expect(find.text('Try again'), findsOneWidget);
    r.offline = false;
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(find.text('CIMB Clicks'), findsOneWidget);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('existing invoice skips bank switching and never recreates',
      (t) async {
    final r = MethodPayments()..existing = true;
    await show(t, r);
    expect(find.text('Choose a payment method'), findsNothing);
    expect(r.creates, 0);
    expect(r.gets, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'return from hosted payment prioritizes verification and reopens same bill',
      (t) async {
    final r = MethodPayments();
    final opened = <Uri>[];
    await show(t, r, openCheckout: (uri) async {
      opened.add(uri);
      return true;
    });
    await t.tap(find.text('CIMB Clicks'));
    await t.pump();
    await t.tap(find.text('Continue to Payment'));
    await t.pump();
    expect(find.text('Confirming your payment'), findsOneWidget);
    expect(find.text('Continue to Payment'), findsNothing);
    await t.tap(find.text('Return to payment'));
    await t.pump();
    expect(opened.length, 2);
    expect(opened.first, opened.last);
    expect(r.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'reopen own hold without invoice still chooses method before creation',
      (t) async {
    final r = MethodPayments();
    await show(t, r, create: false);
    expect(find.text('Choose a payment method'), findsOneWidget);
    expect(r.discoveries, 1);
    expect(r.creates, 0);
    expect(r.gets, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('late availability cannot expose previous account checkout',
      (t) async {
    var current = true;
    final r = MethodPayments()..gate = Completer();
    await show(t, r, current: () => current);
    current = false;
    r.gate!.complete(const BookingPaymentMethods(methods: [
      BookingPaymentMethod(
          code: 'BCBB0235', name: 'Private bank', category: 'fpx')
    ], serverNowMillis: 1800000000000));
    await t.pump();
    expect(find.text('Private bank'), findsNothing);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
}
