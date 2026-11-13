import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_payment_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_confirmed_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'commercial_booking_checkout_test.dart' show CommercialPayments;

void main() {
  testWidgets('commercial checkout responsive stages', (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    final dir = Directory('../../build/commercial-checkout-20261113/renders')
      ..createSync(recursive: true);
    final now = DateTime.fromMillisecondsSinceEpoch(1800000000000);
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final stage in [
          'methods',
          'bank-selected',
          'wallet-selected',
          'card-selected',
          'redirecting',
          'confirming',
          'confirmed'
        ]) {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          final r = CommercialPayments();
          final pending = Completer<bool>();
          final key = GlobalKey();
          final screen = stage == 'confirmed'
              ? BookingConfirmedScreen(
                  payment: (r
                        ..status = 'confirmed'
                        ..paid = 'cleared'
                        ..choiceCode = 'tng')
                      .value,
                  onViewBookings: () {})
              : BookingPaymentScreen(
                  repository: r,
                  bookingId: 'booking',
                  isCurrent: () => true,
                  create: true,
                  now: () => now,
                  reviewedQuoteToken: 'a' * 64,
                  openCheckout: (_) => stage == 'redirecting'
                      ? pending.future
                      : Future.value(true));
          await t.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildMemberTypographyTheme(),
                  builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(c).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: screen)));
          await t.pump();
          await t.pump(const Duration(milliseconds: 220));
          if (!['methods', 'confirmed'].contains(stage)) {
            final label = stage == 'bank-selected'
                ? 'Maybank2u'
                : stage == 'card-selected'
                    ? 'Visa / Mastercard'
                    : 'GrabPay';
            await t.scrollUntilVisible(find.text(label), 250,
                scrollable: find.byType(Scrollable).first);
            await t.pump();
            await Scrollable.ensureVisible(t.element(find.text(label)),
                alignment: 0.5);
            await t.pump();
            await t.tap(find.text(label));
            await t.pump();
            expect(find.text('Continue').hitTestable(), findsOneWidget);
            if (['redirecting', 'confirming'].contains(stage)) {
              await t.tap(find.text('Continue'));
              await t.pump();
              await t.pump(const Duration(milliseconds: 220));
              expect(
                  find.text(stage == 'redirecting'
                      ? 'Redirecting to secure payment'
                      : 'Confirming payment'),
                  findsOneWidget);
              expect(r.creates, 1);
            }
          }
          expect(
              find.textContaining(
                  RegExp('sandbox|simulator|demo|test', caseSensitive: false)),
              findsNothing);
          final scroll =
              t.state<ScrollableState>(find.byType(Scrollable).first);
          scroll.position.jumpTo(0);
          await t.pump();
          var part = 0;
          while (true) {
            expect(t.takeException(), isNull,
                reason: '$stage $width $scale part$part');
            await t.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final data =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/$stage-${width.toInt()}-${(scale * 100).round()}-$part.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
            if (scroll.position.pixels >= scroll.position.maxScrollExtent ||
                part > 14) {
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 600)
                .clamp(0, scroll.position.maxScrollExtent));
            await t.pump();
            part++;
          }
          await t.pumpWidget(const SizedBox());
          if (!pending.isCompleted) pending.complete(false);
          await t.pump();
        }
      }
    }
    t.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_COMMERCIAL_CHECKOUT'));
}
