import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/exercise_insights_panel.dart';
import 'support/exercise_insights_fixture.dart';

class FixtureInsightsRepository implements ExerciseInsightsRepository {
  bool current = true;
  int revision = 0, loads = 0, saves = 0;
  ExerciseInsightsQuery? lastQuery;
  Completer<Object?>? pending;
  @override
  String get organizationId => 'gainpath';
  @override
  bool get isCurrent => current;
  @override
  bool get enabled => true;
  @override
  bool get fixtureOnly => true;
  @override
  Future<Object?> load(ExerciseInsightsQuery query) async {
    loads++;
    lastQuery = query;
    return pending?.future ?? response(query);
  }

  Map<String, Object?> response(ExerciseInsightsQuery query) =>
      insightsFixture()
        ..['startAtMillis'] = query.start.millisecondsSinceEpoch
        ..['endAtMillis'] = query.end.millisecondsSinceEpoch
        ..['configurationRevision'] = revision;
  @override
  Future<InsightsConfigurationOptions> configuration() async =>
      InsightsConfigurationOptions(
          revision: revision,
          selectedPolicyIds: const [],
          availablePolicies: const [
            ReviewedPolicyChoice(
                policyId: 'fixture-policy',
                title: 'Synthetic squat policy',
                definition:
                    'Exact squat group · fixture-only reviewed policy; not eligibility')
          ]);
  @override
  Future<int> saveConfiguration(
      int expectedRevision, List<String> policyIds) async {
    if (!current ||
        expectedRevision != revision ||
        policyIds.single != 'fixture-policy') {
      throw const ExerciseInsightsUnavailable();
    }
    saves++;
    return ++revision;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester tester,
      {ExerciseInsightsRepository? repo,
      void Function(String, List<List<Object?>>)? export}) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExerciseInsightsPanel(
                repository: repo,
                clock: () => insightsNow,
                onExport: export))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'normal composition is unavailable and never fabricates analytics or a threshold slider',
      (tester) async {
    await show(tester);
    expect(find.text('Exercise insights are unavailable in this release.'),
        findsOneWidget);
    expect(find.text('65.0%'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Descriptive-only mode'), findsOneWidget);
  });
  testWidgets(
      'renders injected typed metrics with explicit synthetic provenance and definitions',
      (tester) async {
    await show(tester, repo: FixtureInsightsRepository());
    expect(find.text('Exercise evidence · educational review'), findsOneWidget);
    expect(find.text('65.0%'), findsOneWidget);
    expect(find.textContaining('3 distinct Members'), findsOneWidget);
    expect(find.textContaining('80.0% tracking coverage'), findsOneWidget);
    expect(find.text('Content Gap Report'), findsOneWidget);
    expect(find.textContaining('Sample policy not configured'), findsOneWidget);
    expect(find.textContaining('Not a clinical injury-risk measurement'),
        findsOneWidget);
  });
  testWidgets('category filters affect the screen and exported rows together',
      (tester) async {
    List<List<Object?>>? exported;
    await show(tester,
        repo: FixtureInsightsRepository(),
        export: (_, rows) => exported = rows);
    await tester.tap(find.byKey(const ValueKey('insights-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper Body').last);
    await tester.pumpAndSettle();
    expect(find.text('65.0%'), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('export-content-coverage')));
    await tester.tap(find.byKey(const ValueKey('export-content-coverage')));
    await tester.pump();
    expect(exported!.expand((r) => r), contains('Wall push-up'));
    expect(exported!.expand((r) => r), isNot(contains('Squat')));
  });
  testWidgets('date choices issue bounded Malaysia queries', (tester) async {
    final repo = FixtureInsightsRepository();
    await show(tester, repo: repo);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(repo.lastQuery!.start, DateTime.utc(2026, 10, 25, 16));
    expect(repo.lastQuery!.end, insightsNow);
    expect(repo.loads, 2);
  });
  testWidgets('drops a pending response after scope revocation',
      (tester) async {
    final repo = FixtureInsightsRepository()..pending = Completer<Object?>();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExerciseInsightsPanel(
                repository: repo, clock: () => insightsNow))));
    await tester.pump();
    repo.current = false;
    repo.pending!.complete(repo.response(repo.lastQuery!));
    await tester.pumpAndSettle();
    expect(find.text('65.0%'), findsNothing);
    expect(find.text('Your Admin session changed. Reopen Exercise Insights.'),
        findsOneWidget);
  });
  testWidgets(
      'configuration selects only reviewed policy IDs with an expected revision',
      (tester) async {
    final repo = FixtureInsightsRepository();
    await show(tester, repo: repo);
    await tester.tap(find.text('Threshold configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic squat policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reviewed selection'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.revision, 1);
    expect(find.textContaining('Configuration revision 1'), findsOneWidget);
  });
  testWidgets('narrow layout wraps controls and evidence without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExerciseInsightsPanel(
                repository: FixtureInsightsRepository(),
                clock: () => insightsNow))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
