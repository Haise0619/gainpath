import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_unified_admin.dart';

void main() {
  final scope = SessionScope(userId: 'real-admin', organizationId: 'gainpath');
  test('canonical Admin transport sends fixed unified reads without a dataset assignment', () async {
    final calls = <Map<String, Object?>>[];
    final transport = UnifiedAdminTransport(scope: scope, isCurrent: () => true, currentUid: () => scope.userId,
      invoke: (data) async { calls.add(data); return {'schemaVersion': 1}; });
    expect(await transport.map('admin.queue.list', {'schemaVersion': 1, 'organizationId': 'gainpath'}), {'schemaVersion': 1});
    expect(calls.single['operation'], 'admin.unified.cohort');
    expect((calls.single['data'] as Map)['operation'], 'admin.queue.list');
    expect(scope.datasetScope, isNull);
    for (final operation in ['admin.queue.refresh', 'admin.queue.decide', 'delivery.process', 'member.consent.set']) {
      await expectLater(transport.call(operation, {}), throwsA(isA<StateError>()));
    }
    expect(calls, hasLength(1));
  });
  test('account switches invalidate a pending unified response', () async {
    var current = true;
    final transport = UnifiedAdminTransport(scope: scope, isCurrent: () => current, currentUid: () => scope.userId,
      invoke: (_) async { current = false; return {'schemaVersion': 1}; });
    await expectLater(transport.read('directory', {'kind': 'members'}), throwsA(isA<StateError>()));
  });
  test('a current auth UID mismatch closes an otherwise retained Admin UI session',()async{
    var uid='real-admin',calls=0;
    final transport=UnifiedAdminTransport(scope:scope,isCurrent:()=>true,currentUid:()=>uid,invoke:(_)async{calls++;uid='different-account';return {'schemaVersion':1};});
    await expectLater(transport.read('directory',{'kind':'members'}),throwsA(isA<StateError>()));
    await expectLater(transport.read('directory',{'kind':'members'}),throwsA(isA<StateError>()));expect(calls,1);
  });
}
