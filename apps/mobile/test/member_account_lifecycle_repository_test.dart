import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_account_lifecycle_repository.dart';

Map<String, dynamic> snapshot(
        {bool pending = false, int revision = 0, String? requestId}) =>
    {
      'schemaVersion': 1,
      'state': pending ? 'pendingDeletion' : 'active',
      'revision': revision,
      'requestedAtMillis': pending ? 1000000 : null,
      'retentionEndsAtMillis': pending ? 1000000 + 30 * 86400000 : null,
      'policy': pending ? 'grace30Days' : 'pendingApproval',
      'sessionNotBeforeSeconds': pending ? 1001 : 0,
      'sessionRevocationPending': false,
      'reactivationAllowed': pending,
      'reactivationAvailableAtMillis': pending ? 1090000 : null,
      'currentTimeMillis': 1200000,
      'lastRequestId': requestId,
    };
FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
    mode: 'debug',
    release: false,
    supported: true,
    activate: (_) async {},
    token: () async => 'isolated-test-token');
void main() {
  test(
      'decoder accepts pending cleanup without a promised restoration time and rejects unsafe allowed state',
      () {
    final value =
        snapshot(pending: true, revision: 1, requestId: 'request_0001')
          ..['reactivationAvailableAtMillis'] = null
          ..['sessionRevocationPending'] = true
          ..['reactivationAllowed'] = false;
    expect(
        MemberAccountLifecycle.fromJson(value, editBaseline: Object())
            .reactivationAvailableAtMillis,
        isNull);
    value['reactivationAllowed'] = true;
    expect(() => MemberAccountLifecycle.fromJson(value, editBaseline: Object()),
        throwsFormatException);
  });
  test(
      'ambiguous request reconciles through server get and keeps one command id',
      () async {
    final calls = <Map<String, dynamic>>[];
    var pending = false;
    String? id;
    final repo = FirebaseMemberAccountLifecycleRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => true,
        currentUid: () => 'm',
        readiness: ready(),
        verifyCurrentPassword: (_) async {},
        call: (name, data) async {
          if (name == 'requestMemberDeactivationCommand') {
            calls.add(data);
            pending = true;
            id = data['requestId'] as String;
            throw Exception('response lost');
          }
          return snapshot(
              pending: pending, revision: pending ? 1 : 0, requestId: id);
        });
    final before = await repo.load();
    final after = await repo.requestDeactivation(before);
    expect(after.isPendingDeletion, isTrue);
    expect(after.revision, 1);
    expect(calls, hasLength(1));
    expect(calls.single.keys,
        unorderedEquals(['schemaVersion', 'requestId', 'expectedRevision']));
  });
  test(
      'unconfirmed retry reuses the original id and revision instead of double-transitioning',
      () async {
    final commands = <Map<String, dynamic>>[];
    var fail = false;
    final repo = FirebaseMemberAccountLifecycleRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => true,
        currentUid: () => 'm',
        readiness: ready(),
        verifyCurrentPassword: (_) async {},
        call: (name, data) async {
          if (name == 'requestMemberDeactivationCommand') {
            commands.add(data);
            throw Exception('network');
          }
          if (fail) throw Exception('network');
          return snapshot();
        });
    final original = await repo.load();
    fail = true;
    for (var i = 0; i < 2; i++) {
      await expectLater(repo.requestDeactivation(original),
          throwsA(isA<MemberAccountLifecycleException>()));
    }
    expect(commands, hasLength(2));
    expect(commands[0], commands[1]);
  });
  test(
      'App Check failure, foreign baseline and session switch prevent remote commands',
      () async {
    var current = true, calls = 0;
    Future<Map<String, dynamic>> call(String _, Map<String, dynamic> __) async {
      calls++;
      return snapshot();
    }

    final repo = FirebaseMemberAccountLifecycleRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => current,
        currentUid: () => 'm',
        readiness: ready(),
        verifyCurrentPassword: (_) async {},
        call: call);
    final baseline = await repo.load();
    final other = FirebaseMemberAccountLifecycleRepository(
        scope: repo.scope,
        isCurrent: () => true,
        currentUid: () => 'm',
        readiness: ready(),
        verifyCurrentPassword: (_) async {},
        call: call);
    await expectLater(other.requestDeactivation(baseline),
        throwsA(isA<MemberAccountLifecycleException>()));
    expect(calls, 1);
    current = false;
    await expectLater(
        repo.load(), throwsA(isA<MemberAccountLifecycleException>()));
    current = true;
    await expectLater(
        repo.load(), throwsA(isA<MemberAccountLifecycleException>()));
    expect(calls, 1);
    final unavailable = FirebaseMemberAccountLifecycleRepository(
        scope: repo.scope,
        isCurrent: () => true,
        currentUid: () => 'm',
        readiness: FirebaseAppCheckReadiness(mode: 'off'),
        verifyCurrentPassword: (_) async {},
        call: call);
    await expectLater(
        unavailable.load(), throwsA(isA<MemberAccountLifecycleException>()));
    expect(calls, 1);
  });
}
