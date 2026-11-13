import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'booking_payment_consumer_test.dart' show ConsumerPayments;

class CommercialPayments extends ConsumerPayments
    implements BookingPaymentSelectionRepository {
  String? choiceCode, reviewToken;
  bool existing = false;
  bool recoverLegacy = false;
  Completer<BookingPaymentMethods>? pending;
  int loads = 0;
  @override
  BookingPaymentView get value => BookingPaymentView(
      bookingId: 'booking',
      status: status,
      paymentStatus: paid,
      refundStatus: refund,
      quote: const BookingPaymentQuote(
          amountMinor: 12500,
          coachName: 'Jackson Lee',
          branchName: 'GainPath Studio',
          durationMinutes: 60,
          quoteToken:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
      startLabel: '09:00',
      endLabel: '10:00',
      localDate: '2027-01-15',
      holdExpiresAtMillis: expiry,
      serverNowMillis: 1800000000000,
      checkoutUrl: 'https://www.billplz-sandbox.com/bills/original',
      selectedPaymentMethod: choiceCode == null || recoverLegacy
          ? null
          : SelectedBookingPaymentMethod(
              choice:
                  bookingPaymentChoices.firstWhere((m) => m.code == choiceCode),
              selectedAt: 1800000000000));
  @override
  Future<BookingPaymentMethods> loadPaymentSelections(String id) async {
    loads++;
    if (pending != null) return pending!.future;
    return existing
        ? BookingPaymentMethods(
            methods: const [],
            serverNowMillis: 1800000000000,
            existingPayment: value)
        : BookingPaymentMethods(
            methods: const [],
            selectionMethods: bookingPaymentChoices,
            serverNowMillis: 1800000000000,
            quote: value.quote,
            localDate: value.localDate,
            startLabel: value.startLabel,
            endLabel: value.endLabel,
            holdExpiresAtMillis: expiry);
  }

  @override
  Future<BookingPaymentView> createWithSelectedPaymentMethod(String id,
      {required String selectedPaymentMethodCode,
      String? quoteToken,
      bool usePremiumVoucher = false}) async {
    choiceCode = selectedPaymentMethodCode;
    reviewToken = quoteToken;
    return createReviewed(id, quoteToken: quoteToken ?? '');
  }
}

void main() {
  Future<void> show(WidgetTester t, CommercialPayments r,
      {bool Function()? current, Future<bool> Function(Uri)? open}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final start = t.binding.clock.now();
    await t.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: r,
            bookingId: 'booking',
            isCurrent: current ?? () => true,
            create: true,
            onViewBookings: () {},
            reviewedQuoteToken: 'a' * 64,
            now: () => DateTime.fromMillisecondsSinceEpoch(1800000000000)
                .add(t.binding.clock.now().difference(start)),
            openCheckout: open ?? (_) => Future.value(true))));
    await t.pump();
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.scrollUntilVisible(find.text(text), 250,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    await Scrollable.ensureVisible(t.element(find.text(text)), alignment: 0.5);
    await t.pump();
    await t.tap(find.text(text));
    await t.pump();
  }

  testWidgets('grouped choices and sticky Continue do not expose testing words',
      (t) async {
    final r = CommercialPayments();
    await show(t, r);
    expect(find.text('Continue'), findsOneWidget);
    await tap(t, 'More banks');
    await tap(t, 'GrabPay');
    expect(r.creates, 0);
    expect(find.text('Continue').hitTestable(), findsOneWidget);
    expect(
        find.textContaining(
            RegExp('sandbox|simulator|demo|test', caseSensitive: false)),
        findsNothing);
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(r.choiceCode, 'grabpay');
    expect(r.reviewToken, 'a' * 64);
    expect(r.creates, 1);
    expect(find.text('Confirming payment'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('existing invoice retains choice and never offers bank switching',
      (t) async {
    final r = CommercialPayments()
      ..existing = true
      ..choiceCode = 'tng';
    await show(t, r);
    expect(find.text('Choose a payment method'), findsNothing);
    expect(find.text('Touch ’n Go eWallet'), findsOneWidget);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'hosted return stays pending until server confirms then shows recorded choice',
      (t) async {
    final r = CommercialPayments();
    await show(t, r);
    await tap(t, 'Maybank2u');
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Payment successful'), findsNothing);
    expect(r.creates, 1);
    r.status = 'confirmed';
    r.paid = 'cleared';
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Maybank2u'), findsOneWidget);
    await t.scrollUntilVisible(find.text('View My Bookings'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('View My Bookings'), findsOneWidget);
    expect(r.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'quote change keeps explicit review recovery without automatic new checkout',
      (t) async {
    final r = CommercialPayments()..changed = true;
    await show(t, r);
    await tap(t, 'Maybank2u');
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(seconds: 30));
    expect(find.text('Return to booking review'), findsOneWidget);
    expect(r.gets, 0);
    expect(r.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('expired selection cannot create payment', (t) async {
    final r = CommercialPayments()..expiry = 1799999999999;
    await show(t, r);
    expect(find.text('Choose another time'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'recovering an older invoice does not falsely attach local preference',
      (t) async {
    final r = CommercialPayments()..recoverLegacy = true;
    await show(t, r);
    await tap(t, 'Maybank2u');
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Maybank2u'), findsNothing);
    expect(r.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('account change discards delayed choice discovery', (t) async {
    var current = true;
    final r = CommercialPayments()..pending = Completer();
    await show(t, r, current: () => current);
    current = false;
    r.pending!.complete(const BookingPaymentMethods(
        methods: [],
        selectionMethods: bookingPaymentChoices,
        serverNowMillis: 1800000000000));
    await t.pump();
    expect(find.text('GrabPay'), findsNothing);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
}
