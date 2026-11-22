import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show BookingCursor, BookingHold, BookingPage;
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'booking_payment_consumer_test.dart' show ConsumerPayments;
import 'booking_selection_consumer_test.dart' show SelectionOptions;
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'live_booking_cubit_test.dart' show Writer;
import 'booking_history_coach_fix_test.dart' show bookingJson;
import 'member_booking_refresh_test.dart' show RangeBookings;
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';

class CommercialPayments extends ConsumerPayments
    implements BookingPaymentSelectionRepository {
  String? choiceCode, reviewToken;
  bool existing = false;
  bool recoverLegacy = false;
  String checkoutUrl = 'https://www.billplz-sandbox.com/bills/original';
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
      checkoutUrl: checkoutUrl,
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

class _PendingBookings extends RangeBookings {
  @override
  Future<BookingPage> load({
    String? coachId,
    String? firstLocalDate,
    int? dayCount,
    BookingCursor? cursor,
  }) async {
    final page = await super.load(
        firstLocalDate: firstLocalDate, dayCount: dayCount, cursor: cursor);
    return BookingPage.fromJson({
      ...page.toJson(),
      'records': [
        if (dayCount != 1 && firstLocalDate == null)
          {
            ...bookingJson('booking', DateTime.utc(2026, 11, 12, 2, 30),
                status: 'pending_hold'),
            'createdAtMillis': page.serverNowMillis - 60000,
            'holdExpiresAtMillis': page.serverNowMillis + 600000,
          },
      ],
    });
  }
}

void main() {
  testWidgets('My bookings retains the preference when reopening the hold',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final payments = CommercialPayments();
    await t.pumpWidget(MaterialApp(
      home: LiveBookingListView(
        repository: _PendingBookings(),
        isCurrent: () => true,
        createPaymentRepository: () => payments,
      ),
    ));
    await t.pumpAndSettle();
    final continuePayment = find.text('Continue to Payment');
    await t.scrollUntilVisible(continuePayment, 180,
        scrollable: find.byType(Scrollable).first);
    await t.tap(continuePayment);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('CIMB Clicks'), 180,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('CIMB Clicks'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(continuePayment);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(payments.loads, 2);
    expect(payments.creates, 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('returning to review preserves the preference for the same hold',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final writer = Writer()..pending = Completer();
    final payments = CommercialPayments();
    await t.pumpWidget(MaterialApp(
      home: BookSessionScreen(
        options: SelectionOptions(),
        writer: writer,
        payments: payments,
        coachId: 'coach',
        isCurrent: () => true,
        onOpenBookings: () {},
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('8:00 AM'));
    await t.pumpAndSettle();
    await t.tap(find.text('Review Booking'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue to payment'));
    await t.pump();
    writer.pending!.complete(BookingHold.fromJson({
      'schemaVersion': 1,
      'requestId': writer.requests.single.requestId,
      'bookingId': 'booking',
      'status': 'pending_hold',
      'holdExpiresAtMillis': payments.expiry,
    }));
    await t.pumpAndSettle();
    expect(payments.loads, 1);
    await t.scrollUntilVisible(find.text('E-Wallet'), 180,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('E-Wallet'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('GrabPay'), 180,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('GrabPay'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text('Continue reservation'));
    await t.pumpAndSettle();
    expect(find.text('GrabPay'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(writer.requests, hasLength(1));
    expect(payments.creates, 0);
    await t.pumpWidget(const SizedBox());
  });

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

  testWidgets('checkout expands one category and searches all banks',
      (t) async {
    final r = CommercialPayments();
    await show(t, r);
    expect(find.text('GrabPay'), findsNothing);
    expect(find.text('Visa / Mastercard'), findsNothing);
    expect(find.text('Maybank2u'), findsOneWidget);
    await tap(t, 'More Banks');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'affin');
    await t.pumpAndSettle();
    expect(find.text('BSN'), findsNothing);
    await t.tap(find.text('Affin Bank'));
    await t.pumpAndSettle();
    expect(find.text('Affin Bank').hitTestable(), findsOneWidget);
    await tap(t, 'E-Wallet');
    await t.pumpAndSettle();
    expect(find.text('Maybank2u'), findsNothing);
    await tap(t, 'GrabPay');
    await tap(t, 'Credit / Debit Card');
    await t.pumpAndSettle();
    expect(find.text('Visa / Mastercard'), findsOneWidget);
    await tap(t, 'E-Wallet');
    await t.pumpAndSettle();
    expect(r.creates, 0);
    expect(find.text('Continue to Payment').hitTestable(), findsOneWidget);
    await t.tap(find.text('Continue to Payment'));
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
      'Xendit return stays pending until server confirms then shows recorded choice',
      (t) async {
    final r = CommercialPayments()
      ..checkoutUrl = 'https://checkout-staging.xendit.co/latest/test-checkout';
    Uri? opened;
    await show(t, r, open: (url) async {
      opened = url;
      return true;
    });
    await tap(t, 'Maybank2u');
    await t.tap(find.text('Continue to Payment'));
    await t.pump();
    expect(opened, Uri.parse(r.checkoutUrl));
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
    await t.tap(find.text('Continue to Payment'));
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
    expect(find.text('Continue to Payment'), findsNothing);
    expect(r.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'recovering an older invoice does not falsely attach local preference',
      (t) async {
    final r = CommercialPayments()..recoverLegacy = true;
    await show(t, r);
    await tap(t, 'Maybank2u');
    await t.tap(find.text('Continue to Payment'));
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
