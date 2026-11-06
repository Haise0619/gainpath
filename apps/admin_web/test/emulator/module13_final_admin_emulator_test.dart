import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';

typedef Rpc = Future<Map<String, Object?>> Function(
    String method, Map<String, Object?> data);

class EInsightsRepository implements ExerciseInsightsRepository {
  EInsightsRepository(this.rpc);
  final Rpc rpc;
  @override
  String get organizationId => 'gainpath';
  @override
  bool get isCurrent => true;
  @override
  bool get enabled => true;
  @override
  bool get fixtureOnly => true;
  @override
  Future<Object?> load(ExerciseInsightsQuery query) =>
      rpc('insights', query.toJson());
  @override
  Future<InsightsConfigurationOptions> configuration() async {
    final data = await rpc('configuration',
        {'schemaVersion': 1, 'organizationId': organizationId});
    return InsightsConfigurationOptions(
        revision: data['revision'] as int,
        selectedPolicyIds: const [],
        availablePolicies: const []);
  }

  @override
  Future<int> saveConfiguration(int expectedRevision, List<String> policyIds) =>
      throw StateError('No policy is approved in E');
}

void main() {
  final enabled =
      Platform.environment['MODULE13_FINAL_GATEWAY'] == '127.0.0.1:18118';
  testWidgets(
      'Actual Admin loads protected Insights then refreshes reviews and sends both final kinds',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    final client = HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5);
    addTearDown(() {
      client.close(force: true);
      HttpOverrides.global = previous;
    });
    Future<Map<String, Object?>> rpc(
        String method, Map<String, Object?> data) async {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:18118/rpc'));
      request.persistentConnection = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('x-gainpath-fixture-session', 'module13-final-local');
      request.headers.set('x-gainpath-fixture-role', 'admin');
      request.write(jsonEncode({'method': method, 'data': data}));
      final response = await request.close();
      final raw = jsonDecode(await response.transform(utf8.decoder).join());
      if (response.statusCode != 200 || raw is! Map || raw['result'] is! Map) {
        throw StateError('E local Admin operation was not confirmed.');
      }
      return Map<String, Object?>.from(raw['result'] as Map);
    }

    final health = (await tester.runAsync(() async {
      final response = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:18118/health')))
          .close();
      return jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    }))!;
    expect(health['fixtureOnly'], true);
    final logical = DateTime.fromMillisecondsSinceEpoch(
        health['nowMillis'] as int,
        isUtc: true);
    final hostStart = DateTime.now();
    DateTime clock() => logical.add(DateTime.now().difference(hostStart));
    Future<void> settle() async {
      for (var i = 0; i < 400; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final exception = tester.takeException();
        if (exception != null) throw exception;
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
      }
      fail('E Admin operation did not settle.');
    }

    Future<void> tap(String label) async {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await settle();
    }

    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final queue = RpcRecommendationQueueRepository(
        organizationId: 'gainpath', isCurrent: () => true, invoke: rpc);
    await tester.pumpWidget(MaterialApp(
        home: RiskLeaderboardScreen(
            insightsRepository: EInsightsRepository(rpc),
            queueRepository: queue,
            queueClock: clock)));
    await settle();
    expect(find.text('Exercise Insights'), findsWidgets);
    // Canonical validated synthetic backups drive descriptive Insights and the queue.
    expect(find.textContaining('could not be loaded'), findsNothing);
    final insight = (await tester.runAsync(() => rpc(
        'insights',
        ExerciseInsightsQuery.recent(
                'gainpath', DateTime.now().toUtc(), 30)
            .toJson())))!;
    expect(insight['mode'], 'descriptive_only');
    expect(insight['recommendationEligibility'], 'not_evaluated');
    expect(insight['groups'], isNotEmpty);
    final group = (insight['groups'] as List).single as Map;
    expect((group['metrics'] as Map)['meanEstimatedFormScore'], 62);
    expect((group['metrics'] as Map)['scoredSessions'], 6);
    expect(insight['content'], isNotEmpty);
    for (final kind in ['trainer', 'content']) {
      await tap(
          kind == 'trainer' ? 'Trainer Matching' : 'Content Recommendations');
      await tap('Refresh queue');
      for (var batch = 0;
          batch < 10 && find.text('Continue refresh').evaluate().isNotEmpty;
          batch++) {
        await tap('Continue refresh');
      }
      final pending = (await tester.runAsync(() => rpc(
          'list',
          RecommendationQueueQuery.recent('gainpath', kind, clock(), 30)
              .filtered(status: 'pending')
              .toJson()
            ..['kind'] = kind)))!;
      expect((pending['leads'] as List), hasLength(1));
      final derivedLead = (pending['leads'] as List).single as Map;
      expect(derivedLead['exerciseId'], 'F3b8xIr8ynBDd3gEICKX');
      expect((derivedLead['evidence'] as Map)['sourceVersion'], 'validated-workout-evidence-v1');
      expect((derivedLead['evidence'] as Map)['scoredSessions'], 3);
      expect((derivedLead['evidence'] as Map)['estimatedFormScorePercent'], 62);
      await tap('View details');
      if (kind == 'trainer') {
        expect(find.textContaining('Observed option'), findsOneWidget);
      }
      await tap('Close');
      await tap('Send');
      expect(find.textContaining('No notification'), findsOneWidget);
      await tap('Confirm Send');
      expect(find.textContaining('Prepared locally. No notification'),
          findsOneWidget);
      final sent = (await tester.runAsync(() => rpc(
          'list',
          RecommendationQueueQuery.recent('gainpath', kind, clock(), 30)
              .filtered(status: 'sent')
              .toJson()
            ..['kind'] = kind)))!;
      expect((sent['leads'] as List), hasLength(1));
      expect(((sent['leads'] as List).single as Map)['status'], 'sent');
    }
    await tester.pumpWidget(const SizedBox());
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
}
