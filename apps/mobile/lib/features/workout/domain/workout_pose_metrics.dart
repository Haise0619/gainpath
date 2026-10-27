import 'real_workout_contract.dart' show workoutConsentVersion;
import 'curl_arm_metrics.dart';

const _maximumMicros = 86400000000;
const _maximumAttempts = 10000;
const _supportedDeviations = {'trunkLean', 'incompleteDepth'};
final _metricId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// One supported deviation aggregate; never stores per-frame/attempt history.
class WorkoutDeviationAggregate {
  WorkoutDeviationAggregate(
      {required this.count, required this.maximumDegrees}) {
    if (count < 0 ||
        count > _maximumAttempts ||
        !maximumDegrees.isFinite ||
        maximumDegrees < 0 ||
        maximumDegrees > 180 ||
        (count == 0 && maximumDegrees != 0)) {
      throw const FormatException('Invalid workout deviation aggregate.');
    }
  }
  final int count;
  final double maximumDegrees;
  Map<String, Object?> toJson() =>
      {'count': count, 'maximumDegrees': maximumDegrees};
  factory WorkoutDeviationAggregate.fromJson(Map<String, Object?> json) {
    _fields(json, const {'count', 'maximumDegrees'});
    final degrees = json['maximumDegrees'];
    if (degrees is! num) {
      throw const FormatException('Invalid degree aggregate.');
    }
    return WorkoutDeviationAggregate(
        count: _integer(json, 'count'), maximumDegrees: degrees.toDouble());
  }
  @override
  bool operator ==(Object other) =>
      other is WorkoutDeviationAggregate &&
      count == other.count &&
      maximumDegrees == other.maximumDegrees;
  @override
  int get hashCode => Object.hash(count, maximumDegrees);
}

/// Immutable local measured results. Local acknowledgement is not a server
/// consent grant, proof of motion, upload permission or accuracy acceptance.
class WorkoutPoseMetrics {
  WorkoutPoseMetrics({
    required this.partialRepetitions,
    required this.trackedDurationMicros,
    required this.rejectedDurationMicros,
    required this.formScorePercent,
    required this.scoringVersion,
    required this.detectorId,
    required this.detectorVersion,
    required this.cameraView,
    required this.consentVersion,
    required DateTime consentedAt,
    this.publishedRoutineId,
    this.curlArms,
    Map<String, WorkoutDeviationAggregate> deviations = const {},
  })  : consentedAt = consentedAt.toUtc(),
        deviations = Map.unmodifiable(deviations) {
    if (partialRepetitions < 0 ||
        partialRepetitions > _maximumAttempts ||
        trackedDurationMicros < 0 ||
        rejectedDurationMicros < 0 ||
        trackedDurationMicros > _maximumMicros ||
        rejectedDurationMicros > _maximumMicros ||
        trackedDurationMicros + rejectedDurationMicros > _maximumMicros ||
        (formScorePercent != null &&
            (!formScorePercent!.isFinite ||
                formScorePercent! < 0 ||
                formScorePercent! > 100)) ||
        (trackedDurationMicros == 0 &&
            (formScorePercent != null || partialRepetitions != 0)) ||
        !const {
          'bodyweight-squat-side-v1',
          'single-arm-curl-side-v1',
          'standing-calf-raise-side-v1',
          'wall-push-up-side-v1'
        }.contains(scoringVersion) ||
        cameraView != 'side' ||
        consentVersion != workoutConsentVersion ||
        !_metricId.hasMatch(detectorId) ||
        !_metricId.hasMatch(detectorVersion) ||
        (publishedRoutineId != null &&
            !_metricId.hasMatch(publishedRoutineId!)) ||
        !deviations.keys.every(_supportedDeviations.contains) ||
        (scoringVersion != 'bodyweight-squat-side-v1' &&
            deviations.isNotEmpty) ||
        (curlArms != null &&
            (scoringVersion != 'single-arm-curl-side-v1' ||
                curlArms!.partialRepetitions != partialRepetitions ||
                (curlArms!.formScorePercent != formScorePercent &&
                    (curlArms!.formScorePercent == null ||
                        formScorePercent == null ||
                        (curlArms!.formScorePercent! - formScorePercent!)
                                .abs() >
                            .000001))))) {
      throw const FormatException('Invalid local pose metrics.');
    }
  }

