import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'booking_payment_screen_test.dart' show Payments;
import 'live_booking_cubit_test.dart' show Options, Writer;
import 'booking_empty_state_test.dart' show DailyOptions;
import 'booking_selection_consumer_test.dart'
    show SelectionPayments, SelectionOptions;

void main() {
  testWidgets('render real booking selection and review widgets',
      (tester) async {
    await tester.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    const stage =
        String.fromEnvironment('BOOKING_RENDER_STAGE', defaultValue: 'after');
    final dir =
        Directory('../../build/booking-consumer-20261113/selection-$stage')
          ..createSync(recursive: true);
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        if (stage == 'before' && scale > 1) continue;
        for (final state in [
          'available',
          'selected',
          'empty',
          if (stage != 'before') 'review'
        ]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
              theme: buildMemberTypographyTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: BookSessionScreen(
                      options: state == 'empty'
                          ? DailyOptions()
                          : stage == 'before'
                              ? Options()
                              : SelectionOptions(),
                      writer: Writer(),
                      payments:
                          stage == 'before' ? Payments() : SelectionPayments(),
                      coachId: 'coach',
                      isCurrent: () => true,
                      onOpenBookings: () {}))));
          await tester.pumpAndSettle();
          if (state == 'selected' || state == 'review') {
            final slot = stage == 'before'
                ? find.textContaining('08:00 GMT+8 –')
                : find.text('8:00 AM');
            await tester.ensureVisible(slot);
            await tester.pumpAndSettle();
            await tester.tap(slot);
            await tester.pumpAndSettle();
            if (state == 'review') {
              await tester.tap(find.text('Review Booking'));
              await tester.pumpAndSettle();
            }
          }
          var page = 0;
          final scrollable =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          while (true) {
            expect(tester.takeException(), isNull,
                reason: '$state $width $scale $page');
            await tester.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/$state-${width.toInt()}-${(scale * 100).round()}-$page.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            if (scrollable.position.pixels >=
                    scrollable.position.maxScrollExtent ||
                page > 12) {
              break;
            }
            scrollable.position.jumpTo((scrollable.position.pixels + 650)
                .clamp(0, scrollable.position.maxScrollExtent));
            await tester.pumpAndSettle();
            page++;
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_BOOKING'));
}
