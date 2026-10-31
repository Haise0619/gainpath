import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'workout_pose_metrics.dart';
export 'workout_pose_metrics.dart';

final _measuredSummaryId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
const _measuredSummaryFields = {
  'sessionId',
  'userId',
  'organizationId',
  'exerciseId',
  'repetitions',
  'accuracy',
  'startedAt',
  'endedAt',
  'summarySchemaVersion',
  'provenance',
  'poseMetrics'
};

enum WorkoutProvenance { legacyUnknown, simulated, recordedFixture, realCamera }

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
    this.provenance = WorkoutProvenance.simulated,
    this.poseMetrics,
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
  final WorkoutProvenance provenance;
  final WorkoutPoseMetrics? poseMetrics;
  double? get formScorePercent => poseMetrics?.formScorePercent;
  int get partialRepetitions => poseMetrics?.partialRepetitions ?? 0;
  int get trackedDurationMicros => poseMetrics?.trackedDurationMicros ?? 0;
  int get rejectedDurationMicros => poseMetrics?.rejectedDurationMicros ?? 0;

  /// Legacy summaries retain their existing semantics. Measured summaries must
  /// be self-consistent before local persistence; this does not enable upload.
  void validateForLocalStorage() {
    final metrics = poseMetrics;
    if (metrics == null) return;
    final elapsed = endedAt.difference(startedAt).inMicroseconds;
    final attempts = repetitions + metrics.partialRepetitions;
    if (!{WorkoutProvenance.realCamera, WorkoutProvenance.recordedFixture}
            .contains(provenance) ||
        ![sessionId, userId, organizationId, exerciseId]
            .every(_measuredSummaryId.hasMatch) ||
        accuracy < 0 ||
        accuracy > 100 ||
        (metrics.scoringVersion == 'standing-lateral-raise-front-v1' &&
            (accuracy != 0 ||
                organizationId != 'gainpath' ||
                exerciseId != 'standing-lateral-raise-front-v1')) ||
        (exerciseId == 'standing-lateral-raise-front-v1' &&
            metrics.scoringVersion != 'standing-lateral-raise-front-v1') ||
        (metrics.scoringVersion == 'reverse-lunge-side-v1' &&
            (accuracy != 0 ||
                organizationId != 'gainpath' ||
                exerciseId != 'bodyweight-reverse-lunge-side-v1')) ||
        (exerciseId == 'bodyweight-reverse-lunge-side-v1' &&
            metrics.scoringVersion != 'reverse-lunge-side-v1') ||
        (metrics.scoringVersion == 'dumbbell-shoulder-press-front-v1' &&
            (accuracy != 0 ||
                organizationId != 'gainpath' ||
                exerciseId != 'dumbbell-shoulder-press-front-v1')) ||
        (exerciseId == 'dumbbell-shoulder-press-front-v1' &&
            metrics.scoringVersion != 'dumbbell-shoulder-press-front-v1') ||
        (metrics.scoringVersion == 'single-arm-row-side-v1' &&
            (accuracy != 0 ||
                organizationId != 'gainpath' ||
                exerciseId != 'single-arm-dumbbell-row-side-v1')) ||
        (exerciseId == 'single-arm-dumbbell-row-side-v1' &&
            metrics.scoringVersion != 'single-arm-row-side-v1') ||
        repetitions < 0 ||
        repetitions > 10000 ||
        attempts > 10000 ||
        elapsed < 0 ||
        elapsed > 86400000000 ||
        metrics.trackedDurationMicros + metrics.rejectedDurationMicros >
            elapsed ||
        metrics.consentedAt.isAfter(startedAt) ||
        (metrics.trackedDurationMicros == 0 && repetitions != 0) ||
        (attempts == 0 && metrics.formScorePercent != null) ||
        metrics.deviations.values.any((value) => value.count > attempts) ||
        (metrics.curlArms != null &&
            metrics.curlArms!.repetitions != repetitions) ||
        (provenance == WorkoutProvenance.realCamera &&
            {'simulated', 'demo', 'fixture', 'unknown'}
                .contains(metrics.detectorId))) {
      throw const FormatException(
          'Inconsistent local measured workout summary.');
    }
  }

  // Step 1 is fail-closed. A real submission DTO will carry consent and version
  // evidence; setting a provenance label alone never enables real upload.
  bool get isEligibleForRealUpload => false;

  Map<String, Object?> toJson() {
    validateForLocalStorage();
    return {
      'sessionId': sessionId,
      'userId': userId,
      'organizationId': organizationId,
      'exerciseId': exerciseId,
      'repetitions': repetitions,
      'accuracy': accuracy,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'summarySchemaVersion': poseMetrics == null ? 2 : 3,
      'provenance': provenance.name,
      if (poseMetrics != null) 'poseMetrics': poseMetrics!.toJson(),
    };
  }

  factory WorkoutSessionSummary.fromJson(Map<String, Object?> json) {
    final version = json['summarySchemaVersion'];
    if (version != null && version != 2 && version != 3) {
      throw const FormatException('Unsupported local workout summary version.');
    }
    if (version == 3 &&
        (json.length != _measuredSummaryFields.length ||
            !_measuredSummaryFields.every(json.containsKey))) {
      throw const FormatException(
          'Unexpected measured workout summary fields.');
    }
    final rawProvenance = json['provenance'];
    final provenance = version == null
        ? WorkoutProvenance.legacyUnknown
        : WorkoutProvenance.values
            .where((p) => p.name == rawProvenance)
            .firstOrNull;
    if (provenance == null) {
      throw const FormatException('Invalid workout provenance.');
    }
    final rawMetrics = json['poseMetrics'];
    if (version == 3 &&
        (rawMetrics is! Map || rawMetrics.keys.any((key) => key is! String))) {
      throw const FormatException('Measured workout metrics are required.');
    }
    final summary = WorkoutSessionSummary(
      sessionId: _requiredString(json, 'sessionId'),
      userId: _requiredString(json, 'userId'),
      organizationId: _requiredString(json, 'organizationId'),
      exerciseId: _requiredString(json, 'exerciseId'),
      repetitions: _requiredInt(json, 'repetitions'),
      accuracy: _requiredInt(json, 'accuracy'),
      startedAt: _requiredDateTime(json, 'startedAt'),
      endedAt: _requiredDateTime(json, 'endedAt'),
      provenance: provenance,
      poseMetrics: version == 3
          ? WorkoutPoseMetrics.fromJson(
              Map<String, Object?>.from(rawMetrics as Map))
          : null,
    );
    summary.validateForLocalStorage();
    return summary;
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
      other.endedAt == endedAt &&
      other.provenance == provenance &&
      other.poseMetrics == poseMetrics;

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
        provenance,
        poseMetrics,
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

  void validateForLocalStorage() {
    summary.validateForLocalStorage();
    if ((summary.poseMetrics != null ||
            summary.provenance == WorkoutProvenance.realCamera ||
            summary.provenance == WorkoutProvenance.recordedFixture) &&
        (status != WorkoutSyncStatus.pending ||
            acceptedAt != null ||
            serverReference != null)) {
      throw const FormatException(
          'Measured workout acceptance is not enabled.');
    }
  }

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
    validateForLocalStorage();
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
    final parsedSummary =
        WorkoutSessionSummary.fromJson(Map<String, Object?>.from(summary));
    if ((parsedSummary.poseMetrics != null ||
            parsedSummary.provenance == WorkoutProvenance.realCamera ||
            parsedSummary.provenance == WorkoutProvenance.recordedFixture) &&
        (acceptedAt != null || serverReference != null)) {
      throw const FormatException(
          'Measured workout acceptance is not enabled.');
    }
    final record = WorkoutSessionRecord(
      summary: parsedSummary,
      status: parsedStatus.first,
      acceptedAt: parsedAcceptedAt,
      serverReference: serverReference is String ? serverReference : null,
    );
    record.validateForLocalStorage();
    return record;
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

/// Explicit local prototype acceptance, never a network activity uploader.
abstract interface class DemoWorkoutUploadGateway
    implements WorkoutUploadGateway {}

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
