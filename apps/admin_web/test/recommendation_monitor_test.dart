import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_monitor.dart';

import 'support/recommendation_queue_fixture.dart';

class _Transport {
  final tab = ValueNotifier(RecommendationMonitorTab.overview);
  final calls = <Map<String, Object?>>[];
  Completer<void>? lists, details;
  bool current = true, failDetail = false;
  late final repository = RpcRecommendationQueueRepository(
    organizationId: 'synthetic-org',
    isCurrent: () => current,
    invoke: (operation, request) async {
      calls.add({'operation': operation, ...request});
      if (operation == 'detail') {
        await details?.future;
        if (failDetail) throw StateError('private transport error');
        return {
          'schemaVersion': 1,
          'mode': 'synthetic_local',
          'organizationId': 'synthetic-org',
          'lead': queueLead(id: request['leadId']! as String, status: 'sent'),
        };
      }
      await lists?.future;
      final kind = request['kind']! as String;
      final id = '$kind-${request['afterLeadId'] == null ? 1 : 2}';
      return queuePage(
        kind: kind,
        leads: [queueLead(kind: kind, id: id, status: 'sent')],
        next: request['afterLeadId'] == null ? id : null,
      )..['deliveredLeadIds'] = kind == 'trainer' ? [id] : <String>[];
    },
  );

  int count(String operation) =>
      calls.where((call) => call['operation'] == operation).length;
}

Future<void> _show(WidgetTester tester, _Transport transport,
    {double width = 1440, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: ValueListenableBuilder(
        valueListenable: transport.tab,
        builder: (context, tab, _) => RiskLeaderboardScreen(
              initialTab: tab,
              queueRepository: transport.repository,
              queueClock: () => queueNow,
            )),
  ));
}

void main() {
  testWidgets('initial requests overlap and tabs and filters use loaded pages',
      (tester) async {
    final transport = _Transport()..lists = Completer<void>();
    await _show(tester, transport);
    expect(transport.count('list'), 2);
    expect(find.bySemanticsLabel('Loading recommendations'), findsOneWidget);
    transport.lists!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sample Coach'), findsOneWidget);
    expect(find.text('Squat foundations'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Delivery unverified'), findsOneWidget);

    transport.tab.value = RecommendationMonitorTab.attention;
    await tester.pumpAndSettle();
    expect(find.text('Squat foundations'), findsOneWidget);
    expect(find.text('Sample Coach'), findsNothing);

    transport.tab.value = RecommendationMonitorTab.history;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sample coach');
    await tester.pumpAndSettle();
    expect(find.text('Sample Coach'), findsOneWidget);
    expect(find.text('Squat foundations'), findsNothing);
    expect(transport.count('list'), 2);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(transport.calls.skip(2).map((call) => call['afterLeadId']),
        unorderedEquals(['trainer-1', 'content-1']));
  });

  testWidgets(
      'drawer opens immediately, coalesces clicks and fetches fresh detail',
      (tester) async {
    final transport = _Transport()..details = Completer<void>();
    await _show(tester, transport, width: 320, scale: 2);
    await tester.pumpAndSettle();
    transport.tab.value = RecommendationMonitorTab.history;
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: list,
            matching: find.byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down))
        .first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final coachCard = find.ancestor(
        of: find.text('Sample Coach'), matching: find.byType(Card));
    final coachView =
        find.descendant(of: coachCard, matching: find.text('View'));
    await tester.ensureVisible(coachView);
    await tester.pumpAndSettle();
    await tester.tap(coachView);
    await tester.tap(coachView, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Recommendation details'), findsOneWidget);
    expect(find.bySemanticsLabel('Verifying recommendation'), findsOneWidget);
    expect(find.textContaining('Specialization:'), findsNothing);
    expect(transport.count('detail'), 1);
    transport.details!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Specialization: Strength'), findsOneWidget);
    expect(find.text('Approve & Send'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    transport.failDetail = true;
    await tester.tap(coachView);
    await tester.pumpAndSettle();
    expect(transport.count('detail'), 2);
    expect(find.text('Recommendation details could not be verified.'),
        findsOneWidget);
    expect(find.text('Specialization: Strength'), findsNothing);
    expect(find.textContaining('private transport'), findsNothing);
  });

  testWidgets('account drift discards detail that was still in flight',
      (tester) async {
    final transport = _Transport()..details = Completer<void>();
    await _show(tester, transport);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View').last);
    await tester.pumpAndSettle();
    transport.current = false;
    transport.details!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your Admin session changed.'), findsOneWidget);
    expect(find.text('Specialization: Strength'), findsNothing);
  });
}
