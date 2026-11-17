import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';

import '../../features/gamification/domain/member_achievements.dart';

/// Display-only data scoped to the signed-in Member and organization.
class MemberAchievementsCache {
  const MemberAchievementsCache(this.scope);

  final SessionScope scope;

  Future<File> _file() async {
    final key = sha256
        .convert(utf8.encode(jsonEncode([scope.organizationId, scope.userId])));
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/member_achievements_v1_$key.json');
  }

  Future<MemberAchievements?> read() async {
    try {
      final file = await _file();
      if (!await file.exists() || await file.length() > 65536) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map ||
          raw['organizationId'] != scope.organizationId ||
          raw['memberId'] != scope.userId) {
        return null;
      }
      return MemberAchievements.fromJson(raw['collection']);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
      MemberAchievements collection, bool Function() current) async {
    final file = await _file();
    if (!current()) return;
    final staged = await file.parent.createTemp('.achievements-');
    final pending = File('${staged.path}/collection.json');
    try {
      await pending.writeAsString(
          jsonEncode({
            'organizationId': scope.organizationId,
            'memberId': scope.userId,
            'collection': collection.toJson(),
          }),
          flush: true);
      if (current()) await pending.rename(file.path);
    } finally {
      if (await pending.exists()) await pending.delete();
      await staged.delete();
    }
  }
}
