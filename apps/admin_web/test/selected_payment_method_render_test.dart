import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import '../../mobile/test/support/module13_demo_render.dart'
    show loadDemoRenderFonts;
import 'payment_review_screen_test.dart' show ReviewFake;

void main() {
  testWidgets('render Admin selected method and legacy detail', (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final dir =
        Directory('../../build/commercial-checkout-20261113/admin-renders')
          ..createSync(recursive: true);
    for (final width in [1024.0, 1440.0]) {
      for (final selected in [true, false]) {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        final r = ReviewFake();
        if (selected) {
          r.record = PaymentReviewRecord({
            ...r.record.data,
            'selectedPaymentMethodCategory': 'ewallet',
            'selectedPaymentMethodCode': 'grabpay',
            'selectedPaymentMethodLabel': 'GrabPay',
            'selectedPaymentMethodIconKey': 'grabpay',
            'selectedAt': 1800000000000
          });
        }
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                home: Scaffold(
                    body: PaymentsScreen(
                        live: true,
                        repository: r,
                        isCurrent: () => true,
                        initialBookingId: 'booking-1')))));
        await t.pumpAndSettle();
        final label = selected ? 'E-Wallet · GrabPay' : 'Not recorded';
        await t.scrollUntilVisible(find.text(label), 300,
            scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${dir.path}/${selected ? 'selected' : 'legacy'}-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await t.pumpWidget(const SizedBox());
    t.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_ADMIN_PAYMENT_METHOD'));
}
