import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../infrastructure/firebase/firebase_function_transport.dart';

typedef AdminAiInvoke = Future<Object?> Function(
    String operation, Map<String, Object?> data);
Map<String, dynamic> aiMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : throw const FormatException('Invalid AI response.');
String aiRequestId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

class AdminAiRepository {
  AdminAiRepository(
      {required this.organizationId,
      required bool Function() isCurrent,
      AdminAiInvoke? invoke})
      : _current = isCurrent,
        _invoke = invoke ??
            ((operation, data) async => (await firebaseCallable(
                            'module13AdminCommand',
                            options: HttpsCallableOptions(
                                timeout: const Duration(seconds: 60)))
                        .call<Object?>({
                  'schemaVersion': 1,
                  'operation': operation,
                  'data': data,
                }))
                    .data);
  final String organizationId;
  final bool Function() _current;
  final AdminAiInvoke _invoke;
  bool get current => _current();
  Future<Map<String, dynamic>> call(
      String operation, Map<String, Object?> input) async {
    if (!current) throw StateError('Your Admin session changed.');
    final result = aiMap(await _invoke(operation,
        {'schemaVersion': 1, 'organizationId': organizationId, ...input}));
    if (!current) throw StateError('Your Admin session changed.');
    return result;
  }
}
