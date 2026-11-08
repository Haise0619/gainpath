import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'booking_history_coach_fix_test.dart' show HistoryBookings;
import 'member_coach_ux_test.dart' show coachProfile;

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
      testWidgets('booking history/detail render $width at $scale',
          (tester) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = HistoryBookings()
          ..rows.removeLast(); // Same past-only case as the owner's screenshot.
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildMemberTypographyTheme(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: memberTextScaler(TextScaler.linear(scale))),
                    child: child!),
                home: LiveBookingListView(
                    repository: repo,
                    isCurrent: () => true,
                    loadCoachProfile: (id) async =>
                        coachProfile(id: id, name: 'Jackson'),
                    coachPhotoBuilder: (_) =>
                        const Icon(Icons.person_outline, size: 44)))));
        Future<void> capture(String name) async {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await tester.runAsync(() async {
            final img = await b.toImage(),
                bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final f = File(
                '../../build/booking-history-coach-fix-20261108/renders/$name-${width.toInt()}-${scale.toInt()}x.png');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('history');
        final vertical = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        await tester.scrollUntilVisible(find.text('View details'), 180,
            scrollable: vertical.first);
        await tester.ensureVisible(find.text('View details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View details'));
        await capture('details');
        await tester.scrollUntilVisible(find.text('COACH & LOCATION'), 200,
            scrollable: vertical.first);
        await tester.ensureVisible(find.text('COACH & LOCATION'));
        await capture('coach');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
