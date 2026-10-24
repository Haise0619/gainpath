import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import 'live_booking_cubit_test.dart' show Options, Writer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingOptionsContext;
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

class FutureOptions extends Options {
  final start =
      ((DateTime.now().millisecondsSinceEpoch ~/ 1800000) + 96) * 1800000;
  String date(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
          .add(const Duration(hours: 8))
          .toIso8601String()
          .substring(0, 10);
  @override
  Future<BookingOptionsContext> load(
          {required String coachId,
          String? localDate,
          required int durationMinutes}) async =>
      BookingOptionsContext.fromJson({
        'schemaVersion': 1,
        'coachId': coachId,
        'durationMinutes': durationMinutes,
        'serverNowMillis': DateTime.now().millisecondsSinceEpoch,
        'todayLocalDate': date(DateTime.now().millisecondsSinceEpoch),
        'localDate': localDate ?? date(start),
        'timeZone': 'Asia/Kuala_Lumpur',
        'throughLocalDate': date(start + 14 * 86400000),
        'permittedBranchIds': ['branch'],
        'options': [
          {
            'branchId': 'branch',
            'startAtMillis': start,
            'endAtMillis': start + durationMinutes * 60000,
            'startLabel': '08:00 GMT+8',
            'endLabel': '08:30 GMT+8'
          }
        ],
      });
}

class VoucherPayments extends Payments
    implements PremiumVoucherBookingPaymentRepository {
  String voucherStatus = 'available';
  int voucherCreates = 0;
  @override
  Future<BookingPaymentQuote> loadVoucherQuote(
          {required String coachId,
          required String branchId,
          required int durationMinutes,
          required bool usePremiumVoucher}) async =>
      BookingPaymentQuote(
          amountMinor: usePremiumVoucher ? 11250 : 12500,
          coachName: 'Real Coach',
          branchName: 'Real Studio',
          durationMinutes: durationMinutes,
          grossAmountMinor: usePremiumVoucher ? 12500 : null,
          discountMinor: usePremiumVoucher ? 1250 : null,
          voucher: PremiumCoachVoucherOffer(
              status: voucherStatus,
              discountMinor: voucherStatus == 'available' ? 1250 : null));
  @override
  Future<BookingPaymentView> createWithPremiumVoucher(String id) async {
    voucherCreates++;
    return value();
  }
}

void main() {
  testWidgets(
      'trusted voucher is opt-in, reloads total, and checkout keeps the selected choice',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = VoucherPayments(), writer = Writer();
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
    expect(repo.voucherCreates, 0);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('RM 112.50'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue to payment'));
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry same request'));
    await tester.tap(find.text('Retry same request'));
    await tester.pumpAndSettle();
    expect(repo.voucherCreates, 1);
    expect(repo.creates, 0);
  });
  testWidgets(
      'missing voucher policy displays unavailable while preserving full-price checkout',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = VoucherPayments()..voucherStatus = 'unavailable';
    await tester.pumpWidget(MaterialApp(
        home: BookSessionScreen(
            options: Options(),
            writer: Writer(),
            coachId: 'coach',
            payments: repo,
            isCurrent: () => true,
            onOpenBookings: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('08:00 GMT+8').first);
    await tester.pumpAndSettle();
    expect(find.text('Premium Coach voucher unavailable.'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('RM 125.00'), findsOneWidget);
  });
  testWidgets(
      'AI suggestion reloads trusted options and price without creating a hold or payment',
      (tester) async {
    final repo = Payments(), writer = Writer(), options = FutureOptions();
    final suggestion = BookingSuggestionAttachment.fromJson({
      'schemaVersion': 1,
      'coachId': 'coach',
      'coachName': 'Suggested Coach',
      'branchId': 'branch',
      'branchName': 'Studio',
      'localDate': options.date(options.start),
      'timeZone': 'Asia/Kuala_Lumpur',
      'startAtMillis': options.start,
      'endAtMillis': options.start + 1800000,
      'startLabel': '08:00 GMT+8',
      'endLabel': '08:30 GMT+8',
      'durationMinutes': 30,
      'amountMinor': 1,
      'currency': 'MYR',
      'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 60000,
      'requiresConfirmation': true
    });
    await tester.pumpWidget(MaterialApp(
        home: BookSessionScreen(
            options: options,
            writer: writer,
            coachId: 'coach',
            payments: repo,
            isCurrent: () => true,
            onOpenBookings: () {},
            suggestion: suggestion)));
    await tester.pumpAndSettle();
    expect(find.text('RM 125.00'), findsOneWidget);
    expect(writer.requests, isEmpty);
    expect(repo.creates, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final invalid in [
      {
        ...suggestion.data,
        'expiresAtMillis': DateTime.now().millisecondsSinceEpoch - 1
      },
      {
        ...suggestion.data,
        'startAtMillis': options.start + 7200000,
        'endAtMillis': options.start + 9000000
      },
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: BookSessionScreen(
              options: options,
              writer: writer,
              coachId: 'coach',
              payments: repo,
              isCurrent: () => true,
              onOpenBookings: () {},
              suggestion: BookingSuggestionAttachment.fromJson(invalid))));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'The suggested time expired or is no longer available. Choose a current time.'),
          findsOneWidget);
      expect(writer.requests, isEmpty);
      expect(repo.creates, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
      'approval and uncertain refund are never presented as a sent refund',
      (tester) async {
    final repo = Payments()
      ..status = 'reconciliation_required'
      ..refundStatus = 'approved';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Refund approved · not sent'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.refundStatus = 'uncertain';
    await tester.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo, bookingId: 'booking', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Refund outcome not confirmed'), findsOneWidget);
    expect(find.text('Refund in progress'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
