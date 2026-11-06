import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_demo_recommendation.dart';

void main() {
  test(
      'owned history fails closed on foreign payloads, malformed pages and repeated cursors',
      () async {
    for (final raw in [
      {
        'schemaVersion': 1,
        'records': [
          {
            'kind': 'session',
            'payload': {'userId': 'foreign'}
          }
        ],
        'nextCursor': null
      },
      {'schemaVersion': 1, 'records': 'invalid', 'nextCursor': null},
      {'schemaVersion': 1, 'records': [], 'nextCursor': 'routines'},
    ]) {
      var calls = 0;
      final scope =
          SessionScope(userId: 'demo-member', organizationId: 'gainpath');
      final repo = FirebaseDemoMemberRepositories(Module13DemoTransport(
          scope: scope,
          role: AppRole.member,
          isCurrent: () => true,
          currentUid: () => scope.userId,
          emailVerified: () => true,
          appCheckReady: () async => true,
          invoke: (_, __) async {
            calls++;
            return raw;
          }));
      await expectLater(repo.loadWorkoutProgress(), throwsA(anything));
      expect(calls, lessThanOrEqualTo(2));
    }
  });
  test(
      'demo consent absent state remains all off and notice comes from protected server',
      () async {
    final scope =
        SessionScope(userId: 'demo-member', organizationId: 'gainpath');
    final operations = <String>[];
    final transport = Module13DemoTransport(
        scope: scope,
        role: AppRole.member,
        isCurrent: () => true,
        currentUid: () => scope.userId,
        emailVerified: () => true,
        appCheckReady: () async => true,
        invoke: (_, body) async {
          operations.add(body['operation'] as String);
          if (body['operation'] == 'member.consent.get') {
            return null;
          }
          if (body['operation'] == 'member.consent.notice') {
            return {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'policyId': 'reviewed-demo',
              'noticeVersion': 'v1',
              'contentVersion': 'v1',
              'historyDescription': 'Only this explicit fictional dataset.',
              'demoData': true
            };
          }
          throw StateError('Unknown');
        });
    final repo = FirebaseDemoMemberRepositories(transport);
    final state = await repo.consent.load();
    expect(state.revision, 0);
    expect(state.purposes.values.every((p) => !p.granted), true);
    final notice = await repo.notice();
    expect(notice.policyId, 'reviewed-demo');
    expect(operations, ['member.consent.get', 'member.consent.notice']);
  });
  test('foreign or malformed notices are not displayed as approved', () async {
    final scope =
        SessionScope(userId: 'demo-member', organizationId: 'gainpath');
    final repo = FirebaseDemoMemberRepositories(Module13DemoTransport(
        scope: scope,
        role: AppRole.member,
        isCurrent: () => true,
        currentUid: () => scope.userId,
        emailVerified: () => true,
        appCheckReady: () async => true,
        invoke: (_, __) async => {
              'schemaVersion': 1,
              'organizationId': 'foreign',
              'demoData': true
            }));
    await expectLater(repo.notice(), throwsA(anything));
  });
}
