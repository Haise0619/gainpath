import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'live_booking_cubit_test.dart' show Options, Writer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_confirmed_screen.dart';

class Payments implements BookingPaymentRepository {
  String status = 'awaiting_payment';
  int gets = 0;
  int creates = 0;
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  BookingPaymentView value() => BookingPaymentView(
      bookingId: 'booking',
      status: status,
      quote: const BookingPaymentQuote(
          amountMinor: 12500,
          coachName: 'Real Coach',
          branchName: 'Real Studio',
          durationMinutes: 30),
      startLabel: '09:00',
      endLabel: '09:30',
      localDate: '2026-10-20',
      holdExpiresAtMillis: 123);
  @override
  Future<BookingPaymentView> get(String id) async {
    gets++;
    return value();
  }

  @override
  Future<BookingPaymentView> create(String id) async {
    creates++;
    return value();
  }

  @override
  Future<BookingPaymentQuote> loadQuote(
          {required String coachId,
          required String branchId,
          required int durationMinutes}) async =>
      value().quote;
}

void main() {
  testWidgets(
      'real quote then uncertain hold retry keeps original intent before payment',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = Payments();
    final writer = Writer();
    await tester.pumpWidget(MaterialApp(
        home: BookSessionScreen(
            options: Options(),
            writer: writer,
            coachId: 'coach',
            payments: repo,
            isCurrent: () => true,
            onOpenBookings: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('08:00 GMT+8').first);
    await tester.pumpAndSettle();
    expect(find.text('RM 125.00'), findsOneWidget);
    expect(find.text('Real Coach'), findsOneWidget);
    expect(find.text('Real Studio'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue to payment'));
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    expect(find.text('Retry same request'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry same request'));
    await tester.tap(find.text('Retry same request'));
    await tester.pumpAndSettle();
    expect(writer.requests.length, 2);
    expect(writer.requests[0].requestId, writer.requests[1].requestId);
    expect(repo.creates, 1);
    expect(find.byType(BookingPaymentScreen), findsOneWidget);
    expect(find.byType(BookingConfirmedScreen), findsNothing);
  });
  testWidgets(
      'pending trusted status does not show success; refresh is throttled',
      (tester) async {
    final repo = Payments();
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    expect(find.text('Real Coach'), findsOneWidget);
    expect(find.text('RM 125.00'), findsOneWidget);
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(repo.gets, 1);
  });
  testWidgets('confirmed trusted status uses shared confirmation',
      (tester) async {
    final repo = Payments()..status = 'confirmed';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
    expect(find.text('RM 125.00'), findsOneWidget);
  });
  testWidgets('account switch hides previous account payment', (tester) async {
    final repo = Payments();
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => false)));
    await tester.pumpAndSettle();
    expect(repo.gets, 0);
    expect(find.text('Payments unavailable for this session.'), findsOneWidget);
  });
  testWidgets('reconciliation never shows success', (tester) async {
    final repo = Payments()..status = 'reconciliation_required';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    expect(find.text('Payment needs review'), findsOneWidget);
  });
}
