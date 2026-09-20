import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.repetitions,
    required this.downThreshold,
    required this.upThreshold,
  });

  final String id;
  final String name;
  final int sets;
  final int repetitions;
  final double downThreshold;
  final double upThreshold;
}

class WorkoutPlan {
  const WorkoutPlan({required this.exercises});

  static const starter = WorkoutPlan(
    exercises: [
      WorkoutExercise(
        id: 'bodyweight_squat',
        name: 'Bodyweight Squat',
        sets: 3,
        repetitions: 10,
        downThreshold: 0.7,
        upThreshold: 0.3,
      ),
    ],
  );

  final List<WorkoutExercise> exercises;
}

class WorkoutSessionSummary {
  const WorkoutSessionSummary({
    this.userId = 'demo-user',
    this.organizationId = 'demo-org',
    required this.sessionId,
    required this.exerciseId,
    required this.repetitions,
    required this.accuracy,
    required this.startedAt,
    required this.endedAt,
  });

  final String sessionId;
  final String userId;
  final String organizationId;
  SessionScope get scope =>
      SessionScope(userId: userId, organizationId: organizationId);
  final String exerciseId;
  final int repetitions;
  final int accuracy;
  final DateTime startedAt;
  final DateTime endedAt;

  Map<String, Object?> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'organizationId': organizationId,
      'exerciseId': exerciseId,
      'repetitions': repetitions,
      'accuracy': accuracy,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
    };
  }

  factory WorkoutSessionSummary.fromJson(Map<String, Object?> json) {
    return WorkoutSessionSummary(
      sessionId: _requiredString(json, 'sessionId'),
      userId: _requiredString(json, 'userId'),
      organizationId: _requiredString(json, 'organizationId'),
      exerciseId: _requiredString(json, 'exerciseId'),
      repetitions: _requiredInt(json, 'repetitions'),
      accuracy: _requiredInt(json, 'accuracy'),
      startedAt: _requiredDateTime(json, 'startedAt'),
      endedAt: _requiredDateTime(json, 'endedAt'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutSessionSummary &&
      other.sessionId == sessionId &&
      other.userId == userId &&
      other.organizationId == organizationId &&
      other.exerciseId == exerciseId &&
      other.repetitions == repetitions &&
      other.accuracy == accuracy &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
        sessionId,
        userId,
        organizationId,
        exerciseId,
        repetitions,
        accuracy,
        startedAt,
        endedAt,
      );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Workout session field "$key" must be a string.');
}

enum WorkoutSyncStatus { pending, accepted }

class WorkoutSessionRecord {
  const WorkoutSessionRecord({
    required this.summary,
    required this.status,
    this.acceptedAt,
    this.serverReference,
  });

  final WorkoutSessionSummary summary;
  final WorkoutSyncStatus status;
  final DateTime? acceptedAt;
  final String? serverReference;

  WorkoutSessionRecord copyWith({
    WorkoutSyncStatus? status,
    DateTime? acceptedAt,
    String? serverReference,
  }) {
    return WorkoutSessionRecord(
      summary: summary,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      serverReference: serverReference ?? this.serverReference,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'summary': summary.toJson(),
      'status': status.name,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'serverReference': serverReference,
    };
  }

  factory WorkoutSessionRecord.fromJson(Map<String, Object?> json) {
    final status = json['status'];
    final acceptedAt = json['acceptedAt'];
    final serverReference = json['serverReference'];
    final summary = json['summary'];
    if (status is! String || summary is! Map) {
      throw const FormatException('Invalid workout session record.');
    }
    final parsedStatus = WorkoutSyncStatus.values.where(
      (value) => value.name == status,
    );
    if (parsedStatus.isEmpty) {
      throw FormatException('Unknown workout sync status "$status".');
    }
    DateTime? parsedAcceptedAt;
    if (acceptedAt is String) {
      parsedAcceptedAt = DateTime.tryParse(acceptedAt);
      if (parsedAcceptedAt == null) {
        throw const FormatException('Invalid workout acceptance timestamp.');
      }
    }
    return WorkoutSessionRecord(
      summary: WorkoutSessionSummary.fromJson(
        Map<String, Object?>.from(summary),
      ),
      status: parsedStatus.first,
      acceptedAt: parsedAcceptedAt,
      serverReference: serverReference is String ? serverReference : null,
    );
  }
}

class WorkoutUploadReceipt {
  const WorkoutUploadReceipt({
    required this.acceptedAt,
    required this.serverReference,
  });

  final DateTime acceptedAt;
  final String serverReference;
}

class WorkoutSyncResult {
  const WorkoutSyncResult({
    required this.acceptedCount,
    required this.failedCount,
  });

  final int acceptedCount;
  final int failedCount;
}

abstract interface class WorkoutRepository {
  SessionScope get scope;
  Future<void> saveLocal(WorkoutSessionSummary summary);
  Future<List<WorkoutSessionRecord>> loadHistory();
  Future<WorkoutSyncResult> syncPending();

  /// Immediately invalidates queued work and suppresses stale upload results.
  void dispose();
}

/// One store per immutable account scope. Repositories use exclusive for every
/// read/modify/write operation, including upload acknowledgement persistence.
abstract interface class WorkoutSessionStore {
  SessionScope get scope;
  Future<T> exclusive<T>(Future<T> Function() action);
  Future<List<WorkoutSessionRecord>> read();
  Future<void> write(List<WorkoutSessionRecord> records);
}

abstract interface class WorkoutUploadGateway {
  /// Must authenticate as summary.scope and use sessionId as an idempotency key.
  /// The server must independently validate ownership and deduplicate retries.
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary);
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Workout session field "$key" must be an integer.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Workout session field "$key" must be an ISO date.');
}
