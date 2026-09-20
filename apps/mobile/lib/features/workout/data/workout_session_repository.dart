import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/workout_contracts.dart';
export '../domain/workout_contracts.dart';

class InMemoryWorkoutSessionStore implements WorkoutSessionStore {
  InMemoryWorkoutSessionStore({SessionScope? scope})
      : scope = scope ??
            SessionScope(userId: 'demo-user', organizationId: 'demo-org');
  @override
  final SessionScope scope;
  List<WorkoutSessionRecord> _records = [];
  Future<void> _tail = Future<void>.value();
  @override
  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail =
        result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }

  @override
  Future<List<WorkoutSessionRecord>> read() async =>
      List.unmodifiable(_records);
  @override
  Future<void> write(List<WorkoutSessionRecord> records) async {
    if (records.any((record) => record.summary.scope != scope)) {
      throw StateError('Workout account mismatch.');
    }
    _records = List.of(records);
  }
}

class InMemoryWorkoutUploadGateway implements WorkoutUploadGateway {
  final List<WorkoutSessionSummary> uploaded = [];
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) async {
    if (!uploaded.any((item) =>
        item.scope == summary.scope && item.sessionId == summary.sessionId)) {
      uploaded.add(summary);
    }
    return WorkoutUploadReceipt(
        acceptedAt: DateTime.now().toUtc(),
        serverReference: 'local-accepted-${summary.sessionId}');
  }
}

class UnavailableWorkoutUploadGateway implements WorkoutUploadGateway {
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) =>
      Future.error(
          UnsupportedError('Workout upload is not configured for this build.'));
}

class WorkoutSessionRepository implements WorkoutRepository {
  WorkoutSessionRepository({
    required this.scope,
    required WorkoutSessionStore store,
    required WorkoutUploadGateway uploadGateway,
    required SessionScope? Function() activeScope,
  })  : _store = store,
        _uploadGateway = uploadGateway,
        _activeScope = activeScope {
    if (store.scope != scope) {
      throw ArgumentError('Store and repository scopes must match.');
    }
  }
  @override
  final SessionScope scope;
  final WorkoutSessionStore _store;
  final WorkoutUploadGateway _uploadGateway;
  final SessionScope? Function() _activeScope;
  bool _disposed = false;

  void _checkActive() {
    if (_disposed || _activeScope() != scope) {
      throw StateError('Workout account is no longer active.');
    }
  }

  void _checkRecords(List<WorkoutSessionRecord> records) {
    if (records.any((record) => record.summary.scope != scope)) {
      throw StateError('Stored workout account mismatch.');
    }
  }

  @override
  Future<void> saveLocal(WorkoutSessionSummary summary) =>
      _store.exclusive(() async {
        _checkActive();
        if (summary.scope != scope) {
          throw StateError('Cannot save another account workout.');
        }
        final records = List<WorkoutSessionRecord>.of(await _store.read());
        _checkRecords(records);
        _checkActive();
        final existing = records
            .where((record) => record.summary.sessionId == summary.sessionId);
        if (existing.isNotEmpty) {
          if (existing.single.summary != summary) {
            throw StateError(
                'Session ID already belongs to a different summary.');
          }
          return; // A retry must never turn an accepted record back into pending.
        }
        records.add(WorkoutSessionRecord(
            summary: summary, status: WorkoutSyncStatus.pending));
        await _store.write(records);
        _checkActive();
      });

  @override
  Future<List<WorkoutSessionRecord>> loadHistory() =>
      _store.exclusive(() async {
        _checkActive();
        final records = await _store.read();
        _checkRecords(records);
        _checkActive();
        return List.unmodifiable(records.reversed);
      });

  @override
  Future<WorkoutSyncResult> syncPending() => _store.exclusive(() async {
        _checkActive();
        final records = List<WorkoutSessionRecord>.of(await _store.read());
        _checkRecords(records);
        var acceptedCount = 0;
        var failedCount = 0;
        for (var index = 0; index < records.length; index++) {
          final record = records[index];
          if (record.status != WorkoutSyncStatus.pending) continue;
          _checkActive();
          WorkoutUploadReceipt receipt;
          try {
            receipt = await _uploadGateway.upload(record.summary);
          } on Object {
            _checkActive();
            failedCount++;
            continue;
          }
          _checkActive();
          records[index] = record.copyWith(
              status: WorkoutSyncStatus.accepted,
              acceptedAt: receipt.acceptedAt,
              serverReference: receipt.serverReference);
          await _store
              .write(records); // Persist each acknowledgement before advancing.
          _checkActive();
          acceptedCount++;
        }
        return WorkoutSyncResult(
            acceptedCount: acceptedCount, failedCount: failedCount);
      });

  @override
  void dispose() {
    _disposed = true;
  }
}

/// Explicit development/test composition. Never selected by a production screen.
class InMemoryWorkoutSessionRepository extends WorkoutSessionRepository {
  factory InMemoryWorkoutSessionRepository(
      {WorkoutUploadGateway? uploadGateway, SessionScope? scope}) {
    final account =
        scope ?? SessionScope(userId: 'demo-user', organizationId: 'demo-org');
    return InMemoryWorkoutSessionRepository._(
        account, uploadGateway ?? InMemoryWorkoutUploadGateway());
  }
  InMemoryWorkoutSessionRepository._(
      SessionScope account, WorkoutUploadGateway gateway)
      : super(
            scope: account,
            store: InMemoryWorkoutSessionStore(scope: account),
            uploadGateway: gateway,
            activeScope: () => account);
}
