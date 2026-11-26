import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';

class RedesignMockRepo implements PaymentReviewRepository {
  PaymentReviewRecord reviewableRecord = PaymentReviewRecord({
    'bookingId': 'reviewable-1',
    'memberId': 'user-101',
    'memberEmail': 'alex@gainpath.com',
    'coachName': 'Marcus Vance',
    'branchName': 'Downtown Flagship',
    'amountMinor': 15000,
    'currency': 'MYR',
    'paymentStatus': 'cleared',
    'fulfilmentStatus': 'reconciliation_required',
    'bookingStatus': 'cancelled',
    'refundStatus': 'pending_review',
    'refundReason': 'Coach unavailable due to emergency scheduling conflict',
    'refundNotes': 'Member requested immediate refund rather than reschedule',
    'provider': 'xendit',
    'billId': 'xnd_inv_987654',
    'createdAtMillis': 1732000000000,
    'paymentConfirmedAtMillis': 1732000500000,
    'cancelledAtMillis': 1732005000000,
  });

  PaymentReviewRecord completedRecord = PaymentReviewRecord({
    'bookingId': 'completed-2',
    'memberId': 'user-102',
    'memberEmail': 'clara@gainpath.com',
    'coachName': 'Elena Rostova',
    'branchName': 'West Bay',
    'amountMinor': 8500,
    'currency': 'MYR',
    'paymentStatus': 'cleared',
    'fulfilmentStatus': 'reconciliation_required',
    'bookingStatus': 'cancelled',
    'refundStatus': 'completed',
    'refundReason': 'Session cancelled within refund window',
    'refundReference': 'ref-exec-202611-001',
    'reviewReason': 'Approved per standard cancellation policy',
    'provider': 'billplz',
    'billId': 'bp_bill_112233',
    'createdAtMillis': 1731900000000,
    'paymentConfirmedAtMillis': 1731900500000,
  });

  int manageCalls = 0;
  String? lastAction;
  String? lastReason;

  @override
  Future<PaymentReviewPage> load({String? afterId}) async {
    return PaymentReviewPage([reviewableRecord, completedRecord]);
  }

  @override
  Future<PaymentReviewDetail> detail(String bookingId) async {
    if (bookingId == 'completed-2') {
      return PaymentReviewDetail(
        completedRecord,
        events: [
          {
            'source': 'billplz',
            'type': 'payout.completed',
            'createdAtMillis': 1731910000000,
          },
        ],
      );
    }
    return PaymentReviewDetail(
      reviewableRecord,
      events: [
        {
          'source': 'xendit',
          'type': 'payment.cleared',
          'createdAtMillis': 1732000500000,
        },
        {
          'source': 'gainpath',
          'type': 'refund.requested',
          'createdAtMillis': 1732005000000,
        },
      ],
    );
  }

  @override
  Future<PaymentReviewDetail> manage(
    String bookingId,
    String action, {
    required String requestId,
    String? reason,
    String? billId,
    String? refundOrderId,
  }) async {
    manageCalls++;
    lastAction = action;
    lastReason = reason;

    final updated = PaymentReviewRecord({
      ...reviewableRecord.data,
      'refundStatus': action == 'approve_refund' ? 'approved' : 'rejected',
      'reviewReason': reason ?? '',
    });
    reviewableRecord = updated;
    return PaymentReviewDetail(updated);
  }
}

