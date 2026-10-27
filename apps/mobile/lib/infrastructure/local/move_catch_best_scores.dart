import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/gamification/domain/move_catch_ports.dart';

class LocalMoveCatchBestScores implements MoveCatchBestScoreStore {
  LocalMoveCatchBestScores({Future<Directory> Function()? directory})
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
      throw ArgumentError('Game account required.');
    }
    final key = sha256
            .convert(
                utf8.encode(jsonEncode([scope.organizationId, scope.userId])))
            .toString(),
        dir = await _directory();
    return File('${dir.path}/move_catch_v1_$key.json');
  }

  Future<int> _read(File file, SessionScope scope) async {
    if (!await file.exists()) return 0;
    final d = jsonDecode(await file.readAsString());
    if (d is! Map ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        d['gameVersion'] != 'move-catch-v1' ||
        d['bestScore'] is! int ||
        d['bestScore'] < 0 ||
        d['bestScore'] > 1000000) {
      throw const FormatException('Local personal best is unreadable.');
    }
    return d['bestScore'] as int;
  }

  @override
  Future<int> load(SessionScope scope) =>
      _serial(() async => _read(await _file(scope), scope));
  @override
  Future<int> record(SessionScope scope, int score,
          {required bool Function() isCurrent}) =>
      _serial(() async {
        if (!isCurrent()) throw StateError('Game account changed.');
        if (score < 0 || score > 1000000) {
          throw ArgumentError('Invalid game score.');
        }
        final file = await _file(scope), previous = await _read(file, scope);
        if (!isCurrent()) throw StateError('Game account changed.');
        final best = score > previous ? score : previous;
        await file.parent.create(recursive: true);
        final staging = File('${file.path}.pending');
        await staging.writeAsString(
            jsonEncode({
              'schemaVersion': 1,
              'organizationId': scope.organizationId,
              'memberId': scope.userId,
              'gameVersion': 'move-catch-v1',
              'bestScore': best
            }),
            flush: true);
        if (!isCurrent()) {
          if (await staging.exists()) await staging.delete();
          throw StateError('Game account changed.');
        }
        await staging.rename(file.path);
        return best;
      });
}
