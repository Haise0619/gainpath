import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart';

abstract interface class ScopedCommandTransport {
  SessionScope get scope;
  bool get isCurrent;
  Future<Object?> call(String operation, Map<String, Object?> data);
  Future<Map<String, Object?>> map(String operation, Map<String, Object?> data);
}

/// Parses a protected session response, never an assignment document alone.
class FypDatasetSession {
  FypDatasetSession._(this.scope, this.user, this.member);
  final VerifiedDatasetScope scope;
  final Map<String, Object?> user, member;

  factory FypDatasetSession.fromResponse(Object? value) {
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['organizationId'] != 'gainpath' ||
        value['datasetId'] != 'fyp-v1' ||
        value['seedId'] != 'gainpath-fyp-v1' ||
        value['revision'] is! int ||
        (value['revision'] as int) < 1 ||
        value['fictional'] != true ||
        value['rootPath'] != 'orgs/gainpath/cohorts/fyp-v1' ||
        !['admin', 'member', 'coach'].contains(value['role']) ||
        value['user'] is! Map ||
        value['member'] is! Map ||
        value['branchIds'] is! List) {
      throw const AuthException(
          'The fictional dataset session is unavailable.');
    }
    final user = Map<String, Object?>.from(value['user'] as Map);
    final member = Map<String, Object?>.from(value['member'] as Map);
    if (user['organizationId'] != value['organizationId'] ||
        member['organizationId'] != value['organizationId'] ||
        member['role'] != value['role'] ||
        member['status'] != 'active' ||
        jsonEncode(member['branchIds']) != jsonEncode(value['branchIds'])) {
      throw const AuthException(
          'The fictional dataset membership is unavailable.');
    }
    return FypDatasetSession._(
        VerifiedDatasetScope(
            datasetId: value['datasetId'] as String,
            seedId: value['seedId'] as String,
            revision: value['revision'] as int,
            rootPath: value['rootPath'] as String),
        Map.unmodifiable(user),
        Map.unmodifiable(member));
  }
}

/// Ordinary-app transport. The dataset is always derived again on the server;
/// no client-supplied dataset selector enters the request.
class FypDatasetTransport implements ScopedCommandTransport {
  FypDatasetTransport(
      {required this.scope,
      required bool Function() isCurrent,
      required Future<Object?> Function(String, Map<String, Object?>) invoke})
      : _current = isCurrent,
        _invoke = invoke;
  @override
  final SessionScope scope;
  final bool Function() _current;
  final Future<Object?> Function(String, Map<String, Object?>) _invoke;
  @override
  bool get isCurrent => scope.datasetScope != null && _current();
  @override
  Future<Object?> call(String operation, Map<String, Object?> data) async {
    if (!isCurrent ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9./]*$').hasMatch(operation) ||
        ['datasetId', 'cohortId', 'demoMode', 'rootPath']
            .any(data.containsKey) ||
        data['organizationId'] != null &&
            data['organizationId'] != scope.organizationId) {
      throw const AuthException('The dataset request is unavailable.');
    }
    final request = <String, Object?>{
      'schemaVersion': 1,
      'operation': operation,
      'data': Map<String, Object?>.unmodifiable(data)
    };
    if (utf8.encode(jsonEncode(request)).length > 32768) {
      throw const FormatException('Dataset request exceeds its bound.');
    }
    final response = await _invoke('fypDatasetCommand', request);
    if (!isCurrent) {
      throw const AuthException('Your session changed. Sign in again.');
    }
    return response;
  }

  @override
  Future<Map<String, Object?>> map(
      String operation, Map<String, Object?> data) async {
    final response = await call(operation, data);
    if (response is! Map || response.keys.any((k) => k is! String)) {
      throw const FormatException('Invalid dataset response.');
    }
    return Map<String, Object?>.from(response);
  }
}

typedef FypDatasetTransportFactory = ScopedCommandTransport Function(
    SessionScope scope, bool Function() isCurrent);
