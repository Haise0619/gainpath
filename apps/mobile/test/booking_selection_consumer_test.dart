import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' as core;
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'booking_payment_screen_test.dart' show Payments;
import 'live_booking_cubit_test.dart' show Options, Writer;

class SelectionPayments extends Payments
    implements ReviewedBookingPaymentRepository {
  int amount = 12500, quoteCalls = 0;
  bool changeOnReview = false;
  @override
  Future<BookingPaymentQuote> loadQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes}) async {
    quoteCalls++;
    if (changeOnReview && quoteCalls > 2) amount = 14000;
    return BookingPaymentQuote(
        amountMinor: amount,
        coachName: 'Real Coach',
        branchName: 'Real Studio',
        durationMinutes: durationMinutes,
        quoteToken: 'a' * 64,
        serverNowMillis: 1791936000000);
  }

  @override
  Future<BookingPaymentView> createReviewed(String bookingId,
          {required String quoteToken, bool usePremiumVoucher = false}) =>
      create(bookingId);
}

class SelectionOptions extends Options {
  final durations = <int>[];
  @override
  Future<core.BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    durations.add(durationMinutes);
    final base = await super.load(
        coachId: coachId,
        localDate: localDate ?? '2026-10-15',
        durationMinutes: durationMinutes);
    final json = base.toJson();
    final start = DateTime.parse('${base.localDate}T00:00:00Z')
        .add(Duration(hours: base.localDate == base.todayLocalDate ? 2 : 0));
    json['coachDisplayName'] = 'Real Coach';
    json['branchDisplayNames'] = {'branch': 'Real Studio'};
    json['options'] = [
      for (var i = 0; i < 6; i++)
        {
          'branchId': 'branch',
          'startAtMillis':
              start.add(Duration(minutes: i * 30)).millisecondsSinceEpoch,
          'endAtMillis': start
              .add(Duration(minutes: i * 30 + durationMinutes))
              .millisecondsSinceEpoch,
          'startLabel':
              '${8 + (base.localDate == base.todayLocalDate ? 2 : 0) + i ~/ 2}:${i.isEven ? '00' : '30'} GMT+8',
          'endLabel':
              '${9 + (base.localDate == base.todayLocalDate ? 2 : 0) + i ~/ 2}:${i.isEven ? '00' : '30'} GMT+8',
        }
    ];
    return core.BookingOptionsContext.fromJson(json);
  }
}

class EmptyUntilSelectionOptions extends SelectionOptions {
  @override
  Future<core.BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    final result = await super.load(
        coachId: coachId,
        localDate: localDate,
        durationMinutes: durationMinutes);
    if (result.localDate.compareTo('2026-10-16') >= 0) return result;
    return core.BookingOptionsContext.fromJson({
      ...result.toJson(),
      'options': [],
      'unavailableReason': 'no_open_times'
    });
  }
}

class DelayedSelectionPayments extends SelectionPayments {
  final pending = Completer<BookingPaymentQuote>();
  @override
  Future<BookingPaymentQuote> loadQuote(
          {required String coachId,
          required String branchId,
          required int durationMinutes}) =>
      pending.future;
}

class ExpiringSelectionVoucher extends SelectionPayments
    implements PremiumVoucherBookingPaymentRepository {
  @override
  Future<BookingPaymentQuote> loadVoucherQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes,
      required bool usePremiumVoucher}) async {
    if (usePremiumVoucher) {
      throw const core.BookingException('failed-precondition');
    }
    final quote = await super.loadQuote(
        coachId: coachId, branchId: branchId, durationMinutes: durationMinutes);
    return BookingPaymentQuote(
        amountMinor: quote.amountMinor,
        coachName: quote.coachName,
        branchName: quote.branchName,
        durationMinutes: 60,
        quoteToken: quote.quoteToken,
        voucher: const PremiumCoachVoucherOffer(
            status: 'available', discountMinor: 1000));
  }

  @override
  Future<BookingPaymentView> createWithPremiumVoucher(String bookingId) =>
      create(bookingId);
}

