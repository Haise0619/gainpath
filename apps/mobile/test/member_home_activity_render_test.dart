import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/home/member_home_activity.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';

import '../../../test_support/fyp_render_support.dart';
import 'member_home_refinement_test.dart' as fixture;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final layout in [
    (390.0, 1.0, false),
    (320.0, 2.0, false),
    (390.0, 1.0, true)
  ]) {
    testWidgets(
        'Home activity at ${layout.$1}, text ${layout.$2}, mixed ${layout.$3}',
        (tester) async {
      final restore = await installFypOfflineFonts();
      addTearDown(restore);
      tester.view.physicalSize = Size(layout.$1, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final capture = GlobalKey();
      await tester.pumpWidget(fixture.homeTestApp(
          captureKey: capture,
          scale: layout.$2,
          routines: layout.$3
              ? RoutineProgress(
                  scope: fixture.homeScope,
                  asOf: DateTime.utc(2026, 11, 17, 8),
                  attempts: [
                      fixture.homeAttempt(
                          completed: true,
                          finished: true,
                          at: DateTime.utc(2026, 11, 16, 7)),
                      fixture.homeAttempt(
                          id: 'in-progress', at: DateTime.utc(2026, 11, 17, 7)),
                    ])
              : fixture.homeRoutines(
                  [fixture.homeAttempt(completed: true, finished: true)]),
          onStart: () {},
          onAttempt: (_) {}));
      await tester.pumpAndSettle();
      for (final name in ['Weekly progress', 'Recent activity']) {
        final heading = find.text(name);
        await tester.scrollUntilVisible(heading, 180,
            scrollable: find
                .descendant(
                    of: find.byKey(const ValueKey('home-scroll')),
                    matching: find.byType(Scrollable))
                .first);
        await Scrollable.ensureVisible(tester.element(heading), alignment: .1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          const stage = String.fromEnvironment('HOME_ACTIVITY_CAPTURE',
              defaultValue: 'after');
          final filename =
              '${name.split(' ').first.toLowerCase()}-${layout.$1.toInt()}-${layout.$2.toInt()}x${layout.$3 ? '-mixed' : ''}.png';
          final file =
              File('../../build/home-activity-redesign/$stage/$filename');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (layout.$2 == 1) {
        expect(tester.getSize(find.byType(HomeWeeklyActivity)).height,
            lessThan(270));
      }
      if (layout.$2 == 2) {
        final card = find.byType(HomeWeeklyActivity);
        await Scrollable.ensureVisible(tester.element(card), alignment: 0);
        await tester.pumpAndSettle();
        const contentTop = kToolbarHeight + 2;
        final scroll = tester.state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('home-scroll')),
                matching: find.byType(Scrollable))
            .first);
        scroll.position.jumpTo(
            scroll.position.pixels + tester.getTopLeft(card).dy - contentTop);
        await tester.pumpAndSettle();
        final cardBounds = tester.getRect(card);
        final chatBounds =
            tester.getRect(find.byKey(const ValueKey('home-ai-entry')));
        expect(cardBounds.top, closeTo(contentTop, 1));
        expect(cardBounds.bottom, lessThan(chatBounds.top),
            reason:
                "Card $cardBounds overlaps the floating AI button $chatBounds.");
        expect(tester.takeException(), isNull);
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          const stage = String.fromEnvironment('HOME_ACTIVITY_CAPTURE',
              defaultValue: 'after');
          final file = File(
              '../../build/home-activity-redesign/$stage/weekly-card-320-2x.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