void main() {
  testWidgets('reviewable row displays "Review" and quick view icon; completed row displays "View Details"',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RedesignMockRepo();
    await tester.pumpWidget(MaterialApp(
      home: RefundsScreen(
        mode: PaymentsMode.refunds,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Refund requested · Pending review'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.byTooltip('Quick preview'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
  });

  testWidgets('clicking "Review" directly opens dedicated review page with breadcrumb and 4-part status breakdown',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RedesignMockRepo();
    await tester.pumpWidget(MaterialApp(
      home: RefundsScreen(
        mode: PaymentsMode.refunds,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    // Verify breadcrumb
    expect(find.text('Back to Refund Requests'), findsOneWidget);
    expect(find.text('Refresh payment'), findsOneWidget);

    // Verify 4-part status hierarchy breakdown
    expect(find.text('Status Hierarchy Breakdown'), findsOneWidget);
    expect(find.text('1. Original Payment'), findsOneWidget);
    expect(find.text('2. Booking Fulfillment'), findsOneWidget);
    expect(find.text('3. Refund Review'), findsOneWidget);
    expect(find.text('4. Refund Execution'), findsOneWidget);

    // Verify policy notice
    expect(find.textContaining('Policy Notice: Approving a refund records an administrative authorization'), findsOneWidget);

    // Verify detail cards
    expect(find.text('REFUND REQUEST DETAILS'), findsOneWidget);
    expect(find.text('ORIGINAL PAYMENT DETAILS'), findsOneWidget);
    expect(find.text('Review Actions'), findsOneWidget);
    expect(find.text('Approve refund'), findsOneWidget);
    expect(find.text('Reject refund'), findsOneWidget);
  });

  testWidgets('breadcrumb "Back to Refund Requests" preserves search and filter state',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RedesignMockRepo();
    await tester.pumpWidget(MaterialApp(
      home: RefundsScreen(
        mode: PaymentsMode.refunds,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    // Enter a search term
    await tester.enterText(find.byType(TextField).first, 'Marcus');
    await tester.pumpAndSettle();

    // Click Review
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    // Verify on review page
    expect(find.text('Back to Refund Requests'), findsOneWidget);

    // Click Back
    await tester.tap(find.text('Back to Refund Requests'));
    await tester.pumpAndSettle();

    // Verify search term is preserved and table is displayed
    final searchField = tester.widget<TextField>(find.byType(TextField).first);
    expect(searchField.controller?.text, 'Marcus');
    expect(find.text('Refund requested · Pending review'), findsOneWidget);
  });

  testWidgets('quick view eye icon opens right-side overlay drawer without shrinking list',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RedesignMockRepo();
    await tester.pumpWidget(MaterialApp(
      home: RefundsScreen(
        mode: PaymentsMode.refunds,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the quick view icon for the first record
    await tester.tap(find.byTooltip('Quick preview').first);
    await tester.pumpAndSettle();

    // Verify Drawer is visible with Open Full Review and Close buttons
    expect(find.text('Refund Request Preview'), findsOneWidget);
    expect(find.text('Open Full Review'), findsOneWidget);
    expect(find.byTooltip('Close details'), findsOneWidget);

    // Verify the list table is still underneath in the tree
    expect(find.text('Coach Booking — Marcus Vance'), findsWidgets);

    // Tap "Open Full Review" transitions from Drawer to Dedicated Review Page
    await tester.tap(find.text('Open Full Review'));
    await tester.pumpAndSettle();

    expect(find.text('Back to Refund Requests'), findsOneWidget);
    expect(find.text('Status Hierarchy Breakdown'), findsOneWidget);
  });

  testWidgets('approve refund requires reason validation dialog before submitting',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RedesignMockRepo();
    await tester.pumpWidget(MaterialApp(
      home: RefundsScreen(
        mode: PaymentsMode.refunds,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Approve refund'));
    await tester.tap(find.text('Approve refund'));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify validation dialog appears
    expect(find.text('Approve refund'), findsWidgets);
    expect(find.text('Confirm'), findsOneWidget);

    // Try submitting without reason
    final confirmBtn = find.text('Confirm');
    await tester.tap(confirmBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('A reason is required.'), findsOneWidget);
    expect(repo.manageCalls, 0);

    // Enter reason and submit
    await tester.enterText(find.byType(TextFormField), 'Approved due to coach emergency');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(repo.manageCalls, 1);
    expect(repo.lastAction, 'approve_refund');
    expect(repo.lastReason, 'Approved due to coach emergency');
  });

  testWidgets('dedicated review page adapts layout across 1536px, 1280px, 1024px and 390px with zero overflows',
      (tester) async {
    final viewports = [
      const Size(1536, 960),
      const Size(1366, 768),
      const Size(1280, 800),
      const Size(1024, 768),
      const Size(390, 844),
    ];

    for (final size in viewports) {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(MaterialApp(
        home: RefundsScreen(
          key: UniqueKey(),
          mode: PaymentsMode.refunds,
          repository: RedesignMockRepo(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Overflow on list page at $size');

      // Open review page
      await tester.ensureVisible(find.text('Review').first);
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Overflow on review page at $size');

      // Verify key elements present
      expect(find.text('Back to Refund Requests'), findsOneWidget);
      expect(find.text('Status Hierarchy Breakdown'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
