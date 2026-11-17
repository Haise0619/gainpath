import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/recommendation/application/canonical_admin_recommendation_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'support/canonical_admin_recommendation_fixture.dart';
import 'support/recommendation_queue_fixture.dart';

Map<String, Object?> aiMonitorRecord({
  String kind = 'routine',
  String member = 'Alex Lim',
  String method = 'gemini',
  String status = 'delivered',
  int daysAgo = 1,
  String id = 'd',
}) {
  final raw = canonicalAdminRecord(status: status)
    ..['id'] = id.padLeft(64, id)
    ..['memberLabel'] = member
    ..['createdAtMillis'] =
        queueNow.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch;
  final suggestion = raw['suggestion']! as Map<String, Object?>;
  if (kind == 'routine') {
    suggestion['target'] = {
      'kind': 'routine',
      'organizationId': 'synthetic-org',
      'routineId': 'strength-20',
    };
    suggestion['targetLabel'] = 'Foundation Strength · 20 min';
  } else {
    suggestion['target'] = queueLead(kind: kind)['target'];
    suggestion['targetLabel'] =
        kind == 'trainer' ? 'Coach Maya' : 'Squat technique';
  }
  suggestion['summary'] =
      'Your recent squat practice and strength goal suit this focused session.';
  suggestion['ai'] = <String, Object?>{
    'method': method,
    'workoutContext': '3 completed workouts this week with 30 squat reps.',
    'fitnessGoals': ['Build strength'],
    'model': 'gemini-2.5-flash',
    'factors': ['Beginner experience', '20-minute session preference'],
  };
  return raw;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester t, CanonicalAdminHarness h,
      {double width = 1440, double scale = 1}) async {
    t.view.physicalSize = Size(width, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: RiskLeaderboardScreen(
          canonicalRepository: h.repository, queueClock: () => queueNow),
    ));
    await t.pumpAndSettle();
  }

  test('routine target and saved Gemini context parse with organization scope',
      () {
    final record =
        CanonicalAdminRecommendation.parse(aiMonitorRecord(), 'synthetic-org');
    expect(record.kind, 'routine');
    expect(record.aiMethodLabel, 'Gemini');
    expect(record.ai!.fitnessGoals, ['Build strength']);
    final raw = aiMonitorRecord();
    ((raw['suggestion'] as Map)['target'] as Map)['organizationId'] = 'foreign';
    expect(() => CanonicalAdminRecommendation.parse(raw, 'synthetic-org'),
        throwsFormatException);
  });
  test('old records show Rules and explicit failures show Rule fallback', () {
    expect(
        CanonicalAdminRecommendation.parse(
                canonicalAdminRecord(), 'synthetic-org')
            .aiMethodLabel,
        'Rules');
    expect(
        CanonicalAdminRecommendation.parse(
                aiMonitorRecord(method: 'rule_fallback'), 'synthetic-org')
            .aiMethodLabel,
        'Rule fallback');
  });
  test('withdrawn routine history parses without private AI payload', () {
    final raw = aiMonitorRecord()..remove('suggestion');
    raw.addAll({'status': 'withdrawn', 'redacted': true, 'kind': 'routine'});
    final record = CanonicalAdminRecommendation.parse(raw, 'synthetic-org');
    expect(record.kind, 'routine');
    expect(record.ai, isNull);
    expect(record.aiMethodLabel, 'Withheld');
  });
  testWidgets(
      'loaded scope KPIs, member search and Routine filter use saved records',
      (t) async {
    final h = CanonicalAdminHarness()
      ..records = [
        aiMonitorRecord(),
        aiMonitorRecord(kind: 'content', member: 'Jia Chen', id: 'e'),
        aiMonitorRecord(
            kind: 'trainer', status: 'prepared', member: 'Sam Tan', id: 'f'),
      ];
    await show(t, h);
    expect(find.textContaining('3 loaded'), findsOneWidget);
    for (final label in [
      'Total recommendations',
      'Tutorials',
      'Coaches',
      'Routines',
      'Delivered',
      'Delivery issues'
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byType(DataTable), findsOneWidget);
    await t.enterText(find.byType(TextField), 'jia');
    await t.pumpAndSettle();
    expect(find.text('Jia Chen'), findsOneWidget);
    expect(find.text('Alex Lim'), findsNothing);
    expect(h.requests.length, 1);
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.byKey(const ValueKey('monitor-type')));
    await t.pumpAndSettle();
    await t.tap(find.text('Routine').last);
    await t.pumpAndSettle();
    expect(find.text('Alex Lim'), findsOneWidget);
    expect(find.text('Jia Chen'), findsNothing);
  });
  testWidgets(
      'details show saved context, goals and actual method with technical foldout',
      (t) async {
    final h = CanonicalAdminHarness()..record = aiMonitorRecord();
    await show(t, h);
    await t.tap(find.text('View'));
    await t.pumpAndSettle();
    expect(find.text('3 completed workouts this week with 30 squat reps.'),
        findsOneWidget);
    expect(find.text('Build strength'), findsOneWidget);
    expect(find.text('Beginner experience'), findsOneWidget);
    expect(find.text('gemini-2.5-flash').hitTestable(), findsNothing);
    await t.ensureVisible(find.text('Technical Details'));
    await t.tap(find.text('Technical Details'));
    await t.pumpAndSettle();
    expect(find.textContaining('gemini-2.5-flash'), findsOneWidget);
    expect(h.requests.map((r) => r['operation']),
        ['admin.queue.list', 'admin.queue.detail']);
    expect(find.text('Approve & Send'), findsNothing);
  });
  testWidgets(
      'recent first and date filter preserve delivered outcome after expiry',
      (t) async {
    final old = aiMonitorRecord(id: 'e', daysAgo: 21, member: 'Older Member');
    old['expiresAtMillis'] =
        queueNow.subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    old['deliveredAtMillis'] =
        queueNow.subtract(const Duration(days: 20)).millisecondsSinceEpoch;
    final h = CanonicalAdminHarness()
      ..records = [old, aiMonitorRecord(member: 'Newer Member')];
    await show(t, h);
    expect(t.getTopLeft(find.text('Newer Member')).dy,
        lessThan(t.getTopLeft(find.text('Older Member')).dy));
    expect(find.text('Expired'), findsNothing);
    await t.tap(find.byKey(const ValueKey('monitor-date')));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 7 days').last);
    await t.pumpAndSettle();
    expect(find.text('Older Member'), findsNothing);
    expect(find.text('Newer Member'), findsOneWidget);
    expect(h.requests.length, 1);
  });
  testWidgets(
      'load more retains current filters and refresh resets server cursor',
      (t) async {
    final h = CanonicalAdminHarness()
      ..record = aiMonitorRecord()
      ..nextAfterId = 'd'.padLeft(64, 'd');
    await show(t, h);
    h.record = aiMonitorRecord(id: 'e', member: 'Second Member');
    h.nextAfterId = null;
    await t.ensureVisible(find.text('Load more'));
    await t.tap(find.text('Load more'));
    await t.pumpAndSettle();
    expect(find.text('Second Member'), findsOneWidget);
    expect(h.requests.last['afterId'], 'd'.padLeft(64, 'd'));
    await t.ensureVisible(find.text('Refresh'));
    await t.tap(find.text('Refresh'));
    await t.pumpAndSettle();
    expect(h.requests.last['afterId'], isNull);
    expect(find.text('Alex Lim'), findsNothing);
  });
  for (final layout in [(320.0, 1.0), (390.0, 2.0), (1024.0, 1.0)]) {
    testWidgets('monitor and details fit ${layout.$1} at ${layout.$2}',
        (t) async {
      final h = CanonicalAdminHarness()..record = aiMonitorRecord();
      await show(t, h, width: layout.$1, scale: layout.$2);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('View'));
      await t.tap(find.text('View'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Close'));
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'custom Malaysia dates include the final day and cancel retains the prior range',
      (t) async {
    final late = aiMonitorRecord(id: 'e', member: 'Late Member');
    late['createdAtMillis'] =
        DateTime.utc(2026, 10, 31, 15, 59).millisecondsSinceEpoch;
    final after = aiMonitorRecord(id: 'f', member: 'Next Day Member');
    after['createdAtMillis'] =
        DateTime.utc(2026, 10, 31, 16).millisecondsSinceEpoch;
    final h = CanonicalAdminHarness()..records = [late, after];
    await show(t, h);
    await t.tap(find.byKey(const ValueKey('monitor-date')));
    await t.pumpAndSettle();
    await t.tap(find.text('Custom dates').last);
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(DateRangePickerDialog))).pop(
        DateTimeRange(
            start: DateTime(2026, 10, 31), end: DateTime(2026, 10, 31)));
    await t.pumpAndSettle();
    expect(find.text('Late Member'), findsOneWidget);
    expect(find.text('Next Day Member'), findsNothing);
    await t.tap(find.byKey(const ValueKey('monitor-date')));
    await t.pumpAndSettle();
    await t.tap(find.text('2026-10-31 – 2026-10-31').last);
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(DateRangePickerDialog))).pop();
    await t.pumpAndSettle();
    expect(find.text('Late Member'), findsOneWidget);
    expect(find.text('Next Day Member'), findsNothing);
    expect(find.text('2026-10-31 – 2026-10-31'), findsOneWidget);
    expect(h.requests.length, 1);
  });
}
