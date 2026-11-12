import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';

class ReviewFake implements PaymentReviewRepository {
  var record = PaymentReviewRecord({
    'bookingId': 'booking-1',
    'memberId': 'member',
    'coachName': 'Coach',
    'branchName': 'Branch',
    'amountMinor': 12000,
    'currency': 'MYR',
    'paymentStatus': 'cleared',
    'fulfilmentStatus': 'reconciliation_required'
  });
  int actions = 0;
  int loads = 0;
  String? reason;
  Completer<PaymentReviewDetail>? pending;
  @override
  Future<PaymentReviewPage> load({String? afterId}) async {
    loads++;
    return PaymentReviewPage([record]);
  }

  @override
  Future<PaymentReviewDetail> detail(String bookingId) async =>
      PaymentReviewDetail(record);
  @override
  Future<PaymentReviewDetail> manage(String bookingId, String action,
      {required String requestId,
      String? reason,
      String? billId,
      String? refundOrderId}) async {
    actions++;
    this.reason = reason;
    return pending == null ? PaymentReviewDetail(record) : pending!.future;
  }
}

void main() {
  testWidgets(
      'existing payment details show the saved voucher finance breakdown',
      (tester) async {
    final repo = ReviewFake();
    repo.record = PaymentReviewRecord({
      ...repo.record.data,
      'amountMinor': 9000,
      'grossAmountMinor': 10000,
      'discountMinor': 1000,
      'premiumVoucher': {
        'schemaVersion': 1,
        'voucherId': 'voucher',
        'memberId': 'member',
        'amountMinor': 9000,
        'grossAmountMinor': 10000,
        'discountMinor': 1000,
        'policyVersion': 'policy',
        'fundingSource': 'gym',
        'coachCommissionBasis': 'gross_fee',
        'financeApprovalId': 'finance',
        'commissionPolicyVersion': 'sandbox-coach-80-v1'
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: RefundsScreen(
            live: true, repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();
    expect(find.text('Original booking fee'), findsOneWidget);
    expect(find.text('RM 100.00'), findsOneWidget);
    expect(find.text('Premium voucher discount'), findsOneWidget);
    expect(find.text('RM 10.00'), findsOneWidget);
    expect(find.textContaining('Gym-funded'), findsOneWidget);
    expect(repo.actions, 0);
  });
  testWidgets(
      'queue shows schedule and uncertain detail explains safe recovery',
      (tester) async {
    final repo = ReviewFake();
    repo.record = PaymentReviewRecord({
      ...repo.record.data,
      'localDate': '2026-10-23',
      'startLabel': '10:00 GMT+8',
      'endLabel': '11:00 GMT+8',
      'refundStatus': 'uncertain',
      'refundReference': 'refund-booking-1'
    });
    await tester.pumpWidget(MaterialApp(
        home: RefundsScreen(
            live: true, repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-10-23'), findsWidgets);
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do not execute again'), findsOneWidget);
    expect(find.text('Execute sandbox refund'), findsNothing);
    expect(find.text('refund-booking-1'), findsOneWidget);
    expect(repo.actions, 0);
  });
  testWidgets('requires reason, prevents duplicates and reloads after approval',
      (tester) async {
    final repo = ReviewFake();
    await tester.pumpWidget(MaterialApp(
        home: RefundsScreen(
            live: true, repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();
    expect(find.text('Execute sandbox refund'), findsNothing);
    await tester.ensureVisible(find.text('Approve refund'));
    await tester.tap(find.text('Approve refund'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('A reason is required.'), findsOneWidget);
    expect(repo.actions, 0);
    await tester.enterText(
        find.byType(TextFormField), 'Paid booking could not be fulfilled');
    repo.pending = Completer<PaymentReviewDetail>();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump();
    expect(repo.actions, 1);
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Approve refund'));
    expect(button.onPressed, isNull);
    repo.pending!.complete(PaymentReviewDetail(repo.record));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(repo.reason, 'Paid booking could not be fulfilled');
  });
  testWidgets('narrow queue and details avoid overflow', (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: RefundsScreen(repository: ReviewFake())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('session invalidation while confirming never submits',
      (tester) async {
    var current = true;
    final repo = ReviewFake();
    await tester.pumpWidget(MaterialApp(
        home: RefundsScreen(
            live: true, repository: repo, isCurrent: () => current)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Approve refund'));
    await tester.tap(find.text('Approve refund'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField), 'Decision');
    current = false;
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.actions, 0);
  });
  testWidgets('unconnected console shows no fabricated records or metrics',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RefundsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('No payments on this page.'), findsOneWidget);
    expect(find.textContaining('DEMO-'), findsNothing);
  });

  testWidgets('sub-tab navigation switches between the 3 financial surfaces',
      (tester) async {
    PaymentsMode? lastMode;
    final repo = ReviewFake();
    await tester.pumpWidget(MaterialApp(
      home: PaymentsScreen(
        live: true,
        repository: repo,
        isCurrent: () => true,
        onNavigateMode: (mode) => lastMode = mode,
      ),
    ));
    await tester.pumpAndSettle();

    // Default mode is transactions
    expect(find.text('Transactions'), findsWidgets);
    expect(
        find.text('Track membership and coaching payments across facilities.'),
        findsOneWidget);

    // Switch to Refund Requests
    await tester.tap(find.text('Refund Requests').first);
    await tester.pumpAndSettle();
    expect(lastMode, PaymentsMode.refunds);
    expect(
        find.text(
            'Review, approve, and manage member refund requests with audit evidence.'),
        findsOneWidget);

    // Switch to Reconciliation
    await tester.tap(find.text('Reconciliation').first);
    await tester.pumpAndSettle();
    expect(lastMode, PaymentsMode.reconciliation);
    expect(
        find.text(
            'Investigate uncertain bills and resolve payment exceptions safely.'),
        findsOneWidget);
  });

  testWidgets(
      'cross-navigation banner links between transactions and reconciliation',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PaymentsMode? navigatedMode;
    final repo = ReviewFake();
    // Record has fulfilmentStatus: 'reconciliation_required' => isReconciliationCase is true
    await tester.pumpWidget(MaterialApp(
      home: PaymentsScreen(
        live: true,
        repository: repo,
        isCurrent: () => true,
        onNavigateMode: (mode) => navigatedMode = mode,
      ),
    ));
    await tester.pumpAndSettle();

    // Open detail from Transactions
    await tester.ensureVisible(find.text('booking-1'));
    await tester.tap(find.text('booking-1'));
    await tester.pumpAndSettle();

    // Verify cross-navigation banner is visible
    expect(find.text('Investigate in Reconciliation'), findsOneWidget);

    // Tap cross-navigation button
    await tester.ensureVisible(find.text('Investigate in Reconciliation'));
    await tester.tap(find.text('Investigate in Reconciliation'));
    await tester.pumpAndSettle();

    expect(navigatedMode, PaymentsMode.reconciliation);
    expect(
        find.text(
            'Investigate uncertain bills and resolve payment exceptions safely.'),
        findsOneWidget);

    // Now in Reconciliation mode, the banner offers "View in Transactions"
    expect(find.text('View in Transactions'), findsOneWidget);
    await tester.ensureVisible(find.text('View in Transactions'));
    await tester.tap(find.text('View in Transactions'));
    await tester.pumpAndSettle();

    expect(navigatedMode, PaymentsMode.transactions);
    expect(
        find.text('Track membership and coaching payments across facilities.'),
        findsOneWidget);
  });

  testWidgets(
      'desktop viewport renders enterprise data table with formatted amounts',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ReviewFake();
    await tester.pumpWidget(MaterialApp(
      home: PaymentsScreen(
        live: true,
        repository: repo,
        isCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();

    // Table view header should be rendered
    expect(find.text('Transaction / Title'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Payment Status'), findsOneWidget);
    expect(find.text('Date / Time'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    // Formatted currency and ID
    expect(find.text('RM 120.00'), findsWidgets);
    expect(find.text('booking-1'), findsOneWidget);
  });
}
