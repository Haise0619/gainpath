import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';

/// Dedicated runner only. This never connects to a configured Firebase project
/// and cannot run accidentally as part of the ordinary Admin unit suite.
void main() {
  final enabled =
      Platform.environment['MODULE13_C_GATEWAY'] == '127.0.0.1:18112';
  testWidgets(
      'Admin UI persists Trainer Send and Content dismissal through the local Firestore gateway',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final client = HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5);
    addTearDown(() {
      client.close(force: true);
      HttpOverrides.global = previousOverrides;
    });
    Future<Map<String, Object?>> rpc(
        String method, Map<String, Object?> data) async {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:18112/rpc'));
      request.persistentConnection = false;
      request.headers.contentType = ContentType.json;
      request.headers
          .set('x-gainpath-fixture-session', 'module13-c-local-admin');
      request.write(jsonEncode({'method': method, 'data': data}));
      final response = await request.close();
      final raw = jsonDecode(await response.transform(utf8.decoder).join());
      if (response.statusCode != 200 || raw is! Map || raw['result'] is! Map) {
        throw StateError(
            'The local synthetic queue gateway rejected the request.');
      }
      return Map<String, Object?>.from(raw['result'] as Map);
    }

    Future<Map<String, Object?>> list(String kind, String status) async =>
        (await tester.runAsync(() => rpc(
            'list',
            RecommendationQueueQuery.recent(
                    'synthetic-org', kind, DateTime.now().toUtc(), 30)
                .filtered(status: status)
                .toJson())))!;
    Future<void> settle() async {
      for (var attempt = 0; attempt < 400; attempt++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final exception = tester.takeException();
        if (exception != null) throw exception;
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
      }
      fail('The local queue operation did not settle.');
    }

    Future<void> tap(String label) async {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await settle();
    }

    Future<void> refresh() async {
      await tap('Refresh queue');
      for (var batch = 0;
          batch < 10 && find.text('Continue refresh').evaluate().isNotEmpty;
          batch++) {
        await tap('Continue refresh');
      }
      expect(find.text('Continue refresh'), findsNothing);
    }

    final repository = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org', isCurrent: () => true, invoke: rpc);
    // Verify the dedicated loopback endpoint before creating any UI operation.
    final health = await tester.runAsync(() async {
      final response = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:18112/health')))
          .close();
      return jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    });
    expect(health!['fixtureOnly'], true);
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: RiskLeaderboardScreen(
            queueRepository: repository,
            queueClock: () => DateTime.now().toUtc())));
    await settle();
    await tap('Trainer Matching');
    await refresh();
    expect(find.text('Synthetic fixtures · local review only'), findsOneWidget);
    final trainerPending = await list('trainer', 'pending');
    expect((trainerPending['leads'] as List), isNotEmpty);
    final trainerId =
        ((trainerPending['leads'] as List).first as Map)['leadId'];
    await tap('View details');
    expect(find.textContaining('Observed option'), findsOneWidget);
    await tap('Close');
    await tap('Send');
    expect(find.textContaining('No notification'), findsOneWidget);
    await tap('Confirm Send');
    expect(find.textContaining('Prepared locally. No notification'),
        findsOneWidget);
    final trainerProcessed = await list('trainer', 'sent');
    final sent = (trainerProcessed['leads'] as List)
        .cast<Map>()
        .singleWhere((lead) => lead['leadId'] == trainerId);
    expect(sent['status'], 'sent');
    expect((sent['decision'] as Map)['recipientRecommendationId'], isNotNull);
    await tester.tap(find.byKey(const ValueKey('queue-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepared locally').last);
    await settle();
    expect(find.text('View details'), findsWidgets);
    await tap('Content Recommendations');
    await refresh();
    final contentPending = await list('content', 'pending');
    expect((contentPending['leads'] as List), isNotEmpty);
    final contentId =
        ((contentPending['leads'] as List).first as Map)['leadId'];
    await tap('Dismiss');
    await tester.enterText(find.byKey(const ValueKey('queue-dismiss-reason')),
        'Synthetic review: a different tutorial is preferred.');
    await tap('Confirm dismissal');
    expect(find.textContaining('Dismissed. The decision'), findsOneWidget);
    final contentProcessed = await list('content', 'dismissed');
    final dismissed = (contentProcessed['leads'] as List)
        .cast<Map>()
        .singleWhere((lead) => lead['leadId'] == contentId);
    expect(dismissed['status'], 'dismissed');
    expect((dismissed['decision'] as Map)['reason'],
        'Synthetic review: a different tutorial is preferred.');
    expect((dismissed['decision'] as Map)['recipientRecommendationId'], isNull);
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 2)));
}
