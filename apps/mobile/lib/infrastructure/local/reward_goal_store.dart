import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/gamification/domain/reward_goal.dart';

class LocalRewardGoalStore implements RewardGoalStore {
  LocalRewardGoalStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  static Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<File> _file(SessionScope scope) async {
    if (scope.organizationId.isEmpty || scope.userId.isEmpty) {
      throw ArgumentError('Reward goal account required.');
    }
    final key = sha256
        .convert(utf8.encode(jsonEncode([scope.organizationId, scope.userId])));
    final dir = await _directory();
    return File('${dir.path}/reward_goal_v1_$key.json');
  }

  @override
  Future<String?> load(SessionScope scope) => _serial(() async {
        final file = await _file(scope);
        if (!await file.exists()) return null;
        final data = jsonDecode(await file.readAsString());
        if (data is! Map ||
            data['schemaVersion'] != 1 ||
            data['organizationId'] != scope.organizationId ||
            data['memberId'] != scope.userId ||
            (data['itemId'] != null &&
                (data['itemId'] is! String ||
                    !RegExp(r'^[A-Za-z0-9_-]{1,128}$')
                        .hasMatch(data['itemId'] as String)))) {
          throw const FormatException('Reward goal unavailable.');
        }
        return data['itemId'] as String?;
      });
  @override
  Future<void> save(SessionScope scope, String? itemId,
          {required bool Function() isCurrent}) =>
      _serial(() async {
        if (!isCurrent()) throw StateError('Reward account changed.');
        if (itemId != null &&
            !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(itemId)) {
          throw ArgumentError('Invalid reward goal.');
        }
        final file = await _file(scope);
        if (!isCurrent()) throw StateError('Reward account changed.');
        await file.parent.create(recursive: true);
        final staging = File('${file.path}.pending');
        await staging.writeAsString(
            jsonEncode({
              'schemaVersion': 1,
              'organizationId': scope.organizationId,
              'memberId': scope.userId,
              'itemId': itemId
            }),
            flush: true);
        if (!isCurrent()) {
          if (await staging.exists()) await staging.delete();
          throw StateError('Reward account changed.');
        }
        await staging.rename(file.path);
      });
}
