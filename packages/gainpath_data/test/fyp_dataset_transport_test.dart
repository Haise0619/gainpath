import 'package:test/test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

void main() {
  final response = <String, Object?>{
    'schemaVersion': 1,
    'organizationId': 'gainpath',
    'datasetId': 'fyp-v1',
    'seedId': 'gainpath-fyp-v1',
    'rootPath': 'orgs/gainpath/cohorts/fyp-v1',
    'revision': 1,
    'fictional': true,
    'role': 'member',
    'branchIds': ['main'],
    'user': {'organizationId': 'gainpath'},
    'member': {
      'organizationId': 'gainpath',
      'role': 'member',
      'status': 'active',
      'branchIds': ['main']
    }
  };
  test(
      'canonical sessions keep exact canonical paths and differ from scoped identity',
      () {
    final canonical = SessionScope(userId: 'm', organizationId: 'gainpath');
    final scoped = SessionScope(
        userId: 'm',
        organizationId: 'gainpath',
        datasetScope: FypDatasetSession.fromResponse(response).scope);
    expect(canonical.dataRootPath, 'orgs/gainpath');
    expect(canonical.userDocumentPath, 'users/m');
    expect(scoped.dataRootPath, 'orgs/gainpath/cohorts/fyp-v1');
    expect(scoped.userDocumentPath, 'orgs/gainpath/cohorts/fyp-v1/users/m');
    expect(scoped, isNot(canonical));
  });
  test(
      'protected session rejects mismatched path provenance role or assignment',
      () {
    for (final patch in <Map<String, Object?>>[
      {'rootPath': 'orgs/gainpath'},
      {'fictional': false},
      {'datasetId': 'other'},
      {'role': 'admin'},
      {
        'branchIds': ['other']
      },
      {'revision': 0},
    ]) {
      expect(() => FypDatasetSession.fromResponse({...response, ...patch}),
          throwsA(isA<AuthException>()));
    }
  });
  test(
      'dataset transport envelopes operations without client dataset selection',
      () async {
    final scope = SessionScope(
        userId: 'm',
        organizationId: 'gainpath',
        datasetScope: FypDatasetSession.fromResponse(response).scope);
    var calls = 0;
    final transport = FypDatasetTransport(
        scope: scope,
        isCurrent: () => true,
        invoke: (name, input) async {
          calls++;
          expect(name, 'fypDatasetCommand');
          expect(input, {
            'schemaVersion': 1,
            'operation': 'member.history',
            'data': {'organizationId': 'gainpath'}
          });
          return {'records': []};
        });
    await transport.map('member.history', {'organizationId': 'gainpath'});
    for (final key in ['datasetId', 'cohortId', 'demoMode', 'rootPath']) {
      await expectLater(
          transport.call(
              'member.history', {'organizationId': 'gainpath', key: 'fyp-v1'}),
          throwsA(isA<AuthException>()));
    }
    expect(calls, 1);
  });
  test('session invalidation discards in-flight result', () async {
    var current = true;
    final scope = SessionScope(
        userId: 'm',
        organizationId: 'gainpath',
        datasetScope: FypDatasetSession.fromResponse(response).scope);
    final transport = FypDatasetTransport(
        scope: scope,
        isCurrent: () => current,
        invoke: (name, input) async {
          current = false;
          return {};
        });
    await expectLater(
        transport.map('member.history', {}), throwsA(isA<AuthException>()));
  });
}
