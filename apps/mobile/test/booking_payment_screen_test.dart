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
  bool fail = false;
  String? refundStatus;
  String? paymentStatus;
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  BookingPaymentView value() => BookingPaymentView(
      bookingId: 'booking',
      status: status,
      refundStatus: refundStatus,
      paymentStatus: paymentStatus,
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
    if (fail) throw StateError("offline");
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments()..status = 'confirmed';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
    expect(find.text('RM 125.00'), findsOneWidget);
  });
  testWidgets('account switch hides previous account payment', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments();
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => false)));
    await tester.pumpAndSettle();
    expect(repo.gets, 0);
    expect(find.text('Payments unavailable for this session.'), findsOneWidget);
  });
  testWidgets('reconciliation never shows success', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments()..status = 'reconciliation_required';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    expect(find.text('Payment needs review'), findsOneWidget);
  });
  testWidgets(
      'resume within cooldown checks eventually without early hammering',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments();
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => true,
            now: tester.binding.clock.now)));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.gets, 1);
    expect(find.textContaining('Waiting for the next trusted check'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(repo.gets, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.gets, 2);
    expect(repo.creates, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.gets, 3);
  });

  testWidgets('background and account drift stop automatic checks',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments();
    var current = true;
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => current,
            now: tester.binding.clock.now)));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(repo.gets, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.gets, 2);
    current = false;
    await tester.pump(const Duration(seconds: 20));
    expect(repo.gets, 2);
  });

  testWidgets('automatic checks recover errors then stop on confirmation',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => true,
            now: tester.binding.clock.now)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payment status unavailable'), findsOneWidget);
    repo.fail = false;
    repo.status = 'confirmed';
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(repo.gets, 2);
  });

  testWidgets('automatic checks are bounded and dispose cancels timer',
      (tester) async {
    final repo = Payments();
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => true,
            now: tester.binding.clock.now)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 10));
    }
    expect(repo.gets, 7);
    expect(find.textContaining('Automatic checks paused'), findsOneWidget);
    await tester.tap(find.text('Check payment status'));
    await tester.pump();
    expect(repo.gets, 8);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    expect(repo.gets, 8);
  });
  testWidgets('completed refund never confirms the booking', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments()
      ..status = 'confirmed'
      ..refundStatus = 'completed';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    expect(find.text('Refund completed'), findsOneWidget);
  });

  testWidgets('unpaid reconciliation does not claim a refund is underway',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final repo = Payments()
      ..status = 'reconciliation_required'
      ..paymentStatus = 'pending';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Payment needs review'), findsOneWidget);
    expect(find.text('Refund in progress'), findsNothing);
    expect(find.textContaining('before attempting another payment'),
        findsOneWidget);
  });
}
