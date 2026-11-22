import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'support/admin_test_fonts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/recommendation/application/canonical_admin_recommendation_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'support/canonical_admin_recommendation_fixture.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_monitor.dart';
import 'support/recommendation_queue_fixture.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester t, CanonicalAdminHarness h,
      {RecommendationMonitorTab tab =
          RecommendationMonitorTab.overview}) async {
    t.view.physicalSize = const Size(1440, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: RiskLeaderboardScreen(
            initialTab: tab,
            canonicalRepository: h.repository,
            queueClock: () => queueNow)));
    await t.pumpAndSettle();
  }

  testWidgets(
      'Overview source filter and Details stay visible without duplicate navigation',
      (t) async {
    addTearDown(await installFypOfflineFonts());
    await loadAdminMaterialIcons();
    final h = CanonicalAdminHarness(), key = GlobalKey();
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: Scaffold(
                body: Column(children: [
              const Material(
                  child: SizedBox(
                      width: double.infinity,
                      child: Text(
                          'OFFLINE WIDGET FIXTURE · substitute typography · no live provider request'))),
              Expanded(
                  child: RiskLeaderboardScreen(
                      canonicalRepository: h.repository,
                      queueClock: () => queueNow)),
            ])))));
    await t.pumpAndSettle();
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Exercise Guidance Insights'), findsNothing);
    expect(find.text('Source'), findsWidgets);
    final details = find.text('View Details');
    expect(details.hitTestable(), findsOneWidget);
    expect(t.getBottomRight(details).dx, lessThan(1280));
    final requests = h.requests.length;
    if (const bool.fromEnvironment('GAINPATH_RENDER_ADMIN_AI')) {
      await t.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
            '../../build/module13-completion-20261118/screenshots/overview-fixture.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await t.tap(find.byKey(const ValueKey('monitor-source')));
    await t.pumpAndSettle();
    await t.tap(find.text('Admin Outreach').last);
    await t.pumpAndSettle();
    expect(find.text('View Details'), findsNothing);
    expect(h.requests.length, requests);
    expect(t.takeException(), isNull);
  });

  test('canonical record rejects synthetic scope and unproved delivery', () {
    expect(
        () => CanonicalAdminRecommendation.parse(
            canonicalAdminRecord()..['mode'] = 'synthetic_local',
            'synthetic-org'),
        throwsFormatException);
    expect(
        () => CanonicalAdminRecommendation.parse(
            canonicalAdminRecord(), 'foreign'),
        throwsFormatException);
    expect(
        () => CanonicalAdminRecommendation.parse(
            canonicalAdminRecord()..['status'] = 'delivered', 'synthetic-org'),
        throwsFormatException);
  });
  test('canonical assessed summary preserves verified cohort counts', () {
    final record = CanonicalAdminRecommendation.parse(
        canonicalAdminRecord(), 'synthetic-org');
    expect(record.evidenceSummary,
        contains('3 qualifying assessments across 3 days'));
  });
  test('withdrawn canonical history needs no private suggestion payload', () {
    final raw = canonicalAdminRecord()..remove('suggestion');
    raw.addAll({'status': 'withdrawn', 'redacted': true, 'kind': 'content'});
    final parsed = CanonicalAdminRecommendation.parse(raw, 'synthetic-org');
    expect(parsed.status, 'withdrawn');
    expect(parsed.actionable(queueNow), isFalse);
    expect(parsed.explanations, isEmpty);
    expect(parsed.targetLabel, 'Unavailable');
  });
  test('canonical access denies operations until reviewed server admission',
      () async {
    final h = CanonicalAdminHarness()..enabled = false;
    expect(await h.repository.access(), isFalse);
    await expectLater(h.repository.list(), throwsStateError);
    expect(h.requests.map((r) => r['operation']), ['session.access']);
  });
  testWidgets('server disabled state never lists records or offers approval',
      (t) async {
    final h = CanonicalAdminHarness()..enabled = false;
    await show(t, h);
    expect(find.textContaining('await review'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
    expect(h.requests.length, 1);
  });
  testWidgets(
      'canonical detail revalidates before evidence and collapses technical data',
      (t) async {
    final h = CanonicalAdminHarness();
    await show(t, h);
    expect(h.requests.map((r) => r['operation']), ['admin.queue.list']);
    expect(find.textContaining('1 loaded'), findsOneWidget);
    expect(find.text('Fictional educational dataset'), findsNothing);
    h.pendingDetail = Completer<Object?>();
    await t.tap(find.text('View Details'));
    await t.pump();
    expect(find.text('Approve & Send'), findsNothing);
    h.pendingDetail!.complete(h.record);
    await t.pumpAndSettle();
    expect(find.text('Approve & Send'), findsNothing);
    expect(find.textContaining('Member account: member-1').hitTestable(),
        findsNothing);
    await t.ensureVisible(find.text('Technical Details'));
    await t.tap(find.text('Technical Details'));
    await t.pumpAndSettle();
    expect(find.textContaining('Member account: member-1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'revoked detail clears cached evidence and safe error does not leak',
      (t) async {
    final h = CanonicalAdminHarness()..failDetail = true;
    await show(t, h);
    await t.tap(find.text('View Details'));
    await t.pumpAndSettle();
    expect(find.text('Approve & Send'), findsNothing);
    expect(find.textContaining('Private revoked'), findsNothing);
    expect(find.textContaining('could not be verified'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
  });
  testWidgets(
      'prepared records appear in Delivery Issues without delivery actions',
      (t) async {
    final h = CanonicalAdminHarness();
    h.record['status'] = 'prepared';
    await show(t, h, tab: RecommendationMonitorTab.attention);
    await t.pumpAndSettle();
    expect(find.text('Delivery unverified'), findsOneWidget);
    await t.tap(find.text('View Details'));
    await t.pumpAndSettle();
    expect(find.text('Retry delivery'), findsNothing);
    expect(h.requests.where((r) => r['operation'] == 'admin.queue.decide'),
        isEmpty);
  });
  testWidgets('account change drops a pending detail without evidence',
      (t) async {
    final h = CanonicalAdminHarness();
    await show(t, h);
    h.pendingDetail = Completer<Object?>();
    await t.tap(find.text('View Details'));
    await t.pump();
    h.current = false;
    h.pendingDetail!.complete(h.record);
    await t.pumpAndSettle();
    expect(find.text('Approve & Send'), findsNothing);
    expect(find.text('Your Admin session changed. Reopen Recommendations.'),
        findsOneWidget);
  });
  testWidgets(
      'search and history include pending records without extra requests',
      (t) async {
    final h = CanonicalAdminHarness();
    await show(t, h);
    await t.enterText(find.byType(TextField), 'unmatched');
    await t.pumpAndSettle();
    expect(find.text('View Details'), findsNothing);
    await t.enterText(find.byType(TextField), 'squat');
    await t.pumpAndSettle();
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.text('Earlier records'), findsNothing);
  });
}
