import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/roster_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'booking_history_coach_fix_test.dart' show bookingJson;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Coach pinned history and summary render $width $scale',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final records = List.generate(25, (i) {
          final start =
                  DateTime.utc(2026, 10, 21, 2, 30).add(Duration(hours: i)),
              local =
                  DateTime.utc(2026, 10, 21, 10, 30).add(Duration(hours: i));
          String clock(DateTime d) =>
              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} GMT+8';
          return PersistedBookingRecord.fromJson({
            ...bookingJson('summary-$i', start, status: 'completed'),
            'memberDisplayName': i == 0 ? 'Alicia Tan' : 'Member $i',
            'branchId': 'main',
            'startLabel': clock(local),
            'endLabel': clock(local.add(const Duration(minutes: 30)))
          });
        });
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
                home: CoachRosterScreen(
                    historyRange: true,
                    todayLocalDate: '2026-11-08',
                    serverNowMillis:
                        DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
                    persistedBookings:
                        records.map(persistedBookingPresentation).toList(),
                    recordFor: (id) =>
                        records.firstWhere((r) => r.bookingId == id),
                    onNotes: (_) {},
                    onMessage: (_) {}))));
        await t.pumpAndSettle();
        Future<void> capture(String label) async {
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/coach-roster-summary-20261108/renders/$label-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('history');
        await t.drag(find.byType(ListView).first, const Offset(0, -1600));
        await t.pumpAndSettle();
        expect(find.widgetWithText(FilterChip, 'All').hitTestable(),
            findsOneWidget);
        await capture('scrolled');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
