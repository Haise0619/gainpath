import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/exercise_insights_panel.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_queue_panel.dart';
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

  testWidgets('desktop hub offers monitoring tabs and preserves Insights',
      (tester) async {
    await show(tester, const RiskLeaderboardScreen(), 1400);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Needs Attention'), findsOneWidget);
    expect(find.text('Exercise Guidance Insights'), findsOneWidget);
  });

  for (final width in [1400.0, 600.0]) {
    testWidgets('queue uses table or stacked cards at $width', (tester) async {
      final fixture = QueueTransportHarness();
      await show(
          tester,
          RecommendationQueuePanel(
              repository: fixture.repository, clock: () => queueNow),
          width);
      expect(find.text('Sample Member'), findsNWidgets(2));
      expect(find.text('Sample Coach'), findsOneWidget);
      expect(find.text('Squat foundations'), findsOneWidget);
      expect(find.byType(Card), width < 1080 ? findsNWidgets(2) : findsNothing);
      expect(find.text('Approve & Send'), findsNothing);
      expect(find.text('View'), findsNWidgets(2));
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
