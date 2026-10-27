import 'dart:convert';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_backup.dart';

class FileWorkoutBackupStore implements WorkoutBackupStore {
  FileWorkoutBackupStore({required Directory directory, required this.scope})
      : _directory = Directory(
            '${directory.absolute.path}/workout-backup-v1/${_segment(scope.organizationId)}/${_segment(scope.userId)}');
  @override
  final SessionScope scope;
  final Directory _directory;
  static final _queues = <String, Future<void>>{};
  static String _segment(String value) {
    final hex = utf8
        .encode(value)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${[
      for (var i = 0; i < hex.length; i += 100)
        hex.substring(i, i + 100 > hex.length ? hex.length : i + 100)
    ].join('/')}/id';
  }

  Future<T> _lock<T>(Future<T> Function() action) async {
    await _directory.create(recursive: true);
    final path = await _directory.resolveSymbolicLinks();
    final future = (_queues[path] ?? Future<void>.value()).then((_) async {
      final lock = await File('$path/state.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await action();
      } finally {
        await lock.close();
      }
    });
    final tail =
        future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _queues[path] = tail;
    try {
      return await future;
    } finally {
      if (identical(_queues[path], tail)) _queues.remove(path);
    }
  }

  @override
  Future<BackupState> read() => _lock(() async {
        final file = File('${_directory.path}/state.json');
        if (!await file.exists()) return BackupState();
        if (await file.length() > 8 * 1024 * 1024) {
          throw const FormatException('Backup metadata too large');
        }
        final raw =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (raw['organizationId'] != scope.organizationId ||
            raw['userId'] != scope.userId) {
          throw StateError('Backup metadata account mismatch');
        }
        return BackupState.fromJson(
            Map<String, dynamic>.from(raw['state'] as Map));
      });
  @override
  Future<void> write(BackupState state) => _lock(() async {
        final validated =
            BackupState.fromJson(Map<String, dynamic>.from(state.toJson()));
        final bytes = utf8.encode(jsonEncode({
          'organizationId': scope.organizationId,
          'userId': scope.userId,
          'state': validated.toJson()
        }));
        if (bytes.length > 8 * 1024 * 1024) {
          throw const FormatException('Backup metadata too large');
        }
        final file = File('${_directory.path}/state.json.pending');
        await file.writeAsBytes(bytes, flush: true);
        await file.rename('${_directory.path}/state.json');
      });
}