Future<void> selection(WidgetTester tester, SelectionOptions options,
    SelectionPayments payments, Writer writer) async {
  await tester.pumpWidget(MaterialApp(
      home: BookSessionScreen(
          options: options,
          writer: writer,
          payments: payments,
          coachId: 'coach',
          isCurrent: () => true,
          onOpenBookings: () {})));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'uncertain reservation keeps review retry reachable and blocks toolbar back',
      (tester) async {
    final writer = Writer();
    await selection(tester, SelectionOptions(), SelectionPayments(), writer);
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(find.text('Retry reservation'), findsOneWidget);
    final back = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Back'));
    expect(back.onPressed, isNull);
    expect(writer.requests, hasLength(1));
  });
  testWidgets(
      'next available date is selected only after successful server availability reads',
      (tester) async {
    await selection(
        tester, EmptyUntilSelectionOptions(), SelectionPayments(), Writer());
    expect(find.text('No open sessions on this date'), findsNothing);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Real Studio'), findsOneWidget);
  });
  testWidgets('late quote cannot reveal previous-account details',
      (tester) async {
    var current = true;
    final payments = DelayedSelectionPayments(),
        options = SelectionOptions(),
        writer = Writer();
    Widget app() => MaterialApp(
        home: BookSessionScreen(
            options: options,
            writer: writer,
            payments: payments,
            coachId: 'coach',
            isCurrent: () => current,
            onOpenBookings: () {}));
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();
    current = false;
    await tester.pumpWidget(app());
    payments.pending.complete(const BookingPaymentQuote(
        amountMinor: 999,
        coachName: 'Private previous coach',
        branchName: 'Private previous branch',
        durationMinutes: 60));
    await tester.pumpAndSettle();
    expect(find.text('Private previous coach'), findsNothing);
    expect(find.text('Private previous branch'), findsNothing);
    expect(find.text('Sign in again to view your booking.'), findsOneWidget);
  });
  testWidgets(
      'unavailable selected voucher returns to explicit standard-price consent',
      (tester) async {
    final payments = ExpiringSelectionVoucher(), writer = Writer();
    await selection(tester, SelectionOptions(), payments, writer);
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use Premium Coach voucher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Premium Coach voucher'));
    await tester.pumpAndSettle();
    expect(find.textContaining('voucher could not be applied'), findsOneWidget);
    expect(find.text('Accept updated price'), findsOneWidget);
    expect(writer.requests, isEmpty);
  });
  testWidgets(
      'fixed 60 selection shows friendly time and no premature summary; review creates no hold',
      (tester) async {
    final options = SelectionOptions(),
        payments = SelectionPayments(),
        writer = Writer();
    await selection(tester, options, payments, writer);
    expect(options.durations, everyElement(60));
    expect(options.durations.length, lessThanOrEqualTo(7));
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.text('60-minute coaching session'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.textContaining('GMT+8'), findsNothing);
    expect(find.text('Booking Summary'), findsNothing);
    final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Review Booking'));
    expect(review.onPressed, isNull);
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Review booking'), findsOneWidget);
    expect(find.text('Real Studio'), findsWidgets);
    expect(find.textContaining('12 hours'), findsOneWidget);
    expect(find.textContaining('24 hours'), findsOneWidget);
    expect(writer.requests, isEmpty);
  });
  testWidgets(
      'changed reviewed price requires explicit acceptance before reserving',
      (tester) async {
    final payments = SelectionPayments()..changeOnReview = true;
    final writer = Writer();
    await selection(tester, SelectionOptions(), payments, writer);
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Booking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('price changed'), findsOneWidget);
    expect(find.text('Accept updated price'), findsOneWidget);
    expect(writer.requests, isEmpty);
    await tester.tap(find.text('Accept updated price'));
    await tester.pumpAndSettle();
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(writer.requests, isEmpty);
  });
}
