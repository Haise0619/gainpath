import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';

class ReviewFake implements PaymentReviewRepository {
  final record = PaymentReviewRecord({
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
  testWidgets('unconnected console shows no fabricated records or metrics', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RefundsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('No booking payments on this page.'), findsOneWidget);
    expect(find.textContaining('DEMO-'), findsNothing);
  });}

