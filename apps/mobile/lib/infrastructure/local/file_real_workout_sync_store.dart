import 'dart:convert';
import 'dart:io';

import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/real_workout_sync.dart';

/// Account-scoped sync metadata in the app-private support directory.
/// Call [exclusive] around a whole read/modify/write transaction. Read and write
/// do not acquire it again, so the caller can keep that transaction atomic.
class FileRealWorkoutSyncStore implements RealWorkoutSyncStore {
  FileRealWorkoutSyncStore({required Directory directory, required this.scope})
      : _directory =
            Directory('${directory.absolute.path}/real-workout-sync-v1/'
                '${_segment(scope.organizationId)}/${_segment(scope.userId)}');

  static const _maximumSnapshotBytes = 8 * 1024 * 1024;
  static final Map<String, Future<void>> _queues = {};

  // UTF-8 hex preserves case distinctions on case-insensitive filesystems.
  // An explicit terminator separates IDs even when they span several chunks.
  static String _segment(String value) {
    final hex = utf8
        .encode(value)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${[
      for (var offset = 0; offset < hex.length; offset += 100)
        hex.substring(
            offset, offset + 100 > hex.length ? hex.length : offset + 100),
    ].join('/')}/id';
  }

  final Directory _directory;
  @override
  final SessionScope scope;
  File get _file => File('${_directory.path}/state.json');

  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    await _directory.create(recursive: true);
    final key = await _directory.resolveSymbolicLinks();
    final previous = _queues[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      final lock = await File('$key/state.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await action();
      } finally {
        await lock.close();
      }
    });
    // A failed transaction must not poison later callers on this path.
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
  Future<RealWorkoutSyncState> read() async {
    if (!await _file.exists()) return RealWorkoutSyncState();
    final handle = await _file.open();
    try {
      final length = await handle.length();
      if (length > _maximumSnapshotBytes) {
        throw const FormatException('Workout sync snapshot is too large.');
      }
      // Bound allocation even if another writer changes the file in place.
      final bytes = await handle.read(length + 1);
      if (bytes.length != length) {
        throw const FormatException(
            'Workout sync snapshot changed during read.');
      }
      final state = _parse(jsonDecode(utf8.decode(bytes)));
      state.validateScope(scope);
      return state;
    } finally {
      await handle.close();
    }
  }

  static RealWorkoutSyncState _parse(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid workout sync snapshot.');
    }
    try {
      return RealWorkoutSyncState.fromJson(value);
    } on TypeError {
      throw const FormatException('Invalid workout sync snapshot value.');
    } on ArgumentError {
      throw const FormatException('Invalid workout sync snapshot value.');
    }
  }

  @override
  Future<void> write(RealWorkoutSyncState state) async {
    state.validateScope(scope);
    final validated = _parse(state.toJson());
    validated.validateScope(scope);
    final bytes = utf8.encode(jsonEncode(validated.toJson()));
    if (bytes.length > _maximumSnapshotBytes) {
      throw const FormatException('Workout sync snapshot is too large.');
    }
    await _directory.create(recursive: true);
    final pending = File('${_file.path}.pending');
    await pending.writeAsBytes(bytes, flush: true);
    // Readers see one complete snapshot. A crash before rename leaves the old
    // snapshot intact; an orphan pending file is deliberately never promoted.
    await pending.rename(_file.path);
  }
}
