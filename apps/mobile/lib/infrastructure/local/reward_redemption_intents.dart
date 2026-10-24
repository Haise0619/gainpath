import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';

/// Private retry references only; all reward authority remains on the server.
class RewardRedemptionIntents {
  RewardRedemptionIntents(this.scope, {Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final SessionScope scope;
  final Future<Directory> Function() _directory;
  // Serialize file access across repository instances in this application isolate.
  static Future<void> _pending = Future<void>.value();
  static final _identifier = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<File> _file(String itemId) async {
    if (!_identifier.hasMatch(itemId)) {
      throw const FormatException('Invalid reward item.');
    }
    String hex(String value) => utf8
        .encode(value)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final directory = await _directory();
    return File(
        '${directory.path}/reward_intents/${hex(scope.organizationId)}/${hex(scope.userId)}/${hex(itemId)}.json');
  }

  Future<String?> _read(File file, String itemId) async {
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString());
    if (data is! Map ||
        data['schemaVersion'] != 1 ||
        data['organizationId'] != scope.organizationId ||
        data['memberId'] != scope.userId ||
        data['itemId'] != itemId ||
        data['requestId'] is! String ||
        !_identifier.hasMatch(data['requestId'] as String)) {
      throw const FormatException('Invalid reward retry reference.');
    }
    return data['requestId'] as String;
  }

  Future<String> reserve(String itemId, String requestId) => _serial(() async {
        if (!_identifier.hasMatch(requestId)) {
          throw const FormatException('Invalid reward request.');
        }
        final file = await _file(itemId);
        final existing = await _read(file, itemId);
        if (existing != null) return existing;
        await file.parent.create(recursive: true);
        // A partial write fails closed on the next attempt instead of risking a new debit.
        await file.writeAsString(
            jsonEncode({
              'schemaVersion': 1,
              'organizationId': scope.organizationId,
              'memberId': scope.userId,
              'itemId': itemId,
              'requestId': requestId,
            }),
            flush: true);
        return requestId;
      });

  Future<void> complete(String itemId, String requestId) => _serial(() async {
        final file = await _file(itemId);
        if (await _read(file, itemId) == requestId) await file.delete();
      });
}
