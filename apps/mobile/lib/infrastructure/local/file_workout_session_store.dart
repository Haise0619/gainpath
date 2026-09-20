import 'dart:convert';
import 'dart:io';

import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_contracts.dart';

/// App-private durable outbox. Composition supplies the application support
/// directory; never use a temporary directory for real sessions.
class FileWorkoutSessionStore implements WorkoutSessionStore {
  FileWorkoutSessionStore({required Directory directory, required this.scope})
      : _directory = Directory('${directory.absolute.path}/workouts-v2/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}');

  // Lowercase hex remains injective on case-insensitive filesystems. Chunking
  // supports long provider IDs without exceeding a filename component limit.
  static String _segment(String id) {
    final hex = utf8
        .encode(id)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${[
      for (var start = 0; start < hex.length; start += 100)
        hex.substring(
            start, start + 100 > hex.length ? hex.length : start + 100)
    ].join('/')}/id';
  }

  static final Map<String, Future<void>> _queues = {};
  final Directory _directory;
  @override
  final SessionScope scope;
  File get _file => File('${_directory.path}/records.json');

  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    await _directory.create(recursive: true);
    final key = await _directory.resolveSymbolicLinks();
    final previous = _queues[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      final lock = await File('$key/records.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await action();
      } finally {
        await lock.close();
      }
    });
    final tail =
        result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    _queues[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_queues[key], tail)) _queues.remove(key);
    }
  }

  @override
  Future<List<WorkoutSessionRecord>> read() async {
    if (!await _file.exists()) return const [];
    final json = jsonDecode(await _file.readAsString());
    if (json is! List) throw const FormatException('Invalid workout outbox.');
    final records = json
        .map((item) => WorkoutSessionRecord.fromJson(
            Map<String, Object?>.from(item as Map)))
        .toList();
    _validate(records);
    return List.unmodifiable(records);
  }

  void _validate(List<WorkoutSessionRecord> records) {
    if (records.any((record) => record.summary.scope != scope)) {
      throw StateError('Stored workout account mismatch.');
    }
  }

  @override
  Future<void> write(List<WorkoutSessionRecord> records) async {
    _validate(records);
    await _directory.create(recursive: true);
    final pending = File('${_file.path}.pending');
    await pending.writeAsString(
        jsonEncode(records.map((record) => record.toJson()).toList()),
        flush: true);
    // Atomic replace leaves either the previous complete snapshot or the new
    // complete snapshot after process interruption. Orphan .pending is ignored.
    await pending.rename(_file.path);
  }
}
