import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_function_transport.dart';

typedef UnifiedAdminInvoke = Future<Object?> Function(Map<String, Object?>);

/// Canonical session stays canonical. Every scope decision is repeated server-side.
class UnifiedAdminTransport implements ScopedCommandTransport {
  UnifiedAdminTransport({required this.scope, required bool Function() isCurrent,
    UnifiedAdminInvoke? invoke, String? Function()? currentUid}) : _current = isCurrent,
    _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
    _invoke = invoke ?? ((data) async => (await firebaseCallable('fypDatasetCommand',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120))).call<Object?>(data)).data);
  @override
  final SessionScope scope;
  final bool Function() _current;
  final String? Function() _uid;
  final UnifiedAdminInvoke _invoke;
  @override
  bool get isCurrent {
    try { return scope.datasetScope == null && _current() && _uid() == scope.userId; }
    catch (_) { return false; }
  }
  void _check() { if (!isCurrent) throw StateError('Your Admin session changed.'); }
  Future<Map<String, Object?>> read(String action, Map<String, Object?> data) async {
    _check();
    if (!const {'directory','member','coach','programs','report','workouts','business','cohort'}.contains(action) ||
      data.keys.any(const {'rootPath','datasetId','role','cohortId','projectId'}.contains)) {
      throw StateError('Unsupported Admin read.');
    }
    final response = await _invoke({'schemaVersion': 1, 'operation': 'admin.unified.$action',
      'data': {'schemaVersion': 1, 'organizationId': scope.organizationId, ...data}});
    _check();
    if (response is! Map || response.keys.any((k) => k is! String)) throw const FormatException('Invalid unified Admin response.');
    return Map<String,Object?>.from(response);
  }
  @override
  Future<Object?> call(String operation, Map<String, Object?> data) async {
    if (!const {'admin.insights','admin.configuration.get','admin.configuration.choices',
      'admin.queue.list','admin.queue.detail','admin.queue.status'}.contains(operation)) {
      throw StateError('This integration provides read-only recommendations.');
    }
    return read('cohort', {'operation':operation,'input':data});
  }
  @override
  Future<Map<String,Object?>> map(String operation,Map<String,Object?> data) async =>
      Map<String,Object?>.from(await call(operation,data) as Map);
}
