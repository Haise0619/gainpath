import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'support/workout_analytics_fixture.dart';
import 'workout_report_ui_test.dart' show ReportExporterFake;

/// Actual Flutter raster evidence; synthetic saved history, no Firebase/device.
void main() {
  const render = bool.fromEnvironment('GAINPATH_RENDER_REPORT');
  const stage = String.fromEnvironment('REPORT_STAGE', defaultValue: 'after');
  const directory = String.fromEnvironment('REPORT_RENDER_DIR',
      defaultValue:
          'C:/Users/Ngzhe/StudioProjects/gainpath/build/report-rewards-consumer-20261112/renders');
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Training Report ${width.toInt()}dp ${scale}x text',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final fixture = WorkoutAnalyticsFixture();
        final key = GlobalKey();
        await t.pumpWidget(MaterialApp(
            theme: buildMemberTypographyTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true),
                child: child!),
            home: RepaintBoundary(
                key: key,
                child: WorkoutReportScreen(
                    scope: fixture.scope,
                    source: fixture.snapshot,
                    asOf: fixture.now,
                    exporter: ReportExporterFake(),
                    isCurrent: () => true,
                    onRefresh: () async {},
                    onOpenWorkout: (_) {},
                    onOpenRoutine: (_) {}))));
        await t.pumpAndSettle();
        Future<void> capture(String name) async {
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (!render) return;
          await t.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '$directory/$stage-report-$name-${width.toInt()}-${(scale * 100).toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('top');
        await t.scrollUntilVisible(find.text('Workout activity (1)'), 200,
            scrollable: find.byType(Scrollable).first);
        await capture('activity');
        if (stage != 'before') {
          final parent = find.byWidgetPredicate((w) =>
              w is ExpansionTile &&
              w.key.toString().contains('report-workout-'));
          await t.ensureVisible(parent);
          await t.tap(find
              .descendant(
                  of: parent,
                  matching: find.textContaining('Everyday Strength'))
              .first);
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('View Squat result'));
          await capture('expanded');
          await t.scrollUntilVisible(find.text('Squat · Side view'), 200,
              scrollable: find.byType(Scrollable).first);
          await t.tap(find.text('Squat · Side view'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text(
              'An estimate of recorded movements, not an overall workout score. Missing assessments are unavailable, never 0%.'));
          await capture('assessment');
        }
        await t.scrollUntilVisible(find.text('Technical details'), 200,
            scrollable: find.byType(Scrollable).first);
        await capture('lower');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  for (final state in ['filtered', 'empty', 'loading', 'error', 'landscape']) {
    testWidgets('Training Report $state state', (t) async {
      final restore = await installFypOfflineFonts();
      addTearDown(restore);
      t.view.physicalSize =
          state == 'landscape' ? const Size(844, 390) : const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final fixture = WorkoutAnalyticsFixture(), key = GlobalKey();
      await t.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          home: RepaintBoundary(
              key: key,
              child: WorkoutReportScreen(
                  scope: fixture.scope,
                  source: state == 'loading' || state == 'error'
                      ? null
                      : state == 'empty'
                          ? LocalMemberProgressSnapshot(
                              records: [], routineHistoryAvailable: false)
                          : fixture.snapshot,
                  asOf: fixture.now,
                  initialFilter: state == 'filtered'
                      ? WorkoutReportFilter(exerciseId: 'manual-core')
                      : null,
                  loading: state == 'loading',
                  error: state == 'error'
                      ? 'Could not refresh your report.'
                      : null,
                  exporter: ReportExporterFake(),
                  isCurrent: () => true,
                  onRefresh: () async {}))));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      if (render) {
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$directory/$stage-report-$state.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
    });
  }
}
