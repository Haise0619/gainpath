import 'package:flutter/services.dart';

class AndroidCoachStatementExporter {
  const AndroidCoachStatementExporter();
  Future<bool> save(List<String> lines) async =>
      await const MethodChannel('gainpath/coach_statement')
          .invokeMethod<bool>('save', lines) ??
      false;
}
