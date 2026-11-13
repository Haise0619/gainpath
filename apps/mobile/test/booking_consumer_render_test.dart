import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_booking_refresh_test.dart' show RangeBookings;
import 'member_coach_ux_test.dart' show coachProfile, MemberDirectoryFake;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'booking_history_coach_fix_test.dart' show bookingJson;

class ConsumerBookings extends RangeBookings {
  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) async {
    final page = await super.load(
        coachId: coachId,
        firstLocalDate: firstLocalDate,
        dayCount: dayCount,
        cursor: cursor);
    if (dayCount == 1) return page;
    return BookingPage.fromJson({
      ...page.toJson(),
      'records': firstLocalDate != null
          ? [
              {
                ...bookingJson('refund', DateTime.utc(2026, 10, 21, 2, 30),
                    status: 'cancelled'),
                'paymentStatus': 'cleared',
                'refundStatus': 'processing'
              }
            ]
          : [
              bookingJson('future', DateTime.utc(2026, 11, 12, 2, 30)),
              bookingJson('hold', DateTime.utc(2026, 11, 13, 3),
                  status: 'pending_hold')
            ]
    });
  }
}

void main() {
  setUpAll(() async {
    await loadDemoRenderFonts();
    for (final family in ['Barlow', 'BarlowCondensed']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/$family-$weight.ttf').readAsBytes())));
      }
      await loader.load();
    }
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('inline booking pull-refresh layout $width $scale',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildMemberTypographyTheme(),
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: memberTextScaler(TextScaler.linear(scale))),
                    child: child!),
                home: BrowseCoachesScreen(
                    live: true,
                    liveRepository: MemberDirectoryFake(),
                    isCurrent: () => true,
                    onMessages: () {},
                    bookingsBuilder: (_) => LiveBookingListView(
                        repository: ConsumerBookings(),
                        onPayment: (_) {},
                        isCurrent: () => true,
                        embedded: true,
                        loadCoachProfile: (id) async =>
                            coachProfile(id: id, name: 'Jackson'),
                        coachPhotoBuilder: (_) =>
                            const Icon(Icons.person_outline, size: 44))))));
        await t.pumpAndSettle();
        await t.tap(find.text('My Bookings'));
        await t.pumpAndSettle();
        Future<void> capture(String label) async {
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/booking-consumer-20261113/after/$label-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('next');
        await t.scrollUntilVisible(find.text('AWAITING PAYMENT'), 200,
            scrollable: find
                .byWidgetPredicate((w) =>
                    w is Scrollable && w.axisDirection == AxisDirection.down)
                .first);
        await t.ensureVisible(find.text('AWAITING PAYMENT'));
        await t.pumpAndSettle();
        await capture('awaiting-payment');
        await t.scrollUntilVisible(
            find.byKey(const ValueKey('tab_history')), -250,
            scrollable: find
                .byWidgetPredicate((w) =>
                    w is Scrollable && w.axisDirection == AxisDirection.down)
                .first);
        await t.ensureVisible(find.byKey(const ValueKey('tab_history')));
        await t.tap(find.byKey(const ValueKey('tab_history')));
        await t.pumpAndSettle();
        expect(find.text('Refund processing'), findsOneWidget);
        await capture('past');
        final vertical = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        await t.scrollUntilVisible(find.text('View details').first, 160,
            scrollable: vertical.first);
        await t.ensureVisible(find.text('View details').first);
        await t.pumpAndSettle();
        await t.tap(find.text('View details').first);
        await t.pumpAndSettle();
        await capture('refund-details');
        await t.scrollUntilVisible(find.text('View Refund Details'), 180,
            scrollable: vertical.first);
        await t.ensureVisible(find.text('View Refund Details'));
        await t.pumpAndSettle();
        await capture('refund-progress');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
