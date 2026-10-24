import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// App-private, identity-scoped display cache. Never used to authorize commerce.
class MembershipCache {
  const MembershipCache(this.scope);
  final SessionScope scope;
  Future<File> _file() async {
    String hex(String value) => utf8
        .encode(value)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final directory = await getApplicationSupportDirectory();
    return File(
        '${directory.path}/membership/${hex(scope.organizationId)}/${hex(scope.userId)}.json');
  }

  Future<void> save(Map<String, dynamic> data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
        jsonEncode(
            {...data, 'cachedAtMillis': DateTime.now().millisecondsSinceEpoch}),
        flush: true);
  }

  Future<Map<String, dynamic>?> read() async {
    try {
      final data = Map<String, dynamic>.from(
          jsonDecode(await (await _file()).readAsString()) as Map);
      if (data['organizationId'] != scope.organizationId ||
          data['memberId'] != scope.userId) { return null; }
      return {...data, 'cached': true};
    } catch (_) {
      return null;
    }
  }
}
