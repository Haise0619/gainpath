import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_queue_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support/recommendation_queue_fixture.dart';
import 'support/recommendation_queue_transport.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester tester, QueueTransportHarness h,
      {bool trainer = true, double width = 1400, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: RecommendationQueuePanel(
                    trainer: trainer,
                    repository: h.repository,
                    clock: () => queueNow)))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'normal hub needs no prototype provider and both queues fail closed',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: RiskLeaderboardScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Trainer Matching'));
    await tester.pumpAndSettle();
    expect(find.text('Recommendation queue is unavailable in this release.'),
        findsOneWidget);
    expect(find.text('Export CSV'), findsNothing);
    await tester.tap(find.text('Content Recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('Recommendation queue is unavailable in this release.'),
        findsOneWidget);
  });
  testWidgets(
      'injected queue shows truthful counts and kind-specific reviewed details',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    expect(find.text('Educational review'), findsOneWidget);
    expect(find.text('Sample Member'), findsOneWidget);
    expect(find.text('Sample Coach'), findsOneWidget);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Observed option'), findsOneWidget);
    expect(find.textContaining('not reserved'), findsOneWidget);
    expect(find.textContaining('Estimated Form Score: 64.0%'), findsOneWidget);
    expect(find.text('member-1'), findsNothing);
    expect(find.text('coach-1'), findsNothing);
    expect(find.text('Matches the supported exercise.'), findsOneWidget);
  });
  testWidgets(
      'Send requires confirmation and reports preparation without claiming delivery',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r['method'] == 'decide'), isEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('No notification'), findsOneWidget);
    await tester.tap(find.text('Confirm Send'));
    await tester.pumpAndSettle();
    expect(
        h.requests.lastWhere((r) => r['method'] == 'decide')['action'], 'send');
    expect(find.textContaining('Prepared locally'), findsWidgets);
    expect(find.text('Sample Member'), findsNothing);
  });

  testWidgets(
      'denied fresh details withhold cached evidence and clear stale rows',
      (tester) async {
    final h = QueueTransportHarness()..failDetail = true;
    await show(tester, h);
    expect(find.text('Sample Member'), findsOneWidget);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Recommendation details'), findsNothing);
    expect(find.text('Evidence summary'), findsNothing);
    expect(find.text('Synthetic compatible squat observations for review.'),
        findsNothing);
    expect(find.text('Sample Member'), findsNothing);
    expect(find.textContaining('private revoked'), findsNothing);
    expect(
        find.text(
            'Recommendation details could not be verified. Reload records before reviewing again.'),
        findsOneWidget);
  });

  testWidgets(
      'details display the freshly authorized label instead of the cached list lead',
      (tester) async {
    final h = QueueTransportHarness()
      ..freshDetail = (queueLead()..['targetLabel'] = 'Fresh authorized Coach');
    await show(tester, h);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Recommendation details'), findsOneWidget);
    expect(
        find.text('Suggested Coach: Fresh authorized Coach'), findsOneWidget);
    expect(find.text('Suggested Coach: Sample Coach'), findsNothing);
    expect(h.requests.last, {
      'method': 'detail',
      'schemaVersion': 1,
      'organizationId': 'synthetic-org',
      'leadId': 'lead-1'
    });
  });

  testWidgets(
      'pending detail withholds evidence and drops account drift before dialog creation',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    h.detailPending = Completer<Map<String, Object?>>();
    await tester.tap(find.text('View details'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Recommendation details'), findsNothing);
    expect(find.text('Evidence summary'), findsNothing);
    h.current = false;
    h.detailPending!.complete({
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'organizationId': 'synthetic-org',
      'lead': queueLead()
    });
    await tester.pumpAndSettle();
    expect(find.text('Recommendation details'), findsNothing);
    expect(find.text('Sample Member'), findsNothing);
    expect(find.text('Your Admin session changed. Reopen Recommendations.'),
        findsOneWidget);
  });

  testWidgets(
      'replaced repository cannot open an older pending detail projection',
      (tester) async {
    final old = QueueTransportHarness();
    final fresh = QueueTransportHarness();
    var selected = old;
    late StateSetter replace;
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, update) {
      replace = update;
      return RecommendationQueuePanel(
          trainer: true,
          repository: selected.repository,
          clock: () => queueNow);
    }))));
    await tester.pumpAndSettle();
    old.detailPending = Completer<Map<String, Object?>>();
    await tester.tap(find.text('View details'));
    await tester.pump();
    replace(() => selected = fresh);
    await tester.pumpAndSettle();
    old.detailPending!.complete({
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'organizationId': 'synthetic-org',
      'lead': queueLead()..['memberLabel'] = 'Old private label'
    });
    await tester.pumpAndSettle();
    expect(find.text('Old private label'), findsNothing);
    expect(find.text('Recommendation details'), findsNothing);
    expect(find.text('Sample Member'), findsOneWidget);
  });
  testWidgets(
      'dismiss rejects a trivial reason and persists a meaningful reason',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('queue-dismiss-reason')), 'no');
    await tester.tap(find.text('Confirm dismissal'));
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r['method'] == 'decide'), isEmpty);
    expect(find.textContaining('at least 8 characters'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('queue-dismiss-reason')),
        'No suitable time available.');
    await tester.tap(find.text('Confirm dismissal'));
    await tester.pumpAndSettle();
    expect(h.requests.lastWhere((r) => r['method'] == 'decide')['reason'],
        'No suitable time available.');
  });
  testWidgets(
      'refresh continuation reuses one command while reload and filters stay bounded',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    await tester.tap(find.text('Refresh queue'));
    await tester.pumpAndSettle();
    expect(find.text('Continue refresh'), findsOneWidget);
    await tester.tap(find.text('Continue refresh'));
    await tester.pumpAndSettle();
    final refreshes =
        h.requests.where((r) => r['method'] == 'refresh').toList();
    expect(refreshes.length, 2);
    expect(refreshes[1]['commandId'], refreshes[0]['commandId']);
    expect(refreshes[1]['continuation'], 'continue-1');
    await tester.tap(find.byKey(const ValueKey('queue-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper Body').last);
    await tester.pumpAndSettle();
    expect(h.requests.last['category'], 'Upper Body');
    expect(h.requests.last['afterLeadId'], isNull);
    expect(h.requests.last['limit'], 25);
    expect(
        find.text('No recommendations match these filters.'), findsOneWidget);
  });
  testWidgets('load errors are safe and a retry recovers', (tester) async {
    final h = QueueTransportHarness()..failList = true;
    await show(tester, h);
    expect(find.textContaining('private provider'), findsNothing);
    expect(find.text('Recommendation queue could not be loaded. Retry.'),
        findsOneWidget);
    h.failList = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Member'), findsOneWidget);
  });
  testWidgets(
      'session drift drops an outstanding result and disables mutations',
      (tester) async {
    final h = QueueTransportHarness()
      ..pending = Completer<Map<String, Object?>>();
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecommendationQueuePanel(
                trainer: true,
                repository: h.repository,
                clock: () => queueNow))));
    await tester.pump();
    h.current = false;
    h.pending!.complete(queuePage());
    await tester.pumpAndSettle();
    expect(find.text('Sample Member'), findsNothing);
    expect(find.text('Your Admin session changed. Reopen Recommendations.'),
        findsOneWidget);
    expect(find.text('Send'), findsNothing);
  });
  testWidgets('small width and enlarged text wrap controls and cards',
      (tester) async {
    await show(tester, QueueTransportHarness(), width: 375, scale: 1.7);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'content details show an existing tutorial destination without exposing IDs',
      (tester) async {
    await show(tester, QueueTransportHarness(), trainer: false);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Published routine tutorial'), findsOneWidget);
    expect(find.textContaining('Day 1'), findsOneWidget);
    expect(find.text('routine-1'), findsNothing);
  });
  testWidgets(
      'pagination appends the bounded cursor page without replacing records',
      (tester) async {
    final h = QueueTransportHarness()..nextPage = 'lead-1';
    await show(tester, h);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(h.requests.last['afterLeadId'], 'lead-1');
    expect(h.requests.last['limit'], 25);
    expect(find.text('Sample Member'), findsNWidgets(2));
    expect(find.text('Load more'), findsNothing);
  });
  testWidgets(
      'a delayed filter query retains valid filter choices while clearing old rows',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    h.pending = Completer<Map<String, Object?>>();
    await tester.tap(find.byKey(const ValueKey('queue-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper Body').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Sample Member'), findsNothing);
    h.pending!.complete(queuePage(leads: []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'decision errors preserve the lead and retry the same idempotent command',
      (tester) async {
    final h = QueueTransportHarness()..failDecision = true;
    await show(tester, h);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Send'));
    await tester.pumpAndSettle();
    expect(find.text('Decision could not be saved. Retry or cancel.'),
        findsOneWidget);
    expect(find.textContaining('private decision'), findsNothing);
    h.failDecision = false;
    await tester.tap(find.text('Confirm Send'));
    await tester.pumpAndSettle();
    final requests = h.requests.where((r) => r['method'] == 'decide').toList();
    expect(requests.length, 2);
    expect(requests[1]['commandId'], requests[0]['commandId']);
    expect(find.text('Sample Member'), findsNothing);
  });
  testWidgets('replacing a repository drops an older pending session response',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final old = QueueTransportHarness()
      ..pending = Completer<Map<String, Object?>>();
    final fresh = QueueTransportHarness();
    Widget panel(QueueTransportHarness h) => MaterialApp(
        home: Scaffold(
            body: RecommendationQueuePanel(
                trainer: true,
                repository: h.repository,
                clock: () => queueNow)));
    await tester.pumpWidget(panel(old));
    await tester.pump();
    await tester.pumpWidget(panel(fresh));
    await tester.pumpAndSettle();
    final response = queuePage();
    ((response['leads'] as List).single as Map)['memberLabel'] =
        'Old session Member';
    old.pending!.complete(response);
    await tester.pumpAndSettle();
    expect(find.text('Sample Member'), findsOneWidget);
    expect(find.text('Old session Member'), findsNothing);
  });
  testWidgets(
      'refresh advances the open date window to include newly generated records',
      (tester) async {
    final h = QueueTransportHarness();
    var now = queueNow;
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecommendationQueuePanel(
                trainer: true, repository: h.repository, clock: () => now))));
    await tester.pumpAndSettle();
    now = queueNow.add(const Duration(minutes: 2));
    await tester.tap(find.text('Refresh queue'));
    await tester.pumpAndSettle();
    expect(h.requests.last['endAtMillis'],
        queueNow.add(const Duration(minutes: 2)).millisecondsSinceEpoch);
  });
  testWidgets(
      'refresh visibly reports progress and disables repeat actions while pending',
      (tester) async {
    final h = QueueTransportHarness();
    await show(tester, h);
    h.refreshPending = Completer<Map<String, Object?>>();
    await tester.tap(find.text('Refresh queue'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('Refresh queue'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    h.refreshPending!.complete({
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'organizationId': 'synthetic-org',
      'summary': queueGeneration()
    });
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('terminal failed refresh shown by reload allows a new command',
      (tester) async {
    final h = QueueTransportHarness()..failRefresh = true;
    await show(tester, h);
    await tester.tap(find.text('Refresh queue'));
    await tester.pumpAndSettle();
    final first =
        h.requests.lastWhere((r) => r['method'] == 'refresh')['commandId'];
    h.generationStatus = 'failed';
    await tester.tap(find.text('Reload records'));
    await tester.pumpAndSettle();
    expect(find.text('Refresh queue'), findsOneWidget);
    h.failRefresh = false;
    h.generationStatus = null;
    await tester.tap(find.text('Refresh queue'));
    await tester.pumpAndSettle();
    expect(h.requests.lastWhere((r) => r['method'] == 'refresh')['commandId'],
        isNot(first));
  });
  testWidgets(
      'an unknown lost refresh response retries the same command without regeneration',
      (tester) async {
    final h = QueueTransportHarness()..failRefresh = true;
    await show(tester, h);
    await tester.tap(find.text('Refresh queue'));
    await tester.pumpAndSettle();
    h.failRefresh = false;
    await tester.tap(find.text('Retry refresh'));
    await tester.pumpAndSettle();
    final requests = h.requests.where((r) => r['method'] == 'refresh').toList();
    expect(requests.length, 2);
    expect(requests[1]['commandId'], requests[0]['commandId']);
  });
  for (final status in ['sent', 'dismissed']) {
    testWidgets('past validity preserves $status processed-history label',
        (tester) async {
      final h = QueueTransportHarness()
        ..status = status
        ..expiresAt = queueNow.subtract(const Duration(hours: 1));
      await show(tester, h);
      await tester.tap(find.byKey(const ValueKey('queue-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All statuses').last);
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsNothing);
      expect(find.text(status == 'sent' ? 'Prepared locally' : 'Dismissed'),
          findsOneWidget);
      expect(find.text('Send'), findsNothing);
    });
  }
  testWidgets('mock semantic provider is labeled explicitly in current details',
      (tester) async {
    final detail = queueLead();
    (detail['ranking'] as Map)['model'] = 'gainpath-demo-structured-mock-v1';
    (detail['ranking'] as Map)['origin'] = 'ai_reranked';
    final h = QueueTransportHarness()..freshDetail = detail;
    await show(tester, h);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Rule-based relevance · educational review'),
        findsOneWidget);
    expect(find.textContaining('AI-assisted ranking'), findsNothing);
  });
  testWidgets(
      'generation explains insufficient evidence without exposing internal reason codes',
      (tester) async {
    final h = QueueTransportHarness()..generationStatus = 'complete';
    await show(tester, h);
    expect(find.textContaining('Insufficient evidence: 1'), findsOneWidget);
    expect(find.textContaining('insufficient_evidence'), findsNothing);
  });
  testWidgets(
      'empty generation explains no eligible candidates separately from load failure',
      (tester) async {
    final h = QueueTransportHarness()
      ..status = 'revoked'
      ..generationStatus = 'complete'
      ..abstentionReasons = {
        'insufficient_evidence': 0,
        'unsupported_evidence': 0,
        'missing_consent': 0,
        'no_eligible_candidates': 1,
        'semantic_abstention': 0
      };
    await show(tester, h);
    expect(find.textContaining('No eligible candidates: 1'), findsOneWidget);
    expect(
        find.text('No recommendations match these filters.'), findsOneWidget);
    expect(find.text('Recommendation queue could not be loaded. Retry.'),
        findsNothing);
  });
}
