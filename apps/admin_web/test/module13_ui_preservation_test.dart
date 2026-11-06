import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/exercise_insights_panel.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_queue_panel.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'admin_exercise_insights_test.dart' show FixtureInsightsRepository;
import 'support/exercise_insights_fixture.dart';
import 'support/recommendation_queue_fixture.dart';
import 'support/recommendation_queue_transport.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester tester, Widget child, double width) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop hub preserves the original equal-width three tabs',
      (tester) async {
    await show(tester, const RiskLeaderboardScreen(), 1400);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
    expect(find.text('Exercise Insights'), findsOneWidget);
    expect(find.text('Trainer Matching'), findsOneWidget);
    expect(find.text('Content Recommendations'), findsOneWidget);
  });

  for (final width in [1400.0, 600.0]) {
    testWidgets('queue preserves compact original cards at $width',
        (tester) async {
      final fixture = QueueTransportHarness();
      await show(
          tester,
          RecommendationQueuePanel(
              trainer: true,
              repository: fixture.repository,
              clock: () => queueNow),
          width);
      final card = find.ancestor(
          of: find.text('Sample Member'), matching: find.byType(Panel));
      expect(tester.getSize(card.first).width, 380);
      final target = find.byKey(const ValueKey('queue-target-lead-1'));
      expect(target, findsOneWidget);
      expect(
          tester.widget<Container>(target).decoration,
          isA<BoxDecoration>()
              .having((d) => d.color, 'tint', AppColors.primaryTint));
      expect(tester.getRect(find.text('Send')).top,
          tester.getRect(find.text('Dismiss')).top);
      expect(find.text('View details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('insights preserves score chart without clinical classification',
      (tester) async {
    await show(
        tester,
        ExerciseInsightsPanel(
            repository: FixtureInsightsRepository(), clock: () => insightsNow),
        1400);
    final chart =
        tester.widget<SfCartesianChart>(find.byType(SfCartesianChart));
    expect((chart.primaryYAxis as NumericAxis).minimum, 0);
    expect((chart.primaryYAxis as NumericAxis).maximum, 100);
    final series =
        chart.series.single as ColumnSeries<ExerciseInsightGroup, String>;
    expect(series.yValueMapper!(series.dataSource!.first, 0), 65);
    expect(tester.getTopLeft(find.text('Content Gap Report')).dx,
        greaterThan(tester.getTopLeft(find.byType(SfCartesianChart)).dx + 500));
    expect(find.textContaining('High risk'), findsNothing);
    expect(find.textContaining('Not a clinical injury-risk measurement.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
