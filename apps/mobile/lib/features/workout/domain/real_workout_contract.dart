import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart'
    show ExerciseTrackingRegistry, ExerciseTrackingCapability;

const workoutConsentVersion = 'pose-local-summary-v1';
const _maxTimestamp = 8639999996400000;
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Bounded wire DTO only. Parsing validates client assertions; it neither
/// proves motion nor enables capture, persistence or trusted acceptance.
class RealWorkoutSubmission {
  RealWorkoutSubmission._(Map<String, Object?> json)
      : _json = Map.unmodifiable(json);

  static const _ids = {
    'requestId',
    'organizationId',
    'memberId',
    'sessionId',
    'exerciseId',
    'publishedRoutineId',
    'scoringVersion',
    'detectorId',
    'detectorVersion',
    'consentVersion',
    'consentAcknowledgementId',
  };
  static const _fields = {
    ..._ids,
    'schemaVersion',
    'provenance',
    'cameraView',
    'startedAtMillis',
    'endedAtMillis',
    'repetitions',
    'formScorePercent',
    'trackedDurationMillis',
    'rejectedDurationMillis',
  };

  factory RealWorkoutSubmission.fromJson(Map<String, Object?> json) {
    _exactFields(json, _fields);
    for (final key in _ids) {
      _id(json, key);
    }
    if (json['schemaVersion'] != 2 ||
        json['provenance'] != 'real_camera' ||
        json['cameraView'] != 'side' ||
        json['consentVersion'] != workoutConsentVersion ||
        json['memberId'] == 'demo-user' ||
        json['organizationId'] == 'demo-org' ||
        {'simulated', 'demo', 'fixture', 'unknown', 'recorded_fixture'}
            .contains(json['detectorId'])) {
      throw const FormatException(
          'Invalid real workout identity or provenance.');
    }
    final start = _integer(json, 'startedAtMillis', 1, _maxTimestamp);
    final end = _integer(json, 'endedAtMillis', 1, _maxTimestamp);
    final reps = _integer(json, 'repetitions', 0, 10000);
    final tracked = _integer(json, 'trackedDurationMillis', 0, 86400000);
    final rejected = _integer(json, 'rejectedDurationMillis', 0, 86400000);
    final score = json['formScorePercent'];
    if (end <= start ||
        end - start > 86400000 ||
        tracked + rejected > end - start ||
        (score != null &&
            (score is! num || !score.isFinite || score < 0 || score > 100)) ||
        (tracked == 0 && (score != null || reps != 0))) {
      throw const FormatException('Invalid workout chronology or metrics.');
    }
    return RealWorkoutSubmission._(json);
  }

  final Map<String, Object?> _json;
  SessionScope get scope => SessionScope(
      userId: _json['memberId'] as String,
      organizationId: _json['organizationId'] as String);
  String get sessionId => _json['sessionId'] as String;
  String get exerciseId => _json['exerciseId'] as String;
  String get consentVersion => _json['consentVersion'] as String;
  String get consentAcknowledgementId =>
      _json['consentAcknowledgementId'] as String;
  int get startedAtMillis => _json['startedAtMillis'] as int;
  num? get formScorePercent => _json['formScorePercent'] as num?;
  Map<String, Object?> toJson() => _json;
}

/// Explicit development catalog-to-rule candidate, never resolved by name.
/// This binding does not imply an enabled or device-validated pose rule.
class DevelopmentSquatBinding {
  const DevelopmentSquatBinding._({required this.sets, required this.reps});

  static DevelopmentSquatBinding? resolve(
      {required String organizationId,
      required String exerciseId,
      required int sets,
      required int reps}) {
    if (ExerciseTrackingRegistry.resolve(
                organizationId: organizationId, exerciseId: exerciseId)
            .trackerId !=
        ExerciseTrackingCapability.sideViewSquat.trackerId) {
      return null;
    }
    if (sets <= 0 || reps <= 0) {
      throw const FormatException('Invalid published exercise targets.');
    }
    return DevelopmentSquatBinding._(sets: sets, reps: reps);
  }

  String get scoringVersion => 'bodyweight-squat-side-v1';
  String get cameraView => 'side';
  final int sets;
  final int reps;
}

/// Cached server acknowledgement for subsequent authorized offline use.
/// The server must independently recheck current consent and revocation.
class WorkoutConsentAcknowledgement {
  WorkoutConsentAcknowledgement._(Map<String, Object?> json)
      : _json = Map.unmodifiable(json);

  factory WorkoutConsentAcknowledgement.fromJson(Map<String, Object?> json) {
    _exactFields(json, const {
      'schemaVersion',
      'requestId',
      'organizationId',
      'memberId',
      'consentVersion',
      'acknowledgementId',
      'acknowledgedAtMillis'
    });
    for (final key in [
      'requestId',
      'organizationId',
      'memberId',
      'acknowledgementId'
    ]) {
      _id(json, key);
    }
    _integer(json, 'acknowledgedAtMillis', 1, _maxTimestamp);
    if (json['schemaVersion'] != 1 ||
        json['consentVersion'] != workoutConsentVersion) {
      throw const FormatException('Unsupported workout consent.');
    }
    return WorkoutConsentAcknowledgement._(json);
  }

  final Map<String, Object?> _json;
  Map<String, Object?> toJson() => _json;
  SessionScope get scope => SessionScope(
      userId: _json['memberId'] as String,
      organizationId: _json['organizationId'] as String);
  String get requestId => _json['requestId'] as String;
  String get acknowledgementId => _json['acknowledgementId'] as String;
  int get acknowledgedAtMillis => _json['acknowledgedAtMillis'] as int;
  bool authorizes(RealWorkoutSubmission submission) =>
      _json['organizationId'] == submission.scope.organizationId &&
      _json['memberId'] == submission.scope.userId &&
      _json['consentVersion'] == submission.consentVersion &&
      _json['acknowledgementId'] == submission.consentAcknowledgementId &&
      (_json['acknowledgedAtMillis'] as int) <= submission.startedAtMillis;
}

void _exactFields(Map<String, Object?> json, Set<String> fields) {
  if (json.length != fields.length || !fields.every(json.containsKey)) {
    throw const FormatException(
        'Unexpected or missing workout contract fields.');
  }
}

void _id(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || !_idPattern.hasMatch(value)) {
    throw FormatException('Invalid workout contract identifier: $key.');
  }
}

int _integer(Map<String, Object?> json, String key, int minimum, int maximum) {
  final value = json[key];
  if (value is! int || value < minimum || value > maximum) {
    throw FormatException('Invalid workout contract integer: $key.');
  }
  return value;
}
