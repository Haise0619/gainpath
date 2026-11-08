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
  for (final width in [320.0, 360.0]) {
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
                        repository: RangeBookings(),
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
                '../../build/booking-pull-refresh-20261108/renders/$label-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('next');
        await t.tap(find.text('Next 30 days'));
        await t.pumpAndSettle();
        expect(find.text('Session ended'), findsOneWidget);
        await capture('past');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
