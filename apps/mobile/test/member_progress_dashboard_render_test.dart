import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_comparison_report.dart';
import 'support/workout_analytics_fixture.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_data.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_details.dart';

class Targets implements NumericFitnessGoalRepository {
  Targets(this.scope, {this.populated = false});
  final bool populated;
  @override
  final SessionScope scope;
  @override
  Future<List<NumericFitnessGoal>> loadActive() async => [
        if (populated)
          NumericFitnessGoal(
              id: 'weekly-fixture',
              category: NumericGoalCategory.trainingFrequency,
              targetValue: 3,
              status: NumericGoalStatus.active,
              revision: 1,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026)),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('actual Progress dashboard Flutter renders', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    await tester.runAsync(() async {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(File(
              'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
      final font = FontLoader('Barlow');
      font.addFont(File('assets/fonts/Barlow-Regular.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await font.load();
    });
    const stage =
        String.fromEnvironment('PROGRESS_RENDER_STAGE', defaultValue: 'after');
    final directory = Directory('build/member-progress-dashboard/$stage')
      ..createSync(recursive: true);
    final fixture = WorkoutAnalyticsFixture();
    for (final width in [320, 360, 390]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final populated in [true, false]) {
          tester.view.physicalSize = Size(width.toDouble(), 844);
          tester.view.devicePixelRatio = 1;
          final key = GlobalKey();
          final progress = calculateLocalMemberProgress(
              scope: fixture.scope,
              records: populated ? fixture.snapshot.records : [],
              asOf: fixture.now);
          final routines = RoutineProgress(
              scope: fixture.scope,
              attempts: populated ? [fixture.attempt] : [],
              asOf: fixture.now);
          await tester.pumpWidget(MaterialApp(
              theme: buildMemberTypographyTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: ProgressDashboardScreen(
                      localProgress: progress,
                      routineProgress: routines,
                      programStatsBuilder: (summary) => Builder(
                          builder: (context) => summary(
                              context, populated ? 2 : 0, populated ? 3 : 0)),
                      goalSummary: GoalComparisonReport(
                          repository: Targets(fixture.scope),
                          isCurrent: () => true,
                          progress: progress,
                          routineProgress: routines,
                          compact: true,
                          onView: () {}),
                      onOpenPerformance: () {},
                      onOpenForm: () {},
                      onOpenHistory: () {},
                      onOpenReport: () {},
                      onOpenBackup: () {},
                      onOpenWorkout: (_) {},
                      onOpenRoutine: (_) {},
                      onStartWorkout: () {}))));
          await tester.pumpAndSettle();
          final prefix =
              '$width-${(scale * 100).round()}-${populated ? 'mixed' : 'empty'}';
          var page = 0;
          Future<void> capture() async {
            expect(tester.takeException(), isNull,
                reason: '$prefix page $page');
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File('${directory.path}/$prefix-$page.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture();
          final scrollable =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          while (scrollable.position.pixels <
                  scrollable.position.maxScrollExtent &&
              page < 16) {
            scrollable.position.jumpTo((scrollable.position.pixels + 650)
                .clamp(0, scrollable.position.maxScrollExtent));
            await tester.pumpAndSettle();
            page++;
            await capture();
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_PROGRESS'));

  testWidgets(
      'render secondary assessments measurement details and active goals',
      (tester) async {
    await tester.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final fixture = WorkoutAnalyticsFixture();
    final progress = calculateLocalMemberProgress(
        scope: fixture.scope,
        records: fixture.snapshot.records,
        asOf: fixture.now);
    final routines = RoutineProgress(
        scope: fixture.scope, attempts: [fixture.attempt], asOf: fixture.now);
    final data = ProgressDashboardData(progress, routines);
    final directory = Directory('build/member-progress-dashboard/secondary')
      ..createSync(recursive: true);
    for (final config in [(390.0, 1.0), (320.0, 2.0)]) {
      for (final screen in <String, Widget>{
        'assessments': ProgressAssessmentsScreen(
            data: data, onOpen: (_) {}, onTrends: () {}),
        'measurements': ProgressMeasurementScreen(progress: progress),
        'goals': ProgressDashboardScreen(
            localProgress: progress,
            routineProgress: routines,
            goalSummary: GoalComparisonReport(
                repository: Targets(fixture.scope, populated: true),
                isCurrent: () => true,
                compact: true,
                progress: progress,
                routineProgress: routines,
                onView: () {})),
      }.entries) {
        tester.view.physicalSize = Size(config.$1, 844);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: buildMemberTypographyTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(config.$2),
                    disableAnimations: true),
                child: child!),
            home: RepaintBoundary(key: key, child: screen.value)));
        await tester.pumpAndSettle();
        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        var page = 0;
        while (true) {
          expect(tester.takeException(), isNull,
              reason: '${screen.key} $config page $page');
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    '${directory.path}/${screen.key}-${config.$1.toInt()}-${(config.$2 * 100).round()}-$page.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (scrollable.position.pixels >=
                  scrollable.position.maxScrollExtent ||
              page >= 16) {
            break;
          }
          scrollable.position.jumpTo((scrollable.position.pixels + 650)
              .clamp(0, scrollable.position.maxScrollExtent));
          await tester.pumpAndSettle();
          page++;
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_PROGRESS'));
}
