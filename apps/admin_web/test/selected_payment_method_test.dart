import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';
import 'payment_review_screen_test.dart' show ReviewFake;

void main() {
  testWidgets(
      'Admin shows canonical member method label and icon, not processed-rail evidence',
      (t) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final r = ReviewFake();
    r.record = PaymentReviewRecord({
      ...r.record.data,
      'selectedPaymentMethodCategory': 'ewallet',
      'selectedPaymentMethodCode': 'grabpay',
      'selectedPaymentMethodLabel': 'GrabPay',
      'selectedPaymentMethodIconKey': 'grabpay',
      'selectedAt': 1800000000000
    });
    await t.pumpWidget(MaterialApp(
        home: PaymentsScreen(
            live: true,
            repository: r,
            isCurrent: () => true,
            initialBookingId: 'booking-1')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('E-Wallet · GrabPay'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('E-Wallet · GrabPay'), findsOneWidget);
  });
  testWidgets('legacy invoice has graceful unrecorded method fallback',
      (t) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: PaymentsScreen(
            live: true,
            repository: ReviewFake(),
            isCurrent: () => true,
            initialBookingId: 'booking-1')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Not recorded'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Legacy booking'), findsOneWidget);
  });
}
