import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_demo_recommendation.dart';
import 'support/exercise_insights_fixture.dart';

void main() {
  test('delivery requires an exact current delivered receipt before success',
      () async {
    for (final valid in [true, false]) {
      final repo = FirebaseDemoAdminRepositories(Module13DemoTransport(
          scope: SessionScope(userId: 'demo-admin', organizationId: 'gainpath'),
          role: AppRole.admin,
          isCurrent: () => true,
          currentUid: () => 'demo-admin',
          emailVerified: () => true,
          appCheckReady: () async => true,
          invoke: (_, __) async => {
                'schemaVersion': 1,
                'mode': 'synthetic_local',
                'organizationId': 'gainpath',
                'recommendationId': 'recipient-1',
                'notificationId': 'recommendation-recipient-1',
                'revision': 1,
                'deliveredAtMillis': 1,
                'status': valid ? 'delivered' : 'prepared'
              }));
      if (valid) {
        await repo.deliver('recipient-1');
      } else {
        await expectLater(repo.deliver('recipient-1'), throwsA(anything));
      }
    }
  });
  test(
      'Firebase demo Insights reads typed server choices and saves revision-bound selection',
      () async {
    final requests = <Map<String, Object?>>[];
    final transport = Module13DemoTransport(
        scope: SessionScope(userId: 'demo-admin', organizationId: 'gainpath'),
        role: AppRole.admin,
        isCurrent: () => true,
        currentUid: () => 'demo-admin',
        emailVerified: () => true,
        appCheckReady: () async => true,
        invoke: (name, body) async {
          requests.add(body);
          if (body['operation'] == 'admin.insights') {
            return insightsFixture();
          }
          if (body['operation'] == 'admin.configuration.choices') {
            return {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'revision': 2,
              'selectedPolicyIds': ['reviewed-demo'],
              'availablePolicies': [
                {
                  'policyId': 'reviewed-demo',
                  'title': 'Demo Squat',
                  'definition': 'Explicit synthetic policy.'
                }
              ]
            };
          }
          if (body['operation'] == 'admin.configuration.save') {
            return {'revision': 3};
          }
          throw StateError('Unexpected operation');
        });
    final repo = FirebaseDemoExerciseInsightsRepository(transport);
    expect(await repo.load(insightsQuery), isA<Map>());
    final config = await repo.configuration();
    expect(config.revision, 2);
    expect(config.availablePolicies.single.policyId, 'reviewed-demo');
    expect(await repo.saveConfiguration(2, ['reviewed-demo']), 3);
    final command = requests.last['data'] as Map;
    expect(command['expectedRevision'], 2);
    expect(command['policyIds'], ['reviewed-demo']);
    expect(command['commandId'], isA<String>());
  });
  test('malformed or foreign configuration never becomes an available policy',
      () async {
    for (final bad in [
      {'organizationId': 'foreign'},
      {
        'availablePolicies': [
          {'policyId': 'unknown'}
        ]
      }
    ]) {
      final repo = FirebaseDemoExerciseInsightsRepository(Module13DemoTransport(
          scope: SessionScope(userId: 'demo-admin', organizationId: 'gainpath'),
          role: AppRole.admin,
          isCurrent: () => true,
          currentUid: () => 'demo-admin',
          emailVerified: () => true,
          appCheckReady: () async => true,
          invoke: (_, __) async => {
                'schemaVersion': 1,
                'organizationId': 'gainpath',
                'revision': 0,
                'selectedPolicyIds': [],
                'availablePolicies': [],
                ...bad
              }));
      await expectLater(repo.configuration(), throwsA(anything));
    }
  });
}
