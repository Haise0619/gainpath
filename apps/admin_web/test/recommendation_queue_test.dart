import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'support/recommendation_queue_fixture.dart';

void main() {
  test(
      'detail requests only the bound lead identity and uses the fresh server record',
      () async {
    final cached = RecommendationLead.parse(queueLead(), 'synthetic-org');
    Map<String, Object?>? sent;
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => true,
        invoke: (method, request) async {
          expect(method, 'detail');
          sent = request;
          return {
            'schemaVersion': 1,
            'mode': 'synthetic_local',
            'organizationId': 'synthetic-org',
            'lead': queueLead()..['targetLabel'] = 'Fresh authorized Coach'
          };
        });
    expect((await repo.detail(cached)).targetLabel, 'Fresh authorized Coach');
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'synthetic-org',
      'leadId': 'lead-1'
    });
  });
  for (final corruption in [
    'schema',
    'mode',
    'org',
    'extra',
    'lead-id',
    'lead-org',
    'lead-kind',
    'private'
  ]) {
    test('detail rejects $corruption response before exposing evidence',
        () async {
      final fresh = queueLead();
      final result = <String, Object?>{
        'schemaVersion': 1,
        'mode': 'synthetic_local',
        'organizationId': 'synthetic-org',
        'lead': fresh
      };
      switch (corruption) {
        case 'schema':
          result['schemaVersion'] = 2;
        case 'mode':
          result['mode'] = 'production';
        case 'org':
          result['organizationId'] = 'other';
        case 'extra':
          result['rawHistory'] = [];
        case 'lead-id':
          fresh['leadId'] = 'lead-other';
        case 'lead-org':
          fresh['organizationId'] = 'other';
        case 'lead-kind':
          result['lead'] = queueLead(kind: 'content');
        case 'private':
          fresh['rawHistory'] = [];
      }
      final repo = RpcRecommendationQueueRepository(
          organizationId: 'synthetic-org',
          isCurrent: () => true,
          invoke: (_, __) async => result);
      await expectLater(
          repo.detail(RecommendationLead.parse(queueLead(), 'synthetic-org')),
          throwsFormatException);
    });
  }
  test(
      'detail drops asynchronous account drift and does not dispatch a foreign lead',
      () async {
    var current = true, calls = 0;
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => current,
        invoke: (_, __) async {
          calls++;
          current = false;
          return {
            'schemaVersion': 1,
            'mode': 'synthetic_local',
            'organizationId': 'synthetic-org',
            'lead': queueLead()
          };
        });
    final lead = RecommendationLead.parse(queueLead(), 'synthetic-org');
    await expectLater(
        repo.detail(lead), throwsA(isA<RecommendationQueueUnavailable>()));
    await expectLater(
        repo.detail(lead), throwsA(isA<RecommendationQueueUnavailable>()));
    expect(calls, 1);
    current = true;
    final rawForeign = queueLead()..['organizationId'] = 'other';
    final foreign = RecommendationLead.parse(rawForeign, 'other');
    await expectLater(
        repo.detail(foreign), throwsA(isA<RecommendationQueueUnavailable>()));
    expect(calls, 1);
  });
  test('normal unavailable repository never provides cached lead details',
      () async {
    await expectLater(
        const UnavailableRecommendationQueueRepository()
            .detail(RecommendationLead.parse(queueLead(), 'synthetic-org')),
        throwsA(isA<RecommendationQueueUnavailable>()));
  });
  test('Malaysia range is half-open and emits bounded server filters', () {
    final q = RecommendationQueueQuery.recent(
        'synthetic-org', 'trainer', queueNow, 7);
    expect(q.start, DateTime.utc(2026, 10, 25, 16));
    expect(q.end, queueNow);
    expect(q.toJson()['limit'], 25);
    expect(q.toJson()['status'], 'pending');
  });
  test(
      'strict page parser preserves unknown metrics and rejects private or foreign data',
      () {
    final raw = queuePage();
    ((raw['leads'] as List).single['evidence'] as Map)['coverage'] = null;
    expect(
        RecommendationQueuePage.parse(raw, queueQuery()).leads.single.coverage,
        isNull);
    final foreign = queuePage()..['organizationId'] = 'other';
    expect(() => RecommendationQueuePage.parse(foreign, queueQuery()),
        throwsFormatException);
    final leaked = queuePage();
    ((leaked['leads'] as List).single as Map)['rawHistory'] = [];
    expect(() => RecommendationQueuePage.parse(leaked, queueQuery()),
        throwsFormatException);
  });
  test(
      'validates queue kind, target, dates and query predicates instead of accepting stale response',
      () {
    for (final mutate in <void Function(Map)>[
      (r) => r['kind'] = ['trainer'],
      (r) => r['expiresAtMillis'] = 1,
      (r) => (r['target'] as Map)['kind'] = 'content',
      (r) => r['status'] = 'sent',
    ]) {
      final raw = queuePage();
      mutate((raw['leads'] as List).single as Map);
      expect(() => RecommendationQueuePage.parse(raw, queueQuery()),
          throwsFormatException);
    }
  });
  test(
      'RPC repository sends exact filters and rejects session drift after transport',
      () async {
    var current = true;
    Map<String, Object?>? request;
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => current,
        invoke: (method, body) async {
          expect(method, 'list');
          request = body;
          return queuePage();
        });
    final page = await repo.list(queueQuery());
    expect(page.leads.single.memberLabel, 'Sample Member');
    expect(request!['limit'], 25);
    current = false;
    expect(() => repo.list(queueQuery()),
        throwsA(isA<RecommendationQueueUnavailable>()));
  });
  test('rejects a decision response for the opposite Admin action', () async {
    final lead = RecommendationLead.parse(queueLead(), 'synthetic-org');
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => true,
        invoke: (_, body) async => {
              'schemaVersion': 1,
              'organizationId': 'synthetic-org',
              'leadId': lead.id,
              'revision': 2,
              'status': 'dismissed',
              'outcome': 'dismissed',
              'recipientRecommendationId': null,
              'deliveryStatus': 'not_prepared'
            });
    expect(() => repo.decide(lead, 'send', 'command-1'), throwsFormatException);
  });
  test(
      'drops an RPC response if the captured Admin scope changes during transport',
      () async {
    var current = true;
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => current,
        invoke: (_, body) async {
          current = false;
          return queuePage();
        });
    expect(() => repo.list(queueQuery()),
        throwsA(isA<RecommendationQueueUnavailable>()));
  });
  test(
      'accepts the same meaningful eight-character dismissal boundary as the server',
      () async {
    final lead = RecommendationLead.parse(queueLead(), 'synthetic-org');
    final repo = RpcRecommendationQueueRepository(
        organizationId: 'synthetic-org',
        isCurrent: () => true,
        invoke: (_, body) async {
          expect(body['reason'], 'Time off');
          return {
            'schemaVersion': 1,
            'organizationId': 'synthetic-org',
            'leadId': lead.id,
            'revision': 2,
            'status': 'dismissed',
            'outcome': 'dismissed',
            'recipientRecommendationId': null,
            'deliveryStatus': 'not_prepared'
          };
        });
    expect(
        (await repo.decide(lead, 'dismiss', 'command-1', reason: 'Time off'))
            .outcome,
        'dismissed');
  });
  test(
      'parses the complete bounded abstention taxonomy and rejects inconsistent totals',
      () {
    final raw = queueGeneration();
    expect(() => QueueGenerationSummary.parse(raw, 'trainer'), returnsNormally);
    (raw['abstentionReasons'] as Map)['insufficient_evidence'] = 2;
    expect(() => QueueGenerationSummary.parse(raw, 'trainer'),
        throwsFormatException);
    (raw['abstentionReasons'] as Map)['insufficient_evidence'] = 1;
    (raw['abstentionReasons'] as Map)['private_history'] = 0;
    expect(() => QueueGenerationSummary.parse(raw, 'trainer'),
        throwsFormatException);
  });
}
