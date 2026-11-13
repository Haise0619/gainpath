import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_confirmed_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'support/booking_payment_before.dart';

class ConsumerPayments
    implements BookingPaymentRepository, ReviewedBookingPaymentRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  int gets = 0, creates = 0;
  bool failed = false, changed = false;
  String status = 'awaiting_payment';
  String? refund, paid;
  int expiry = 1800000000000 + 600000;
  int? serverNow;
  BookingPaymentView get value => BookingPaymentView(
      bookingId: 'booking',
      status: status,
      quote: const BookingPaymentQuote(
          amountMinor: 12500,
          coachName: 'Jackson Lee',
          branchName: 'GainPath Studio',
          durationMinutes: 60),
      startLabel: '09:00',
      endLabel: '10:00',
      localDate: '2027-01-15',
      holdExpiresAtMillis: expiry,
      checkoutUrl: 'https://www.billplz-sandbox.com/bills/example',
      paymentStatus: paid,
      refundStatus: refund,
      serverNowMillis: serverNow);
  @override
  Future<BookingPaymentView> get(String id) async {
    gets++;
    if (failed) throw StateError('offline');
    return value;
  }

  @override
  Future<BookingPaymentView> create(String id) async {
    creates++;
    return value;
  }

  @override
  Future<BookingPaymentView> createReviewed(String id,
      {required String quoteToken, bool usePremiumVoucher = false}) async {
    creates++;
    if (changed) throw const BookingException('booking-quote-changed');
    return value;
  }

  @override
  Future<BookingPaymentQuote> loadQuote(
          {required String coachId,
          required String branchId,
          required int durationMinutes}) async =>
      value.quote;
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1800000000000);
  setUpAll(loadDemoRenderFonts);
  Future<void> setup(WidgetTester t, ConsumerPayments repo,
      {bool create = false, bool Function()? current}) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: current ?? () => true,
            now: () =>
                now.add(t.binding.clock.now().difference(DateTime(2015))),
            create: create,
            reviewedQuoteToken: create ? 'reviewed' : null)));
    await t.pump();
  }

  testWidgets(
      'reviewed checkout is created once and not automatically launched',
      (t) async {
    final repo = ConsumerPayments()..expiry = 9999999999999;
    await setup(t, repo, create: true);
    expect(repo.creates, 1);
    expect(find.text('Continue to Payment'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
    expect(repo.creates, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'price change requires review and never retries checkout automatically',
      (t) async {
    final repo = ConsumerPayments()..changed = true;
    await setup(t, repo, create: true);
    expect(find.text('Return to booking review'), findsOneWidget);
    await t.pump(const Duration(seconds: 20));
    expect(repo.creates, 1);
    expect(find.text('Continue to Payment'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('expired hold blocks payment and keeps status recovery',
      (t) async {
    final repo = ConsumerPayments()..expiry = 1;
    await setup(t, repo);
    expect(find.text('Reservation expired'), findsOneWidget);
    expect(find.text('Continue to Payment'), findsNothing);
    expect(find.text('Check payment status'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'server anchor ignores fast device clock and refund prevents confirmation',
      (t) async {
    final repo = ConsumerPayments()..serverNow = 1800000000000;
    await setup(t, repo);
    expect(find.text('Reservation expired'), findsNothing);
    expect(find.text('Time remaining: 10:00'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    repo
      ..status = 'confirmed'
      ..refund = 'processing';
    await setup(t, repo);
    expect(find.text('Refund in progress'), findsOneWidget);
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'pending errors recover by checking same bill and account drift hides data',
      (t) async {
    final repo = ConsumerPayments()..failed = true;
    var current = true;
    await setup(t, repo, current: () => current);
    expect(find.textContaining('Payment status unavailable'), findsOneWidget);
    repo
      ..failed = false
      ..status = 'confirmed';
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
    expect(repo.creates, 0);
    await t.pumpWidget(const SizedBox());
    current = false;
    await setup(t, repo, current: () => current);
    expect(find.text('Payments unavailable for this session.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'background expires legacy hold and resume checks without creating another bill',
      (t) async {
    final repo = ConsumerPayments();
    var localNow = now;
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => true,
            now: () => localNow)));
    await t.pumpAndSettle();
    expect(find.text('Time remaining: 10:00'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    localNow = now.add(const Duration(minutes: 11));
    await t.pump(const Duration(minutes: 11));
    expect(repo.gets, 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(repo.gets, 2);
    expect(repo.creates, 0);
    expect(find.text('Reservation expired'), findsOneWidget);
    expect(find.text('Continue to Payment'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'received payment shows verification without another payment action',
      (t) async {
    final repo = ConsumerPayments()..paid = 'cleared';
    await setup(t, repo);
    expect(find.text('Confirming your payment'), findsOneWidget);
    expect(find.text('Continue to Payment'), findsNothing);
    expect(find.textContaining('Time remaining:'), findsNothing);
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unpaid cancellation failure retains reservation and allows retry',
      (t) async {
    final repo = ConsumerPayments();
    var cancels = 0;
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: BookingPaymentScreen(
            repository: repo,
            bookingId: 'booking',
            isCurrent: () => true,
            now: () => now,
            onCancelUnpaidReservation: () async {
              cancels++;
              throw StateError('offline');
            })));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel unpaid reservation'));
    await t.pumpAndSettle();
    expect(cancels, 1);
    expect(find.textContaining('Could not cancel your reservation'),
        findsOneWidget);
    expect(find.text('Continue to Payment'), findsOneWidget);
    expect(repo.creates, 0);
    await t.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final stage in [
        'before',
        'hold',
        'verifying',
        'confirmed',
        'refund'
      ]) {
        testWidgets('render $stage $width $scale', (t) async {
          final restore = await installFypOfflineFonts();
          addTearDown(restore);
          t.view.physicalSize = Size(width, 960);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final repo = ConsumerPayments();
          if (stage == 'verifying') repo.paid = 'cleared';
          if (stage == 'confirmed') repo.status = 'confirmed';
          if (stage == 'refund') {
            repo.status = 'reconciliation_required';
            repo.refund = 'processing';
          }
          final key = GlobalKey();
          final screen = stage == 'before'
              ? BookingPaymentBeforeScreen(
                  repository: repo,
                  bookingId: 'booking',
                  isCurrent: () => true,
                  now: () => now)
              : stage == 'confirmed'
                  ? BookingConfirmedScreen(payment: repo.value)
                  : BookingPaymentScreen(
                      repository: repo,
                      bookingId: 'booking',
                      isCurrent: () => true,
                      now: () => now);
          await t.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildMemberTypographyTheme(),
                  builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(c)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: screen)));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          Future<void> capture(String suffix) async {
            expect(t.takeException(), isNull);
            final boundary =
                t.renderObject<RenderRepaintBoundary>(find.byKey(key));
            await t.runAsync(() async {
              final img = await boundary.toImage();
              final bytes =
                  await img.toByteData(format: ui.ImageByteFormat.png);
              final file = File(
                  '../../build/booking-consumer-20261113/payment/$stage-${width.toInt()}-${scale.toInt()}x$suffix.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
          }

          await capture('');
          if (scale == 2) {
            await t.drag(find.byType(Scrollable).first, const Offset(0, -2400));
            await t.pumpAndSettle();
            await capture('-scrolled');
          }
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
