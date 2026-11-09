import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_coach_public_data_test.dart' show statistics;
import 'member_coach_ux_test.dart' show coachProfile;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('public session and review data render $width $scale',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 820);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey(),
            p = coachProfile()
                .withStatistics(CoachPublicStatistics.fromJson(statistics()));
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: CoachProfileScreen(
                    coach: publishedCoachPresentation(p),
                    published: p,
                    photo: const Icon(Icons.person),
                    onOpenBooking: () {}))));
        await t.pumpAndSettle();
        Future<void> capture(String name) async {
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final f = File(
                '../../build/member-coach-data-20261109/renders/$name-${width.toInt()}-${scale.toInt()}x.png');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('profile');
        await t.scrollUntilVisible(find.text('Actual saved review.'), 180);
        await Scrollable.ensureVisible(
            t.element(find.text('Actual saved review.')),
            alignment: .75);
        await t.pumpAndSettle();
        await capture('review');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
