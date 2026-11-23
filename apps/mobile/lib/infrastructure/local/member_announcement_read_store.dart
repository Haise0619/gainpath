import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';

/// Read receipts for app announcements, scoped to this device and Member.
class MemberAnnouncementReadStore {
  const MemberAnnouncementReadStore(this.scope,
      {this.directory = getApplicationSupportDirectory});

  final SessionScope scope;
  final Future<Directory> Function() directory;

  Future<File> _file() async {
    final key = sha256
        .convert(utf8.encode(jsonEncode([scope.dataRootPath, scope.userId])));
    return File(
        '${(await directory()).path}/member_announcements_read_$key.json');
  }

  Future<Map<String, int>> read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic>) return {};
    return {
      for (final entry in data.entries)
        if (entry.value is int) entry.key: entry.value as int
    };
  }

  Future<void> save(Map<String, int> read) async {
    final file = await _file();
    final staged = await file.parent.createTemp('.announcement-read-');
    final pending = File('${staged.path}/receipts.json');
    try {
      await pending.writeAsString(jsonEncode(read), flush: true);
      await pending.rename(file.path);
    } finally {
      if (await pending.exists()) await pending.delete();
      await staged.delete();
    }
  }
}
