import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'support/workout_analytics_fixture.dart';

// Test-only visual references with synthetic records, no Firebase or devices.
void main() {
  setUpAll(loadDemoRenderFonts);
  for (final name in ['history', 'progress']) {
    testWidgets('reference $name with offline Barlow fonts', (t) async {
      final restore = await installFypOfflineFonts();
      addTearDown(restore);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = WorkoutAnalyticsFixture();
      final screen = name == 'history'
          ? RoutineHistoryScreen(attempts: [f.attempt], onOpenAttempt: (_) {})
          : ProgressDashboardScreen(
              localProgress: calculateLocalMemberProgress(scope: f.scope, records: f.snapshot.records, asOf: f.now),
              routineProgress: RoutineProgress(scope: f.scope, attempts: [f.attempt], asOf: f.now),
              onOpenReport: () {}, onOpenPoints: () {}, onOpenHistory: () {}, onStartWorkout: () {});
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(theme: buildMemberTypographyTheme(),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: RepaintBoundary(key: key, child: screen)));
      await t.pumpAndSettle();
      Future<void> capture(String section) async {
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('C:/Users/Ngzhe/StudioProjects/gainpath/build/report-rewards-consumer-20261112/references/$name-$section-390-100.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await capture('top');
      if (name == 'progress') {
        await t.scrollUntilVisible(find.text('Explore more'), 300, scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        await capture('lower');
      }
      await t.pumpWidget(const SizedBox());
    }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_REFERENCE'));
  }
}
