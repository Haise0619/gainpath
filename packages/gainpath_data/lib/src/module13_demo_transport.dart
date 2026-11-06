import 'dart:convert';
import 'fyp_dataset_transport.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class Module13DemoUnavailable implements Exception {
  const Module13DemoUnavailable();
}

/// Explicit client binding, never a server processing permission. The server
/// independently checks the current manifest, Auth, App Check and record owners.
class Module13DemoBinding {
  const Module13DemoBinding(
      {required this.projectId,
      required this.databaseId,
      required this.emulator});
  final String projectId, databaseId;
  final bool emulator;
  bool get isValid =>
      databaseId == 'module13-demo' &&
      projectId == (emulator ? 'demo-gainpath-module13-demo' : 'gainpath-0619');
}

typedef Module13DemoInvoke = Future<Object?> Function(
    String callable, Map<String, Object?> request);

/// Shared session-scoped callable protocol. No SDK, credentials, fixtures,
/// default data, URL gateway or automatic retry is embedded in this adapter.
class Module13DemoTransport implements ScopedCommandTransport {
  Module13DemoTransport(
      {required this.scope,
      required this.role,
      required bool Function() isCurrent,
      required String? Function() currentUid,
      required bool Function() emailVerified,
      required Future<bool> Function() appCheckReady,
      required Module13DemoInvoke invoke})
      : _current = isCurrent,
        _uid = currentUid,
        _verified = emailVerified,
        _appCheck = appCheckReady,
        _invoke = invoke;
  @override
  final SessionScope scope;
  final AppRole role;
  final bool Function() _current, _verified;
  final String? Function() _uid;
  final Future<bool> Function() _appCheck;
  final Module13DemoInvoke _invoke;
  @override
  bool get isCurrent => _current() && _uid() == scope.userId && _verified();
  static const _admin = {
    'admin.insights',
    'admin.configuration.get',
    'admin.configuration.save',
    'admin.configuration.choices',
    'admin.queue.refresh',
    'admin.queue.list',
    'admin.queue.detail',
    'admin.queue.decide',
    'admin.queue.status'
  };
  static const _member = {
    'member.consent.get',
    'member.consent.set',
    'member.consent.notice',
    'member.recommendation.command',
    'member.inbox',
    'member.coach',
    'member.routine',
    'member.workoutHistory'
  };
  void _check() {
    if (!isCurrent ||
        scope.organizationId != 'gainpath' ||
        !{AppRole.admin, AppRole.member}.contains(role)) {
      throw const Module13DemoUnavailable();
    }
  }

  @override
  Future<Object?> call(String operation, Map<String, Object?> data) async {
    _check();
    final allowed = operation == 'session.access' ||
        (role == AppRole.admin &&
            (_admin.contains(operation) || operation == 'delivery.process')) ||
        (role == AppRole.member && _member.contains(operation));
    if (!allowed ||
        data['organizationId'] != scope.organizationId ||
        [
          'demoMode',
          'mode',
          'fixtureSetId',
          'enabled',
          'localFixture',
          'localDelivery',
          'capability'
        ].any(data.containsKey)) {
      throw const Module13DemoUnavailable();
    }
    final request = <String, Object?>{
      'schemaVersion': 1,
      'operation': operation,
      'data': Map<String, Object?>.unmodifiable(data)
    };
    try {
      if (utf8.encode(jsonEncode(request)).length > 16384) {
        throw const Module13DemoUnavailable();
      }
      if (!await _appCheck()) {
        throw const Module13DemoUnavailable();
      }
      _check();
      final name = operation == 'delivery.process'
          ? 'module13DemoDeliveryCommand'
          : role == AppRole.admin
              ? 'module13DemoAdminCommand'
              : 'module13DemoMemberCommand';
      final response = await _invoke(name, request);
      _check();
      if (utf8.encode(jsonEncode(response)).length > 262144) {
        throw const Module13DemoUnavailable();
      }
      return response;
    } catch (_) {
      // Provider messages can contain document paths or account identifiers.
      throw const Module13DemoUnavailable();
    }
  }

  @override
  Future<Map<String, Object?>> map(
      String operation, Map<String, Object?> data) async {
    final raw = await call(operation, data);
    if (raw is! Map || raw.keys.any((k) => k is! String)) {
      throw const Module13DemoUnavailable();
    }
    return Map<String, Object?>.from(raw);
  }
}
