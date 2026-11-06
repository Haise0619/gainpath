import 'package:gainpath_data/src/module13_demo_transport.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

void main() {
  final scope = SessionScope(userId: 'demo-member', organizationId: 'gainpath');
  test('selects protected grouped callable and keeps exact leaf payload',
      () async {
    final calls = <Map<String, Object?>>[];
    final rpc = Module13DemoTransport(
      scope: scope,
      role: AppRole.member,
      isCurrent: () => true,
      currentUid: () => scope.userId,
      emailVerified: () => true,
      appCheckReady: () async => true,
      invoke: (name, data) async {
        calls.add({'name': name, ...data});
        return {'state': 'available'};
      },
    );
    expect(
        await rpc.call(
            'member.inbox', {'schemaVersion': 1, 'organizationId': 'gainpath'}),
        {'state': 'available'});
    expect(calls.single, {
      'name': 'module13DemoMemberCommand',
      'schemaVersion': 1,
      'operation': 'member.inbox',
      'data': {'schemaVersion': 1, 'organizationId': 'gainpath'}
    });
  });
  test('current verified identity and App Check gate precede any callable',
      () async {
    var calls = 0;
    for (final failure in [
      'session',
      'identity',
      'verified',
      'appcheck',
      'scope',
      'role'
    ]) {
      final rpc = Module13DemoTransport(
          scope: scope,
          role: AppRole.member,
          isCurrent: () => failure != 'session',
          currentUid: () => failure == 'identity' ? 'other' : scope.userId,
          emailVerified: () => failure != 'verified',
          appCheckReady: () async => failure != 'appcheck',
          invoke: (_, __) async {
            calls++;
            return null;
          });
      await expectLater(
          rpc.call(failure == 'role' ? 'admin.insights' : 'member.inbox', {
            'schemaVersion': 1,
            'organizationId': failure == 'scope' ? 'other' : 'gainpath'
          }),
          throwsA(isA<Module13DemoUnavailable>()));
    }
    expect(calls, 0);
  });
  test('account drift during App Check or response never returns data',
      () async {
    for (final phase in ['appcheck', 'response']) {
      var current = true, calls = 0;
      final rpc = Module13DemoTransport(
          scope: scope,
          role: AppRole.member,
          isCurrent: () => current,
          currentUid: () => scope.userId,
          emailVerified: () => true,
          appCheckReady: () async {
            if (phase == 'appcheck') {
              current = false;
            }
            return true;
          },
          invoke: (_, __) async {
            calls++;
            current = false;
            return {'private': 'withheld'};
          });
      await expectLater(
          rpc.call('member.inbox',
              {'schemaVersion': 1, 'organizationId': 'gainpath'}),
          throwsA(isA<Module13DemoUnavailable>()));
      expect(calls, phase == 'appcheck' ? 0 : 1);
    }
  });
  test(
      'oversized requests, unknown operations and fixture activation fields refuse',
      () async {
    var calls = 0;
    final rpc = Module13DemoTransport(
        scope: scope,
        role: AppRole.member,
        isCurrent: () => true,
        currentUid: () => scope.userId,
        emailVerified: () => true,
        appCheckReady: () async => true,
        invoke: (_, __) async {
          calls++;
          return null;
        });
    for (final extra in [
      {'demoMode': true},
      {'history': 'x' * 17000}
    ]) {
      await expectLater(
          rpc.call('member.inbox',
              {'schemaVersion': 1, 'organizationId': 'gainpath', ...extra}),
          throwsA(isA<Module13DemoUnavailable>()));
    }
    await expectLater(
        rpc.call('member.unknown',
            {'schemaVersion': 1, 'organizationId': 'gainpath'}),
        throwsA(isA<Module13DemoUnavailable>()));
    expect(calls, 0);
  });
  test(
      'real and emulator bindings are explicit and never accept default database',
      () {
    expect(
        const Module13DemoBinding(
                projectId: 'gainpath-0619',
                databaseId: 'module13-demo',
                emulator: false)
            .isValid,
        true);
    expect(
        const Module13DemoBinding(
                projectId: 'demo-gainpath-module13-demo',
                databaseId: 'module13-demo',
                emulator: true)
            .isValid,
        true);
    expect(
        const Module13DemoBinding(
                projectId: 'gainpath-0619',
                databaseId: '(default)',
                emulator: false)
            .isValid,
        false);
    expect(
        const Module13DemoBinding(
                projectId: 'other',
                databaseId: 'module13-demo',
                emulator: false)
            .isValid,
        false);
  });
}
