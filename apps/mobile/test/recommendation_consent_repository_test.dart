import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/recommendation/application/recommendation_consent_repository.dart';
import 'support/recommendation_consent_fixture.dart';

void main() {
  test(
      'absent server record is four default-off purposes with scoped revision zero',
      () async {
    final requests = <Map<String, Object?>>[];
    final repository = RpcRecommendationConsentRepository(
      scope: consentScope,
      isCurrent: () => true,
      read: (q) async {
        requests.add(q);
        return null;
      },
      command: (_) async => throw StateError('must not write'),
    );
    final result = await repository.load();
    expect(result.revision, 0);
    expect(result.purposes.values.every((p) => !p.granted && p.revision == 0),
        isTrue);
    expect(requests.single, {'schemaVersion': 2, 'organizationId': 'gym1'});
  });

  test(
      'grant emits exact v2 fields without member/history/mode supplied by client',
      () async {
    Map<String, Object?>? sent;
    final repository = RpcRecommendationConsentRepository(
      scope: consentScope,
      isCurrent: () => true,
      read: (_) async => null,
      command: (q) async {
        sent = q;
        return consentReceipt(q);
      },
    );
    await repository.change(
        await repository.load(), RecommendationConsentPurpose.exerciseInsights,
        granted: true, commandId: 'intent-1', notice: consentNotice);
    expect(sent, {
      'schemaVersion': 2,
      'organizationId': 'gym1',
      'commandId': 'intent-1',
      'expectedRevision': 0,
      'purpose': 'exerciseInsights',
      'action': 'grant',
      'noticePolicyId': 'synthetic-only-policy',
      'acceptedNoticeVersion': 'synthetic-notice-1',
      'acceptedContentVersion': 'synthetic-content-1'
    });
  });

  test('revoke omits notice fields and leaves other purposes independent',
      () async {
    Map<String, Object?>? sent;
    final repository = RpcRecommendationConsentRepository(
      scope: consentScope,
      isCurrent: () => true,
      read: (_) async => null,
      command: (q) async {
        sent = q;
        return consentReceipt(q);
      },
    );
    await repository.change(await repository.load(),
        RecommendationConsentPurpose.externalAiInference,
        granted: false, commandId: 'intent-revoke');
    expect(sent, {
      'schemaVersion': 2,
      'organizationId': 'gym1',
      'commandId': 'intent-revoke',
      'expectedRevision': 0,
      'purpose': 'externalAiInference',
      'action': 'revoke'
    });
  });

  test(
      'same explicit intent replays exactly without generating a replacement ID',
      () async {
    final requests = <Map<String, Object?>>[];
    final repository = RpcRecommendationConsentRepository(
      scope: consentScope,
      isCurrent: () => true,
      read: (_) async => null,
      command: (q) async {
        requests.add(q);
        return consentReceipt(q);
      },
    );
    final current = await repository.load();
    for (var retry = 0; retry < 2; retry++) {
      await repository.change(
          current, RecommendationConsentPurpose.recommendationDelivery,
          granted: false, commandId: 'durable-intent');
    }
    expect(requests[0], requests[1]);
  });

  test('account drift before dispatch and after asynchronous read fails closed',
      () async {
    var current = true;
    final pending = Completer<Map<String, Object?>?>();
    var calls = 0;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => current,
        read: (_) {
          calls++;
          return pending.future;
        },
        command: (_) async => throw StateError('must not write'));
    final loading = repository.load();
    current = false;
    pending.complete(consentWire(revision: 1, granted: true));
    await expectLater(
        loading, throwsA(isA<RecommendationConsentUnavailable>()));
    await expectLater(
        repository.load(), throwsA(isA<RecommendationConsentUnavailable>()));
    expect(calls, 1);
  });

  test('account drift after mutation hides its receipt', () async {
    var current = true;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => current,
        read: (_) async => null,
        command: (q) async {
          current = false;
          return consentReceipt(q);
        });
    final state = await repository.load();
    await expectLater(
        repository.change(
            state, RecommendationConsentPurpose.recommendationDelivery,
            granted: false, commandId: 'intent'),
        throwsA(isA<RecommendationConsentUnavailable>()));
  });

  for (final corruption in [
    'legacy',
    'extra',
    'foreign',
    'missing',
    'fraction',
    'sum',
    'partial-grant',
    'inconsistent-time',
    'persisted-zero',
    'future-update',
    'invalid-notice-id'
  ]) {
    test('rejects $corruption server state rather than showing permission',
        () async {
      final raw = consentWire(revision: 1, granted: true);
      final purposes = raw['purposes']! as Map<String, Object?>;
      final insight = purposes['exerciseInsights']! as Map<String, Object?>;
      switch (corruption) {
        case 'legacy':
          raw['schemaVersion'] = 1;
        case 'extra':
          raw['workoutHistory'] = 'private';
        case 'foreign':
          raw['memberId'] = 'someone-else';
        case 'missing':
          purposes.remove('recommendationDelivery');
        case 'fraction':
          raw['revision'] = 1.5;
        case 'sum':
          raw['revision'] = 2;
        case 'partial-grant':
          insight['noticeVersion'] = null;
        case 'inconsistent-time':
          insight['historyStartAtMillis'] = 1500;
        case 'persisted-zero':
          raw.addAll(consentWire());
        case 'future-update':
          raw['updatedAtMillis'] = 9007199254740991;
        case 'invalid-notice-id':
          insight['noticePolicyId'] = 'contains:colon';
      }
      final repository = RpcRecommendationConsentRepository(
          scope: consentScope,
          isCurrent: () => true,
          read: (_) async => raw,
          command: (_) async => throw StateError('must not write'));
      await expectLater(repository.load(), throwsFormatException);
    });
  }

  test('missing notice and invalid command ID never dispatch a grant',
      () async {
    var writes = 0;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async => null,
        command: (q) async {
          writes++;
          return consentReceipt(q);
        });
    final state = await repository.load();
    await expectLater(
        repository.change(state, RecommendationConsentPurpose.exerciseInsights,
            granted: true, commandId: 'grant'),
        throwsFormatException);
    await expectLater(
        repository.change(state, RecommendationConsentPurpose.exerciseInsights,
            granted: true, commandId: '../bad', notice: consentNotice),
        throwsFormatException);
    await expectLater(
        repository.change(state, RecommendationConsentPurpose.exerciseInsights,
            granted: true,
            commandId: 'not:server-valid',
            notice: consentNotice),
        throwsFormatException);
    expect(writes, 0);
  });

  for (final corruption in [
    'schema',
    'purpose',
    'revision',
    'grant',
    'private'
  ]) {
    test('rejects mismatched $corruption mutation receipt', () async {
      final repository = RpcRecommendationConsentRepository(
          scope: consentScope,
          isCurrent: () => true,
          read: (_) async => null,
          command: (q) async {
            final raw = consentReceipt(q);
            switch (corruption) {
              case 'schema':
                raw['schemaVersion'] = 1;
              case 'purpose':
                raw['purpose'] = 'exerciseInsights';
              case 'revision':
                raw['revision'] = 8;
              case 'grant':
                raw['granted'] = true;
              case 'private':
                raw['rawPrompt'] = 'private';
            }
            return raw;
          });
      await expectLater(
          repository.change(await repository.load(),
              RecommendationConsentPurpose.recommendationDelivery,
              granted: false, commandId: 'revoke'),
          throwsFormatException);
    });
  }
}