  final int partialRepetitions, trackedDurationMicros, rejectedDurationMicros;
  final double? formScorePercent;
  final String scoringVersion,
      detectorId,
      detectorVersion,
      cameraView,
      consentVersion;
  final String? publishedRoutineId;
  final DateTime consentedAt;
  final Map<String, WorkoutDeviationAggregate> deviations;
  final CurlArmMetrics? curlArms;

  Map<String, Object?> toJson() => {
        'schemaVersion': curlArms == null ? 1 : 2,
        if (curlArms != null) 'curlArms': curlArms!.toJson(),
        'partialRepetitions': partialRepetitions,
        'trackedDurationMicros': trackedDurationMicros,
        'rejectedDurationMicros': rejectedDurationMicros,
        'formScorePercent': formScorePercent,
        'scoringVersion': scoringVersion,
        'detectorId': detectorId,
        'detectorVersion': detectorVersion,
        'cameraView': cameraView,
        'consentVersion': consentVersion,
        'consentedAt': consentedAt.toIso8601String(),
        'publishedRoutineId': publishedRoutineId,
        'deviations':
            deviations.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory WorkoutPoseMetrics.fromJson(Map<String, Object?> json) {
    _fields(json, {
      'schemaVersion',
      'partialRepetitions',
      'trackedDurationMicros',
      'rejectedDurationMicros',
      'formScorePercent',
      'scoringVersion',
      'detectorId',
      'detectorVersion',
      'cameraView',
      'consentVersion',
      'consentedAt',
      'publishedRoutineId',
      'deviations',
      if (json['schemaVersion'] == 2) 'curlArms',
    });
    if (json['schemaVersion'] != 1 && json['schemaVersion'] != 2) {
      throw const FormatException('Unsupported pose metrics version.');
    }
    final score = json['formScorePercent'];
    final routine = json['publishedRoutineId'];
    final rawDate = json['consentedAt'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if ((score != null && score is! num) ||
        (routine != null && routine is! String) ||
        date == null) {
      throw const FormatException('Invalid local pose metric values.');
    }
    final rawDeviations = _object(json['deviations']);
    if (!rawDeviations.keys.every(_supportedDeviations.contains)) {
      throw const FormatException('Unsupported workout deviation.');
    }
    return WorkoutPoseMetrics(
      curlArms: json['schemaVersion'] == 2
          ? CurlArmMetrics.fromJson(_object(json['curlArms']))
          : null,
      partialRepetitions: _integer(json, 'partialRepetitions'),
      trackedDurationMicros: _integer(json, 'trackedDurationMicros'),
      rejectedDurationMicros: _integer(json, 'rejectedDurationMicros'),
      formScorePercent: (score as num?)?.toDouble(),
      scoringVersion: _text(json, 'scoringVersion'),
      detectorId: _text(json, 'detectorId'),
      detectorVersion: _text(json, 'detectorVersion'),
      cameraView: _text(json, 'cameraView'),
      consentVersion: _text(json, 'consentVersion'),
      consentedAt: date,
      publishedRoutineId: routine as String?,
      deviations: rawDeviations.map((key, value) =>
          MapEntry(key, WorkoutDeviationAggregate.fromJson(_object(value)))),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutPoseMetrics &&
      curlArms == other.curlArms &&
      partialRepetitions == other.partialRepetitions &&
      trackedDurationMicros == other.trackedDurationMicros &&
      rejectedDurationMicros == other.rejectedDurationMicros &&
      formScorePercent == other.formScorePercent &&
      scoringVersion == other.scoringVersion &&
      detectorId == other.detectorId &&
      detectorVersion == other.detectorVersion &&
      cameraView == other.cameraView &&
      consentVersion == other.consentVersion &&
      consentedAt == other.consentedAt &&
      publishedRoutineId == other.publishedRoutineId &&
      deviations.length == other.deviations.length &&
      deviations.entries
          .every((entry) => other.deviations[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros,
      formScorePercent,
      scoringVersion,
      detectorId,
      detectorVersion,
      cameraView,
      consentVersion,
      consentedAt,
      publishedRoutineId,
      deviations['trunkLean'],
      deviations['incompleteDepth'],
      curlArms);
}

void _fields(Map<String, Object?> json, Set<String> fields) {
  if (json.length != fields.length || !fields.every(json.containsKey)) {
    throw const FormatException('Unexpected or missing pose metrics fields.');
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Pose metrics must be an object.');
  }
  return Map<String, Object?>.from(value);
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Invalid pose integer: $key');
}

String _text(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid pose text: $key');
}
