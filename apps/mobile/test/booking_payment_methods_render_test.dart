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
import 'booking_payment_methods_ui_test.dart' show MethodPayments;

void main() {
  testWidgets('render checkout stages at mobile widths and large text',
      (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    final dir = Directory('../../build/booking-payment-ux-20261113/renders')
      ..createSync(recursive: true);
    final now = DateTime.fromMillisecondsSinceEpoch(1800000000000);
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final stage in [
          'methods',
          'selected-bank',
          'redirecting',
          'confirming',
          'confirmed',
          'configured-billplz'
        ]) {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          final r = MethodPayments()
            ..enabledFpx = stage != 'configured-billplz';
          final pending = Completer<bool>();
          final key = GlobalKey();
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
                  home: stage == 'confirmed'
                      ? BookingConfirmedScreen(
                          payment: (r
                                ..status = 'confirmed'
                                ..paid = 'cleared')
                              .value,
                          onViewBookings: () {})
                      : BookingPaymentScreen(
                          repository: r,
                          bookingId: 'booking',
                          isCurrent: () => true,
                          create: true,
                          reviewedQuoteToken: 'a' * 64,
                          now: () => now,
                          openCheckout: (_) => stage == 'redirecting'
                              ? pending.future
                              : Future.value(true)))));
          await t.pump();
          await t.pump(const Duration(milliseconds: 220));
          if (['selected-bank', 'redirecting', 'confirming'].contains(stage)) {
            await t.scrollUntilVisible(find.text('CIMB Clicks'), 250,
                scrollable: find.byType(Scrollable).first);
            await t.pump();
            await Scrollable.ensureVisible(t.element(find.text('CIMB Clicks')),
                alignment: 0.5);
            await t.pump();
            await t.tap(find.text('CIMB Clicks'));
            await t.pump();
            expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
          }
          if (['redirecting', 'confirming'].contains(stage)) {
            await t.scrollUntilVisible(find.text('Continue to Payment'), 250,
                scrollable: find.byType(Scrollable).first);
            await t.pump();
            await Scrollable.ensureVisible(
                t.element(find.text('Continue to Payment')),
                alignment: 0.5);
            await t.pump();
            await t.tap(find.text('Continue to Payment'));
            await t.pump();
            await t.pump(const Duration(milliseconds: 220));
            expect(r.selected, 'BCBB0235');
            expect(
                find.text(stage == 'redirecting'
                    ? 'Opening secure payment'
                    : 'Confirming your payment'),
                findsOneWidget);
          }
          final scroll = find.byType(Scrollable).first;
          final state = t.state<ScrollableState>(scroll);
          state.position.jumpTo(0);
          await t.pump();
          var part = 0;
          while (true) {
            expect(t.takeException(), isNull,
                reason: '$stage $width $scale part$part');
            await t.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/$stage-${width.toInt()}-${(scale * 100).round()}-$part.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            if (state.position.pixels >= state.position.maxScrollExtent ||
                part > 8) {
              break;
            }
            state.position.jumpTo((state.position.pixels + 600)
                .clamp(0, state.position.maxScrollExtent));
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
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_PAYMENT_METHODS'));
}
