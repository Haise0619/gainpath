import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/availability_screens.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'support/availability_dashboard_fixture.dart';

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Availability dashboard render $width $scale', (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 820);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: AvailabilityScreen(
                    liveRepository: DashboardRosterFake(),
                    coachId: 'coach',
                    isCurrent: () => true,
                    loadBranchNames: () async => {'main': 'GainPath Main'}))));
        await t.pumpAndSettle();
        Future<void> capture(String label) async {
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final f = File(
                '../../build/availability-dashboard-20261108/renders/$label-${width.toInt()}-${scale.toInt()}x.png');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        Future<void> show(Finder f, {double delta = 150}) async {
          await t.scrollUntilVisible(f, delta,
              scrollable: find.byType(Scrollable).first);
          await Scrollable.ensureVisible(t.element(f), alignment: .4);
          await t.pumpAndSettle();
        }

        await capture('overview');
        await show(find.byKey(const ValueKey('weekly-day-1')));
        await t.tap(find.byKey(const ValueKey('weekly-day-1')));
        await t.pumpAndSettle();
        await capture('weekly-editor');
        await t.tap(find.byType(Switch).last);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('Done'), 140,
            scrollable: find.byType(Scrollable).last);
        await Scrollable.ensureVisible(t.element(find.text('Done')),
            alignment: .5);
        await t.pumpAndSettle();
        await t.tap(find.text('Done'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('availability-save-bar')).hitTestable(),
            findsOneWidget);
        await capture('sticky-save');
        await t.tap(find.byKey(const ValueKey('save-roster')));
        await t.pumpAndSettle();
        await show(find.byKey(const ValueKey('manage-this-day-btn')),
            delta: -150);
        await t.tap(find.byKey(const ValueKey('manage-this-day-btn')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('open-specific-date-btn')));
        await t.pumpAndSettle();
        await capture('date-editor');
        await t.tap(find.byIcon(Icons.close).last);
        await t.pumpAndSettle();
        await show(find.byKey(const Key('availability-booking-limits')));
        await t.tap(find.text('Booking limits'));
        await t.pumpAndSettle();
        await capture('quick-settings');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
