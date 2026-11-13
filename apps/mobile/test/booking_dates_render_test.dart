import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/book_session_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'booking_date_availability_test.dart' show CalendarOptions;
import 'booking_selection_consumer_test.dart' show SelectionPayments;
import 'live_booking_cubit_test.dart' show Writer;

void main() {
  testWidgets('render confirmed unavailable dates and retryable unknown dates',
      (tester) async {
    await tester.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final directory =
        Directory('../../build/booking-unavailable-dates-20261113/renders')
          ..createSync(recursive: true);
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final state in ['mixed', 'empty', 'error']) {
          final repo = CalendarOptions()..allEmpty = state == 'empty';
          if (state == 'error') repo.failed.add('2026-10-17');
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
                      options: repo,
                      writer: Writer(),
                      payments: SelectionPayments(),
                      coachId: 'coach',
                      isCurrent: () => true,
                      onOpenBookings: () {}))));
          await tester.pumpAndSettle();
          final scroll =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          var page = 0;
          while (true) {
            expect(tester.takeException(), isNull,
                reason: '$state $width $scale page$page');
            await tester.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${directory.path}/$state-${width.toInt()}-${(scale * 100).round()}-$page.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            if (scroll.position.pixels >= scroll.position.maxScrollExtent ||
                page > 8) {
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 650)
                .clamp(0, scroll.position.maxScrollExtent));
            await tester.pumpAndSettle();
            page++;
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_BOOKING_DATES'));
}
