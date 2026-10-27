import 'dart:convert';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/routine_journey.dart';

class FileRoutineJourneyStore implements RevisionedRoutineJourneyStore {
  FileRoutineJourneyStore({required Directory directory, required this.scope})
      : _directory = Directory('${directory.absolute.path}/routine-journeys-v1/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}');
  @override
  final SessionScope scope;
  final Directory _directory;
  static final _queues = <String, Future<void>>{};
  static String _segment(String value) {
    final hex = utf8
        .encode(value)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      for (var i = 0; i < hex.length; i += 100)
        hex.substring(i, i + 100 > hex.length ? hex.length : i + 100)
    ].join('/');
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    await _directory.create(recursive: true);
    final key = await _directory.resolveSymbolicLinks();
    final result = (_queues[key] ?? Future<void>.value()).then((_) async {
      final lock =
          await File('$key/checkpoints.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await action();
      } finally {
        await lock.close();
      }
    });
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _queues[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_queues[key], tail)) _queues.remove(key);
    }
  }

  Future<RoutineCheckpoint> _read(File file) async {
    if (await file.length() > 1024 * 1024) {
      throw const FormatException('Routine checkpoint too large');
    }
    final value = RoutineCheckpoint.fromJson(Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map));
    if (value.scope != scope) {
      throw StateError('Routine checkpoint account mismatch');
    }
    return value;
  }

  @override
  Future<List<RoutineCheckpoint>> load() => _exclusive(() async {
        final result = <RoutineCheckpoint>[];
        await for (final entity in _directory.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            result.add(await _read(entity));
          }
        }
        return result;
      });
  @override
  Future<void> save(RoutineCheckpoint checkpoint) => _save(checkpoint);

  @override
  Future<void> saveRevision(RoutineCheckpoint checkpoint,
          {required int? expectedUpdatedAtMicros}) =>
      _save(checkpoint,
          compareRevision: true,
          expectedUpdatedAtMicros: expectedUpdatedAtMicros);

  Future<void> _save(RoutineCheckpoint checkpoint,
          {bool compareRevision = false, int? expectedUpdatedAtMicros}) =>
      _exclusive(() async {
        // Round-trip validation also bounds filenames before any filesystem write.
        final value = RoutineCheckpoint.fromJson(
            Map<String, dynamic>.from(checkpoint.toJson()));
        if (value.scope != scope) {
          throw StateError('Routine checkpoint account mismatch');
        }
        final file = File('${_directory.path}/checkpoint-${value.id}.json');
        if (await file.exists()) {
          final previous = await _read(file);
          if (compareRevision &&
              previous.updatedAtMicros != expectedUpdatedAtMicros) {
            throw StateError('Routine changed in another view. Reopen it.');
          }
          if (previous.updatedAtMicros > value.updatedAtMicros) {
            throw StateError('Routine changed in another view. Reopen it.');
          }
        } else if (compareRevision && expectedUpdatedAtMicros != null) {
          throw StateError('Routine attempt is no longer available.');
        }
        final pending = File('${file.path}.pending');
        final encoded = jsonEncode(value.toJson());
        if (utf8.encode(encoded).length > 1024 * 1024) {
          throw const FormatException('Routine checkpoint too large');
        }
        await pending.writeAsString(encoded, flush: true);
        await pending.rename(file.path);
      });
}
