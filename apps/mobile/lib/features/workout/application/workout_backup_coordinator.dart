import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/workout_backup.dart';

class WorkoutBackupCoordinator extends ChangeNotifier {
  WorkoutBackupCoordinator(
      {required this.scope,
      required this.activeScope,
      required this.local,
      required this.gateway,
      required this.store}) {
    if (store.scope != scope) throw ArgumentError('Backup scope mismatch');
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutBackupLocal local;
  final WorkoutBackupGateway gateway;
  final WorkoutBackupStore store;
  BackupState _state = BackupState();
  bool _disposed = false, busy = false;
  int _generation = 0;
  bool get authorized => !_disposed && activeScope() == scope;
  BackupState get state => authorized ? _state : BackupState();
  List<WorkoutBackupRecord> _records = [];
  List<WorkoutBackupRecord> get records =>
      authorized ? List.unmodifiable(_records) : const [];
  void _check(int generation) {
    if (!authorized || generation != _generation) {
      throw StateError('Backup session changed');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void>? _loading;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final generation = _generation;
    final value = await store.read();
    _check(generation);
    _state = value;
    _records = await local.read();
    _check(generation);
    _notify();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!authorized || busy) return;
    ++_generation;
    _state = BackupState(
        enabled: enabled,
        baselines: _state.baselines,
        conflicts: _state.conflicts,
        lastSuccessMillis: _state.lastSuccessMillis);
    await store.write(_state);
    if (!authorized) return;
    _notify();
    if (enabled) await sync();
  }

  BackupRecordStatus statusFor(WorkoutBackupRecord r) {
    if (!authorized || !_state.enabled) return BackupRecordStatus.localOnly;
    if (busy) return BackupRecordStatus.syncing;
    if (_state.conflicts.containsKey(r.key)) return BackupRecordStatus.conflict;
    if (_state.baselines[r.key] == r.digest) return BackupRecordStatus.backedUp;
    return _state.lastError == null
        ? BackupRecordStatus.localOnly
        : BackupRecordStatus.retryNeeded;
  }

  String get label => busy
      ? 'Syncing'
      : !state.enabled
          ? 'Saved locally'
          : state.conflicts.isNotEmpty
              ? 'Conflicting copies kept'
              : state.lastError != null
                  ? 'Retry needed'
                  : records.any(
                          (r) => statusFor(r) != BackupRecordStatus.backedUp)
                      ? 'Saved locally'
                      : 'Backed up';
  Future<void> sync() async {
    if (!authorized || busy || !_state.enabled) return;
    final generation = _generation;
    busy = true;
    _notify();
    final baselines = {..._state.baselines}, conflicts = <String, String>{};
    try {
      var localRows = {for (final r in await local.read()) r.key: r};
      _check(generation);
      String? cursor;
      final seen = <String>{};
      do {
        final page = await gateway.list(cursor);
        _check(generation);
        for (final remote in page.records) {
          if (!seen.add(remote.key)) {
            throw const FormatException('Duplicate backup page');
          }
          if (remote.kind == 'routine') {
            final links = remote.linkedSessionKeys;
            if (links.any((key) => !localRows.containsKey(key))) {
              throw const BackupFailure('incomplete-backup');
            }
            if (links.any(conflicts.containsKey)) {
              conflicts[remote.key] = remote.digest;
              continue;
            }
          }
          final here = localRows[remote.key];
          if (here?.digest == remote.digest) {
            baselines[remote.key] = remote.digest;
            continue;
          }
          if (here == null ||
              (remote.kind == 'routine' &&
                  here.digest == baselines[remote.key])) {
            _check(generation);
            final restored = await local.restore(remote, here?.digest);
            _check(generation);
            if (restored) {
              baselines[remote.key] = remote.digest;
              localRows[remote.key] = remote;
              continue;
            }
          }
          if (baselines[remote.key] != remote.digest) {
            conflicts[remote.key] = remote.digest;
          }
        }
        final next = page.nextCursor;
        if (next != null && (next == cursor || seen.length > 20000)) {
          throw const FormatException('Invalid backup cursor');
        }
        cursor = next;
      } while (cursor != null);
      localRows = {for (final r in await local.read()) r.key: r};
      _check(generation);
      for (final row in localRows.values) {
        if (row.linkedSessionKeys.any(conflicts.containsKey)) {
          conflicts[row.key] = row.digest;
          continue;
        }
        if (conflicts.containsKey(row.key) ||
            baselines[row.key] == row.digest) {
          continue;
        }
        try {
          final saved = await gateway.save(row, baselines[row.key]);
          _check(generation);
          if (saved != row.digest) {
            throw const FormatException('Backup receipt mismatch');
          }
          baselines[row.key] = saved;
        } on BackupFailure catch (e) {
          if (e.code != 'already-exists') rethrow;
          conflicts[row.key] = baselines[row.key] ?? row.digest;
        }
      }
      _check(generation);
      _state = BackupState(
          enabled: true,
          baselines: baselines,
          conflicts: conflicts,
          lastSuccessMillis: DateTime.now().toUtc().millisecondsSinceEpoch);
    } catch (e) {
      if (authorized && generation == _generation) {
        _state = BackupState(
            enabled: _state.enabled,
            baselines: baselines,
            conflicts: {..._state.conflicts, ...conflicts},
            lastError: e is BackupFailure ? e.code : 'unavailable',
            lastSuccessMillis: _state.lastSuccessMillis);
      }
    } finally {
      try {
        if (authorized && generation == _generation) {
          await store.write(_state);
          _records = await local.read();
          _check(generation);
        }
      } finally {
        busy = false;
        _notify();
      }
    }
  }

  /// Intentional local choice; remote archive revisions remain retained by server.
  bool canKeepLocal(WorkoutBackupRecord row) =>
      row.kind == 'routine' &&
      state.conflicts.containsKey(row.key) &&
      !row.linkedSessionKeys.any(state.conflicts.containsKey);

  Future<void> keepLocal(String key) async {
    if (!authorized || busy || !_state.enabled || !key.startsWith('routine-')) {
      return;
    }
    final remote = _state.conflicts[key];
    if (remote == null) return;
    final local = _records.where((row) => row.key == key).firstOrNull;
    if (local == null || !canKeepLocal(local)) return;
    _state = BackupState(
        enabled: true,
        baselines: {..._state.baselines, key: remote},
        conflicts: {..._state.conflicts}..remove(key),
        lastSuccessMillis: _state.lastSuccessMillis);
    await store.write(_state);
    await sync();
  }

  void accountChanged() {
    if (!authorized) {
      ++_generation;
      _records = [];
      _state = BackupState();
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
